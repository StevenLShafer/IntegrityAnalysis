# parseBaselineTable.R - the hybrid entry point: heuristics first, AI second.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-15 by Claude Code (model: Claude Opus 5, Anthropic) at   #
# Steve Shafer's request. New code.                                        #
#                                                                          #
# Policy encoded here: the deterministic engine ALWAYS runs first, and its #
# rows always win. The AI engine is consulted only for what the            #
# deterministic pass could not read, and never overwrites a value that was #
# located on the page by coordinate.                                       #
# Status: run and verified by tests/testthat/test-hybrid.R (deterministic  #
# paths and the merge rule; the live API call is not exercised there).     #
############################################################################

# Does a model-supplied variable's label name an OUTCOME rather than a
# baseline characteristic (issues 54 and 61)? The vocabulary of the caption
# scorer plus the words of block onset, analgesia, follow-up, adverse events
# and operative management. A label whose first two words (of three
# letters or more) appear on a line of `blockText` - the chosen table's own
# text - is the table's own and is never an outcome here; with no block
# text (the AI-only route, where the model read the page without a
# deterministic table beside it) the vocabulary alone decides.
# THE DURATIONS CLASS (2026-09-25, ISSUES.md issue 74; Steve's decision of
# 2026-09-25). A duration of surgery or of anaesthesia, the blood loss, the
# fluids given: a baseline table often prints them, and whether they are
# baseline quantities depends on WHEN randomisation happened. Randomised
# at induction, they are measured after the intervention and do not
# belong; randomised after surgery (a postoperative analgesia trial),
# they precede the intervention like any other baseline variable, with
# the same statistical standing. That is a trial-by-trial judgement, so
# they are never refused as outcomes: the `durations` option of
# parseBaselineTable() keeps them (the default, with a flag that names
# them) or excludes them (to $skipped, with the reason), the app offers
# the same choice as a radio button when a table prints them, and the
# service takes it as ?durations=exclude. The one exception is a
# duration the model brought in from ANOTHER table (issue 54): with the
# chosen table's block text at hand, a duration not printed in it is
# still refused as that table's row, not as an outcome.
.ppDurationLabel <- function(labels) {
  re <- paste0("(?i)duration of (the )?(surgery|surgical|operation|operative|procedure|an(a)?esthes|an(a)?esthetic)|",
               "\\b(surgery|surgical|operation|operative|procedure|an(a)?esthesia|an(a)?esthetic)\\s+(time|duration|length)\\b|",
               "\\b(length|time) of (the )?(surgery|operation|procedure|an(a)?esthesia)\\b|",
               "\\bblood loss\\b|\\b(estimated|intra-?operative) (blood )?loss\\b|",
               "\\b(i-d|u-d|incision.{1,3}delivery|uterine.{1,12}delivery)\\s*interval|",
               "\\b(intra-?operative|total)?\\s*(fluids?|crystalloids?|colloids?)\\b.*(given|administered|infused|replacement|volume|\\bml\\b)|",
               "\\bfluid (replacement|therapy|administration)\\b")
  grepl(re, labels, perl = TRUE)
}

# Apply the `durations` option to a parsed table: "include" keeps the
# rows of the durations class and flags them; "exclude" moves them to
# $skipped with the reason and drops them from $data and $provenance.
.ppApplyDurations <- function(out, durations = c("include", "exclude"),
                              say = function(...) invisible(NULL)) {
  durations <- match.arg(durations)
  if (is.null(out) || is.null(out$data) || nrow(out$data) == 0) return(out)
  isDur <- .ppDurationLabel(out$data$ROW)
  if (!any(isDur)) return(out)
  labs <- unique(out$data$ROW[isDur])
  if (durations == "include") {
    out$flags <- c(out$flags, paste0(
      length(labs), " variable(s) may be post-randomisation quantities (durations of ",
      "surgery or anaesthesia, blood loss, fluids): ", paste(labs, collapse = ", "),
      " - kept; they belong only when randomisation followed them (exclude with ",
      "durations = \"exclude\", or the app's Exclude durations option)"))
    return(out)
  }
  say("Excluding ", length(labs), " duration variable(s) (durations = \"exclude\"): ",
      paste(labs, collapse = ", "))
  out$skipped <- rbind(out$skipped,
                       data.frame(label = labs,
                                  reason = paste("excluded by the durations option: a post-randomisation",
                                                 "quantity (duration of surgery or anaesthesia, blood loss,",
                                                 "fluids) - include it if randomisation followed it"),
                                  text = "", stringsAsFactors = FALSE))
  out$flags <- c(out$flags, paste0(length(labs), " duration variable(s) excluded by the ",
                                   "durations option (see $skipped): ", paste(labs, collapse = ", ")))
  out$data <- out$data[!isDur, , drop = FALSE]
  rownames(out$data) <- NULL
  if (!is.null(out$provenance))
    out$provenance <- out$provenance[!out$provenance$ROW %in% labs, , drop = FALSE]
  out
}

.ppOutcomeLabel <- function(labels, blockText = NULL) {
  outcomeRe <- paste0("(?i)\\btime to\\b|\\bonset\\b|first analgesic|rescue analges|",
                      "\\bvas\\b|\\bodi\\b|\\b(st|nd|rd|th)\\s+(week|month|day)\\b|",
                      "\\b(week|month|day)s?\\s+(after|post)|\\bpost-?op|\\bintra-?op|",
                      "bradycardia|hypotension|nausea|vomit|pruritus|shivering|",
                      "satisfaction|complication|adverse|side.?effect|recovery|",
                      "extubation|emergence|success\\b|\\bat\\s+\\d+\\s*(h|min|hours?|minutes?)\\b|",
                      "ephedrine|phenylephrine|atropine|neostigmine|consumption|\\btotal\\b.*\\bdose\\b")
  # the durations class (issue 74) is judged with the outcomes only when
  # the chosen table's block can vouch for a printed row; with no block
  # (the model-only routes) a duration is never refused - the `durations`
  # option decides its fate
  isDur     <- .ppDurationLabel(labels)
  isOutcome <- grepl(outcomeRe, labels, perl = TRUE)
  # A LABEL IN ANOTHER SCRIPT WITH AN ENGLISH GLOSS (2026-09-25, ISSUES.md
  # issue 83; MTS2006_17, the corpus session's batch 19 Y1): the model
  # returns the row's Japanese name with the gloss "(surgery duration)"
  # for a row the block prints in Japanese, and the block test below -
  # the label's first two words on a line of the block - can never find
  # "surgery" in that block. A duration whose label carries letters
  # outside Latin script is kept on the durations option's terms, block
  # or no block; an outcome in such a label (a Japanese name glossed
  # "(postoperative pentazocine required)") is still refused by its
  # vocabulary.
  # (a code point above U+024F - beyond Latin Extended-B - is another
  # script; tested by code point, not by a PCRE class, which needs UTF mode)
  nonLatin  <- vapply(labels, function(l)
    !is.na(l) && any(utf8ToInt(enc2utf8(l)) > 0x024F), logical(1))
  if (is.null(blockText) || !length(blockText)) isOutcome <- isOutcome & !isDur
  else isOutcome <- isOutcome | (isDur & !nonLatin)
  if (any(isOutcome) && !is.null(blockText) && length(blockText)) {
    blk <- tolower(.ppSquish(blockText))
    inBlock <- vapply(labels, function(lb) {
      w <- tolower(unlist(strsplit(gsub("[^A-Za-z ]", " ", lb), "\\s+")))
      w <- w[nchar(w) >= 3][seq_len(min(2L, sum(nchar(w) >= 3)))]
      if (!length(w)) return(FALSE)
      any(vapply(blk, function(line) all(vapply(w, function(x) grepl(x, line, fixed = TRUE), logical(1))), logical(1)))
    }, logical(1))
    isOutcome <- isOutcome & !inBlock
  }
  unname(isOutcome)
}

