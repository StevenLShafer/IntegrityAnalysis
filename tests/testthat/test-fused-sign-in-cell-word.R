# test-fused-sign-in-cell-word.R - a mean +/- SD cell set as one word with a
# letter or symbol where the sign was ("48.4k7.2") is split into its three
# words (ISSUES.md issue 85, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 20 finding Z1 (Saitoh, Acta Anaesthesiol Scand     #
# 1998;42:851, Loadsman corpus): "48.4k7.2 46.9Z7.7 47.357.9 44 50.1 k8.0"  #
# on the Age row, "166.9k8.4 168.0?8.5 165.2k8.1 170 165.7k9.0" on Height; #
# the deterministic pass read Gender alone and scored a Gender-only table. #
############################################################################

mk <- function(text, x, width = 30) data.frame(text = text, x = x, width = width, y = 0,
                                               stringsAsFactors = FALSE)

test_that("the helper splits fused cells two or more to a line, and leaves exponents, dimensions and lone words", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "48.4k7.2", "46.9Z7.7", "168.0?8.5"), c(60, 180, 240, 300)),
    mk(c("Dose", "1e5", "10x20", "3.2k1.1"), c(60, 180, 240, 300)),   # one fused word only
    mk(c("Rate", "12", "13"), c(60, 180, 240)))
  rep <- .ppRepairFusedSigns(lines, capIdx = 1L)
  expect_identical(rep$repaired, 3L)
  expect_identical(rep$lines[[2]]$text,
                   c("Age", "48.4", "±", "7.2", "46.9", "±", "7.7", "168.0", "±", "8.5"))
  expect_identical(rep$lines[[3]]$text, lines[[3]]$text)
  expect_identical(rep$lines[[4]]$text, lines[[4]]$text)
  # the split words keep the cell's extent
  a <- rep$lines[[2]]
  expect_equal(a$x[2], 180); expect_equal(a$x[4] + a$width[4], 210, tolerance = 1e-6)
})

fusedPdf <- function(file = file.path(tempdir(), "fusedSign.pdf")) {
  vx <- c(230, 320, 410, 500)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Demographic data of patients", adj = 0)),
    rowCells(90, "Group", c("50", "30", "20", "10"), vx),
    rowCells(108, "Number", c("40", "40", "40", "40"), vx),
    rowCells(126, "Gender (M/F)", c("22/18", "22/18", "22/18", "21/19"), vx),
    rowCells(144, "Age (yr)", c("48.4k7.2", "46.9Z7.7", "47.3k7.9", "50.1k8.0"), vx),
    rowCells(162, "Height (cm)", c("166.9k8.4", "168.0?8.5", "165.2k8.1", "165.7k9.0"), vx),
    rowCells(180, "Weight (kg)", c("56.4k9.2", "56.7k9.0", "57.8k9.4", "58.5k7.8"), vx),
    list(list(x = 60, y = 210, text = "Values are number or mean-cSD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with fused cells reads Age, Height and Weight across four arms", {
  r <- parseBaselineTableHeuristics(fusedPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Weight"))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(48.4, 46.9, 47.3, 50.1))
  expect_identical(cont$SD[cont$ROW == "Height"], c(8.4, 8.5, 8.1, 9.0))
  expect_identical(r$arms$N, rep(40L, 4))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
