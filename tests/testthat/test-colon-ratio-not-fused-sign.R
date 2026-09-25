# test-colon-ratio-not-fused-sign.R - "19:21" under "Sex M:F" is a ratio of
# counts, not a mean with the sign set as a colon (ISSUES.md issue 92,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 23b AB2 (CJA 1997;44:390, page 3, four arms       #
# 40/40/40/10): after issue 85 a "Sex M:F" row printing "19:21 19:21      #
# 19:21 5:5" read as a continuous variable with MEAN 19 and SD 21, and     #
# the trial's P_FULL moved from 0.013 to 0.125.                            #
############################################################################

mk <- function(text, x, width = 30) data.frame(text = text, x = x, width = width, y = 0,
                                               stringsAsFactors = FALSE)

test_that("the fused-sign helper leaves colon ratios alone and still splits letter forms", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Sex", "M:F", "19:21", "19:21", "19:21", "5:5"), c(60, 90, 180, 240, 300, 360)),
    mk(c("Age", "48.4k7.2", "46.9Z7.7", "47.3k7.9"), c(60, 180, 240, 300)))
  rep <- .ppRepairFusedSigns(lines, capIdx = 1L)
  expect_identical(rep$lines[[2]]$text, lines[[2]]$text)
  expect_identical(rep$lines[[3]]$text,
                   c("Age", "48.4", "\u00b1", "7.2", "46.9", "\u00b1", "7.7", "47.3", "\u00b1", "7.9"))
  expect_identical(rep$repaired, 3L)
})

ratioPdf <- function(file = file.path(tempdir(), "colonRatio.pdf")) {
  vx <- c(230, 320, 410, 500)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table II Patient characteristics", adj = 0)),
    rowCells(90, "", c("Group A (n = 40)", "Group B (n = 40)", "Group C (n = 40)", "Group D (n = 10)"), vx),
    rowCells(108, "Age (yr)", c("48 \u00b1 7", "47 \u00b1 8", "47 \u00b1 8", "50 \u00b1 8"), vx),
    rowCells(126, "Sex M:F", c("19:21", "19:21", "19:21", "5:5"), vx),
    rowCells(144, "Height (cm)", c("166 \u00b1 8", "168 \u00b1 9", "165 \u00b1 8", "166 \u00b1 9"), vx),
    rowCells(162, "Weight (kg)", c("56 \u00b1 9", "57 \u00b1 9", "58 \u00b1 9", "59 \u00b1 8"), vx),
    list(list(x = 60, y = 190, text = "Values are mean \u00b1 SD or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with a 'Sex M:F' ratio row reads no continuous Sex variable", {
  r <- parseBaselineTableHeuristics(ratioPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Weight"))
  expect_false(any(grepl("^Sex", cont$ROW)))
  expect_identical(r$arms$N, c(40L, 40L, 40L, 10L))
})
