# test-change-from-baseline-caption.R - a caption that says its cells are
# changes from, or responses to, the state before treatment is marked
# down like an outcome caption (ISSUES.md issue 80, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 17 finding W1 (Fujii 1994, Can J Anaesth, PMID    #
# 8055614): once issue 77's sign repairs made its rows readable, "TABLE II #
# Changes in Pdi (cmH20) from pre-fatigue values" out-scored the page's    #
# Table I (score 12 + caption 0 against 10 - 2) and the whole-document    #
# parse returned a table of changes as the baseline table.               #
############################################################################

test_that("a changes-from-baseline or response caption scores below a plain data caption", {
  tII <- .ppCaptionScore("TABLE II Changes in Pdi (cmH20) from pre-fatigue values")
  tI  <- .ppCaptionScore("TABLE I Haemodynamic data and changes")
  expect_true(tII < tI)
  expect_true(tII <= -3)
  expect_true(.ppCaptionScore("Table 3 Changes from baseline in blood pressure") <= -3)
  expect_true(.ppCaptionScore("Table 2 Haemodynamic responses to intubation") <= -6)
  expect_true(.ppCaptionScore("Table 4 Plasma catecholamines during surgery") <= -3)
})

test_that("a caption that says baseline is never marked down for its wording", {
  expect_true(.ppCaptionScore("Table 1 Baseline characteristics and changes from baseline") >= 4)
  expect_true(.ppCaptionScore("Table 1 Demographic data and responses to the questionnaire") >= 4)
  expect_identical(.ppCaptionScore("Table 1 Patient characteristics"),
                   .ppCaptionScore("Table 1 Patient characteristics"))
})

test_that("on a page with both, the table of changes loses to the plain table", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "changesLoses.pdf")
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Haemodynamic data", adj = 0)),
    rowCells(90, "", c("Control (n = 10)", "Drug (n = 10)"), vx),
    rowCells(108, "HR (bpm)", c("146 ± 9", "142 ± 10"), vx),
    rowCells(126, "MAP (mmHg)", c("121 ± 14", "121 ± 14"), vx),
    rowCells(144, "PCWP (mmHg)", c("8 ± 2", "9 ± 2"), vx),
    list(list(x = 60, y = 190, text = "TABLE II Changes in Pdi from pre-fatigue values", adj = 0)),
    rowCells(220, "", c("Control (n = 10)", "Drug (n = 10)"), vx),
    rowCells(238, "10 Hz", c("9.8 ± 1.8", "9.7 ± 2.1"), vx),
    rowCells(256, "20 Hz", c("15.5 ± 3.1", "15.6 ± 2.2"), vx),
    rowCells(274, "30 Hz", c("18.1 ± 1.5", "18.0 ± 1.8"), vx),
    rowCells(292, "50 Hz", c("20.0 ± 2.8", "20.2 ± 2.2"), vx),
    list(list(x = 60, y = 330, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_true(grepl("^TABLE I Haemodynamic", r$caption))
  expect_setequal(unique(r$data$ROW[!is.na(r$data$MEAN)]), c("HR", "MAP", "PCWP"))
})
