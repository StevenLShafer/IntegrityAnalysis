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
  # 1,000 direct-draw arms (N 100, SD 100 against an integer grid) at
  # 100,000 replicates - the screen's own headline shape. Unbounded, the
  # chunk is the whole stage and each ch x arms matrix is 1e8 doubles
  # (0.8 GB); the simulated means and their translated copy are alive
  # together, so the peak cannot fall below 1.6 GB by construction.
  # Bounded at 1e7 doubles per matrix, the peak does not grow with the arms.
  #
  # THE BOUND IS 1 GB, NOT 0.5 (2026-09-24). The first version asserted
  # 400 arms under 0.5 GB and measured 0.40 GB on the desktop; the GitHub
  # Actions runner reported 0.5074 GB on 2026-09-24 (run 36057041666, on a
  # docs-only PR, green on rerun): gc()'s "max used" counts garbage not yet
  # collected, and the runner's collection timing and baseline heap differ
  # from the desktop's. At 400 arms the unbounded peak is only 0.78 GB, so
  # no bound both tolerates that variance and fails on the regression; at
  # 1,000 arms one does. Measured 2026-09-24 on the desktop (R 4.5.3,
  # Windows), with the 1e7 / COLS term in P_Calc.R present and removed:
  #   arms   bounded   unbounded
  #    400   0.40 GB    0.78 GB
  #  1,000   0.42 GB    1.69 GB
  #  2,000   0.46 GB    3.18 GB
  # So 1 GB sits 0.58 GB above the honest peak (six times the runner's
  # excess) and 0.69 GB below the measured failure, whose structural 1.6 GB
  # floor keeps it above the bound whatever the runner's gc does.
  d <- data.frame(TRIAL = "T", ROW = "X", N = 100, MEAN = 50, SD = 100,
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)[rep(1, 1000), ]
  invisible(gc(reset = TRUE))
  x <- runP(d, m = 100000)
  g <- gc()
  peakGB <- sum(g[, 6]) / 1024
  expect_lt(peakGB, 1)
  expect_identical(x$M[1], "1e+05")            # it did escalate to the top stage
})
