# test-letter-in-the-mean-before-the-sign.R - a look-alike letter among the
# digits of the MEAN before a genuine sign ("20l +/- 40") is read as its
# digit, as it is in the SD after the sign (ISSUES.md issue 136, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG7 (Anesth Analg 2002, PMID 12182258; four    #
# arms of 20): "Duration of anesthesia, min 20l +/- 40 205 +/- 40 207 +/-  #
# 41 204 +/- 49" lost its first cell; the page prints 201 +/- 40.           #
############################################################################

pm <- "\u00b1"

test_that("the helper reads the letter before the sign as in the SD after it", {
  L <- data.frame(text = c("Duration", "20l", pm, "40", "205", pm, "4O", "I2", "min"),
                  x = c(47, 236, 252, 259, 282, 298, 305, 330, 340), width = c(32, 12, 4, 8, 12, 4, 8, 8, 12),
                  stringsAsFactors = FALSE)
  r <- .ppRepairLetterDigitsAfterSign(list(data.frame(text = "Table", x = 47, width = 20), L), capIdx = 1L)
  # "20l" before a sign and "4O" after one; "I2" stands beside no sign
  expect_identical(r$repaired, 2L)
  expect_identical(r$lines[[2]]$text, c("Duration", "201", pm, "40", "205", pm, "40", "I2", "min"))
})

letterMeanPdf <- function(file = file.path(tempdir(), "letterMean.pdf")) {
  vx <- c(236, 282, 329, 374)
  cells <- c(
    list(list(x = 47, y = 60, text = "Table 1. Patient Characteristics", adj = 0)),
    rowCells(80, "", c("A", "B", "C", "D"), vx + 12, labelX = 47),
    rowCells(94, "", c("(n = 20)", "(n = 20)", "(n = 20)", "(n = 20)"), vx + 12, labelX = 47),
    rowCells(112, "Age, yr", c(paste("47", pm, "9"), paste("46", pm, "8"), paste("45", pm, "9"), paste("48", pm, "7")), vx, labelX = 47),
    rowCells(130, "Duration of anesthesia, min", c(paste("20l", pm, "40"), paste("205", pm, "40"), paste("207", pm, "41"), paste("204", pm, "49")), vx, labelX = 47),
    list(list(x = 47, y = 162, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the first Duration cell through the letter in its mean", {
  r <- parseBaselineTableHeuristics(letterMeanPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  dur <- cont[grepl("^Duration", cont$ROW), ]
  expect_identical(dur$MEAN, c(201, 205, 207, 204))
  expect_identical(dur$SD, c(40, 40, 41, 49))
})
