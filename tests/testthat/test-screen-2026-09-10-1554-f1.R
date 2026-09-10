# Adjudication of security screen 2026-09-10-1554 (over the S1 merge,
# d6496e0..68f1ed5), finding F1 (LOW, integrity): the long categorical
# layout bypassed the duplicate-header refusal.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/app_globals.R (.iaLongToWide() returns a
# frame with a duplicated header as it came, so the validator's
# duplicate-name refusal sees both headers). Reproduced through the path
# the screen names - a CSV with a LEVEL column and the header N twice,
# through .apiReadUpload() and .apiAnalyze(), and through validateData()
# directly - and checked to FAIL on 68f1ed5 (validateData FAIL = FALSE
# with the second N as a Misc column N.1; the API past validation).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

dupLongCsv <- function() {
  f <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,LEVEL,N,MEAN,SD,N",
               "T,Sex,Male,30,,,31",
               "T,Sex,Male,32,,,33",
               "T,Sex,Female,20,,,21",
               "T,Sex,Female,18,,,17",
               "T,Age,,50,45.1,10.2,50",
               "T,Age,,50,45.3,10.1,50"), f)
  f
}

test_that("a long-layout sheet with the header N twice is refused structurally, both headers in the template (screen 1554 F1)", {
  r <- .apiReadUpload(dupLongCsv(), "dup.csv")
  expect_true(isTRUE(r$ok))
  expect_identical(sum(names(r$data) == "N"), 2L)              # the reader keeps both
  a <- shiny::isolate(.apiAnalyze(r$data, seed = 42))
  expect_false(isTRUE(a$ok))
  expect_identical(a$stage, "validation")
  expect_true("structural" %in% a$issues$code)
  expect_match(a$issues$note[a$issues$code == "structural"][1], "N from 'N' and 'N'", fixed = TRUE)
  hdr <- strsplit(a$templateCsv, "\n")[[1]][1]
  expect_identical(lengths(regmatches(hdr, gregexpr('"N"', hdr))), 2L)   # the sheet as received
  expect_false(grepl("N.1", a$templateCsv, fixed = TRUE))
})

test_that("the validator refuses the same frame directly, and the app's path is the same function", {
  d <- read.csv(dupLongCsv(), check.names = FALSE, stringsAsFactors = FALSE)
  expect_identical(sum(names(d) == "N"), 2L)
  v <- suppressMessages(shiny::isolate(validateData(d)))
  expect_true(v$FAIL)
  expect_true("structural" %in% v$issues$code)
  # and .iaLongToWide() itself leaves the frame alone
  expect_identical(names(.iaLongToWide(d)), names(d))
})

test_that("a long-layout sheet without a duplicated header still converts", {
  d <- data.frame(TRIAL = "T", ROW = c("Sex", "Sex", "Sex", "Sex"),
                  LEVEL = c("Male", "Male", "Female", "Female"),
                  N = c(30, 32, 20, 18), MEAN = NA_real_, SD = NA_real_,
                  stringsAsFactors = FALSE)
  w <- .iaLongToWide(d)
  expect_true(all(c("MALE", "FEMALE") %in% names(w)))
  expect_identical(nrow(w), 2L)
})
