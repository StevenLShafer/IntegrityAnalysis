# Adjudication of the 2026-09-10 independent statistical audit, finding F3
# (docs/audits/2026-09-10-independent-statistical-audit-chatgpt.md).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix across R/validateData.R (the rows left out
# are returned beside the analysed frame), R/P_Calc.R (they are counted
# on the Summary line and listed), R/apiService.R (they go back in the
# template and the journal table) and R/baselineTable.R. Per the
# standing rule in AGENTS.md the defect is reproduced THROUGH THE PATH
# THE REPORT NAMES: the audit's own JATS and Word fixtures, through the
# document parsers into the API's analysis route, and through the actual
# /analyze handler of inst/api/plumber.R including the XML parse
# subprocess. Testing reviewFlags() alone would miss it, as the report
# says. Checked to FAIL on 42bb219: blank Summary NOTE, no ASA row.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

# The audit's fixture (evidence-2026-09-10/flags.xml and flags.docx):
# four variables, 1,200 per arm; ASA 33/33/34% permits too many
# reconstructions and is declined; NYHA 33.3/33.3/33.4% is reconstructed.
# Both blocks use the level names I/II/III.
fixtureRows <- list(c("N", "1200", "1200"), c("Age", "50.1 (10.0)", "50.2 (10.0)"),
                    c("ASA status, %", "", ""), c("I", "33", "33"), c("II", "33", "33"),
                    c("III", "34", "34"),
                    c("Weight", "70.1 (10.0)", "70.2 (10.0)"),
                    c("NYHA class, %", "", ""), c("I", "33.3", "33.3"),
                    c("II", "33.3", "33.3"), c("III", "33.4", "33.4"))
fixtureHeader <- c("Characteristic", "Control", "Treatment")
fixtureFoot <- "Values are mean (SD) or percentages."
jatsFixture <- function() {
  f <- file.path(tempdir(), "audit-f3-flags.xml")
  makeJatsArticle(f, list(list(caption = "Baseline characteristics",
                               rows = c(list(fixtureHeader), fixtureRows),
                               foot = fixtureFoot)))
  f
}
docxFixture <- function() {
  f <- file.path(tempdir(), "audit-f3-flags.docx")
  makeTableDocx(f, fixtureHeader, do.call(rbind, fixtureRows),
                caption = "Table 1. Baseline characteristics", footnote = fixtureFoot)
  f
}
summaryRow <- function(res) res[!is.na(res$KIND) & res$KIND == "summary", , drop = FALSE]
asaRow <- function(res) res[!is.na(res$ROW) & res$ROW == "ASA status, %", , drop = FALSE]

checkAnalysis <- function(a) {
  expect_true(isTRUE(a$ok))
  res <- a$results
  # the coverage line the method document promises
  expect_match(as.character(summaryRow(res)$NOTE[1]), "^3 of 4 rows analysed")
  # the declined block is listed, not analysed, with the reason
  asa <- asaRow(res)
  expect_equal(nrow(asa), 1L)
  expect_equal(as.character(asa$P), "Not analysed")
  expect_equal(as.character(asa$KIND), "variable")
  expect_match(as.character(asa$NOTE), "no values in any cell")
  # the three analysed rows are what they were: Age, Weight, NYHA
  expect_equal(sum(!is.na(res$KIND) & res$KIND == "variable"), 4L)
  expect_equal(sum(res$P %in% c("Not analysed")), 1L)
  # the row stays in the round-trip template and the journal table
  tpl <- utils::read.csv(text = a$templateCsv, check.names = FALSE, stringsAsFactors = FALSE)
  expect_true(any(tpl$ROW == "ASA status, %"))
  expect_equal(sum(tpl$ROW == "ASA status, %"), 2L)      # both arms' lines
  expect_true(any(grepl("ASA status", a$journalTables[[1]], fixed = TRUE)))
  invisible(res)
}

test_that("a category block left blank by the parser is counted on the Summary line (audit 2026-09-10 F3, JATS)", {
  r <- parseBaselineTableJats(jatsFixture(), trial = "Audit", quiet = TRUE, pctApprox = TRUE)
  expect_true(any(r$data$ROW == "ASA status, %"))
  expect_true(length(r$approxUnresolved) > 0)             # the seam already repaired
  a <- shiny::isolate(.apiAnalyze(r$data, seed = 42))
  checkAnalysis(a)
})

