# Adjudication of security screen 2026-09-10-1856 (over 7c377dc..1810272),
# finding F2 (HIGH, availability): utils::read.csv() is quadratic in the
# length of any of a file's first five lines (it sizes a header = FALSE
# frame from them), and it ran before every gate that follows on every CSV
# route - one field of 1 MB on line 2 (three fields, so the column gate
# passed it) took 107 s; a 25 MiB line about eighteen hours.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (.iaCsvLongLine(): the
# first five physical lines measured in bytes by readLines(), which is
# linear; .iaCsvRefusal(): the one reason a CSV is refused before it is
# read, used by the wide reader, the API's template read and the app's)
# and R/apiService.R (the CSV is gated once, before either reader, so the
# reason reaches the caller). Reproduced through the path the screen names
# - the CSV through .apiReadUpload(), timed - and checked to FAIL on
# 1810272 by timing (107 s there).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

longLineCsv <- function(KB, line = 2L) {
  f <- tempfile(fileext = ".csv")
  rows <- c("Variable,Arm A (n=10),Arm B (n=10)",
            '"Height, mean (SD)","165 (7)","167 (7)"',
            '"Weight, mean (SD)","63 (13)","68 (12)"',
            '"Age, mean (SD)","45.3 (12.1)","46.1 (11.8)"',
            sprintf('"V%d, mean (SD)","50.1 (10.2)","50.3 (10.1)"', 1:6))   # ten short lines
  long <- paste0('"Long, mean (SD)","', strrep("x", KB * 1000L), '","50.3 (10.1)"')
  writeLines(append(rows, long, after = line - 1L), f)
  f
}
timed <- function(expr) { el <- system.time(r <- expr)[["elapsed"]]; list(r = r, s = el) }

test_that("a 1 MB line among the first five is refused before read.csv sees it, with the reason (screen 1856 F2)", {
  t <- timed(.apiReadUpload(longLineCsv(1000L), "line.csv"))
  expect_lt(t$s, 5)                                       # 107 s on 1810272
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "line over", fixed = TRUE)
  expect_match(t$r$reasons, "100 KB", fixed = TRUE)
  expect_true(.iaCsvLongLine(longLineCsv(1000L)))
  expect_error(.wideRawCells(longLineCsv(1000L), "csv"), "line over")
})

test_that("the gate is linear and measures every line", {
  # a 1 MB line on line 8 costs read.csv nothing (it sizes from the first
  # five non-empty lines) but is refused all the same: since screen 2004
  # every line is measured, because one empty first line put physical
  # line 6 among read.csv's five
  t <- timed(.iaCsvLongLine(longLineCsv(1000L, line = 8L)))
  expect_true(t$r)
  expect_lt(t$s, 1)
  # a 5 MB line on line 1: measured, refused, in well under a second
  t <- timed(.iaCsvLongLine(longLineCsv(5000L, line = 1L)))
  expect_true(t$r)
  expect_lt(t$s, 2)
})

test_that("a quoted field spanning lines still refuses (the count.fields NA), and a wide line refuses as before", {
  f <- tempfile(fileext = ".csv"); writeLines(c('a,"b', 'c",d', "1,2"), f)
  expect_true(.iaCsvTooWide(f))
  expect_match(.iaCsvRefusal(f), "columns", fixed = TRUE)
  g <- tempfile(fileext = ".csv")
  writeLines(c("a,b", rep(paste(rep("", 3001), collapse = ","), 4)), g)
  expect_match(.iaCsvRefusal(g), "500 columns", fixed = TRUE)
  expect_false(isTRUE(.apiReadUpload(g, "wide.csv")$ok))
})

test_that("an ordinary CSV, template or journal-style, reads as before", {
  h <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", "T,Age,10,50,10", "T,Age,10,51,11"), h)
  expect_null(.iaCsvRefusal(h))
  r <- .apiReadUpload(h, "t.csv")
  expect_true(isTRUE(r$ok)); expect_identical(nrow(r$data), 2L)
  w <- longLineCsv(0L)                                    # the wide fixture with a 0-byte long cell
  r2 <- .apiReadUpload(w, "w.csv")
  expect_true(isTRUE(r2$ok)); expect_identical(r2$engine, "wide")
  # a 90 KB line is under the gate: read, and then refused by the wide reader's cell cap, not by this gate
  r3 <- .apiReadUpload(longLineCsv(90L), "ninety.csv")
  expect_false(isTRUE(r3$ok))
  expect_match(r3$reasons, "characters", fixed = TRUE)
})
