# Adjudication of security screen 2026-09-10-1822 (over 45865b0..7c377dc),
# findings F1 and F2 (both HIGH, availability): the journal-style reader's
# bounds counted its OUTPUT, not its work. Every arm cell of every row went
# through the tokenizer (about 1.3 ms a cell) whether or not the row became
# a line, so 200 rows of bare "1" cells under 499 arm headers (207 KB) cost
# 134 s and counted zero lines; and one cell of 40,000 tokens cost 37 s (a
# cap-sized cell, hours).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (a per-file budget of
# cells classified, .iaMaxWideCells, carried across blocks in the totals
# environment and checked before each block by rows x arms and inside the
# loop; a cell longer than .ppMaxCellChars refuses the file before it is
# tokenised). Reproduced through the path the screen names - the CSVs
# through .apiReadUpload(), timed - and checked to FAIL on 7c377dc by
# timing (8 s for the 10,000-token cell, 134 s for the bare cells; both
# admitted there).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

bigCellCsv <- function(T) {
  f <- tempfile(fileext = ".csv")
  writeLines(c("Variable,Arm A (n=10),Arm B (n=10)",
               paste0('"Age, mean (SD)","', paste(rep("1", T), collapse = " "), '","50.3 (10.1)"')), f)
  f
}
bareCellsCsv <- function(R, A) {
  f <- tempfile(fileext = ".csv")
  hdr <- paste(c("Variable", sprintf("Arm %d (n=10)", seq_len(A))), collapse = ",")
  writeLines(c(hdr, rep(paste(c("X", rep("1", A)), collapse = ","), R)), f)
  f
}
timed <- function(expr) { el <- system.time(r <- expr)[["elapsed"]]; list(r = r, s = el) }

test_that("one oversized cell is refused before the tokenizer sees it (screen 1822 F1)", {
  t <- timed(.apiReadUpload(bigCellCsv(10000L), "cell.csv"))
  expect_lt(t$s, 5)                                       # 8.1 s on 7c377dc, and admitted
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "characters", fixed = TRUE)
  expect_match(t$r$reasons, as.character(.ppMaxCellChars), fixed = TRUE)
  expect_error(parseWideTable(bigCellCsv(10000L), "csv"), class = "iaWideTooLarge")
})

test_that("rows whose cells parse to nothing are bounded by the cell budget, up front (screen 1822 F2)", {
  t <- timed(.apiReadUpload(bareCellsCsv(200L, 499L), "bare.csv"))
  expect_lt(t$s, 5)                                       # 133.6 s on 7c377dc, and counted zero lines
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "cells to read", fixed = TRUE)
  expect_match(t$r$reasons, as.character(.iaMaxWideCells), fixed = TRUE)
})

test_that("the cell budget is spent across blocks, and a block that yields nothing still counts", {
  # two "Trial:" blocks of 60 rows x 499 bare arm cells: 29,940 cells each,
  # the first within the budget (and yielding no line), the second past it
  f <- tempfile(fileext = ".csv")
  hdr <- paste(c("Variable", sprintf("Arm %d (n=10)", seq_len(499L))), collapse = ",")
  row <- paste(c("X", rep("1", 499L)), collapse = ",")
  writeLines(c(paste(c("Trial: T1", rep("", 499L)), collapse = ","), hdr, rep(row, 60L),
               paste(c("Trial: T2", rep("", 499L)), collapse = ","), hdr, rep(row, 60L)), f)
  t <- timed(tryCatch(parseWideTable(f, "csv"), iaWideTooLarge = function(e) e))
  expect_s3_class(t$r, "iaWideTooLarge")
  expect_match(conditionMessage(t$r), "cells to read", fixed = TRUE)
  expect_lt(t$s, 120)                                     # the first block is tokenised (about 40 s here)
})

test_that("a table within the budget still reads, and a cell at the limit is not refused", {
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  f <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, f)
  r <- .apiReadUpload(f, "two.xlsx")
  expect_true(isTRUE(r$ok)); expect_identical(nrow(r$data), nrow(two))
  # a cell of exactly .ppMaxCellChars characters is read (and skipped as unrecognised, not refused)
  g <- tempfile(fileext = ".csv")
  writeLines(c("Variable,Arm A (n=10),Arm B (n=10)",
               paste0('"Age, mean (SD)","', strrep("1 ", .ppMaxCellChars / 2), '","50.3 (10.1)"'),
               '"Height, mean (SD)","165 (7)","167 (7)"'), g)
  b <- parseWideTable(g, "csv")
  expect_false(is.null(b))
  expect_true("Height" %in% b[[1]]$data$ROW)
})
