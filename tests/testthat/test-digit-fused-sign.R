# test-digit-fused-sign.R - on a line whose other cells fix the sign, a
# cell word with a DIGIT where the sign was ("47.357.9") and a soup word
# glued to the SD alone after a bare number ("50.1" "k8.0") are read as
# mean +/- SD cells (ISSUES.md issue 90, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 23 on AAS1998_851 (Saitoh, Acta Anaesthesiol      #
# Scand 1998;42:851, Loadsman corpus): after issue 85 Height read four     #
# arms but Age "48.4k7.2 46.9Z7.7 47.357.9 44 50.1 k8.0" and Weight        #
# "56.429.2 56.7?9.0 57.8Z9.4 66 58.527.8" were still skipped as bare      #
# numbers with no SD.                                                      #
############################################################################

mk <- function(text, x, width = 30) data.frame(text = text, x = x, width = width, y = 0,
                                               stringsAsFactors = FALSE)

test_that("the digit-fused and split-soup forms are read when the line's other cells fix the sign", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "48.4k7.2", "46.9Z7.7", "47.357.9", "44", "50.1", "k8.0"), c(60, 180, 240, 300, 360, 400, 440)),
    mk(c("Weight", "56.429.2", "56.7?9.0", "57.8Z9.4", "66", "58.527.8"), c(60, 180, 240, 300, 360, 400)),
    mk(c("Height", "166.9", "\u00b1", "8.4", "168.0", "\u00b1", "8.5", "165.257.1"), c(60, 180, 200, 210, 240, 260, 270, 300)),
    mk(c("Dose", "47.357.9", "50.1", "k8.0"), c(60, 180, 240, 300)),            # no sign cell: untouched
    mk(c("Rate", "12k3", "13.5Z2.1", "47.357.9"), c(60, 180, 240, 300)))       # precisions disagree: letters only
  rep <- .ppRepairFusedSigns(lines, capIdx = 1L)
  expect_identical(rep$lines[[2]]$text,
                   c("Age", "48.4", "\u00b1", "7.2", "46.9", "\u00b1", "7.7", "47.3", "\u00b1", "7.9",
                     "44", "50.1", "\u00b1", "8.0"))
  expect_identical(rep$lines[[3]]$text,
                   c("Weight", "56.4", "\u00b1", "9.2", "56.7", "\u00b1", "9.0", "57.8", "\u00b1", "9.4",
                     "66", "58.5", "\u00b1", "7.8"))
  expect_identical(rep$lines[[4]]$text,
                   c("Height", "166.9", "\u00b1", "8.4", "168.0", "\u00b1", "8.5", "165.2", "\u00b1", "7.1"))
  expect_identical(rep$lines[[5]]$text, lines[[5]]$text)
  expect_identical(rep$lines[[6]]$text, c("Rate", "12", "\u00b1", "3", "13.5", "\u00b1", "2.1", "47.357.9"))
  expect_identical(rep$repaired, 4L + 4L + 1L + 2L)
  # the split words keep the cell's extent
  a <- rep$lines[[2]]
  expect_equal(a$x[8], 300); expect_equal(a$x[10] + a$width[10], 330, tolerance = 1e-6)
  expect_equal(a$x[13], 440); expect_equal(a$x[14] + a$width[14], 470, tolerance = 1e-6)
})

saitohPdf <- function(file = file.path(tempdir(), "digitFusedSign.pdf")) {
  vx <- c(230, 320, 410, 500)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Demographic data of patients", adj = 0)),
    rowCells(90, "Group", c("50", "30", "20", "10"), vx),
    rowCells(108, "Number", c("40", "40", "40", "15"), vx),
    rowCells(126, "Gender (M/F)", c("22/18", "22/18", "22/18", "8/7"), vx),
    rowCells(144, "Age (yr)", c("48.4k7.2", "46.9Z7.7", "47.357.9", "50.1 k8.0"), vx),
    rowCells(162, "Height (cm)", c("166.9k8.4", "168.0?8.5", "165.2k8.1", "165.7k9.0"), vx),
    rowCells(180, "Weight (kg)", c("56.429.2", "56.7?9.0", "57.8Z9.4", "58.527.8"), vx),
    list(list(x = 60, y = 210, text = "Values are number or mean-cSD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt Saitoh page reads Age and Weight beside Height, four arms each", {
  r <- parseBaselineTableHeuristics(saitohPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Weight"))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(48.4, 46.9, 47.3, 50.1))
  expect_identical(cont$SD[cont$ROW == "Age"], c(7.2, 7.7, 7.9, 8.0))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(56.4, 56.7, 57.8, 58.5))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(9.2, 9.0, 9.4, 7.8))
  expect_identical(r$arms$N, c(40L, 40L, 40L, 15L))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
