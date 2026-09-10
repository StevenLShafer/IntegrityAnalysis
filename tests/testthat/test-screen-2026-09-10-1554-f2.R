# Adjudication of security screen 2026-09-10-1554 (over the S1 merge,
# d6496e0..68f1ed5), finding F2: a journal-style (wide) spreadsheet with
# ONE trial was a 500 on /parse and /analyze, and so was one with THREE
# or more - only a two-trial workbook read.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/apiService.R (the blocks are folded
# pairwise with Reduce(); do.call() had handed .ppRbindFill(a, b) the
# whole list as arguments). Reproduced through the path the screen
# names - the Editor's View workbook this app writes, read back by
# .apiReadUpload() - and checked to FAIL on 68f1ed5: one trial raised
# 'argument "b" is missing, with no default', three raised 'unused
# argument'; two read. Present since the API's first commit (99b25b5).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

wideWorkbook <- function(d) {
  v <- shiny::isolate(validateData(d))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  f <- tempfile(fileext = ".xlsx")
  writeBaselineTablesXlsx(tabs, f)
  f
}

test_that("a one-trial journal-style workbook reads through the API (screen 1554 F2)", {
  two <- wideFixtureTwoTrials()
  one <- two[two$TRIAL == unique(two$TRIAL)[1], ]
  r <- .apiReadUpload(wideWorkbook(one), "one.xlsx")
  expect_true(isTRUE(r$ok))
  expect_identical(r$engine, "wide")
  expect_identical(nrow(r$data), nrow(one))
  expect_identical(unique(r$data$TRIAL), unique(one$TRIAL))
  # and it analyses
  a <- shiny::isolate(.apiAnalyze(r$data, seed = 42))
  expect_true(isTRUE(a$ok))
})

test_that("two and three trials read too, every block kept", {
  two <- wideFixtureTwoTrials()
  r2 <- .apiReadUpload(wideWorkbook(two), "two.xlsx")
  expect_true(isTRUE(r2$ok)); expect_identical(nrow(r2$data), nrow(two))
  three <- rbind(two, transform(two[two$TRIAL == unique(two$TRIAL)[1], ], TRIAL = "C"))
  r3 <- .apiReadUpload(wideWorkbook(three), "three.xlsx")
  expect_true(isTRUE(r3$ok))
  expect_identical(r3$engine, "wide")
  expect_identical(nrow(r3$data), nrow(three))
  expect_setequal(unique(r3$data$TRIAL), unique(three$TRIAL))
})
