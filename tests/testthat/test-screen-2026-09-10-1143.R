# Adjudication of security screen 2026-09-10-1143 (over the range #252
# and #250 merged), finding F1 (MEDIUM): restored label-only rows widened
# the journal table past the cell gate.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fixes in R/app_globals.R (.iaJournalCells counts
# WIDTH; .iaWithExcluded gives the journal table one line per label),
# R/apiService.R, R/baselineTable.R and R/app_server.R (the app's
# downloads behind the same gate) and R/P_Calc.R (the observation). Per
# the standing rule in AGENTS.md the defect is reproduced THROUGH THE
# PATH THE REPORT NAMES - the screen's own probe, a 5,000-line CSV,
# through the upload reader and the API's analysis route, and the app's
# workbook writer - and checked to FAIL on a3fe636 (6.25 million cells,
# 28 s, an 18.8 MB journal CSV in the response).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

# the screen's probe: two valid Age lines, 2,499 label-only lines all
# named "A", 2,499 label-only lines with distinct names - 5,000 lines,
# about 90 KB, nothing for the engine to simulate but the two Age lines
probe <- function() {
  d <- data.frame(TRIAL = "T",
                  ROW = c("Age", "Age", rep("A", 2499L), paste0("L", seq_len(2499L))),
                  N = c(100, 100, rep(NA, 4998L)), MEAN = c(50, 50.2, rep(NA, 4998L)),
                  SD = c(3, 3.1, rep(NA, 4998L)), ROUND_MEAN = c(1, 1, rep(NA, 4998L)),
                  ROUND_OBSERVATION = c(0, 0, rep(NA, 4998L)),
                  ROUND_DISPERSION = c(1, 1, rep(NA, 4998L)), stringsAsFactors = FALSE)
  f <- file.path(tempdir(), "journal-width-probe.csv")
  utils::write.csv(d, f, row.names = FALSE)
  f
}

test_that("the estimator counts the table's width, not only its lines (screen 1143 F1)", {
  plain <- data.frame(TRIAL = "T", ROW = c("Age", "Age"), N = 50, MEAN = c(60, 61), SD = 10)
  expect_equal(.iaJournalCells(plain, character(0)), 2 * (1 + 2))
  rd <- .apiReadUpload(probe(), "journal-width-probe.csv")
  v <- shiny::isolate(validateData(rd$data))
  expect_false(isTRUE(v$FAIL))
  expect_equal(nrow(v$ExcludedRows), 4998L)
  # every row restored: one variable of 2,499 arms -> width 2,500
  wide <- .iaWithExcluded(v$DATA, v$ExcludedRows)
  expect_gt(.iaJournalCells(wide, v$CategoryNames), .iaMaxJournalCells)
  # one line per label restores the width to that of the analysed table
  narrow <- .iaWithExcluded(v$DATA, v$ExcludedRows, oneLinePerLabel = TRUE)
  expect_equal(nrow(narrow), 2L + 1L + 2499L)
  expect_lt(.iaJournalCells(narrow, v$CategoryNames), .iaMaxJournalCells)
})

test_that("the probe through /analyze: the journal tables are omitted, the template keeps every row, in bounded time", {
  rd <- .apiReadUpload(probe(), "journal-width-probe.csv")
  elapsed <- system.time(a <- shiny::isolate(.apiAnalyze(rd$data, seed = 42)))[["elapsed"]]
  expect_true(isTRUE(a$ok))
  # on a3fe636 this took 27.8 s and returned an 18.8 MB journal CSV
  expect_lt(elapsed, 15)
  expect_true(is.null(a$journalTables) || length(a$journalTables) == 0L ||
              nchar(a$journalTables[[1]]) < 200000)
  tpl <- utils::read.csv(text = a$templateCsv, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(nrow(tpl), 5000L)                 # the round trip keeps every row
  expect_equal(sum(tpl$ROW == "A"), 2499L)
  # and the results list each label once, with the coverage count
  res <- a$results
  expect_equal(sum(res$ROW %in% "A"), 1L)
  sm <- res[!is.na(res$KIND) & res$KIND == "summary", , drop = FALSE]
  expect_match(as.character(sm$NOTE[1]), "^1 of 2501 rows analysed")
})

test_that("the app's workbook is behind the same gate: a one-line note, not a two-minute table", {
  rd <- .apiReadUpload(probe(), "journal-width-probe.csv")
  v <- shiny::isolate(validateData(rd$data))
  set.seed(42); dqrng::dqset.seed(42)
  out <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000, excluded = v$Excluded))
  # every row restored (what the app did before): the gate refuses it
  wide <- .iaWithExcluded(v$DATA, v$ExcludedRows)
  xf <- tempfile(fileext = ".xlsx")
  elapsed <- system.time(writeResultsWorkbook(out, wide, v$CategoryNames, xf))[["elapsed"]]
  expect_lt(elapsed, 15)                          # 144.5 s on a3fe636
  sheet <- openxlsx::readWorkbook(xf, sheet = "Baseline Tables", colNames = FALSE)
  expect_match(as.character(sheet[1, 1]), "omitted")
  # one line per label (what the app passes now): small, and built
  narrow <- .iaWithExcluded(v$DATA, v$ExcludedRows, oneLinePerLabel = TRUE)
  tabs <- buildBaselineTables(narrow, v$CategoryNames)
  expect_equal(ncol(tabs[["T"]]), 3L)             # Variable + two arms, not 2,500
  expect_equal(nrow(tabs[["T"]]), 2501L)
})

test_that("a label that is also an analysed variable is not listed twice (screen 1143 observation)", {
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Age"), N = c(30, 30, NA),
                  MEAN = c(5.1, 5.2, NA), SD = c(1, 1, NA), ROUND_MEAN = c(1, 1, NA),
                  ROUND_DISPERSION = c(0, 0, NA), ROUND_OBSERVATION = c(1, 1, NA),
                  stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  set.seed(42); dqrng::dqset.seed(42)
  x <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000, excluded = v$Excluded))
  expect_equal(sum(x$ROW %in% "Age"), 1L)
  expect_equal(as.character(x$NOTE[!is.na(x$KIND) & x$KIND == "summary"][1]), "")
})
