# app_globals.R — constants shared by the UI and server.
#
# PROVENANCE: was global.R at the repository root until the package
# restructure (phase 1, 2026-08-16); in phase 2 (same date) sumz() and
# outputComments() moved to their own files (R/sumz.R, R/outputComments.R,
# bodies untouched), leaving only the Monte Carlo replication constant here.
# The library() calls that used to open global.R live in run_app()
# (app_run.R). History for the earlier cleanup passes (2026-08-14) is in
# git; the FIX rationale comments travel with the code they explain.

# m is the MAXIMUM replication count per row for the Monte Carlo
# simulation (the final stage of the adaptive scheme - see the header of
# R/P_Calc.R and docs/statistics.md). Rows simulate in stages
# 1,000 -> 10,000 -> m, escalating only while the running mid-p is
# < 0.01, so a typical (unalarming) row costs 1,000 replicates - CHEAPER
# than the old flat 15,000 - while alarming rows get the precision that
# makes a "<0.0001" claim defensible (the 97.5% upper confidence bound
# must clear it, which needs ~30,000+ replicates at zero exceedances).
m <- 100000

############################################################################
# References                                                               #
# Carlisle JB. The analysis of 168 randomised controlled trials to test    #
# data integrity. Anaesthesia. 2012;67:521-537.                            #
#                                                                          #
# Carlisle JB, Dexter F, Pandit JJ, Shafer SL, Yentis SM. Calculating the  #
# probability of random sampling for continuous variables in submitted or  #
# published randomised controlled trials. Anaesthesia. 2015;70:848-58.     #
#                                                                          #
# Carlisle JB. Data fabrication and other reasons for non-random sampling  #
# in 5087 randomised, controlled trials in anaesthetic and general medical #
# journals. Anaesthesia. 2017;72:944-952                                   #
############################################################################

# The arm-size ceiling, shared by the app and the API so one number
# governs both and the documentation can state it as a property of
# IntegrityAnalysis rather than of one entry point (Steve, 2026-08-28).
#
# Two reasons, in his words: the Monte Carlo for a trial with more than
# 5,000 subjects in an arm is computationally expensive; and trials that
# large are "almost certainly funded by large companies or government
# entities" which "typically institute detailed auditing and review of
# manuscripts", so an independent fraud screen adds little.
#
# Enforcement is in validateData(), the gate BOTH surfaces run - the
# ceiling previously existed only in apiService.R, so the app had no
# limit and the documented claim would have been false for every web
# user. R/P_Calc.R remains callable directly for anyone with the
# computing horsepower and a reason.
.iaMaxArmN <- 5000L


# ---- ONE name normalizer, used by validateData AND the API gates -------
#
# WHY THIS EXISTS (2026-08-29). The /analyze size gates must read the
# frame validateData will actually see, or an attacker picks a column
# NAME that the gate does not recognise and the validator does. On
# 2026-08-28 that was fixed by adding .apiNormalizeNames to apiService.R
# - a SECOND implementation of rules that already lived here. It matched
# a subset, and the overnight screen found that every rule it missed was
# a bypass:
#
#   F1  label column named "ROWS" - validateData greps "ROW" and renames
#       it; the gate matched "ROW" exactly, so the categorical term was
#       skipped entirely. drawWork 1.9e10 -> 0, refused -> accepted,
#       and the table was analysed anyway. ~2 hours of CPU for a 180 KB
#       upload.
#   F2  NUMBER and N BOTH present - validateData renames NUMBER to N
#       UNCONDITIONALLY, producing two columns named N; R resolves $N to
#       the FIRST, which is the attacker's. The gate read N = 1 and
#       admitted a simulation of N = 5000. Scored 24x under budget for
#       work 208x over it.
#   F3  the MEASURE rename was copied WITHOUT validateData's coupled
#       GROUP/DECSD drops, so a legitimate Carlisle-2016 file the app
#       accepts got a 422 from the API with six bogus cell issues.
#
# Two implementations of one rule set is the defect. This is the rule
# set; both callers use it, so they cannot disagree.
#
# ORDER MATTERS and mirrors validateData's original sequence exactly:
# uppercase, TRIAL, MEASURE (with its drops), DECM, NUMBER, GROUP->ROW
# fallback, then the ROW grep. Changing the order changes which column
# wins when several match.
.iaNormalizeNames <- function(DATA) {
  if (is.null(DATA) || is.null(names(DATA)) || !length(names(DATA)))
    return(DATA)
  names(DATA) <- toupper(trimws(names(DATA)))

  nm <- names(DATA)
  i <- grep("TRIAL", nm)
  if (length(i)) names(DATA)[i[1]] <- "TRIAL"

  nm <- names(DATA)
  i <- grep("MEASURE", nm)
  if (length(i)) {
    names(DATA)[i[1]] <- "ROW"
    # COUPLED, not incidental: validateData drops these in the same
    # branch. Splitting them was F3.
    DATA$GROUP <- NULL
    DATA$DECSD <- NULL
  }

  nm <- names(DATA)
  i <- grep("DECM", nm)
  if (length(i)) names(DATA)[i[1]] <- "ROUND_MEAN"

  # UNCONDITIONAL, exactly as validateData does it. Renaming only when
  # no N exists was F2: it left two columns that both normalize to N.
  nm <- names(DATA)
  i <- grep("NUMBER", nm)
  if (length(i)) names(DATA)[i[1]] <- "N"

  nm <- names(DATA)
  if (!length(grep("ROW", nm))) {
    i <- grep("GROUP", nm)
    if (length(i)) names(DATA)[i[1]] <- "ROW"
  }

  # The grep that F1 turned on: ANY name containing ROW becomes ROW.
  nm <- names(DATA)
  i <- grep("ROW", nm)
  if (length(i)) names(DATA)[i[1]] <- "ROW"
  # The long categorical layout's column (2026-09-05): LEVEL, or its
  # alias CATEGORY, matched EXACTLY - a grep would swallow a category
  # column that happens to contain the word.
  nm <- names(DATA)
  i <- which(nm %in% c("LEVEL", "CATEGORY"))
  if (length(i)) names(DATA)[i[1]] <- "LEVEL"
  DATA
}

