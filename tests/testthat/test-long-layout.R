# The long categorical layout: one line per level per arm, the level in
# LEVEL and its count in N (Steve, 2026-09-05), accepted beside the wide
# layout and converted to it on validation.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-05,
# with .iaLongToWide() in R/app_globals.R.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
vd <- function(d) shiny::isolate(validateData(d))
runP <- function(v, m = 10000) {
  dqrng::dqset.seed(42); set.seed(42)
  suppressWarnings(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, m)))
}
summaryP <- function(x) suppressWarnings(as.numeric(x$P[which(x$ROW == "Summary")]))[1]

wideFrame <- data.frame(
  TRIAL = "T", ROW = c("Age", "Age", "Sex", "Sex", "Surgery", "Surgery"),
  N = c(50, 50, NA, NA, NA, NA), MEAN = c(61.2, 60.8, NA, NA, NA, NA), SD = c(10.4, 11.1, NA, NA, NA, NA),
  ROUND_MEAN = c(1, 1, NA, NA, NA, NA), ROUND_OBSERVATION = c(0, 0, NA, NA, NA, NA),
  MALE = c(NA, NA, 40, 34, NA, NA), FEMALE = c(NA, NA, 10, 16, NA, NA),
  UPPER = c(NA, NA, NA, NA, 7, 7), LOWER = c(NA, NA, NA, NA, 8, 15), UROLOGIC = c(NA, NA, NA, NA, 35, 28),
  stringsAsFactors = FALSE)
longFrame <- data.frame(
  TRIAL = "T",
  ROW = c("Age", "Age", "Sex", "Sex", "Sex", "Sex", "Surgery", "Surgery", "Surgery", "Surgery", "Surgery", "Surgery"),
  LEVEL = c("", "", "Male", "Male", "Female", "Female", "Upper", "Upper", "Lower", "Lower", "Urologic", "Urologic"),
  N = c(50, 50, 40, 34, 10, 16, 7, 7, 8, 15, 35, 28),
  MEAN = c(61.2, 60.8, rep(NA, 10)), SD = c(10.4, 11.1, rep(NA, 10)),
  ROUND_MEAN = c(1, 1, rep(NA, 10)), ROUND_OBSERVATION = c(0, 0, rep(NA, 10)),
  stringsAsFactors = FALSE)

test_that("the long layout validates to the wide one, and analyses identically", {
  vw <- vd(wideFrame); vl <- vd(longFrame)
  expect_false(isTRUE(vw$FAIL)); expect_false(isTRUE(vl$FAIL))
  expect_setequal(vl$CategoryNames, c("MALE", "FEMALE", "UPPER", "LOWER", "UROLOGIC"))
  expect_false("LEVEL" %in% names(vl$DATA))
  # same rows, same cells, in the same order
  cols <- c("TRIAL", "ROW", "N", "MEAN", "SD", "MALE", "FEMALE", "UPPER", "LOWER", "UROLOGIC")
  expect_equal(vl$DATA[, cols], vw$DATA[, cols], ignore_attr = TRUE)
  # the Monte Carlo cannot tell them apart
  expect_equal(summaryP(runP(vl)), summaryP(runP(vw)))
})

test_that("arm-grouped and level-grouped orders give the same table", {
  byArm <- longFrame[c(1, 3, 5, 7, 9, 11, 2, 4, 6, 8, 10, 12), ]   # arm 1's lines, then arm 2's
  vA <- vd(byArm); vL <- vd(longFrame)
  cols <- c("ROW", "N", "MEAN", "MALE", "FEMALE", "UPPER", "LOWER", "UROLOGIC")
  a <- vA$DATA[order(vA$DATA$ROW), cols]; l <- vL$DATA[order(vL$DATA$ROW), cols]
  expect_equal(a, l, ignore_attr = TRUE)
})

test_that("two variables may share level names, and a level named like a base column is prefixed", {
  d <- data.frame(
    TRIAL = "T", ROW = c("Smoker", "Smoker", "Smoker", "Smoker", "Diabetes", "Diabetes", "Diabetes", "Diabetes", "Grade", "Grade", "Grade", "Grade"),
    LEVEL = c("Yes", "Yes", "No", "No", "Yes", "Yes", "No", "No", "N", "N", "Mean", "Mean"),
    N = c(12, 14, 38, 36, 5, 6, 45, 44, 20, 22, 30, 28), MEAN = NA_real_, SD = NA_real_,
    stringsAsFactors = FALSE)
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  # "N" is a base column and "Mean" would be grepped as the MEAN column:
  # both become the variable's name and the level, in lower case
  expect_setequal(v$CategoryNames, c("YES", "NO", "grade n", "grade mean"))
  sm <- v$DATA[v$DATA$ROW == "Smoker", ]; db <- v$DATA[v$DATA$ROW == "Diabetes", ]
  expect_equal(sm$YES, c(12, 14)); expect_equal(db$NO, c(45, 44))
  expect_true(all(is.na(sm$`grade n`)))
  x <- runP(v)
  expect_true(is.finite(summaryP(x)))
})

test_that("a level whose name contains a grepped word is not mistaken for a base column", {
  d <- data.frame(TRIAL = "T", ROW = "Surgery", LEVEL = c("Obstetric", "Obstetric", "Brown", "Brown", "Other", "Other"),
                  N = c(10, 12, 5, 4, 35, 34), MEAN = NA_real_, SD = NA_real_, stringsAsFactors = FALSE)
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  expect_setequal(v$CategoryNames, c("surgery obstetric", "surgery brown", "OTHER"))
  expect_equal(v$DATA$`surgery obstetric`, c(10, 12))
})

test_that("a level missing in one arm is a flagged cell, not a crash", {
  d <- longFrame[-4, ]                      # Sex / Male has one arm's line only
  v <- vd(d)
  # the wide row for arm 2 has MALE = NA: the existing NA-cell refusal applies
  expect_true(any(is.na(v$DATA$MALE[v$DATA$ROW == "Sex"])) || isTRUE(v$FAIL))
  expect_no_error(runP(v))
})

test_that("CATEGORY is accepted as the column's alias, and a file with no levels is untouched", {
  d <- longFrame; names(d)[names(d) == "LEVEL"] <- "Category"
  v <- vd(d)
  expect_false(isTRUE(v$FAIL)); expect_true("MALE" %in% v$CategoryNames)
  w <- wideFrame; w$LEVEL <- ""
  vw <- vd(w)
  expect_false(isTRUE(vw$FAIL)); expect_false("LEVEL" %in% names(vw$DATA))
})

test_that("the API's normaliser converts the long layout, so the categorical work gate sees its columns", {
  n <- IntegrityAnalysis:::.apiNormalizeNames(longFrame)
  expect_true(all(c("MALE", "FEMALE", "UROLOGIC") %in% names(n)))
  expect_false("LEVEL" %in% names(n))
  expect_true(length(IntegrityAnalysis:::.apiCategoryGuess(n)) >= 5)
})
