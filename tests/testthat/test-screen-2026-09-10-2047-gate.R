# Adjudication of security screen 2026-09-10-2047 (over 67a03ab..90d3404),
# findings F1 (HIGH) and F4 (MEDIUM), both in the CSV pre-read gate of the
# 2004 fix:
#   F1 - the compressed-stream check named gzip, bzip2 and xz; R 4.5's
#        file() also inflates zstd (28 b5 2f fd) and LZMA-alone (5d 00 00
#        80 00, and the FF "LZMA" prefix), so a 6 KB zstd holding a 200 MB
#        line (32,300:1) was inflated whole inside the gate.
#   F4 - the whole-file readLines() measure held a pointer per line: 25 MiB
#        of newline bytes alone was 550 MB; and it read through file() in
#        text mode, which inflates.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (.iaCsvCompressed() names
# every magic R inflates; .iaCsvLongLine() measures the file as a stream of
# raw bytes - file(path, "rb"), readBin() in 256 KB chunks, the longest run
# between newlines - constant memory, immune to inflation) and the group-1c
# pin updated. Reproduced through the path the screen names - the files
# through .apiReadUpload() and the gate directly - and checked to FAIL on
# b1c1dea (zstd and LZMA read end to end; 25 MiB of newlines 550 MB).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

twoLines <- c("Variable,Arm A (n=10),Arm B (n=10)", '"Age, mean (SD)","45.3 (12.1)","46.1 (11.8)"')
heapMB <- function() sum(gc()[, 6])

test_that("zstd and LZMA streams named .csv are refused by their bytes, like gzip, bzip2 and xz (screen 2047 F1)", {
  if (exists("zstdfile", envir = baseenv())) {
    f <- tempfile(fileext = ".csv"); con <- zstdfile(f, "wb"); writeLines(twoLines, con); close(con)
    expect_identical(.iaCsvCompressed(f), "zstd")
    r <- .apiReadUpload(f, "z.csv")
    expect_false(isTRUE(r$ok)); expect_match(r$reasons, "zstd stream", fixed = TRUE)
  }
  # LZMA-alone: the header xz --format=lzma writes at its default dictionary
  g <- tempfile(fileext = ".csv"); writeBin(c(as.raw(c(0x5d, 0, 0, 0x80, 0)), as.raw(rep(0x41, 100))), g)
  expect_identical(.iaCsvCompressed(g), "lzma")
  expect_match(.apiReadUpload(g, "l.csv")$reasons, "lzma stream", fixed = TRUE)
  # ...and the other spelling R accepts
  h <- tempfile(fileext = ".csv"); writeBin(c(as.raw(c(0xff, 0x4c, 0x5a, 0x4d, 0x41, 0x00)), as.raw(rep(0x41, 100))), h)
  expect_identical(.iaCsvCompressed(h), "lzma")
  expect_false(isTRUE(.apiReadUpload(h, "l2.csv")$ok))
  # the three from 2004 still named
  for (kind in c("gzip", "bzip2", "xz")) {
    k <- tempfile(fileext = ".csv")
    con <- switch(kind, gzip = gzfile(k, "wb"), bzip2 = bzfile(k, "wb"), xz = xzfile(k, "wb"))
    writeLines(twoLines, con); close(con)
    expect_identical(.iaCsvCompressed(k), kind)
  }
})

test_that("the line measure is a stream of raw bytes: constant memory on 25 MiB of newlines (screen 2047 F4)", {
  skip_if_not_installed("callr")
  f <- tempfile(fileext = ".csv")
  con <- file(f, "wb"); for (i in 1:25) writeBin(as.raw(rep(0x0a, 2^20)), con); close(con)
  t <- system.time(r <- .iaCsvLongLine(f))[["elapsed"]]
  expect_false(r)
  expect_lt(t, 5)
  # The heap high-water is measured in a FRESH process: inside a full
  # suite the collector's trigger has grown with everything before, so an
  # in-process delta says more about the suite than the function. The
  # child loads the tree under test (the repo when the tests run from it,
  # the installed package under R CMD check).
  root <- normalizePath(test_path("..", ".."), mustWork = FALSE)
  m <- callr::r(function(f, root) {
    if (file.exists(file.path(root, "R", "parseWideTable.R")))
      pkgload::load_all(root, quiet = TRUE)
    else suppressPackageStartupMessages(library(IntegrityAnalysis))
    invisible(gc()); before <- sum(gc(reset = TRUE)[, 2])
    r <- IntegrityAnalysis:::.iaCsvLongLine(f)
    c(result = r, deltaMB = sum(gc()[, 6]) - before)
  }, args = list(f, root))
  expect_false(as.logical(m[["result"]]))
  expect_lt(m[["deltaMB"]], 150)                          # about 550 MB above baseline on b1c1dea; 42 here
})

test_that("the streamed measure finds a long line wherever it sits, across chunk boundaries, with or without a final newline", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("a,b,c", paste0(strrep("x", 1500000L), ",1,2"), "d,e,f"), f)   # spans six 256 KB chunks
  expect_true(.iaCsvLongLine(f))
  g <- tempfile(fileext = ".csv")
  con <- file(g, "wb"); writeBin(charToRaw(paste0("a,b,c\n", strrep("y", 200000L), ",1,2")), con); close(con)   # no trailing newline
  expect_true(.iaCsvLongLine(g))
  h <- tempfile(fileext = ".csv")
  writeLines(c("a,b,c", paste0(strrep("z", 90000L), ",1,2"), rep("1,2,3", 300000L)), h)   # 90 KB line, then 300,000 short lines
  expect_false(.iaCsvLongLine(h))
  k <- tempfile(fileext = ".csv")
  con <- file(k, "wb"); writeBin(charToRaw("TRIAL,ROW,N,MEAN,SD\r\nT,Age,10,50,10\r\nT,Age,10,51,11\r\n"), con); close(con)
  expect_false(.iaCsvLongLine(k))                          # CRLF lines are measured with their CR
  expect_true(isTRUE(.apiReadUpload(k, "crlf.csv")$ok))
  e <- tempfile(fileext = ".csv"); file.create(e)
  expect_false(.iaCsvLongLine(e))
})

test_that("a compressed stream is never inflated by the measure: the gate's own cost is the bytes on disk", {
  # a gzip named .csv holding a 20 MB line is refused as a stream in
  # milliseconds; and even called directly, the measure reads the
  # compressed bytes, not the inflated line
  f <- tempfile(fileext = ".csv"); con <- gzfile(f, "wb")
  writeLines(c("a,b,c", paste0(strrep("x", 20000000L), ",1,2")), con); close(con)
  expect_lt(file.size(f), 100000)
  t <- system.time(r <- .iaCsvLongLine(f))[["elapsed"]]
  expect_lt(t, 1)
  expect_false(r)                                          # the compressed bytes hold no newline run over the cap
  expect_match(.iaCsvRefusal(f), "gzip stream", fixed = TRUE)
})
