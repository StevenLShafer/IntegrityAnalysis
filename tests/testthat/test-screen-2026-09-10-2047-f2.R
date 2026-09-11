# Adjudication of security screen 2026-09-10-2047 (over 67a03ab..90d3404),
# finding F2 (HIGH, availability): the template route wrote every cell
# verbatim with no cell cap. An xlsx stores a repeated string once, so the
# inflation preflight passed; R's string cache kept the read frame small,
# so the row and column gates passed; then write.csv materialised rows x
# columns x length - a 130 KB workbook of 5,000 rows with one 30 KB text
# column came back as a 150 MB reply (611 MB peak), and 500 rows x 194
# such columns ran write.csv for 325 s before failing on R's 2^31 limit.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/app_globals.R (.iaTableTextRefusal(): no
# cell over .ppMaxCellChars, no more than .iaMaxTableTextBytes of text),
# applied in R/apiService.R (the template branch, before the reply) and
# R/app_server.R (after readSheet). Reproduced through the path the screen
# names - the workbook through .apiReadUpload() - and checked to FAIL on
# b1c1dea (read, 5,000 rows, a 150 MB templateCsv).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

templateXlsx <- function(rows, cell, cols = 1L) {
  f <- tempfile(fileext = ".xlsx"); wb <- openxlsx::createWorkbook(); openxlsx::addWorksheet(wb, "S")
  d <- data.frame(TRIAL = "T", ROW = "Age", N = 10, MEAN = 50, SD = 10, stringsAsFactors = FALSE)[rep(1, rows), ]
  for (k in seq_len(cols)) d[[paste0("NOTE", k)]] <- cell
  openxlsx::writeData(wb, "S", d); openxlsx::saveWorkbook(wb, f, overwrite = TRUE); f
}

test_that("a template workbook with a 30 KB cell is refused before the reply is written (screen 2047 F2)", {
  f <- templateXlsx(5000L, strrep("z", 30000L))
  expect_lt(file.size(f), 200000)                         # a small file holding a large table
  t <- system.time(r <- .apiReadUpload(f, "t.xlsx"))[["elapsed"]]
  expect_lt(t, 10)
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "cell of 30000 characters", fixed = TRUE)
  expect_match(r$reasons, as.character(.ppMaxCellChars), fixed = TRUE)
  expect_null(r$data)                                     # nothing to serialise
})

test_that("a table within the cell cap but past the text budget is refused too", {
  # 5,000 rows x 3 columns of 1,900-character cells: every cell under the cap, 28 MB of text
  f <- templateXlsx(5000L, strrep("y", 1900L), cols = 3L)
  r <- .apiReadUpload(f, "big.xlsx")
  expect_false(isTRUE(r$ok))
  expect_match(r$reasons, "MB of text", fixed = TRUE)
  expect_match(r$reasons, as.character(.iaMaxTableTextBytes %/% 1000000L), fixed = TRUE)
})

test_that("the refusal is the one function, on a frame, so the app's route shares it", {
  d <- data.frame(TRIAL = "T", ROW = "Age", N = 10, MEAN = 50, SD = 10, NOTE = strrep("q", 2001L), stringsAsFactors = FALSE)
  expect_match(.iaTableTextRefusal(d), "2001 characters", fixed = TRUE)
  d$NOTE <- strrep("q", 2000L)
  expect_null(.iaTableTextRefusal(d))                     # at the cap: read
  big <- data.frame(A = rep(strrep("w", 2000L), 11000L), stringsAsFactors = FALSE)   # 22 MB
  expect_match(.iaTableTextRefusal(big), "MB of text", fixed = TRUE)
  expect_null(.iaTableTextRefusal(data.frame(N = 1:3, MEAN = c(1, 2, 3))))            # no text at all
  expect_null(.iaTableTextRefusal(NULL))
})

test_that("ordinary templates read as before, on both routes' reader", {
  f <- templateXlsx(50L, "a short note")
  r <- .apiReadUpload(f, "ok.xlsx")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "template"); expect_identical(nrow(r$data), 50L)
  h <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", "T,Age,10,50,10", "T,Age,10,51,11"), h)
  expect_true(isTRUE(.apiReadUpload(h, "t.csv")$ok))
  ex <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  if (nzchar(ex)) expect_true(isTRUE(.apiReadUpload(ex, "Example.xlsx")$ok))
})
