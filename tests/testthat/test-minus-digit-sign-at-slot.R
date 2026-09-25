# test-minus-digit-sign-at-slot.R - under an announced notation, "-6"
# between two numbers at a slot the block's other rows mark is the
# plus-minus, not a negative number (ISSUES.md issue 114, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE8 (CJA 1995, PMID 7534216, a scan under a    #
# RETRACTED watermark): "All values are expressed as mean + SD." over      #
# "59 -6 14  59 -6 11  56 + 11  56 + 10" and "154 -6 9"; the "-6" read as   #
# a negative number, the cells fell apart, and the table read one arm.    #
############################################################################

mk <- function(text, x) data.frame(text = text, x = x, width = nchar(text) * 5, y = 0,
                                   stringsAsFactors = FALSE)

test_that("the helper: '-6' at an announced slot is the sign; a real negative number elsewhere is not touched", {
  lines <- list(
    mk(c("TABLE", "I"), c(305, 333)),
    mk(c("Age", "(yr)", "61", "+", "9", "62", "+", "8", "64", "4-", "5", "63", "+", "7"), c(306, 321, 365, 375, 383, 407, 417, 425, 449, 459, 467, 491, 501, 509)),
    mk(c("Height", "(cm)", "156", "+", "9", "157", "+", "12", "154", "-6", "9", "154", "-6", "9"), c(306, 329, 366, 379, 387, 408, 421, 430, 450, 462, 471, 492, 504, 513)),
    mk(c("Weight", "(kg)", "59", "-6", "14", "59", "-6", "11", "56", "+", "11", "56", "+", "10"), c(306, 330, 366, 375, 385, 407, 417, 426, 449, 459, 468, 491, 501, 510)),
    mk(c("Change", "in", "BE", "-6", "to", "-2"), c(306, 340, 352, 380, 400, 420)),
    mk(c("All", "values", "are", "expressed", "as", "mean", "+", "SD."), c(306, 318, 340, 352, 384, 393, 412, 421)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$lines[[3]]$text[10], "\u00b1")
  expect_identical(rep$lines[[3]]$text[13], "\u00b1")
  expect_identical(rep$lines[[4]]$text[4], "\u00b1")
  expect_identical(rep$lines[[4]]$text[7], "\u00b1")
  expect_identical(rep$lines[[5]]$text, lines[[5]]$text)     # "-6 to -2" is a range of negative numbers
})

test_that("without the announcement '-6' stays a number", {
  lines <- list(
    mk(c("TABLE", "I"), c(305, 333)),
    mk(c("Age", "(yr)", "61", "\u00b1", "9", "62", "\u00b1", "8"), c(306, 321, 365, 375, 383, 407, 417, 425)),
    mk(c("Weight", "(kg)", "59", "-6", "14", "59", "-6", "11"), c(306, 330, 366, 375, 385, 407, 417, 426)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$lines[[3]]$text, lines[[3]]$text)
})

minusDigitPdf <- function(file = file.path(tempdir(), "minusDigit.pdf")) {
  vx <- c(230, 320, 410, 500)
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Demographic data in normotensive and hypertensive patients", adj = 0)),
    rowCells(90, "", c("ET (n = 12)", "LMA (n = 12)", "ET (n = 11)", "LMA (n = 11)"), vx),
    rowCells(108, "Age (yr)", c("61 + 9", "62 + 8", "64 4- 5", "63 + 7"), vx),
    rowCells(126, "Height (cm)", c("156 + 9", "157 + 12", "154 -6 9", "154 -6 9"), vx),
    rowCells(144, "Weight (kg)", c("59 -6 14", "59 -6 11", "56 + 11", "56 + 10"), vx),
    list(list(x = 60, y = 176, text = "All values are expressed as mean + SD.", adj = 0)))
  # left-aligned cells, as the scan sets them: the sign of every row then starts at one x
  for (k in seq_along(cells)) cells[[k]]$adj <- 0
  makeTablePdf(file, cells)
}

test_that("a rebuilt page under 'mean + SD' reads all four arms of every row", {
  r <- parseBaselineTableHeuristics(minusDigitPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(12L, 12L, 11L, 11L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(156, 157, 154, 154))
  expect_identical(cont$SD[cont$ROW == "Height"], c(9, 12, 9, 9))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(59, 59, 56, 56))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(14, 11, 11, 10))
})
