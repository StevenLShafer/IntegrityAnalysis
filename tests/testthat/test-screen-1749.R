# Regression tests for the full-surface security screen of 2026-09-06
# (screen-2026-09-06-1749): F1 the long-layout converter's cost and its
# gate, F3 case-variant trial names in the journal-view workbook, N2 the
# page-band bins.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-06.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

longFrame <- function(n, levelsPerVar = 1L) {
  # n lines, each variable with `levelsPerVar` distinct levels, one arm
  data.frame(TRIAL = "T", ROW = paste0("V", ceiling(seq_len(n) / levelsPerVar)),
             LEVEL = paste0("L", seq_len(n)), N = seq_len(n), stringsAsFactors = FALSE)
}

test_that("F1: a long file whose levels would need more than .iaMaxLevelColumns count columns is refused before anything is built, in well under a second", {
  d <- longFrame(3000)
  t0 <- Sys.time()
  expect_error(.iaLongToWide(d), "count columns")
  expect_lt(as.numeric(Sys.time() - t0, units = "secs"), 1)
  # exactly at the limit it converts; one over, it refuses
  expect_equal(ncol(.iaLongToWide(longFrame(.iaMaxLevelColumns))) - 3L, .iaMaxLevelColumns)
  expect_error(.iaLongToWide(longFrame(.iaMaxLevelColumns + 1L)), "count columns")
})

test_that("F1: the linear build converts a large legitimate long file quickly", {
  # 5,000 lines: 100 variables x 5 levels x 10 arms - well inside the column limit
  d <- data.frame(TRIAL = "T",
                  ROW = rep(paste0("V", 1:100), each = 50),
                  LEVEL = rep(rep(paste0("L", 1:5), each = 10), 100),
                  N = seq_len(5000), stringsAsFactors = FALSE)
  t0 <- Sys.time()
  w <- .iaLongToWide(d)
  expect_lt(as.numeric(Sys.time() - t0, units = "secs"), 5)
  expect_equal(nrow(w), 1000)          # 100 variables x 10 arms
  expect_equal(ncol(w), 3 + 5)         # TRIAL, ROW, N + five level columns
  # the counts land in the right cells: variable 1, level L2, arm 3 is line 13
  expect_equal(w$L2[w$ROW == "V1"][3], 13)
})

test_that("F1: the rebuilt converter reproduces the old semantics on a mixed file (arm order, later duplicate wins, continuous lines in place)", {
  d <- data.frame(TRIAL = "T",
                  ROW   = c("Age", "Sex", "Sex", "Age", "Sex", "Sex", "Wt", "Sex"),
                  LEVEL = c(NA,   "M",   "F",   NA,    "M",   "F",   NA,   "M"),
                  N     = c(20,   10,    10,    22,    11,    11,    20,   99),
                  MEAN  = c(60,   NA,    NA,    61,    NA,    NA,    70,   NA),
                  SD    = c(10,   NA,    NA,    11,    NA,    NA,    12,   NA),
                  stringsAsFactors = FALSE)
  w <- .iaLongToWide(d)
  expect_identical(w$ROW, c("Age", "Sex", "Sex", "Sex", "Age", "Wt"))   # the wide rows sit where the first Sex line stood
  expect_equal(w$M[w$ROW == "Sex"], c(10, 11, 99))                      # three arms of M, in file order
  expect_equal(w$F[w$ROW == "Sex"], c(10, 11, NA))                      # F has two arms
  expect_true(all(is.na(w$N[w$ROW == "Sex"])))
  expect_equal(w$MEAN[w$ROW == "Age"], c(60, 61))
  expect_identical(attr(w, "iaLevelColumns"), c("M", "F"))
  expect_false("LEVEL" %in% names(w))
})

test_that("F1: the API returns a 422 at the validation stage, not a 500, for a long file over the column limit", {
  d <- longFrame(.iaMaxLevelColumns + 1L)
  r <- .apiAnalyze(d)
  expect_false(r$ok)
  expect_identical(r$stage, "validation")
  expect_identical(r$issues$code, "error")
  expect_match(r$issues$note, "count columns")
})

