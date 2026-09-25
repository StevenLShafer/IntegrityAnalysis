# test-meansd-with-range.R - a mean +/- SD cell with a bracketed range
# appended, the plus-minus set as a plain "+", and a "[ranges]" label suffix
# (ISSUES.md issue 63, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 11 finding P1 (Fujii 1998, PMID 9649986): rows    #
# "Height (cm) [ranges] 153.3 + 6.7[147-171] ..." across four arms of 30.  #
# The "+" left the mean a plain number and the SD a median-with-range      #
# token, so the row was skipped; only Age survived (p 0.057 -> 0.60).      #
############################################################################

test_that("a bracketed range after a mean +/- SD cell is part of the cell; a '+' is a plus-minus when a range follows", {
  line <- data.frame(text = c("48.4", "±", "7.6", "[33-63]", "46.0", "+8.0[29-61]", "5", "+", "2"),
                     x = c(200, 222, 232, 252, 300, 322, 400, 412, 420), width = c(20, 6, 16, 34, 20, 60, 6, 6, 6),
                     stringsAsFactors = FALSE)
  t <- .ppTokenizeLine(line)
  expect_identical(t$type[1:2], c("meanSD", "meanSD"))
  expect_identical(t$num1[1:2], c(48.4, 46.0))
  expect_identical(t$num2[1:2], c(7.6, 8.0))
  # "5 + 2" with no range stays two plain numbers (the block walker's announced rules decide those)
  expect_true(all(t$type[-(1:2)] == "plain"))
})

test_that("'[ranges]' after a label is notation", {
  expect_identical(.ppCleanLabel("Height (cm) [ranges]"), "Height")
  expect_identical(.ppCleanLabel("Duration of operation min [ranges]"), "Duration of operation min")
  expect_identical(.ppCleanLabel("Weight (kg) [range]"), "Weight")
})

test_that("a page whose cells carry ranges parses with its means and SDs", {
  f  <- file.path(tempdir(), "meansdRange.pdf")
  vx <- c(200, 320, 440)
  cells <- c(
    list(list(x = 40, y = 70, text = "Table 1. Patient demographics", adj = 0)),
    rowCells(100, "Group", c("Placebo (n=30)", "Drug 20 (n=30)", "Drug 40 (n=30)"), vx),
    rowCells(130, "Age (years)",       c("48.4 ± 7.6 [33-63]", "46.0 ± 8.0 [29-61]", "46.8 ± 9.9 [25-63]"), vx),
    rowCells(148, "Height (cm) [ranges]", c("153.3 ± 6.7 [147-171]", "157.8 ± 6.5 [145-172]", "157.3 ± 6.1 [149-172]"), vx),
    rowCells(166, "Weight (kg) [ranges]", c("55.7 +7.4[44-72]", "56.3 +8.5[42-76]", "55.0 +7.9[45-78]"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(d$ROW), c("Age", "Height", "Weight"))
  expect_identical(d$MEAN[d$ROW == "Height"], c(153.3, 157.8, 157.3))
  expect_identical(d$SD[d$ROW == "Weight"],   c(7.4, 8.5, 7.9))
  expect_identical(r$arms$N, rep(30L, 3))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
