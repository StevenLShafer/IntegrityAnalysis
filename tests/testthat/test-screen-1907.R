# Security screen 2026-09-07-1907, which screened the fix for screen 1758
# and found three more.
#
# F1 (HIGH): the grid gate covered ROUND_MEAN and ROUND_DISPERSION but not
# ROUND_OBSERVATION, the third precision column and the one that sets the
# grid every simulated observation is rounded to. A coarse value quantises
# the replicates while the printed values stay put, so honest data looks
# impossibly alike: five honest arms of 40 read p = 0.433 at 0 and 0.0125
# at -2; integer means near 50,000 read 0.586 and 0.00013 at -5.
# F2 (MEDIUM): zero sits on every grid, so an all-zero median row - "0
# (0-0)", a shape many analgesia trials carry - passed the gate at any
# stated precision and went from its honest 0.5 to below 0.0001.
# F3 (MEDIUM) and A1: the app-side cap raised "undefined columns selected"
# on every document that reached it, and the test that pinned it asserted
# only that a constant existed.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runRow <- function(D, m = 2000, seed = 5) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}
armRow <- function(ro, means = c(58.9, 61.2, 60.0, 62.3, 59.4), rm = 1)
  data.frame(TRIAL = "T", ROW = "X", N = rep(40, length(means)), MEAN = means,
             SD = rep(10, length(means)), ROUND_MEAN = rm, ROUND_OBSERVATION = ro,
             ROUND_DISPERSION = 0, stringsAsFactors = FALSE)
zeroRow <- function(rd)
  data.frame(TRIAL = "T", ROW = "X", N = c(40, 40), MEAN = c(0, 0), SD = NA_real_,
             Q1 = c(0, 0), Q3 = c(0, 0), ROUND_MEAN = 0, ROUND_OBSERVATION = 0,
             ROUND_DISPERSION = rd, stringsAsFactors = FALSE)

test_that("F1: a coarse ROUND_OBSERVATION is refused, and the honest row is not", {
  expect_false(grepl("stated precision", runRow(armRow(0))$P))
  expect_match(runRow(armRow(-2))$P, "stated precision")
  expect_match(runRow(armRow(-5))$P, "stated precision")
  # the screen's second row: integer means near 50,000
  expect_false(grepl("stated precision", runRow(armRow(0, 50000:50004, rm = 0))$P))
  expect_match(runRow(armRow(-5, 50000:50004, rm = 0))$P, "stated precision")
  # ...and the refusal names the column an editor has to look at
  expect_match(runRow(armRow(-2))$P, "ROUND OBSERVATION")
})

test_that("F1: the rule itself is vacuous for every ordinary table", {
  # a statistic built from N observations on a grid of h lies on a grid no
  # coarser than h/N, so the printed value's own interval must contain a
  # multiple of h/N - which it always does when h/N is the finer of the two
  expect_true(.iaObservationGridOK(58.9, 1, 0, 40))       # honest
  expect_false(.iaObservationGridOK(58.9, 1, -2, 40))     # h/N = 2.5
  expect_true(.iaObservationGridOK(60.0, 1, -2, 40))      # 60 IS a multiple of 2.5
  expect_false(.iaObservationGridOK(50001, 0, -5, 40))    # h/N = 2500
  expect_true(.iaObservationGridOK(50000, 0, -5, 40))     # 50000 is a multiple
  expect_true(.iaObservationGridOK(c(NA, 5), c(1, 1), c(0, 0), c(NA, 40)))
  expect_true(.iaObservationGridOK(5, 1, 0, 0))           # no arm size, nothing to judge
  # the divisor is the caller's: a MEDIAN of an even number of observations
  # moves in half-steps of the observation grid, not in hObs/N, so a median
  # row must be judged on that coarser lattice (CodeRabbit on PR #220)
  expect_true(.iaObservationGridOK(0.5, 1, -1, 40))       # as a MEAN: hObs/N = 0.25
  expect_false(.iaObservationGridOK(0.5, 1, -1, 2))       # as a MEDIAN: steps of 5
  expect_true(.iaObservationGridOK(5.0, 1, -1, 2))
})

test_that("F1: a median row is judged on the median's lattice, not the mean's", {
  # observations rounded to tens: an even arm's median can only land on a
  # multiple of 5, so a median printed as 12.4 is not a reading of that page
  med <- function(ro) data.frame(
    TRIAL = "T", ROW = "X", N = c(40, 40), MEAN = c(12.4, 12.9), SD = NA_real_,
    Q1 = c(10, 10), Q3 = c(15, 15), ROUND_MEAN = 1, ROUND_OBSERVATION = ro,
    ROUND_DISPERSION = 0, stringsAsFactors = FALSE)
  expect_false(grepl("stated precision", runRow(med(1))$P))
  expect_match(runRow(med(-1))$P, "stated precision")
})

test_that("F2: an all-zero row keeps its honest verdict and refuses the coarse claim", {
  z <- runRow(zeroRow(0))
  expect_false(grepl("stated precision", z$P))
  expect_equal(as.numeric(sub("^<", "", z$P)), 0.5)
  expect_match(z$NOTE, "attainable floor")
  expect_match(runRow(zeroRow(-20))$P, "stated precision")
  expect_match(runRow(zeroRow(-3))$P, "stated precision")
  # the helper: a row with any non-zero value is left to the grid test
  expect_true(.iaZeroRowGridOK(c(0, 0), 0, 0))
  expect_false(.iaZeroRowGridOK(c(0, 0), 0, -20))
  expect_true(.iaZeroRowGridOK(c(0, 5), 0, -20))          # not a zero row
  expect_true(.iaZeroRowGridOK(c(0, 0), 1, 2))            # dispersion FINER: fine
  # ARM BY ARM: comparing minima would pass this, while the second arm
  # still claims a dispersion grid of 1e20 against a location grid of 1
  # (CodeRabbit on PR #220)
  expect_false(.iaZeroRowGridOK(c(0, 0), c(-20, 0), c(-20, -20)))
  expect_true(.iaZeroRowGridOK(c(0, 0), c(-20, 0), c(-20, 0)))
})

test_that("F3 and A1: the app's cap runs on a real three-column skipped frame", {
  # the parser's frame carries label, reason AND text; the first version of
  # this cap built a two-column literal and selected three names out of it,
  # which raised "undefined columns selected" on every document that
  # reached the cap - the hostile case the cap exists for. This test calls
  # the function the upload observer calls, and fails on that version.
  sk <- data.frame(label = paste("line", seq_len(250)),
                   reason = paste("reason", seq_len(250)),
                   text = paste("text", seq_len(250)),
                   stringsAsFactors = FALSE)
  out <- expect_silent(.iaCapSkipped(sk))
  expect_equal(nrow(out), .iaMaxSkippedRows + 1L)
  expect_identical(names(out), names(sk))
  expect_equal(out$label[.iaMaxSkippedRows], paste("line", .iaMaxSkippedRows))
  expect_match(out$label[nrow(out)], "50 further unusable line")
  expect_match(out$reason[nrow(out)], "capped")
  # a short frame passes through untouched, and so does an empty one
  short <- sk[1:3, , drop = FALSE]
  expect_identical(.iaCapSkipped(short), short)
  expect_null(.iaCapSkipped(NULL))
})