# The refusal applied to a MODEL-ONLY result (2026-09-25, ISSUES.md issues
# 64 and 66). With no deterministic table beside it there is no block
# text, so the vocabulary alone decides: a refused row leaves $data and
# $provenance for $skipped with its reason, and a flag names it. Issue 64
# put this on the retry route (the deterministic pass failed and the model
# read the page alone); issue 66 shares it with the explicit ai = "always"
# route, which the corpus batches use as their retry - on that route the
# same page (PMID 9542558) kept Table 2's operative management, duration
# of surgery to tubal ligation, and p moved from 0.059 to 7e-05.
.ppRefuseModelOutcomes <- function(out, say = function(...) invisible(NULL)) {
  if (!identical(out$engine, "ai") || is.null(out$data) || nrow(out$data) == 0) return(out)
  isOutcome <- .ppOutcomeLabel(out$data$ROW, NULL)
  if (!any(isOutcome)) return(out)
  bad <- unique(out$data$ROW[isOutcome])
  say("Refusing ", length(bad), " model variable(s) whose label names an ",
      "outcome, not a baseline characteristic: ", paste(bad, collapse = ", "))
  out$skipped <- rbind(out$skipped,
                       data.frame(label = bad,
                                  reason = "model variable with outcome vocabulary - not a baseline characteristic; enter by hand if it is one",
                                  text = "", stringsAsFactors = FALSE))
  out$flags <- c(out$flags, paste0(length(bad), " model variable(s) refused as ",
                                   "outcomes (see $skipped): ", paste(bad, collapse = ", ")))
  out$data <- out$data[!isOutcome, , drop = FALSE]
  rownames(out$data) <- NULL
  if (!is.null(out$provenance))
    out$provenance <- out$provenance[!out$provenance$ROW %in% bad, , drop = FALSE]
  out
}

