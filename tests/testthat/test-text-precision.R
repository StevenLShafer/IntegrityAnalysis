# The printed precision survives a spreadsheet round trip.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5, Anthropic),
# 2026-09-08, with the change in R/validateData.R, R/app_server.R,
# R/writeIntegrityTemplate.R and R/apiService.R, at Steve Shafer's
# request: "on the xlsx export, I think we should export the numbers as
# text, not as numbers. As you note, 50.0 exported as a number reports
# 50. The 0 is lost." Two halves, tested here together because only the
# pair is worth anything - the reader, which counts a text cell's
# decimals BEFORE coercing it, and the writer, which formats the value
# columns as text at the precision the row declares.
#
# The precision is not cosmetic: it is the width of the interval the
# engine draws over, a direct multiplier on the null. A mean of 50.0
# re-uploaded as 50 is analysed on a ten-times coarser grid than the
# manuscript printed.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
  library(openxlsx)
}))

vd <- function(d) shiny::isolate(validateData(d))

# a table with no precision columns, so every precision below is INFERRED
noRound <- function(MEAN, SD) data.frame(
  TRIAL = "T", ROW = "Age", N = c(40, 40), MEAN = MEAN, SD = SD,
  SE = NA_real_, Q1 = NA_real_, Q3 = NA_real_, ROUND_OBSERVATION = c(0, 0),
  stringsAsFactors = FALSE)

# ---------------------------------------------------------------- reader

test_that("a text cell's trailing zeros are counted before the coercion", {
  v <- vd(noRound(MEAN = c("50.0", "51.0"), SD = c("10.00", "10.00")))
  expect_false(v$FAIL)
  expect_equal(v$DATA$ROUND_MEAN, c(1, 1))
  expect_equal(v$DATA$ROUND_DISPERSION, c(2, 2))
  # and the values themselves are numbers afterwards, as they always were
  expect_true(is.numeric(v$DATA$MEAN))
  expect_equal(v$DATA$MEAN, c(50, 51))
})

test_that("the same table as numbers still infers zero decimals", {
  # the loss this change exists to stop: nothing rescues a genuine
  # numeric cell, which is why the writer half is needed as well
  v <- vd(noRound(MEAN = c(50, 51), SD = c(10, 10)))
  expect_equal(v$DATA$ROUND_DISPERSION, c(0, 0))
})

test_that("a supplied precision still wins over the text", {
  d <- noRound(MEAN = c("50.0", "51.0"), SD = c("10.0", "10.0"))
  d$ROUND_MEAN <- c(3, 3)
  v <- vd(d)
  expect_false(v$FAIL)
  expect_equal(v$DATA$ROUND_MEAN, c(3, 3))
})

test_that("unreadable text is still refused, not credited with decimals", {
  v <- vd(noRound(MEAN = c("about 50.0", "51.0"), SD = c("10.0", "10.0")))
  expect_true(v$FAIL)
})

# ---------------------------------------------------------------- writer

test_that(".iaValueColumnsAsText writes the declared precision", {
  d <- noRound(MEAN = c(50, 51.5), SD = c(10, 10))
  d$ROUND_MEAN <- c(1, 1); d$ROUND_DISPERSION <- c(2, 2)
  t <- .iaValueColumnsAsText(d)
  expect_identical(t$MEAN, c("50.0", "51.5"))
  expect_identical(t$SD, c("10.00", "10.00"))
  # N, the counts and the precision columns stay numeric: they are whole
  # numbers, and is_category() calls a text column a Misc column
  expect_true(is.numeric(t$N))
  expect_true(is.numeric(t$ROUND_MEAN))
})

test_that("the declared precision is a floor, never a ceiling", {
  # an export must not quietly round the datum it is exporting
  d <- noRound(MEAN = c(50.125, 51), SD = c(10, 10))
  d$ROUND_MEAN <- c(1, 1); d$ROUND_DISPERSION <- c(0, 0)
  expect_identical(.iaValueColumnsAsText(d)$MEAN, c("50.125", "51.0"))
})

