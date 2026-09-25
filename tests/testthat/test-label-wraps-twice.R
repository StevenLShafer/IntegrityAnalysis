# test-label-wraps-twice.R - a row label that wraps onto TWO lines beneath
# its values is read whole (ISSUES.md issue 69, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 15 residue on Fujii 2006 (PMID 17126782):        #
# "Propofol doses" over the values, "given at" and "first (mg)*" beneath - #
# the continuation rule of 2026-09-24 absorbed one line and the row went   #
# out as "Propofol doses given at".                                        #
############################################################################

twiceWrappedPdf <- function(file = file.path(tempdir(), "wrapTwice.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient demographics", adj = 0)),
    rowCells(100, "", c("Placebo", "Lidocaine"), vx),
    rowCells(118, "No.", c("20", "20"), vx),
    rowCells(136, "Age (y)", c("30 ± 4", "31 ± 5"), vx),
    rowCells(154, "Propofol doses", c("29 ± 5", "29 ± 5"), vx),
    list(list(x = 72, y = 166, text = "given at", adj = 0)),
    list(list(x = 72, y = 178, text = "first (mg)*", adj = 0)),
    rowCells(196, "Weight (kg)", c("58 ± 10", "57 ± 9"), vx),
    list(list(x = 60, y = 226, text = "Values are means ± SD or numbers.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("both continuation lines of a wrapped label are absorbed", {
  r <- parseBaselineTableHeuristics(twiceWrappedPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  rows <- unique(cont$ROW)
  expect_length(rows, 3L)
  # the footnote marker after the unit is dropped with the unit
  expect_true("Propofol doses given at first" %in% rows)
  expect_false(any(grepl("^Propofol doses given at$", rows)))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(58, 57))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a footnote marker after a unit is dropped with the unit", {
  expect_identical(.ppCleanLabel("Propofol doses given at first (mg)*"), "Propofol doses given at first")
  expect_identical(.ppCleanLabel("Weight (kg)†"), "Weight")
  expect_identical(.ppCleanLabel("Age (yr)"), "Age")
})

test_that("a capitalised line after a continuation is the next variable, not a third line", {
  f  <- file.path(tempdir(), "wrapStop.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient demographics", adj = 0)),
    rowCells(100, "", c("A (n = 20)", "B (n = 20)"), vx),
    rowCells(118, "Amount of intraoperative", c("561 ± 120", "540 ± 110"), vx),
    list(list(x = 60, y = 130, text = "fluid (ml)", adj = 0)),
    list(list(x = 60, y = 142, text = "ASA class", adj = 0)),
    rowCells(160, "I", c("12", "11"), vx, labelX = 80),
    rowCells(178, "II", c("8", "9"), vx, labelX = 80))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_true(any(grepl("^Amount of intraoperative fluid", r$data$ROW)))
  expect_true(any(grepl("^ASA class", r$data$ROW)))
})
