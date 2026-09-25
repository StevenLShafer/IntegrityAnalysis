# armNRecovery.R - recover missing treatment-arm sizes deterministically.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-21 by Claude Code (model: Claude Fable 5) at Steve       #
# Shafer's request, after running all 654 A&A RCT submissions through the  #
# deterministic engine and through the AI engine separately and comparing: #
# the single largest deterministic deficit was the arm N. 583 skipped      #
# n (%) rows across the corpus were blocked ONLY on an unknown arm N, and  #
# the arm-N sets agreed with the AI reading on just 255 of 453 co-parsed   #
# files - while the Ns were nearly always printed somewhere: in the very   #
# n (%) cells being skipped, in the randomization sentence of the Methods, #
# or in the CONSORT flow labels.                                           #
#                                                                          #
# Everything here is deterministic - no AI service is called. Every        #
# recovered N is traceable: either to printed cells of the table itself    #
# (the count and its percentage bracket the arm size), or to a quoted      #
# sentence of the document, which is recorded and surfaced by              #
# reviewFlags() so a human can verify it against the CONSORT diagram.      #
# Status: run and verified by tests/testthat/test-armn-recovery.R and a    #
# full re-run of the 654-submission corpus.                                #
############################################################################

# --------------------------------------------------------------------------
# Source 1: the table's own n (%) cells
# --------------------------------------------------------------------------
# A printed cell "13 (68.4%)" pins the arm size tightly: the true proportion
# lies within half a printed unit of 68.4%, so N = 13/p can only be an
# integer in [13/0.6845, 13/0.6835] = {19}. One cell with a one-decimal
# percentage is usually conclusive; several cells of the same arm intersect
# to a unique N even at zero decimals. This uses nothing but the printed
# table, so it is the most trustworthy recovery and is tried first.

# Feasible arm sizes for one printed "count (pct%)" cell. `dec` is the
# number of printed decimals of the percentage - it decides the bracket
# width, exactly as ROUND_MEAN does for the Monte Carlo.
.ppNFromCountPct <- function(count, pct, dec) {
  if (is.na(count) || is.na(pct) || count <= 0 || pct <= 0 || pct > 100)
    return(integer(0))
  if (is.na(dec)) dec <- 0L
  half <- 0.5 * 10^(-dec)
  lo <- (pct - half) / 100
  hi <- (pct + half) / 100
  if (lo <= 0) return(integer(0))
  # IN DOUBLES, AND REFUSED BEFORE as.integer() (security screen
  # 2026-09-10-0858, F1). A cell printing "25000000 (0.01%)" implies an arm
  # of about 1.7e11; as.integer() of that is NA with a warning, and the
  # comparison below then raised "missing value where TRUE/FALSE needed".
  # On the JATS route the block parser's tryCatch swallowed the error and
  # the WHOLE document failed to parse with a message naming no cell; on
  # the PDF route the child returned the raw R error. Verified end to end
  # on ae37f0e with "30000 (0.001%)" as well. An implied arm size above
  # .iaMaxArmN can never be analysed - validateData() refuses the trial -
  # so the same rule applies here: the cell yields no arm size, the arm's
  # N stays unknown, and the rest of the table is read as it always was.
  nLoD <- ceiling(count / hi - 1e-9)
  nHiD <- floor(count / lo + 1e-9)
  # THE COUNT ITSELF IS PART OF THE LOWER BOUND (screen 2026-09-10-0923,
  # F2). The ceiling added by screen 0858 capped the upper bound and gated
  # only nLoD, so a count of 5,010 at 100% - lower bound 4,985, under the
  # ceiling - returned the DESCENDING sequence 5,010..5,000, ten of its
  # eleven values above the ceiling the comment said could never be
  # returned, and .ppDeriveArmN() then derived N = 5,000 for an arm whose
  # own printed count is 5,010. A derived arm size is at least the count,
  # so the count is folded into the lower bound before the gate, and an
  # empty range is empty rather than reversed.
  nLoD <- max(nLoD, ceiling(count))
  if (!is.finite(nLoD) || !is.finite(nHiD) || nLoD > .iaMaxArmN)
    return(integer(0))
  nHiD <- min(nHiD, .iaMaxArmN)
  if (nHiD < nLoD) return(integer(0))
  seq.int(as.integer(nLoD), as.integer(nHiD))
}

