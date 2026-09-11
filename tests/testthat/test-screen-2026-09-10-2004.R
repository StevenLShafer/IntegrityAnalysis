# Adjudication of security screen 2026-09-10-2004 (over 1810272..67a03ab),
# findings F1 and F2 (both HIGH, availability), both under the CSV line
# gate of the 1856 fix:
#   F1 - the gate measured the first five PHYSICAL lines, but read.table()
#        sizes its frame from the first five NON-EMPTY lines, so one empty
#        first line put physical line 6 among them and past the gate (a
#        400 KB field there: 16 s, the quadratic curve intact).
#   F2 - R's file() inflates gzip, bzip2 and xz transparently whatever the
#        file is called, so every CSV reader on every route read the
#        DECOMPRESSED stream while the request cap had bounded only the
#        compressed bytes (a 388 KB gzip held a 400 MB line; 146 KB of xz a
#        gigabyte); the gate itself was the first reader to pay.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (.iaCsvLongLine() measures
# every line; .iaCsvCompressed() reads six bytes with readBin() and names
# the three magics; .iaCsvRefusal() judges the bytes before any reader
# opens the file) and the group-1c pin in tools/securityCheck.R.
# Reproduced through the path the screen names - the files through
# .apiReadUpload() - and checked to FAIL on 28d7ee1 (the blank-first-line
# file: about 16 s and read; the gzip: inflated and read).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

blankThenLong <- function(KB) {
  f <- tempfile(fileext = ".csv")
  writeLines(c("", "Variable,Arm A (n=10),Arm B (n=10)",
               '"Height, mean (SD)","165 (7)","167 (7)"', '"Weight, mean (SD)","63 (13)","68 (12)"',
               '"Age, mean (SD)","45.3 (12.1)","46.1 (11.8)"',
               paste0('"Long, mean (SD)","', strrep("x", KB * 1000L), '","50.3 (10.1)"')), f)
  f
}
compressedCsv <- function(kind, MB = 5L) {
  f <- tempfile(fileext = ".csv")
  con <- switch(kind, gzip = gzfile(f, "wb"), bzip2 = bzfile(f, "wb"), xz = xzfile(f, "wb"))
  writeLines(c("Variable,Arm A (n=10),Arm B (n=10)",
               paste0('"Long, mean (SD)","', strrep("x", MB * 1000000L), '","50.3 (10.1)"')), con)
  close(con); f
}
timed <- function(expr) { el <- system.time(r <- expr)[["elapsed"]]; list(r = r, s = el) }

test_that("an empty first line no longer puts a long line past the gate: every line is measured (screen 2004 F1)", {
  t <- timed(.apiReadUpload(blankThenLong(400L), "blank.csv"))
  expect_lt(t$s, 5)                                       # 16 s on 28d7ee1, and read
  expect_false(isTRUE(t$r$ok))
  expect_match(t$r$reasons, "line over", fixed = TRUE)
  expect_true(.iaCsvLongLine(blankThenLong(400L)))
  # and a long line anywhere, not only among the first five
  f <- tempfile(fileext = ".csv")
  writeLines(c("Variable,Arm A (n=10),Arm B (n=10)", rep('"V, mean (SD)","50.1 (10.2)","50.3 (10.1)"', 20),
               paste0('"Long, mean (SD)","', strrep("x", 200000L), '","50.3 (10.1)"')), f)
  expect_true(.iaCsvLongLine(f))
  expect_false(isTRUE(.apiReadUpload(f, "late.csv")$ok))
})

test_that("a gzip, bzip2 or xz stream named .csv is refused by its bytes before any reader opens it (screen 2004 F2)", {
  for (kind in c("gzip", "bzip2", "xz")) {
    f <- compressedCsv(kind)
    expect_lt(file.size(f), 200000)          # a few KB on disk holding a 5 MB line
    expect_identical(.iaCsvCompressed(f), kind)
    t <- timed(.apiReadUpload(f, "z.csv"))
    expect_lt(t$s, 2)
    expect_false(isTRUE(t$r$ok), info = kind)
    expect_match(t$r$reasons, paste(kind, "stream"), fixed = TRUE)
    expect_match(.iaCsvRefusal(f), "decompress", fixed = TRUE)
    # the wide reader and the raw-cell reader refuse the same way
    expect_error(.wideRawCells(f, "csv"), "stream")
  }
})

test_that("the refusal order judges the bytes first, and the check reads six bytes, not the file", {
  # a gzip whose inflated content would ALSO be refused for its line: the
  # reason is the stream, which means nothing inflated it
  f <- compressedCsv("gzip", MB = 20L)
  expect_match(.iaCsvRefusal(f), "gzip stream", fixed = TRUE)
  t <- timed(.iaCsvCompressed(f))
  expect_lt(t$s, 0.5)
  # a plain file whose first bytes are not a magic is not a stream
  g <- tempfile(fileext = ".csv"); writeLines(c("BZ,a,b", "1,2,3"), g)
  expect_null(.iaCsvCompressed(g))
  expect_null(.iaCsvRefusal(g))
})

test_that("ordinary CSVs, and the earlier gates, are unchanged", {
  h <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", "T,Age,10,50,10", "T,Age,10,51,11"), h)
  expect_null(.iaCsvRefusal(h))
  expect_true(isTRUE(.apiReadUpload(h, "t.csv")$ok))
  w <- tempfile(fileext = ".csv")
  writeLines(c("", "Variable,Arm A (n=10),Arm B (n=10)", '"Age, mean (SD)","45.3 (12.1)","46.1 (11.8)"'), w)
  r <- .apiReadUpload(w, "w.csv")                         # an empty first line is not itself a refusal
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  q <- tempfile(fileext = ".csv"); writeLines(c('a,"b', 'c",d', "1,2"), q)
  expect_match(.iaCsvRefusal(q), "columns", fixed = TRUE) # the quoted-newline refusal stands
})
