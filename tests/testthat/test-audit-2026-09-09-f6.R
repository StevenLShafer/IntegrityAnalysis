# Independent audit 2026-09-09, finding F6: the zero floor dropped genuine
# ties at fine printed precision, so the same equality event gave a
# different p depending on a number that describes how the table was
# PRINTED rather than what was measured.
#
# The cause is a mismatch the code's own comment already assumed away. The
# OBSERVED row is translated by its own first arm (dd <- ROWS$MEAN -
# ROWS$MEAN[1]), so arms that print alike give a structurally exact zero.
# Each REPLICATE was translated by that same single OBSERVED constant, so a
# replicate whose arms all drew the same value did not cancel: the
# N-weighted centre of equal values is not bitwise equal to them, and the
# residual dust had to be caught by a tolerance instead. Screen 1459's
# comment says the translation exists so that identical means are exactly
# zero "in the observed row and in every replicate"; one constant only ever
# delivered the first half.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-09,
# with the change in R/P_Calc.R. Every assertion was checked to FAIL on
# ca8433c, the code the audit read.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runP <- function(d, m = 100000, seed = 42) {
  set.seed(seed); dqrng::dqset.seed(seed)
  v <- shiny::isolate(validateData(d))
  r <- suppressWarnings(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, m)))
  as.character(r[which(r$ROW == "X")[1], ]$P)
}

# ------------------------------------------------------- the arithmetic ----

test_that("equal arms in a replicate give a structurally exact zero", {
  # This is the property, independent of any p. Whatever the magnitude and
  # whatever the printed grid, a replicate whose arms all drew the SAME
  # value must produce exactly 0 - not something a tolerance has to
  # forgive. Values that are not dyadic rationals are the ones that matter:
  # a tenth is not exactly representable, a half is, which is why an
  # integer-observation median row could never show the defect.
  N <- c(30, 30, 40)
  for (v in c(2.3, 0.1, 1/3, 1e9 + 0.7, 1e-7)) {
    M <- matrix(v, nrow = 5, ncol = 3)          # every arm drew the same value
    centred <- M - M[, 1]
    MS <- drop(centred %*% N) / sum(N)
    stat <- rowSums((centred - MS)^2)
    expect_true(all(stat == 0), info = paste("value", v))
  }
  # and the observed row's own convention agrees with it
  for (v in c(2.3, 0.1, 1/3)) {
    dd <- rep(v, 3) - v
    expect_identical(sum((dd - sum(N * dd) / sum(N))^2), 0)
  }
})

# ------------------------------------------------ the audit's own row ----

test_that("the printed precision does not move the continuous answer", {
  # The audit's construction: two arms of 30, MEAN 2.3, SD 3.007, integer
  # observations. Both precisions distinguish adjacent possible sample
  # means, whose spacing is 1/30, so the equality event is the SAME and the
  # p must be too. On ca8433c this read 0.00816 at six decimals and 0.0066
  # at fourteen; an independent million-draw reference comparing integer
  # sample SUMS - never a floating statistic - puts the mid-p at 0.008474,
  # and a 400,000-draw repetition here at 0.008529.
  cont <- function(dec) data.frame(
    TRIAL = "T", ROW = "X", N = rep(30, 2), MEAN = 2.3, SD = 3.007,
    ROUND_MEAN = dec, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 3,
    stringsAsFactors = FALSE)
  six <- runP(cont(6))
  expect_equal(as.numeric(six), 0.00816, tolerance = 1e-6)
  for (dec in c(6, 8, 10, 12, 14))
    expect_identical(runP(cont(dec)), six, info = paste("ROUND_MEAN", dec))
})