#' What in a parsed table needs a human look
#'
#' Returns the reasons a parsed table should not be trusted as-is. An empty
#' character vector means the deterministic engine read the whole table
#' cleanly. [parseBaselineTable()] uses this to decide whether to consult the
#' AI fallback.
#'
#' @param x A `ParsePDFTable` object.
#' @return A character vector of human-readable reasons, possibly empty.
#' @export
reviewFlags <- function(x) {
  stopifnot(inherits(x, "ParsePDFTable"))
  flags <- character(0)
  if (nrow(x$data) == 0)
    flags <- c(flags, "no rows were parsed at all")
  if (nrow(x$skipped) > 0)
    flags <- c(flags, paste0(nrow(x$skipped),
                             " table line(s) could not be used: ",
                             paste(unique(x$skipped$label), collapse = ", ")))
  if (nrow(x$arms) < 2)
    flags <- c(flags, paste0("only ", nrow(x$arms),
                             " treatment arm(s) were found"))
  if (any(is.na(x$arms$N)))
    flags <- c(flags, "arm N is missing for at least one arm")
  # A COLUMN OF A DIFFERENT POPULATION BESIDE THE RANDOMISED ARMS
  # (2026-09-25, ISSUES.md issue 62; the corpus session's O2, AAS1998_851):
  # fifteen VOLUNTEERS beside three randomised current groups of 40. The
  # cells are right, but the column is not an arm of the trial, and
  # carried as one it moved P_FULL from 0.34 to 0.043 on the categorical
  # rows. Named here so the reviewer can drop the column; the engine does
  # not decide what the trial randomised.
  other <- !is.na(x$arms$arm) &
    grepl("(?i)\\bvolunteers?\\b|\\bhealthy\\s+(controls?|subjects?|adults?)|\\bnormal\\s+(subjects?|controls?)|\\bnon[- ]?randomi[sz]ed",
          x$arms$arm, perl = TRUE)
  if (any(other))
    flags <- c(flags, paste0("arm(s) ", paste0("\"", x$arms$arm[other], "\"", collapse = ", "),
                             " name a different population (volunteers, healthy ",
                             "controls) beside the randomised arms - remove the column ",
                             "before analysis unless it was randomised too"))
  # A TABLE WHOSE DISPERSIONS MOSTLY EXCEED THEIR MEANS is probably not a
  # table of means (2026-09-24, Loadsman corpus, Akkaya 2015 EJA: 31 of
  # 48 "continuous" rows were counts with their percentages - "18 (90)"
  # - read as mean 18, SD 90, and the engine scored them, p = 0.0029, the
  # corpus's second-strongest result). One such row is ordinary: a
  # skewed quantity - opioid consumption, previous operations - prints an
  # SD above its mean and is analysed as it stands. Half the table doing
  # it is a misread, and a flag here consults the AI under ai =
  # "fallback" and tells a human what to look at. The per-row invariant
  # belongs in the validator as a non-fatal issue, which needs a new
  # issue code - a contract decision, held for Steve (ISSUES.md 35).
  cont <- !is.na(x$data$MEAN) & !is.na(x$data$SD)
  if (sum(cont) >= 3) {
    above <- cont & x$data$MEAN >= 0 & x$data$SD > x$data$MEAN
    if (sum(above) >= 0.5 * sum(cont))
      flags <- c(flags, paste0(sum(above), " of ", sum(cont), " mean (SD) ",
                               "cells print an SD larger than the mean: ",
                               "counts with their percentages read as ",
                               "mean (SD)? - check the table's notation"))
  }
  # DEGENERATE ROWS (2026-09-25, ISSUES.md 36; the corpus session's
  # proposal, Steve's instruction to flag at parse time). A variable that
  # prints the SAME value with ZERO dispersion in every arm ("%Edi 100.0
  # +/- 0.0" in every group of MTS2006_49, by construction), or a median
  # pinned at its own quartile in every arm ("0 (0-20)" for intraoperative
  # ephedrine in Akelma 2020: median = Q1 = 0 everywhere), carries no
  # information about sampling: it is fixed by design or by a floor, and
  # its agreement across arms is forced. Fed to a homogeneity test it
  # sits at the attainable floor - Akelma's ephedrine row alone took a
  # trial from 0.0084 to 0.00094. The engine still analyses it (a rule
  # that removed rows is the validator's business, and a contract
  # decision); the flag names it so a reader can remove it, and it
  # consults the AI under ai = "fallback".
  d <- x$data
  byRow <- split(seq_len(nrow(d)), d$ROW)
  hasQ  <- all(c("Q1", "Q3") %in% names(d))
  isDegenerate <- function(i) {
    if (length(i) < 2) return(FALSE)
    m <- d$MEAN[i]; s <- d$SD[i]
    if (all(!is.na(m)) && all(!is.na(s)) && all(s == 0) && length(unique(m)) == 1L)
      return(TRUE)
    if (hasQ) {
      q1 <- d$Q1[i]; q3 <- d$Q3[i]
      if (all(!is.na(m)) && all(!is.na(q1)) && all(!is.na(q3)) &&
          (all(m == q1) || all(m == q3)))
        return(TRUE)
    }
    FALSE
  }
  # A CONTINUOUS VARIABLE WITH FEWER CELLS THAN THE TABLE HAS ARMS (2026-09-25,
  # ISSUES.md issue 51; corpus batch 5, K2: CJA 1995;42:992, six arms of 15,
  # Age read in all six, Height and Weight in four - the OCR of two cells
  # failed). The deterministic table was accepted as it stood, so the
  # fallback never consulted the model and the two variables went into the
  # analysis two arms short. A variable that disagrees with its table on
  # arm count is a review flag - which is what gates the model consult, and
  # the arm-by-arm merge of issue 37 then fills the missing cells from the
  # model's reading and tags them.
  nArmsTable <- nrow(x$arms)
  cellsPer <- vapply(byRow, function(i) sum(!is.na(d$MEAN[i])), integer(1))
  short <- names(cellsPer)[cellsPer > 0 & cellsPer < nArmsTable]
  if (length(short) && nArmsTable >= 2)
    flags <- c(flags, paste0(length(short), " variable(s) carry fewer cells ",
                             "than the table has arms - a cell the reader ",
                             "dropped, or a variable the page reports for ",
                             "fewer arms: ",
                             paste0(short, " (", cellsPer[short], " of ",
                                    nArmsTable, ")", collapse = ", ")))
  degenerate <- names(byRow)[vapply(byRow, isDegenerate, logical(1))]
  if (length(degenerate))
    flags <- c(flags, paste0(length(degenerate), " variable(s) print the same ",
                             "value with no dispersion in every arm, or a ",
                             "median pinned at its quartile in every arm - ",
                             "fixed by design or by a floor, not a sample; ",
                             "consider removing before analysis: ",
                             paste(degenerate, collapse = ", ")))
  # DUPLICATED TUPLES (same source). Two variables printing identical N,
  # mean and SD in every arm are either one row read twice - which adds
  # fabricated agreement to a homogeneity test - or the table as printed:
  # in the retracted Saitoh trials BJA2001_814 and CJA2003_342, Age and
  # Weight print the same numbers, faithfully. The corpus session showed
  # both occur, so this is a flag and never an assertion: the reader is
  # told which rows agree and decides. (The hybrid merge already drops a
  # model row whose values duplicate a deterministic row's; this catches
  # what one engine produced, and what the page itself printed.)
  contI <- which(!is.na(d$MEAN) & !is.na(d$SD))
  if (length(contI)) {
    sig <- vapply(split(contI, d$ROW[contI]), function(i)
      paste(sort(paste(d$N[i], d$MEAN[i], d$SD[i], sep = "/")), collapse = " | "),
      character(1))
    dupSig <- unique(sig[duplicated(sig)])
    if (length(dupSig)) {
      groups <- vapply(dupSig, function(s) paste(names(sig)[sig == s], collapse = " = "),
                       character(1))
      flags <- c(flags, paste0(length(groups), " set(s) of variables print ",
                               "identical N, mean and SD in every arm - a row ",
                               "read twice, or the table as printed (both ",
                               "happen); check the page: ",
                               paste(groups, collapse = "; ")))
    }
  }
  # Recovered arm sizes are usable but not the same thing as an N printed in
  # the table header: say where each one came from, so a human can verify it
  # - a text-recovered N against the CONSORT flow diagram in particular
  # (2026-08-21, armNRecovery.R).
  if (!is.null(x$armNSource) && any(!is.na(x$armNSource))) {
    src      <- x$armNSource[!is.na(x$armNSource)]
    fromText <- grepl("^document text", src)
    if (any(!fromText))
      flags <- c(flags, paste0(sum(!fromText), " arm size(s) derived from ",
                               "the table's own printed n (%) or a/b fraction ",
                               "cells"))
    if (any(fromText))
      flags <- c(flags, paste0(sum(fromText), " arm size(s) recovered from ",
                               "the document text - verify against the ",
                               "CONSORT flow diagram: ",
                               paste(src[fromText], collapse = " | ")))
  }
  # Counts converted from printed percentages are usable but derived: the
  # percentage and the arm N pinned a unique integer, but no count is
  # printed on the page. Say which rows, so a human can check them
  # (2026-08-21, the percent-block conversion).
  if (!is.null(x$derivedCounts) && length(x$derivedCounts) > 0)
    flags <- c(flags, paste0(length(x$derivedCounts), " category row(s) ",
                             "converted from printed percentages via the ",
                             "arm N (unique-count bracket): ",
                             paste(x$derivedCounts, collapse = ", ")))
  # FAIL-SAFE conversions (pctApprox = TRUE; Steve, 2026-09-07, rule
  # replaced 2026-09-08). The printed percentage fit several counts for
  # the arm size. Every whole arms-by-levels table the page allows is
  # enumerated, the least alike of them are scored with the engine's own
  # statistic, and the one analysed is the BEST CASE - the largest p, the
  # reading most favourable to the authors. A design decision for
  # incomplete data, not a datum: the printed counts would settle it.
  #
  # "of the readings scored", not "of every reading" (security screens
  # 2026-09-08-2100 and 2026-09-09-0721, F1): scoring every reading is
  # what made an ordinary Table 1 unparseable, and a flag is not the
  # place to keep a guarantee the engine no longer gives.
  if (!is.null(x$approxCounts) && length(x$approxCounts) > 0)
    flags <- c(flags, paste0(length(x$approxCounts), " category row(s) use ",
                             "FAIL-SAFE counts - the printed percentage fit ",
                             "several counts for the arm size, so of the ",
                             "readings the page allows that were scored, ",
                             "the one with the LARGEST p was taken, giving ",
                             "the authors the benefit of the doubt: ",
                             paste(x$approxCounts, collapse = ", "),
                             ". Check these against the paper before ",
                             "analyzing."))
  # Only when the choice decided the answer (Steve, 2026-09-08: "worst
  # case only appearing if it straddles 0.01"). Saying it on every
  # fail-safe row would train the reader to skip it.
  if (!is.null(x$approxStraddle) && length(x$approxStraddle) > 0)
    flags <- c(flags, paste0(length(x$approxStraddle), " of those row(s) ",
                             "cross p = 0.01 between the best and the worst ",
                             "reading the page allows, so the printed counts ",
                             "decide this row and the percentages do not: ",
                             paste(x$approxStraddle, collapse = ", "),
                             ". Get the counts from the authors before ",
                             "acting on this trial."))
  # UNRESOLVED rows (audit 2026-09-09, F1 and F8; Steve Shafer's
  # decision: "Skip"). The search is complete or it does not happen, so
  # there is no "best of a bounded search" to report - those cells are
  # blank and the row is not analysed.
  if (!is.null(x$approxUnresolved) && length(x$approxUnresolved) > 0)
    flags <- c(flags, paste0(length(x$approxUnresolved), " category row(s) ",
                             "could NOT be read as counts and are left ",
                             "blank, so they are not analysed: ",
                             paste(sprintf("%s (%s)", names(x$approxUnresolved),
                                           x$approxUnresolved),
                                   collapse = "; "),
                             ". Enter the printed counts to analyse them."))
  disp <- if ("SE" %in% names(x$data))
    !is.na(x$data$SD) | !is.na(x$data$SE) else !is.na(x$data$SD)
  cont <- !is.na(x$data$MEAN) | disp
  if (any(cont & (is.na(x$data$MEAN) | !disp)))
    flags <- c(flags,
               "a continuous row is missing its mean or its SD/SE")
  # A standard error is not interchangeable with a standard deviation, and the
  # conversion needs N. Say so rather than letting it pass silently.
  if ("SE" %in% names(x$data) && any(!is.na(x$data$SE)))
    flags <- c(flags, paste(sum(!is.na(x$data$SE)),
                            "row(s) report a standard error, not an SD -",
                            "converting needs N and is the analysis's decision"))
  if (!is.null(x$dispersion) && grepl("assumed", x$dispersion))
    flags <- c(flags, paste0("the table does not say whether its dispersion is",
                             " an SD or an SE; recorded as SD"))
  flags
}

