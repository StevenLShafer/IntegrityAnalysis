# Regression tests for security screen 2026-09-07-1459 (the #211 range):
# F1 the zero snap at extreme shapes, fixed by translating the means before
# the statistic; F2 the direct-draw chunk bounded by the arm count.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
quiet <- function(expr) { utils::capture.output(r <- suppressMessages(expr)); r }
runP <- function(d, m = 1000, seed = 5) {
  dqrng::dqset.seed(seed); set.seed(seed)
  quiet(suppressWarnings(shiny::isolate(P_Calc("T", d, NULL, m))))
}
rowP <- function(x) suppressWarnings(as.numeric(sub("^<", "", x$P[1])))

test_that("F1: a thousand arms printing the same two-decimal mean near 1e9 sit at the attainable floor with p = 0.5, not at the stage floor", {
  # the screen's failing shape: every replicate ties (SD tiny against the
  # grid), and the replicates' N-weighted centre carried floating-point
  # dust the observed row did not; translating by the first arm's mean
  # makes identical means exactly zero in both arithmetics
  d <- data.frame(TRIAL = "T", ROW = "X", N = 5000, MEAN = 1e9 + 0.25, SD = 0.05,
                  ROUND_MEAN = 2, ROUND_OBSERVATION = 2, stringsAsFactors = FALSE)[rep(1, 1000), ]
  x <- runP(d, m = 1000)
  expect_equal(rowP(x), 0.5)
  expect_match(x$NOTE[1], "attainable floor")
})

test_that("F1: translation changes no ordinary answer - the screen 1441 cases and a three-arm row", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(50, 52), MEAN = c(1e11, 1e11 + 5), SD = c(10, 10),
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  x <- runP(d); expect_false(grepl("floor", x$NOTE[1]))
  d$MEAN <- c(1e11, 1e11); y <- runP(d); expect_match(y$NOTE[1], "attainable floor")
  d3 <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 40, 50), MEAN = c(60.1, 60.3, 60.2), SD = c(10, 11, 9),
                   ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  p <- rowP(runP(d3)); expect_true(is.finite(p) && p > 0 && p < 1)
})

test_that("F2: the direct-draw chunk is bounded by the arm count, so peak memory does not scale with arms x replicates", {
  # 400 direct-draw arms (N 100, SD 100 against an integer grid) at 100,000
  # replicates: unbounded, the ch x arms matrices were 4e7 doubles each
  # (1.3 GB with the copies); bounded at 1e7 doubles each, the peak with the
  # translation, deviation and square copies alive stays under 0.5 GB
  d <- data.frame(TRIAL = "T", ROW = "X", N = 100, MEAN = 50, SD = 100,
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)[rep(1, 400), ]
  invisible(gc(reset = TRUE))
  x <- runP(d, m = 100000)
  g <- gc()
  peakGB <- sum(g[, 6]) / 1024
  expect_lt(peakGB, 0.5)
  expect_identical(x$M[1], "1e+05")            # it did escalate to the top stage
})
