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
  newCols <- character(0)
  wide <- list()          # per level key: the wide rows (one per arm)
  for (k in levelKeys) {
    rows <- which(key == k & isLevel)
    levels <- unique(lv[rows])
    nArms <- max(vapply(levels, function(l) sum(lv[rows] == l), integer(1)))
    proto <- DATA[rows[1], , drop = FALSE]
    out <- proto[rep(1, nArms), , drop = FALSE]
    out$N <- NA_real_; out$LEVEL <- NA
    for (cc in intersect(c("MEAN", "SD", "SE", "Q1", "Q3", "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION"), names(out)))
      out[[cc]] <- NA
    for (l in levels) {
      cn <- colOf(DATA$ROW[rows[1]], l)
      newCols <- union(newCols, cn)
      lrows <- rows[lv[rows] == l]
      counts <- suppressWarnings(as.numeric(DATA$N[lrows]))
      if (!(cn %in% names(out))) out[[cn]] <- NA_real_
      out[[cn]][seq_along(lrows)] <- counts
    }
    wide[[k]] <- out
  }
  # every count column exists on every row, NA where a variable does not use it
  for (cn in newCols) if (!(cn %in% names(DATA))) DATA[[cn]] <- NA_real_
  for (k in names(wide)) for (cn in newCols) if (!(cn %in% names(wide[[k]]))) wide[[k]][[cn]] <- NA_real_
  # rebuild in file order: continuous lines as they are, each level
  # group's wide rows where its first line stood
  pieces <- list(); placed <- character(0)
  for (i in seq_len(nrow(DATA))) {
    if (!isLevel[i]) { pieces[[length(pieces) + 1]] <- DATA[i, , drop = FALSE]; next }
    k <- key[i]
    if (k %in% placed) next
    placed <- c(placed, k)
    pieces[[length(pieces) + 1]] <- wide[[k]][, names(DATA), drop = FALSE]
  }
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out$LEVEL <- NULL
  # the columns this layout created are categories by construction; the
  # attribute lets validateData accept them even when every row of the
  # file is categorical and no count column has an NA to prove it by
  attr(out, "iaLevelColumns") <- newCols
  out
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
