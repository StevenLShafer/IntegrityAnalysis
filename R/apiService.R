# apiService.R - the REST API around the analysis (ISSUES.md issue 1).
#
############################################################################
# Provenance                                                               #
# Written 2026-08-26 by Claude Code (model Claude Fable 5) at Steve        #
# Shafer's request ("Is it time to implement the API? I know that will    #
# be of interest to publishers"), to the contract issue 1 has carried     #
# since the start: input is one PDF or spreadsheet; on pass return the    #
# Monte Carlo results plus confirmation the upload was deleted; on fail   #
# return THE PARTIAL TABLE - valid input for the next call - plus what    #
# is wrong with it; retention none.                                       #
#                                                                          #
# Design decisions (Steve, 2026-08-26):                                    #
# - Hosting target is an AWS container (phase 2); THIS file is           #
#   hosting-agnostic - runApiService() starts plumber on a port and      #
#   works identically on a laptop and in a container.                     #
# - Callers authenticate with bearer tokens Steve issues: the            #
#   INTEGRITY_API_TOKENS environment variable holds a comma-separated    #
#   list; a request whose Authorization header does not carry one of     #
#   them is refused 401 before any handler runs. /health alone is open   #
#   (it serves load balancers and carries no data).                       #
# - BYOK per request (issue 8's service side): an X-Anthropic-Key        #
#   header switches parsing from ai="never" to the fallback path for     #
#   THAT request only. The key is the caller's consent and their bill;   #
#   it is never stored, never logged, and is scrubbed from any error     #
#   text that could echo it - same guarantees as the app.                #
#                                                                          #
# The security posture the app promises is preserved here:                #
# - every upload lands in its own fresh tempdir that is deleted when     #
#   the request ends, success or failure - the response says so          #
#   ("deleted": true), because the contract requires confirming it;      #
# - PDFs and docx go through parseBaselineTableFiles(), the subprocess-  #
#   per-file batcher with an OS timeout: ~2% of real PDFs hang poppler,  #
#   R cannot interrupt it, and a service must survive a crafted or       #
#   broken upload (the manuscript AUTHOR is the adversary - AGENTS.md);  #
# - no code path writes an upload anywhere but its request tempdir.      #
#                                                                          #
# Status: run and verified by tests/testthat/test-api-service.R, which   #
# boots the service in a callr subprocess and exercises health, auth,    #
# parse (success and the failure round-trip), and analyze end to end.    #
############################################################################

# ---- request helpers (plain functions, unit-testable without a server) ---

# Strip the request's working directory (either slash style) from a
# reason string, leaving the file's own name (break test, 2026-09-06: the
# docx reader's zip error quoted the full temp path back to the caller)
.apiScrubPath <- function(reasons, work, name) {
  if (is.null(reasons) || !is.character(reasons)) return(reasons)
  # the parse child's tempdir is a sibling of `work` under the parent's
  # tempdir, so the parent's tempdir is scrubbed as well (screen
  # 2026-09-06-1118 F3); longest strings first so a prefix never
  # survives a shorter match
  roots <- c(work, tempdir())
  ws <- unique(c(roots, normalizePath(roots, winslash = "/", mustWork = FALSE),
                 normalizePath(roots, winslash = "\\", mustWork = FALSE)))
  ws <- ws[order(-nchar(ws))]
  for (w in ws) for (sep in c("/", "\\", ""))
    reasons <- gsub(paste0(w, sep), "", reasons, fixed = TRUE)
  reasons
}

# The reader's flags, made safe to put in a reply (security screen
# 2026-09-07-1654, finding F3). A flag quotes the document: skipped table
# lines and the arm-size sentences the reader recovered N from, and with
# the AI assist on, model output the manuscript can steer. Two properties
# are pinned here rather than left to the goodwill of every present and
# future flag constructor: the array cannot grow without bound (the row
# cap bounds the TABLE, not the lines the reader refused), and a flag that
# one day quotes a reader's error cannot carry the request's temp path
# back to the caller. Truncation is marked, never silent.
# The refused table lines travel beside the flags and carry the document's
# own text; the row cap bounds the TABLE, not the lines a reader could not
# use, so they are bounded here too (security screen 2026-09-07-1758,
# finding F3 - the flags fix's own rationale applied to its neighbour).
.apiMaxSkipped <- 200L
.apiSafeSkipped <- function(skipped, work, name) {
  if (is.null(skipped) || !nrow(skipped)) return(list())
  n <- nrow(skipped)
  keep <- seq_len(min(n, .apiMaxSkipped))
  # each string on its own - NOT through .apiSafeFlags(), whose own cap of
  # 50 entries would have turned skipped lines 51 and beyond into one
  # truncation message and a run of NAs (CodeRabbit on PR #219)
  lab <- .apiSafeText(skipped$label[keep], work, name)
  rsn <- .apiSafeText(skipped$reason[keep], work, name)
  out <- lapply(seq_along(keep), function(i)
    list(label = lab[i], reason = rsn[i]))
  if (n > .apiMaxSkipped)
    out <- c(out, list(list(
      label = sprintf("...%d further line(s) omitted", n - .apiMaxSkipped),
      reason = "the reply's list of unusable lines is capped")))
  out
}

.apiMaxFlags     <- 50L
.apiMaxFlagBytes <- 2048L

# One string, made safe to put in a reply: valid UTF-8, the request's
# directories removed, and no longer than .apiMaxFlagBytes BYTES. Applied
# element by element to a vector, with no cap on how many elements - the
# callers decide that, because a flag list and a list of refused lines are
# bounded differently.
.apiSafeText <- function(x, work, name) {
  if (is.null(x) || !length(x)) return(character(0))
  # Every step below inspects the string, and a string that is not valid
  # UTF-8 makes nchar(), substr() and gsub(fixed = TRUE) raise - which
  # would turn a successful parse into a 500 (security screen
  # 2026-09-07-1758, finding F4). No reader is known to produce one; the
  # guard is here so that none ever can.
  f <- enc2utf8(as.character(x))
  bad <- is.na(f) | is.na(iconv(f, "UTF-8", "UTF-8"))
  if (any(bad)) f[bad] <- "<unreadable text removed>"
  f <- .apiScrubPath(f, work, name)
  # by BYTES, and substr() counts characters: 2,048 accented letters are
  # 4,096 bytes and survived the cut whole (CodeRabbit on PR #217).
  # Characters are cut until the byte count fits, so a multi-byte
  # character is never sliced in half either.
  cut <- function(x) {
    k <- nchar(x)
    while (k > 0 && nchar(substr(x, 1, k), type = "bytes") > .apiMaxFlagBytes)
      k <- max(0L, k - max(1L, (nchar(substr(x, 1, k), type = "bytes") -
                                .apiMaxFlagBytes) %/% 4L))
    paste0(substr(x, 1, k), " ...truncated")
  }
  long <- nchar(f, type = "bytes") > .apiMaxFlagBytes
  if (any(long)) f[long] <- vapply(f[long], cut, character(1), USE.NAMES = FALSE)
  f
}

# ...and the flags themselves, which are additionally capped in NUMBER
.apiSafeFlags <- function(flags, work, name) {
  if (is.null(flags) || !length(flags)) return(NULL)
  f <- .apiSafeText(flags, work, name)
  if (length(f) > .apiMaxFlags)
    f <- c(f[seq_len(.apiMaxFlags)],
           sprintf("...%d further flag(s) truncated", length(f) - .apiMaxFlags))
  f
}

