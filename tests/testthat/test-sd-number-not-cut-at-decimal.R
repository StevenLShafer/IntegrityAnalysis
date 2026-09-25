# test-sd-number-not-cut-at-decimal.R - a token never ends inside a
# number: when the lookahead of issue 118 refuses a whole decimal number
# as the SD, the regex does not shorten it to its integer part
# (ISSUES.md issue 121, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 27 AF3 (CJA 1995, PMID 7614644, a scan): the Age  #
# line "40.1 +/- 7.5 45.3 +/- 43.2 +/- 8.3 42.5 +/- 9.4" - the second SD   #
# lost to the text layer - read "45.3 +/- 43" for its second cell, the     #
# ".2" left behind, and the row scored on an SD of 43. Found while         #
# building the fixture of issue 120.                                       #
############################################################################

pm <- "\u00b1"

tokLine <- function(s) {
  w <- strsplit(s, " ")[[1]]
  .ppTokenizeLine(data.frame(text = w, x = cumsum(c(0, head(nchar(w) + 1, -1))) * 6,
                             width = nchar(w) * 6, stringsAsFactors = FALSE))
}

test_that("a refused decimal SD leaves a bare mean, not a cell cut at the decimal point", {
  t <- tokLine(paste("45.3", pm, "43.2", pm, "8.3"))
  expect_identical(t$type, c("plain", "meanSD"))
  expect_identical(t$text[2], paste("43.2", pm, "8.3"))
  t <- tokLine(paste("40.1", pm, "7.5 45.3", pm, "43.2", pm, "8.3 42.5", pm, "9.4"))
  expect_identical(t$type, c("meanSD", "plain", "meanSD", "meanSD"))
  expect_identical(t$num2[t$type == "meanSD"], c(7.5, 8.3, 9.4))
  # whole numbers were already safe; a comma decimal is refused the same way
  t <- tokLine(paste("62", pm, "61", pm, "62", pm, "9"))
  expect_identical(t$type, c("plain", "plain", "meanSD"))
  t <- tokLine(paste("45,3", pm, "43,2", pm, "8,3"))
  expect_identical(t$type, c("plain", "meanSD"))
})

lostDecimalSdPdf <- function(file = file.path(tempdir(), "lostDecimalSd.pdf")) {
  vx <- c(200, 290, 380, 470)
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Patient demographics", adj = 0)),
    rowCells(90, "", c("Placebo (n = 22)", "Gran (n = 22)", "Dex (n = 22)", "Both (n = 22)"), vx, labelX = 60),
    rowCells(108, "Age (yr)", c(paste("40.1", pm, "7.5"), paste("45.3", pm), paste("43.2", pm, "8.3"), paste("42.5", pm, "9.4")), vx, labelX = 60),
    rowCells(126, "Height (cm)", c(paste("154.0", pm, "3.8"), paste("154.9", pm, "4.8"), paste("156.3", pm, "6.2"), paste("154.4", pm, "4.9")), vx, labelX = 60),
    rowCells(144, "Weight (kg)", c(paste("54.0", pm, "7.3"), paste("53.2", pm, "8.0"), paste("54.9", pm, "9.0"), paste("54.1", pm, "7.6")), vx, labelX = 60),
    list(list(x = 60, y = 176, text = paste("All values are expressed as mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with a lost decimal SD reads the three whole Age cells and no cell cut from a neighbour's mean", {
  r <- parseBaselineTableHeuristics(lostDecimalSdPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(22L, 4))
  age <- r$data[r$data$ROW == "Age" & !is.na(r$data$MEAN), ]
  expect_identical(age$MEAN, c(40.1, 43.2, 42.5))
  expect_identical(age$SD, c(7.5, 8.3, 9.4))
  expect_identical(r$data$MEAN[r$data$ROW == "Height"], c(154.0, 154.9, 156.3, 154.4))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
