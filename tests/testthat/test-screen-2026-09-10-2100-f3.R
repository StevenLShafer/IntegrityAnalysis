# Adjudication of the nightly security screen 2026-09-10-2100 (over
# 67a03ab..b1c1dea), finding F3 (LOW): .ppClip() tested a cell's length in
# BYTES and cut it in CHARACTERS, so a row label of 2,500 four-byte
# characters passed the wide reader's clip as 8,000 bytes - four times the
# bound the 2004 fix intended - and the template grew accordingly (4 MB
# under 499 arms; 40 MB at the line cap). The JATS and Word readers share
# the helper.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseJats.R (.ppClip() cuts a bytes-encoded
# copy byte-wise, drops a multibyte character split at the boundary, and
# marks the result UTF-8). Reproduced through the path the screen names -
# the multibyte label through .apiReadUpload() - and checked to FAIL on
# 7fd6545 (8,000-byte labels there).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that(".ppClip() clips to bytes, and never leaves a split multibyte character (screen 2100 F3)", {
  x <- .ppClip(c("abc", strrep("é", 5), strrep("\U0001F600", 3), NA, ""), 6L)
  expect_identical(nchar(x, type = "bytes"), c(3L, 6L, 4L, 0L, 0L))
  expect_identical(x[2], strrep("é", 3))              # three two-byte characters
  expect_identical(x[3], "\U0001F600")                      # one four-byte character; the split second dropped
  expect_true(all(validUTF8(x)))
  expect_identical(.ppClip("plain ascii", 100L), "plain ascii")
  long <- paste(rep("word", 1000), collapse = " ")
  expect_identical(nchar(.ppClip(long, 2000L), type = "bytes"), 2000L)
})

test_that("a multibyte row label under 499 arms is 2,000 bytes in every line, not 8,000", {
  f <- tempfile(fileext = ".csv")
  A <- 499L
  hdr <- paste(c("Variable", sprintf("Arm %d (n=10)", seq_len(A))), collapse = ",")
  label <- paste0(strrep("\U0001F600", 2500L), ", mean (SD)")       # 10,000 bytes of emoji
  row <- paste(c(paste0('"', label, '"'), rep('"50.1 (10.2)"', A)), collapse = ",")
  con <- file(f, open = "w", encoding = "UTF-8"); writeLines(c(hdr, row), con); close(con)
  r <- .apiReadUpload(f, "emoji.csv")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_identical(nrow(r$data), A)
  expect_lte(max(nchar(r$data$ROW, type = "bytes")), .ppMaxCellChars)   # 8,000 on 7fd6545
  expect_true(all(validUTF8(r$data$ROW)))
  expect_lt(nchar(.apiTemplateCsv(r$data), type = "bytes"), 1.2e6)      # 4 MB on 7fd6545
})
