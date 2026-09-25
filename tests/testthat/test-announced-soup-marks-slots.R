# test-announced-soup-marks-slots.R - once the notation is announced with a
# soup glyph, every soup word set between two numbers marks its column, so
# a glued digit-colon form ("5:34") at that column is the sign and its SD
# (ISSUES.md issue 108, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD4 (CJA 1994, PMID 8004733, a scan): "All     #
# values are expressed as mean ~ SD." over "81 5:34 82 -t- 29 81 4- 39";  #
# the first arm's durations went unread because the page sets no genuine  #
# glyph and no plain plus, so no slot existed for the glued form.         #
############################################################################

mk <- function(text, x) data.frame(text = text, x = x, width = nchar(text) * 5, y = 0,
                                   stringsAsFactors = FALSE)

test_that("the helper: under an announced soup, soup words mark the slots and the glued digit-colon form at a slot is repaired", {
  lines <- list(
    mk(c("TABLE", "I", "Demographic", "data"), c(48, 69, 77, 149)),
    mk(c("Age", "(yr)", "47.3", "4-", "9.3", "46.7", "4-", "10.1", "45.5", "4-", "8.6"), c(48, 59, 145, 157, 163, 190, 202, 208, 248, 260, 266)),
    mk(c("Weight", "(kg)", "54.1", "4-", "7.6", "55.2", "+", "9.1", "52.5", "4-", "6.0"), c(48, 66, 145, 157, 163, 190, 202, 208, 249, 260, 266)),
    mk(c("Duration", "(min)", "81", "5:34", "82", "-t-", "29", "81", "4-", "39"), c(48, 102, 150, 157, 195, 202, 208, 253, 260, 267)),
    mk(c("All", "values", "are", "expressed", "as", "mean", "~", "SD."), c(48, 57, 73, 82, 107, 113, 128, 134)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  d <- rep$lines[[4]]$text
  expect_identical(d[3:5], c("81", "\u00b1", "34"))
  expect_identical(d[6:8], c("82", "\u00b1", "29"))
  expect_identical(d[9:11], c("81", "\u00b1", "39"))
})

test_that("without the announcement the glued digit form still needs a genuine slot", {
  lines <- list(
    mk(c("TABLE", "I"), c(48, 69)),
    mk(c("Age", "(yr)", "47.3", "4-", "9.3", "46.7", "4-", "10.1"), c(48, 59, 145, 157, 163, 190, 202, 208)),
    mk(c("Duration", "(min)", "81", "5:34", "82", "-t-", "29"), c(48, 102, 150, 157, 195, 202, 208)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$lines[[3]]$text, lines[[3]]$text)
})

announcedPdf <- function(file = file.path(tempdir(), "announcedSoup.pdf")) {
  vx <- c(230, 320, 410)
  cells <- c(
    list(list(x = 48, y = 60, text = "TABLE I Demographic and anaesthetic data", adj = 0)),
    rowCells(90, "", c("Placebo", "Metoclopramide", "Granisetron"), vx, labelX = 48),
    rowCells(108, "Age (yr)", c("47.3 4- 9.3", "46.7 4- 10.1", "45.5 4- 8.6"), vx, labelX = 48),
    rowCells(126, "Weight (kg)", c("54.1 4- 7.6", "55.2 + 9.1", "52.5 4- 6.0"), vx, labelX = 48),
    rowCells(144, "Duration of operation (min)", c("81 5:34", "82 -t- 29", "81 4- 39"), vx, labelX = 48),
    rowCells(162, "Duration of anaesthesia (min)", c("108 5:38", "108 4- 34", "104 4- 40"), vx, labelX = 48),
    list(list(x = 48, y = 190, text = "All values are expressed as mean ~ SD. Twenty patients were studied in each group.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page under 'mean ~ SD' reads all three arms of both duration rows", {
  r <- parseBaselineTableHeuristics(announcedPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Duration of operation"], c(81, 82, 81))
  expect_identical(cont$SD[cont$ROW == "Duration of operation"], c(34, 29, 39))
  expect_identical(cont$MEAN[cont$ROW == "Duration of anaesthesia"], c(108, 108, 104))
  expect_identical(cont$SD[cont$ROW == "Duration of anaesthesia"], c(38, 34, 40))
})
