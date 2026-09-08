# The Monte Carlo seed, the range checks, and the 0.1 escalation
# (Steve, 2026-09-05, after an outside review of the app).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-05.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
vd <- function(d) shiny::isolate(validateData(d))
issueCodes <- function(v, col) v$issues$code[v$issues$col == col]
cont <- function(N = c(15, 17), MEAN = c(45.3, 46.1), SD = c(12.1, 11.8), SE = NA_real_) data.frame(
  TRIAL = "T", ROW = "Age", N = N, MEAN = MEAN, SD = SD, SE = SE,
  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)

test_that("a negative SD, a fractional or tiny N, a negative SE are refused with the rule named; a printed zero SD is accepted", {
  v <- vd(cont(SD = c(-12.1, 11.8)))
  expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% issueCodes(v, "SD"))
  expect_match(v$issues$note[v$issues$col == "SD"][1], "cannot be negative")
  # a printed zero (13 rows of Carlisle's 2017 corpus): accepted, and analyzable
  v <- vd(cont(SD = c(0, 11.8)))
  expect_false(isTRUE(v$FAIL))
  dqrng::dqset.seed(5); set.seed(5)
  z <- vd(cont(N = c(6, 6), MEAN = c(39, 39), SD = c(0, 0)))
  expect_false(isTRUE(z$FAIL))
  x <- suppressWarnings(shiny::isolate(P_Calc("T", z$DATA, z$CategoryNames, 10000)))
  expect_equal(as.numeric(x$P[1]), 0.5)            # identical arms, nothing to compare
  # the floor note, beside the disclosure that this row's stated mean
  # precision runs past the digits its values carry - the arms print the
  # same mean, so the p rests on that precision (screen 2026-09-07-2101,
  # F2, which took the slack to zero)
  expect_match(x$NOTE[1], "^attainable floor")
  v <- vd(cont(N = c(15.5, 17)))
  expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% issueCodes(v, "N"))
  expect_match(v$issues$note[v$issues$col == "N"][1], "whole number")
  v <- vd(cont(N = c(1, 17)))
  expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% issueCodes(v, "N"))
  v <- vd(cont(SE = c(-2, 3)))
  expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% issueCodes(v, "SE"))
  # ...and a clean row still validates
  expect_false(isTRUE(vd(cont())$FAIL))
})

test_that("a median row with a fractional N, and a negative count, are refused", {
  d <- data.frame(TRIAL = "T", ROW = "Dur", N = c(20.5, 20), MEAN = c(127, 128), SD = NA_real_,
                  Q1 = c(98, 99), Q3 = c(160, 161), ROUND_MEAN = 0, ROUND_OBSERVATION = 0,
                  stringsAsFactors = FALSE)
  v <- vd(d); expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% issueCodes(v, "N"))
  # (a continuous row beside the category rows: the wide layout's count
  # columns are recognised by their blank cells on continuous rows)
  c2 <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Sex", "Sex"),
                   N = c(50, 50, NA, NA), MEAN = c(61, 60, NA, NA), SD = c(10, 11, NA, NA),
                   ROUND_MEAN = c(0, 0, NA, NA), ROUND_OBSERVATION = c(0, 0, NA, NA),
                   MALE = c(NA, NA, 25, -3), FEMALE = c(NA, NA, 25, 28), stringsAsFactors = FALSE)
  v <- vd(c2); expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% issueCodes(v, "MALE"))
})

test_that(".iaSeedValue accepts a whole number in range and nothing else", {
  f <- IntegrityAnalysis:::.iaSeedValue
  expect_identical(f("12345"), 12345L); expect_identical(f(7), 7L); expect_identical(f(" 42 "), 42L)
  expect_null(f(NULL)); expect_null(f("")); expect_null(f("abc")); expect_null(f(0)); expect_null(f(-1))
  expect_null(f(1.5)); expect_null(f(2147483648)); expect_identical(f(c("1", "2")), 1L)   # the first value only
})

test_that("the same seed reproduces the analysis exactly; different seeds differ; unseeded runs vary within the interval", {
  d <- data.frame(TRIAL = "T", ROW = "Weight", N = 6, MEAN = c(77, 78), SD = c(30, 30),
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  v <- vd(d)
  run <- function(seed) {
    if (!is.null(seed)) IntegrityAnalysis:::.iaSetSeed(seed)
    x <- suppressWarnings(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 100000)))
    x[which(x$ROW == "Weight"), c("P", "CI95", "M")]
  }
  a <- run(12345L); b <- run(12345L); c <- run(54321L)
  expect_identical(a, b)
  expect_false(identical(a$P, c$P) && identical(a$CI95, c$CI95))
  # the worked example is borderline, so it now escalates to 10,000
  expect_identical(a$M, "10000")
  ps <- as.numeric(a$P)
  expect_gt(ps, 0.03); expect_lt(ps, 0.07)
})

test_that("the API path seeds too: .apiAnalyze(seed =) is reproducible", {
  d <- data.frame(TRIAL = "T", ROW = "Weight", N = 6, MEAN = c(77, 78), SD = c(30, 30),
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  a <- IntegrityAnalysis:::.apiAnalyze(d, seed = 99L)
  b <- IntegrityAnalysis:::.apiAnalyze(d, seed = 99L)
  expect_true(isTRUE(a$ok)); expect_identical(a$results$P, b$results$P)
})

test_that("the escalation rule: p in [0.01, 0.1) runs 10,000; p >= 0.1 stops at 1,000; p < 0.01 runs 100,000", {
  dqrng::dqset.seed(3); set.seed(3)
  meanrow <- function(mean, sd, n = 40) data.frame(
    TRIAL = "T", ROW = "X", N = n, MEAN = mean, SD = sd,
    ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  runM <- function(d) { x <- suppressWarnings(shiny::isolate(P_Calc("T", d, NULL, 100000))); as.numeric(x$M[1]) }
  expect_equal(runM(rbind(meanrow(54.1, 9.2), meanrow(51.0, 8.9))), 1000)          # far from alarming
  expect_equal(runM(rbind(meanrow(54.1, 9.2), meanrow(54.1, 9.2), meanrow(54.1, 9.2))), 100000)  # alarming
  # borderline: three arms two apart at SD 9, N 40 - a row p around 0.05
  x <- suppressWarnings(shiny::isolate(P_Calc("T", rbind(meanrow(54.1, 9.2), meanrow(54.6, 9.0)), NULL, 100000)))
  p <- as.numeric(x$P[1]); m <- as.numeric(x$M[1])
  expect_true((p < 0.1 && m >= 10000) || (p >= 0.1 && m == 1000))
})

test_that("a sheet with MEANX or SDX and no MEAN or SD is refused, not crashed (screen 2026-09-05 F4)", {
  d <- data.frame(TRIAL = "T", ROW = "Age", N = c(15, 17), MEANX = c(45, 46), SDX = c(12, 11),
                  stringsAsFactors = FALSE)
  v <- vd(d)
  expect_true(isTRUE(v$FAIL))
  d2 <- data.frame(TRIAL = "T", ROW = "Age", N = c(15, 17), MEAN = c(45, 46), SDX = c(12, 11),
                   stringsAsFactors = FALSE)
  expect_true(isTRUE(vd(d2)$FAIL))
})

test_that("the plumber layer's empty-list seed (a form part without a Content-Type) is recognised", {
  expect_null(IntegrityAnalysis:::.iaSeedValue(list()))
  expect_true(is.list(list()) && !length(list()))
})
