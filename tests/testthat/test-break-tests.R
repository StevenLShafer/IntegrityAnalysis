# What a user can type that used to end the session or 500 the API
# (Steve's "break IntegrityAnalysis" ask, 2026-09-06; harness and
# transcripts in C:/dev/Corpus/security/breakApp.py, breakApi.py).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-06.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
vd <- function(d) shiny::isolate(validateData(d))
cont <- function(N = c(15, 17), MEAN = c(45.3, 46.1), SD = c(12.1, 11.8)) data.frame(
  TRIAL = "T", ROW = "Age", N = N, MEAN = MEAN, SD = SD, ROUND_MEAN = 1, ROUND_OBSERVATION = 1,
  stringsAsFactors = FALSE)

test_that("Inf, -Inf and NaN in any numeric cell are unreadable, not a crash", {
  for (bad in c(Inf, -Inf, NaN)) {
    for (col in c("MEAN", "N", "SD")) {
      d <- cont(); d[[col]][1] <- bad
      v <- NULL
      expect_error(v <- vd(d), NA)
      expect_true(isTRUE(v$FAIL))
    }
  }
  d <- cont(); d$MEAN <- c("Inf", "46.1")          # typed as text, as the grid delivers it
  v <- vd(d); expect_true(isTRUE(v$FAIL)); expect_true("unreadable" %in% v$issues$code[v$issues$col == "MEAN"])
})

test_that("an absurd magnitude is refused before it can overflow the engine", {
  v <- vd(cont(SD = c(1e300, 11.8)))
  expect_true(isTRUE(v$FAIL)); expect_true("incongruent" %in% v$issues$code[v$issues$col == "SD"])
  v <- vd(cont(MEAN = c(1e300, 46.1)))
  expect_true(isTRUE(v$FAIL))
  expect_false(isTRUE(vd(cont(MEAN = c(1e11, 46.1)))$FAIL))   # large but possible stays
})

test_that("an Inf rounding column is dropped to inferred, not crashed on", {
  d <- cont(); d$ROUND_MEAN <- c(Inf, 1)
  expect_error(v <- vd(d), NA)
})

test_that("category counts beyond the arm ceiling are refused, not simulated", {
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Sex", "Sex"), N = c(10, 10, NA, NA),
                  MEAN = c(50, 51, NA, NA), SD = c(10, 10, NA, NA),
                  MALE = c(NA, NA, 1e9, 1e9), FEMALE = c(NA, NA, 1e9, 1e9), stringsAsFactors = FALSE)
  v <- vd(d)
  expect_true(isTRUE(v$FAIL)); expect_true("too_large" %in% v$issues$code)
})

test_that("a reason never carries the server's working directory", {
  work <- file.path(tempdir(), "apiXYZ")
  r <- IntegrityAnalysis:::.apiScrubPath(paste0("zip error: cannot open `", work, "/bad.docx`"), work, "bad.docx")
  expect_false(grepl(tempdir(), r, fixed = TRUE)); expect_match(r, "bad.docx")
  expect_null(IntegrityAnalysis:::.apiScrubPath(NULL, work, "x"))
})

test_that("an overflowing count in a level column is refused, not passed to the engine (screen 0514 F1)", {
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Sex", "Sex", "Sex", "Sex"),
                  LEVEL = c(NA, NA, "M", "M", "F", "F"),
                  N = c(10, 10, 1e308, 1e308, 5, 5), MEAN = c(50, 51, NA, NA, NA, NA),
                  SD = c(10, 10, NA, NA, NA, NA), stringsAsFactors = FALSE)
  v <- NULL; expect_error(v <- vd(d), NA)
  expect_true(isTRUE(v$FAIL))
  expect_true(any(v$issues$code %in% c("too_large", "incongruent")))
})