test_that("blanks stay blank and a non-finite value stays itself", {
  d <- noRound(MEAN = c(NA_real_, Inf), SD = c(10, 10))
  d$ROUND_MEAN <- c(2, 2)
  t <- .iaValueColumnsAsText(d)
  expect_true(is.na(t$MEAN[1]))
  expect_identical(t$MEAN[2], "Inf")
  # an empty table is returned untouched rather than erroring
  expect_equal(nrow(.iaValueColumnsAsText(d[0, ])), 0)
})

# ------------------------------------------------------- the round trip

test_that("50.0 survives the workbook: written, re-read, still one decimal", {
  d <- noRound(MEAN = c(50, 51), SD = c(10, 10))
  d$ROUND_MEAN <- c(1, 1); d$ROUND_DISPERSION <- c(2, 2)
  # a category variable of its own, so is_category() sees the blank it
  # keys on and the counts travel through the file beside the means
  cat2 <- d[1:2, ]
  cat2$ROW <- "Sex"
  cat2[, c("N", "MEAN", "SD", "ROUND_MEAN", "ROUND_DISPERSION",
           "ROUND_OBSERVATION")] <- NA
  d <- rbind(d, cat2)
  d$Male   <- c(NA, NA, 20, 22)
  d$Female <- c(NA, NA, 20, 18)

  f <- tempfile(fileext = ".xlsx")
  on.exit(unlink(f), add = TRUE)
  openxlsx::write.xlsx(.iaValueColumnsAsText(d), f, keepNA = FALSE)
  back <- openxlsx::read.xlsx(f, sheet = 1)

  # the workbook holds them as TEXT - that is the whole point
  expect_true(is.character(back$MEAN))
  expect_identical(back$MEAN[1:2], c("50.0", "51.0"))

  # and with the precision columns stripped, the reader recovers them
  bare <- back[, setdiff(names(back), c("ROUND_MEAN", "ROUND_DISPERSION"))]
  v <- vd(bare)
  expect_false(v$FAIL)
  expect_equal(v$DATA$ROUND_MEAN[1:2], c(1, 1))
  expect_equal(v$DATA$ROUND_DISPERSION[1:2], c(2, 2))
  # the counts are still counts, not Misc columns
  expect_setequal(toupper(v$CategoryNames), c("MALE", "FEMALE"))
})

test_that("50.0 survives the API round-trip payload", {
  d <- noRound(MEAN = c(50, 51), SD = c(10, 10))
  d$ROUND_MEAN <- c(1, 1); d$ROUND_DISPERSION <- c(2, 2)
  csv <- .apiTemplateCsv(d)
  expect_true(grepl('"50.0"', csv, fixed = TRUE))
  expect_true(grepl('"10.00"', csv, fixed = TRUE))

  back <- utils::read.csv(text = csv, check.names = FALSE,
                          colClasses = "character")
  bare <- back[, setdiff(names(back), c("ROUND_MEAN", "ROUND_DISPERSION"))]
  v <- vd(bare)
  expect_false(v$FAIL)
  expect_equal(v$DATA$ROUND_MEAN, c(1, 1))
  expect_equal(v$DATA$ROUND_DISPERSION, c(2, 2))
})

test_that("the parser's template spreadsheet carries its digits too", {
  skip_if_not_installed("openxlsx")
  d <- data.frame(
    TRIAL = "T", ROW = "Age", N = c(40, 40), MEAN = c(50, 51),
    SD = c(10, 10), SE = NA_real_, ROUND_MEAN = c(1, 1),
    ROUND_DISPERSION = c(2, 2), ROUND_OBSERVATION = c(0, 0),
    stringsAsFactors = FALSE)
  x <- structure(list(data = d,
                      provenance = data.frame(row = 1:2, source = "engine"),
                      skipped = data.frame(line = character(0),
                                           reason = character(0))),
                 class = "ParsePDFTable")
  f <- tempfile(fileext = ".xlsx")
  on.exit(unlink(f), add = TRUE)
  writeIntegrityTemplate(x, f)
  back <- openxlsx::read.xlsx(f, sheet = 1)
  expect_identical(back$MEAN, c("50.0", "51.0"))
  expect_identical(back$SD, c("10.00", "10.00"))
})