test_that("...and through Word", {
  r <- parseBaselineTableDocx(docxFixture(), trial = "Audit", quiet = TRUE, pctApprox = TRUE)
  expect_true(any(r$data$ROW == "ASA status, %"))
  a <- shiny::isolate(.apiAnalyze(r$data, seed = 42))
  checkAnalysis(a)
})

test_that("...and through the actual /analyze handler with the XML parse subprocess", {
  # the installed package under R CMD check has api/plumber.R; a source
  # checkout under load_all resolves the same path through inst/
  plumberFile <- system.file("api", "plumber.R", package = "IntegrityAnalysis")
  if (!nzchar(plumberFile)) plumberFile <- test_path("..", "..", "inst", "api", "plumber.R")
  ast <- parse(plumberFile, keep.source = FALSE)
  funs <- lapply(Filter(function(x) is.call(x) && identical(x[[1]], as.name("function")),
                        as.list(ast)), eval)
  upload <- Filter(function(f) "file" %in% names(formals(f)), funs)
  analyzeHandler <- upload[[2]]
  path <- jatsFixture()
  part <- stats::setNames(list(readBin(path, "raw", n = file.info(path)$size)), basename(path))
  a <- analyzeHandler(new.env(), new.env(), part, seed = 42)
  expect_true(isTRUE(a$ok))
  res <- utils::read.csv(text = a$resultsCsv, stringsAsFactors = FALSE)
  expect_match(as.character(summaryRow(res)$NOTE[1]), "^3 of 4 rows analysed")
  expect_equal(as.character(asaRow(res)$P), "Not analysed")
  tpl <- utils::read.csv(text = a$templateCsv, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(sum(tpl$ROW == "ASA status, %"), 2L)
})

test_that("the validator returns what it left out, and the engine lists it once", {
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Blank", "Blank"),
                  N = c(30, 30, NA, NA), MEAN = c(5.1, 5.2, NA, NA), SD = c(1, 1, NA, NA),
                  ROUND_MEAN = c(1, 1, NA, NA), ROUND_DISPERSION = c(0, 0, NA, NA),
                  ROUND_OBSERVATION = c(1, 1, NA, NA), stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  expect_false(isTRUE(v$FAIL))
  expect_equal(nrow(v$DATA), 2L)
  expect_equal(nrow(v$Excluded), 2L)
  expect_equal(names(v$Excluded), c("TRIAL", "ROW", "REASON"))
  expect_equal(unique(v$Excluded$REASON), "label only")
  # the rows themselves come back untouched, every column as uploaded
  expect_equal(nrow(v$ExcludedRows), 2L)
  expect_true(all(c("N", "MEAN", "SD") %in% names(v$ExcludedRows)))
  expect_false("REASON" %in% names(v$ExcludedRows))
  expect_equal(nrow(.iaWithExcluded(v$DATA, v$ExcludedRows)), 4L)
  # the excluded rows change the count and the listing, never the p
  # (CodeRabbit on #250)
  set.seed(42); dqrng::dqset.seed(42)
  baseline <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  set.seed(42); dqrng::dqset.seed(42)
  x <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000, excluded = v$Excluded))
  expect_equal(as.character(summaryRow(x)$P), as.character(summaryRow(baseline)$P))
  expect_equal(sum(x$ROW %in% "Blank"), 1L)
  expect_match(as.character(summaryRow(x)$NOTE[1]), "^1 of 2 rows analysed")
  # and nothing to count when nothing was left out
  v2 <- shiny::isolate(validateData(d[1:2, ]))
  expect_null(v2$Excluded)
  expect_null(v2$ExcludedRows)
  # an uploaded column called REASON is the caller's, and survives
  d3 <- d; d3$REASON <- c("a", "b", "c", "d")
  v3 <- shiny::isolate(validateData(d3))
  expect_equal(v3$ExcludedRows$REASON, c("c", "d"))
  expect_equal(v3$Excluded$REASON, c("label only", "label only"))
  set.seed(42); dqrng::dqset.seed(42)
  x2 <- shiny::isolate(P_Calc("T", v2$DATA, v2$CategoryNames, 1000, excluded = v2$Excluded))
  expect_equal(as.character(summaryRow(x2)$NOTE[1]), "")
})
