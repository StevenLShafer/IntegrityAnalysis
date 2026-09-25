# test-lost-sd-does-not-reach-next-cell.R - a sign whose SD is absent from
# the text layer does not take the next cell's mean as its SD (ISSUES.md
# issue 118, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 27 AF1 (CJA 1998, PMID 9350368, a scan): the Age  #
# line reads "62 +/- 61 +/- 62 +/- 9 61 +/- 11" with the first two SDs      #
# lost, and "62 +/- 61" was read as a cell, p < 0.0001 on it.               #
############################################################################

mk <- function(words, xs) data.frame(text = words, x = xs, width = nchar(words) * 5, y = 100, height = 8,
                                     stringsAsFactors = FALSE)

test_that("an SD followed by a sign glyph is refused; ranges and whole cells are untouched", {
  t <- .ppTokenizeLine(mk(c("Age", "(yr)", "62", "\u00b1", "61", "\u00b1", "62", "\u00b1", "9", "61", "\u00b1", "11"),
                          c(60, 80, 200, 215, 225, 240, 300, 315, 325, 400, 415, 425)))
  expect_identical(t$type, c("plain", "plain", "meanSD", "meanSD"))
  expect_identical(t$num1[3:4], c(62, 61)); expect_identical(t$num2[3:4], c(9, 11))
  t2 <- .ppTokenizeLine(mk(c("Age", "45.3", "\u00b1", "12.1", "[30-60]", "44", "\u00b1", "9"), c(60, 200, 225, 235, 260, 300, 315, 325)))
  expect_identical(t2$type, c("meanSD", "meanSD"))
  t3 <- .ppTokenizeLine(mk(c("Weight", "70", "\u2022", "9", "71", "\u2022", "8"), c(60, 200, 215, 225, 300, 315, 325)))
  expect_identical(t3$num2, c(9, 8))
})

lostSdPdf <- function(file = file.path(tempdir(), "lostSd.pdf")) {
  vx <- c(200, 290, 380, 470)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table I Patient characteristics", adj = 0)),
    rowCells(90, "", c("ET (n = 20)", "LMA (n = 20)", "ET (n = 20)", "LMA (n = 20)"), vx, labelX = 60),
    rowCells(108, "Age (yr)", c("62 \u00b1", "61 \u00b1", "62 \u00b1 9", "61 \u00b1 11"), vx, labelX = 60),
    rowCells(126, "Height (cm)", c("157 \u00b1 7", "156 \u00b1 6", "155 \u00b1 8", "157 \u00b1 7"), vx, labelX = 60),
    rowCells(144, "Weight (kg)", c("56 \u00b1 7", "53 \u00b1 8", "54 \u00b1 6", "55 \u00b1 7"), vx, labelX = 60),
    list(list(x = 60, y = 176, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with two lost SDs reads the two whole Age cells and no cell built from a neighbour's mean", {
  r <- parseBaselineTableHeuristics(lostSdPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  age <- cont[cont$ROW == "Age", ]
  expect_identical(nrow(age), 2L)
  expect_identical(age$MEAN, c(62, 61)); expect_identical(age$SD, c(9, 11))
  expect_true(all(cont$SD < cont$MEAN))
  expect_identical(nrow(cont[cont$ROW == "Height", ]), 4L)
})
