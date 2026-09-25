# test-announced-letter-glyph.R - a legend that names a LETTER as the
# plus-minus ("Values are means F SD") makes that letter the sign between
# two numbers (ISSUES.md issue 67, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 13 finding R1 (Fujii 2006, PMID 17126782): the   #
# Symbol-font plus-minus is mapped to "F" throughout Table 1 ("Age (y) 30 #
# F 4 31 F 5 32 F 5 31 F 4"), the legend reads "Values are means F SD or  #
# numbers.", and the deterministic engine read one arm and two variables. #
# The stratum lines ("Young patients (n = 80)", "Elderly patients (n =    #
# 80)") then never had rows to prefix, and the trial's reading was the    #
# model's alone - a different shape on each run.                          #
############################################################################

test_that("the helper: an announced letter between two numbers is the sign; unannounced it is not", {
  mk <- function(text, x) data.frame(text = text, x = x, width = rep(8, length(text)),
                                     y = 0, stringsAsFactors = FALSE)
  rows <- list(
    mk(c("Table", "1", "Patient", "demographics"), c(60, 90, 100, 140)),
    mk(c("Age", "(y)", "30", "F", "4", "31", "F", "5"), c(60, 80, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "(cm)", "164", "F", "7", "163", "F", "7"), c(60, 90, 180, 200, 210, 240, 260, 270)))
  said <- c(rows, list(mk(c("Values", "are", "means", "F", "SD", "or", "numbers."), c(60, 90, 110, 140, 150, 170, 180))))
  rep <- .ppRepairPlusMinusGlyphs(said, capIdx = 1L)
  expect_identical(rep$repaired, 4L)
  expect_identical(rep$lines[[2]]$text, c("Age", "(y)", "30", "±", "4", "31", "±", "5"))
  # no legend: a letter between two numbers is left alone
  expect_identical(.ppRepairPlusMinusGlyphs(rows, capIdx = 1L)$repaired, 0L)
  # a word of the legend's own ("means and SD") names no glyph
  andSD <- c(rows, list(mk(c("Values", "are", "means", "and", "SD."), c(60, 90, 110, 140, 160))))
  expect_identical(.ppRepairPlusMinusGlyphs(andSD, capIdx = 1L)$repaired, 0L)
  # a letter other than the announced one is not the sign
  other <- c(rows, list(mk(c("Values", "are", "means", "G", "SD."), c(60, 90, 110, 140, 150))))
  expect_identical(.ppRepairPlusMinusGlyphs(other, capIdx = 1L)$repaired, 0L)
})

letterPdf <- function(file = file.path(tempdir(), "letterF.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient demographics", adj = 0)),
    rowCells(100, "", c("Placebo", "Lidocaine"), vx),
    rowCells(118, "No.", c("20", "20"), vx),
    rowCells(136, "Age (y)", c("30 F 4", "31 F 5"), vx),
    rowCells(154, "Gender (men/women)", c("10/10", "11/9"), vx),
    rowCells(172, "Height (cm)", c("164 F 7", "163 F 7"), vx),
    rowCells(190, "Weight (kg)", c("58 F 10", "57 F 9"), vx),
    list(list(x = 60, y = 220, text = "Values are means F SD or numbers.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with the letter glyph reads its three continuous variables and validates", {
  r <- parseBaselineTableHeuristics(letterPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Weight"))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(30, 31))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(10, 9))
  expect_identical(r$arms$N, c(20L, 20L))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
