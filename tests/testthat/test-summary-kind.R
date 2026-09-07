# The structural KIND column (2026-09-07; finding F2 of the GPT-6 audit in
# docs/audits/): the trial's summary line is identified by KIND, never by
# the text "Summary" in ROW, so a variable the paper happened to call
# "Summary" cannot enter the across-trial combination as another trial or
# appear as a second study on the workbook's Summary sheet.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
options(ECHO_OUTPUT_COMMENTS = NA)
mk <- function(lab) data.frame(TRIAL = "T", ROW = lab, N = 6, MEAN = c(77, 78), SD = c(30, 30),
                               ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)

test_that("P_Calc returns KIND: variable lines, one summary, a blank spacer", {
  dqrng::dqset.seed(1); set.seed(1)
  x <- suppressWarnings(shiny::isolate(P_Calc("T", mk("Summary"), NULL, 1000)))
  expect_identical(names(x), c("TRIAL", "ROW", "P", "CI95", "M", "NOTE", "KIND"))
  expect_identical(x$KIND, c("variable", "summary", NA))
  expect_identical(x$ROW[1:2], c("Summary", "Summary"))   # the label collides; the kind does not
})

test_that("renaming a variable to Summary changes no API result and no count of combined trials", {
  a <- .apiAnalyze(mk("X"), seed = 42)
  b <- .apiAnalyze(mk("Summary"), seed = 42)
  expect_true(a$ok && b$ok)
  expect_identical(a$overallP, b$overallP)        # was 0.0462 vs 0.008658 before the fix
  expect_identical(a$trials, b$trials)
  # the results frame carries the column (the CSV is written from it by the
  # route), so a client can tell the lines apart too
  expect_identical(b$results$KIND, c("variable", "summary", NA))
  expect_match(.apiResultsCsv(b$results), "\"KIND\"")
})

test_that("the workbook's Summary sheet lists one study, whatever the variables are called", {
  dqrng::dqset.seed(3); set.seed(3)
  d <- mk("Summary")
  v <- shiny::isolate(validateData(d))
  out <- suppressWarnings(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000)))
  f <- tempfile(fileext = ".xlsx")
  writeResultsWorkbook(out, v$DATA, v$CategoryNames, f)
  s <- openxlsx::read.xlsx(f, sheet = "Summary")
  expect_equal(nrow(s), 1)                        # one trial, no across-trial row
  expect_identical(s$TRIAL[1], "T")
  # the Test Results sheet keeps its six printed columns
  tr <- openxlsx::read.xlsx(f, sheet = "Test Results")
  expect_equal(ncol(tr), 6)
})