.apiTokens <- function()
  trimws(strsplit(Sys.getenv("INTEGRITY_API_TOKENS", ""), ",")[[1]])

# Token issuance (Steve's design, 2026-08-26): the operator's registry
# - a PRIVATE repository - stores only SHA-256 HASHES, and the service
# env carries them as "sha256:<hex>" entries, so no live token is
# recorded anywhere after the moment of issuance. Plaintext entries
# keep working for local testing. tools/issueApiToken.R is the
# issuing mechanism (public, like every mechanism here; the DATA is
# what stays private).
.apiAuthorized <- function(authHeader) {
  toks <- .apiTokens()
  toks <- toks[nzchar(toks)]
  if (length(toks) == 0) return(FALSE)
  if (is.null(authHeader) || !nzchar(authHeader)) return(FALSE)
  supplied <- sub("(?i)^\\s*Bearer\\s+", "", authHeader, perl = TRUE)
  if (!nzchar(supplied)) return(FALSE)
  # hashed entries authorize ONLY via the hash of what the caller
  # presents - never by literal match, or the registry's hashes would
  # themselves be credentials and the whole design would be theater
  plain  <- toks[!startsWith(toks, "sha256:")]
  hashed <- paste0("sha256:", digest::digest(supplied, algo = "sha256",
                                             serialize = FALSE))
  supplied %in% plain || hashed %in% toks
}

# The request-size ceiling. Defined here (not only in plumber.R) so the
# verdict function and its tests share one number.
.apiMaxBytes <- 26214400L   # 25 MiB

# The request-size verdict, as a pure function so every branch is
# testable without driving HTTP (the re-review's point: the tripwire and
# tests pinned that the filter EXISTS, not that it decides correctly).
# The plumber filter in inst/api/plumber.R is a thin wrapper over this.
#   "ok"        - forward
#   "no_length" - 411: a POST without Content-Length (chunked), which
#                 would otherwise bypass the cap entirely
#   "too_large" - 413
.apiSizeVerdict <- function(method, contentLength,
                            maxBytes = .apiMaxBytes) {
  cl <- if (is.null(contentLength) || !nzchar(as.character(contentLength)))
    NA_real_ else suppressWarnings(as.numeric(contentLength))
  if (identical(toupper(as.character(method)), "POST") && is.na(cl))
    return("no_length")
  if (!is.na(cl) && cl > maxBytes) return("too_large")
  "ok"
}

# Neutralize spreadsheet formula injection (security review M5,
# 2026-08-26): a manuscript row label like =HYPERLINK(...) or
# =cmd|'/c ...'!A1 round-trips through write.csv verbatim and executes
# when the editor - the intended human consumer - opens the CSV in
# Excel or Sheets. A leading apostrophe forces text interpretation in
# every spreadsheet app. Applied to character cells only; numbers are
# untouched. (The app's xlsx writer has the analogous property; the
# guide's "cannot smuggle formulas" claim now holds on the CSV surface
# too.)
.apiCsvSafe <- function(data) {
  # the dash must sit LAST in the class or it reads as a range (TRE:
  # "Invalid character range") - found by the test, 2026-08-26
  danger <- "^[=+@\t\r-]"
  guard <- function(x) {
    hit <- !is.na(x) & nzchar(x) & grepl(danger, x)
    if (any(hit)) x[hit] <- paste0("'", x[hit])
    x
  }
  for (nm in names(data)) {
    v <- data[[nm]]
    if (is.character(v)) data[[nm]] <- guard(v)
  }
  # COLUMN NAMES TOO (2026-08-27), as DEFENCE IN DEPTH - not because a
  # live path is known to reach here.
  #
  # The rationale first written here was WRONG and is corrected in
  # place rather than deleted, because the wrong version is the more
  # instructive one. It claimed the journal table's headers are arm
  # names parsed from the manuscript, hence attacker text. They are
  # not: buildBaselineTables (baselineTable.R:127) builds them
  # POSITIONALLY - "Arm 1 (n = 15)" - from an index and a number, so no
  # manuscript string reaches names() by that route.
  #
  # The guard stays anyway. write.csv emits names() as the header row,
  # nothing structural stops a future caller handing this function a
  # frame whose names DID come from an upload, and the cost is one
  # apostrophe. What changed is the claim: this is a cheap barrier
  # against a plausible future path, not the closing of an open hole.
  # (Re-screen finding F3, after the first version of this comment
  # survived into the tripwire and a test and had to be chased down in
  # three places.)
  names(data) <- guard(names(data))
  data
}

# The template CSV: the exact column layout validateData() accepts, so
# the failure payload is - by construction - valid input to the next
# call (the round-trip contract). Category columns ride after the base
# columns, as everywhere else.
.apiTemplateCsv <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    data <- as.data.frame(setNames(
      rep(list(character(0)), length(.ppBaseColumns())), .ppBaseColumns()))
  }
  # COLUMNS BY POSITION, NOT BY NAME (outside security audit 2026-09-10,
  # S1). A sheet carrying the SAME header twice - N and N - passed the
  # reader (check.names = FALSE) and was rightly refused by the validator
  # as ambiguous; but this serializer, choosing columns with intersect()
  # and setdiff() on names, kept one of the pair, so the 422's own
  # template had resolved the ambiguity the caller was asked to resolve,
  # and an unchanged resubmission analysed the FIRST N with a 200. Every
  # column and every header survive now, base columns first in their
  # order and everything else in the order received; an ambiguous sheet
  # stays ambiguous on the way back.
  nm <- names(data)
  basePos <- unlist(lapply(.ppBaseColumns(), function(b) which(nm == b)), use.names = FALSE)
  pos <- c(basePos, setdiff(seq_along(nm), basePos))
  data <- data[, pos, drop = FALSE]
  names(data) <- nm[pos]            # `[.data.frame` would have made the pair N and N.1
  # The value columns carry their declared precision as text
  # (.iaValueColumnsAsText, 2026-09-08). This payload is the round trip -
  # a caller POSTs it straight back - so a mean of 50.0 must not come
  # back as 50 and be re-analysed at a coarser grid than it was.
  data <- .iaValueColumnsAsText(data)
  con <- textConnection("out", "w", local = TRUE)
  # NOT .apiCsvSafe here: templateCsv is the ROUND-TRIP payload, and the
  # contract (issue 1) is that a caller can POST it straight back. An
  # apostrophe prefix would silently RENAME a variable - "-Mean change"
  # returns as "'-Mean change" - so the next call would analyze a
  # different table. Verified 2026-08-26; caught by the review question
  # before it shipped. Machine payload stays verbatim; the human-facing
  # results CSV is where sanitizing belongs (.apiResultsCsv).
  utils::write.csv(data, con, row.names = FALSE, na = "")
  close(con)
  paste0(paste(out, collapse = "\n"), "\n")
}

# The results CSV, sanitized the same way (M5): row labels parsed from
# the manuscript ride into it too, and it is the file an editor opens.
.apiResultsCsv <- function(results) {
  con <- textConnection("out", "w", local = TRUE)
  utils::write.csv(.apiCsvSafe(results), con, row.names = FALSE, na = "")
  close(con)
  paste0(paste(out, collapse = "\n"), "\n")
}