#' Parse the baseline demographic table of a trial document
#'
#' Reads the baseline characteristics table ("Table 1") out of a randomized
#' controlled trial and returns it as one line per baseline variable per
#' treatment arm, in the input layout of the Integrity-Analysis app. The
#' document may be a PDF, a Word manuscript (`.docx`) or JATS XML (`.xml`);
#' the file extension selects the reader.
#'
#' The deterministic engine ([parseBaselineTableHeuristics()]) always runs
#' first and its rows always win. What happens next depends on `ai`:
#'
#' * `"fallback"` (the default) consults the Claude API only when the
#'   deterministic pass left something unread - see [reviewFlags()] - and adds
#'   only those variables the deterministic pass did not produce. It never
#'   overwrites a value that was located on the page by coordinate.
#' * `"never"` is purely deterministic: no network call is made under any
#'   circumstance. Use this when the provenance of every number has to be
#'   mechanical, or when there is no API key.
#' * `"always"` skips the deterministic pass and asks the model to read the
#'   whole table. Useful for comparing the two engines against each other.
#'   A model variable whose label names an outcome rather than a baseline
#'   characteristic is refused on this route as on the fallback (it goes to
#'   `$skipped` with its reason, and a flag names it).
#'
#' `.docx` and `.xml` are an exception to all three: the AI engine reads
#' RENDERED PDF PAGES, which neither format has. For those two, `ai` is
#' forced to `"never"` with a message and parsing proceeds deterministically
#' — including when `"always"` was asked for. Failing outright instead would
#' be worse: a mixed folder uploaded with the assist on would lose its Word
#' and XML files for no reason.
#'
#' If no table can be read by either engine and `prose = TRUE`, a last attempt
#' asks the model to find baseline characteristics in the article's running
#' text. Some trials never tabulate them — age, weight and sex appear in a
#' sentence in the Methods — and in a 250-article sample about a third of the
#' articles nothing could be extracted from were of that kind.
#'
#' Rows are tagged in `$provenance` with the engine that produced them, and
#' [writeIntegrityTemplate()] carries that tagging into the spreadsheet.
#'
#' @inheritParams parseBaselineTableHeuristics
#' @param ai When to consult the Claude API: `"fallback"`, `"never"`, or
#'   `"always"`. See Details.
#' @param prose When no table can be read at all, ask the model for baseline
#'   data stated in the article's running text — some trials report age,
#'   weight and sex in a sentence rather than tabulating them. Only reached
#'   when `ai` is not `"never"` and the table routes have both failed. Rows
#'   found this way are tagged `"ai-prose"` in `$provenance`.
#' @param model,effort,maxTokens,apiKey Passed to [parseBaselineTableAI()].
#' @param tatr `"auto"` (the default) brings in the Table Transformer's
#'   geometry when the text engine fails, provided a `tatrXml` is given or
#'   the pegged Python environment is present (see `R/parseTatr.R`);
#'   `"always"` also compares it against a successful text parse and keeps
#'   the better; `"never"` leaves it out.
#' @param tatrXml Path to the Table Transformer XML for this PDF (a
#'   `*.tatr.xml` written by `python/tatr/tatrTables.py`), or a directory
#'   holding `<stem>.tatr.xml`. When `NULL`, the model is run if available.
#' @param durations `"include"` (the default) keeps the rows a baseline
#'   table prints for post-randomisation quantities - durations of surgery
#'   and of anaesthesia, blood loss, fluids given - and flags them;
#'   `"exclude"` moves them to `$skipped` with the reason. Whether they
#'   belong is a trial-by-trial judgement: randomised at induction they are
#'   measured after the intervention; randomised after surgery (a
#'   postoperative analgesia trial) they precede it like any other baseline
#'   variable. The app offers the same choice when a table prints them.
#'
#' @return An object of class `ParsePDFTable`. `$engine` is `"heuristic"`,
#'   `"ai"`, or `"hybrid"`; `$provenance` records the engine per row; and
#'   `$flags` records why the fallback was consulted, if it was.
#'
#' @examples
#' \dontrun{
#' # Deterministic only - no network call, fully reproducible
#' res <- parseBaselineTable("trial.pdf", ai = "never")
#' res
#' res$data
#'
#' # Let the model fill in what the heuristics could not read
#' res <- parseBaselineTable("trial.pdf")
#' subset(res$provenance, ENGINE == "ai")
#'
#' writeIntegrityTemplate(res, "trial.xlsx")
#' }
#' @export
parseBaselineTable <- function(pdfFile,
                               trial         = tools::file_path_sans_ext(basename(pdfFile)),
                               pages         = NULL,
                               ai            = c("fallback", "never", "always"),
                               prose         = TRUE,
                               parenIsSD     = c("auto", "sd", "percent"),
                               roundObsDelta = 1,
                               pctApprox     = FALSE,
                               model         = .ppDefaultModel,
                               effort        = "medium",
                               maxTokens     = 16000L,
                               apiKey        = NULL,
                               tatr          = c("auto", "never", "always"),
                               tatrXml       = NULL,
                               quiet         = FALSE,
                               durations     = c("include", "exclude"))
{
  # The routes live in .ppParseBaselineTableCore(); the `durations` option
  # (issue 74) is applied to whatever route produced the table, so the
  # deterministic, hybrid and model-only readings of one document agree
  # on which rows the screen counts.
  durations <- match.arg(durations)
  out <- .ppParseBaselineTableCore(pdfFile, trial = trial, pages = pages, ai = ai,
                                   prose = prose, parenIsSD = parenIsSD,
                                   roundObsDelta = roundObsDelta, pctApprox = pctApprox,
                                   model = model, effort = effort, maxTokens = maxTokens,
                                   apiKey = apiKey, tatr = tatr, tatrXml = tatrXml,
                                   quiet = quiet)
  .ppApplyDurations(out, durations, function(...) if (!quiet) message(...))
}