# The grid rows a file's UNUSABLE lines may add (security screen
# 2026-09-07-1758, F3): a page whose lines mostly fail to parse would
# otherwise put one row in the browser per refused line. Generous beside
# any real baseline table, and the count of the rest is shown.
.iaMaxSkippedRows <- 200L

# A whole FILE's unusable lines, capped across its blocks. parseWideTable()
# returns one block per "Trial:" marker row and nothing caps the number of
# markers, so capping each block separately bounded 200 times the block
# count - a 10,000-row sheet of three-row blocks was unbounded in practice
# (screen 2026-09-07-2101, F4). One budget, spent in order; the block that
# exhausts it carries the marker and the rest contribute nothing.
.iaCapSkippedFile <- function(blocks, cap = .iaMaxSkippedRows) {
  budget <- cap
  lapply(blocks, function(sk) {
    if (is.null(sk) || !nrow(sk)) return(sk)
    if (budget <= 0) return(sk[0, , drop = FALSE])
    out <- .iaCapSkipped(sk, budget)
    budget <<- max(0L, budget - nrow(out))
    out
  })
}

# The grid payload for the skip registry: which rows carry the "unreadable"
# mark and its hover text. Two versions of this ran quadratically inside
# the upload observer - the first scanned the whole frame per registry
# entry, the second used a list-name lookup, which is a linear search
# because R hashes environments and not list names, and grew the payload
# one `[[<-` at a time (screens 2026-09-07-2000 F3 and -2101 F3, the
# second of which measured both and found the "linear" claim false). This
# is match() plus one bulk assignment, and it is a function so that a test
# can measure it.
.iaSkipPayload <- function(d, sk, dataCols, rowCol) {
  empty <- list(iss = list(), note = list())
  if (is.null(sk) || !nrow(sk) || is.null(d) || !nrow(d)) return(empty)
  keyD  <- paste0(as.character(d$TRIAL), "\r", as.character(d$ROW))
  keySk <- paste0(as.character(sk$TRIAL), "\r", as.character(sk$ROW))
  emptyRow <- if (length(dataCols))
    !Reduce(`|`, lapply(d[dataCols], function(v) !is.na(v))) else rep(TRUE, nrow(d))
  # the LAST registry entry for a key wins, which is what the per-entry
  # loop did by overwriting as it went
  idx <- length(keySk) + 1L - match(keyD, rev(keySk))
  hit <- emptyRow & !is.na(idx)
  if (!any(hit)) return(empty)
  keys <- paste0(which(hit) - 1L, "|", rowCol - 1L)
  iss  <- as.list(rep("unreadable", sum(hit)));  names(iss)  <- keys
  note <- as.list(paste0(
    "The PDF reader saw this table line but could not use it: ",
    sk$reason[idx[hit]]));                       names(note) <- keys
  list(iss = iss, note = note)
}