# Upper bounds on an /analyze payload (security review H2): the Monte
# Carlo escalates a homogeneous-looking row to 100k replicates, so a
# large crafted table can pin the single-threaded service for minutes.
# These are far above any real baseline table (Carlisle's largest
# trials are tens of variables x a handful of arms) and reject abuse
# 422 before any simulation runs.
.apiMaxTrials <- 200L
.apiMaxRows   <- 5000L
# Rows and trials are NOT the only ways to make the Monte Carlo huge
# (found by the hardening re-review, 2026-08-26): P_Calc allocates
# rnorm(N * chunk) per simulated row, so a two-row table declaring
# N = 1e9 passes a row gate and then asks for gigabytes. Category
# variables allocate r2dtable over the category COLUMNS, so a table
# that is short but very wide is the same attack. Both are capped.
# The ceiling is .iaMaxArmN subjects per arm - 5,000 - and the reason is editorial
# rather than computational (Steve, 2026-08-27):
#
#   "A 10,000 patient randomized controlled trial is huge. It is
#    expensive, likely funded by a major pharmaceutical company or a
#    government entity. The study would be audited extensively. There
#    would be lots of statistical review prior to manuscript
#    submission... enormous trials like that don't need independent
#    screens for fraud."
#
# That is a better justification than the arithmetic one it replaced
# (100,000, chosen only as "far above any real trial"). A limit
# defended by what the tool is FOR survives review; a limit defended by
# a round number invites someone to raise it because a caller asked.
#
# It is NOT, by itself, a fix for the compute-product problem below.
# Measured at the 5,000-row ceiling with every row escalating, the
# worst case falls from 5.7 days to 0.6 days - ten times better and
# still far past any timeout. The draw budget still does that work.
.apiMaxN    <- .iaMaxArmN   # one number, defined in app_globals.R
.apiMaxCols <- 200L

# ...and the four limits above are still not enough, because they are
# checked INDEPENDENTLY while the Monte Carlo cost is their PRODUCT
# (screen finding F4, 2026-08-27 - the same shape as the journal-table
# amplification: every gate passes, the product is catastrophic).
#
# Both P_Calc branches chunk by 1e8/N, which bounds per-chunk MEMORY
# but not total work: one replicate of one row draws sum(N) over its
# arms, so the request costs replicates x sum(N) draws. Measured at
# 1.01e8 draws/sec:
#
#   one row, N = 100,000, 100,000 replicates    1.0e10 draws    199 sec
#   the gate maxima, 5,000 rows x N = 100,000   1.0e14 draws    12 days
#
# A SINGLE row at the permitted maximum already exceeds the request
# timeout on a single-threaded service. And it is reachable on purpose,
# not a corner: the staged scheme escalates to 100,000 replicates
# precisely on HOMOGENEOUS rows, which the submitter produces by making
# arm means near-identical.
#
# The budget is expressed in draws so the reasoning stays visible. At
# ~1e8 draws/sec, 6e9 draws is about a minute of simulation - inside a
# typical request timeout with room to spare, and far above any real
# baseline table (a 25-variable, 2-arm trial with N = 500 per arm comes
# to 25,000 x 1e5 = 2.5e9... which is why the ceiling is not tighter).
#
# RAISED from 6e9 to 1.2e10 on 2026-08-27. The first value was set from
# the attack side alone and was too tight from the other: it refused a
# 20-variable trial above N = 1,500 per arm, and a 30-variable trial
# above N = 1,000. Carlisle's corpus is full of trials in the
# thousands, so the deployed service was refusing ordinary work. Found
# when Steve asked whether capping N would solve the compute problem -
# the question sent me back to the numbers, and the numbers were about
# the wrong risk.
#
# This is the knob the decision below explicitly names, used exactly as
# it says: the ceiling proved too tight, so the ceiling moved. What did
# NOT move is what the service does when it hits it.
#
# The gap is that this bounds the WORST case, where every row escalates
# to the replicate ceiling, and the typical case is cheaper because rows
# stop before it. Since the 0.1 escalation (2026-09-05) a trial advances
# to 10,000 replicates whenever any row's mid-p is below 0.1 - for a
# 25-row honest trial, about 93% of the time - so the typical case is
# ~10x cheaper than the worst, not ~100x as it was under the 0.01 rule:
#
#   25 variables, N = 10,000/arm   typical ~50 sec   worst case 495 sec
#
# WHAT 1.2e10 ACTUALLY BUYS - corrected 2026-08-28 (screen F3). This
# comment used to say "about two minutes", from a measured 1.01e8
# draws/sec. That figure benchmarked dqrnorm IN ISOLATION, which is not
# what the loop runs. Re-measured against the exact body of
# P_Calc.R:334-346 - dqrnorm, then rnorm with a VECTORISED mean, then
# round/rowmeans/round/rowsums around it:
#
#     dqrnorm alone (the wrong benchmark)        7.6e7 draws/sec
#     rnorm with a vectorised mean               2.0e7 draws/sec
#     the full continuous loop body              1.0e7 draws/sec
#
# So the budget is ~20 MINUTES of worst-case CPU, not two. The
# median/IQR branch is dearer still (metalog: dqrunif, log, arithmetic,
# rowMedians) and, since its scale draw of 2026-09-07 resamples every
# arm (and row-sorts the resample) before simulating it, runs at 2.5 to
# 2.8 times the continuous loop's cost per subject-draw (screen
# 2026-09-07-1059, measured on fully escalating rows at 10, 50 and 5,000
# per arm: 2.7e6 to 3.6e6 against 6.9e6 to 9.9e6; an earlier screen's
# factor of two did not reproduce). .apiDrawWork therefore counts a
# median line at THREE times its N - the ratio, not the absolute rate,
# is what survives a change of host - so the 20-minute worst case holds
# on that path as well.
#
# THE BUDGET IS NOT LOWERED TO MATCH THE OLD CLAIM, and the reason
# belongs here rather than in a commit message. Two minutes of worst
# case is 1.2e9 draws, which at 25 variables x 2 arms would refuse any
# trial above N = 240 - useless. The number stays; the CLAIM is what
# was wrong.
#
# What makes 20 minutes tolerable is that the worst case assumes EVERY
# row escalates to the replicate ceiling, and the staged scheme stops
# unremarkable trials at 10,000 (1,000 when no row is below 0.1). A
# real trial at this budget costs a minute or two, not 20 minutes (it
# was about 12 seconds under the 0.01 rule). The worst case is reached only by a table
# engineered so every row looks alarming - which is also, uncomfortably,
# what a fabricated table looks like.
#
# That is the honest argument for ISSUES.md issue 26 (submit-and-poll):
# a synchronous request cannot both admit real trials and promise a
# bounded response time, and the more suspicious the data, the longer
# it takes.
#
# WHAT THIS TRADE-OFF CANNOT SOLVE, and why the number is not simply
# larger: the rows that escalate are the SUSPICIOUS ones, so the worst
# case is a fraudulent-looking mega-trial - exactly the submission most
# worth analysing. No synchronous budget both admits that and bounds
# request time; the honest fix is an asynchronous submit-and-poll API
# (ISSUES.md issue 26). Until then a very large trial is refused here
# and analysed in the app, which has no request timeout.
#
# ---------------------------------------------------------------------
# A REFUSAL, NOT A REPLICATE REDUCTION - SETTLED, not a default.
#
# Dropping to 10,000 replicates would keep large submissions working
# while lowering the precision of a fraud verdict. A caller who is
# refused can split the submission by trial; a caller handed a coarser
# p-value does not know to.
#
# Put to Steve as an open question when this gate was written, because
# it is a statistical judgment rather than a security one, and the
# alternative was defensible: a DISCLOSED reduction ("analyzed at
# 10,000 replicates; p reported as < 1e-4") tells the caller what they
# got, so the objection to a SILENT reduction would not apply to it.
#
# Steve's decision, 2026-08-27: "Keep the refusal - a coarser p-value is
# worse than a refusal." The reasoning behind it is the tool's purpose:
# these p-values are used to question whether someone's data are real,
# and a number carrying less evidence than the reader assumes is more
# dangerous than no number at all. Disclosure in a JSON field does not
# fix that, because the p-value travels onward - into an email, an
# editorial decision, a conversation with an author - long after the
# field that qualified it has been left behind.
#
# So do not "improve" this into an adaptive reduction later. Widening
# .apiMaxDrawBudget is the supported knob if the ceiling proves too
# tight in practice.
.apiMaxDrawBudget <- 1.2e10
.apiReplicateCeiling <- 100000    # the global m in app_globals.R

