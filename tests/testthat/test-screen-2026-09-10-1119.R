# Adjudication of security screen 2026-09-10-1119 (over the range #247,
# #249 and #251 merged), finding F1: an all-blank `trial` column gave
# /analyze a 200 with no p-value.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fixes in R/apiService.R (the template reader fills
# a trial column that is present but blank in every cell, as the wide
# path already did) and R/validateData.R (a column blank in SOME cells is
# refused cell by cell). Per the standing rule in AGENTS.md the defect
# is reproduced THROUGH THE PATH THE REPORT NAMES - the actual /analyze
# handler of inst/api/plumber.R handed a raw file part - and checked to
# FAIL on 4b6983f (ok = TRUE, overallP null, every row "No values").
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
header <- '"trial","row","n","mean","sd","round_mean","round_observation","round_dispersion"'
rows <- c('"X",100,"50.0","3.0",1,0,1', '"X",100,"50.2","3.1",1,0,1',
          '"Y",100,"70.0","5.0",1,0,1', '"Y",100,"70.3","5.2",1,0,1')

test_that("a trial column blank in every cell is filled from the file name and analysed (screen 1119 F1)", {
  f <- writeCsv(c(header, paste0('"",', rows)), "blank-trial.csv")
  a <- request(f)
  expect_true(isTRUE(a$ok))
  expect_true(is.numeric(a$overallP) && is.finite(a$overallP) && a$overallP > 0)
  res <- utils::read.csv(text = a$resultsCsv, stringsAsFactors = FALSE)
  expect_equal(as.character(res$TRIAL[1]), "blank-trial")       # the file name, as documented
  expect_false(any(grepl("No values", res$P)))
  # the reader itself, the audit's F4 route
  rd <- .apiReadUpload(f, "blank-trial.csv")
  expect_equal(unique(rd$data[[.iaTrialColumn(rd$data)]]), "blank-trial")
})

test_that("a trial column blank in SOME cells is refused, cell by cell, never analysed", {
  f <- writeCsv(c(header, paste0(c('"A",', '"",', '"B",', '"B",'), rows)), "partly-blank-trial.csv")
  a <- request(f)
  expect_false(isTRUE(a$ok))
  expect_equal(a$stage, "validation")
  iss <- do.call(rbind, lapply(a$issues, as.data.frame, stringsAsFactors = FALSE))
  expect_true(any(iss$col == "TRIAL" & iss$code == "missing" & iss$row == 2L))
  expect_true(all(iss$row[iss$col == "TRIAL"] == 2L))
  expect_null(a$overallP)
})

test_that("the validator: all blank defaults like an absent column; some blank fails with the cells named", {
  d <- data.frame(TRIAL = c("", "", NA, ""), ROW = rep(c("X", "Y"), each = 2),
                  N = 100, MEAN = c(50, 50.2, 70, 70.3), SD = c(3, 3.1, 5, 5.2),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 1,
                  stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  expect_false(isTRUE(v$FAIL))
  expect_equal(v$TRIALS, 1)
  d$TRIAL <- c("A", "", "B", "B")
  v <- shiny::isolate(validateData(d))
  expect_true(isTRUE(v$FAIL))
  expect_true(!is.null(v$issues) && any(v$issues$col == "TRIAL" & v$issues$row == 2L))
  # the refusal returns the NORMALIZED frame the issues index (CodeRabbit
  # on #254): a lower-case `trial` header comes back as TRIAL, so the grid
  # paints the right column
  names(d)[names(d) == "TRIAL"] <- "trial"
  v <- shiny::isolate(validateData(d))
  expect_true(isTRUE(v$FAIL))
  expect_true(!is.null(v$DATA) && "TRIAL" %in% names(v$DATA))
  expect_false("trial" %in% names(v$DATA))
  expect_true(any(v$issues$col == "TRIAL" & v$issues$row == 2L))
})
