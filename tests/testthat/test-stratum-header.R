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

# ---- the first size line as a stratum (batch 8, N2: Fujii & Shiga 2006, PMID 17163298) ----
test_that("a first size line naming a population with one size, the arm names on their own line above, is a stratum", {
  vx <- c(240, 340, 440)
  f <- file.path(tempdir(), "stratumFirst.pdf")
  cells <- c(
    list(list(x = 40, y = 60, text = "Table I. Patient demographics", adj = 0)),
    rowCells(84,  "Variable", c("Placebo", "Metoclopramide 2.5", "Metoclopramide 5"), vx),
    list(list(x = 40, y = 104, text = "Younger patients (20-40y) [n = 60]", adj = 0)),
    rowCells(122, "n", c("20", "20", "20"), vx),
    rowCells(140, "Age (y)", c("31 ± 5", "30 ± 6", "31 ± 5"), vx),
    rowCells(158, "Weight (kg)", c("56 ± 9", "57 ± 8", "55 ± 9"), vx),
    list(list(x = 40, y = 180, text = "Older patients (60-80y) [n = 60]", adj = 0)),
    rowCells(198, "n", c("20", "20", "20"), vx),
    rowCells(216, "Age (y)", c("70 ± 4", "71 ± 5", "71 ± 4"), vx),
    rowCells(234, "Weight (kg)", c("54 ± 10", "53 ± 9", "54 ± 10"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$N, rep(20L, 3))
  d <- r$data[!is.na(r$data$MEAN), ]
  rows <- unique(gsub(intToUtf8(0x2212), "-", d$ROW, fixed = TRUE))
  expect_setequal(rows, c("Younger patients (20-40y): Age", "Younger patients (20-40y): Weight",
                          "Older patients (60-80y): Age", "Older patients (60-80y): Weight"))
  expect_true(all(d$N == 20L))
  expect_identical(d$MEAN[grepl("^Younger.*Age", d$ROW)], c(31, 30, 31))
  expect_identical(d$MEAN[grepl("^Older.*Age", d$ROW)], c(70, 71, 71))
})

# ---- CodeRabbit on PR #363 -------------------------------------------------
test_that("a stratum line's sole size is its total, never an arm's, even when it sits over the first arm column", {
  vx <- c(240, 340, 440)
  f <- file.path(tempdir(), "stratumTotal.pdf")
  cells <- c(
    list(list(x = 40, y = 60, text = "Table I. Patient demographics", adj = 0)),
    rowCells(84,  "Variable", c("Placebo", "Drug 2.5", "Drug 5"), vx),
    list(list(x = 40, y = 104, text = "Younger patients (20-40y)", adj = 0), list(x = 232, y = 104, text = "[n = 60]", adj = 0)),
    rowCells(126, "Age (y)", c("31 ± 5", "30 ± 6", "31 ± 5"), vx),
    rowCells(144, "Weight (kg)", c("56 ± 9", "57 ± 8", "55 ± 9"), vx),
    list(list(x = 40, y = 166, text = "Older patients (60-80y)", adj = 0), list(x = 232, y = 166, text = "[n = 60]", adj = 0)),
    rowCells(188, "Age (y)", c("70 ± 4", "71 ± 5", "71 ± 4", "x"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_false(any(!is.na(r$arms$N) & r$arms$N == 60L))
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_false(any(!is.na(d$N) & d$N == 60L))
})

# ---- a wrapped arm header is no stratum (issue 55, second follow-up) --------
# The pasted-screenshot shape of test-image-uploads.R, here through the text
# layer under a caption: "Characteristic Control Treatment (n = 17)" with the
# first arm's "(n = 15)" wrapped onto the next line. #363's population test
# matched "men" inside "Treatment" and made the header a stratum.
test_that("a first size line whose next line is a size line is the header, wrapped - and 'Treatment' is no population", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "wrappedHeaderText.pdf")
  cells <- c(
    list(list(x = 72, y = 60, text = "Table 1. Baseline characteristics", adj = 0)),
    rowCells(80,  "Characteristic", c("Control", "Treatment (n = 17)"), vx),
    rowCells(98,  "",               c("(n = 15)", ""),                  vx),
    rowCells(126, "Age (yr)",       c("45.3 (12.1)", "46.1 (11.8)"),    vx),
    rowCells(144, "Weight (kg)",    c("63 (13)",     "68 (12)"),        vx),
    rowCells(162, "Male, n (%)",    c("10 (67%)",    "12 (71%)"),       vx),
    rowCells(180, "Smoker, n (%)",  c("4 (27%)",     "5 (29%)"),        vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_equal(r$arms$N, c(15, 17))
  expect_setequal(unique(r$data$ROW), c("Age", "Weight", "Male", "Smoker"))
  expect_equal(nrow(r$skipped), 0L)
  # a genuine population line over the arms, one size, is still a stratum
  # when the line beneath it is not a size line
  f2 <- file.path(tempdir(), "populationFirst.pdf")
  cells2 <- c(
    list(list(x = 40, y = 60, text = "Table I. Patient demographics", adj = 0)),
    rowCells(84,  "Variable", c("Placebo", "Drug"), vx),
    list(list(x = 40, y = 104, text = "Women (n = 40)", adj = 0)),
    rowCells(126, "Age (y)", c("31 \u00b1 5", "30 \u00b1 6"), vx),
    rowCells(144, "Weight (kg)", c("56 \u00b1 9", "57 \u00b1 8"), vx))
  makeTablePdf(f2, cells2)
  r2 <- parseBaselineTableHeuristics(f2, quiet = TRUE)
  expect_true(all(grepl("^Women: ", r2$data$ROW)))
  # ... and when the arms' own size line follows the population line, the
  # population line is still the stratum, the sizes are the arms', and the
  # names come from the line above the stratum (CodeRabbit on PR #458)
  f3 <- file.path(tempdir(), "populationThenSizes.pdf")
  cells3 <- c(
    list(list(x = 40, y = 60, text = "Table I. Patient demographics", adj = 0)),
    rowCells(84,  "Variable", c("Placebo", "Drug"), vx),
    list(list(x = 40, y = 104, text = "Women (n = 40)", adj = 0)),
    rowCells(118, "", c("(n = 20)", "(n = 20)"), vx),
    rowCells(140, "Age (y)", c("31 \u00b1 5", "30 \u00b1 6"), vx),
    rowCells(158, "Weight (kg)", c("56 \u00b1 9", "57 \u00b1 8"), vx))
  makeTablePdf(f3, cells3)
  r3 <- parseBaselineTableHeuristics(f3, quiet = TRUE)
  expect_identical(r3$arms$arm, c("Placebo", "Drug"))
  expect_identical(r3$arms$N, c(20L, 20L))
  expect_true(all(grepl("^Women: ", r3$data$ROW)))
})
