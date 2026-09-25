# test-underscore-plus-is-soup.R - "_+" between two numbers, at a column
# where the block's other rows set the sign, is the plus-minus (ISSUES.md
# issue 107, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD5 (CJA 1996, PMID 8665632, a scan under a    #
# diagonal RETRACTED watermark): "52.6 _+ 20.7", "252.0 _+ 82.3" in the     #
# second arm went unread while the first arm's "51.4 . 20.4" (a bullet)   #
# read.                                                                    #
############################################################################

mk <- function(text, x) data.frame(text = text, x = x, width = nchar(text) * 5, y = 0,
                                   stringsAsFactors = FALSE)

test_that("the underscore-plus soup at a slot is repaired; a bare underscore word elsewhere is not", {
  lines <- list(
    mk(c("Table", "I"), c(60, 90)),
    mk(c("Age", "(yr)", "6.3", "\u2022", "2.0", "6.7", "\u2022", "2.2"), c(60, 80, 200, 222, 232, 300, 322, 332)),
    mk(c("Height", "(cm)", "119.1", "\u2022", "12.4", "122.2", "\u2022", "16.3"), c(60, 90, 196, 222, 232, 296, 322, 332)),
    mk(c("Duration", "(min)", "51.4", "\u2022", "20.4", "52.6", "_+", "20.7"), c(60, 100, 200, 222, 232, 300, 322, 332)),
    mk(c("Acetaminophen", "(mg)", "240.0", "+", "64.5", "252.0", "_+", "82.3"), c(60, 120, 196, 222, 232, 296, 322, 332)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$lines[[4]]$text[7], "\u00b1")
  expect_identical(rep$lines[[5]]$text[7], "\u00b1")
  expect_true(rep$repaired >= 2L)
})

underscorePdf <- function(file = file.path(tempdir(), "underscorePlus.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table I Patient characteristics", adj = 0)),
    rowCells(90, "", c("Placebo (n = 25)", "Granisetron (n = 25)"), vx),
    rowCells(108, "Age (yr)", c("6.3 \u2022 2.0", "6.7 \u2022 2.2"), vx),
    rowCells(126, "Height (cm)", c("119.1 \u2022 12.4", "122.2 \u2022 16.3"), vx),
    rowCells(144, "Weight (kg)", c("23.9 \u2022 6.7", "25.8 \u2022 9.8"), vx),
    rowCells(162, "Duration of operation (min)", c("51.4 \u2022 20.4", "52.6 _+ 20.7"), vx),
    rowCells(180, "Acetaminophen (mg)", c("240.0 + 64.5", "252.0 _+ 82.3"), vx),
    list(list(x = 60, y = 210, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt scanned page reads both arms of the rows whose second cell is set with '_+'", {
  r <- parseBaselineTableHeuristics(underscorePdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Duration of operation"], c(51.4, 52.6))
  expect_identical(cont$SD[cont$ROW == "Duration of operation"], c(20.4, 20.7))
  expect_identical(cont$MEAN[cont$ROW == "Acetaminophen"], c(240.0, 252.0))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