test_that("the same holds on the median branch, which the audit did not test", {
  # N is ODD, so the median IS one of the observations and therefore
  # already sits on the printed observation grid: rounding it to one or to
  # fourteen decimals changes nothing, and the equality event is identical
  # across every precision below. The grid is TENTHS, because a tenth is
  # not a dyadic rational - with integer observations the medians are
  # multiples of a half, which are exact in binary, and no dust can arise.
  #
  # On ca8433c this read 0.01995 at one and six decimals and drifted to
  # 0.01755 from eleven on - which is exactly where 1e-12 * step^2 falls
  # below the dust.
  med <- function(dec) data.frame(
    TRIAL = "T", ROW = "X", N = rep(31, 2), MEAN = 2.5, SD = NA_real_,
    Q1 = 0.4, Q3 = 4.6,
    ROUND_MEAN = dec, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 1,
    stringsAsFactors = FALSE)
  one <- runP(med(1))
  expect_equal(as.numeric(one), 0.01995, tolerance = 1e-6)
  for (dec in c(6, 11, 12, 13, 14))
    expect_identical(runP(med(dec)), one, info = paste("ROUND_MEAN", dec))
})

test_that("an EVEN median row is still allowed to move with the precision", {
  # The mirror of the test above, and the reason it specifies an odd N. At
  # an even N the median is the mean of two order statistics, so on a
  # tenths grid it is a multiple of 0.05 and rounding it to one decimal
  # genuinely COARSENS it. The equality event is then not the same event,
  # and the p is expected to differ. Pinned so that a later change cannot
  # quietly flatten a difference that ought to be there.
  med <- function(dec) data.frame(
    TRIAL = "T", ROW = "X", N = rep(30, 2), MEAN = 2.5, SD = NA_real_,
    Q1 = 0.4, Q3 = 4.6,
    ROUND_MEAN = dec, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 1,
    stringsAsFactors = FALSE)
  expect_false(identical(runP(med(1)), runP(med(14))))
})

# ---------------------------------------------------- nothing else moves ----

test_that("ordinary printed precision is untouched", {
  # The loss needs 1e-12 * step^2 to fall below the floating dust, which
  # takes about eleven decimals. Everything a real paper prints is far
  # above that, and these values are bitwise what ca8433c returned.
  ord <- function(dec) data.frame(
    TRIAL = "T", ROW = "X", N = c(40, 40, 40), MEAN = c(50.2, 50.0, 49.8),
    SD = c(10, 10, 10), ROUND_MEAN = dec, ROUND_OBSERVATION = 0,
    ROUND_DISPERSION = 1, stringsAsFactors = FALSE)
  expect_identical(runP(ord(0)), "0.015")
  expect_identical(runP(ord(1)), "0.0162")
  expect_identical(runP(ord(2)), "0.01795")
  expect_identical(runP(ord(3)), "0.01795")
  tied <- function(dec) data.frame(
    TRIAL = "T", ROW = "X", N = c(40, 40, 40), MEAN = c(50, 50, 50),
    SD = c(10, 10, 10), ROUND_MEAN = dec, ROUND_OBSERVATION = 0,
    ROUND_DISPERSION = 1, stringsAsFactors = FALSE)
  expect_identical(runP(tied(1)), "0.000205")
  expect_identical(runP(tied(3)), "<0.0001")
})

test_that("the earlier audits' units and origin invariance still holds", {
  # screens 1441/1459 and the 2026-09-08 audit: the answer may not depend
  # on the units the trial is reported in, nor on where the origin sits.
  base <- function() data.frame(
    TRIAL = "T", ROW = "X", N = c(10, 10), MEAN = c(0, .1), SD = 1,
    ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 1,
    stringsAsFactors = FALSE)
  d <- base(); original <- as.numeric(runP(d))
  s <- base(); s$MEAN <- s$MEAN * 1e-13; s$SD <- s$SD * 1e-13
  s[c("ROUND_MEAN", "ROUND_OBSERVATION", "ROUND_DISPERSION")] <- 14
  scaled <- as.numeric(runP(s))
  t <- base(); t$MEAN <- t$MEAN + 1000
  translated <- as.numeric(runP(t))
  expect_equal(scaled, original, tolerance = 0.05)
  expect_equal(translated, original, tolerance = 0.05)
})
