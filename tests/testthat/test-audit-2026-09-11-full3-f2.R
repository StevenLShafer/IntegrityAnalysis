# Adjudication of the independent statistical audit of 2026-09-11 (the
# audit Steve commissioned against 32de737), finding F2 (P2, Medium): the
# Barnett dispersion instrument crashed on a valid table of many identical
# arm means. barnettTStats() reduces such a table to all-zero t-statistics;
# .bdLogLik() then formed x = exp(eps/2) * t, and at the large eps the slab
# grid search reaches (the mode sits near n*slabVar/2, about 1400 for 280
# comparisons) exp(eps/2) overflowed to Inf, so Inf * 0 = NaN for a zero
# statistic, and the NaN propagated into the grid's max and stopping test:
# "missing value where TRUE/FALSE needed". The likelihood is now evaluated
# in log space, exact at a zero statistic.
#
# The exact reference the audit gives: with J zero t-statistics and slab
# prior variance 10, the conditional slab posterior of epsilon is
# N(5J, 10). For J = 280 the mean is 1400.
#
# PROVENANCE: written by Claude Code (model Claude Opus 4.8, Anthropic),
# 2026-09-11, with the fix in R/dispersionTest.R (.bdLogLik in log space).
# The fixture is the audit's own (10 variables, eight arms, N = 20,
# MEAN = 50, SD = 10 throughout - 280 zero t-statistics), through the
# exported barnettTStats() -> barnettDispersion() path the report names,
# and checked to FAIL on 32de737/a94674d with the reported error.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that(".bdLogLik agrees with the plain t-density on ordinary inputs (no regression)", {
  old <- function(eps, t, df) {
    arg <- outer(exp(eps / 2), t)
    d <- stats::dt(arg, df = rep(df, each = length(eps)), log = TRUE); dim(d) <- dim(arg)
    rowSums(d) + length(t) * eps / 2
  }
  eps <- seq(-4, 4, by = 0.25); t <- c(-2.1, 0.7, 1.3, 0.4, -0.9); df <- c(18, 18, 30, 12, 40)
  expect_lt(max(abs(.bdLogLik(eps, t, df) - old(eps, t, df))), 1e-10)
})

test_that(".bdLogLik is finite when a zero statistic meets a huge eps (the Inf*0 that was NaN)", {
  v <- .bdLogLik(c(0, 700, 1400, 2000), t = c(0, 0, 1.5), df = c(19, 19, 19))
  expect_true(all(is.finite(v)))                           # NaN on 32de737 at eps = 1400
})

test_that("the Barnett instrument returns a result on a table of many identical arm means (audit 2026-09-11 F2)", {
  D <- do.call(rbind, lapply(sprintf("V%02d", 1:10), function(vn)
    data.frame(TRIAL = "T", ROW = vn, N = 20, MEAN = 50, SD = 10, stringsAsFactors = FALSE)[rep(1, 8), ]))
  v <- shiny::isolate(validateData(D))
  ts <- barnettTStats(v$DATA)
  expect_identical(nrow(ts), 280L)                         # 10 variables x choose(8,2) = 280 comparisons
  expect_true(all(abs(ts$t) < 1e-9))                       # all-zero t-statistics
  r <- barnettDispersion(ts)                               # threw "missing value where TRUE/FALSE needed" on 32de737
  expect_true(is.finite(r$epsilon))
  # the exact conditional slab posterior mean is 5J = 1400
  expect_equal(r$epsilon, 1400, tolerance = 0.5)
  expect_gt(r$pDispersed, 0.99)                            # the slab dominates (log Bayes factor ~ 98,000)
})