# The worst-case simulation cost of a payload, in drawn values: every
# line contributes its N to one replicate, and the staged scheme can
# escalate any row to the ceiling. Pure and separate so the bound is
# testable directly - the journal-cell bound's first test went through
# .apiAnalyze, where validateData rejected the fixture before the code
# under test ran, and passed while testing nothing (2026-08-27).
#
# Worst case, not expected case: most rows stop early. A gate has to
# bound what an adversary can force, and an adversary picks the input
# that escalates every row.
# NORMALISE THE NAMES BEFORE GATING - via the SHARED rule set.
#
# The gates must read the frame validateData will actually see. The
# 2026-08-28 fix wrote a SECOND normalizer here that matched a subset of
# validateData's rules, and the overnight screen found every missed rule
# was a bypass: a label column named "ROWS" zeroed the categorical
# budget term (F1), and NUMBER+N together made the gate read N=1 while
# P_Calc got N=5000 (F2). Both are now impossible by construction -
# there is one implementation, in app_globals.R, and both callers use
# it.
#
# Duplicate names after normalizing are REFUSED rather than resolved:
# R's $ takes the first silently, so the gate and the simulator can
# otherwise mean different columns.
# ...and the long categorical layout converted, so the categorical work
# gate counts the level columns the validator will build (an unconverted
# long frame has NO category columns and its counts sit in N, which the
# gate would score as continuous work: an under-count, which is the
# unsafe direction).
.apiNormalizeNames <- function(DATA) .iaLongToWide(.iaNormalizeNames(DATA))

# Which columns look like category columns, on the RAW frame - the gate
# runs before validateData has computed CategoryNames, so it has to
# make the same judgement itself. Anything that is not a base column
# and holds a number is a candidate; over-counting here is safe (it
# only makes the budget stricter), under-counting is not.
.apiCategoryGuess <- function(DATA) {
  if (is.null(DATA) || !length(names(DATA))) return(character(0))
  base <- c(.ppBaseColumns(), "GROUP", "DECM", "DECSD", "MEASURE", "NUMBER")
  cand <- setdiff(names(DATA), base)
  cand[vapply(cand, function(k)
    is.numeric(DATA[[k]]) || all(is.na(DATA[[k]])) ||
      !any(is.na(suppressWarnings(as.numeric(
        DATA[[k]][!is.na(DATA[[k]])])))), logical(1))]
}

.apiDrawWork <- function(DATA, categoryNames = NULL) {
  if (is.null(DATA) || nrow(DATA) == 0) return(0)

  # CONTINUOUS / MEDIAN work: one replicate of one row draws sum(N)
  # over its arms.
  cont <- 0
  if ("N" %in% names(DATA)) {
    n <- suppressWarnings(as.numeric(DATA$N))
    # a median/IQR line costs about 2.5 to 2.8 times its N per replicate
    # since the scale draw of 2026-09-07 resamples and row-sorts every
    # arm before it simulates it (screens 2026-09-07-1036 and -1059; the
    # weight is the measured ratio rounded up, see the budget's note)
    w <- rep(1, length(n))
    for (q in intersect(c("Q1", "Q3"), names(DATA)))
      w[is.finite(suppressWarnings(as.numeric(DATA[[q]])))] <- 3
    ok <- is.finite(n) & n > 0
    if (any(ok)) cont <- sum(n[ok] * w[ok])
  }

  # CATEGORICAL work, missing entirely until the 2026-08-28 screen (F1)
  # and missing STRUCTURALLY rather than by oversight. P_Calc has THREE
  # branches, not the two this function's comment described. The third
  # simulates a contingency table with r2dtable, whose cost is driven by
  # arms x categories and NOT by N at all - and validateData REQUIRES
  # that any line carrying a category value has N = NA, so every row
  # that reaches it is one the continuous term above drops. A wholly
  # categorical payload therefore scored zero and the budget refused
  # nothing, on a path that allocates unchunked.
  #
  # Worse, the test written to document careful NA handling -
  #   expect_identical(.apiDrawWork(data.frame(N = c(NA, -5, 0))), 0)
  # - pinned that hole as INTENDED BEHAVIOUR. A test can encode a bug
  # as a guarantee, and this one did.
  #
  # Cost per replicate is the table's cell count: lines x populated
  # categories, per TRIAL x ROW group, which is the unit P_Calc builds
  # a table for.
  cat_ <- 0
  have <- intersect(categoryNames, names(DATA))
  if (length(have) && all(c("TRIAL", "ROW") %in% names(DATA))) {
    M <- as.matrix(DATA[, have, drop = FALSE])
    populated <- !is.na(M)
    rowsWithCat <- rowSums(populated) > 0
    if (any(rowsWithCat)) {
      grp <- paste(DATA$TRIAL, DATA$ROW)[rowsWithCat]
      pc  <- populated[rowsWithCat, , drop = FALSE]
      for (g in unique(grp)) {
        sel <- grp == g
        nCats <- sum(colSums(pc[sel, , drop = FALSE]) > 0)
        cat_ <- cat_ + sum(sel) * nCats
      }
    }
  }
  (cont + cat_) * .apiReplicateCeiling
}
# The journal-style tables expand one line per populated category
# column, so their size is NOT bounded by the input gates above. This
# caps the estimated emitted cells; a real baseline table is a few
# hundred (tens of variables x a handful of arms), so 200,000 is far
# above any honest document and far below anything that hurts.
.apiMaxJournalCells <- .iaMaxJournalCells   # one limit, shared with the app (screen 2026-09-10-1143)

