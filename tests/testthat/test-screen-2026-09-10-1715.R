# Adjudication of security screen 2026-09-10-1715 (over 84051f3..45865b0),
# findings F1 and F2 (both HIGH, availability): the bounds the 1628 fix put
# on the journal-style reader were reached at an unbounded cost - identical
# row labels made the row loop cubic (.ppUniqueName against a growing
# vector, the line bound only after the loop), and the cross-block
# accounting recounted every block at every block (quadratic).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (lines counted as each
# row joins outRows against the FILE's running total; row names through a
# hash set with a per-base hint; the file's totals carried into each block
# rather than recounted; a block with more rows past its header than the
# file has lines left refused before a row is tokenised). Reproduced
# through the path the screen names - the sheets through parseWideTable()
# and .apiReadUpload(), timed - and checked to FAIL on 45865b0 by timing:
# 4,000 identical rows 141 s (the screen) / measured again here; 3,333
# one-line blocks 209 s; 6,666 blocks over two sheets 554 s. After the
# fix the reader is linear, about 3 ms a row or a block: 9,999 identical
# rows 0.2 s, 4,000 rows 10 s, 3,333 blocks 18 s (admitted), 6,666
# blocks 26 s (refused). The bounds below leave room for a slower runner.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

identicalRowsCsv <- function(N) {
  f <- tempfile(fileext = ".csv")
  writeLines(c("Variable,Arm A (n=10),Arm B (n=10)",
               rep('"Age, mean (SD)","50.1 (10.2)","50.3 (10.1)"', N)), f)
  f
}
oneLineBlocksXlsx <- function(K, S) {
  f <- tempfile(fileext = ".xlsx"); wb <- openxlsx::createWorkbook()
  for (s in seq_len(S)) {
    m <- matrix("", nrow = 3L * K, ncol = 3L)
    for (k in seq_len(K)) {
      i <- 3L * (k - 1L)
      m[i + 1L, ] <- c(sprintf("Trial: T%d_%d", s, k), "", "")
      m[i + 2L, ] <- c("Variable", "Arm A (n=10)", "Arm B (n=10)")
      m[i + 3L, ] <- c(sprintf("X%d, mean (SD)", k), "50.1 (10.2)", "")
    }
    openxlsx::addWorksheet(wb, paste0("S", s))
    openxlsx::writeData(wb, paste0("S", s), as.data.frame(m, stringsAsFactors = FALSE), colNames = FALSE)
  }
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE); f
}
timed <- function(expr) {
  el <- system.time(r <- expr)[["elapsed"]]
  list(r = r, s = el)
}

test_that("a sheet of identical labels at the row cap is refused before a row is tokenised (screen 1715 F1)", {
  f <- identicalRowsCsv(9999L)
  t <- timed(.apiReadUpload(f, "same.csv"))
  expect_lt(t$s, 5)                                       # about half an hour on 45865b0, by extrapolation
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "rows past its header", fixed = TRUE)
})

test_that("4,000 identical labels are refused by the line count inside the loop, in seconds (screen 1715 F1)", {
  f <- identicalRowsCsv(4000L)
  t <- timed(.apiReadUpload(f, "same.csv"))
  expect_lt(t$s, 45)                                      # 141 s on 45865b0
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "template lines", fixed = TRUE)
})

test_that("row names are unique by the same rule as before, at a constant cost per row", {
  # 1,500 identical labels stay under the line cap (3,000 lines) and are
  # named "Age", "Age 2", ... "Age 1500" - the .ppUniqueName rule
  f <- identicalRowsCsv(1500L)
  t <- timed(parseWideTable(f, "csv"))
  expect_lt(t$s, 20)
  d <- t$r[[1]]$data
  expect_identical(nrow(d), 3000L)
  expect_identical(unique(d$ROW)[1:3], c("Age", "Age 2", "Age 3"))
  expect_identical(length(unique(d$ROW)), 1500L)
  # and an explicit "Age 2" in the file still takes the next free name
  g <- tempfile(fileext = ".csv")
  writeLines(c("Variable,Arm A (n=10),Arm B (n=10)",
               '"Age, mean (SD)","50.1 (10.2)","50.3 (10.1)"',
               '"Age 2, mean (SD)","50.1 (10.2)","50.3 (10.1)"',
               '"Age, mean (SD)","50.1 (10.2)","50.3 (10.1)"'), g)
  expect_identical(unique(parseWideTable(g, "csv")[[1]]$data$ROW), c("Age", "Age 2", "Age 3"))
})

test_that("3,333 one-line trial blocks in one sheet are admitted in seconds, the totals carried not recounted (screen 1715 F2)", {
  f <- oneLineBlocksXlsx(3333L, 1L)
  t <- timed(.apiReadUpload(f, "blocks.xlsx"))
  expect_lt(t$s, 60)                                      # 209 to 218 s on 45865b0
  expect_true(isTRUE(t$r$ok))
  expect_identical(nrow(t$r$data), 3333L)
  expect_identical(length(unique(t$r$data$TRIAL)), 3333L)
})

test_that("6,666 one-line blocks over two sheets are refused at the line cap, in seconds (screen 1715 F2)", {
  f <- oneLineBlocksXlsx(3333L, 2L)
  t <- timed(.apiReadUpload(f, "blocks.xlsx"))
  expect_lt(t$s, 90)                                      # 518 to 554 s on 45865b0
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "5000", fixed = TRUE)
  expect_error(parseWideTable(f, "xlsx"), class = "iaWideTooLarge")
})

test_that("the running totals cross blocks: a block is refused mid-loop once the file is past the bound", {
  # two blocks of 2,000 continuous rows x 2 arms: the second is refused
  # while it is being read, by the file's total, not after it is built
  f <- tempfile(fileext = ".xlsx"); wb <- openxlsx::createWorkbook()
  m <- matrix("", nrow = 2L * 2002L, ncol = 3L)
  for (b in 1:2) {
    i <- (b - 1L) * 2002L
    m[i + 1L, ] <- c(sprintf("Trial: T%d", b), "", "")
    m[i + 2L, ] <- c("Variable", "Arm A (n=10)", "Arm B (n=10)")
    for (r in seq_len(2000L)) m[i + 2L + r, ] <- c(sprintf("X%d, mean (SD)", r), "50.1 (10.2)", "50.3 (10.1)")
  }
  openxlsx::addWorksheet(wb, "S1"); openxlsx::writeData(wb, "S1", as.data.frame(m, stringsAsFactors = FALSE), colNames = FALSE)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  t <- timed(tryCatch(parseWideTable(f, "xlsx"), iaWideTooLarge = function(e) e))
  expect_s3_class(t$r, "iaWideTooLarge")
  expect_match(conditionMessage(t$r), "template lines", fixed = TRUE)
  expect_lt(t$s, 45)
})
