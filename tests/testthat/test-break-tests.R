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
