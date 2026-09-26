# test-lost-decimal-point.R - two more ways a decimal number comes apart in
# a text layer: the point lost between the mean's parts before the sign
# ("152" "9" for 152.9), and the point kept with the second part inside a
# bracket ("(41" ".l)" for (41.1)) (ISSUES.md issue 140, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's arm-count audit: Anesth Analg 1997, PMID 9067046,       #
# "Height(cm) 154.4 <bullet> 5.8 152 9 <bullet> 4.5 154.8 <bullet> 5.1     #
# 155.1 <bullet> 5.8" (three cells of four); Anesth Analg 1999, PMID       #
# 10201761, "175.9 (41 .l) 173.6 (44.5) 177.1 (39.4)" (two of three).      #
############################################################################

pm <- "\u00b1"; bu <- "\u2022"

test_that("the helper restores a lost point before the sign and a point kept with the bracketed second part", {
  L <- data.frame(text = c("Height(cm)", "154.4", bu, "5.8", "152", "9", bu, "4.5", "154.8", bu, "5.1"),
                  x = c(58, 195, 217, 224, 275, 290, 297, 304, 357, 379, 386), width = c(40, 20, 4, 12, 13, 5, 4, 12, 20, 4, 12),
                  stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(data.frame(text = "Table", x = 58, width = 20), L), capIdx = 1L)
  expect_identical(r$repaired, 1L)
  expect_identical(r$lines[[2]]$text, c("Height(cm)", "154.4", bu, "5.8", "152.9", bu, "4.5", "154.8", bu, "5.1"))
  L2 <- data.frame(text = c("of", "175.9", "(41", ".l)", "173.6", "(44.5)"),
                   x = c(159, 262, 284, 295, 340, 361), width = c(8, 20, 10, 8, 20, 22), stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L2))
  expect_identical(r$lines[[1]]$text, c("of", "175.9", "(41.1)", "173.6", "(44.5)"))
  # the bracket split without the point, the OCR's O for the zero: "(1" "O)"
  L4 <- data.frame(text = c("Mean", "(SD)", "54", "(10)", "53", "(9)", "54", "(1", "O)", "12", "(1", "2)"),
                   x = c(60, 85, 150, 165, 200, 215, 250, 265, 275, 300, 315, 325), width = c(22, 20, 12, 20, 12, 15, 12, 9, 10, 12, 9, 10),
                   stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L4))
  expect_identical(r$lines[[1]]$text, c("Mean", "(SD)", "54", "(10)", "53", "(9)", "54", "(10)", "12", "(1", "2)"))
  # two whole numbers before a sign on a line of whole numbers are two numbers
  L3 <- data.frame(text = c("Weight", "54", "8", pm, "7", "55", pm, "8"),
                   x = c(58, 195, 210, 217, 224, 275, 297, 304), width = c(28, 13, 5, 4, 5, 13, 4, 5), stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L3))
  expect_identical(r$repaired, 0L)
})

lostPointPdf <- function(file = file.path(tempdir(), "lostPoint.pdf")) {
  vx <- c(195, 275, 357, 444)
  cell <- function(y, k, mean, sd, split = FALSE) c(
    # the split mean's two parts two points apart, the sign and SD clear of them
    if (split) list(list(x = vx[k], y = y, text = sub("[.].*$", "", mean), adj = 0),
                    list(x = vx[k] + 19, y = y, text = sub("^.*[.]", "", mean), adj = 0))
    else list(list(x = vx[k], y = y, text = mean, adj = 0)),
    list(list(x = vx[k] + 30, y = y, text = pm, adj = 0), list(x = vx[k] + 38, y = y, text = sd, adj = 0)))
  row <- function(y, label, means, sds, splitAt = 0) c(
    list(list(x = 58, y = y, text = label, adj = 0)),
    unlist(lapply(1:4, function(k) cell(y, k, means[k], sds[k], split = k == splitAt)), recursive = FALSE))
  cells <- c(
    list(list(x = 58, y = 60, text = "Table 1. Patient Characteristics", adj = 0)),
    rowCells(80, "", c("A", "B", "C", "D"), vx + 14, labelX = 58),
    rowCells(94, "", c("(n = 25)", "(n = 25)", "(n = 25)", "(n = 25)"), vx + 14, labelX = 58),
    row(112, "Age (yr)", c("44.2", "45.1", "43.8", "44.9"), c("8.1", "7.9", "8.4", "9.0")),
    row(130, "Height (cm)", c("154.4", "152.9", "154.8", "155.1"), c("5.8", "4.5", "5.1", "5.8"), splitAt = 2),
    list(list(x = 58, y = 162, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the mean whose point was lost", {
  r <- parseBaselineTableHeuristics(lostPointPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(154.4, 152.9, 154.8, 155.1))
  expect_identical(cont$SD[cont$ROW == "Height"], c(5.8, 4.5, 5.1, 5.8))
})
