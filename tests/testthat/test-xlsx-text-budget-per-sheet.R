# test-xlsx-text-budget-per-sheet.R - a modest multi-sheet workbook passes
# the cell-text preflight, and a refused archive is told which gate refused
# it (ISSUES.md issue 164, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's report of John Loadsman's six-sheet workbook (288 KB   #
# on disk, 1.84 MB inflated) refused as a decompression bomb.              #
############################################################################
suppressPackageStartupMessages(library(openxlsx))

# six sheets, three of them of a realistic size: 1,500 rows x 12 numeric
# columns each, so the worksheet MARKUP alone is well over the old
# per-sheet share of the budget (8 MiB / 6) while the shared strings are a
# few KB - the shape of a real multi-trial workbook
sixSheetXlsx <- function() {
  wb <- createWorkbook()
  for (k in 1:6) {
    addWorksheet(wb, paste0("Trial", k))
    n <- if (k <= 3) 1500L else 20L
    d <- as.data.frame(matrix(round(runif(n * 12) * 100, 2), n, 12))
    d$ROW <- paste0("Variable ", seq_len(n))
    writeData(wb, k, d)
  }
  f <- tempfile("sixsheet", fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE); f
}

test_that("a modest six-sheet workbook is not refused by the cell-text preflight", {
  g <- sixSheetXlsx()
  info <- utils::unzip(g, list = TRUE)
  expect_identical(.apiXlsxSheetCount(g), 6L)
  # the shape that was refused: the markup over all parts is past the old
  # per-sheet share (the aggregate budget divided by six) ...
  lt <- as.raw(0x3c)
  nonLt <- sum(vapply(info$Name[grepl("xml$", info$Name)], function(nm) {
    con <- unz(g, nm, open = "rb"); b <- readBin(con, "raw", n = 5e7); close(con); sum(b != lt)
  }, numeric(1)))
  expect_gt(nonLt, .iaMaxXlsxStringBytes %/% 6L)
  expect_lt(nonLt, .iaMaxXlsxStringBytes)
  # ... and the workbook passes, because that share applies to the shared
  # strings alone
  expect_true(.apiXlsxStringRunOK(g, info$Name))
  expect_null(.apiXlsxStringRunOK(g, info$Name, why = TRUE))
  expect_true(.apiZipInflationOK(g, "xlsx"))
  expect_null(.apiZipInflationOK(g, "xlsx", why = TRUE))
})

test_that("a refused archive names the gate that refused it", {
  # not a zip at all
  notZip <- tempfile(fileext = ".xlsx"); writeLines("TRIAL,ROW", notZip)
  expect_match(.apiZipInflationOK(notZip, "xlsx", why = TRUE), "not a readable .xlsx archive", fixed = TRUE)
  r <- .apiReadUpload(notZip, "table.xlsx")
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "table.xlsx was not read: it is not a readable .xlsx archive.", fixed = TRUE)
  # the declared size, under a lowered cap
  ex <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  expect_null(.apiZipInflationOK(ex, "xlsx", why = TRUE))
  local_mocked_bindings(.apiMaxUncompressed = 1)
  expect_match(.apiZipInflationOK(ex, "xlsx", why = TRUE), "expands to more than the 0 MB limit", fixed = TRUE)
})

test_that("shared strings past the per-sheet budget are refused with that reason (screens 1655 and 1730 still hold)", {
  # ten sheets whose shared strings fill most of the whole-file budget:
  # ~7 MB of distinct text, read once per sheet
  wb <- createWorkbook(); k <- 0L
  for (sh in 1:10) {
    addWorksheet(wb, paste0("S", sh))
    ids <- vapply(1:90, function(i) { k <<- k + 1L; paste0(strrep("é", 4000L), k) }, character(1))
    writeData(wb, sh, data.frame(ROW = ids, stringsAsFactors = FALSE), colNames = FALSE)
  }
  g <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, g, overwrite = TRUE)
  info <- utils::unzip(g, list = TRUE)
  expect_false(.apiXlsxStringRunOK(g, info$Name))
  why <- .apiXlsxStringRunOK(g, info$Name, why = TRUE)
  expect_match(why, "its shared strings (over ", fixed = TRUE)
  expect_match(why, "each of its 10 sheets", fixed = TRUE)
  r <- .apiReadUpload(g, "tensheet.xlsx")
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "tensheet.xlsx was not read: its shared strings", fixed = TRUE)
})
