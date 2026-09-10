# A structural validation failure carries an `issues` entry (the second
# half of the 2026-09-10 independent audit's F4; Steve's decision on the
# API contract, 2026-09-10).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the change in R/validateData.R (one "structural" issue
# per problem, row NA, col the column concerned), R/app_server.R (the
# grid's painter skips rows that are NA) and docs/api-users-guide.md.
# Reproduced THROUGH THE PATH THE REPORT NAMES - the actual /analyze
# handler of inst/api/plumber.R handed a raw file part - and checked to
# FAIL on 4b6983f, where the issues array came back empty.
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

test_that("two columns that normalise to one name arrive as a structural issue naming the name", {
  f <- writeCsv(c('"TRIAL","trial","ROW","N","MEAN","SD","ROUND_MEAN","ROUND_OBSERVATION","ROUND_DISPERSION"',
                  '"A","A","X",100,"50.0","3.0",1,0,1', '"A","A","X",100,"50.2","3.1",1,0,1'),
                "duplicate-trial.csv")
  a <- request(f)
  expect_false(isTRUE(a$ok))
  expect_equal(a$stage, "validation")
  iss <- issuesOf(a)
  expect_true(nrow(iss) >= 1L)
  s <- iss[iss$code == "structural", , drop = FALSE]
  expect_equal(nrow(s), 1L)
  expect_true(is.na(s$row))
  expect_equal(s$col, "TRIAL")
  expect_match(s$note, "two columns normalize to the same name")
  # the API normalises names before validation, so through this route the
  # note names the collapsed spelling twice; the app's route, which hands
  # the validator the raw header, names both originals (pre-existing)
  expect_match(s$note, "'TRIAL'")
  expect_match(a$templateCsv, "TRIAL")          # the table as read still comes back
})

test_that("a missing required column arrives as a structural issue naming the column", {
  f <- writeCsv(c('"TRIAL","ROW","MEAN","SD"', '"A","X","50.0","3.0"', '"A","X","50.2","3.1"'),
                "no-n.csv")
  a <- request(f)
  expect_false(isTRUE(a$ok))
  expect_equal(a$stage, "validation")
  s <- issuesOf(a); s <- s[s$code == "structural", , drop = FALSE]
  expect_true("N" %in% s$col)
  expect_true(all(is.na(s$row)))
  expect_match(s$note[s$col == "N"], "missing column labeled N")
})

test_that("the validator files one structural issue per problem, and none on a sound table", {
  d <- data.frame(TRIAL = "A", ROW = "X", MEAN = c(50, 50.2), SD = c(3, 3.1),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 1)
  v <- shiny::isolate(validateData(d))                 # no N
  expect_true(isTRUE(v$FAIL))
  expect_equal(v$issues$code, "structural")
  expect_equal(v$issues$col, "N")
  d$N <- 100
  v <- shiny::isolate(validateData(d))
  expect_false(isTRUE(v$FAIL))
  expect_true(is.null(v$issues) || !any(v$issues$code == "structural"))
})
