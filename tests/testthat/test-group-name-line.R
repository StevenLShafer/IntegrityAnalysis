# test-group-name-line.R - "Group 60 50 40 30 20 Volunteers": a line whose
# label is the word Group and whose values are the arms' names is the
# arm-name line (ISSUES.md issue 56, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 5 finding K2 (CJA 1995;42:992, Saitoh): six arms  #
# named by their stimulating current, "Group 60 50 40 30 20 Volunteers",   #
# over "n 15 15 15 15 15 15". The line was data to the classifier - the    #
# label "Group" with five plain numbers - so it was skipped as a bare       #
# number and the six arms went unnamed.                                    #
############################################################################

test_that("a Group line of numeric arm names above the first value line names the arms; the N row still gives N", {
  f  <- file.path(tempdir(), "groupNames.pdf")
  vx <- c(150, 215, 280, 345, 410, 475)
  cells <- c(
    list(list(x = 40, y = 60, text = "TABLE Demographic data of the five groups and the awake volunteers", adj = 0)),
    rowCells(90,  "Group", c("60", "50", "40", "30", "20", "Volunteers"), vx),
    rowCells(108, "n", c("15", "15", "15", "15", "15", "15"), vx),
    rowCells(130, "Age (yr)", c("47.2 ± 6.1", "48.9 ± 5.3", "49.0 ± 5.0", "46.4 ± 5.1", "49.4 ± 5.9", "46.8 ± 4.4"), vx),
    rowCells(148, "Weight (kg)", c("56.0 ± 8.4", "55.8 ± 7.1", "56.4 ± 7.4", "59.7 ± 6.9", "58.3 ± 6.2", "55.5 ± 5.4"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$arm, c("60", "50", "40", "30", "20", "Volunteers"))
  expect_identical(r$arms$N, rep(15L, 6))
  expect_false(any(grepl("^Group", r$skipped$label)))
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$MEAN[d$ROW == "Age"], c(47.2, 48.9, 49.0, 46.4, 49.4, 46.8))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a 'Group' row of counts below the first value line is data, not the arm-name line", {
  f  <- file.path(tempdir(), "groupCounts.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Control (n = 15)", "Treatment (n = 17)"), vx),
    rowCells(150, "Age (yr)", c("45.3 ± 12.1", "46.1 ± 11.8"), vx),
    list(list(x = 72, y = 168, text = "ASA physical status", adj = 0)),
    rowCells(186, "Group", c("9", "10"), vx, labelX = 82))   # an odd level name, but a level
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$arm, c("Control", "Treatment"))
  expect_true(any(r$data$ROW == "ASA physical status"))
})
