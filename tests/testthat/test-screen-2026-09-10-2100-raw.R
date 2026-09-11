# Adjudication of the nightly security screen 2026-09-10-2100 (over
# 67a03ab..b1c1dea), finding F1 (HIGH), the part not closed by #288: the
# magic-byte refusal names the formats R inflates TODAY (gzip, bzip2, xz,
# LZMA, zstd), and every text reader behind it - count.fields(), read.csv()
# in the wide reader and in the template reader - still opened the file
# through file() in text mode, which inflates whatever a later R adds.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R and R/app_globals.R
# (.iaCsvConnection(): file(path, "rt", raw = TRUE), documented to suppress
# the compressed-file check; every CSV reader takes it) and a tripwire pin
# (a reader that takes a path is refused). Reproduced through the readers
# themselves on a compressed stream and checked to FAIL on 7fd6545 (the
# readers inflated it).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

gzipRows <- function(n) {
  f <- tempfile(fileext = ".csv"); con <- gzfile(f, "wb")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", rep("T,Age,10,50,10", n)), con); close(con); f
}

test_that("the CSV readers open the file raw: a gzip stream is read as its bytes, never inflated (screen 2100 F1)", {
  f <- gzipRows(200000L)                                  # 2.6 MB inflated, a few KB on disk
  expect_lt(file.size(f), 50000)
  # the column counter sees the compressed bytes, not 200,001 lines of five fields
  n <- .iaCsvColumns(f)
  expect_false(isTRUE(n == 5L))
  # the template reader sees a handful of garbage rows, not 200,000 template rows
  d <- tryCatch(.iaReadCsvKeepingText(f, check.names = FALSE), error = function(e) NULL)
  expect_true(is.null(d) || nrow(d) < 1000L)              # 200,000 on 7fd6545
  # the raw-cell reader likewise (behind the gate, which refuses first)
  expect_error(.wideRawCells(f, "csv"), "gzip stream")
  expect_match(.iaCsvRefusal(f), "gzip stream", fixed = TRUE)
})

test_that(".iaCsvConnection() is raw, and an ordinary CSV reads through it exactly as before", {
  h <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", "T,Age,10,50.0,10", "T,Age,10,51.5,11"), h)
  con <- .iaCsvConnection(h); on.exit(close(con))
  expect_true(inherits(con, "file"))
  expect_identical(summary(con)$mode, "rt")
  expect_identical(.iaCsvColumns(h), 5L)
  d <- .iaReadCsvKeepingText(h, check.names = FALSE)
  expect_identical(nrow(d), 2L)
  expect_identical(d$MEAN, c("50.0", "51.5"))              # the text precision survives the raw read
  r <- .apiReadUpload(h, "t.csv")
  expect_true(isTRUE(r$ok)); expect_identical(nrow(r$data), 2L)
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".csv"); utils::write.csv(v$DATA, g, row.names = FALSE)
  expect_true(isTRUE(.apiReadUpload(g, "wide.csv")$ok))
})