# Estimate the size of the journal-style tables WITHOUT building them -
# a pure function so the bound is testable directly rather than through
# validateData, which rejects most synthetic wide tables before the
# journal logic is ever reached.
#
# The expansion driver: buildBaselineTables emits one line per
# populated category column for every categorical variable, plus one
# line per other row. Rows carrying any category value are the ones
# that can expand.
#
# WHAT THIS COUNTS, precisely (2026-08-27 screen, finding F1): LINES,
# not cells. The emitted table is `Variable` plus one column per arm,
# so the true cell count is lines x (1 + maxArms). The screen argued
# this under-bounds by a maxArms factor. It does not, and the reason is
# worth recording: nrow(DATA) is variables x arms, so the arm
# multiplicity is ALREADY in the count, and the only shortfall is the
# constant Variable column. Measured against buildBaselineTables:
#
#     arms      2      5     10     25     50
#     actual/estimate  1.50   1.20   1.10   1.04   1.02
#
# The ratio FALLS toward 1 as arms grow - the opposite of the claim.
# Worst case is few arms, ~1.5x, and 1.33x when categories widen. A
# bounded 1.5x against a 200,000 threshold is a few MB, so the estimate
# is fit for bounding an explosion; it is not, and does not claim to
# be, an exact cell count.
#
# SUPERSEDED IN ONE RESPECT (screen 2026-09-10-1143, F1): the argument
# above holds for a table whose lines belong to distinct variables. Lines
# that SHARE a ROW name become columns, and every other line pays for
# that width in blank cells - a 5,000-line upload with 2,499 lines named
# "A" built 6.25 million cells against an estimate of 5,000. The estimate
# now multiplies by the width (.iaJournalCells in app_globals.R, shared
# with the app's downloads); this name stays for the callers and tests.
.apiJournalCells <- function(DATA, categoryNames) .iaJournalCells(DATA, categoryNames)

# A spreadsheet decompression bomb (security review H3): .xlsx and .xls
# are zips, so a 25 MB upload (the H1 request cap) can inflate to
# gigabytes when openxlsx unzips it in-process and hang the
# single-threaded service. The zip's own central directory declares
# each entry's UNCOMPRESSED size, readable in milliseconds WITHOUT
# extracting, so a bomb is rejected before a byte is inflated. A
# legitimate baseline-table workbook is well under the cap.
.apiMaxUncompressed <- 104857600   # 100 MiB declared, total
.apiMaxZipEntries   <- 512L        # a workbook has tens, not thousands
.apiMaxZipRatio     <- 200         # compression ratio ceiling: AGGREGATE declared
                                   # uncompressed bytes over the archive's size, not
                                   # per entry (the comment said per-entry; the code
                                   # never was - security audit 2026-09-10)

.apiZipInflationOK <- function(path, ext = tools::file_ext(path)) {
  ext <- tolower(ext)
  # csv is not an archive - nothing to preflight
  if (ext == "csv") return(TRUE)
  info <- tryCatch(utils::unzip(path, list = TRUE), error = function(e) NULL)
  if (is.null(info) || !nrow(info)) {
    # Not readable as a zip. .xlsx MUST be one, so an unreadable .xlsx is
    # refused rather than passed to openxlsx (the re-review found this
    # branch FALLING OPEN, 2026-08-26). .xls is OLE2 rather than zip, so
    # it legitimately lands here; bound it by file size instead, since
    # there is no directory to inspect.
    if (ext == "xlsx") return(FALSE)
    return(file.size(path) <= .apiMaxBytesOnDisk)
  }
  if (nrow(info) > .apiMaxZipEntries) return(FALSE)
  declared <- sum(info$Length, na.rm = TRUE)
  if (declared > .apiMaxUncompressed) return(FALSE)
  # The declared sizes are attacker-controlled, so ALSO bound the
  # inflation ratio against the real file size on disk: a directory that
  # under-declares while the stream over-inflates still cannot claim a
  # plausible ratio (re-review, H3).
  onDisk <- max(file.size(path), 1)
  declared / onDisk <= .apiMaxZipRatio
}

# The on-disk ceiling for a non-zip spreadsheet (.xls, no longer accepted) - the request
# filter already caps the upload, this is defense in depth for direct
# callers of the helper.
.apiMaxBytesOnDisk <- 26214400L