test_that("F3: two trials whose names differ only by case get two sheets", {
  tabs <- list("Trial A" = data.frame(Variable = "Age", Arm1 = "60 (10)"),
               "trial a" = data.frame(Variable = "Age", Arm1 = "61 (11)"))
  f <- tempfile(fileext = ".xlsx")
  expect_error(writeBaselineTablesXlsx(tabs, f), NA)
  expect_length(openxlsx::getSheetNames(f), 2)
})

test_that("N2: a word placed far off the page does not make the band bins proportional to its position", {
  set.seed(1)
  w <- data.frame(x = runif(200, 50, 550), y = rep(seq(50, 750, length.out = 40), each = 5),
                  width = 30, height = 10, text = "w", stringsAsFactors = FALSE)
  w$x[1] <- 1e9
  t0 <- Sys.time()
  b <- .ppPageBands(w)
  expect_lt(as.numeric(Sys.time() - t0, units = "secs"), 5)
  expect_true(is.data.frame(b) && all(c("x0", "x1") %in% names(b)))
})

test_that("F1 (screen 0702): 101 trials identical in their first 31 characters get 101 sheets, none longer than 31", {
  pre <- strrep("T", 31)
  tabs <- setNames(lapply(1:101, function(k) data.frame(Variable = "Age", Arm1 = "60 (10)")),
                   paste0(pre, 1:101))
  f <- tempfile(fileext = ".xlsx")
  expect_error(sheets <- writeBaselineTablesXlsx(tabs, f), NA)   # failed on the previous code: "... 100" was 32 characters
  expect_length(unique(tolower(sheets)), 101)
  expect_true(all(nchar(sheets) <= 31))
  expect_length(openxlsx::getSheetNames(f), 101)
})

test_that("F1 (screens 1036 and 1059): the draw budget prices a median/IQR line at three times its N", {
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Dur", "Dur"), N = c(100, 100, 100, 100),
                  MEAN = c(60, 61, 120, 121), SD = c(10, 10, NA, NA),
                  Q1 = c(NA, NA, 100, 100), Q3 = c(NA, NA, 150, 150), stringsAsFactors = FALSE)
  expect_equal(.apiDrawWork(d, character(0)), (200 + 3 * 200) * .apiReplicateCeiling)
  d$Q1 <- NA_real_; d$Q3 <- NA_real_
  expect_equal(.apiDrawWork(d, character(0)), 400 * .apiReplicateCeiling)
})

test_that("F2 (screen 1036): sheet names are Excel-safe - no apostrophe at either end, no character outside the basic plane, and a truncation cannot manufacture one", {
  nms <- c("'Smith 2024", "Jones 2023'", "Brüggemann Étude 2021",
           paste(rep(intToUtf8(0x1F600), 31), collapse = ""),   # 31 emoji: 62 UTF-16 units
           paste0(strrep("A", 30), "'B"),                        # the cut at 31 would end in an apostrophe
           "abc' '", "' 'abc", "Smith 2024'\t'")                 # apostrophe, space, apostrophe (screen 1059, F1)
  tabs <- setNames(lapply(60:67, function(v) data.frame(Variable = "Age", Arm1 = paste0(v, " (10)"))), nms)
  f <- tempfile(fileext = ".xlsx")
  sheets <- writeBaselineTablesXlsx(tabs, f)
  expect_length(sheets, 8)
  expect_identical(sheets[6:8], c("abc", "abc 2", "Smith 2024 2"))   # the last de-duplicates against the first
  expect_false(any(grepl("^'|'$", sheets)))
  expect_true(all(vapply(sheets, function(s) all(utf8ToInt(s) <= 0xFFFF), logical(1))))
  expect_true(all(nchar(sheets) <= 31))
  expect_identical(sheets[1], "Smith 2024")
  expect_identical(sheets[2], "Jones 2023")
  expect_identical(sheets[3], "Brüggemann Étude 2021")
  expect_identical(sheets[4], "Trial")
  expect_identical(sheets[5], strrep("A", 30))
  expect_length(openxlsx::getSheetNames(f), 8)
})
