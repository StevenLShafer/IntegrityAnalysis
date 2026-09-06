# validateData.R — the upload validation pipeline.
#
# PROVENANCE: moved out of app_server() in phase 2 of the package
# restructure (Claude Code, model Claude Fable 5, 2026-08-16). The body of
# the reactiveData() observer became validateData(); is_category() came
# with it. One deliberate change, verified bit-identical under fixed seeds
# (see the phase-2 PR): instead of mutating the server's session state with
# <<-, validateData() RETURNS everything it derives and app_server assigns.
# outputComments() reports STRUCTURAL problems (a missing column - nothing
# to paint) to the session log; per-cell problems communicate through the
# issues frame and the grid's colored cells alone (Steve's direction,
# 2026-08-19 - no explanatory text below the table). outputComments()
# recovers the active session itself, so being called from an ordinary
# function changes nothing. Every FIX comment travels with its code.

#' Is a column a category (count) column?
#'
#' A category column is numeric, integer-valued, and has at least one NA
#' (the NA rows are where the trial's continuous variables live).
#'
#' @param x a column of the uploaded table.
#' @return `TRUE` if the column should be treated as categorical counts.
#' @noRd
.iaMaxMagnitude <- 1e12   # |value| at or beyond this is not a measurement (validateData)

is_category <- function(x, requireNA = TRUE) {
  # Remove NAs first for efficiency, then check if all values are integers

  # FIX: text columns (e.g. a comments column) previously crashed the app:
  # as.integer() on character data yields NA, all() then returns NA, and
  # if (!NA) is a fatal error ("missing value where TRUE/FALSE needed").
  # A non-numeric column can never be a category (categories are counts).
  if (!is.numeric(x))
    return(FALSE)

  # If there are no na values, then it can't be a category (unless the
  # caller knows the table has no continuous line to leave one)
  if (requireNA && sum(is.na(x)) == 0)
    return(FALSE)

  # If the vector is empty after removing NAs then it is not a category
  x_clean <- x[!is.na(x)]
  if (length(x_clean) == 0)
    return(FALSE)

  # Check if all values are whole numbers. (Not `== as.integer()`: beyond
  # 2^31 - 1, or at Inf, as.integer is NA and the if() upstream crashed -
  # screen 2026-09-06-0514 F2.)
  all(is.finite(x_clean) & x_clean %% 1 == 0)
}

