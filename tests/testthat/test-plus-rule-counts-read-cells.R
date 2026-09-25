# test-plus-rule-counts-read-cells.R - the announced "mean + SD" rule's
# two-cell floor counts the cells the slot repair already read, so the one
# plus pair it leaves behind is not lost (ISSUES.md issue 82, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 19 finding Y4 (Saitoh, CJA 1995;42:992, six arms  #
# of 15): after issue 77 the slot repair turned five of Age's six plus     #
# signs into the sign and left "49.4 + 5.9", whose column no other line   #
# marked; alone, that pair fell under the announced rule's floor of two   #
# and the fifth arm's Age was lost.                                        #
############################################################################

sixArmPdf <- function(file = file.path(tempdir(), "sixArms.pdf")) {
  vx <- c(150, 218, 286, 354, 422, 490)
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE Demographic data of the five groups (Number or mean + SD)", adj = 0)),
    rowCells(90, "", c("A", "B", "C", "D", "E", "F"), vx),
    rowCells(108, "Number", c("15", "15", "15", "15", "15", "15"), vx),
    # the plus is set as the sign in four columns on the rows beneath, so the
    # slot repair reads those columns' "+" on every row; column E is marked
    # by no other line and its "+" is left to the announced rule
    rowCells(126, "Age (yr)", c("47.2 + 6.1", "48.9 + 5.3", "49.0 + 5.0", "46.4 + 5.1", "49.4 + 5.9", "46.8 + 4.4"), vx),
    rowCells(144, "Height (cm)", c("164.2 :l: 10.0", "166.0 + 9.8", "164.6 + 8.8", "160.8 + 8.6", "162.5 -4- 12.2", "163.3 + 7.8"), vx),
    rowCells(162, "Weight (kg)", c("56.0 + 8.4", "55.8 + 7.1", "56.4 -I- 7.4", "59.7 + 6.9", "58.3 :i: 6.2", "55.5 + 5.4"), vx),
    list(list(x = 60, y = 192, text = "Values are number or mean + SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("every arm of Age survives when the slot repair leaves one plus pair to the announced rule", {
  r <- parseBaselineTableHeuristics(sixArmPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 6L)
  age <- r$data[r$data$ROW == "Age" & !is.na(r$data$MEAN), ]
  expect_identical(age$MEAN, c(47.2, 48.9, 49.0, 46.4, 49.4, 46.8))
  expect_identical(age$SD, c(6.1, 5.3, 5.0, 5.1, 5.9, 4.4))
  expect_identical(nrow(r$data[r$data$ROW == "Weight" & !is.na(r$data$MEAN), ]), 6L)
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a lone plus pair on a line with no cell is still refused under the announced rule", {
  f  <- file.path(tempdir(), "lonePlusAnnounced.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient data (mean + SD)", adj = 0)),
    rowCells(100, "", c("A (n = 10)", "B (n = 10)"), vx),
    # the Dose cells sit off the Age cells' columns, so no slot backs the "+"
    rowCells(130, "Dose (mg)", c("5 + 2", "6"), c(340, 460)),
    rowCells(148, "Age (yr)", c("45 ± 12", "46 ± 11"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_false(any(r$data$ROW == "Dose" & !is.na(r$data$SD) & r$data$SD == 2))
})
