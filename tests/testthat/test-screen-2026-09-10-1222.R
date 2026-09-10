# Adjudication of security screen 2026-09-10-1222 (over the range #254,
# #257, #255 and #256 merged): F2, the duplicate-name refusal's template
# had already chosen one column; F3, the blank-TRIAL issues indexed the
# frame before the long layout was converted. (F1, the tripwire pin's
# constructed-name gap, is verified by tools/securityCheckMutations.R.)
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fixes in R/apiService.R and R/validateData.R. Per
# the standing rule in AGENTS.md each defect is reproduced THROUGH THE
# PATH THE REPORT NAMES - F2 through the actual /analyze handler with the
# screen's NUMBER = 100 / N = 7 sheet, F3 through the validator with a
# long-layout frame - and checked to FAIL on 26133b2.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

analyzeHandler <- local({
  plumberFile <- system.file("api", "plumber.R", package = "IntegrityAnalysis")
  if (!nzchar(plumberFile)) plumberFile <- test_path("..", "..", "inst", "api", "plumber.R")
  ast <- parse(plumberFile, keep.source = FALSE)
  funs <- lapply(Filter(function(x) is.call(x) && identical(x[[1]], as.name("function")),
                        as.list(ast)), eval)
  upload <- Filter(function(f) "file" %in% names(formals(f)), funs)
  upload[[2]]
})
request <- function(path, seed = 42) {
  part <- stats::setNames(list(readBin(path, "raw", n = file.info(path)$size)), basename(path))
  analyzeHandler(new.env(), new.env(), part, seed = seed)
}
writeCsv <- function(lines, name) { f <- file.path(tempdir(), name); writeLines(lines, f); f }
issuesOf <- function(a) do.call(rbind, lapply(a$issues, function(i)
  data.frame(row = if (is.null(i$row)) NA_integer_ else i$row, col = as.character(i$col),
             code = as.character(i$code), note = as.character(i$note), stringsAsFactors = FALSE)))

test_that("a duplicate-name refusal names the original headers and returns the sheet as received (screen 1222 F2)", {
  f <- writeCsv(c('"TRIAL","ROW","NUMBER","N","MEAN","SD","ROUND_MEAN","ROUND_OBSERVATION","ROUND_DISPERSION"',
                  '"A","X",100,7,"50.0","3.0",1,0,1', '"A","X",100,7,"50.2","3.1",1,0,1'),
                "number-and-n.csv")
  a <- request(f)
  expect_false(isTRUE(a$ok))
  expect_equal(a$stage, "validation")
  s <- issuesOf(a); s <- s[s$code == "structural", , drop = FALSE]
  expect_equal(nrow(s), 1L)
  # the note names the two SOURCE columns, not the collapsed name twice
  expect_match(s$note, "'NUMBER'"); expect_match(s$note, "'N'")
  # ...and the round-trip payload is the sheet as received: both columns,
  # both values - on 26133b2 it held a single N column with the 100 and
  # the 7 was gone, so a re-post analysed the service's own choice
  tpl <- utils::read.csv(text = a$templateCsv, check.names = FALSE, stringsAsFactors = FALSE)
  expect_true(all(c("NUMBER", "N") %in% names(tpl)))
  expect_equal(unique(tpl$NUMBER), 100L)
  expect_equal(unique(tpl$N), 7L)
})

test_that("blank-TRIAL issues index the frame the validator returns, long layout included (screen 1222 F3)", {
  # a continuous variable named on trial A, and a categorical block in the
  # long layout whose four lines carry no trial: after the block collapses
  # to two wide rows, the returned frame has four rows, not six
  d <- data.frame(TRIAL = c("A", "A", "", "", "", ""),
                  ROW = c("Age", "Age", "Sex", "Sex", "Sex", "Sex"),
                  LEVEL = c("", "", "Male", "Male", "Female", "Female"),
                  N = c(100, 100, 40, 45, 60, 55), MEAN = c(50, 50.2, NA, NA, NA, NA),
                  SD = c(3, 3.1, NA, NA, NA, NA), stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  expect_true(isTRUE(v$FAIL))
  rows <- v$issues$row[v$issues$col == "TRIAL"]
  expect_true(length(rows) > 0)
  expect_true(all(rows <= nrow(v$DATA)))                     # 5 and 6 pointed past the frame
  blank <- which(is.na(v$DATA$TRIAL) | !nzchar(trimws(as.character(v$DATA$TRIAL))))
  expect_setequal(rows, blank)                               # exactly the blank cells, no others
  expect_equal(nrow(v$DATA), 4L)
})
