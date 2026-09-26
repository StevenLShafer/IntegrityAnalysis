# test-digit-fused-sign-at-integer-precision.R - on a line of whole-number
# cells whose letter-fused cells fix the SD's digit count, a word of digits
# alone is a mean, a digit for the sign, and the SD ("4329" is 43 +/- 9)
# (ISSUES.md issue 141, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's arm-count audit (BJA 1998, PMID 9689270; four arms of   #
# 30): "Age (years) 45i8 44i7 4329 4428 NS", "Height (cm) 154i6 153i4      #
# 15626 15625 NS", "Duration of anaesthesia (min) 98t26 99526 102232 95528 #
# NS" - Age, Height and Weight read two arms of four.                      #
############################################################################

pm <- "\u00b1"

test_that("the fused-sign repair splits integer digit-fused words by the letter-fused cells' SD digits", {
  w <- function(...) { t <- c(...); data.frame(text = t, x = cumsum(c(0, head(nchar(t) + 1, -1))) * 6, width = nchar(t) * 6, stringsAsFactors = FALSE) }
  lines <- list(w("Table"),
                w("Age", "(years)", "45i8", "44i7", "4329", "4428", "NS"),
                w("Height", "(cm)", "154i6", "153i4", "15626", "15625", "NS"),
                w("Duration", "of", "anaesthesia", "(min)", "98t26", "99526", "102232", "95528", "NS"),
                # a bare count on such a line is not a cell: no two-digit mean within reach
                w("Smokers", "(n)", "3i1", "2i1", "120", "4", "NS"))
  r <- .ppRepairFusedSigns(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Age", "(years)", "45", pm, "8", "44", pm, "7", "43", pm, "9", "44", pm, "8", "NS"))
  expect_identical(r$lines[[3]]$text, c("Height", "(cm)", "154", pm, "6", "153", pm, "4", "156", pm, "6", "156", pm, "5", "NS"))
  expect_identical(r$lines[[4]]$text, c("Duration", "of", "anaesthesia", "(min)", "98", pm, "26", "99", pm, "26", "102", pm, "32", "95", pm, "28", "NS"))
  expect_identical(r$lines[[5]]$text, c("Smokers", "(n)", "3", pm, "1", "2", pm, "1", "120", "4", "NS"))
  # one letter-fused cell beside a digit word whose mean is out of range: no
  # second witness, nothing split (CodeRabbit on PR #450)
  r <- .ppRepairFusedSigns(list(w("Dose", "45i8", "1200")))
  expect_identical(r$lines[[1]]$text, c("Dose", "45i8", "1200"))
})

integerFusedPdf <- function(file = file.path(tempdir(), "integerFused.pdf")) {
  vx <- c(225, 293, 370, 447)
  cells <- c(
    list(list(x = 52, y = 60, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(80, "", c("G", "D", "M", "P"), vx + 10, labelX = 52),
    rowCells(94, "", c("(n = 30)", "(n = 30)", "(n = 30)", "(n = 30)"), vx + 10, labelX = 52),
    rowCells(112, "Age (years)", c("45i8", "44i7", "4329", "4428"), vx, labelX = 52),
    rowCells(130, "Height (cm)", c("154i6", "153i4", "15626", "15625"), vx, labelX = 52),
    rowCells(148, "Weight (kg)", c("56i8", "5428", "5428", "56i7"), vx, labelX = 52),
    rowCells(166, "Duration of anaesthesia (min)", c("98t26", "99526", "102232", "95528"), vx, labelX = 52),
    list(list(x = 52, y = 200, text = "Values are mean (SD) or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with letter- and digit-fused whole-number cells reads every arm", {
  r <- parseBaselineTableHeuristics(integerFusedPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(30L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(45, 44, 43, 44))
  expect_identical(cont$SD[cont$ROW == "Height"], c(6, 4, 6, 5))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(56, 54, 54, 56))
  expect_identical(cont$MEAN[grepl("^Duration", cont$ROW)], c(98, 99, 102, 95))
  expect_identical(cont$SD[grepl("^Duration", cont$ROW)], c(26, 26, 32, 28))
})
