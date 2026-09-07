# P_Calc called directly, without validateData() (2026-09-07; audit
# finding F4 of 2026-09-06, Steve: "the default columns in P_Calc"). The
# roxygen invites investigators with more computing power to call the
# engine directly and lists the rounding columns as optional; without
# them the call used to die in R's own error messages. Now the columns are
# inferred as the validator infers them, and an arm of fewer than two
# patients is refused by name.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
runP <- function(d, m = 1000, seed = 3) {
  dqrng::dqset.seed(seed); set.seed(seed)
  suppressWarnings(shiny::isolate(P_Calc("T1", d, NULL, m)))
}

test_that("no rounding columns at all: inferred from the printed decimals, identical to supplying them", {
  d <- data.frame(TRIAL = "T1", ROW = c("Age", "Age", "Wt", "Wt"), N = c(50, 52, 50, 52),
                  MEAN = c(60.1, 60.3, 72.4, 72.95), SD = c(10.2, 9.8, 12.1, 11.7),
                  stringsAsFactors = FALSE)
  bare <- runP(d)
  withCols <- d; withCols$ROUND_MEAN <- c(1, 1, 2, 2); withCols$ROUND_OBSERVATION <- c(1, 1, 2, 2)
  expect_identical(bare$P, runP(withCols)$P)
  expect_true(all(is.finite(suppressWarnings(as.numeric(bare$P[1:2])))))
})

test_that("a blank ROUND_OBSERVATION follows the mean's precision; the direct-draw path included", {
  d <- data.frame(TRIAL = "T1", ROW = c("Age", "Age"), N = c(150, 152), MEAN = c(60.1, 60.3), SD = c(10.2, 9.8),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = NA_real_, stringsAsFactors = FALSE)
  filled <- d; filled$ROUND_OBSERVATION <- 1
  expect_identical(runP(d)$P, runP(filled)$P)
})

test_that("fewer than two patients in an arm is a named refusal, not a crash", {
  d <- data.frame(TRIAL = "T1", ROW = c("Age", "Age"), N = c(1, 30), MEAN = c(60, 61), SD = c(NA, 10),
                  stringsAsFactors = FALSE)
  x <- runP(d)
  expect_match(x$P[1], "fewer than 2")
  expect_identical(x$P[which(x$ROW == "Summary")], "No values")   # no usable row is left
  # a median row with a one-patient arm is refused the same way
  d <- data.frame(TRIAL = "T1", ROW = c("Dur", "Dur"), N = c(1, 30), MEAN = c(120, 125), SD = NA_real_,
                  Q1 = c(100, 100), Q3 = c(150, 150), stringsAsFactors = FALSE)
  expect_match(runP(d)$P[1], "fewer than 2")
})

test_that("the validator's own output is unchanged by the inference (it already carries the columns)", {
  d <- data.frame(TRIAL = "T1", ROW = c("Age", "Age"), N = c(50, 52), MEAN = c(60.1, 60.3), SD = c(10.2, 9.8),
                  stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  expect_false(isTRUE(v$FAIL))
  expect_identical(runP(v$DATA)$P, runP(d)$P)
})
