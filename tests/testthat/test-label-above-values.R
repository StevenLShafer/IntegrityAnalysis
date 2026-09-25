# test-label-above-values.R - a row whose name sits on the line ABOVE its
# values, with the unit on the line beneath (ISSUES.md issue 68,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 14 finding S1 (Rezk 2015, Clin Exp Obstet        #
# Gynecol, Loadsman corpus; page 3, Table 1 "Maternal characteristics"):   #
# in a narrow first column "Duration of active phase (hours)" wraps to     #
# two lines and the cells 5.25 +/- 0.86 / 5.31 +/- 0.85 are centred on the #
# pair, so the values' line carries no label and the row went out as      #
# "Unnamed" on both engines.                                               #
############################################################################

wrappedPdf <- function(file = file.path(tempdir(), "labelAbove.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Maternal characteristics.", adj = 0)),
    rowCells(100, "", c("Fentanyl group", "Pethidine group"), vx),
    rowCells(112, "", c("n=40", "n=40"), vx),
    rowCells(130, "Age (years)", c("21.72 ± 2.63", "21.70 ± 1.69"), vx),
    rowCells(148, "Weight (kg)", c("69.40 ± 5.68", "70.00 ± 5.52"), vx),
    list(list(x = 60, y = 166, text = "Duration of active phase", adj = 0)),
    rowCells(172, "", c("5.25 ± 0.86", "5.31 ± 0.85"), vx),
    list(list(x = 60, y = 178, text = "(hours)", adj = 0)),
    rowCells(196, "Need for oxytocin", c("26 (55%)", "23 (57.5%)"), vx),
    list(list(x = 60, y = 226, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a label-less value line directly under the line that named it takes that name", {
  r <- parseBaselineTableHeuristics(wrappedPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_false(any(grepl("^Unnamed", r$data$ROW)))
  expect_true("Duration of active phase" %in% cont$ROW)
  expect_identical(cont$MEAN[cont$ROW == "Duration of active phase"], c(5.25, 5.31))
  expect_identical(cont$SD[cont$ROW == "Duration of active phase"], c(0.86, 0.85))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(69.40, 70.00))
  expect_identical(r$arms$N, c(40L, 40L))
  # the unit line was absorbed as the label's continuation, not left as a heading
  expect_false(any(grepl("hours", r$data$ROW)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a category heading over LABELLED level rows is still a heading", {
  f  <- file.path(tempdir(), "headingKept.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(100, "", c("A (n = 40)", "B (n = 40)"), vx),
    rowCells(118, "Age (years)", c("45 ± 12", "46 ± 11"), vx),
    list(list(x = 60, y = 136, text = "ASA class", adj = 0)),
    rowCells(154, "I", c("22", "20"), vx, labelX = 80),
    rowCells(172, "II", c("18", "20"), vx, labelX = 80))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_true(any(grepl("^ASA class", r$data$ROW)))
  expect_false(any(grepl("^Unnamed", r$data$ROW)))
})
