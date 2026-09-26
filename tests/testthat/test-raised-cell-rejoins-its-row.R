# test-raised-cell-rejoins-its-row.R - a cell set half a line above or
# below its row, alone on a line of its own, joins the neighbouring row
# that has no word across its x (ISSUES.md issue 134, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 29 AH4 (Akelma 2020, Turk J Med Sci, Loadsman     #
# corpus; three arms of 16, 18 and 17): the middle cell of Duration of     #
# anaesthesia, "84.94 +/- 26.71", sits five points higher than its         #
# neighbours and went out as a separate variable "Unnamed".                #
############################################################################

pm <- "\u00b1"

test_that("the line builder rejoins a raised one-cell line to the row with a gap at its x", {
  w <- function(text, x, y, width) data.frame(text = text, x = x, y = y, width = width, height = 8, stringsAsFactors = FALSE)
  words <- rbind(
    w("Table", 35, 50, 20),
    w(c("Duration", "of", "anaesthesia", "(min)", "90.68", pm, "33.80", "90.05", pm, "23.94", "0.807"),
      c(77, 114, 124, 169, 220, 242, 249, 362, 383, 391, 433), 406, c(35, 7, 43, 21, 19, 5, 19, 19, 5, 19, 19)),
    w(c("84.94", pm, "26.71"), c(291, 312, 320), 401, c(19, 5, 19)),
    # a raised line whose x the neighbour already covers stays apart (a superscript's number)
    w("Weight", 77, 430, 30), w(c("70", pm, "9"), c(220, 242, 249), 430, c(11, 5, 5)),
    w("12", 224, 425, 8))
  lines <- .ppBuildLines(words)
  texts <- vapply(lines, .ppLineText, character(1))
  expect_true(any(texts == paste("Duration of anaesthesia (min) 90.68", pm, "33.80 84.94", pm, "26.71 90.05", pm, "23.94 0.807")))
  expect_true("12" %in% texts)
  expect_true(any(texts == paste("Weight 70", pm, "9")))
})

raisedCellPdf <- function(file = file.path(tempdir(), "raisedCell.pdf")) {
  vx <- c(220, 291, 362)
  cells <- c(
    list(list(x = 77, y = 60, text = "Table 1. Demographic data", adj = 0)),
    rowCells(80, "", c("Group I (n = 16)", "Group II (n = 18)", "Group III (n = 17)"), vx, labelX = 77),
    rowCells(100, "Age (years)", c(paste("35.2", pm, "8.1"), paste("33.9", pm, "7.4"), paste("34.6", pm, "9.0")), vx, labelX = 77),
    rowCells(118, "Weight (kg)", c(paste("70.1", pm, "9.2"), paste("68.4", pm, "8.8"), paste("71.0", pm, "10.1")), vx, labelX = 77),
    # the middle cell five points higher than its row
    list(list(x = 77, y = 136, text = "Duration of anaesthesia (min)", adj = 0),
         list(x = vx[1], y = 136, text = paste("90.68", pm, "33.80"), adj = 0),
         list(x = vx[2], y = 131, text = paste("84.94", pm, "26.71"), adj = 0),
         list(x = vx[3], y = 136, text = paste("90.05", pm, "23.94"), adj = 0)),
    list(list(x = 77, y = 170, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the raised middle cell in its row and no Unnamed variable", {
  r <- parseBaselineTableHeuristics(raisedCellPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(16L, 18L, 17L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  dur <- cont[grepl("^Duration", cont$ROW), ]
  expect_identical(dur$MEAN, c(90.68, 84.94, 90.05))
  expect_identical(dur$SD, c(33.80, 26.71, 23.94))
  expect_false(any(grepl("Unnamed", cont$ROW)))
})