# Read one uploaded file into template-layout rows. PDFs, Word
# manuscripts, JATS XML and table images go through the subprocess
# batcher; spreadsheets are read in-process after a decompression-bomb
# preflight.
#
# JATS XML joined the list on 2026-09-03 (Steve: "XML through the API
# will become the preferred route for screening manuscripts for research
# fraud" - it is what an editorial system holds before any PDF exists).
# It takes the same road as a PDF: the child process, the OS timeout, the
# 25 MiB request cap, and libxml2's own defences - the tripwire bans the
# options (HUGE, NOENT, DTDLOAD) that would switch them off, so an
# entity bomb or an external-entity read in a hostile submission stays a
# parse error inside the child (issue 29; tools/securityCheck.R group 1).
.apiReadUpload <- function(path, name, apiKey = NULL) {
  ext <- tolower(tools::file_ext(name))
  stem <- tools::file_path_sans_ext(basename(name))
  if (ext %in% c("pdf", "docx", "xml", .ppImageExts)) {
    # A table image is preflighted from its header - our own bounded
    # parser, no decoder - before a child process is spent on it; the
    # engine repeats the check, so this gate is defence in depth
    # (2026-09-02; see utils.R).
    if (ext %in% .ppImageExts) {
      ok <- .ppImageOK(path)
      if (!isTRUE(ok))
        return(list(ok = FALSE,
                    reasons = paste0(name, " was not read: ",
                                     attr(ok, "reason"), "."),
                    data = NULL, skipped = NULL, flags = character(0),
                    engine = NA_character_))
    }
    # A JATS file likewise: size ceiling and gzip magic judged here, so
    # a caller gets the reason as a 422 rather than a child that died
    # (screen of PR #162, F1); the reader repeats the check.
    if (ext == "xml") {
      ok <- .ppJatsOK(path)
      if (!isTRUE(ok))
        return(list(ok = FALSE,
                    reasons = paste0(name, " was not read: ",
                                     attr(ok, "reason"), "."),
                    data = NULL, skipped = NULL, flags = character(0),
                    engine = NA_character_))
    }
    aiOn <- !is.null(apiKey) && nzchar(apiKey)
    # pctApprox = TRUE: a percent-only cell whose percentage fits several
    # counts is filled with the end of its bracket that leaves the arms
    # least alike - the fail-safe choice the app makes too (Steve,
    # 2026-09-07) - and the flags name the rows on BOTH routes (see the
    # API guide, "Incomplete data"; /analyze carried the p without them
    # until security screen 2026-09-07-1609, finding F2)
    res <- parseBaselineTableFiles(
      path, ai = if (aiOn) "fallback" else "never",
      timeout = if (aiOn) 300 else 60,
      quiet = TRUE, pctApprox = TRUE, apiKey = if (aiOn) apiKey else NULL)
    r <- res$result[[1]]
    if (is.null(r) || nrow(r$data) == 0) {
      msg <- res$error[1]
      if (!is.null(apiKey) && nzchar(apiKey))
        msg <- gsub(apiKey, "<key>", msg, fixed = TRUE)
      msg <- gsub(path, name, msg, fixed = TRUE)
      return(list(ok = FALSE, reasons = msg, data = NULL,
                  skipped = NULL, flags = character(0),
                  engine = NA_character_))
    }
    d <- r$data
    d$TRIAL <- stem
    list(ok = TRUE, data = d,
         skipped = if (nrow(r$skipped)) r$skipped else NULL,
         flags = r$flags %||% character(0),
         engine = r$engine)
  } else if (ext == "xls") {
    # dropped 2026-09-06 (security screen 2026-09-05-2117 F3): see .wideRawCells
    list(ok = FALSE, reasons = paste0(name, ": ", .iaXlsMessage()),
         data = NULL, skipped = NULL, flags = character(0), engine = NA_character_)
  } else if (ext %in% c("csv", "xlsx")) {
    # Decompression-bomb preflight before any in-process read (H3).
    if (!.apiZipInflationOK(path, ext))
      return(list(ok = FALSE,
                  reasons = paste0(name, " expands to more than the ",
                                   round(.apiMaxUncompressed / 1024^2),
                                   " MB limit when decompressed and was ",
                                   "not read."),
                  data = NULL, skipped = NULL, flags = character(0),
                  engine = NA_character_))
    # THE SHEET-COUNT REFUSAL HOLDS ON EVERY ROUTE (security audit
    # 2026-09-10, S5). The wide reader refuses a workbook of more than
    # .iaSheetCountCap sheets before reading one (screen 2026-09-05-2117
    # F2) - but its error was caught below and the template fallback then
    # read the first sheet anyway, so an eleven-sheet workbook came back
    # 200 through /parse. The count is checked here, once, before either
    # reader; a workbook that cannot even be opened falls through to the
    # readers' own "could not read".
    if (ext == "xlsx") {
      nSheets <- tryCatch(length(openxlsx::getSheetNames(path)), error = function(e) NA_integer_)
      if (!is.na(nSheets) && nSheets > .iaSheetCountCap)
        return(list(ok = FALSE,
                    reasons = paste0(name, " has more than ", .iaSheetCountCap,
                                     " sheets and was not read"),
                    data = NULL, skipped = NULL, flags = character(0),
                    engine = NA_character_))
    }
    # A journal-style table the wide reader refuses for size (screen
    # 2026-09-10-1628, F1) is a refusal with the reason, not a fall-through
    # to the template reader: the same sheet would cost the same there.
    # A CSV is gated ONCE, here, before either reader (screen 2026-09-10-1856,
    # F2): a line over .iaCsvMaxLineBytes among the first five (read.csv is
    # quadratic in it), or more columns than the sheet cap. Inside the readers
    # the same refusal was an error the fallback swallowed, so the caller saw
    # "could not read" with no reason.
    if (ext == "csv") {
      msg <- .iaCsvRefusal(path)
      if (!is.null(msg))
        return(list(ok = FALSE, reasons = paste0(name, ": ", msg),
                    data = NULL, skipped = NULL, flags = character(0),
                    engine = NA_character_))
    }
    wide <- tryCatch(parseWideTable(path, ext),
                     iaWideTooLarge = function(e) e, error = function(e) NULL)
    if (inherits(wide, "iaWideTooLarge"))
      return(list(ok = FALSE, reasons = paste0(name, ": ", conditionMessage(wide)),
                  data = NULL, skipped = NULL, flags = character(0),
                  engine = NA_character_))
    if (!is.null(wide)) {
      # The blocks are folded pairwise (security screen 2026-09-10-1554,
      # F2). .ppRbindFill() takes exactly two frames, and do.call() handed
      # it the whole list as arguments: one block (a one-trial journal-
      # style sheet, the most ordinary input) raised 'argument "b" is
      # missing' and three or more raised 'unused argument', neither
      # caught by the handlers - a 500 for every wide upload but a two-
      # trial one, since the API's first commit. The blocks are joined on
      # the union of their columns in ONE rbind, as the app joins files
      # (screen 2026-09-10-1628, F1: a pairwise fold copies the whole
      # accumulated frame at every step - cubic in the blocks); the reader
      # has already bounded the lines and the width.
      d <- .ppRbindFillAll(lapply(wide, function(b) {
        bd <- b$data
        # the trial column by the normaliser's rule, whatever its case
        # (audit 2026-09-10 F4); filled from the file name only when the
        # block carries none, or an empty one
        tr <- .iaTrialColumn(bd)
        if (is.na(tr)) tr <- "TRIAL"
        if (is.null(bd[[tr]]) || all(is.na(bd[[tr]])))
          bd[[tr]] <- if (is.null(b$trial) || is.na(b$trial)) stem else b$trial
        bd
      }))
      # the wide branch's frame is bounded before anything is written back,
      # as the template branch's is (screen 2026-09-10-2149, F1)
      msg <- .iaTableTextRefusal(d)
      if (!is.null(msg))
        return(list(ok = FALSE, reasons = paste0(name, ": ", msg),
                    data = NULL, skipped = NULL, flags = character(0),
                    engine = NA_character_))
      return(list(ok = TRUE, data = d, skipped = NULL,
                  flags = character(0), engine = "wide"))
    }
    d <- tryCatch({
      # bounded like .wideRawCells (the sparse-sheet expansion, 2026-09-05)
      if (ext == "csv") {
        msg <- .iaCsvRefusal(path)          # a long line or too many columns (screen 1856 F2)
        if (!is.null(msg)) stop(msg)
        # THE VALUE COLUMNS ARE READ AS TEXT (independent audit 2026-09-09, F5).
        # read.csv() coerces "50.000" to the double 50 before the validator can
        # count its trailing zeros, so the precision the spreadsheet route now
        # preserves was still destroyed on the comma-separated one: the same
        # table read 3 and 2 decimals as text and 0 and 0 as a CSV, and the p
        # moved from 0.0047 to 0.35. Only the value columns are held as text -
        # validateData() coerces those itself and reads their digits first,
        # while N, the counts and every other column must stay numeric or
        # is_category() stops seeing a count column. Reading them as text also
        # stops a trial named "T" becoming the logical TRUE.
        .iaReadCsvKeepingText(path, check.names = FALSE,
                              nrows = .iaSheetRowCap + 1L)
      } else {
        openxlsx::read.xlsx(path, rows = seq_len(.iaSheetRowCap + 1L),
                            cols = seq_len(.iaSheetColCap + 1L))
      }
    }, error = function(e) NULL)
    if (!is.null(d) && (nrow(d) > .iaSheetRowCap || ncol(d) > .iaSheetColCap)) d <- NULL
    if (is.null(d) || nrow(d) == 0)
      return(list(ok = FALSE,
                  reasons = paste0("could not read ", name,
                                   " as a template or journal-style table"),
                  data = NULL, skipped = NULL, flags = character(0),
                  engine = NA_character_))
    # A trial column of ANY case counts (independent audit 2026-09-10,
    # F4): testing for the exact spelling "TRIAL" here, before the
    # normaliser upper-cases the names, gave a file with a lower-case
    # `trial` column a second one from the file name, and validation
    # then refused the pair as duplicates. The rule is the normaliser's
    # own, .iaTrialColumn(), so the reader and the gate cannot disagree.
    # ...and a trial column that is present but BLANK in every cell is
    # filled the same way, exactly as the wide path above does (screen
    # 2026-09-10-1119, F1): the two readers written in one commit
    # disagreed on an empty column, and an all-blank lower-case `trial`
    # header - which used to be refused as a duplicate - became a trial
    # called NA whose every row the engine reported as "No values" inside
    # an ok = TRUE response with no p at all.
    tr <- .iaTrialColumn(d)
    if (is.na(tr)) d$TRIAL <- stem
    else if (all(is.na(d[[tr]]) | !nzchar(trimws(as.character(d[[tr]])))))
      d[[tr]] <- stem
    # the template route's cells are bounded before anything is written
    # back (screen 2026-09-10-2047, F2)
    msg <- .iaTableTextRefusal(d)
    if (!is.null(msg))
      return(list(ok = FALSE, reasons = paste0(name, ": ", msg),
                  data = NULL, skipped = NULL, flags = character(0),
                  engine = NA_character_))
    list(ok = TRUE, data = d, skipped = NULL, flags = character(0),
         engine = "template")
  } else {
    list(ok = FALSE, reasons = paste0("unsupported file type: .", ext),
         data = NULL, skipped = NULL, flags = character(0),
         engine = NA_character_)
  }
}

