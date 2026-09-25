# test-stratum-header.R - a labelled "(n = k)" line inside a table opens a
# stratum: the rows beneath carry its arm sizes and its name (ISSUES.md
# issue 55, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 7 finding M1 (Fujii & Nakayama 2006, Clin Ther;   #
# PMID 16982288): Table I prints "Young patients (n = 75) (n = 25) (n =    #
# 25) (n = 25)" and, half-way down, "Older patients (n = 75) (n = 25) ..." #
# under a column header of "(n = 50)", each stratum with the same          #
# variables as "Mean (SD)" / "Range" sub-rows. The hybrid reading had      #
# every variable three times, two of them with the column header's N.     #
############################################################################

stratumPdf <- function(file = file.path(tempdir(), "stratum.pdf")) {
  vx <- c(240, 340, 440)
  cells <- c(
    list(list(x = 40, y = 60, text = "Table I. Demographic baseline and clinical characteristics.", adj = 0)),
    rowCells(84,  "", c("Drug 25 mg", "Drug 50 mg", "Vehicle"), vx),
    rowCells(100, "Characteristic", c("(n = 50)", "(n = 50)", "(n = 50)"), vx),
    rowCells(120, "Young patients (n = 75)", c("(n = 25)", "(n = 25)", "(n = 25)"), vx),
    list(list(x = 40, y = 138, text = "Age, y", adj = 0)),
    rowCells(154, "Mean (SD)", c("30 (5)", "31 (5)", "31 (4)"), vx, labelX = 50),
    rowCells(170, "Range", c("20-39", "21-39", "21-38"), vx, labelX = 50),
    rowCells(188, "Sex, male/female, no.", c("13/12", "12/13", "13/12"), vx),
    list(list(x = 40, y = 206, text = "Weight, kg", adj = 0)),
    rowCells(222, "Mean (SD)", c("56 (9)", "59 (9)", "58 (9)"), vx, labelX = 50),
    rowCells(240, "Older patients (n = 75)", c("(n = 25)", "(n = 25)", "(n = 25)"), vx),
    list(list(x = 40, y = 258, text = "Age, y", adj = 0)),
    rowCells(274, "Mean (SD)", c("70 (6)", "71 (7)", "70 (6)"), vx, labelX = 50),
    rowCells(290, "Sex, male/female, no.", c("13/12", "13/12", "12/13"), vx),
    list(list(x = 40, y = 308, text = "Weight, kg", adj = 0)),
    rowCells(324, "Mean (SD)", c("54 (10)", "53 (9)", "54 (10)"), vx, labelX = 50),
    list(list(x = 40, y = 350, text = "*No significant between-group differences were found.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("each stratum's rows carry its arm sizes and its name; the arms table keeps the column header's", {
  r <- parseBaselineTableHeuristics(stratumPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(50L, 50L, 50L))
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(d$ROW), c("Young patients: Age, y", "Young patients: Weight, kg",
                                   "Older patients: Age, y", "Older patients: Weight, kg"))
  expect_true(all(d$N == 25L))
  expect_identical(d$MEAN[d$ROW == "Young patients: Age, y"], c(30, 31, 31))
  expect_identical(d$MEAN[d$ROW == "Older patients: Age, y"], c(70, 71, 70))
  expect_false(any(grepl(" 2$", r$data$ROW)))
  # the fraction rows are categories of their stratum; the footnote is no heading
  expect_true(all(c("Young patients: Sex, male/female, no.", "Older patients: Sex, male/female, no.") %in% r$data$ROW))
  expect_false(any(grepl("significant", r$data$ROW)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a bare (n = k) line under a row is still that row's own n, not a stratum", {
  vx <- c(250, 320, 390, 460)
  f <- file.path(tempdir(), "bareN.pdf")
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Demographic characteristics.", adj = 0)),
    rowCells(96,  "", c("0.15 mg", "0.3 mg", "0.6 mg", "Placebo"), vx),
    rowCells(112, "", c("(n = 20)", "(n = 20)", "(n = 20)", "(n = 20)"), vx),
    rowCells(140, "Age, y", c("46 ± 8", "47 ± 8", "47 ± 8", "48 ± 6"), vx),
    rowCells(158, "Last menstrual cycle, d*", c("15 ± 4", "16 ± 3", "16 ± 2", "16 ± 3"), vx),
    rowCells(172, "", c("(n = 12)", "(n = 13)", "(n = 12)", "(n = 12)"), vx),
    rowCells(190, "Duration of surgery, min", c("170 ± 38", "172 ± 47", "177 ± 43", "174 ± 48"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$N[grepl("^Last menstrual", d$ROW)], c(12L, 13L, 12L, 12L))
  expect_identical(d$N[grepl("^Duration", d$ROW)], rep(20L, 4))
  expect_false(any(grepl(":", d$ROW)))
})