.ppParseBaselineTableCore <- function(pdfFile,
                               trial         = tools::file_path_sans_ext(basename(pdfFile)),
                               pages         = NULL,
                               ai            = c("fallback", "never", "always"),
                               prose         = TRUE,
                               parenIsSD     = c("auto", "sd", "percent"),
                               roundObsDelta = 1,
                               pctApprox     = FALSE,
                               model         = .ppDefaultModel,
                               effort        = "medium",
                               maxTokens     = 16000L,
                               apiKey        = NULL,
                               tatr          = c("auto", "never", "always"),
                               tatrXml       = NULL,
                               quiet         = FALSE)
{
  ai        <- match.arg(ai)
  parenIsSD <- match.arg(parenIsSD)
  tatr      <- match.arg(tatr)
  say <- function(...) if (!quiet) message(...)

  # ---- The Table Transformer seam (R/parseTatr.R, 2026-09-02) -------------
  # Geometry from the model, characters from the text layer or from OCR.
  # A rescue tier: it engages when the text engine fails (or on request),
  # and only where an XML is supplied or the pegged Python is present -
  # everywhere else this function behaves exactly as before. The model
  # is run at most once per call, lazily, in a subprocess under a timeout.
  tatrPath <- NULL; tatrTried <- FALSE
  # When the runner produced the XML, its work directory (the copied PDF,
  # the list, the XML) is removed as this call returns - not left for
  # session cleanup (CodeRabbit on #147; the batcher's children already
  # have a parent-owned tempdir, this covers a direct call).
  tatrSource <- function() {
    if (tatrTried) return(tatrPath)
    tatrTried <<- TRUE
    if (!is.null(tatrXml)) {
      p <- if (dir.exists(tatrXml))
        file.path(tatrXml, paste0(tools::file_path_sans_ext(basename(pdfFile)), ".tatr.xml"))
      else tatrXml
      tatrPath <<- if (file.exists(p)) p else NULL
    } else if (.ppTatrAvailable()) {
      tatrPath <<- .ppTatrRun(pdfFile, quiet = quiet)
      if (!is.null(tatrPath)) tatrWork <<- dirname(dirname(tatrPath))
    }
    tatrPath
  }
  tatrWork <- NULL
  on.exit(if (!is.null(tatrWork)) unlink(tatrWork, recursive = TRUE, force = TRUE),
          add = TRUE)
  tatrNote <- paste("table geometry from the Table Transformer (rows and",
                    "columns located by the model; every value read from",
                    "the document)")
  # The parse is memoised per OCR mode, as the XML is: the rescue chain
  # asks for it twice (on the text engine's error, then again inside the
  # OCR rescue), and without the memo a degraded scan was rendered and
  # OCRed through the model twice before plain OCR ran a third time -
  # more than the parse child's budget on a host that runs the model
  # (screen 2026-09-03, F2). A NULL answer is memoised too.
  tatrMemo <- list()
  tatrParse <- function(ocrMode = "auto") {
    if (!is.null(tatrMemo[[ocrMode]])) return(tatrMemo[[ocrMode]]$value)
    r <- tatrParseOnce(ocrMode)
    tatrMemo[[ocrMode]] <<- list(value = r)
    r
  }
  tatrParseOnce <- function(ocrMode = "auto") {
    xml <- tatrSource()
    if (is.null(xml)) return(NULL)
    r <- tryCatch(
      parseBaselineTableTatr(pdfFile, xml, trial = trial, parenIsSD = parenIsSD,
                             roundObsDelta = roundObsDelta, pctApprox = pctApprox,
                             ocr = ocrMode, quiet = quiet),
      error = function(e) { say("Table Transformer: ", conditionMessage(e)); NULL })
    if (is.null(r)) return(NULL)
    # The OCR rescue's quality gate, applied here too: a pairing result
    # with no arm name and no arm N cannot be analysed and would only
    # erode trust surfaced as a cyan table. Measured 2026-09-02 on the
    # scanned corpus set: 18 pairing results, none with two arm Ns, one
    # with a continuous row - fragments, not tables. Gate them.
    if (identical(r$engine, "heuristic-tatr-ocr") &&
        !(any(!is.na(r$arms$arm) & nzchar(r$arms$arm)) || any(!is.na(r$arms$N)))) {
      say("Table Transformer + OCR found a table but could not read any arm ",
          "name or arm N - the scan is too degraded for OCR.")
      return(NULL)
    }
    r$flags <- c(tatrNote,
                 if (identical(r$engine, "heuristic-tatr-ocr"))
                   paste("scanned page(s) read by local OCR - OCR can misread",
                         "digits, so verify every value against the manuscript"),
                 reviewFlags(r))
    r
  }

  # The AI fallback renders PDF pages (parseBaselineTableAI), which a
  # .docx does not have. Proceed deterministically with a note rather
  # than erroring: with the BYOK assist (issue 8) a mixed folder upload
  # legitimately arrives here with ai = "fallback", and a docx failing
  # OUTRIGHT because the assist was on would be strictly worse than the
  # docx parse the user gets with it off.
  # .xml is here for the same reason (issue 29, found by CodeRabbit on
  # PR #129): JATS has no pages to render either, and without this an
  # ai = "always" call would reach parseBaselineTableAI() and fail
  # having never tried the JATS parser at all.
  if (grepl("[.](docx|xml)$", pdfFile, ignore.case = TRUE) && ai != "never") {
    say("The AI fallback reads rendered PDF pages, which a ",
        if (grepl("[.]xml$", pdfFile, ignore.case = TRUE)) ".xml" else ".docx",
        " does not have - parsing this file deterministically.")
    ai <- "never"
  }

  # A table image (2026-09-02): the deterministic pass IS an OCR pass, so
  # the OCR rescue below has nothing to add and the prose route has no
  # prose to read; and only what the Messages API accepts as an image
  # block can take the AI route - JPEG, PNG and GIF under its size
  # limits. A TIFF, or an oversized picture, is parsed deterministically
  # with a note rather than failing outright.
  isImage <- .ppIsImageFile(pdfFile)
  if (isImage && ai != "never") {
    why <- .ppImageAiRefusal(pdfFile)
    if (!is.null(why)) {
      say(why, " - parsing this image deterministically.")
      ai <- "never"
    }
  }

  # ---- AI-only path -------------------------------------------------------
  # THE OUTCOME REFUSAL APPLIES HERE TOO (2026-09-25, ISSUES.md issue 66; the
  # corpus session's batch 13 R2, PMID 9542558): the batches use this route
  # as their retry, and on it the model's reading kept Table 2's operative
  # management beside Table 1's rows. Same helper as the retry route.
  if (ai == "always")
    return(.ppRefuseModelOutcomes(
      parseBaselineTableAI(pdfFile, trial = trial, pages = pages,
                           model = model, effort = effort,
                           maxTokens = maxTokens,
                           roundObsDelta = roundObsDelta,
                           apiKey = apiKey, quiet = quiet),
      say))

  # ---- Deterministic pass, always first -----------------------------------
  het <- tryCatch(
    parseBaselineTableHeuristics(pdfFile, trial = trial, pages = pages,
                                 parenIsSD = parenIsSD,
                                 roundObsDelta = roundObsDelta,
                                 pctApprox = pctApprox, quiet = quiet),
    error = function(e) e)

  # Tier 2 of issue 22: when the failed document has image-only pages -
  # scanned pages, or tables pasted in as pictures - and the AI route is
  # unavailable or also failed, retry those pages through the SAME
  # deterministic engine on tesseract word boxes (.ppOcrData). Local,
  # free, offline; but OCR misreads digits (3/8, 1/7), so the result's
  # "ocr" provenance makes the app shade the whole table cyan with a
  # verify-every-cell note. With a key present the AI image route (tier
  # 1) runs first - a model reads a page picture better than OCR.
  ocrRescue <- function() {
    if (isImage) return(NULL)   # the deterministic pass already read pixels
    if (!requireNamespace("tesseract", quietly = TRUE)) return(NULL)
    imgs <- tryCatch(.ppImageOnlyPages(.ppPdfText(pdfFile)),
                     error = function(e) integer(0))
    if (length(imgs) == 0) return(NULL)
    # The pairing first: the model's geometry with tesseract's characters.
    # Arm 1 of the OCR measurement (2026-09-02) found the dominant failure
    # of plain OCR to be aiming at the WRONG TABLE, not misread digits -
    # which is the failure geometry from the model addresses.
    if (tatr != "never") {
      tt <- tatrParse("auto")
      if (!is.null(tt) && (any(!is.na(tt$arms$arm) & nzchar(tt$arms$arm)) ||
                           any(!is.na(tt$arms$N))))
        return(tt)
    }
    say("Page(s) ", paste(imgs, collapse = ","), " are scanned images; ",
        "retrying them with local OCR (tesseract) ...")
    # OCR only the image pages (their captions are part of the picture);
    # OCRing a 30-page preprint end to end would cost minutes for pages
    # the text engine already read.
    r <- tryCatch(
      parseBaselineTableHeuristics(pdfFile, trial = trial,
                                   pages = if (is.null(pages)) imgs else pages,
                                   parenIsSD = parenIsSD,
                                   roundObsDelta = roundObsDelta,
                                   pctApprox = pctApprox,
                                   ocr = TRUE, quiet = quiet),
      error = function(e) {
        say("The OCR retry also failed (", conditionMessage(e), ").")
        NULL
      })
    # Quality gate: on a degraded scan OCR can "succeed" into noise -
    # garbled labels, junk values, and no arm identity (live example
    # 2026-08-26: medRxiv 10.1101/19007195, 34 of 286 cells filled,
    # every arm nameless and N-less, values like 72087). Without any
    # arm identity the analysis can never run, so surfacing the table
    # would only erode trust. The AI image route reads the same page
    # correctly; point there instead.
    if (!is.null(r)) {
      armKnown <- any(!is.na(r$arms$arm) & nzchar(r$arms$arm)) ||
        any(!is.na(r$arms$N))
      if (!armKnown) {
        say("OCR found a table but could not read any arm name or arm ",
            "N - the scan is too degraded for OCR. An Anthropic API ",
            "key would let the AI assist read the page image instead.")
        return(NULL)
      }
      r$flags <- paste("scanned page(s) read by local OCR - OCR can",
                       "misread digits, so verify every value against",
                       "the manuscript")
    }
    r
  }

  if (inherits(het, "error")) {
    # The text engine found nothing: the model's geometry over the same
    # text layer is the cheapest second opinion, free and offline.
    if (tatr != "never") {
      tt <- tatrParse("auto")
      if (!is.null(tt)) return(tt)
    }
    if (ai == "never") {
      ocr <- ocrRescue()
      if (!is.null(ocr)) return(ocr)
      stop(het)
    }
    say("Deterministic parse failed (", conditionMessage(het),
        "); falling back to ", model, ".")
    out <- tryCatch(
      parseBaselineTableAI(pdfFile, trial = trial, pages = pages,
                           source = "table", model = model, effort = effort,
                           maxTokens = maxTokens,
                           roundObsDelta = roundObsDelta,
                           apiKey = apiKey, quiet = quiet),
      error = function(e) e)

    # Some trials never tabulate their baseline data - age, weight and sex are
    # given in a sentence in the Methods instead. In a 250-article sample,
    # about a third of the articles nothing could be extracted from were of
    # that kind, so when no table can be read anywhere, ask for the prose.
    if (inherits(out, "error") && prose && !isImage) {
      say("No table could be read (", conditionMessage(out),
          "); asking ", model, " for baseline data stated in the text.")
      out <- tryCatch(
        parseBaselineTableAI(pdfFile, trial = trial, source = "prose",
                             model = model, effort = effort,
                             maxTokens = maxTokens,
                             roundObsDelta = roundObsDelta,
                             apiKey = apiKey, quiet = quiet),
        error = function(e) e)
    }
    if (inherits(out, "error")) {
      # every AI route failed (bad key, network, refusal, nothing found);
      # a scanned page may still yield to local OCR before giving up
      ocr <- ocrRescue()
      if (!is.null(ocr)) return(ocr)
      stop(out)
    }
    out$flags <- c(paste0("deterministic parse failed: ", conditionMessage(het)),
                   out$flags)           # the model route's own flags (issue 42)
    # THE REFUSAL OF OUTCOME VARIABLES APPLIES HERE TOO (2026-09-25, ISSUES.md
    # issue 64; the corpus session's P2, PMID 9773135): with no deterministic
    # table beside it, the model's page reading carried Table 2's operative
    # management (duration of surgery, I-D interval, tubal ligation) beside
    # Table 1's rows, and nothing refused them (p 0.24 -> 0.039). There is
    # no block text on this route, so the vocabulary alone decides; a
    # refused row goes to $skipped with its reason and a flag names it.
    # Shared with the explicit ai = "always" route since issue 66.
    out <- .ppRefuseModelOutcomes(out, say)
    return(out)
  }

  # tatr = "always": the text engine succeeded, but the caller wants the
  # model's reading compared - keep whichever parses better. The model's
  # own provenance notes (geometry from the model; OCR if it read pixels)
  # ride along under `tatrFlags`, ahead of the review flags every return
  # below rebuilds - otherwise the replacement silently lost them
  # (CodeRabbit on #147).
  tatrFlags <- NULL
  if (tatr == "always") {
    tt <- tatrParse("auto")
    # The caption rule (whole-corpus comparison, 2026-09-03): by parse
    # score alone the model's reading won 441 of 1,654 articles both
    # engines parsed, and a share of those wins were a DIFFERENT table -
    # a results or outcomes table the model read fluently, displacing
    # the text engine's captioned baseline table. Parse score measures
    # how well a table was read, not which table it is. So the model
    # replaces the text engine only when its own caption is at least as
    # convincing: a strong caption (score >= 3, the threshold the
    # candidate ordering uses on every route) is never displaced by a
    # weaker one, and when neither or both are strong the parse score
    # decides as before.
    if (!is.null(tt)) {
      capText <- .ppCaptionScoreOf(het$caption)
      capTatr <- .ppCaptionScoreOf(tt$caption)
      better  <- .ppParseScore(tt) > .ppParseScore(het)
      displaces <- !(capText >= 3 && capTatr < 3)
      if (better && displaces) {
        say("Keeping the Table Transformer reading (parse score ",
            round(.ppParseScore(tt), 1), " vs ", round(.ppParseScore(het), 1), ").")
        tatrFlags <- setdiff(tt$flags, reviewFlags(tt))
        het <- tt
      } else if (better) {
        say("The Table Transformer read a table better (parse score ",
            round(.ppParseScore(tt), 1), " vs ", round(.ppParseScore(het), 1),
            ") but its caption does not announce a baseline table and the ",
            "text engine's does - keeping the text engine's table.")
      }
    }
  }

  flags <- reviewFlags(het)
  # A picture was read by OCR end to end, so it carries the same
  # verify-every-value note the scanned-page rescue attaches (the app
  # shades on engine, but API and console callers see only the flags).
  # Kept apart from `flags`: the note is not a gap for the AI assist to
  # fill, and must not trigger a consult on its own.
  imageNote <- if (isImage)
    paste("picture read by local OCR - OCR can misread digits, so verify",
          "every value against the original")
  het$flags <- c(imageNote, tatrFlags, flags)
  if (ai == "never" || length(flags) == 0) return(het)

  if (!claudeAvailable() && is.null(apiKey)) {
    say("The deterministic parse left ", length(flags), " issue(s) open, but ",
        "ANTHROPIC_API_KEY is not set - returning the deterministic result. ",
        "Review $skipped by hand.")
    return(het)
  }

  # ---- AI fallback for what the heuristics could not read -----------------
  say("Deterministic parse left ", length(flags),
      " issue(s) open; consulting ", model, " for the rest:")
  for (f in flags) say("  - ", f)

  hint <- paste0(
    "Arms already identified: ",
    paste(sprintf("%s (n = %s)", het$arms$arm,
                  ifelse(is.na(het$arms$N), "unknown", het$arms$N)),
          collapse = "; "),
    ". Variables already read: ",
    paste(unique(het$data$ROW), collapse = "; "), ".")

  aiRes <- tryCatch(
    parseBaselineTableAI(pdfFile, trial = trial, pages = het$pages,
                         model = model, effort = effort, maxTokens = maxTokens,
                         roundObsDelta = roundObsDelta, hint = hint,
                         apiKey = apiKey, quiet = quiet),
    error = function(e) e)

  if (inherits(aiRes, "error")) {
    say("The AI fallback failed (", conditionMessage(aiRes),
        "); returning the deterministic result.")
    het$flags <- c(imageNote, tatrFlags, flags,
                   paste0("AI fallback failed: ", conditionMessage(aiRes)))
    return(het)
  }

  # Merge: keep every deterministic row, add only variables the deterministic
  # pass never produced. Comparison is on the squished, case-folded label so
  # that "Age, yr" and "age, yr" are recognized as the same variable.
  key      <- function(v) tolower(.ppSquish(v))
  haveRows <- unique(key(het$data$ROW))
  newRows  <- aiRes$data[!key(aiRes$data$ROW) %in% haveRows, , drop = FALSE]

  # The model names variables its own way - "Weight" for the printed
  # "Weight, kg", "Sex" for "Female sex" - so a label comparison alone
  # re-adds nearly every variable under a synonym: 20 duplicate lines on
  # one real PDF (2026-08-25), and DUPLICATED variables would inflate
  # the Stouffer combination. Values are the identity that labels are
  # not: a candidate variable whose per-arm numbers already appear under
  # some deterministic variable IS that variable, whatever either side
  # called it. (Two genuine variables with identical values would be
  # wrongly deduped - vastly rarer, and the safe direction for a fraud
  # screen: rather one missing duplicate than one double-counted.)
  rowSig <- function(d) {
    catCols <- setdiff(names(d), c(.ppBaseColumns(), "Q1", "Q3"))
    vapply(split(d, d$ROW), function(g) {
      if (any(!is.na(g$MEAN)))
        paste(sort(paste(g$N, g$MEAN, g$SD, g$SE, sep = "/")),
              collapse = " | ")
      else {
        v <- unlist(g[intersect(catCols, names(g))])
        paste(sort(v[!is.na(v)]), collapse = ",")
      }
    }, character(1))
  }
  # CONTINUOUS VARIABLES ARE COMPARED ARM BY ARM, NOT AS A WHOLE
  # (2026-09-25, issue 37; the corpus session's F3, G1 and H2). The
  # whole-signature comparison above matched only when both sides had
  # read the SAME arms. A deterministic row that read two of three arms
  # ("Height; cm" on Anaesthesia2002_218, one of two on Akkus 2020) never
  # matched the model's complete row, and both survived: the variable
  # twice, once under each name - and on PMID 9602596 every variable of
  # the table, doubled. So: a model variable IS a deterministic variable
  # when every deterministic arm tuple (MEAN, SD, SE) appears among the
  # model's, with N compared only where both sides have one. Then the
  # model's row is dropped as before, and two things the finding asked
  # for happen under the DETERMINISTIC label: an arm the deterministic
  # pass had with no N takes the model's N (flagged as recovered), and
  # arms the deterministic pass did not read at all are appended from the
  # model, tagged "ai". Categorical variables keep the whole-signature
  # rule (their levels are the identity).
  valKey <- function(t) paste(t$MEAN, t$SD, t$SE, sep = "/")
  contOf <- function(d) {
    cont <- d[!is.na(d$MEAN), , drop = FALSE]
    if (!nrow(cont)) return(list())
    split(seq_len(nrow(d))[!is.na(d$MEAN)], cont$ROW)   # row indices into d, by ROW
  }
  # ARMS ARE MATCHED ONE TO ONE, AND KEPT IN THE MODEL'S ORDER (CodeRabbit
  # on PR #340). Two arms can print the same mean and SD, so each
  # deterministic arm claims ONE unused model arm with the same values -
  # preferring the one whose N agrees when both are known - and a model
  # arm claimed by nobody is the arm the deterministic pass did not read.
  # The template's arms are positional (a variable's lines are its arms
  # left to right), so a recovered arm cannot simply be appended: the
  # variable's lines are rebuilt in the model's arm order, each line
  # taken from the deterministic side where matched and from the model
  # where not, and put back where the variable's lines were.
  hetT  <- contOf(het$data); candT <- contOf(newRows)
  dropRows <- character(0); nFilled <- character(0); recovered <- character(0)
  rebuilt <- list()   # [[hn]] = the variable's lines, in the model's order
  # THE SAME VARIABLE UNDER A LABEL SUFFIX, ONE CELL APART (2026-09-25,
  # ISSUES.md issue 52; the corpus session's K3, CJA 1997;44:390): the
  # table's "Weight" and the model's "Weight - kg" hold the same six cells
  # but one - the page prints "57.9 ± 64", a missing decimal point, which
  # the table's reading takes as 6.4 and the model as 64.0 - so the value
  # signature does not match and both survived, the variable counted
  # twice. Two variables whose labels agree once a trailing unit or
  # suffix is set aside (", kg", "- kg", "(kg)", "; cm") and whose cells
  # agree in at least half the arms are one variable: the table's own
  # reading is kept, the model's dropped, and the disagreeing cell named
  # for the reviewer.
  labKey <- function(v) tolower(.ppSquish(sub("\\s*[,;:(\u2013\u2014-]\\s*[^,;:()]{1,12}\\)?\\s*$", "", v)))
  labelPairs <- character(0)
  for (nm in names(candT)) {
    ci <- candT[[nm]]; ck <- valKey(newRows[ci, ])
    for (hn in names(hetT)) {
      hi <- hetT[[hn]]; hk <- valKey(het$data[hi, ])
      if (!all(hk %in% ck)) {
        if (labKey(nm) == labKey(hn) && length(hk) == length(ck) && mean(hk %in% ck) >= 0.5) {
          dropRows   <- c(dropRows, nm)
          labelPairs <- c(labelPairs, paste0("\"", nm, "\" = \"", hn, "\" (",
                                             sum(!(hk %in% ck)), " of ", length(hk),
                                             " cell(s) differ)"))
          break
        }
        next
      }
      used <- rep(FALSE, length(ci)); assign <- rep(NA_integer_, length(hi))
      for (r in seq_along(hi)) {
        cands <- which(!used & ck == hk[r])
        if (!length(cands)) break
        hN <- het$data$N[hi[r]]; cN <- newRows$N[ci][cands]
        agree <- !is.na(hN) & !is.na(cN) & cN == hN
        unknown <- is.na(hN) | is.na(cN)
        pick <- if (any(agree)) cands[agree][1] else if (any(unknown)) cands[unknown][1] else NA_integer_
        if (is.na(pick)) break
        assign[r] <- pick; used[pick] <- TRUE
      }
      if (anyNA(assign)) next
      dropRows <- c(dropRows, nm)
      lines <- vector("list", length(ci))
      for (j in seq_along(ci)) {
        r <- match(j, assign)
        if (!is.na(r)) {
          line <- het$data[hi[r], , drop = FALSE]
          if (is.na(line$N) && !is.na(newRows$N[ci[j]])) {
            line$N <- newRows$N[ci[j]]; nFilled <- c(nFilled, hn)
          }
        } else {
          line <- newRows[ci[j], , drop = FALSE]; line$ROW <- hn
          recovered <- c(recovered, hn)
        }
        lines[[j]] <- line
      }
      rebuilt[[hn]] <- .ppRbindFillAll(lines)
      break
    }
  }
  if (length(rebuilt)) {
    # put each rebuilt variable back where its lines were, in the model's
    # arm order; other variables keep their place
    firstAt <- vapply(names(rebuilt), function(hn) min(hetT[[hn]]), integer(1))
    keep <- !(het$data$ROW %in% names(rebuilt)) | is.na(het$data$MEAN)
    pieces <- list(); pos <- 0L
    for (hn in names(rebuilt)[order(firstAt)]) {
      at <- firstAt[[hn]]
      if (at > pos + 1L) pieces[[length(pieces) + 1L]] <- het$data[seq(pos + 1L, at - 1L), , drop = FALSE][keep[seq(pos + 1L, at - 1L)], , drop = FALSE]
      pieces[[length(pieces) + 1L]] <- rebuilt[[hn]]
      pos <- max(hetT[[hn]])
    }
    if (pos < nrow(het$data)) pieces[[length(pieces) + 1L]] <- het$data[seq(pos + 1L, nrow(het$data)), , drop = FALSE][keep[seq(pos + 1L, nrow(het$data))], , drop = FALSE]
    het$data <- .ppRbindFillAll(pieces)
    rownames(het$data) <- NULL
  }
  fillRows <- list()
  hetSig  <- rowSig(het$data)
  candSig <- rowSig(newRows)
  catDup  <- names(candSig)[candSig %in% hetSig & nzchar(candSig) &
                              !(names(candSig) %in% names(candT))]
  dupRows <- unique(c(dropRows, catDup))
  if (length(dupRows) > 0) {
    say("Dropping ", length(dupRows), " model variable(s) whose values ",
        "duplicate deterministic rows under another name: ",
        paste(dupRows, collapse = ", "))
    newRows <- newRows[!newRows$ROW %in% dupRows, , drop = FALSE]
  }
  if (length(nFilled)) {
    nFilled <- unique(nFilled)
    say("Arm N taken from the model for ", length(nFilled), " variable(s) the ",
        "deterministic pass read without one: ", paste(nFilled, collapse = ", "))
    flags <- c(flags, paste0("arm N for ", length(nFilled), " variable(s) taken ",
                             "from the model where the table's own reading had ",
                             "none - verify against the header: ",
                             paste(nFilled, collapse = ", ")))
  }
  if (length(labelPairs)) {
    say("Dropping ", length(labelPairs), " model variable(s) that are the table's ",
        "own under a label suffix, with a differing cell: ",
        paste(labelPairs, collapse = "; "))
    flags <- c(flags, paste0(length(labelPairs), " model variable(s) matched the ",
                             "table's own reading under a label suffix but differ in ",
                             "a cell - check that cell against the printed table: ",
                             paste(labelPairs, collapse = "; ")))
  }
  if (length(recovered)) {
    say("Adding ", length(recovered), " arm line(s) from ", model, " under ",
        "deterministic variable(s) the table's own reading had only partly: ",
        paste(unique(recovered), collapse = ", "))
    het$provenance <- rbind(het$provenance,
                            data.frame(ROW = unique(recovered), ENGINE = "ai",
                                       stringsAsFactors = FALSE))
    flags <- c(flags, paste0(length(recovered), " arm line(s) for ",
                             paste(unique(recovered), collapse = ", "),
                             " taken from the model where the table's own ",
                             "reading had no cell - check them against the ",
                             "printed table"))
  }
  # A model level column that differs from a deterministic one only by
  # case or spacing is that column ("male" beside "Male" made two columns
  # that normalise to one, and the table was refused; Sener 2008 EJA).
  # A MODEL-ADDED VARIABLE THAT IS AN OUTCOME (2026-09-25, ISSUES.md issue
  # 54; the corpus session's L2: on Polat 2018 the model, asked for the
  # baseline table, also returned Tables 2-3 - "Time to T10", "Time to first
  # analgesic request", Bradycardia / Hypotension / Nausea / Pruritus - and
  # on Akkaya 2016 the VAS and ODI at every follow-up). The call is not
  # reproducible (thinking on), so a run may read every table on the page.
  # The deterministic table is the baseline table by caption; a variable
  # the model adds to it whose label carries outcome vocabulary is refused
  # with its reason, so a reviewer sees it in $skipped rather than in the
  # analysis. The vocabulary is the caption scorer's, plus the words of
  # block onset, analgesia, follow-up and adverse events.
  if (nrow(newRows) > 0) {
    isOutcome <- .ppOutcomeLabel(newRows$ROW, het$blockText)
    if (any(isOutcome)) {
      bad <- unique(newRows$ROW[isOutcome])
      say("Refusing ", length(bad), " model variable(s) whose label names an ",
          "outcome, not a baseline characteristic: ", paste(bad, collapse = ", "))
      het$skipped <- rbind(het$skipped,
                           data.frame(label = bad,
                                      reason = "model-added variable with outcome vocabulary - not a baseline characteristic; enter by hand if it is one",
                                      text = "", stringsAsFactors = FALSE))
      flags <- c(flags, paste0(length(bad), " model-added variable(s) refused as ",
                               "outcomes (see $skipped): ", paste(bad, collapse = ", ")))
      newRows <- newRows[!isOutcome, , drop = FALSE]
    }
  }
  hetCols <- names(het$data)
  for (cn in setdiff(names(newRows), hetCols)) {
    jj <- match(tolower(.ppSquish(cn)), tolower(.ppSquish(hetCols)))
    if (!is.na(jj)) names(newRows)[names(newRows) == cn] <- hetCols[jj]
  }

  if (nrow(newRows) == 0) {
    het$flags <- c(imageNote, tatrFlags, flags)
    # Arm lines or arm sizes taken from the model make the result a HYBRID
    # even when no whole variable was new: the provenance already names
    # the recovered rows "ai", and the engine label, the model's notes and
    # its reply must say so too (issue 51; before, a table completed from
    # the model's reading reported itself as "heuristic").
    if (length(recovered) || length(nFilled)) {
      say("The model added no variable, but completed ",
          length(unique(c(recovered, nFilled))), " of the table's own.")
      het$engine  <- "hybrid"
      het$notes   <- aiRes$notes
      het$aiReply <- aiRes$aiReply
      return(het)
    }
    say("The model found nothing the deterministic pass had missed.")
    return(het)
  }
  say("Adding ", nrow(newRows), " line(s) from ", model,
      " for: ", paste(unique(newRows$ROW), collapse = ", "),
      ". These are tagged \"ai\" in $provenance - check them against the ",
      "printed table.")

  merged <- .ppRbindFill(het$data, newRows)
  merged <- merged[, c(.ppBaseColumns(),
                       setdiff(names(merged), .ppBaseColumns())), drop = FALSE]

  # THE ROW FLAGS ARE RECOMPUTED ON THE MERGED TABLE (2026-09-25, ISSUES.md
  # issue 60; the corpus session's N4, PMID 15281514): the flags above were
  # read off the deterministic table before the model's rows joined it, so
  # a degenerate row the model added - eight "%Edi" rows at 100.0 +/- 0.0,
  # a normalised baseline fixed by construction - was never named. The
  # flags that describe rows (degenerate, duplicated tuples, SD above the
  # mean, a variable short of arms) are taken from reviewFlags() on the
  # merged result; the ones already present are kept once.
  out <- structure(
    list(data       = merged,
         arms       = het$arms,
         skipped    = het$skipped,
         provenance = rbind(het$provenance,
                            data.frame(ROW = newRows$ROW,
                                       ENGINE = rep("ai", nrow(newRows)),
                                       stringsAsFactors = FALSE)),
         pages      = het$pages,
         caption    = het$caption,
         trial      = trial,
         notes      = aiRes$notes,
         # the model's reply verbatim rides on the hybrid result too (the
         # corpus session's L1: issue 43 had reached only the AI-only route)
         aiReply    = aiRes$aiReply,
         blockText  = het$blockText,
         flags      = c(imageNote, tatrFlags, flags),
         # CARRIED THROUGH THE MERGE (2026-09-08). These were dropped
         # here, so a hybrid parse painted no fail-safe cell orange and
         # showed no hover note, even though the flag text above named
         # the rows. The heuristic half of a hybrid result is still the
         # half that read the percentages, so its record of what it
         # rebuilt is still the truth about those cells.
         approxCounts   = het$approxCounts,
         approxStraddle = het$approxStraddle,
         approxUnresolved = het$approxUnresolved,
         derivedCells   = het$derivedCells,
         derivedCounts  = het$derivedCounts,
         dispersion     = het$dispersion,
         engine     = "hybrid"),
    class = "ParsePDFTable")
  rowFlags <- grep("degenerate|identical N, mean and SD|SD larger than the mean|fewer cells than the table has arms|same value with no dispersion",
                   reviewFlags(out), value = TRUE)
  out$flags <- unique(c(out$flags, rowFlags))
  out
}

