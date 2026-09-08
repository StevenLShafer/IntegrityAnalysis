# The quartiles' printed intervals (Steve's decision, 2026-09-07, after the
# GPT-6 audit's finding F4). A printed quartile stands for an interval half
# a printed unit either side, exactly as a printed SD does; every replicate
# draws each arm's Q1 and Q3 inside those intervals, pools them by N, and
# fits THAT replicate's metalog. Quartiles that print the same value are
# therefore admissible - the old branch refused them, and refused 45% to
# 85% of honest tables from a population whose interquartile range is
# comparable to one printed unit (C:/dev/Corpus/synthetic/quartile-draw/).
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

medRow <- function(N, med, q1, q3, qDec = 0, medDec = 1)
  data.frame(TRIAL = "T", ROW = "X", N = N, MEAN = med, SD = NA_real_,
             Q1 = q1, Q3 = q3, ROUND_MEAN = medDec, ROUND_OBSERVATION = 1,
             ROUND_DISPERSION = qDec, stringsAsFactors = FALSE)

runRow <- function(D, m = 1000, seed = 4242) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}

test_that("arms whose quartiles print equal are analyzed, not refused", {
  # the audit's case: a variable near 5 with an interquartile range of
  # about 0.7, quartiles printed as integers - both print 5
  row <- runRow(medRow(c(30, 30), c(5.0, 5.1), c(5, 5), c(5, 5)))
  expect_false(grepl("Quartiles do not increase", row$P))
  expect_false(is.na(suppressWarnings(as.numeric(sub("^<", "", row$P)))))
  expect_match(row$NOTE, "printed quartiles do not separate in 2 arm(s)", fixed = TRUE)
})

test_that("quartiles printed in the wrong order are still refused", {
  row <- runRow(medRow(c(30, 30), c(5.0, 5.1), c(6, 6), c(5, 5)))
  expect_equal(row$P, "Quartiles do not increase (Q3 must exceed Q1)")
})

test_that("the note counts only the arms whose quartiles do not separate", {
  row <- runRow(medRow(c(30, 30, 30), c(5.0, 5.1, 5.2), c(5, 4, 4), c(5, 6, 6)))
  expect_match(row$NOTE, "do not separate in 1 arm(s)", fixed = TRUE)
  row2 <- runRow(medRow(c(30, 30), c(50.1, 49.6), c(43.2, 42.8), c(56.0, 57.1), qDec = 1))
  expect_equal(row2$NOTE, "")
})

test_that("a reversed pair in ONE arm is refused even when the pooled pair is in order", {
  # each drawn pair is ordered, so an arm printed Q3 < Q1 would otherwise
  # be silently repaired whenever the other arms kept the pooled pair in
  # order (CodeRabbit on PR #214)
  row <- runRow(medRow(c(30, 30), c(12.0, 12.4), c(10, 15), c(15, 11)))
  expect_equal(row$P, "Quartiles do not increase (Q3 must exceed Q1)")
})

test_that("a supplied quartile precision survives a blank in another arm", {
  # A blank cell is inferred on its own from the printed quartiles'
  # decimals - the rule .iaSdInterval() applies to a printed SD - and must
  # not overwrite what the caller supplied for the other arm (CodeRabbit on
  # PR #214; before this, one blank sent every arm to the median's
  # precision). These quartiles all carry one decimal, so inferring both
  # cells gives 1 for both.
  D <- medRow(c(30, 30), c(12.4, 12.9), c(10.2, 11.4), c(15.3, 15.1), qDec = 1)
  D$ROUND_DISPERSION <- c(1, NA)
  bothOne <- runRow(D)
  expect_false(is.na(suppressWarnings(as.numeric(sub("^<", "", bothOne$P)))))
  D2 <- D; D2$ROUND_DISPERSION <- c(NA, NA)
  expect_equal(runRow(D2)$P, bothOne$P)
  # ...and a supplied coarser precision for the FIRST arm is kept, so the
  # row is not the same as inferring both
  D3 <- D; D3$ROUND_DISPERSION <- c(0, NA)
  expect_false(identical(runRow(D3)$P, bothOne$P))
})

test_that("the same seed gives the same p", {
  D <- medRow(c(20, 25), c(12.4, 12.9), c(10, 11), c(15, 15))
  expect_equal(runRow(D)$P, runRow(D)$P)
})

test_that("identical printed medians still reach the attainable floor, and coarse printing raises it", {
  coarse <- runRow(medRow(c(30, 30), c(5.0, 5.0), c(5, 5), c(5, 5)))
  expect_match(coarse$NOTE, "attainable floor")
  fine <- runRow(medRow(c(30, 30), c(50.0, 50.0), c(43.0, 43.0), c(57.0, 57.0), qDec = 1))
  expect_match(fine$NOTE, "attainable floor")
  # the floor IS the share of honest replicates that agreed as exactly:
  # quartiles printed as integers across an interquartile range near one
  # printed unit let that happen often, a wide one-decimal variable
  # almost never - the floor is a property of the printing, not a bug
  expect_gt(as.numeric(sub("^<", "", coarse$P)), as.numeric(sub("^<", "", fine$P)))
  expect_lt(as.numeric(sub("^<", "", fine$P)), 0.05)
})

test_that("coarser printed quartiles are no less conservative than finer ones", {
  # the same underlying numbers, printed to no decimals and to two: the
  # coarse row's intervals are a hundred times wider, so its null carries
  # more scale uncertainty and its p cannot be the smaller one by much.
  # Averaged over seeds so the comparison is not one draw's luck.
  pOf <- function(qDec, seed) {
    D <- medRow(c(40, 40), c(12.4, 13.1),
                c(10.00, 10.60), c(15.00, 15.40), qDec = qDec, medDec = 1)
    as.numeric(sub("^<", "", runRow(D, m = 1000, seed = seed)$P))
  }
  seeds <- c(11, 22, 33, 44, 55)
  coarse <- vapply(seeds, function(s) pOf(0, s), numeric(1))
  fine   <- vapply(seeds, function(s) pOf(2, s), numeric(1))
  expect_gt(mean(coarse), mean(fine) - 0.05)
})
