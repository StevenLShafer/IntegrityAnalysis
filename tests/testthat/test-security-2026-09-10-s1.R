# Adjudication of the private security audit of 2026-09-10, S1 (MEDIUM):
# a sheet with the SAME header twice lost one column in the 422's own
# template, and an unchanged resubmission analysed the survivor.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/apiService.R (.apiTemplateCsv selects
# columns by position). Reproduced THROUGH THE PATH THE REPORT NAMES: the
# actual /analyze and /parse handlers on the audit's fixture, then the
# returned template POSTed back. Checked to FAIL on d6496e0.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
handlers <- local({
  plumberFile <- system.file("api", "plumber.R", package = "IntegrityAnalysis")
  if (!nzchar(plumberFile)) plumberFile <- test_path("..", "..", "inst", "api", "plumber.R")
  ast <- parse(plumberFile, keep.source = FALSE)
  funs <- lapply(Filter(function(x) is.call(x) && identical(x[[1]], as.name("function")),
                        as.list(ast)), eval)
  upload <- Filter(function(f) "file" %in% names(formals(f)), funs)
  list(parse = upload[[1]], analyze = upload[[2]])
})
request <- function(f, path, seed = NULL) {
  part <- stats::setNames(list(readBin(path, "raw", n = file.info(path)$size)), basename(path))
  if (is.null(seed)) f(new.env(), new.env(), part) else f(new.env(), new.env(), part, seed = seed)
}
writeCsv <- function(lines, name) { f <- file.path(tempdir(), name); writeLines(lines, f); f }
fixture <- c("TRIAL,ROW,N,MEAN,SD,N", "T,Age,30,50,10,300", "T,Age,30,50.2,10,300")
headersOf <- function(csv) strsplit(strsplit(csv, "\n", fixed = TRUE)[[1]][1], ",", fixed = TRUE)[[1]]

test_that("identical duplicate headers survive the refusal's template, and the resubmission stays refused (security audit 2026-09-10, S1)", {
  f <- writeCsv(fixture, "duplicate-identical-header.csv")
  a <- request(handlers$analyze, f, seed = 42)
  expect_false(isTRUE(a$ok))
  expect_equal(a$stage, "validation")
  h <- gsub('"', "", headersOf(a$templateCsv))
  expect_equal(sum(h == "N"), 2L)                       # both N columns, both headers
  tpl <- utils::read.csv(text = a$templateCsv, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(unname(unlist(tpl[1, names(tpl) == "N"])), c(30L, 300L))
  # POSTing the template back is still the ambiguous sheet: refused again,
  # never analysed as N = 30
  rt <- writeCsv(strsplit(a$templateCsv, "\n", fixed = TRUE)[[1]], "duplicate-roundtrip.csv")
  b <- request(handlers$analyze, rt, seed = 42)
  expect_false(isTRUE(b$ok))
  expect_equal(b$stage, "validation")
  expect_null(b$overallP)
})

test_that("/parse returns both columns too", {
  f <- writeCsv(fixture, "duplicate-identical-header-parse.csv")
  p <- request(handlers$parse, f)
  h <- gsub('"', "", headersOf(p$templateCsv))
  expect_equal(sum(h == "N"), 2L)
})

test_that("the serializer keeps every column of a frame with duplicate names, base columns first", {
  d <- data.frame(ROW = "Age", N = 30, X = 1, N = 300, TRIAL = "T", check.names = FALSE)
  h <- gsub('"', "", headersOf(.apiTemplateCsv(d)))
  expect_equal(h, c("TRIAL", "ROW", "N", "N", "X"))
})