# ...and the capping itself, a function rather than a block inside the
# upload observer so that a test can call what the app calls (screen
# 2026-09-07-1907, A1). The marker row is built FROM the frame: the
# parser's skipped frame carries three columns (label, reason, text), and
# a two-column literal raised "undefined columns selected" on exactly the
# documents the cap exists for (screen 1907, F3).
.iaCapSkipped <- function(skipped, cap = .iaMaxSkippedRows) {
  if (is.null(skipped) || !nrow(skipped) || nrow(skipped) <= cap) return(skipped)
  n <- nrow(skipped)
  out <- skipped[seq_len(cap), , drop = FALSE]
  mk <- skipped[1, , drop = FALSE]
  mk[] <- NA_character_
  mk$label  <- sprintf("... %d further unusable line(s) not shown", n - cap)
  mk$reason <- "the list of unusable lines is capped"
  out <- rbind(out, mk)
  rownames(out) <- NULL
  out
}

# THE LONG CATEGORICAL LAYOUT (Steve, 2026-09-05: "would it be more
# logical on the input spreadsheet to use the column N for categorical
# variables ... As it is, the spreadsheet becomes quite wide when there
# are many categories"; and: "add the new format while retaining the old
# format so that both can be parsed"). A categorical variable may be
# entered one line per LEVEL per arm - ROW = the variable, LEVEL = the
# category, N = the count, MEAN and SD blank - instead of one line per
# arm with a column per level. This converts the long lines into the
# wide rows every downstream consumer expects (validateData's checks,
# P_Calc's category columns, the grid, the workbook), so the rest of the
# code sees one layout. Arms are the lines sharing TRIAL, ROW and LEVEL,
# in file order - the same rule as for continuous lines - so a file may
# list all of one arm's levels together or all arms of one level
# together. A level's count column is the level name in upper case; a
# name that collides with a base column ("N", "MEAN") is prefixed with
# the variable's. Lines without a LEVEL pass through untouched; a file
# without a LEVEL column is returned as it came.
.iaMaxLevelColumns <- 200L   # the wide table the long layout may build: .apiMaxCols
.iaLongToWide <- function(DATA) {
  if (is.null(DATA) || !("LEVEL" %in% names(DATA)) || !("ROW" %in% names(DATA)))
    return(DATA)
  lv <- trimws(as.character(DATA$LEVEL))
  isLevel <- !is.na(lv) & nzchar(lv)
  if (!any(isLevel)) { DATA$LEVEL <- NULL; return(DATA) }
  if (!("TRIAL" %in% names(DATA))) DATA$TRIAL <- 1
  base <- c("TRIAL", "ROW", "N", "MEAN", "SD", "SE", "Q1", "Q3", "LEVEL",
            "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION")
  key <- paste(DATA$TRIAL, DATA$ROW, sep = "\r")
  levelKeys <- unique(key[isLevel])
  # the count column for each (variable, level): the level in upper case,
  # like a wide file's headers - unless that would be a base column or
  # would contain one of the substrings the normaliser and validateData
  # grep for (a level "Obstetric" would be taken for an OBSERVATION
  # rounding column; "Brown" for ROW), in which case the variable's name
  # and the level, in lower case, which no upper-case grep can match
  tokens <- "TRIAL|MEASURE|DECM|NUMBER|GROUP|ROW|MEAN|OBS|LEVEL|CATEGORY"
  colOf <- function(row, level) {
    nm <- toupper(level)
    if (nm %in% base || grepl(tokens, nm)) nm <- tolower(paste(row, level))
    nm
  }
  # THE GATE COMES FIRST (security screen 2026-09-06-1749, F1). The
  # previous build assigned one data.frame cell at a time - keys x new
  # columns `[[<-` calls, an n x n frame, thousands of one-row rbinds -
  # and was cubic in time and quadratic in memory: a 100 KB CSV of 1,000
  # all-distinct (ROW, LEVEL) lines took 91 s and 219 MB, and 5,000 lines
  # (the API's row limit) extrapolated to three hours on the single
  # plumber thread, before any downstream gate had seen the frame. The
  # wide table's width is known from the raw lines alone, so it is
  # counted and refused BEFORE anything is built: a real categorical
  # variable has a handful of levels, and a file whose long lines would
  # need more count columns than the API admits (.iaMaxLevelColumns, the
  # same 200 as .apiMaxCols) is not a baseline table. The build itself is
  # then one indexed matrix and one rbind, linear in the lines.
  li <- which(isLevel)
  cn <- vapply(li, function(i) colOf(DATA$ROW[i], lv[i]), character(1))
  newCols <- unique(cn)
  if (length(newCols) > .iaMaxLevelColumns)
    stop(sprintf(paste("the long layout would need %d count columns (one per",
                       "distinct level); the limit is %d - a baseline table's",
                       "categorical variables have a handful of levels each"),
                 length(newCols), .iaMaxLevelColumns))
  # the arm of each level line: its position among the lines of the same
  # (variable, level), in file order - the same rule as before
  arm <- stats::ave(seq_along(li), paste(key[li], lv[li], sep = "\r"), FUN = seq_along)
  # one wide row per (variable, arm), carrying the variable's first line
  # (its TRIAL, ROW, any extra columns) with the measurement columns blank
  keyFirst <- tapply(li, key[li], min)
  nArms    <- tapply(arm, key[li], max)
  keys     <- names(keyFirst)[order(keyFirst)]
  keyFirst <- keyFirst[keys]; nArms <- nArms[keys]
  W <- DATA[rep(keyFirst, nArms), , drop = FALSE]
  wideKey <- rep(keys, nArms)
  wideArm <- unlist(lapply(nArms, seq_len), use.names = FALSE)
  W$N <- NA_real_; W$LEVEL <- NA
  for (cc in intersect(c("MEAN", "SD", "SE", "Q1", "Q3", "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION"), names(W)))
    W[[cc]] <- NA
  # the counts, placed by (wide row, count column) in one indexed
  # assignment; a later line for the same cell wins, as the loop did
  M <- matrix(NA_real_, nrow(W), length(newCols), dimnames = list(NULL, newCols))
  ri <- match(paste(key[li], arm, sep = "\r"), paste(wideKey, wideArm, sep = "\r"))
  M[cbind(ri, match(cn, newCols))] <- suppressWarnings(as.numeric(DATA$N[li]))
  # every count column exists on every row, NA where a variable does not use it
  for (j in seq_along(newCols)) {
    if (!(newCols[j] %in% names(DATA))) DATA[[newCols[j]]] <- NA_real_
    W[[newCols[j]]] <- M[, j]
  }
  # rebuild in file order: continuous lines as they are, each variable's
  # wide rows where its first line stood, arms in order
  cont <- DATA[!isLevel, , drop = FALSE]
  pos  <- c(which(!isLevel), keyFirst[wideKey] + wideArm / (max(wideArm) + 1))
  out  <- rbind(cont, W[, names(DATA), drop = FALSE])
  out  <- out[order(pos), , drop = FALSE]
  rownames(out) <- NULL
  out$LEVEL <- NULL
  # the columns this layout created are categories by construction; the
  # attribute lets validateData accept them even when every row of the
  # file is categorical and no count column has an NA to prove it by
  attr(out, "iaLevelColumns") <- newCols
  out
}