# Intersect the feasible sets of several cells belonging to one arm.
# Returns the arm size only when exactly ONE integer survives; anything
# looser stays NA rather than guessed - and a CONTRADICTION (a cell with
# valid inputs but no feasible N at all, or two cells with disjoint sets)
# refuses outright, because it means these are not really n (%) cells and
# nothing about this arm should be inferred from them.
.ppDeriveArmN <- function(counts, pcts, decs) {
  feas <- NULL
  for (i in seq_along(counts)) {
    valid <- !is.na(counts[i]) && !is.na(pcts[i]) &&
             counts[i] > 0 && pcts[i] > 0 && pcts[i] <= 100
    if (!valid) next                     # degenerate cell: no evidence
    s <- .ppNFromCountPct(counts[i], pcts[i], decs[i])
    if (length(s) == 0) return(NA_integer_)   # contradiction: refuse
    if (length(s) > 400) next            # too loose to narrow anything
    feas <- if (is.null(feas)) s else intersect(feas, s)
    if (length(feas) == 0) return(NA_integer_)  # disjoint cells: refuse
  }
  if (!is.null(feas) && length(feas) == 1) feas else NA_integer_
}

# The reverse bracket, for percent-block category tables (2026-08-21): given
# the arm size, which count was printed as `pct`%? The printed rounding
# brackets it - count/N must round to pct at `dec` decimals - and the count
# is accepted only when exactly ONE integer lies in the bracket. "47%" of
# n = 40 pins 19; "47%" of n = 702 spans 327..333 and is refused, because a
# fraud screen must not analyze approximated counts as if they were printed.
.ppCountFromPct <- function(pct, dec, N) {
  b <- .ppCountBracket(pct, dec, N)
  if (anyNA(b) || b[1] != b[2]) return(NA_integer_)
  b[1]
}

# The bracket itself: the smallest and largest integer counts whose
# proportion of N rounds to `pct` at `dec` decimals (2026-09-07, for the
# fail-safe fill - see parseBaselineTableHeuristics.R). NA, NA when the
# inputs cannot be bracketed.
.ppCountBracket <- function(pct, dec, N) {
  if (is.na(pct) || is.na(N) || N <= 0 || pct < 0 || pct > 100)
    return(c(NA_integer_, NA_integer_))
  if (is.na(dec)) dec <- 0L
  # IN DOUBLES, AND REFUSED BEFORE as.integer() - the same cure
  # .ppNFromCountPct() received from screen 2026-09-10-0858, which the next
  # screen (0923, F1) found this sibling still needed. A header cell
  # "(n=2147000000)" arrives intact through as.integer(); a "100%" cell
  # then made as.integer(floor(N * 1.005)) NA with a warning, the
  # comparison raised, and on the JATS route the whole document failed
  # with a message naming no cell. An arm above .iaMaxArmN can never be
  # analysed, so it yields no bracket at any percentage, and the row is
  # skipped rather than the document lost.
  if (!is.finite(N) || N > .iaMaxArmN) return(c(NA_integer_, NA_integer_))
  half <- 0.5 * 10^(-dec)
  cLoD <- max(ceiling(N * (pct - half) / 100 - 1e-9), 0)
  cHiD <- min(floor(N * (pct + half) / 100 + 1e-9), N)
  if (!is.finite(cLoD) || !is.finite(cHiD) || cHiD < cLoD)
    return(c(NA_integer_, NA_integer_))
  c(as.integer(cLoD), as.integer(cHiD))
}

# THE PERCENTAGE FILL LIVES IN R/failsafeTable.R.
#
# What stood here until 2026-09-09 was .ppFailsafeCounts(), with
# .ppRowStat(), .ppFailsafeExact and .ppFailsafeSweeps: the rule that
# chose each category LEVEL on its own table line by maximising that
# level's statistic against its own complement. It is deleted rather
# than kept, because while it existed it could still be reached - when
# the whole-table search could not run, the caller silently fell back to
# it, and the independent audit of 2026-09-09 (F1) found a page that
# then read p < 0.0001 where a valid reading of the same percentages
# gives 0.59.
#
# Its three defects are recorded in docs/method-history.md under
# 2026-09-08, and R/failsafeTable.R carries the measurements. The
# bracket itself, .ppCountBracket(), is still here and still used: which
# counts a printed percentage allows is arithmetic, and that part was
# never in doubt.

