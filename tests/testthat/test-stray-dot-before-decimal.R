# test-stray-dot-before-decimal.R - a stray dot fused before a decimal
# number (".5.0") is dropped, so the number is a cell and not part of the
# row label (ISSUES.md issue 126, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's AF7 (CJA 1996, PMID 8706192, a scan): the Morphine row's #
# text layer ".5.0 5:0.6 5.0 -t- 0.8 5.1 5:0.9 4.9 5:0.9" - the row came    #
# out as "Morphine administered (epidural) after operation (mg) .5.0" with #
# three cells; the page prints 5.0 +/- 0.6 in the first arm.              #
############################################################################

words <- function(...) {
  w <- c(...)
  data.frame(text = w, x = cumsum(c(0, head(nchar(w) + 1, -1))) * 6, width = nchar(w) * 6,
             stringsAsFactors = FALSE)
}
pm <- "\u00b1"

test_that("the helper drops the dot before a decimal number and leaves a dot before a whole number", {
  r <- .ppRepairStrayDots(list(words("Table"), words("Morphine", "(mg)", ".5.0", pm, "0.6", "5.0", pm, "0.8")), capIdx = 1L)
  expect_identical(r$repaired, 1L)
  expect_identical(r$lines[[2]]$text[3], "5.0")
  # the number keeps the dot's share of the width off its left edge
  expect_equal(r$lines[[2]]$x[3], 6 * nchar("Morphine (mg) ") + 6)
  expect_equal(r$lines[[2]]$width[3], 18)
  r <- .ppRepairStrayDots(list(words("Dose", ".5", pm, "0.1")))
  expect_identical(r$repaired, 0L)
  r <- .ppRepairStrayDots(list(words(".5.0", pm, "0.6"), words("Table")), capIdx = 2L)
  expect_identical(r$repaired, 0L)
})

strayDotPdf <- function(file = file.path(tempdir(), "strayDot.pdf")) {
  vx <- c(200, 290, 380, 470)
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Patient characteristics", adj = 0)),
    rowCells(90, "", c("A (n = 25)", "B (n = 25)", "C (n = 25)", "D (n = 25)"), vx, labelX = 60),
    rowCells(108, "Age (yr)", c(paste("40.1", pm, "7.5"), paste("45.3", pm, "8.1"), paste("43.2", pm, "8.3"), paste("42.5", pm, "9.4")), vx, labelX = 60),
    rowCells(126, "Weight (kg)", c(paste("55.3", pm, "5.4"), paste("53.7", pm, "7.5"), paste("54.0", pm, "7.7"), paste("54.4", pm, "8.2")), vx, labelX = 60),
    rowCells(144, "Morphine (mg)", c(paste(".5.0", pm, "0.6"), paste("5.0", pm, "0.8"), paste("5.1", pm, "0.9"), paste("4.9", pm, "0.9")), vx, labelX = 60),
    list(list(x = 60, y = 176, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with the stray dot reads the first Morphine cell and a clean label", {
  r <- parseBaselineTableHeuristics(strayDotPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_true("Morphine" %in% cont$ROW)
  expect_identical(cont$MEAN[cont$ROW == "Morphine"], c(5.0, 5.0, 5.1, 4.9))
  expect_identical(cont$SD[cont$ROW == "Morphine"], c(0.6, 0.8, 0.9, 0.9))
  expect_false(any(grepl("[.]5[.]0", cont$ROW)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
