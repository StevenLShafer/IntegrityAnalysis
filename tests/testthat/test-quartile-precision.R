# Quartiles printed coarser than the median (2026-09-07; finding F4 of the
# GPT-6 audit in docs/audits/): the validator's order check allows for each
# printed value's own precision, a median line's ROUND_DISPERSION is the
# quartiles' precision (inferred from their decimals when blank), and the
# median branch prints its bootstrap quartiles to that precision.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
vd <- function(d) shiny::isolate(validateData(d))
med <- function(med, q1, q3, n = 30, rm = 2, ro = 2) data.frame(
  TRIAL = "T", ROW = "X", N = n, MEAN = med, SD = NA_real_, Q1 = q1, Q3 = q3,
  ROUND_MEAN = rm, ROUND_OBSERVATION = ro, stringsAsFactors = FALSE)

test_that("the audit's example - integer quartiles 5 and 6 beside the median 4.99 - is accepted, and the quartile precision is inferred as 0", {
  # observations 4.50 4.80 4.99 5.60 6.00: type-7 quartiles 4.80 and 5.60 print as 5 and 6
  d <- rbind(med(4.99, 5, 6, n = 5), med(5.01, 5, 6, n = 5))
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  expect_identical(v$DATA$ROUND_DISPERSION, c(0, 0))
  expect_identical(v$DATA$ROUND_MEAN, c(2, 2))
})

test_that("quartiles that cannot bracket the median at any reading of their precision are still refused", {
  d <- rbind(med(4.99, 6, 8, n = 5), med(5.01, 5, 6, n = 5))     # 6 - 0.5 > 4.99 + 0.005
  v <- vd(d)
  expect_true(isTRUE(v$FAIL))
  expect_true("incongruent" %in% v$issues$code[v$issues$col == "Q1"])
  # and at the median's own precision the old strict order still binds
  d <- rbind(med(12.0, 12.4, 17.0, rm = 1, ro = 1), med(11.5, 8.5, 16.0, rm = 1, ro = 1))
  expect_true(isTRUE(vd(d)$FAIL))
})

test_that("honest samples summarised with integer quartiles and two-decimal medians are no longer refused", {
  set.seed(4)
  refused <- 0L
  for (t in 1:40) {
    a <- round(rnorm(30, 5, 0.5), 2); b <- round(rnorm(30, 5, 0.5), 2)
    qa <- quantile(a, c(.25, .5, .75), type = 7); qb <- quantile(b, c(.25, .5, .75), type = 7)
    d <- rbind(med(round(qa[2], 2), round(qa[1]), round(qa[3])),
               med(round(qb[2], 2), round(qb[1]), round(qb[3])))
    if (isTRUE(vd(d)$FAIL)) refused <- refused + 1L
  }
  expect_equal(refused, 0L)     # 391 of 400 were refused before
})

test_that("a supplied ROUND_DISPERSION on a median line is kept and reaches the bootstrap's quartile printing", {
  d <- rbind(med(12.0, 8.0, 17.0, rm = 1, ro = 1), med(11.5, 8.5, 16.0, rm = 1, ro = 1))
  d$ROUND_DISPERSION <- 0
  v <- vd(d)
  expect_false(isTRUE(v$FAIL))
  expect_identical(v$DATA$ROUND_DISPERSION, c(0, 0))
  # the precision the bootstrap prints to changes the null the row is judged
  # against, so the two runs differ; both are finite p's
  run <- function(D) { dqrng::dqset.seed(9); set.seed(9)
    suppressWarnings(as.numeric(sub("^<", "", shiny::isolate(P_Calc("T", D, NULL, 1000))$P[1]))) }
  p0 <- run(v$DATA); v$DATA$ROUND_DISPERSION <- 3; p3 <- run(v$DATA)
  expect_true(is.finite(p0) && is.finite(p3))
  expect_false(isTRUE(all.equal(p0, p3)))
})
