# Ties decided by a bounded numerical criterion (2026-09-07; finding F1 of
# the GPT-6 audit in docs/audits/). Mathematically equal statistics that
# differ in their last binary digit are one tie group; identical printed
# means with unequal arm sizes are at the attainable floor even though the
# N-weighted centre leaves floating-point dust in the observed statistic.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
runP <- function(d, cats = NULL, m = 1000, seed = 42) {
  dqrng::dqset.seed(seed); set.seed(seed)
  suppressWarnings(shiny::isolate(P_Calc("T", d, cats, m)))
}
rowP <- function(x, i = 1) suppressWarnings(as.numeric(sub("^<", "", x$P[i])))

test_that("the three minimum tables of margins (2, 2, 6) x (3, 7) are one tie group", {
  tab <- rbind(c(1, 1), c(1, 1), c(1, 5)); E <- outer(rowSums(tab), colSums(tab)) / sum(tab)
  st <- function(t) sum((t - E)^2 / E)
  s <- c(st(rbind(c(1, 1), c(1, 1), c(1, 5))), st(rbind(c(1, 1), c(0, 2), c(2, 4))), st(rbind(c(0, 2), c(1, 1), c(2, 4))))
  expect_false(all(s == s[1]))                          # the floating-point split the audit found
  expect_length(unique(.iaTieRank(s)), 1)               # one rank
  expect_equal(unname(.iaTieCounts(s, s[1])), c(0, 3))  # all tied with the first
  # distinct values stay distinct
  expect_equal(unname(.iaTieCounts(c(1, 2, 3, 1 + 1e-6), 2)), c(2, 1))
  expect_equal(.iaTieRank(c(3, 1, 2)), c(3, 1, 2))
})

test_that("the audit's categorical row reads its exact mid-p (0.35), not a tenth of it", {
  d <- data.frame(TRIAL = "T", ROW = "Cat", N = NA_real_, MEAN = NA_real_, SD = NA_real_,
                  A = c(1, 1, 1), B = c(1, 1, 5), stringsAsFactors = FALSE)
  x <- runP(d, cats = c("A", "B"))
  p <- rowP(x)
  # exact enumeration: three minimum tables with total probability 0.70,
  # mid-p 0.35; at 1,000 replicates the Monte Carlo standard error is 0.015
  expect_gt(p, 0.30); expect_lt(p, 0.40)
})

test_that("five such rows combine to the exact trial mid-p (about 0.084), not 0.0002", {
  d <- do.call(rbind, lapply(1:5, function(k)
    data.frame(TRIAL = "T", ROW = paste0("Cat", k), N = NA_real_, MEAN = NA_real_, SD = NA_real_,
               A = c(1, 1, 1), B = c(1, 1, 5), stringsAsFactors = FALSE)))
  x <- runP(d, cats = c("A", "B"), m = 10000)
  p <- suppressWarnings(as.numeric(sub("^<", "", x$P[which(x$ROW == "Summary")])))
  # every row at its minimum tie group: 0.5 * 0.7^5 = 0.084; allow Monte Carlo noise
  expect_gt(p, 0.05); expect_lt(p, 0.13)
})

test_that("identical printed means with unequal arm sizes are at the attainable floor despite floating-point dust", {
  d <- data.frame(TRIAL = "T", ROW = "Age", N = c(50, 52), MEAN = c(60.1, 60.1), SD = c(10, 10),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  center <- sum(d$N * d$MEAN) / sum(d$N)
  expect_gt(sum((d$MEAN - center)^2), 0)                # the dust is real
  x <- runP(d)
  expect_match(x$NOTE[1], "attainable floor")
  # and means that genuinely differ by one printed unit never carry it
  d$MEAN <- c(60.1, 60.2)
  expect_false(grepl("floor", runP(d)$NOTE[1]))
})
