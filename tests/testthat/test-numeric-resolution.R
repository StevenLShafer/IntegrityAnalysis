# The numerical-resolution refusal (GPT-6 audit finding F7, 2026-09-07).
# The validator caps a value's magnitude and its printed decimals
# separately, and neither cap asks whether the two are compatible: a
# double carries about 15.7 significant digits, so twenty decimals at a
# magnitude of 1e11 asks for a resolution the arithmetic does not have,
# and the simulation would round on the floating-point grid instead of
# the printed one without saying so. Such a row is refused by name.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runRow <- function(D, m = 1000, seed = 7) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}
meanRow <- function(mean, sd, dec, N = c(100, 101))
  data.frame(TRIAL = "T", ROW = "X", N = N, MEAN = mean, SD = sd,
             ROUND_MEAN = dec, ROUND_OBSERVATION = dec, ROUND_DISPERSION = 6,
             stringsAsFactors = FALSE)

test_that("the helper marks exactly the rows whose printed grid is unrepresentable", {
  expect_null(.iaResolutionRefusal(c(50, 52), c(2, 2)))          # ordinary
  expect_null(.iaResolutionRefusal(1e12, 2))                     # the validator's ceiling
  expect_null(.iaResolutionRefusal(1e9, 4))
  expect_match(.iaResolutionRefusal(1e11, 20), "numerical resolution")
  expect_match(.iaResolutionRefusal(1e12, 5), "numerical resolution")
  # the edge: 1e9 with six decimals asks for sixteen significant digits,
  # one more than a double carries, and is refused
  expect_match(.iaResolutionRefusal(1e9, 6), "numerical resolution")
  # a row printed at zero, or with no magnitude at all, is not refused
  expect_null(.iaResolutionRefusal(0, 20))
  expect_null(.iaResolutionRefusal(c(NA, NaN), c(NA, 2)))
})

test_that("the audit's row is refused, and the same row at an ordinary magnitude is analyzed", {
  # 100 and 101 per arm, identical means, SD 1e-6, twenty decimals: at
  # zero the row reaches the replicate floor; at 1e11 the draws collapse
  # and the old engine answered 0.5 with no warning at all
  big <- runRow(meanRow(c(1e11, 1e11), c(1e-6, 1e-6), 20))
  expect_match(big$P, "numerical resolution")
  small <- runRow(meanRow(c(0, 0), c(1e-6, 1e-6), 20))
  expect_false(grepl("numerical resolution", small$P))
  expect_lt(as.numeric(sub("^<", "", small$P)), 0.01)
})

test_that("ordinary tables, and the magnitudes the screens pinned, are untouched", {
  expect_false(grepl("resolution", runRow(meanRow(c(50, 52), c(10, 10), 2))$P))
  expect_false(grepl("resolution", runRow(meanRow(c(1e9, 1e9), c(0.05, 0.05), 2))$P))
  # screen 1441's shape: means near 1e11 printed as integers
  expect_false(grepl("resolution", runRow(meanRow(c(1e11, 1e11 + 1), c(3, 3), 0))$P))
  # screen 1459's shape: two decimals at 1e9
  expect_false(grepl("resolution", runRow(meanRow(c(1e9 + 0.25, 1e9 + 0.25), c(0.05, 0.05), 2))$P))
})

test_that("a median row is judged on its quartiles' magnitude and precision too", {
  medRow <- function(med, q1, q3, dec) data.frame(
    TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = med, SD = NA_real_, Q1 = q1, Q3 = q3,
    ROUND_MEAN = dec, ROUND_OBSERVATION = dec, ROUND_DISPERSION = dec,
    stringsAsFactors = FALSE)
  bad <- runRow(medRow(c(1e11, 1e11), c(1e11 - 1, 1e11 - 1), c(1e11 + 1, 1e11 + 1), 20))
  expect_match(bad$P, "numerical resolution")
  # ...and on the precision INFERRED from the printed quartiles when the
  # ROUND_DISPERSION column is blank, which is how a parsed row arrives.
  # The inference can be finer than the median's own precision, so it has
  # to happen before the test (CodeRabbit on PR #218): six decimals at 1e9
  # is sixteen significant digits.
  blank <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30),
                      MEAN = c(1e9, 1e9), SD = NA_real_,
                      Q1 = c(1e9 - 0.000002, 1e9 - 0.000003),
                      Q3 = c(1e9 + 0.000002, 1e9 + 0.000003),
                      ROUND_MEAN = 0, ROUND_OBSERVATION = 0,
                      stringsAsFactors = FALSE)
  expect_match(runRow(blank)$P, "numerical resolution")
  ok <- runRow(medRow(c(12.4, 12.9), c(10.2, 10.8), c(15.1, 15.4), 1))
  expect_false(grepl("resolution", ok$P))
})

test_that("the direct draw stands down where its own grid is unrepresentable", {
  # the direct draw snaps to h/N, the grid a mean of N rounded observations
  # lives on; where that snap is finer than the arithmetic it makes no ties
  # at all, which is the alarming direction. Such arms simulate in full.
  # N must be large enough that h/N falls below the threshold: at 1e11 that
  # is 1.8e-4, so integer observations need more than about 5,600 per arm
  # (CodeRabbit on PR #218 - the first version used 5,000 and the direct
  # draw still ran)
  D <- meanRow(c(1e11, 1e11), c(3, 3), 0, N = c(8000, 8000))
  row <- runRow(D, m = 1000)
  expect_false(grepl("resolution", row$P))
  p <- as.numeric(sub("^<", "", row$P))
  expect_true(is.finite(p) && p >= 0 && p <= 1)
  # identical integer means at that magnitude tie in the honest null too,
  # so the row must not read as a near-certain alarm
  expect_gt(p, 0.001)
})
