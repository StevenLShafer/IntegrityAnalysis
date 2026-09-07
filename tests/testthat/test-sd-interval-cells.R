# The SD's printed interval when precisions are supplied for some arms and
# not others (2026-09-07; finding F5 of the GPT-6 audit in docs/audits/).
# The helper used a supplied ROUND_DISPERSION only when EVERY arm had one
# and otherwise re-inferred every arm, discarding the supplied values; now
# each blank cell alone is inferred, as the validator infers it (the
# variable's maximum printed decimals across its arms).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that("a supplied precision is kept when another arm's is blank; the blank is inferred", {
  iv <- .iaSdInterval(c(1, 1.1), c(2, NA))
  expect_equal(iv$lo, c(0.995, 1.05))      # arm 1 as supplied (two decimals); arm 2 inferred (one decimal)
  expect_equal(iv$hi, c(1.005, 1.15))
  # the audit's counter-example: before the fix arm 1 became [0.5, 1.5]
  expect_false(isTRUE(all.equal(iv$lo[1], 0.5)))
})

test_that("blank cells take the variable's maximum inferred decimals, as the validator does", {
  # 1.2 beside 1.25: a two-decimal variable on both blank lines
  iv <- .iaSdInterval(c(1.2, 1.25), c(NA, NA))
  expect_equal(iv$lo, c(1.195, 1.245)); expect_equal(iv$hi, c(1.205, 1.255))
  # one supplied, one blank beside a finer arm: the blank follows the inferred maximum
  iv <- .iaSdInterval(c(10, 9.85, 12), c(0, NA, NA))
  expect_equal(iv$lo, c(9.5, 9.845, 11.995)); expect_equal(iv$hi, c(10.5, 9.855, 12.005))
})

test_that("a direct call with a partly blank ROUND_DISPERSION agrees with the validator's inference", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(2.3, 2.3), SD = c(1, 1.1),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = c(2, NA),
                  stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  expect_identical(v$DATA$ROUND_DISPERSION, c(2, 1))
  ivDirect <- .iaSdInterval(d$SD, d$ROUND_DISPERSION)
  ivValid  <- .iaSdInterval(v$DATA$SD, v$DATA$ROUND_DISPERSION)
  expect_equal(ivDirect, ivValid)
})