#' Validate an uploaded baseline-data table
#'
#' Normalizes column names (TRIAL / ROW / N / MEAN / SD, the Carlisle-2016
#' aliases, ROUND_MEAN and ROUND_OBSERVATION), coerces the numeric columns,
#' identifies category columns with [is_category()], and checks every line
#' (continuous rows need N, MEAN and SD; category rows must not carry
#' continuous entries). Problems are reported line by line through
#' [outputComments()], which finds the active Shiny session on its own.
#'
#' @param DATA the raw uploaded data.frame.
#' @return a list: `FAIL` (logical), and on success the validated `DATA`
#'   (columns selected and ordered), `TRIALS`, `ColumnNames`,
#'   `CategoryNames`, `MiscNames`. On failure only `FAIL` is meaningful.
#' @noRd
validateData <- function(DATA) {
  FAIL <- FALSE

  # Per-cell issue map (issue 13, Steve's design 2026-08-17, implemented
  # 2026-08-18): every problem the per-line checks flag is ALSO recorded
  # against its cell, so the grid can paint it - yellow = missing,
  # red = unreadable (text where a number belongs), blue = incongruent
  # (a value that contradicts the row's type). The comments log remains
  # the detail view; the colors are the map. The same codes are the API
  # spec's machine-readable issues[] (docs/api-spec.md).
  issues <- list()
  # note: optional cell-specific hover text; NA falls back to the
  # renderer's generic per-color explanation
  addIssue <- function(row, col, code, note = NA_character_)
    issues[[length(issues) + 1]] <<- data.frame(
      row = row, col = col, code = code, note = note,
      stringsAsFactors = FALSE)
  issueFrame <- function() {
    if (length(issues) == 0) return(NULL)
    do.call(rbind, issues)
  }

  # ONE normalizer, shared with the API gates (.iaNormalizeNames in
  # app_globals.R). This block used to live here inline, and the
  # 2026-08-28 API fix copied a SUBSET of it into apiService.R - which
  # the overnight screen then took apart: every rule the copy missed was
  # a gate bypass (a "ROWS" header, a NUMBER+N pair). Two
  # implementations of one rule set was the defect; there is now one.
  # A one-row probe whose CELLS are the original names, pushed through
  # the same normalizer, so a duplicate can be reported by the column
  # that caused it (below) even after the normalizer's renames and drops.
  probe <- .iaNormalizeNames(as.data.frame(
    as.list(stats::setNames(names(DATA), names(DATA))),
    stringsAsFactors = FALSE, check.names = FALSE))
  DATA <- .iaNormalizeNames(DATA)

  # The one thing the normalizer does NOT do, because it mutates data
  # rather than names: default a missing TRIAL to 1. Kept here so the
  # shared function stays a pure renaming and the API gates cannot
  # acquire a hidden column as a side effect of being gated.
  if (!("TRIAL" %in% names(DATA))) DATA$TRIAL <- 1
  # The long categorical layout (one line per level, count in N) becomes
  # the wide one here, so every check below sees one layout. Both are
  # accepted; the grid, the workbook and the API emit the wide one.
  DATA <- .iaLongToWide(DATA)
  ColumnNames <- names(DATA)

  ##############################################

  # Verify that the necessary rows are in place
  RowColumn <- grep("ROW", ColumnNames)
  if (length(RowColumn) == 0)
  {
    outputComments("Missing column labeled ROW")
    FAIL <- TRUE
  } else {
    names(DATA)[RowColumn[1]] <- "ROW"
    ColumnNames <- names(DATA)
  }

  # DUPLICATE NAMES AFTER NORMALIZING (screen F2, 2026-08-29). NUMBER
  # and N both present collapse onto two columns called N; R's $ and
  # [[ ]] silently take the FIRST, so the API's gate scored one column
  # while P_Calc simulated the other. Refuse rather than pick.
  dupNames <- .iaDuplicateNames(DATA)
  if (length(dupNames))
  {
    # Name the SOURCE columns, not only the name they collapsed onto.
    # "(N)" alone sent the reader looking for a second N column when
    # the culprit was a category column called "Male (number, %)"
    # (Steve's Ticagrelor sheet, 2026-09-02).
    from <- vapply(dupNames, function(d) paste0(
      d, " from ",
      paste(sQuote(unlist(probe[names(probe) == d], use.names = FALSE),
                   q = FALSE), collapse = " and ")), character(1))
    outputComments(paste0(
      "Two columns normalize to the same name: ",
      paste(from, collapse = "; "),
      ". Rename or remove one - which column is meant is ambiguous."))
    FAIL <- TRUE
  }

  # [["N"]] not $N (screen F4): $ partial-matches SILENTLY, so a
  # "Notes" column made this test pass with no N present, skipping the
  # structural failure and crashing later at DATA[i, c("N","MEAN","SD")]
  # with "undefined columns selected" - an uncaught error in the app's
  # reactive instead of a coloured cell report.
  if (is.null(DATA[["N"]]))
  {
    outputComments("Missing column labeled N")
    FAIL <- TRUE
  }

  # ---- the arm-size ceiling (Steve, 2026-08-28) ---------------------------
  # IntegrityAnalysis refuses a trial with more than .iaMaxArmN subjects
  # in any arm, for two reasons, both of which belong here rather than in
  # the API alone:
  #
  #   1. The Monte Carlo is expensive in N. Every replicate of a
  #      continuous row draws N values per arm, so cost is
  #      replicates x sum(N) - a large trial can occupy the only thread
  #      for many minutes.
  #   2. Trials that large are funded by major companies or government
  #      entities, which institute detailed auditing and statistical
  #      review before submission. An independent fraud screen adds
  #      little to a manuscript that has already had one.
  #
  # ENFORCED HERE, NOT IN apiService.R, because the documentation says
  # "IntegrityAnalysis won't analyze trials with N > 5000 in any arm" -
  # a statement about the PROGRAM. The ceiling used to live only in the
  # API, so the app had no limit at all and the sentence would have been
  # false for every user who opened the web page. Writing documentation
  # that the code does not honour is the same defect corrected in the
  # privacy statement on 2026-08-27; the fix is to make the code true,
  # not to soften the sentence.
  #
  # An investigator who genuinely needs a larger trial analysed can call
  # P_Calc() directly - the escape hatch is named in the user guide.
  if (!is.null(DATA[["N"]]))
  {
    tooBig <- which(!is.na(suppressWarnings(as.numeric(DATA[["N"]]))) &
                    suppressWarnings(as.numeric(DATA[["N"]])) > .iaMaxArmN)
    if (length(tooBig))
    {
      for (i in tooBig)
        addIssue(i, "N", "too_large",
                 paste0("arm N exceeds ", format(.iaMaxArmN, big.mark = ","),
                        " - see the user guide"))
      outputComments(paste0(
        "This trial has an arm with more than ",
        format(.iaMaxArmN, big.mark = ","),
        " subjects. IntegrityAnalysis does not analyze trials that ",
        "large - see the documentation for why, and for how to run the ",
        "Monte Carlo directly if you need to."))
      FAIL <- TRUE
    }
  }

  # [[ ]] not $: `$` on a data frame partial-matches, so a sheet with a
  # MEANX column and no MEAN passed this check and crashed further down
  # (security screen 2026-09-05 F4, the same defect fixed for N on
  # 2026-08-29)
  if (is.null(DATA[["MEAN"]]))
  {
    outputComments("Missing column labeled MEAN")
    FAIL <- TRUE
  }
  if (is.null(DATA[["SD"]]))
  {
    outputComments("Missing column labeled SD")
    FAIL <- TRUE
  }

  # FIX (found by the consolidated suite, 2026-08-19): a missing required
  # column must stop here. The per-line checks below index
  # DATA[i, c("N", "MEAN", "SD")], and running them without those columns
  # raised "undefined columns selected" - killing the whole session
  # instead of reporting the structural failure. This is the bare-FAIL
  # return shape the server already guards for (is.null(v$DATA)).
  if (FAIL)
    return(list(FAIL = TRUE))

  # FIX: force N, MEAN, and SD to numeric. Excel/CSV files with a stray
  # text cell make the whole column character, and character data in the
  # per-line checks below crashed the app (if (NA) errors). Coercion
  # turns non-numeric cells into NA, which those checks then report to
  # the user line by line instead of crashing. Q1/Q3 and SE included
  # (2026-08-17, median/IQR support).
  unreadable <- list()   # (row, col) cells that held TEXT where a number
                         # belongs - coerced to NA below, but remembered
                         # so the grid paints them red, not yellow
  for (col in c("N", "MEAN", "SD", "SE", "Q1", "Q3"))
  {
    if (!is.null(DATA[[col]]) && !is.numeric(DATA[[col]]))
    {
      before <- !is.na(DATA[[col]]) &
                trimws(as.character(DATA[[col]])) != ""
      DATA[[col]] <- suppressWarnings(as.numeric(DATA[[col]]))
      bad <- which(before & is.na(DATA[[col]]))
      for (i in bad) {
        addIssue(i, col, "unreadable")
        unreadable[[paste(i, col)]] <- TRUE
      }
    }
    # BREAK TEST (2026-09-06, Steve: "is there anything a user can enter
    # from the keyboard that halts shinyapps with a reload error?"): yes -
    # "Inf" or "-Inf" typed into a MEAN cell. as.numeric reads it as a
    # number, is.na() passes it, and `Inf %% 1` is NaN, so the decimal
    # bump's if() met NA and the session died. A non-finite number is
    # UNREADABLE (red), like text; a magnitude no measurement reaches
    # (1e12 and beyond - 1e300 squared is Inf, which reached the engine
    # through the API as a 500) is refused as incongruent.
    if (!is.null(DATA[[col]]) && is.numeric(DATA[[col]]))
    {
      v <- DATA[[col]]
      inf <- which(!is.na(v) & !is.finite(v))
      for (i in inf) {
        addIssue(i, col, "unreadable")
        unreadable[[paste(i, col)]] <- TRUE
      }
      DATA[[col]][inf] <- NA_real_
      huge <- which(is.finite(v) & abs(v) >= .iaMaxMagnitude)
      for (i in huge) {
        addIssue(i, col, "incongruent",
                 paste0(col, " is beyond ", format(.iaMaxMagnitude, scientific = TRUE),
                        ", which no measurement reaches"))
        unreadable[[paste(i, col)]] <- TRUE
      }
      DATA[[col]][huge] <- NA_real_
      if (length(huge)) FAIL <- TRUE
    }
  }
  # The same sweep over every OTHER numeric column - the category and
  # level count columns (screen 2026-09-06-0514 F1: a count of 1e308 in
  # a level column was never swept, summed to Inf, slipped past the arm
  # ceiling's is.finite guard and reached the engine).
  for (col in setdiff(names(DATA), c("TRIAL", "ROW", "N", "MEAN", "SD", "SE", "Q1", "Q3",
                                     "ROUND_MEAN", "ROUND_OBSERVATION", "ROUND_DISPERSION")))
  {
    if (!is.numeric(DATA[[col]])) next
    v <- DATA[[col]]
    bad <- which(!is.na(v) & (!is.finite(v) | abs(v) >= .iaMaxMagnitude))
    for (i in bad) {
      addIssue(i, col, if (is.finite(v[i])) "incongruent" else "unreadable",
               if (is.finite(v[i])) paste0(col, " is beyond ", format(.iaMaxMagnitude, scientific = TRUE),
                                           ", which no count reaches") else NA_character_)
      unreadable[[paste(i, col)]] <- TRUE
    }
    DATA[[col]][bad] <- NA_real_
    if (length(bad)) FAIL <- TRUE
  }
  # the rounding columns too: "Inf" decimals is a number to as.numeric -
  # coerced FIRST (a text cell makes the whole column character, and the
  # clamp used to skip a character column: screen 2026-09-06-0514 F3)
  for (col in c("ROUND_MEAN", "ROUND_OBSERVATION", "ROUND_DISPERSION"))
    if (!is.null(DATA[[col]]))
    {
      if (!is.numeric(DATA[[col]]))
        DATA[[col]] <- suppressWarnings(as.numeric(DATA[[col]]))
      DATA[[col]][!is.na(DATA[[col]]) & (!is.finite(DATA[[col]]) | abs(DATA[[col]]) > 20)] <- NA_real_
    }
  isUnreadable <- function(row, col)
    isTRUE(unreadable[[paste(row, col)]])
  # the range rules (2026-09-05): a sample size is a whole number of at
  # least two (one patient has no SD); a dispersion cannot be negative
  # (a printed ZERO is accepted: 13 rows of Carlisle's 2017 corpus print
  # "SD 0" for a measure every patient shared - 6 patients, ASA 39 (0) -
  # and the engine handles it: identical arms, nothing to compare, mid-p
  # 0.5 at the attainable floor); a count is a whole number of at least
  # zero. (2026-09-05: #179 had refused the zero, which refused the
  # whole corpus sheet.)
  isWholeN    <- function(x) is.finite(x) && x >= 2 && x %% 1 == 0
  isPositive  <- function(x) is.finite(x) && x >= 0
  isCount     <- function(x) is.finite(x) && x >= 0 && x %% 1 == 0

  # Add rounding column for the mean
  MeanColumns <- grep("MEAN", ColumnNames)
  RoundMeanColumn <- which(ColumnNames[MeanColumns] != "MEAN")
  if (length(RoundMeanColumn) > 0)
  {
    names(DATA)[MeanColumns[RoundMeanColumn[1]]] <- "ROUND_MEAN"
    ColumnNames <- names(DATA)
  } else {
    if (!is.null(DATA$ROUND))
    {
      names(DATA)[names(DATA) == "ROUND"] <- "ROUND_MEAN"
    } else {
      ObservationColumns <- grep("OBS", ColumnNames)
      if (length(ObservationColumns) > 0)
      {
        names(DATA)[ObservationColumns[1]] <- "ROUND_OBSERVATION"
        DATA$ROUND_MEAN <- DATA$ROUND_OBSERVATION
      }
    }
  }
  # After all of that, if it still doesn't exist, just put in 0
  if (is.null(DATA$ROUND_MEAN))
  {
    DATA$ROUND_MEAN <- 0
  }
  ColumnNames <- names(DATA)

  ObservationColumns <- grep("OBS", ColumnNames)
  if (length(ObservationColumns) == 0)
  {
    DATA$ROUND_OBSERVATION <- DATA$ROUND_MEAN
    # FIX (outside review, 2026-09-05): this copy happens BEFORE the
    # per-line decimal bump below raises ROUND_MEAN, so a table without
    # rounding columns whose means were 1.20 and 1.25 used to simulate
    # with mean precision 1 and 2 but OBSERVATION precision 0 - every
    # simulated measurement rounded to a whole number. Remember which
    # observation cells were inferred (all of them, here; the blank
    # cells of a supplied column, below) and re-copy after the bump.
    obsInferred <- rep(TRUE, nrow(DATA))
  } else {
    names(DATA)[ObservationColumns[1]] <- "ROUND_OBSERVATION"
    obsInferred <- is.na(suppressWarnings(as.numeric(DATA$ROUND_OBSERVATION)))
  }
  ColumnNames <- names(DATA)

  # FIX (Steve's PR-22 testing, 2026-08-19): the rounding columns can
  # EXIST but hold NA - the blank-table starter ships them empty, and a
  # spreadsheet may leave them blank. The per-line decimal bump below
  # does `if (DATA$ROUND_MEAN[i] < digits)`, and if (NA) is a fatal
  # error: typing a decimal mean (45.3) into the blank table crashed
  # the whole session. An empty rounding cell means "infer it", and the
  # documented inference is exactly what the bump does when it starts
  # from 0 - so fill NAs with 0 and let the bump raise them to the
  # typed precision. (Coerce first: a text cell in a hand-edited
  # rounding column must not crash either.)
  for (col in c("ROUND_MEAN", "ROUND_OBSERVATION"))
  {
    if (!is.numeric(DATA[[col]]))
      DATA[[col]] <- suppressWarnings(as.numeric(DATA[[col]]))
    DATA[[col]][is.na(DATA[[col]])] <- 0
  }

  # Validate Categories
  #
  # SE and ROUND_DISPERSION are recognised columns, not categories. Papers
  # print a standard deviation or a standard error, never a variance, so
  # ParsePDF records whichever was printed in its own column and leaves the
  # conversion to us: it needs N, and the sample SD is a biased estimator
  # of sigma (Jensen's inequality), which P_Calc's c4 correction undoes.
  # ROUND_DISPERSION is the printed granularity of whichever value was
  # given, and cannot be inferred from ROUND_MEAN - a table may print
  # "39 (4.06)".
  #
  # They MUST be excluded here: is_category() calls any numeric column with
  # an NA and integer values a category, and ROUND_DISPERSION is exactly
  # that, so it would otherwise be analysed as a count column.
  # Q1/Q3 (median/IQR rows, 2026-08-17) join SE and ROUND_DISPERSION on
  # the excluded list for the same reason: integer-valued quartiles with
  # NAs elsewhere would otherwise be swallowed as category columns.
  CategoryNames <-
    ColumnNames[!ColumnNames %in% c("TRIAL", "ROW", "MEAN","N", "SD", "SE",
                                    "Q1", "Q3",
                                    "ROUND_OBSERVATION", "ROUND_MEAN",
                                    "ROUND_DISPERSION")]
  MiscNames <- NULL
  # count columns built from the long layout are categories by
  # construction (see .iaLongToWide): is_category()'s "has an NA" test
  # would reject them in a file whose every row is categorical
  levelCols <- attr(DATA, "iaLevelColumns")
  # A table that is nothing but counts - a sex distribution and no
  # continuous variable - has no continuous line to leave the blank that
  # is_category() keys on, and used to be refused for it (outside
  # review, 2026-09-05). When no line carries a MEAN or an SD there is
  # nothing to tell a count column from, so the blank is not required.
  countsOnly <- all(is.na(DATA$MEAN)) && all(is.na(DATA$SD))
  if (length(CategoryNames) == 0)
  {
    CategoryNames <- NULL
  } else {
    for (i in 1:length(CategoryNames))
    {
      if (!(CategoryNames[i] %in% levelCols) &&
          !is_category(DATA[,CategoryNames[i]], requireNA = !countsOnly))
      {
        # Issue 13: a column that LOOKS like a category (numeric, has
        # NAs) but is rejected only because some values are not
        # integers gets those cells painted blue - Steve's canonical
        # "incongruent" example. Columns rejected for other reasons
        # (text, no NAs) are ordinary Misc columns, not errors.
        v <- DATA[[CategoryNames[i]]]
        if (is.numeric(v) && any(is.na(v)) &&
            any(!is.na(v) & v %% 1 != 0))
        {
          for (r in which(!is.na(v) & v %% 1 != 0))
            addIssue(r, CategoryNames[i], "incongruent")
        }
        MiscNames <- c(MiscNames, CategoryNames[i])
        CategoryNames[i] <- "XXXXX"
      }
    }
    CategoryNames <- CategoryNames[CategoryNames != "XXXXX"]
  }

  if (length(CategoryNames) == 0)
    CategoryNames <- NULL

  # Validate each line
  # Steve's direction (2026-08-19): validation problems communicate
  # through the colored cells and the grid legend ONLY - the per-line
  # explanatory messages that used to print below the table are gone.
  # Structural problems with no cell to color (a missing column) still
  # log, because there is nothing to paint.

  # A LABEL-ONLY row - a ROW name with no data in any analyzable column -
  # is a SOFT warning, not a failure: its required cells paint yellow and
  # the row is excluded from the analyzed data. This is what a table line
  # the PDF parser could not use looks like once it is surfaced in the
  # grid (the server adds those rows so parse losses are conspicuous,
  # colored, and fixable), and blocking the analysis until every such row
  # is deleted would punish exactly the user the colors are meant to help.
  analyzableCols <- intersect(c("N", "MEAN", "SD", "SE", "Q1", "Q3"),
                              names(DATA))
  labelOnly <- logical(nrow(DATA))

  for (i in 1:nrow(DATA))
  {
    if (!is.na(DATA$ROW[i]) && trimws(as.character(DATA$ROW[i])) != "" &&
        all(is.na(DATA[i, c(analyzableCols, CategoryNames)])))
    {
      labelOnly[i] <- TRUE
      for (cn in c("N", "MEAN", "SD"))
        if (!isUnreadable(i, cn)) addIssue(i, cn, "missing")
      next
    }
    if (any(!is.na(DATA[i, CategoryNames]))) # If there is any category entry, continuous columns are set to NA
    {
      DATA$ROUND_MEAN[i] <- DATA$ROUND_OBSERVATION[i] <- NA
      # a count below zero (is_category() already requires whole numbers)
      for (cn in CategoryNames)
        if (!is.na(DATA[[cn]][i]) && !isCount(DATA[[cn]][i]))
        {
          addIssue(i, cn, "incongruent", "a count cannot be negative")
          FAIL <- TRUE
        }
      # ...and the arm ceiling applies to counts as it does to N: a line
      # of category counts IS an arm, and r2dtable on a billion patients
      # asked for 134 million TB (break test, 2026-09-06, via the API)
      armTotal <- sum(unlist(DATA[i, CategoryNames]), na.rm = TRUE)
      if (!is.finite(armTotal) || armTotal > .iaMaxArmN)   # an overflowed total is over the ceiling (F1)
      {
        for (cn in CategoryNames)
          if (!is.na(DATA[[cn]][i]))
            addIssue(i, cn, "too_large",
                     paste0("the counts total more than ", format(.iaMaxArmN, big.mark = ","),
                            " in this arm - see the user guide"))
        FAIL <- TRUE
      }
      if (any(!is.na(DATA[i, intersect(c("N", "MEAN", "SD", "Q1", "Q3"),
                                       names(DATA))])))
      {
        for (cn in intersect(c("N", "MEAN", "SD", "Q1", "Q3"),
                             names(DATA)))
          if (!is.na(DATA[[cn]][i])) addIssue(i, cn, "incongruent")
        FAIL <- TRUE
      }
    } else if (("Q1" %in% names(DATA) && !is.na(DATA$Q1[i])) ||
               ("Q3" %in% names(DATA) && !is.na(DATA$Q3[i]))) {
      # Median/IQR row (Steve's design, 2026-08-17): quartiles present
      # mean the MEAN column holds the MEDIAN. Both quartiles, N, and the
      # median are required; SD/SE must be EMPTY (a row carrying both an
      # SD and quartiles is ambiguous about what MEAN means); and the
      # median must sit between its quartiles (non-strict - printed
      # rounding can tie them).
      hasQ1 <- "Q1" %in% names(DATA) && !is.na(DATA$Q1[i])
      hasQ3 <- "Q3" %in% names(DATA) && !is.na(DATA$Q3[i])
      if (!hasQ1 || !hasQ3)
      {
        addIssue(i, if (hasQ1) "Q3" else "Q1", "missing")
        FAIL <- TRUE
      } else if (is.na(DATA$N[i]) || is.na(DATA$MEAN[i]))
      {
        for (cn in c("N", "MEAN"))
          if (is.na(DATA[[cn]][i]) && !isUnreadable(i, cn))
            addIssue(i, cn, "missing")
        FAIL <- TRUE
      } else if (!isWholeN(DATA$N[i]))
      {
        addIssue(i, "N", "incongruent", "N must be a whole number of at least 2")
        FAIL <- TRUE
      } else if (!is.na(DATA$SD[i]) ||
                 ("SE" %in% names(DATA) && !is.na(DATA$SE[i])))
      {
        for (cn in intersect(c("SD", "SE"), names(DATA)))
          if (!is.na(DATA[[cn]][i])) addIssue(i, cn, "incongruent")
        FAIL <- TRUE
      } else if (DATA$Q1[i] > DATA$MEAN[i] || DATA$MEAN[i] > DATA$Q3[i])
      {
        for (cn in c("MEAN", "Q1", "Q3")) addIssue(i, cn, "incongruent")
        FAIL <- TRUE
      } else {
        # median printed with decimals bumps ROUND_MEAN, same as a mean
        if (DATA$MEAN[i] %% 1 != 0)
        {
          digits <- nchar(sub("^.*\\.", "", as.character(DATA$MEAN[i])))
          if (DATA$ROUND_MEAN[i] < digits) DATA$ROUND_MEAN[i] <- digits
        }
      }
    } else {
      if (any(is.na(DATA[i, c("N", "MEAN", "SD")])))
      {
        # An SE beside a missing SD is a different problem from a blank
        # row - the SE cell is INCONGRUENT (the analysis needs an SD;
        # the SE-to-SD conversion needs N and is an analysis decision,
        # so it is not made silently). Everything else missing is plain
        # yellow.
        if ("SE" %in% names(DATA) && !is.na(DATA$SE[i]) && is.na(DATA$SD[i]))
          addIssue(i, "SE", "incongruent")
        for (cn in c("N", "MEAN", "SD"))
          if (is.na(DATA[[cn]][i]) && !isUnreadable(i, cn))
            addIssue(i, cn, "missing")
        FAIL <- TRUE
      } else if (!isWholeN(DATA$N[i]) || !isPositive(DATA$SD[i]) ||
                 ("SE" %in% names(DATA) && !is.na(DATA$SE[i]) && !isPositive(DATA$SE[i])))
      {
        # RANGE (2026-09-05, an outside review: "invalid values such as
        # negative SDs and fractional sample sizes can pass validation").
        # Presence and type were checked; range was not, and the Monte
        # Carlo draws happily from a normal with a negative or zero
        # spread. A blue cell with the rule it broke, and no analysis.
        if (!isWholeN(DATA$N[i]))
          addIssue(i, "N", "incongruent", "N must be a whole number of at least 2")
        if (!isPositive(DATA$SD[i]))
          addIssue(i, "SD", "incongruent", "SD cannot be negative")
        if ("SE" %in% names(DATA) && !is.na(DATA$SE[i]) && !isPositive(DATA$SE[i]))
          addIssue(i, "SE", "incongruent", "SE cannot be negative")
        FAIL <- TRUE
      } else {
        # Fix MEAN digits if Mean has any decimal digits
        # FIX: two changes here.
        # (1) This block is now the else of the NA check above. It
        #     previously ran even for rows just flagged as having a
        #     missing MEAN, and if (NA != ...) is a fatal error - the
        #     user got a crash instead of the validation messages.
        # (2) The decimal test is now MEAN %% 1 != 0 rather than
        #     MEAN != as.integer(MEAN): as.integer() returns NA for
        #     values beyond +/-2^31 (e.g. large counts), which would
        #     also crash the if().
        if (DATA$MEAN[i] %% 1 != 0)
        {
          digits <- nchar(sub("^.*\\.", "", as.character(DATA$MEAN[i])))
          if (DATA$ROUND_MEAN[i] < digits) DATA$ROUND_MEAN[i] <- digits
        }
      }
    }
  }

  # The inferred precisions, finished (outside review, 2026-09-05). A
  # variable is printed at one precision, so a mean typed as 1.20 beside
  # one typed as 1.25 (the trailing zero is lost when text becomes a
  # number) is a 2-decimal variable on both lines: raise ROUND_MEAN to
  # the variable's maximum. Then an observation precision that was not
  # supplied follows the mean's - the inference the guide documents -
  # rather than the 0 it was copied from before the bump.
  if (nrow(DATA) > 0)
  {
    DATA$ROUND_MEAN <- stats::ave(DATA$ROUND_MEAN, DATA$TRIAL, DATA$ROW, FUN = max)
    DATA$ROUND_OBSERVATION[obsInferred] <- DATA$ROUND_MEAN[obsInferred]
  }

  # A SINGLE-LINE categorical variable is unanalyzable: the method
  # compares counts ACROSS arms, and one line is one arm. Real tables
  # never print a one-arm category, but a misparsed PDF can produce one
  # (Steve's Test4 report, 2026-08-19: footnote fragments became
  # "variables" whose stray numbers landed in junk count columns, and
  # the rows sat in the grid valid-looking and unflagged). Soft-flag the
  # ROW cell with a specific hover note and leave the line out of the
  # analysis, exactly like a label-only row.
  singleCat <- logical(nrow(DATA))
  if (!is.null(CategoryNames))
  {
    catLine <- vapply(seq_len(nrow(DATA)), function(i)
      any(!is.na(DATA[i, CategoryNames])), logical(1))
    for (key in unique(paste(DATA$TRIAL, DATA$ROW)[catLine]))
    {
      g <- which(paste(DATA$TRIAL, DATA$ROW) == key & catLine)
      if (length(g) == 1)
      {
        singleCat[g] <- TRUE
        addIssue(g, "ROW", "missing", paste(
          "This looks like a categorical line, but it has no matching",
          "line for another arm - a category needs counts in at least",
          "two arms to compare. It is left out of the analysis: fill in",
          "the other arm(s), or delete the row."))
      }
    }
  }

  if (FAIL)
  {
    # No log text (Steve's direction, 2026-08-19): the colored cells and
    # the legend below the grid are the entire error report. Return the
    # NORMALIZED frame (pre-sort, so issue row numbers still index it)
    # together with the cell issues, so the grid can display the very
    # frame the issues refer to.
    return(list(FAIL = TRUE, DATA = DATA, issues = issueFrame()))
  }
  # Label-only rows and single-line categoricals (soft-flagged above)
  # are excluded from the ANALYZED data only - the grid keeps showing
  # them, painted, in the frame the issues index (the pre-validation
  # frame the caller displays). If NOTHING analyzable remains, that is a
  # failure after all.
  excluded <- labelOnly | singleCat
  if (any(excluded))
  {
    if (all(excluded))
      return(list(FAIL = TRUE, DATA = DATA, issues = issueFrame()))
    DATA <- DATA[!excluded, , drop = FALSE]
  }
  # Carry SE, Q1/Q3, and ROUND_DISPERSION through when the input supplies
  # them. They are optional: a spreadsheet typed by hand, or written
  # before these changes, has none of them, and must still work.
  OptionalColumns <- intersect(c("SE", "Q1", "Q3", "ROUND_DISPERSION"),
                               names(DATA))
  DATA <- DATA[,c("TRIAL", "ROW", "N", "MEAN", "SD",  "ROUND_MEAN", "ROUND_OBSERVATION", OptionalColumns, CategoryNames, MiscNames)]
  DATA <- DATA[order(DATA$TRIAL, DATA$ROW),]
  TRIALS <- unique(DATA$TRIAL)

  # issues can be non-empty on success (e.g. non-integer values in a
  # would-be category column, filed as Misc): soft warnings, painted but
  # not blocking.
  list(FAIL = FALSE, DATA = DATA, TRIALS = TRIALS,
       ColumnNames = ColumnNames, CategoryNames = CategoryNames,
       MiscNames = MiscNames, issues = issueFrame())
}
