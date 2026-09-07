# Known-answer Monte Carlo cases under fixed seeds (ISSUES.md issue 4,
# second priority): a refactor must not silently change results.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-19.
# The pinned values were computed on R 4.5.3 / dqrng 0.4.1 with the
# engine as of the PR 21-25 merges. Under fixed seeds the engine is
# fully deterministic (sequential %do% row loop, chunking depends only
# on N), so equality is exact. If an INTENDED statistical change moves
# these numbers, re-pin them in the same commit and say why; if an
# upgrade of R or dqrng moves them, re-pin and note the version. A
# surprise failure here means the engine changed when it was not meant
# to.
#
# RE-PINNED 2026-09-04 with the exact combination (PR "the exact
# combination"): the staging is now per trial and each stage draws
# afresh rather than cumulatively, so the RNG stream a row sees at its
# final stage differs from before. "Three identical arms" moved from
# p = 3e-04 (bound <=0.0013) to 1e-04 (bound <=0.00072): the same row,
# the same 10,000 replicates, a different draw. The worked example
# (stage 1 only, identical draws) is unchanged at 0.0495.
#
# Re-pinned again 2026-09-05 (the 0.1 escalation, Steve's ask after an
# outside review): a trial or row with mid-p below 0.1 now advances to
# 10,000 replicates, so every borderline pin below is a 10,000-replicate
# value on a fresh stage-2 draw. Worked example 0.0495 -> 0.04805 (M
# 10,000); identical categorical arms 0.089 -> 0.08245; median/IQR pair
# 0.0555 -> 0.0464. Same rows, same seed, more replicates.
#
# Re-pinned 2026-09-05 (the pooled SD: (N_i - 1)-weighted variance, c4
# with N - k degrees of freedom at every N, Steve's decision after the
# outside review's finding 8): the worked example 0.04805 -> 0.04750 -
# its SD is now corrected with 10 degrees of freedom, not 11, and every
# row above N = 30 now receives the (sub-1%) correction it used to skip.
# The categorical and median pins do not touch the pooled SD.
#
# Re-pinned 2026-09-06 (the sigma draw: each replicate draws its own SD
# from the scaled inverse chi-square with N - k degrees of freedom, so
# the simulated statistic is F-like rather than chi-square-like): the
# worked example 0.04750 -> 0.04415 (two arms of six: ten degrees of
# freedom, the uncertainty in the SD is real); three identical arms
# 1e-04 -> 0.00025 (interval 0 to 0.0012) - a replicate that draws a
# smaller sigma makes identical rounded means likelier under the null.
#
# Re-pinned 2026-09-06 (the SD rounding draw, audit finding F1: each
# replicate draws every arm's sample SD uniformly within its PRINTED
# interval before the pooled chi-square draw, so a printed "30" is
# [29.5, 30.5) and a printed "9.2" is [9.15, 9.25)): the worked example
# 0.04415 -> 0.0462 and three identical arms 0.00025 -> 0.00015 (interval
# 0 to 0.00088). Both intervals are narrow (1.7% and 0.5% of the SD), so
# these moves are mostly the RNG stream - one extra uniform per arm per
# replicate - not the SD's rounding; the rows the draw was built for are
# those whose SD is printed to one significant figure (a printed "1" is
# [0.5, 1.5)). The categorical and median pins do not touch the SD.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

runP <- function(d, cats = NULL, m = 10000) {
  dqrng::dqset.seed(42); set.seed(42)
  suppressWarnings(shiny::isolate(P_Calc("T", d, cats, m)))
}
summaryP <- function(x)
  suppressWarnings(as.numeric(x$P[x$ROW == "Summary" & !is.na(x$ROW)]))[1]

test_that("the documentation's worked example: 77 vs 78, SD 30, n = 6", {
  x <- runP(data.frame(
    TRIAL = "T", ROW = "Weight", N = 6, MEAN = c(77, 78), SD = c(30, 30),
    ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE))
  expect_equal(summaryP(x), 0.0462)          # the guide's "about 4%"
  expect_identical(x$M[1], "10000")         # borderline (p < 0.1) - escalates to stage 2
})

test_that("three identical arms escalate and alarm", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = 40, MEAN = 54.1, SD = 9.2,
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1,
                  stringsAsFactors = FALSE)[rep(1, 3), ]
  x <- runP(d)
  expect_equal(summaryP(x), 0.00015)
  expect_identical(x$M[1], "10000")         # escalated past stage 1
  expect_identical(x$CI95[1], "0 to 0.00088")  # the row's Monte Carlo interval
  expect_identical(x$NOTE[1], "attainable floor")  # identical arms: nothing agrees better
})

test_that("identical categorical arms give the pinned lower-tail mid-p", {
  x <- runP(data.frame(
    TRIAL = "T", ROW = "Sex", N = NA_real_, MEAN = NA_real_,
    SD = NA_real_, ROUND_MEAN = NA_real_, ROUND_OBSERVATION = NA_real_,
    MALE = c(25, 25), FEMALE = c(25, 25), stringsAsFactors = FALSE),
    cats = c("MALE", "FEMALE"))
  expect_equal(summaryP(x), 0.08245)
})

test_that("a median/IQR pair gives the pinned metalog p", {
  x <- runP(data.frame(
    TRIAL = "T", ROW = "Dur", N = c(20, 20), MEAN = c(127, 128),
    SD = NA_real_, Q1 = c(98, 99), Q3 = c(160, 161),
    ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE))
  # re-pinned 2026-09-07 (the median branch's scale draw: each replicate
  # resamples the arms from the fitted metalog, pools their printed
  # quartiles and takes the RECIPROCAL of the resampled scale's ratio
  # to the fit - the metalog analogue of the sigma draw - so the pooled
  # quartiles are no longer taken as exact): 0.0464 -> 0.04545
  expect_equal(summaryP(x), 0.04545)
})

test_that("categorical direction: homogeneous alarms, heterogeneous does not", {
  # ported from the issue-6 direction check (scratch catdir_test.R):
  # under the old chisq.test upper-tail convention these were REVERSED
  p_of <- function(male) {
    d <- data.frame(TRIAL = "T", ROW = "Sex", N = NA_real_,
                    MEAN = NA_real_, SD = NA_real_, ROUND_MEAN = NA_real_,
                    ROUND_OBSERVATION = NA_real_,
                    MALE = male, FEMALE = 50 - male,
                    stringsAsFactors = FALSE)
    summaryP(runP(d, cats = c("MALE", "FEMALE"), m = 15000))
  }
  expect_lt(p_of(c(25, 25)), 0.35)   # identical arms - suspicious
  expect_gt(p_of(c(40, 10)), 0.9)    # strongly imbalanced - not the signal
})
