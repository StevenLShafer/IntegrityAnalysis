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

  # THROUGH THE PRODUCTION READER. This test used to pass `colClasses =
  # "character"` to read.csv, which is not how the app or the API reads a
  # file, and that is exactly why it did not catch the defect the
  # 2026-09-09 audit found in F5: the real reader coerced "50.0" to 50
  # before the validator could count its digits, so the comma-separated
  # route still destroyed the precision the spreadsheet route preserved.
  # A test that reads the payload differently from the product tests
  # nothing about the product.
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(csv, f)
  back <- .iaReadCsvKeepingText(f, check.names = FALSE)
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


# ---- the 2026-09-09 audit ---------------------------------------------

test_that("a supplied coarse mean precision is not overwritten", {
  # AUDIT 2026-09-09, F3. The bump that raises ROUND_MEAN to the digits a
  # cell shows was made unconditional when the text reader went in, so a
  # mean of 50 legitimately declared to the nearest ten had its own claim
  # rewritten to 0 - and that moved the row from p = 0.26 to p = 0.005.
  # A value showing no decimals is no evidence against a coarser claim.
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(100, 100, 100), MEAN = 50,
                  SD = 30, SE = NA_real_, ROUND_MEAN = -1,
                  ROUND_OBSERVATION = 0, ROUND_DISPERSION = 0,
                  stringsAsFactors = FALSE)
  expect_equal(vd(d)$DATA$ROUND_MEAN, c(-1, -1, -1))
  # ...and the bump still does its job when the page really shows digits
  d2 <- d; d2$MEAN <- c("50.0", "50.0", "50.0")
  expect_equal(vd(d2)$DATA$ROUND_MEAN, c(1, 1, 1))
  d3 <- d; d3$MEAN <- c(45.25, 45.25, 45.25); d3$ROUND_MEAN <- 0
  expect_equal(vd(d3)$DATA$ROUND_MEAN, c(2, 2, 2))
})

test_that("a median row keeps a supplied coarse precision too", {
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(50, 50),
                  SD = NA_real_, SE = NA_real_, Q1 = c(40, 40), Q3 = c(60, 60),
                  ROUND_MEAN = -1, ROUND_OBSERVATION = 0,
                  ROUND_DISPERSION = -1, stringsAsFactors = FALSE)
  expect_equal(vd(d)$DATA$ROUND_MEAN, c(-1, -1))
})

test_that("scientific notation is not read as extra decimal places", {
  # AUDIT 2026-09-09, F4. Everything after the first "." was counted,
  # exponent included, so "5.0e1" read three decimals where it shows the
  # same unit precision as "50" - and a spreadsheet writes scientific
  # notation without being asked.
  expect_equal(.ppDecimals("5.0e1"), 0L)
  expect_equal(.ppDecimals("1.0e1"), 0L)
  expect_equal(.ppDecimals("50"), 0L)
  expect_equal(.ppDecimals("50.00"), 2L)
  # a negative exponent adds precision rather than removing it
  expect_equal(.ppDecimals("0.5e-2"), 3L)
  expect_equal(.ppDecimals("5E-3"), 3L)
  # vectorised, as its callers use it
  expect_equal(.ppDecimals(c("5.0e1", "1.25", "7")), c(0L, 2L, 0L))
  # and the two spellings of the same number now infer the same grid
  mk <- function(mean, sd) data.frame(
    TRIAL = "T", ROW = "X", N = c(40, 40), MEAN = mean, SD = sd,
    SE = NA_real_, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  a <- vd(mk(c("50", "50"), c("10", "10")))
  b <- vd(mk(c("5.0e1", "5.0e1"), c("1.0e1", "1.0e1")))
  expect_equal(a$DATA$ROUND_MEAN, b$DATA$ROUND_MEAN)
  expect_equal(a$DATA$ROUND_DISPERSION, b$DATA$ROUND_DISPERSION)
})

test_that("the comma-separated reader keeps the printed digits", {
  # AUDIT 2026-09-09, F5. Both routes read a CSV with read.csv, which
  # coerces before the validator can count trailing zeros.
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(c('"TRIAL","ROW","N","MEAN","SD","ROUND_OBSERVATION","Male","Female"',
               '"T","X",100,"50.000","3.00",0,,',
               '"T","X",100,"50.000","3.00",0,,',
               '"T","Sex",,,,,60,40',
               '"T","Sex",,,,,55,45'), f)
  d <- .iaReadCsvKeepingText(f)
  expect_true(is.character(d$MEAN))
  expect_true(is.numeric(d$N))
  expect_true(is.numeric(d$Male))
  v <- vd(d)
  expect_false(v$FAIL)
  # by LABEL, not position: validateData() reorders the rows
  cont <- which(v$DATA$ROW == "X")
  expect_equal(v$DATA$ROUND_MEAN[cont], c(3, 3))
  expect_equal(v$DATA$ROUND_DISPERSION[cont], c(2, 2))
  # the count columns are still counts, not Misc columns
  expect_setequal(toupper(v$CategoryNames), c("MALE", "FEMALE"))
})

test_that("a trial named T is a label, not a logical", {
  # read.csv turns the bare token T into TRUE; reading as text does not
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(c("TRIAL,ROW,N,MEAN,SD,ROUND_OBSERVATION",
               "T,X,40,50.0,10.0,0",
               "T,X,40,51.0,10.0,0"), f)
  d <- .iaReadCsvKeepingText(f)
  expect_identical(unique(as.character(d$TRIAL)), "T")
})

test_that("a stray word still leaves its column unreadable, not silently numeric", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(c("TRIAL,ROW,N,MEAN,SD,ROUND_OBSERVATION",
               "T,X,forty,50.0,10.0,0",
               "T,X,40,51.0,10.0,0"), f)
  d <- .iaReadCsvKeepingText(f)
  expect_true(is.character(d$N))
  v <- vd(d)
  expect_true(v$FAIL)
})
