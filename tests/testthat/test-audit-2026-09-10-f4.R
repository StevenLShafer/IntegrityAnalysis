# Adjudication of the 2026-09-10 independent statistical audit, finding F4
# (docs/audits/2026-09-10-independent-statistical-audit-chatgpt.md).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/apiService.R and R/app_globals.R
# (.iaTrialColumn(): the trial column by the normaliser's own rule). Per
# the standing rule in AGENTS.md the defect is reproduced THROUGH THE
# PATH THE REPORT NAMES - the actual /parse and /analyze handler
# functions of inst/api/plumber.R, evaluated from their source and
# handed a raw file part, exactly as the audit's followup.R did - and
# not only through the CSV reader. Checked to FAIL on d765e66: /parse
# returned a template with both `TRIAL` and `trial`, and both /analyze
# routes failed validation.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

# the audit's fixture, byte for byte (evidence-2026-09-10/precision-lowercase.csv)
lowerCsv <- c('"trial","row","n","mean","sd","round_mean","round_observation","round_dispersion"',
              '"Audit","X",100,"50.000","3.00",,0,',
              '"Audit","X",100,"50.000","3.00",2,0,1')
upperCsv <- c('"TRIAL","ROW","N","MEAN","SD","ROUND_MEAN","ROUND_OBSERVATION","ROUND_DISPERSION"',
              lowerCsv[-1])
writeCsv <- function(lines, name) {
  f <- file.path(tempdir(), name); writeLines(lines, f); f
}

# the endpoint functions, from the audited file, without HTTP transport,
# authentication or multipart decoding (the audit's own harness)
handlers <- local({
  # the installed package under R CMD check has api/plumber.R; a source
  # checkout under load_all resolves the same path through inst/
  plumberFile <- system.file("api", "plumber.R", package = "IntegrityAnalysis")
  if (!nzchar(plumberFile)) plumberFile <- test_path("..", "..", "inst", "api", "plumber.R")
  ast <- parse(plumberFile, keep.source = FALSE)
  funs <- lapply(Filter(function(x) is.call(x) && identical(x[[1]], as.name("function")),
                        as.list(ast)), eval)
  upload <- Filter(function(f) "file" %in% names(formals(f)), funs)
  stopifnot(length(upload) == 2L)
  list(parse = upload[[1]], analyze = upload[[2]])
})
request <- function(f, path, seed = NULL) {
  req <- new.env(); res <- new.env()
  part <- stats::setNames(list(readBin(path, "raw", n = file.info(path)$size)), basename(path))
  if (is.null(seed)) f(req, res, part) else f(req, res, part, seed = seed)
}
trialCols <- function(csvText) {
  d <- utils::read.csv(text = csvText, check.names = FALSE, stringsAsFactors = FALSE)
  names(d)[grepl("TRIAL", toupper(trimws(names(d))))]
}
summaryP <- function(a) {
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", , drop = FALSE]
  suppressWarnings(as.numeric(as.character(s$P[1])))
}

test_that("the reader recognises a trial column of any case, by the normaliser's rule", {
  expect_equal(.iaTrialColumn(data.frame(trial = 1, x = 2)), "trial")
  expect_equal(.iaTrialColumn(data.frame(" Trial id " = 1, check.names = FALSE)), " Trial id ")
  expect_true(is.na(.iaTrialColumn(data.frame(x = 1))))
  expect_true(is.na(.iaTrialColumn(NULL)))
  rd <- .apiReadUpload(writeCsv(lowerCsv, "lower-reader.csv"), "lower-reader.csv")
  expect_true(isTRUE(rd$ok))
  expect_equal(sum(grepl("TRIAL", toupper(names(rd$data)))), 1L)
  expect_equal(unique(rd$data[[.iaTrialColumn(rd$data)]]), "Audit")
})

test_that("a lowercase `trial` header survives /parse, /analyze and the round trip (audit 2026-09-10 F4)", {
  lower <- writeCsv(lowerCsv, "precision-lowercase.csv")
  upper <- writeCsv(upperCsv, "precision-uppercase.csv")

  # /parse: one trial column, the trial's own identity kept
  p <- request(handlers$parse, lower)
  expect_true(isTRUE(p$ok))
  expect_equal(length(trialCols(p$templateCsv)), 1L)
  tpl <- utils::read.csv(text = p$templateCsv, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(unique(tpl[[trialCols(p$templateCsv)]]), "Audit")

  # /analyze, direct: analysed, and the same numbers as the uppercase file
  # (the handler's success body carries overallP and resultsCsv)
  trialOf <- function(a) {
    r <- utils::read.csv(text = a$resultsCsv, stringsAsFactors = FALSE)
    as.character(r$TRIAL[1])
  }
  a <- request(handlers$analyze, lower, seed = 42)
  expect_true(isTRUE(a$ok))
  expect_null(a$stage)
  u <- request(handlers$analyze, upper, seed = 42)
  expect_true(isTRUE(u$ok))
  expect_true(is.numeric(u$overallP) && u$overallP > 0)
  expect_equal(a$overallP, u$overallP)
  expect_equal(trialOf(a), "Audit")

  # /parse -> templateCsv -> /analyze: the round trip the contract promises
  rt <- writeCsv(strsplit(p$templateCsv, "\n", fixed = TRUE)[[1]], "roundtrip-lowercase.csv")
  b <- request(handlers$analyze, rt, seed = 42)
  expect_true(isTRUE(b$ok))
  expect_equal(b$overallP, u$overallP)
  expect_equal(trialOf(b), "Audit")
})
