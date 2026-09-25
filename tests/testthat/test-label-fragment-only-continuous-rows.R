# test-label-fragment-only-continuous-rows.R - the label-fragment join of
# issue 112 applies only to a row of continuous cells: a category heading
# over an OCR-lowercased level ("a -blocker" for the Greek alpha) stays a
# heading (ISSUES.md issue 117, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 27 AF2 (MTS2001_21, an OCR page): "Antihypertensive #
# medication" over "a -blocker 1 1 2", "B-blocker 1 1 1" ...; the join     #
# closed the heading, the count rows were skipped as bare numbers, and     #
# the column candidate lost to a full-width reading with Age alone.        #
############################################################################

alphaBlockerPdf <- function(file = file.path(tempdir(), "alphaBlocker.pdf")) {
  vx <- c(330, 420, 510)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Demographic data", adj = 0)),
    rowCells(80, "", c("Group L", "Group D", "Group V"), vx, labelX = 60),
    rowCells(92, "", c("(n=15)", "(n=15)", "(n=15)"), vx, labelX = 60),
    rowCells(110, "Age (years)", c("60 (11)", "63 (8)", "63 (10)"), vx, labelX = 60),
    rowCells(128, "Height (cm)", c("157 (11)", "155 (12)", "155 (13)"), vx, labelX = 60),
    rowCells(146, "Weight (kg)", c("56 (10)", "56 (11)", "56 (10)"), vx, labelX = 60),
    list(list(x = 60, y = 164, text = "Antihypertensive medication", adj = 0)),
    rowCells(176, "a -blocker", c("1", "1", "2"), vx, labelX = 75),
    rowCells(188, "B-blocker", c("1", "1", "1"), vx, labelX = 75),
    rowCells(200, "Calcium channel blocker", c("8", "8", "8"), vx, labelX = 75),
    list(list(x = 60, y = 230, text = "Values are mean (SD) or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a heading over an OCR-lowercased level stays a heading; the continuous rows all read", {
  r <- parseBaselineTableHeuristics(alphaBlockerPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(15L, 15L, 15L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Weight"))
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(157, 155, 155))
  expect_false(any(grepl("Antihypertensive medication a", c(r$data$ROW, r$skipped$label))))
  # the levels read as counts under their heading, not skipped as bare numbers
  expect_false(any(grepl("no category header", r$skipped$reason)))
  expect_true(any(grepl("blocker", c(r$data$ROW, names(r$data)))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

# THE LEVELS PRINTED AS n (%) (CodeRabbit on PR #425, 2026-09-26): an "a (b)"
# cell is a continuous cell only when it does not check as a count and its
# percentage of the arm's N. "a -blocker 1 (6.7) 1 (6.7) 2 (13.3)" in arms
# of 15 is a level under its heading, not a wrapped label's second line.
alphaBlockerPctPdf <- function(file = file.path(tempdir(), "alphaBlockerPct.pdf")) {
  vx <- c(330, 420, 510)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Demographic data", adj = 0)),
    rowCells(80, "", c("Group L", "Group D", "Group V"), vx, labelX = 60),
    rowCells(92, "", c("(n=15)", "(n=15)", "(n=15)"), vx, labelX = 60),
    rowCells(110, "Age (years)", c("60 (11)", "63 (8)", "63 (10)"), vx, labelX = 60),
    rowCells(128, "Height (cm)", c("157 (11)", "155 (12)", "155 (13)"), vx, labelX = 60),
    rowCells(146, "Weight (kg)", c("56 (10)", "56 (11)", "56 (10)"), vx, labelX = 60),
    list(list(x = 60, y = 164, text = "Antihypertensive medication", adj = 0)),
    rowCells(176, "a -blocker", c("1 (6.7)", "1 (6.7)", "2 (13.3)"), vx, labelX = 75),
    rowCells(188, "B-blocker", c("1 (6.7)", "2 (13.3)", "3 (20.0)"), vx, labelX = 75),
    rowCells(200, "Calcium channel blocker", c("8 (53.3)", "7 (46.7)", "9 (60.0)"), vx, labelX = 75),
    list(list(x = 60, y = 230, text = "Values are mean (SD) or number (%).", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a heading over an OCR-lowercased n (%) level stays a heading", {
  r <- parseBaselineTableHeuristics(alphaBlockerPctPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(15L, 15L, 15L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Weight"))
  expect_false(any(grepl("Antihypertensive medication a", c(r$data$ROW, r$skipped$label))))
  expect_true(any(grepl("blocker", c(r$data$ROW, names(r$data)))))
})
