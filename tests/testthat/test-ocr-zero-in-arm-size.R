# test-ocr-zero-in-arm-size.R - a letter O for a zero inside an "(n = k)"
# group is read as the zero (ISSUES.md issue 75, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 17 finding W2 (Fujii 1999, Can J Anaesth, PMID    #
# 10522590): the OCR text layer prints "(n=4O)" beside "(n=40)"; the size  #
# regex read 4, "O)" joined the first arm's name, and the arm went out    #
# with N = 4 - a wrong number the hybrid merge doubled into a phantom arm. #
############################################################################

test_that("the helper: O among digits in an (n = k) group is a zero, glued or split; nothing else changes", {
  mk <- function(text) data.frame(text = text, x = seq_along(text) * 40, width = 20, y = 0,
                                  stringsAsFactors = FALSE)
  lines <- list(
    mk(c("Table", "1")),
    mk(c("Granisetron", "Ramosetron")),
    mk(c("(n=4O)", "(n=40)")),                    # glued
    mk(c("(n", "=", "1OO)", "(n", "=", "100)")),   # split
    mk(c("Oral", "O)", "n=O", "SpO2", "40", "(n=O2)")))   # untouched: no digit with the O, or not a size
  rep <- .ppRepairSizeZeros(lines, capIdx = 1L)
  expect_identical(rep$repaired, 3L)     # "(n=4O)", "1OO)" and "(n=O2)"
  expect_identical(rep$lines[[3]]$text, c("(n=40)", "(n=40)"))
  expect_identical(rep$lines[[4]]$text, c("(n", "=", "100)", "(n", "=", "100)"))
  expect_identical(rep$lines[[5]]$text[1:4], c("Oral", "O)", "n=O", "SpO2"))
  expect_identical(rep$lines[[5]]$text[6], "(n=02)")   # a size group with a digit: O is 0 (n = 2)
  expect_identical(.ppRepairSizeZeros(lines, capIdx = 5L)$repaired, 0L)
})

ocrZeroPdf <- function(file = file.path(tempdir(), "ocrZero.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE I Patient demographics", adj = 0)),
    rowCells(100, "", c("Granisetron", "Ramosetron"), vx),
    rowCells(112, "", c("(n=4O)", "(n=40)"), vx),
    rowCells(130, "Age (yr)", c("45 ± 9", "47 ± 10"), vx),
    rowCells(148, "Height (cm)", c("157 ± 7", "157 ± 7"), vx),
    rowCells(166, "Weight (kg)", c("54 ± 6", "55 ± 8"), vx),
    list(list(x = 60, y = 196, text = "Values are mean ± SD or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with '(n=4O)' reads two arms of 40 with clean names", {
  r <- parseBaselineTableHeuristics(ocrZeroPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(40L, 40L))
  expect_identical(r$arms$arm, c("Granisetron", "Ramosetron"))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$N[cont$ROW == "Age"], c(40L, 40L))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(45, 47))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