# The /analyze pipeline after reading: validate, then Monte Carlo.
.apiAnalyze <- function(DATA, seed = NULL) {
  # THE FRAME AS RECEIVED is kept (screen 2026-09-10-1222, F2): a sheet
  # carrying both NUMBER and N collapses onto two columns named N once
  # normalised, the validator rightly refuses to guess which is meant -
  # and the 422's templateCsv, built from the normalised frame, silently
  # kept the FIRST and dropped the other, so a caller who re-posted the
  # round-trip payload got an analysis in which the service had chosen
  # for them. The validator now sees the raw headers (it normalises them
  # itself, by the same rule, so its note can name 'NUMBER' and 'N'
  # rather than 'N' and 'N'), and a structural refusal returns the frame
  # as received, both columns intact.
  received <- DATA
  # Gate a frame whose names mean what they say - see .apiNormalizeNames.
  # The long-layout converter inside it refuses a file whose levels would
  # need more count columns than the API admits (screen 2026-09-06-1749,
  # F1); that refusal is a 422 naming the stage, never a 500.
  DATA <- tryCatch(.apiNormalizeNames(DATA), error = function(e) e)
  if (inherits(DATA, "error"))
    return(list(ok = FALSE, stage = "validation",
                issues = data.frame(row = NA_integer_, col = NA_character_, code = "error",
                                    note = paste0("the table could not be read as a template: ",
                                                  conditionMessage(DATA)),
                                    stringsAsFactors = FALSE),
                templateCsv = .apiTemplateCsv(NULL)))
  # Size gate BEFORE any simulation (H2): a crafted oversized table
  # would otherwise run the escalating Monte Carlo on the single
  # service thread past App Runner's request timeout, orphaning work.
  nTrials <- length(unique(DATA$TRIAL))
  maxN <- suppressWarnings(max(as.numeric(DATA$N), na.rm = TRUE))
  if (!is.finite(maxN)) maxN <- 0
  tooBig <- nrow(DATA) > .apiMaxRows || nTrials > .apiMaxTrials ||
            maxN > .apiMaxN || ncol(DATA) > .apiMaxCols
  if (tooBig) {
    return(list(ok = FALSE, stage = "too_large",
                issues = data.frame(row = NA_integer_, col = NA_character_,
                  code = "too_large",
                  detail = paste0("table has ", nrow(DATA), " rows x ",
                    ncol(DATA), " columns across ", nTrials,
                    " trial(s), largest N ", format(maxN, scientific = FALSE),
                    "; the service accepts at most ", .apiMaxRows,
                    " rows, ", .apiMaxCols, " columns, ", .apiMaxTrials,
                    " trials, and N of ", .apiMaxN, " per arm."),
                  stringsAsFactors = FALSE),
                templateCsv = .apiTemplateCsv(NULL)))
  }
  # The COMPUTE PRODUCT (F4) - see .apiMaxDrawBudget. Every limit above
  # can pass while the simulation cost, replicates x sum(N), is days.
  # Computed on the RAW frame, before validateData, because refusing is
  # cheap and validating a 5,000-row table is not.
  drawWork <- .apiDrawWork(DATA, .apiCategoryGuess(DATA))
  if (drawWork > .apiMaxDrawBudget) {
    return(list(ok = FALSE, stage = "too_large",
                issues = data.frame(row = NA_integer_, col = NA_character_,
                  code = "too_much_compute",
                  detail = paste0(
                    "this table is within every individual limit, but the ",
                    "simulation it asks for is not: ", nrow(DATA),
                    " row(s) totalling ", format(sum(as.numeric(DATA$N),
                      na.rm = TRUE), big.mark = ",", scientific = FALSE),
                    " subjects would need about ",
                    format(signif(drawWork, 2), big.mark = ",",
                           scientific = FALSE),
                    " simulated values at full precision, above the ",
                    format(.apiMaxDrawBudget, big.mark = ",",
                           scientific = FALSE),
                    " this service allows in one request. If the ",
                    "submission holds several trials, send them one per ",
                    "request. If it is a SINGLE large trial, splitting ",
                    "it would change the result - its rows are combined ",
                    "into one p-value - so use the web app instead, ",
                    "which has no request timeout. The precision of the ",
                    "analysis is never reduced to fit: a coarser ",
                    "p-value you were not told about would be worse ",
                    "than this refusal."),
                  stringsAsFactors = FALSE),
                templateCsv = .apiTemplateCsv(NULL)))
  }
  # Defense in depth (screen 2026-09-06-0514 F1): an error the validator
  # or the engine did not foresee is a 422 naming the stage, never a 500
  v <- tryCatch(validateData(received), error = function(e)
    list(FAIL = TRUE, issues = data.frame(
      row = NA_integer_, col = NA_character_, code = "error",
      note = paste0("the table could not be validated: ", conditionMessage(e)),
      stringsAsFactors = FALSE)))
  if (isTRUE(v$FAIL)) {
    structural <- !is.null(v$issues) && any(v$issues$code == "structural")
    return(list(ok = FALSE, stage = "validation",
                issues = if (!is.null(v$issues)) v$issues else NULL,
                # a structural refusal returns the frame AS RECEIVED - the
                # normalised one has already chosen between duplicate
                # columns (screen 2026-09-10-1222, F2); a cell refusal
                # returns the normalised frame the issues index
                templateCsv = .apiTemplateCsv(
                  if (structural) received
                  else if (!is.null(v$DATA)) v$DATA else DATA)))
  }
  # the caller's seed (2026-09-05): set once, before the first trial, so
  # the same file, seed and build give the same numbers on any service
  if (!is.null(seed)) .iaSetSeed(seed)
  OUTPUT <- NULL
  for (TRIAL in v$TRIALS) {
    one <- tryCatch(P_Calc(TRIAL, v$DATA, v$CategoryNames, m, excluded = v$Excluded),
                    error = function(e) e)
    if (inherits(one, "error"))
      return(list(ok = FALSE, stage = "analysis",
                  issues = data.frame(row = NA_integer_, col = NA_character_, code = "error",
                                      note = paste0("trial ", TRIAL, " could not be analyzed: ",
                                                    conditionMessage(one)),
                                      stringsAsFactors = FALSE),
                  templateCsv = .apiTemplateCsv(v$DATA)))
    OUTPUT <- rbind(OUTPUT, one)
  }
  # per-trial summary p's, plus the overall Stouffer combination across
  # trials (the same closure the results workbook reports)
  # by KIND, never by the label: a variable named "Summary" is a variable
  # (GPT-6 audit F2, 2026-09-07)
  sm <- OUTPUT[!is.na(OUTPUT$KIND) & OUTPUT$KIND == "summary", , drop = FALSE]
  # "<0.0001" (the exact combination's licensed bound) combines as 1e-4
  # and passes through unchanged when it is the only trial
  trialP <- .trialPNumeric(sm$P)
  ok <- !is.na(trialP)
  overall <- if (sum(ok) > 1) signif(sumz(trialP[ok])$p, 4)
             else if (sum(ok) == 1) {
               if (grepl("^\\s*<", as.character(sm$P[ok]))) as.character(sm$P[ok]) else trialP[ok]
             } else NA_real_
  # The journal-style reconstructed table (issue 15) travels with the
  # response: for the editor email workflow it is the artifact compared
  # against the manuscript page, and returning it here saves a second
  # call. One CSV per trial, sanitized like every human-facing CSV
  # (these carry parsed row labels).
  # OUTPUT-SIZE BOUND (independent screen of this feature, 2026-08-27).
  # The /analyze gate bounds the INPUT - rows, columns, trials, N - but
  # journalTables is the one response element that expands SUPER-
  # LINEARLY: a categorical variable emits one line per populated
  # category column (see the CategoryNames loop in baselineTable.R), so
  # a legal table of 5,000 categorical rows x ~190 category columns
  # becomes ~950,000 emitted lines, and the labels are uncapped. That
  # turns a few-MB request into a multi-hundred-MB response, built and
  # then serialised again - a memory DoS on a single-threaded service.
  # tryCatch cannot save us there: a cgroup OOM kills the process, it
  # does not raise an R condition.
  #
  # So estimate the expansion from the validated frame BEFORE building
  # anything, and omit the tables (with a reason the caller can read)
  # rather than attempt them. Everything else in the response is O(input)
  # and unaffected.
  # the rows the validator left out (a label with no values) go back
  # to the caller in the template and the journal table, not only in the
  # Summary's count (audit 2026-09-10 F3): the template is the round
  # trip, and a row that vanished from it could not be corrected
  shown <- .iaWithExcluded(v$DATA, v$ExcludedRows)              # the template: every row
  # ...the journal table gets one blank line per label, and is estimated
  # WITH its width before it is built (screen 2026-09-10-1143, F1)
  shownJournal <- .iaWithExcluded(v$DATA, v$ExcludedRows, oneLinePerLabel = TRUE)
  journalCells <- .apiJournalCells(shownJournal, v$CategoryNames)
  journalSkipped <- journalCells > .apiMaxJournalCells

  journal <- if (journalSkipped) NULL else tryCatch({
    tabs <- buildBaselineTables(shownJournal, v$CategoryNames)
    lapply(tabs, function(tb) {
      con <- textConnection("jout", "w", local = TRUE)
      utils::write.csv(.apiCsvSafe(as.data.frame(tb, stringsAsFactors = FALSE)),
                       con, row.names = FALSE, na = "")
      close(con)
      paste0(paste(jout, collapse = "\n"), "\n")
    })
  }, error = function(e) NULL)

  list(ok = TRUE, stage = "analysis",
       results = OUTPUT, overallP = overall,
       trials = length(v$TRIALS),
       journalTables = journal,
       # say WHY they are absent rather than returning a bare null the
       # caller has to guess about
       journalTablesOmitted = if (journalSkipped) .iaJournalOmittedNote(journalCells) else NULL,
       templateCsv = .apiTemplateCsv(shown))
}