test_that("a wide count beyond 2^31 - 1, or Inf, is refused rather than crashing is_category (screen 0514 F2)", {
  expect_true(IntegrityAnalysis:::is_category(c(NA, 3e9, 1)))    # a whole number: the sweep and the ceiling judge its size
  expect_false(IntegrityAnalysis:::is_category(c(NA, Inf, 1)))
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Sex", "Sex"), N = c(10, 10, NA, NA),
                  MEAN = c(50, 51, NA, NA), SD = c(10, 10, NA, NA),
                  MALE = c(NA, NA, 3e9, 5), FEMALE = c(NA, NA, 5, 5), stringsAsFactors = FALSE)
  v <- NULL; expect_error(v <- vd(d), NA); expect_true(isTRUE(v$FAIL))
})

test_that("a rounding column that arrives as text is coerced before it is clamped (screen 0514 F3)", {
  d <- cont(); d$ROUND_MEAN <- c("99", "1"); d$ROUND_DISPERSION <- c("x", "Inf")
  v <- NULL; expect_error(v <- vd(d), NA)
  expect_true(all(is.na(v$DATA$ROUND_MEAN) | abs(v$DATA$ROUND_MEAN) <= 20))
  expect_true(is.numeric(v$DATA$ROUND_DISPERSION))
})

test_that("an engine error becomes a 422 naming the stage on the API, never a 500", {
  # a DATA whose P_Calc call errors: force it by stubbing P_Calc
  d <- cont()
  old <- IntegrityAnalysis:::P_Calc
  assignInNamespace("P_Calc", function(...) stop("boom"), "IntegrityAnalysis")
  on.exit(assignInNamespace("P_Calc", old, "IntegrityAnalysis"), add = TRUE)
  r <- IntegrityAnalysis:::.apiAnalyze(d)
  expect_false(isTRUE(r$ok)); expect_identical(r$stage, "analysis"); expect_match(r$issues$note[1], "boom")
})

test_that("the trial's Monte Carlo interval brackets its own mid-p at the attainable floor", {
  # three integer rows of two arms of 20: every replicate that reaches the
  # observed sum ties it, none exceeds it (outside review, 2026-09-06)
  dqrng::dqset.seed(1); set.seed(1)
  d <- do.call(rbind, lapply(1:3, function(j) data.frame(
    TRIAL = "T", ROW = paste0("V", j), N = 20, MEAN = 60 + j, SD = 13,
    ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)[rep(1, 2), ]))
  x <- suppressWarnings(shiny::isolate(P_Calc("T", d, NULL, 100000)))
  s <- which(x$ROW == "Summary")
  p <- as.numeric(sub("^<", "", x$P[s])); b <- as.numeric(strsplit(x$CI95[s], " to ")[[1]])
  expect_lt(p, 0.001)
  expect_identical(b[1], 0)                 # nothing exceeded the observed sum
  expect_true(p >= b[1] && p <= b[2])
})

test_that("decimal places are read off a plain rendering, never scientific notation", {
  f <- IntegrityAnalysis:::.iaDecimals
  expect_identical(f(0.5), 1L); expect_identical(f(45.3), 1L); expect_identical(f(0.0012), 4L)
  expect_identical(f(0.0001), 4L); expect_identical(f(0.000015), 6L); expect_identical(f(1e-10), 10L)
  expect_identical(f(77), 0L); expect_identical(f(NA_real_), 0L); expect_identical(f(Inf), 0L)
  d <- data.frame(TRIAL = "T", ROW = "X", N = 30, MEAN = c(0.0001, 0.0002), SD = 0.00005, stringsAsFactors = FALSE)
  v <- vd(d); expect_identical(v$DATA$ROUND_MEAN, c(4, 4))
})

test_that("an alias-named rounding column is clamped too (screen 0617 F1)", {
  for (nm in c("ROUND", "OBSERVATION", "MEAN DECIMALS")) {
    d <- cont(); d$ROUND_MEAN <- NULL; d$ROUND_OBSERVATION <- NULL; d[[nm]] <- c(2e9, 2e9)
    v <- vd(d)
    expect_true(all(abs(v$DATA$ROUND_MEAN) <= 20), info = nm)
    expect_true(all(abs(v$DATA$ROUND_OBSERVATION) <= 20), info = nm)
  }
  expect_identical(nchar(IntegrityAnalysis:::.fmtAt(1.5, 2e9)), 22L)   # "1." + 20 decimals, not 2e9
})
