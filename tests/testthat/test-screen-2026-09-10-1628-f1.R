# Adjudication of security screen 2026-09-10-1628 (over 68f1ed5..84051f3),
# finding F1 (HIGH, availability): the journal-style spreadsheet reader
# built an unbounded frame - category columns named from every count row,
# lines the width of every column, blocks folded pairwise - and every gate
# on the way in passed, because they measure bytes, sheets and rows, not
# what the reader makes of them.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (the API's own bounds -
# .iaMaxLevelColumns category columns, .iaMaxWideLines template lines -
# checked as the rows are classified and across a file's blocks, a table
# past them refused by a classed condition before a line is built),
# R/apiService.R and R/app_server.R (the refusal carried to the caller
# with its reason), R/utils.R (.ppRbindFillAll: one rbind on the union)
# and inst/api/plumber.R (/parse applies the rows/columns gate /analyze
# has). Reproduced through the path the screen names - the workbooks
# through parseWideTable() and .apiReadUpload(), timed - and checked to
# FAIL on 84051f3: one block of 1,000 distinct "n (%)" rows took 237 s
# there (a 2,000 x 2,009 frame); 300 blocks took 6.4 s and 3,333 blocks
# were not attempted (the fold is cubic in the blocks).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

rawXlsx <- function(m) {
  f <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook(); openxlsx::addWorksheet(wb, "Sheet1")
  openxlsx::writeData(wb, "Sheet1", as.data.frame(m, stringsAsFactors = FALSE), colNames = FALSE)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  f
}
manyBlocks <- function(K) {
  m <- matrix("", nrow = 3L * K, ncol = 3L)
  for (k in seq_len(K)) {
    i <- 3L * (k - 1L)
    m[i + 1L, ] <- c(sprintf("Trial: T%d", k), "", "")
    m[i + 2L, ] <- c("Variable", "Arm A (n=10)", "Arm B (n=10)")
    m[i + 3L, ] <- c(sprintf("V%d, n (%%)", k), "5 (50%)", "5 (50%)")
  }
  rawXlsx(m)
}
oneBlock <- function(M)
  rawXlsx(rbind(c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
                cbind(sprintf("V%d, n (%%)", seq_len(M)), "5 (50%)", "5 (50%)")))

test_that("one block of 1,000 distinct count rows is refused before a line is built, with the reason (screen 1628 F1)", {
  f <- oneBlock(1000L)
  expect_lt(file.size(f), 40000)                          # a 23 KB file
  el <- system.time(r <- .apiReadUpload(f, "one.xlsx"))[["elapsed"]]
  expect_lt(el, 10)                                       # 237 s on 84051f3
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "category columns", fixed = TRUE)
  expect_match(r$reasons, as.character(.iaMaxLevelColumns), fixed = TRUE)
  expect_error(parseWideTable(f, "xlsx"), class = "iaWideTooLarge")
})

test_that("3,333 one-row trial blocks in one sheet are refused in seconds, not folded", {
  f <- manyBlocks(3333L)
  el <- system.time(r <- .apiReadUpload(f, "many.xlsx"))[["elapsed"]]
  expect_lt(el, 10)
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "category columns", fixed = TRUE)
})

test_that("the line bound: blocks whose lines add up past the limit are refused, by count", {
  # 60 blocks of 100 continuous rows x 2 arms = 12,000 lines, no category column
  K <- 60L; R <- 100L
  m <- matrix("", nrow = K * (R + 2L), ncol = 3L)
  for (k in seq_len(K)) {
    i <- (k - 1L) * (R + 2L)
    m[i + 1L, ] <- c(sprintf("Trial: T%d", k), "", "")
    m[i + 2L, ] <- c("Variable", "Arm A (n=10)", "Arm B (n=10)")
    for (r in seq_len(R)) m[i + 2L + r, ] <- c(sprintf("X%d, mean (SD)", r), "50.1 (10.2)", "50.3 (10.1)")
  }
  f <- rawXlsx(m)
  el <- system.time(r <- .apiReadUpload(f, "lines.xlsx"))[["elapsed"]]
  expect_lt(el, 60)
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "template lines", fixed = TRUE)
  expect_match(r$reasons, as.character(.iaMaxWideLines), fixed = TRUE)
})

test_that("a table within the bounds still reads, blocks joined on the union in one rbind", {
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  f <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, f)
  r <- .apiReadUpload(f, "two.xlsx")
  expect_true(isTRUE(r$ok)); expect_identical(nrow(r$data), nrow(two))
  # .ppRbindFillAll is the fold, done once
  blocks <- parseWideTable(f, "xlsx")
  a <- .ppRbindFillAll(lapply(blocks, `[[`, "data"))
  b <- Reduce(.ppRbindFill, lapply(blocks, `[[`, "data"))
  expect_identical(a[, sort(names(a))], b[, sort(names(b))])
  # and a category block at the width limit is admitted: 100 binary rows = 200 columns
  m <- rbind(c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
             cbind(sprintf("V%d, n (%%)", seq_len(100L)), "5 (50%)", "5 (50%)"))
  ok <- .apiReadUpload(rawXlsx(m), "hundred.xlsx")
  expect_true(isTRUE(ok$ok))
  expect_identical(nrow(ok$data), 200L)
  expect_identical(length(setdiff(names(ok$data), c(.ppBaseColumns(), "Q1", "Q3"))), 200L)
})

test_that("the app's reader carries the refusal to the comments, not to the template reader", {
  # the same classed condition; the app catches it by class (app_server.R)
  f <- oneBlock(1000L)
  wide <- tryCatch(parseWideTable(f, "xlsx"), iaWideTooLarge = function(e) e, error = function(e) NULL)
  expect_s3_class(wide, "iaWideTooLarge")
  expect_match(conditionMessage(wide), "category columns", fixed = TRUE)
})
