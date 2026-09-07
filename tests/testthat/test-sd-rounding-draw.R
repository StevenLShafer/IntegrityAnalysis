# The SD rounding draw (2026-09-06, statistical audit finding F1; Steve:
# "do the SD rounding draw first"): each replicate draws every arm's
# sample SD uniformly within its PRINTED interval before the pooled
# chi-square draw, because a printed "1" means anything from 0.5 to 1.5
# and the row p at a tie varied by a factor of 2.5 across that interval
# when the printed value was taken as exact.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-06.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
vd <- function(d) shiny::isolate(validateData(d))
runP <- function(d, m = 100000, seed = 11) {
  dqrng::dqset.seed(seed); set.seed(seed)
  suppressWarnings(shiny::isolate(P_Calc("T", d, NULL, m)))
}
rowP <- function(x) suppressWarnings(as.numeric(sub("^<", "", x$P[1])))

test_that("validateData infers a blank ROUND_DISPERSION from the SD's printed decimals, per variable, and keeps a supplied one", {
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Wt", "Wt", "Sex", "Sex"),
                  N = c(50, 52, 50, 52, NA, NA), MEAN = c(60.1, 60.3, 72.4, 72.9, NA, NA),
                  SD = c(10.2, 10, 12.13, 11.7, NA, NA),
                  Male = c(NA, NA, NA, NA, 25, 26), Female = c(NA, NA, NA, NA, 25, 26),
                  stringsAsFactors = FALSE)
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  D <- v$DATA
  # 10.2 beside 10 is a one-decimal variable on both lines (the trailing
  # zero of "10.0" is lost when text becomes a number)
  expect_identical(D$ROUND_DISPERSION[D$ROW == "Age"], c(1, 1))
  expect_identical(D$ROUND_DISPERSION[D$ROW == "Wt"], c(2, 2))
  expect_true(all(is.na(D$ROUND_DISPERSION[D$ROW == "Sex"])))   # no SD, nothing to infer
  # a supplied value is never overwritten; blanks elsewhere are still inferred
  d$ROUND_DISPERSION <- c(0, 0, NA, NA, NA, NA)
  D2 <- vd(d)$DATA
  expect_identical(D2$ROUND_DISPERSION[D2$ROW == "Age"], c(0, 0))
  expect_identical(D2$ROUND_DISPERSION[D2$ROW == "Wt"], c(2, 2))
})

test_that("the interval a printed SD stands for: half a unit either side, never below zero, zero stays zero, blanks inferred", {
  iv <- .iaSdInterval(c(1, 3, 0.2, 0, 12.5), c(0, 0, 0, 0, 1))
  expect_equal(iv$lo, c(0.5, 2.5, 0,   0, 12.45))
  expect_equal(iv$hi, c(1.5, 3.5, 0.7, 0, 12.55))
  # no column, or a blank in it: inferred as the validator infers - the
  # variable's maximum printed decimals across its arms (2 here), so "10"
  # beside "0.05" is a two-decimal variable (GPT-6 audit F5, 2026-09-07)
  iv <- .iaSdInterval(c(1.2, 0.05, 10))
  expect_equal(iv$lo, c(1.195, 0.045, 9.995))
  expect_equal(iv$hi, c(1.205, 0.055, 10.005))
  expect_equal(.iaSdInterval(c(1, 2), c(NA, 0)), .iaSdInterval(c(1, 2)))
})

test_that("a coarsely printed SD changes the null the row is judged against; a finely printed one barely does", {
  # two arms of 30, means tied at one decimal, the SD printed as "1"
  # ([0.5, 1.5)) against the same value printed "1.000". The trial stops
  # at 10,000 replicates (p > 0.01), where the Monte Carlo standard error
  # is 0.0027 and the integrated effect is about +0.007 (E[1/sigma] over
  # the interval is 1.099 x its point value), so the DIRECTION is not
  # pinned here - a seed can invert a 2.5-standard-error difference -
  # only that both p's sit where the audit measured them (0.074 exact,
  # 0.08 integrated, +/- 3 standard errors).
  base <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(2.3, 2.3), SD = c(1, 1),
                     ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  coarse <- base; coarse$ROUND_DISPERSION <- 0
  exact  <- base; exact$ROUND_DISPERSION  <- 3
  pCoarse <- rowP(runP(coarse)); pExact <- rowP(runP(exact))
  expect_false(isTRUE(all.equal(pCoarse, pExact)))   # a different null, not the same draw
  expect_lt(abs(pExact - 0.074), 0.009)
  expect_lt(abs(pCoarse - 0.081), 0.009)
})

test_that("a direct caller without ROUND_DISPERSION gets the inference the validator would make", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(2.3, 2.3), SD = c(1.2, 0.9),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  withCol <- d; withCol$ROUND_DISPERSION <- 1
  expect_identical(runP(d, m = 10000)$P, runP(withCol, m = 10000)$P)
})

test_that("a printed SD of exactly zero is not an interval: identical arms with SD 0 still sit at p = 0.5", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(6, 6), MEAN = c(39, 39), SD = c(0, 0),
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 0,
                  stringsAsFactors = FALSE)
  x <- runP(d, m = 10000)
  expect_equal(rowP(x), 0.5)
  expect_identical(x$NOTE[1], "attainable floor")
})

test_that("the interval never goes below zero: a small SD printed coarsely still simulates", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(20, 20), MEAN = c(0.3, 0.4), SD = c(0.2, 0.3),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 0,
                  stringsAsFactors = FALSE)
  x <- runP(d, m = 1000)
  p <- rowP(x)
  expect_true(is.finite(p) && p > 0 && p <= 1)
})
