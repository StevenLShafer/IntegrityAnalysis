# Issue 17: journal-style wide baseline tables as INPUT.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-21,
# with R/parseWideTable.R. The acceptance test is Steve's design
# (2026-08-21): the Editor's View download this app generates must be
# valid input - generate from a validated frame, parse back, and the
# validated result must match the frame it came from. Fixture and
# comparison helpers live in helper-baselineTable.R.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(readxl); library(Rfast)
  library(foreach); library(MBESS); library(dqrng)
}))

stage <- function(src) {
  d <- file.path(tempdir(), paste0("wide", basename(tempfile(""))))
  dir.create(d)
  f <- file.path(d, basename(src))
  file.copy(src, f)
  f
}

# write a character matrix as an xlsx sheet, no headers, all text
writeRawXlsx <- function(m, file) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sheet1")
  openxlsx::writeData(wb, "Sheet1",
                      as.data.frame(m, stringsAsFactors = FALSE),
                      colNames = FALSE)
  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
  file
}

test_that("the Editor's View download round-trips (one sheet per trial)", {
  orig <- vdShared(wideFixtureTwoTrials())
  expect_false(orig$FAIL)
  tabs <- buildBaselineTables(orig$DATA, orig$CategoryNames)
  f <- tempfile(fileext = ".xlsx")
  writeBaselineTablesXlsx(tabs, f)

  blocks <- parseWideTable(f, "xlsx")
  expect_false(is.null(blocks))
  expect_length(blocks, 2)
  expect_identical(vapply(blocks, `[[`, character(1), "trial"),
                   c("A", "B"))
  # nothing the generator printed was unusable
  expect_identical(sum(vapply(blocks, function(b) nrow(b$skipped),
                              integer(1))), 0L)

  combined <- do.call(.ppRbindFill, lapply(blocks, `[[`, "data"))
  back <- vdShared(combined)
  expect_false(back$FAIL)
  expectWideRoundTrip(back$DATA, orig$DATA)
  # the category structure survived too
  expect_setequal(back$CategoryNames, orig$CategoryNames)
})

test_that("the results workbook's stacked Baseline Tables sheet round-trips", {
  orig <- vdShared(wideFixtureTwoTrials())
  dqrng::dqset.seed(42); set.seed(42)
  OUTPUT <- NULL
  for (tr in orig$TRIALS) {
    x <- suppressWarnings(shiny::isolate(
      P_Calc(tr, orig$DATA[orig$DATA$TRIAL == tr, ],
             orig$CategoryNames, 1000)))
    OUTPUT <- rbind(OUTPUT, x)
  }
  f <- tempfile(fileext = ".xlsx")
  writeResultsWorkbook(OUTPUT, orig$DATA, orig$CategoryNames, f)

  # the whole three-tab workbook goes back in: only Baseline Tables
  # parses (Test Results is vetoed by its TRIAL/ROW header, Summary
  # never looks like a wide table), trial ids come from the exact
  # "Trial: <id>" markers
  blocks <- parseWideTable(f, "xlsx")
  expect_false(is.null(blocks))
  expect_length(blocks, 2)
  expect_identical(vapply(blocks, `[[`, character(1), "trial"),
                   c("A", "B"))
  combined <- do.call(.ppRbindFill, lapply(blocks, `[[`, "data"))
  back <- vdShared(combined)
  expect_false(back$FAIL)
  expectWideRoundTrip(back$DATA, orig$DATA)
})

test_that("the app-level upload path accepts the Editor's View workbook", {
  orig <- vdShared(wideFixtureTwoTrials())
  tabs <- buildBaselineTables(orig$DATA, orig$CategoryNames)
  raw <- tempfile(fileext = ".xlsx")
  writeBaselineTablesXlsx(tabs, raw)
  up <- stage(raw)
  origDATA <- orig$DATA
  shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "Editors View.xlsx", datapath = up,
      stringsAsFactors = FALSE))
    d <- reactiveData()
    expect_false(is.null(d))
    expect_setequal(unique(d$TRIAL), c("A", "B"))
    # validation ran on upload and succeeded - the grid holds template
    # lines, not raw wide cells
    v <- reactiveDataValidated()
    expect_false(is.null(v))
    expect_identical(sort(unique(v$ROW)), sort(unique(origDATA$ROW)))
  })
})

