# Adjudication of the 2026-09-10 FULL independent statistical audit,
# finding F2 (docs/audits/2026-09-10-full-independent-statistical-audit-chatgpt.md):
# a trial whose every row the validator left out vanished from the
# results - no variable, no Summary, no warning - while another trial in
# the same file analysed normally.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fixes in R/validateData.R (TRIALS lists every
# trial offered) and R/P_Calc.R (a trial with nothing to simulate is
# reported, not dropped). Per the standing rule in AGENTS.md the defect
# is reproduced THROUGH THE PATH THE REPORT NAMES - the audit's complete
# two-trial file through the upload reader and the API's analysis route
# (its own run was over HTTP; the handler tests below evaluate the same
# /analyze function on the same bytes) - and checked to FAIL on 0ba8598.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

# the audit's four-line fixture: trial A analysable, trial B two lines
# labelled "Unresolved category" with every analytical cell blank
fixture <- function() {
  d <- data.frame(TRIAL = c("A", "A", "B", "B"),
                  ROW = c("Age", "Age", "Unresolved category", "Unresolved category"),
                  N = c(30, 30, NA, NA), MEAN = c(50, 50.2, NA, NA), SD = c(10, 10, NA, NA),
                  ROUND_MEAN = c(1, 1, NA, NA), ROUND_OBSERVATION = c(0, 0, NA, NA),
                  ROUND_DISPERSION = c(0, 0, NA, NA), stringsAsFactors = FALSE)
  f <- file.path(tempdir(), "all-excluded-trial.csv")
  utils::write.csv(d, f, row.names = FALSE)
  f
}
analyzeHandler <- local({
  plumberFile <- system.file("api", "plumber.R", package = "IntegrityAnalysis")
  if (!nzchar(plumberFile)) plumberFile <- test_path("..", "..", "inst", "api", "plumber.R")
  ast <- parse(plumberFile, keep.source = FALSE)
  funs <- lapply(Filter(function(x) is.call(x) && identical(x[[1]], as.name("function")),
                        as.list(ast)), eval)
  upload <- Filter(function(f) "file" %in% names(formals(f)), funs)
  upload[[2]]
})

test_that("a trial whose every row was left out is reported, not dropped (audit 2026-09-10 full, F2)", {
  f <- fixture()
  rd <- .apiReadUpload(f, "all-excluded-trial.csv")
  v <- shiny::isolate(validateData(rd$data))
  expect_false(isTRUE(v$FAIL))
  expect_equal(v$TRIALS, c("A", "B"))                    # B is offered, so B is listed
  expect_equal(nrow(v$DATA), 2L)                         # ...but nothing of B is simulated
  a <- shiny::isolate(.apiAnalyze(rd$data, seed = 42))
  expect_true(isTRUE(a$ok))
  res <- a$results
  # B's variable is listed, not analysed, with the reason; B has its own
  # Summary line saying so
  bVar <- res[!is.na(res$ROW) & res$ROW == "Unresolved category", , drop = FALSE]
  expect_equal(nrow(bVar), 1L)
  expect_equal(as.character(bVar$P), "Not analysed")
  expect_equal(as.character(bVar$TRIAL), "B")
  sums <- res[!is.na(res$KIND) & res$KIND == "summary", , drop = FALSE]
  expect_equal(nrow(sums), 2L)
  expect_equal(as.character(sums$P[2]), "No values")
  expect_match(as.character(sums$NOTE[2]), "^0 of 1 rows analysed")
  # A is what it was: the same seed gives the same p as A alone
  aAlone <- shiny::isolate(.apiAnalyze(rd$data[rd$data$TRIAL == "A", ], seed = 42))
  expect_equal(as.character(sums$P[1]), as.character(aAlone$results$P[aAlone$results$KIND %in% "summary"][1]))
  expect_equal(a$trials, 2L)
  # and the overall p is A's alone - B contributes nothing
  expect_equal(a$overallP, aAlone$overallP)
})

test_that("...and through the actual /analyze handler", {
  f <- fixture()
  part <- stats::setNames(list(readBin(f, "raw", n = file.info(f)$size)), basename(f))
  a <- analyzeHandler(new.env(), new.env(), part, seed = 42)
  expect_true(isTRUE(a$ok))
  res <- utils::read.csv(text = a$resultsCsv, stringsAsFactors = FALSE)
  expect_true(any(res$ROW == "Unresolved category" & res$P == "Not analysed"))
  expect_true(any(grepl("^0 of 1 rows analysed", res$NOTE)))
  expect_equal(a$trials, 2L)
})

test_that("the engine alone: a trial with no analysable rows yields the excluded lines and a No values Summary", {
  d <- data.frame(TRIAL = "B", ROW = c("Only label", "Only label"), N = NA_real_, MEAN = NA_real_,
                  SD = NA_real_, ROUND_MEAN = NA_real_, ROUND_OBSERVATION = NA_real_,
                  ROUND_DISPERSION = NA_real_, stringsAsFactors = FALSE)
  ex <- data.frame(TRIAL = "B", ROW = "Only label", REASON = "label only", stringsAsFactors = FALSE)
  set.seed(42); dqrng::dqset.seed(42)
  x <- shiny::isolate(P_Calc("B", d[0, ], NULL, 1000, excluded = ex))
  expect_equal(as.character(x$TRIAL[1]), "B")
  expect_equal(as.character(x$P[1]), "Not analysed")
  s <- x[!is.na(x$KIND) & x$KIND == "summary", , drop = FALSE]
  expect_equal(as.character(s$P), "No values")
  expect_match(as.character(s$NOTE), "^0 of 1 rows analysed")
})