#' Run the IntegrityAnalysis REST service
#'
#' Starts the plumber API defined in `inst/api/plumber.R`. Endpoints:
#' `GET /health` (open); `POST /parse` and `POST /analyze` (bearer
#' token). Uploads are multipart (`file`); an `X-Anthropic-Key` header
#' turns on the per-request AI assist under the caller's own key
#' (issue 8's service side). Every upload is deleted when its request
#' ends, and the response says so - the retention contract of issue 1.
#'
#' @param port TCP port (default 8080, the AWS App Runner convention).
#' @param host bind address; `"0.0.0.0"` for containers.
#' @return Called for the side effect of running the server; blocks.
#' @export
runApiService <- function(port = 8080, host = "0.0.0.0") {
  if (!requireNamespace("plumber", quietly = TRUE))
    stop("The API service needs the 'plumber' package.")
  # The analysis stack expects these ATTACHED, exactly as run_app()
  # attaches them (P_Calc's %do%, dqrnorm, s.u, and Rfast matrix ops
  # resolve from the search path - the app_run.R list minus the Shiny
  # UI packages, which a REST service has no use for).
  suppressWarnings(suppressPackageStartupMessages({
    library(shiny)      # outputComments isolates; no UI is started
    library(openxlsx)
    library(Rfast)
    library(foreach)
    library(MBESS)
    library(dqrng)
  }))
  if (length(.apiTokens()) == 0)
    message("WARNING: INTEGRITY_API_TOKENS is empty - every /parse and ",
            "/analyze request will be refused 401. Set it to a ",
            "comma-separated token list before exposing the service.")
  # F1 of the repeat security screen (2026-09-06): plumber's own request
  # cap, applied by httpuv from the headers BEFORE the body is buffered,
  # was unset (0 = unlimited), so the sizelimit filter in plumber.R only
  # ever refused a body already resident in memory. Set here, before the
  # router is built, to the same 25 MiB the filter enforces: an oversized
  # Content-Length is now refused 413 with nothing buffered.
  options(plumber.maxRequestSize = .apiMaxBytes)
  pr <- plumber::pr(system.file("api", "plumber.R",
                                package = "IntegrityAnalysis"))
  # A fixed, contentless 500 (security review M6): plumber's default
  # error handler returns the R condition message, which can carry the
  # request tempdir path, column names, or fragments of upload content
  # to an arbitrary caller. Log internally, tell the caller nothing.
  pr <- plumber::pr_set_error(pr, function(req, res, err) {
    message("API error: ", conditionMessage(err))
    # Two errors arise inside plumber's own request parsing, before any
    # filter or handler can run (break test, 2026-09-06): a NUL byte in
    # the query string ("?seed=%00") fails decodeURIComponent with
    # "embedded nul", and a file part whose filename carries a quote and
    # a line break is dropped by the multipart parser, after which the
    # part list is indexed out of bounds. Both are the caller's malformed
    # request, not our failure: say 400, still without echoing anything.
    msg <- conditionMessage(err)
    if (grepl("embedded nul", msg, fixed = TRUE) ||
        grepl("subscript out of bounds", msg, fixed = TRUE)) {
      res$status <- 400
      return(list(ok = FALSE, error = paste(
        "Malformed request: a NUL byte in the query string, or a file part",
        "the multipart body could not carry (a quote or line break in the",
        "file name).")))
    }
    res$status <- 500
    list(ok = FALSE, error = "Internal error processing the request.")
  })
  plumber::pr_run(pr, host = host, port = port)
}
