# The four defects confirmed from the outside review of 2026-09-05
# (rounding inference, counts-only wide table, one-variable Summary),
# each pinned so it cannot come back.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-05.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
vd <- function(d) shiny::isolate(validateData(d))

test_that("an inferred observation precision follows the inferred mean precision, per variable", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = 30, MEAN = c(1.20, 1.25), SD = 0.1,
                  stringsAsFactors = FALSE)
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  expect_identical(v$DATA$ROUND_MEAN, c(2, 2))          # one variable, one printed precision
  expect_identical(v$DATA$ROUND_OBSERVATION, c(2, 2))   # used to be 0, 0
  # a supplied observation precision is kept; a blank cell in that column is inferred
  d2 <- data.frame(TRIAL = "T", ROW = "X", N = 30, MEAN = c(1.20, 1.25), SD = 0.1,
                   ROUND_OBSERVATION = c(1, NA), stringsAsFactors = FALSE)
  v2 <- vd(d2)
  expect_identical(v2$DATA$ROUND_OBSERVATION, c(1, 2))
  # integers stay integers
  v3 <- vd(data.frame(TRIAL = "T", ROW = "Age", N = 30, MEAN = c(61, 60), SD = 10, stringsAsFactors = FALSE))
  expect_identical(v3$DATA$ROUND_MEAN, c(0, 0)); expect_identical(v3$DATA$ROUND_OBSERVATION, c(0, 0))
})

test_that("a wide table that is nothing but counts is a valid categorical table", {
  d <- data.frame(TRIAL = "T", ROW = "Sex", N = NA_real_, MEAN = NA_real_, SD = NA_real_,
                  MALE = c(25, 25), FEMALE = c(25, 25), stringsAsFactors = FALSE)
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  expect_identical(v$CategoryNames, c("MALE", "FEMALE"))
  dqrng::dqset.seed(42); set.seed(42)
  x <- suppressWarnings(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 10000)))
  expect_gt(as.numeric(x$P[which(x$ROW == "Summary")]), 0.05)   # identical arms: a lower-tail p near 0.08
  # ...and a continuous line beside it still requires the blank
  e <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Sex", "Sex"), N = c(50, 50, NA, NA),
                  MEAN = c(61, 60, NA, NA), SD = c(10, 11, NA, NA),
                  MALE = c(NA, NA, 25, 25), FEMALE = c(NA, NA, 25, 25), stringsAsFactors = FALSE)
  expect_identical(vd(e)$CategoryNames, c("MALE", "FEMALE"))
})

test_that("a one-variable trial's Summary carries the row's display and interval", {
  dqrng::dqset.seed(1); set.seed(1)
  d <- data.frame(TRIAL = "T", ROW = "Age", N = 200, MEAN = 61, SD = 10,
                  ROUND_MEAN = 3, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)[rep(1, 3), ]
  x <- suppressWarnings(shiny::isolate(P_Calc("T", d, NULL, 100000)))
  row <- which(x$ROW == "Age"); sm <- which(x$ROW == "Summary")
  expect_identical(x$P[row], "<0.0001")
  expect_identical(x$P[sm], x$P[row])          # used to print 9.99990000099999e-06
  expect_identical(x$CI95[sm], x$CI95[row])    # used to be blank
  # an unremarkable single row likewise
  d2 <- data.frame(TRIAL = "T", ROW = "Age", N = 30, MEAN = c(61, 58), SD = 10,
                   ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  y <- suppressWarnings(shiny::isolate(P_Calc("T", d2, NULL, 100000)))
  expect_identical(y$P[y$ROW == "Summary"], y$P[y$ROW == "Age"])
})