# --------------------------------------------------------------------------
# Source 2: the document text (CONSORT labels, randomization sentences)
# --------------------------------------------------------------------------
# Candidate (context, n) pairs from every "n = 137" in the document. The
# context decides whether the mention is an allocation ("allocated to the
# ketamine group (n = 24)") or something else entirely - above all a
# sample-size calculation ("n = 25 per group would provide 80% power"),
# which states a HYPOTHETICAL n that must never be taken for a real one.
.ppArmNCandidatesFromText <- function(txt) {
  empty <- data.frame(n = integer(0), context = character(0),
                      near = character(0), pos = integer(0),
                      stringsAsFactors = FALSE)
  if (!length(txt)) return(empty)
  j <- .ppSquish(paste(txt, collapse = " "))
  m <- gregexpr("(?i)\\bn\\s*=\\s*\\d[\\d,]*", j, perl = TRUE)[[1]]
  if (m[1] == -1) return(empty)
  lens <- attr(m, "match.length")
  out <- lapply(seq_along(m), function(k) {
    hit <- substr(j, m[k], m[k] + lens[k] - 1)
    n   <- suppressWarnings(as.integer(gsub("[^0-9]", "", hit)))
    # The near window must not reach back past the PREVIOUS mention:
    # "...ketamine group (n = 24) or the saline group (n = 26)" packs two
    # mentions into one sentence, and a window that crosses the first one
    # makes the second carry both arm names.
    nearFrom <- max(1, m[k] - 45,
                    if (k > 1) m[k - 1] + lens[k - 1] + 1 else 1)
    data.frame(n = n,
               # wide context: is this an allocation mention at all?
               context = substr(j, max(1, m[k] - 90), m[k] + lens[k] + 12),
               # near context: whose mention is it, and is it a sample-size
               # calculation? The label sits immediately left of "(n = X)".
               near = substr(j, nearFrom, m[k] + lens[k] + 12),
               pos = m[k], stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, out)
  out <- out[!is.na(out$n) & out$n > 0, , drop = FALSE]

  alloc <- grepl(paste0("(?i)allocat|assign|randomi[sz]|\\bgroup\\b|",
                        "\\barm\\b|receiv|analy[sz]ed|completed|enrol"),
                 out$context, perl = TRUE)
  # A sample-size calculation states a HYPOTHETICAL n ("n = 25 per group
  # would provide 80% power") that must never be taken for a real arm
  # size. Judged on the NEAR window: the calculation vocabulary sits right
  # beside its n, while a power sentence two lines earlier is no reason to
  # discard a genuine allocation mention.
  power <- grepl(paste0("(?i)power|sample\\s+size|per\\s+group|required|",
                        "detect|dropout|attrition|calculat|hypothes"),
                 out$near, perl = TRUE)
  out[alloc & !power, , drop = FALSE]
}

# A stated randomized/enrolled total, used to confirm a positional
# assignment. Returns every such total found (papers restate it).
.ppRandomizedTotals <- function(txt) {
  j <- .ppSquish(paste(txt, collapse = " "))
  pats <- c(paste0("(?i)(\\d[\\d,]*)\\s+(patients|subjects|participants|",
                   "children|women|men|volunteers|adults)?\\s*(were\\s+)?",
                   "(randomi[sz]ed|enrolled|recruited|included)"),
            "(?i)randomi[sz]ed\\s+(\\d[\\d,]*)",
            "(?i)total\\s+of\\s+(\\d[\\d,]*)")
  tot <- integer(0)
  for (p in pats) {
    m <- gregexpr(p, j, perl = TRUE)[[1]]
    if (m[1] == -1) next
    lens <- attr(m, "match.length")
    for (k in seq_along(m)) {
      hit    <- substr(j, m[k], m[k] + lens[k] - 1)
      digits <- regmatches(hit, gregexpr("[0-9][0-9,]*", hit))[[1]][1]
      v <- suppressWarnings(as.integer(gsub(",", "", digits)))
      if (!is.na(v)) tot <- c(tot, v)
    }
  }
  unique(tot)
}

# Fill the missing entries of `armN` from the text candidates.
#
# Assignment ladder, strictest first:
#   1. NAME MATCH - a candidate whose context contains a distinctive word
#      of the arm's name. All matching candidates must agree on one n.
#   2. ELIMINATION - every arm but one was name-matched and exactly one
#      distinct candidate value is left over.
#   3. POSITION, CONFIRMED BY THE TOTAL - no names matched at all, but the
#      number of allocation candidates equals the number of arms AND their
#      sum equals a stated randomized total. Document order is taken as
#      column order; that assumption is why the total confirmation is
#      mandatory, why any already-known arm N must agree with its
#      positional candidate, and why reviewFlags() reports the sentence.
#
# Returns list(N = the completed vector, source = per-arm character).
.ppFillArmNFromText <- function(armN, armName, cand, totals) {
  source <- rep(NA_character_, length(armN))
  if (nrow(cand) == 0 || !any(is.na(armN)))
    return(list(N = armN, source = source))
  snip <- function(ctx) paste0("\"...", .ppSquish(substr(ctx, 1, 100)), "...\"")

  stop_words <- c("group", "groups", "arm", "arms", "the", "and", "with",
                  "patients", "study", "control")
  # A distinctive word is three letters or more - or a ROMAN GROUP TAG
  # ("Ia", "IIb", "IV": Fujii's canine papers name their arms "Group Ia
  # (n = 5) ... Group IIb (n = 8)", issue 42), which is short but is the
  # whole of the arm's name once "Group" is set aside. A tag is matched
  # whole (\bia\b), so "Group I" does not claim "Group Ia"'s mention.
  isTag <- function(w) grepl("^[ivx]{1,3}[a-d]?$", w) & nchar(w) >= 2
  armWords <- lapply(armName, function(nm) {
    if (is.na(nm)) return(character(0))
    w <- tolower(unlist(strsplit(gsub("[^A-Za-z ]", " ", nm), "\\s+")))
    setdiff(w[nchar(w) >= 3 | isTag(w)], stop_words)
  })

  used <- rep(FALSE, nrow(cand))
  # 1. name match - against the NEAR window only, because the arm's label
  # sits immediately left of its "(n = X)", while a 90-character context
  # regularly spans the other arm's mention too ("...the ketamine group
  # (n = 24) or the saline group (n = 26)").
  for (k in which(is.na(armN))) {
    if (length(armWords[[k]]) == 0) next
    hits <- which(vapply(cand$near, function(ctx) {
      lc <- tolower(ctx)
      any(vapply(armWords[[k]], function(w)
        grepl(paste0("\\b", w, if (isTag(w)) "\\b" else ""), lc, perl = TRUE),
        logical(1)))
    }, logical(1)))
    if (length(hits) == 0) next
    ns <- unique(cand$n[hits])
    if (length(ns) == 1) {
      armN[k]  <- ns
      source[k] <- paste0("document text (arm name matched): ",
                          snip(cand$near[hits[1]]))
      used[hits] <- TRUE
    }
  }
  # 2. elimination - requires the leftover to actually correspond: exactly
  # one open arm AND exactly one unused mention. Two unused mentions of
  # "n = 20" over one open arm means the mentions belong to the two arms
  # already known, not to the leftover cluster (measured failure mode).
  open <- which(is.na(armN))
  if (length(open) == 1 && sum(!used) == 1) {
    armN[open] <- cand$n[!used]
    source[open] <- paste0("document text (only unassigned mention): ",
                           snip(cand$context[which(!used)[1]]))
  }
  # 3. position, confirmed by the stated total
  open <- which(is.na(armN))
  if (length(open) > 0 && !any(!is.na(source))) {
    firstMention <- cand[!duplicated(cand$pos), , drop = FALSE]
    if (nrow(firstMention) == length(armN) &&
        length(totals) > 0 && sum(firstMention$n) %in% totals) {
      agree <- TRUE
      for (k in seq_along(armN))
        if (!is.na(armN[k]) && armN[k] != firstMention$n[k]) agree <- FALSE
      if (agree) {
        for (k in open) {
          armN[k]  <- firstMention$n[k]
          source[k] <- paste0("document text (by position; the ",
                              sum(firstMention$n),
                              " total confirms the set, not the order): ",
                              snip(firstMention$context[k]))
        }
      }
    }
  }
  list(N = armN, source = source)
}

# ---------------------------------------------------------------------------
# "divided into three groups of eight each" - the group size as animal
# studies state it (2026-09-24, ISSUES.md issue 34).
# ---------------------------------------------------------------------------
# The two readers above want "n = 8" or "24 dogs were randomized". A
# laboratory paper says neither: PMID 11375852 gives its group size only as
# "Twenty-four mongrel dogs ... were divided into three groups of eight
# each", and with no N in the table the whole trial failed validation.
# This reads that one sentence shape and nothing looser. It returns the
# COUNT of groups as well as the size, so the caller can refuse the value
# when it does not match the number of arms actually read from the table -
# a stated "three groups of eight" is evidence for three arms, not for
# whatever the parser happened to find.
#
# EVERY such statement is returned, not the first (CodeRabbit on PR #330,
# 2026-09-24). A Methods section can state a pilot "divided into three
# groups of eight" and then the analysed animals "divided into three
# groups of ten"; taking the first match would hand the three-arm table
# N = 8 with nothing to catch it, because validation only asks that N be
# present. So the result is one entry per DISTINCT (groups, n) statement,
# and .ppParseRepeatedMeasures() applies a size only when the statements
# for its arm count agree on one - otherwise N stays missing, which the
# review flags say out loud.
.ppNumberWord <- function(w) {
  w <- tolower(w)
  words <- c(one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
             seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11,
             twelve = 12, fifteen = 15, sixteen = 16, twenty = 20)
  if (grepl("^[0-9]+$", w)) return(as.integer(w))
  if (w %in% names(words)) return(as.integer(words[[w]]))
  NA_integer_
}

.ppGroupsOfN <- function(txt) {
  if (!length(txt)) return(NULL)
  j <- .ppSquish(paste(txt, collapse = " "))
  pat <- paste0("(?i)\\b(divided|allocated|assigned|randomi[sz]ed|separated|",
                "split)\\b[^.;]{0,60}?\\binto\\s+([a-z0-9-]+)\\s+",
                "(?:equal\\s+)?groups?\\s+of\\s+([a-z0-9]+)",
                "(?:\\s+(?:each|animals?|dogs?|rats?|pigs?|rabbits?|",
                "patients?|subjects?|participants?))?")
  found <- list(groups = integer(0), n = integer(0), snippet = character(0))
  add <- function(groups, n, snippet) {
    # one entry per distinct statement; a sentence repeated verbatim in the
    # Abstract and the Methods is one statement, not two
    if (any(found$groups == groups & found$n == n)) return(invisible())
    found$groups  <<- c(found$groups, groups)
    found$n       <<- c(found$n, n)
    found$snippet <<- c(found$snippet, snippet)
  }
  m <- gregexpr(pat, j, perl = TRUE)[[1]]
  if (m[1] != -1) {
    for (h in seq_along(m)) {
      hit <- substr(j, m[h], m[h] + attr(m, "match.length")[h] - 1L)
      parts <- regmatches(hit, regexec(pat, hit, perl = TRUE))[[1]]
      groups <- .ppNumberWord(parts[3])
      n      <- .ppNumberWord(parts[4])
      if (!is.na(groups) && !is.na(n) && groups >= 2 && n >= 1)
        add(groups, n, .ppSquish(substr(j, max(1, m[h] - 30),
                                        m[h] + attr(m, "match.length")[h] + 10)))
    }
  }
  # THE SENTENCE IS OFTEN CUT AT A LINE BREAK, AND THE OTHER COLUMN FILLS THE
  # GAP. poppler emits each physical line of a two-column page as the left
  # segment followed by the right segment, so PMID 11375852 arrives as
  #     "...divided into three groups of   stimulation did not change."
  #     "eight each: Group 1 received ...  Pdi and Edi for each stimulus"
  # - the size on the NEXT line, with a fragment of the Results between.
  # Joining the page into one string cannot see that. So, per page, the
  # sentence is also accepted when "into <k> groups of" ends one line's left
  # segment and "<n> each" begins the next line: exact at a line boundary
  # and nothing looser, because a window that skipped over text would take
  # numbers from the wrong sentence.
  for (page in txt) {
    ln <- strsplit(page, "\n", fixed = TRUE)[[1]]
    if (length(ln) < 2) next
    for (i in seq_len(length(ln) - 1L)) {
      a <- regmatches(ln[i], regexec("(?i)\\binto\\s+([a-z0-9-]+)\\s+(?:equal\\s+)?groups?\\s+of\\s*(?:\\s{2,}|$)",
                                     ln[i], perl = TRUE))[[1]]
      if (length(a) < 2) next
      b <- regmatches(ln[i + 1], regexec("^\\s*([a-z0-9]+)\\s+each\\b", ln[i + 1], perl = TRUE))[[1]]
      if (length(b) < 2) next
      groups <- .ppNumberWord(a[2]); n <- .ppNumberWord(b[2])
      if (is.na(groups) || is.na(n) || groups < 2 || n < 1) next
      # the snippet is the LEFT segment of each line only - cut at the run of
      # spaces that separates the columns - so the flag the user reads does
      # not quote half a sentence from the other column
      # Cut at the double-space FIRST, then squish: .ppSquish collapses all
      # runs of whitespace to one space, so squishing first would leave
      # nothing to cut at and quote both columns (the first version did).
      left <- function(s) .ppSquish(sub("\\s{2,}.*$", "", sub("^\\s+", "", s)))
      add(groups, n, .ppSquish(paste(left(ln[i]), left(ln[i + 1]))))
    }
  }
  if (!length(found$groups)) return(NULL)
  found
}

# Arm sizes for a table that printed none, from the document text alone
# (issue 42, 2026-09-25). The two sources the block parser and the
# repeated-measures reader already use, in the same order: a "divided
# into k groups of n" statement for exactly this many arms, then the
# "(n = k)" mentions matched to the arm names (.ppFillArmNFromText's
# ladder). Written for the model route: when the deterministic engine
# fails and the model transcribes the table, its arms came back with no
# N on nine of the eleven Carlisle-168 trials that failed validation
# (corpus batch 4b) - Fujii's canine papers, whose sizes are in the
# Methods and nowhere in the table - and nothing ran the ladder over
# them. Every N found carries its sentence, for the CONSORT flag.
.ppArmNFromDocument <- function(armName, txt) {
  k      <- length(armName)
  armN   <- rep(NA_integer_, k)
  source <- rep(NA_character_, k)
  if (k == 0 || !length(txt)) return(list(N = armN, source = source))
  stated <- .ppGroupNFor(.ppGroupsOfN(txt), k)
  if (!is.na(stated$n)) {
    armN[]   <- stated$n
    source[] <- paste0("document text (\"...", stated$snippet, "...\")")
  }
  if (any(is.na(armN))) {
    cand <- .ppArmNCandidatesFromText(txt)
    if (nrow(cand) > 0) {
      fill  <- .ppFillArmNFromText(armN, armName, cand, .ppRandomizedTotals(txt))
      newly <- is.na(armN) & !is.na(fill$N)
      armN[newly]   <- fill$N[newly]
      source[newly] <- fill$source[newly]
    }
  }
  list(N = armN, source = source)
}

# The one group size the document states for a table of k arms, or NA.
# Statements naming a different number of groups are not about this table
# and are ignored; two statements for k arms that disagree on the size make
# the size unknowable from the text, and NA is the honest answer.
.ppGroupNFor <- function(textGroupN, k) {
  if (is.null(textGroupN)) return(list(n = NA_integer_, snippet = NA_character_))
  sel <- which(textGroupN$groups == k & textGroupN$n > 0)
  if (!length(sel) || length(unique(textGroupN$n[sel])) != 1L)
    return(list(n = NA_integer_, snippet = NA_character_))
  list(n = as.integer(textGroupN$n[sel[1]]), snippet = textGroupN$snippet[sel[1]])
}
