# test-letter-l-in-sd-after-sign.R - a word after a genuine sign glyph made
# of digits and the look-alike letters l, I, | and O is the SD with its
# letters restored (ISSUES.md issue 116, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE6 (CJA 1998, PMID 9717598, a scan): the      #
# Weight row prints "58 <bullet> l0" and the whole row was lost.           #
############################################################################

mk <- function(text, x) data.frame(text = text, x = x, width = nchar(text) * 5, y = 0,
                                   stringsAsFactors = FALSE)

test_that("the helper restores l, I, | and O after a sign, and leaves other words alone", {
  lines <- list(
    mk(c("TABLE", "I"), c(60, 90)),
    mk(c("Weight", "(kg)", "58", "\u2022", "l0", "59", "\u2022", "11", "56", "\u2022", "9"), c(60, 100, 200, 215, 225, 300, 315, 325, 400, 415, 425)),
    mk(c("Age", "(yr)", "45.2", "\u00b1", "O.5", "44", "\u00b1", "I2"), c(60, 100, 200, 225, 235, 300, 315, 325)),
    mk(c("Dose", "l0", "mg", "\u00b1", "kg", "\u00b1", "lO"), c(60, 100, 130, 160, 175, 200, 215)))
  rep <- .ppRepairLetterDigitsAfterSign(lines, capIdx = 1L)
  expect_identical(rep$lines[[2]]$text[5], "10")
  expect_identical(rep$lines[[3]]$text[5], "0.5")
  expect_identical(rep$lines[[3]]$text[8], "12")
  expect_identical(rep$lines[[4]]$text[2], "l0")     # not after a sign
  expect_identical(rep$lines[[4]]$text[5], "kg")     # letters that are not look-alikes
  expect_identical(rep$lines[[4]]$text[7], "lO")     # no true digit among them
  expect_identical(rep$repaired, 3L)
})

letterSdPdf <- function(file = file.path(tempdir(), "letterSd.pdf")) {
  vx <- c(395, 444, 491)
  cells <- c(
    list(list(x = 307, y = 60, text = "TABLE I Demographic data", adj = 0)),
    rowCells(80, "", c("Group C", "Group N", "Group D"), vx, labelX = 307),
    rowCells(94, "", c("(n = 20)", "(n = 20)", "(n = 20)"), vx, labelX = 307),
    rowCells(112, "Age (yr)", c("60 \u2022 9", "62 \u2022 9", "62 \u2022 9"), vx, labelX = 307),
    rowCells(130, "Height (cm)", c("156 \u2022 10", "155 \u2022 9", "154 \u2022 8"), vx, labelX = 307),
    rowCells(148, "Weight (kg)", c("58 \u2022 l0", "59 \u2022 11", "56 \u2022 9"), vx, labelX = 307),
    list(list(x = 307, y = 178, text = "Values are mean \u2022 SD or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt scanned page reads the Weight row whose SD prints as 'l0'", {
  r <- parseBaselineTableHeuristics(letterSdPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(58, 59, 56))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(10, 11, 9))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
