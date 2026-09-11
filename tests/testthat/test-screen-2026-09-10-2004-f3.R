# Adjudication of security screen 2026-09-10-2004 (over 1810272..67a03ab),
# finding F3 (LOW): the wide reader capped its arm cells but not the row
# label or the header cells, and the only thing bounding a label was R's
# 10,000-byte limit on a symbol name - a 10 KB label under 499 arms became
# 499 template lines of 10 KB (a 5 MB template from a 55 KB sheet), and a
# longer one an error the callers swallowed into the template fallback.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (the label column and the
# header cells are clipped to .ppMaxCellChars, the JATS and Word readers'
# cell cap, before anything reads them - a decision, not a side effect).
# Reproduced through the path the screen names - the sheet through
# .apiReadUpload() - and checked to FAIL on 28d7ee1 (499 lines of 10 KB
# there; the template 4.9 MB).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

longLabelCsv <- function(LKB, A = 499L) {
  f <- tempfile(fileext = ".csv")
  hdr <- paste(c("Variable", sprintf("Arm %d (n=10)", seq_len(A))), collapse = ",")
  row <- paste(c(paste0('"', strrep("L", LKB * 1000L), ', mean (SD)"'), rep('"50.1 (10.2)"', A)), collapse = ",")
  writeLines(c(hdr, row), f); f
}

test_that("a 10 KB label under 499 arms is clipped, not multiplied into a 5 MB template (screen 2004 F3)", {
  r <- .apiReadUpload(longLabelCsv(10L), "label.csv")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_identical(nrow(r$data), 499L)
  expect_lte(max(nchar(r$data$ROW, type = "bytes")), .ppMaxCellChars)   # 10,000 on 28d7ee1
  expect_lt(nchar(.apiTemplateCsv(r$data)), 1.2e6)                       # 4.9 MB on 28d7ee1
})

test_that("a label past R's symbol limit no longer errors into the template fallback", {
  # 12 KB: on 28d7ee1 the reader raised "variable names are limited to 10000 bytes",
  # the callers swallowed it and the template reader took the sheet
  r <- .apiReadUpload(longLabelCsv(12L, A = 3L), "label12.csv")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_identical(nrow(r$data), 3L)
})

test_that("an ordinary label and header are untouched, and a long header cell is clipped too", {
  f <- tempfile(fileext = ".csv")
  writeLines(c(paste0('"Variable","', strrep("H", 3000L), ' Arm A (n=10)","Arm B (n=10)"'),
               '"Body mass index, kg/m2, mean (SD)","24.1 (3.2)","24.3 (3.1)"'), f)
  r <- .apiReadUpload(f, "hdr.csv")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_identical(unique(r$data$ROW), "Body mass index, kg/m2")
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, g)
  r2 <- .apiReadUpload(g, "two.xlsx")
  expect_true(isTRUE(r2$ok)); expect_identical(nrow(r2$data), nrow(two))
})
