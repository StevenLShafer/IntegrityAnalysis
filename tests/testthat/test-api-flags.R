# The reader's flags, made safe to put in an API reply (security screen
# 2026-09-07-1654, finding F3). A flag quotes the document - the table
# lines the reader refused, the sentences it recovered an arm size from,
# and with the AI assist on, model output the manuscript can steer - so
# the API layer scrubs its temp paths and bounds the length, on both
# routes, rather than trusting every present and future flag constructor.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that("the request's directory is scrubbed out of a flag", {
  work <- file.path(tempdir(), "apiFlagWork")
  f <- c(paste0("could not read ", work, "/upload.pdf"),
         paste0("and again at ", normalizePath(tempdir(), winslash = "/", mustWork = FALSE),
                "/childQ/upload.pdf"))
  out <- .apiSafeFlags(f, work, "upload.pdf")
  expect_false(any(grepl(work, out, fixed = TRUE)))
  expect_false(any(grepl(tempdir(), out, fixed = TRUE)))
  expect_true(any(grepl("upload.pdf", out, fixed = TRUE)))   # the file's own name survives
})

test_that("a long flag is truncated, and the truncation is marked", {
  long <- paste(rep("x", 5000), collapse = "")
  out <- .apiSafeFlags(long, tempdir(), "u.pdf")
  expect_lt(nchar(out[1], type = "bytes"), 5000)
  expect_match(out[1], "truncated")
})

test_that("a long flag of multi-byte characters is truncated by BYTES", {
  # substr() counts characters: 2,048 euro signs are 6,144 bytes and used
  # to pass the cut whole (CodeRabbit on PR #217)
  # built by code point: a non-ASCII literal in a test file is a portability
  # problem of its own
  long <- strrep(intToUtf8(0x20AC), 3000)
  out <- .apiSafeFlags(long, tempdir(), "u.pdf")
  expect_lte(nchar(out[1], type = "bytes"), .apiMaxFlagBytes + 32L)
  expect_match(out[1], "truncated")
  expect_false(is.na(nchar(out[1])))          # no half character left behind
})

test_that("a long ARRAY of flags is truncated, and says how many were dropped", {
  many <- paste0("flag ", seq_len(120))
  out <- .apiSafeFlags(many, tempdir(), "u.pdf")
  expect_equal(length(out), .apiMaxFlags + 1L)
  expect_match(out[length(out)], "further flag")
  expect_match(out[length(out)], "70")
})

test_that("nothing to say stays nothing", {
  expect_null(.apiSafeFlags(NULL, tempdir(), "u.pdf"))
  expect_null(.apiSafeFlags(character(0), tempdir(), "u.pdf"))
  # an ordinary flag passes through unchanged
  one <- "1 category row(s) use FAIL-SAFE counts - ...: Male."
  expect_identical(.apiSafeFlags(one, tempdir(), "u.pdf"), one)
})