# THE MONTE CARLO SEED (Steve, 2026-09-05, answering an outside review
# that saw the same table land on both sides of 0.05 across runs: "The
# Monte Carlo results should not return identical results unless the
# seed is fixed. The seed is not fixed ... allow a command line argument
# in the web application, and an argument in the API, that permits the
# user to set a seed."). Unseeded, the draws differ from run to run
# within the reported Monte Carlo interval, which is what a simulation
# should do. With a seed - the page's ?seed=12345, run_app(seed =), or
# the API's seed field - the same table, the same seed and the same
# build give the same numbers. Both generators are seeded: P_Calc draws
# with base R's rnorm and with dqrng's dqrnorm / dqrunif.
.iaSeedValue <- function(x) {
  if (is.null(x) || !length(x)) return(NULL)
  v <- suppressWarnings(as.numeric(trimws(as.character(x[1]))))
  if (length(v) != 1L || !is.finite(v) || v < 1 || v > 2147483647 || v %% 1 != 0)
    return(NULL)
  as.integer(v)
}
.iaSetSeed <- function(seed) {
  set.seed(seed); dqrng::dqset.seed(seed)
  invisible(seed)
}

# After normalizing, two source columns can collapse onto one name (a
# frame carrying both NUMBER and N ends with two called N). R's $ and
# [[ ]] silently take the FIRST, so the reader and the writer can
# disagree about which column they mean. Refuse instead of guessing.
.iaDuplicateNames <- function(DATA) {
  if (is.null(DATA) || !length(names(DATA))) return(character(0))
  nm <- names(DATA)
  unique(nm[duplicated(nm)])
}
