# Adjudication of security screen 2026-09-10-1856 (over 7c377dc..1810272),
# finding F1 (HIGH, availability): the cell budget and the cell-length cap
# of the 1822 fix multiplied - a 2,000-character cell of "1 1 1 ..." is a
# thousand tokens, the tokenizer built a data frame for every one (0.84 s
# a cell) and the wide reader kept only the first; 49,900 such cells fit
# every bound and were eleven hours.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/tokenize.R (.ppTokenizeLine(first = TRUE):
# one regexpr() match, the first token only) and R/parseWideTable.R
# (classify() asks for the first token; the wide reader's own cell cap,
# .iaMaxWideCellChars = 200, an order of magnitude under the JATS one).
# Reproduced through the path the screen names - the CSV through
# .apiReadUpload(), timed - and checked to FAIL on 1810272 by timing
# (20 x 20 cells of 100 tokens: about 34 s there, admitted).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

tokenCellsCsv <- function(R, A, T) {
  f <- tempfile(fileext = ".csv")
  hdr <- paste(c("Variable", sprintf("Arm %d (n=10)", seq_len(A))), collapse = ",")
  cell <- paste(rep("1", T), collapse = " ")
  writeLines(c(hdr, rep(paste(c("X", rep(paste0('"', cell, '"'), A)), collapse = ","), R)), f)
  f
}
timed <- function(expr) { el <- system.time(r <- expr)[["elapsed"]]; list(r = r, s = el) }

test_that("400 cells of 100 tokens each cost one scan a cell, not a data frame a token (screen 1856 F1)", {
  # 199 characters a cell: under the new cap, so the tokenizer does see them
  t <- timed(.apiReadUpload(tokenCellsCsv(20L, 20L, 100L), "tokens.csv"))
  expect_lt(t$s, 5)                                       # about 34 s on 1810272
  expect_true(isTRUE(t$r$ok))                             # bare numbers: the template reader takes it, as before
})

test_that("a cell of a thousand tokens is refused by the wide reader's own cap, before the tokenizer", {
  t <- timed(.apiReadUpload(tokenCellsCsv(5L, 10L, 1000L), "tokens.csv"))
  expect_lt(t$s, 5)                                       # 0.84 s a cell x 50 on 1810272
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "characters", fixed = TRUE)
  expect_match(t$r$reasons, as.character(.iaMaxWideCellChars), fixed = TRUE)
  expect_lt(.iaMaxWideCellChars, .ppMaxCellChars)         # tighter than the JATS/Word cap
})

test_that("the first token from one match is the first token of the full tokenization", {
  lines <- c("45.3 (12.1)", "127 [98, 160]", "12 (40%)", "5/20", "50.1 (10.2) 33 (11)",
             "1 1 1 1 1 1 1 1", "abc", "")
  for (txt in lines) {
    line <- data.frame(text = txt, x = 0, width = nchar(txt), stringsAsFactors = FALSE)
    full <- .ppTokenizeLine(line)
    one  <- .ppTokenizeLine(line, first = TRUE)
    expect_identical(nrow(one), min(nrow(full), 1L), info = txt)
    if (nrow(full) > 0) expect_identical(one, full[1, , drop = FALSE], info = txt)
  }
})

test_that("a real journal-style table still reads exactly as before", {
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  f <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, f)
  r <- .apiReadUpload(f, "two.xlsx")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_identical(nrow(r$data), nrow(two))
})