test_that("arbitrary real-world headers parse; a bare arm name leaves N empty", {
  m <- rbind(
    c("Variable",            "Control (n=50)", "Treatment"),
    c("Age, mean (SD)",      "45.3 (12.1)",    "46.1 (11.8)"),
    c("Weight, mean (SD)",   "70 (10)",        "72 (11)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  blocks <- parseWideTable(f, "xlsx")
  expect_false(is.null(blocks))
  d <- blocks[[1]]$data
  expect_identical(nrow(d), 4L)
  expect_identical(d$N, c(50, NA, 50, NA))
  expect_identical(blocks[[1]]$arms$arm, c("Control", "Treatment"))
  expect_identical(d$MEAN, c(45.3, 46.1, 70, 72))
  expect_identical(d$ROUND_MEAN, c(1L, 1L, 0L, 0L))
})

test_that("untagged headers with arm names need data-row evidence, then parse", {
  m <- rbind(
    c("Characteristic",  "Placebo",       "Drug"),
    c("Age",             "45.3 ± 12.1", "46.1 ± 11.8"),
    c("BMI",             "24.2 (3.1)",    "24.8 (3.4)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  blocks <- parseWideTable(f, "xlsx")
  expect_false(is.null(blocks))
  d <- blocks[[1]]$data
  # "a +/- b" is mean/SD; untagged "a (b)" under a continuous label too
  expect_identical(d$ROW, c("Age", "Age", "BMI", "BMI"))
  expect_identical(d$SD, c(12.1, 11.8, 3.1, 3.4))
})

test_that("n (%) rows become a count column plus its complement", {
  m <- rbind(
    c("",                  "Arm 1 (n = 20)", "Arm 2 (n = 25)"),
    c("Age, mean (SD)",    "45.3 (12.1)",    "46.1 (11.8)"),
    c("Diabetes",          "5 (25%)",        "10 (40%)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  blocks <- parseWideTable(f, "xlsx")
  d <- blocks[[1]]$data
  dia <- d[d$ROW == "Diabetes", ]
  expect_identical(dia$Diabetes, c(5L, 10L))
  expect_identical(dia[["Not Diabetes"]], c(15L, 15L))
  expect_true(all(is.na(dia$MEAN)))
})

test_that("median rows: explicit IQR parses, range and unlabeled refuse", {
  m <- rbind(
    c("Variable",                     "Arm 1 (n = 20)", "Arm 2 (n = 22)"),
    c("Duration, median [Q1, Q3]",    "127 [98, 160]",  "133 [101, 155]"),
    c("Stay, median (range)",         "5 [2, 21]",      "6 [3, 19]"),
    c("Pain",                         "3 [2, 5]",       "4 [2, 6]"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  blocks <- parseWideTable(f, "xlsx")
  d <- blocks[[1]]$data
  dur <- d[d$ROW == "Duration", ]
  expect_identical(dur$MEAN, c(127, 133))
  expect_identical(dur$Q1, c(98, 101))
  expect_identical(dur$Q3, c(160, 155))
  expect_true(all(is.na(dur$SD)))
  # the two refusals carry their reasons
  sk <- blocks[[1]]$skipped
  expect_identical(nrow(sk), 2L)
  expect_match(sk$reason[sk$label == "Stay"], "range")
  expect_match(sk$reason[sk$label == "Pain"], "unlabeled interval")
})

test_that("trailing empty cells drop the line; interior gaps hold position", {
  m <- rbind(
    c("Variable",           "Arm 1 (n = 20)", "Arm 2 (n = 25)"),
    c("Age, mean (SD)",     "45.3 (12.1)",    "46.1 (11.8)"),
    c("Only 1, mean (SD)",  "50 (9)",         ""),
    c("Only 2, mean (SD)",  "",               "51 (8)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  d <- parseWideTable(f, "xlsx")[[1]]$data
  expect_identical(sum(d$ROW == "Only 1"), 1L)       # trailing: no line
  o2 <- d[d$ROW == "Only 2", ]
  expect_identical(nrow(o2), 2L)                     # interior: NA line
  expect_true(is.na(o2$MEAN[1]) && o2$MEAN[2] == 51)
})

test_that("an unreadable row is skipped with its reason, others still parse", {
  m <- rbind(
    c("Variable",          "Arm 1 (n = 20)", "Arm 2 (n = 25)"),
    c("Age, mean (SD)",    "45.3 (12.1)",    "46.1 (11.8)"),
    c("ASA class",         "I-II",           "mostly II"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  blocks <- parseWideTable(f, "xlsx")
  expect_identical(blocks[[1]]$skipped$label, "ASA class")
  expect_match(blocks[[1]]$skipped$reason, "not in a recognized format")
  expect_identical(unique(blocks[[1]]$data$ROW), "Age")
})

test_that("the template and example spreadsheets are NOT detected as wide", {
  # regression pin: the long template format must keep flowing to
  # validateData() - its header row (TRIAL/ROW/N/MEAN/SD) is the veto
  for (nm in c("Template.xlsx", "Example.xlsx")) {
    f <- system.file("extdata", nm, package = "IntegrityAnalysis")
    skip_if(f == "", paste(nm, "not installed"))
    expect_null(parseWideTable(f, "xlsx"))
  }
})

test_that("a sheet that is no kind of table returns NULL (fallback path)", {
  f <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(head(mtcars), f)
  expect_null(parseWideTable(f, "xlsx"))
})

test_that("the csv flavor parses like the xlsx", {
  lines <- c("Variable,Arm 1 (n = 15),Arm 2 (n = 17)",
             "\"Age, mean (SD)\",45.3 (12.1),46.1 (11.8)",
             "\"Sex, n\",,",
             "    MALE,10,12",
             "    FEMALE,5,5")
  f <- tempfile(fileext = ".csv")
  writeLines(lines, f)
  blocks <- parseWideTable(f, "csv")
  expect_false(is.null(blocks))
  d <- blocks[[1]]$data
  expect_true(is.na(blocks[[1]]$trial))     # csv: caller names the trial
  sex <- d[d$ROW == "Sex", ]
  expect_identical(sex$MALE, c(10L, 12L))
  expect_identical(sex$FEMALE, c(5L, 5L))
  age <- d[d$ROW == "Age", ]
  expect_identical(age$N, c(15, 17))
})

test_that("the vocacapsaicin xlsx shape parses completely (issue 17)", {
  # Steve's real Table 1 as a spreadsheet (2026-08-22): a two-line
  # header (names row, then a bare "N=36" row), a Total column, dash
  # separators before the tags, N (%) block headers with "a(b%)"
  # children, a mixed count row, "Mean(SD)" / "Median" statistic rows
  # under variable headings, and a bare "N (%)" count row under its
  # heading. Values are the paper's (the author supplied ground truth).
  m <- rbind(
    c("Characteristic",  "0.05 mg/mL", "0.15 mg/mL", "0.30 mg/mL",
      "Placebo",     "Total"),
    c("",                "N=36",       "N=36",       "N=38",
      "N=37",        "N=147"),
    c("Age (years)-Mean (SD)", "48.9(12.3)", "44.6(12.3)", "41.4(12.2)",
      "50.7(12.5)",  "46.4(12.7)"),
    c("Female sex-N(%)", "33(92%)",    "25(69%)",    "34(90%)",
      "31(84%)",     "123(84%)"),
    c("Race-N(%)",       "",           "",           "",
      "",            ""),
    c("White (Non-Hispanic)", "12(33%)", "9(25%)",   "11(29%)",
      "10(27%)",     "42(29%)"),
    c("Black",           "12(33%)",    "12(33%)",    "14(37%)",
      "14(38%)",     "52(35%)"),
    c("ASA Classification-N(%)", "",    "",           "",
      "",            ""),
    c("I",               "21(58%)",    "25(69%)",    "22(58%)",
      "22(60%)",     "90(61%)"),
    c("III",             "0",          "0",          "1(2%)",
      "0",           "1(1%)"),
    c("Weight (kg)",     "",           "",           "",
      "",            ""),
    c("Mean(SD)",        "76.4(16.5)", "82.9(19.1)", "78.6(13.8)",
      "77.2(15.1)",  "78.8(16.2)"),
    c("Median",          "71.9",       "82.3",       "78.7",
      "78.9",        "78"),
    c("NSAID Drug Use",  "",           "",           "",
      "",            ""),
    c("N (%)",           "4 (11%)",    "3 (8%)",     "6 (16%)",
      "3 (8%)",      "16 (11%)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  blocks <- parseWideTable(f, "xlsx")
  expect_false(is.null(blocks))
  b <- blocks[[1]]
  d <- b$data

  # Total dropped; Ns from the second header row
  expect_identical(nrow(b$arms), 4L)
  expect_equal(b$arms$N, c(36, 36, 38, 37), ignore_attr = TRUE)
  expect_false(any(vapply(d, function(col)
    any(col %in% c(147, 123L, 42L, 52L, 90L, 16L)), logical(1))))

  age <- d[d$ROW == "Age (years)", ]
  expect_identical(age$MEAN, c(48.9, 44.6, 41.4, 50.7))
  expect_identical(age$N, c(36, 36, 38, 37))

  fem <- d[d$ROW == "Female sex", ]
  expect_identical(fem[["Female sex"]], c(33L, 25L, 34L, 31L))
  expect_identical(fem[["Not Female sex"]], c(3L, 11L, 4L, 6L))

  race <- d[d$ROW == "Race", ]
  expect_identical(race[["White (Non-Hispanic)"]], c(12L, 9L, 11L, 10L))
  expect_identical(race[["Black"]], c(12L, 12L, 14L, 14L))
  expect_true(all(is.na(race$MEAN)))

  asa <- d[d$ROW == "ASA Classification", ]
  expect_identical(asa[["I"]], c(21L, 25L, 22L, 22L))
  expect_identical(asa[["III"]], c(0L, 0L, 1L, 0L))

  wt <- d[d$ROW == "Weight (kg)", ]
  expect_identical(wt$MEAN, c(76.4, 82.9, 78.6, 77.2))
  expect_identical(wt$SD, c(16.5, 19.1, 13.8, 15.1))

  ns <- d[d$ROW == "NSAID Drug Use", ]
  expect_identical(ns[["NSAID Drug Use"]], c(4L, 3L, 6L, 3L))
  expect_identical(ns[["Not NSAID Drug Use"]], c(32L, 33L, 32L, 34L))

  # the Median line skipped with the quartile reason, heading intact
  expect_identical(nrow(b$skipped), 1L)
  expect_match(b$skipped$reason[1], "median without quartiles")
  expect_match(b$skipped$label[1], "Weight")

  v <- vdShared(b$data)
  expect_false(v$FAIL)
})

test_that("a differing-N suffix comes back as that line's N", {
  m <- rbind(
    c("Variable",            "Arm 1 (n = 15)", "Arm 2 (n = 17)"),
    c("Age, mean (SD)",      "45.3 (12.1)",    "46.1 (11.8)"),
    c("Height, mean (SD)",   "165 (7); n = 14", "167 (7)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  d <- parseWideTable(f, "xlsx")[[1]]$data
  ht <- d[d$ROW == "Height", ]
  expect_identical(ht$N, c(14, 17))
  expect_identical(ht$MEAN, c(165, 167))
})

# --------------------------------------------------------------------------
# Steve's Ticagrelor sheet, 2026-09-02: "the rows with median (IQR) don't get
# parsed at all ... I can't type into the cells". Two defects, one report.
# --------------------------------------------------------------------------

test_that("one impossible arm drops that arm, not the whole variable", {
  # Aspirin's median 68.8 sits above its own Q3 of 64 - impossible, so that
  # arm cannot be analyzed. Ticagrelor's 62 (60-67) is perfectly usable and
  # used to be discarded with it, taking the anomaly out of sight as well.
  m <- rbind(
    c("Character",         "Ticagrelor (N=101)", "Aspirin (N = 99)"),
    c("Age, median (IQR)", "62 (60-67)",         "68.8 (59-64)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  b <- parseWideTable(f, "xlsx")[[1]]

  age <- b$data[b$data$ROW == "Age", ]
  expect_identical(nrow(age), 1L)            # the good arm survives, alone
  expect_identical(age$MEAN, 62)
  expect_identical(age$Q1, 60)
  expect_identical(age$Q3, 67)
  expect_identical(age$N, 101)

  # and the impossible arm is REPORTED, by name, rather than silently gone
  expect_identical(nrow(b$skipped), 1L)
  expect_match(b$skipped$label[1], "Aspirin")
  expect_match(b$skipped$reason[1], "outside its own", fixed = FALSE)
})

test_that("every arm impossible still skips the whole row, as before", {
  m <- rbind(
    c("Character",         "Arm 1 (n = 10)", "Arm 2 (n = 10)"),
    c("Age, median (IQR)", "80 (60-67)",     "68.8 (59-64)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  b <- parseWideTable(f, "xlsx")
  # No usable row at all -> parseWideTable declines the sheet entirely.
  expect_null(b)
})

test_that("a skipped median row still gets Q1/Q3 columns to type into", {
  # The skip reason tells the reader to "enter median/Q1/Q3 by hand". If the
  # only median rows were skipped, the grid used to carry no Q1 and no Q3
  # column, so there was nowhere to type them.
  m <- rbind(
    c("Character",    "Arm 1 (n = 20)", "Arm 2 (n = 20)"),
    c("TTR",          "7 (6-9)",        "7 (7-8)"),
    c("Age, mean (SD)", "45.3 (12.1)",  "46.1 (11.8)"))
  f <- writeRawXlsx(m, tempfile(fileext = ".xlsx"))
  b <- parseWideTable(f, "xlsx")[[1]]

  expect_true(all(c("Q1", "Q3") %in% names(b$data)))
  expect_match(b$skipped$reason[1], "unlabeled interval")
})
