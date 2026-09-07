# Regression tests for security screen 2026-09-07-1441 (informational
# notes I1 and I2 on the tie criterion of #207).
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

test_that("I1: at means near 1e11 with integer printing the zero snap does not swallow a genuine difference", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(50, 52), MEAN = c(1e11, 1e11 + 5), SD = c(10, 10),
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  x <- runP(d)
  expect_false(grepl("floor", x$NOTE[1]))                      # 12.5 is not zero
  p5 <- suppressWarnings(as.numeric(sub("^<", "", x$P[1])))
  d$MEAN <- c(1e11, 1e11); y <- runP(d)
  p0 <- suppressWarnings(as.numeric(sub("^<", "", y$P[1])))
  expect_match(y$NOTE[1], "attainable floor")                 # identical means still are
  expect_gt(p5, p0)                                           # and the p responds to the difference
})

test_that("I2: the tie helpers keep a non-finite statistic apart and tolerate NA", {
  r <- .iaTieRank(c(1, 2, 2 + 1e-12, Inf))
  expect_equal(r, c(1, 2.5, 2.5, 4))
  expect_equal(unname(.iaTieCounts(c(1, Inf, NA, 2), 2)), c(1, 1))
  expect_false(anyNA(.iaTieRank(c(3, NA, 1))[c(1, 3)]))
})