#' @export
print.ParsePDFTable <- function(x, ...) {
  cat("<ParsePDFTable>  trial: ", x$trial, "\n", sep = "")
  byModel <- !is.null(x$provenance) && any(grepl("^ai", x$provenance$ENGINE))
  cat("  engine : ", x$engine,
      if (byModel)
        paste0(" (", sum(grepl("^ai", x$provenance$ENGINE)), " of ",
               nrow(x$provenance), " lines read by the model)") else "",
      "\n", sep = "")
  if (identical(x$engine, "ai-prose"))
    cat("           values were read from running text, not a table\n")
  cat("  page(s): ",
      if (all(is.na(x$pages))) "whole article" else
        paste(x$pages, collapse = ", "), "\n", sep = "")
  if (!is.na(x$caption) && nzchar(x$caption))
    cat("  caption: ", substr(x$caption, 1, 60), "\n", sep = "")
  cat("  arms   : ", nrow(x$arms), " (",
      paste(sprintf("%s n=%s", x$arms$arm,
                    ifelse(is.na(x$arms$N), "?", x$arms$N)), collapse = ", "),
      ")\n", sep = "")
  cat("  lines  : ", nrow(x$data), " over ",
      length(unique(x$data$ROW)), " variable(s)\n", sep = "")
  if (!is.null(x$dispersion))
    cat("  spread : ", x$dispersion,
        if ("SE" %in% names(x$data) && any(!is.na(x$data$SE)))
          paste0(" (", sum(!is.na(x$data$SE)), " row(s) in the SE column)")
        else "", "\n", sep = "")
  if (nrow(x$skipped) > 0) {
    cat("  skipped: ", nrow(x$skipped), "\n", sep = "")
    for (i in seq_len(nrow(x$skipped)))
      cat("    - ", x$skipped$label[i], ": ", x$skipped$reason[i], "\n", sep = "")
  }
  if (!is.null(x$notes) && nzchar(x$notes))
    cat("  model notes: ", x$notes, "\n", sep = "")
  cat("Check the parsed values against the printed table before analyzing.\n")
  invisible(x)
}
