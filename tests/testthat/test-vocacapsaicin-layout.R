# The vocacapsaicin Table 1 patterns (2026-08-22).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-22.
# Steve Shafer supplied four renderings of the baseline table of his own
# vocacapsaicin trial (he is first author, so every value has ground
# truth): the published PDF, the submitted .docx, and the table alone as
# .docx and .xlsx. The published-PDF parse surfaced seven distinct
# engine defects, each repaired in R/parseBaselineTableHeuristics.R /
# pageLayout.R / utils.R and pinned here on a synthetic PDF carrying the
# same structures (the real PDF is copyrighted and stays out of the
# repository; the VALUES are facts and appear in the assertions).
#
# The patterns, in table order:
#   - a Total column (N = 147) that is not a treatment arm;
#   - "Female sex, N (%)  33 (92) ..." - n (%) cells without % signs;
#   - "Race, N (%)" block: children are levels of ONE variable, count
#     first, even though a footnote-like line says "mean (SD)";
#   - "ASA ... N (%)" block with a mixed row: "III  0.0  0.0  1 (2)  0.0";
#   - "Weight, kg" / "Body mass index, kg/m 2" headings with "Mean (SD)"
#     and "Median" statistic rows beneath (the exponent "2" must not
#     turn the BMI heading into a data line);
#   - a wrapped label leaving its "N (%)" tag on the next line;
#   - the rotated "Downloaded from ..." watermark rail (unit-tested on
#     fabricated words - R's pdf() device cannot produce one).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
}))

vocaPdf <- function(dir = tempdir()) {
  f  <- file.path(dir, "voca.pdf")
  vx <- c(230, 300, 370, 440, 510)
  cells <- c(
    list(list(x = 72, y = 70, text = "Table 1. Baseline Characteristics",
              adj = 0)),
    rowCells(96, "Characteristic",
             c("0.05 mg/ml", "0.15 mg/ml", "0.30 mg/ml", "Placebo",
               "Total"), vx),
    rowCells(112, "",
             c("(N = 36)", "(N = 36)", "(N = 38)", "(N = 37)",
               "(N = 147)"), vx),
    rowCells(124, "Mean age (SD), yr",
             c("48.9 (12.3)", "44.6 (12.3)", "41.4 (12.2)", "50.7 (12.5)",
               "46.4 (12.7)"), vx),
    rowCells(142, "Female sex, N (%)",
             c("33 (92)", "25 (69)", "34 (90)", "31 (84)", "123 (84)"), vx),
    rowCells(160, "Race, N (%)", c("", "", "", "", ""), vx),
    rowCells(178, "White (non-Hispanic)",
             c("12 (33)", "9 (25)", "11 (29)", "10 (27)", "42 (29)"), vx,
             labelX = 82),
    rowCells(196, "White (Hispanic)",
             c("8 (22)", "11 (31)", "8 (21)", "12 (32)", "39 (27)"), vx,
             labelX = 82),
    rowCells(214, "Black",
             c("12 (33)", "12 (33)", "14 (37)", "14 (38)", "52 (35)"), vx,
             labelX = 82),
    rowCells(232, "Other",
             c("4 (11)", "4 (11)", "5 (13)", "1 (3)", "14 (10)"), vx,
             labelX = 82),
    rowCells(250, "ASA Physical Status, N (%)", c("", "", "", "", ""), vx),
    rowCells(268, "I",
             c("21 (58)", "25 (69)", "22 (58)", "22 (60)", "90 (61)"), vx,
             labelX = 82),
    rowCells(286, "II",
             c("15 (42)", "11 (31)", "15 (40)", "15 (41)", "56 (38)"), vx,
             labelX = 82),
    rowCells(304, "III",
             c("0.0", "0.0", "1 (2)", "0.0", "1 (1)"), vx, labelX = 82),
    rowCells(322, "Weight, kg", c("", "", "", "", ""), vx),
    rowCells(340, "Mean (SD)",
             c("76.4 (16.5)", "82.9 (19.1)", "78.6 (13.8)", "77.2 (15.1)",
               "78.8 (16.2)"), vx, labelX = 82),
    rowCells(358, "Median",
             c("71.9", "82.3", "78.7", "78.9", "78.0"), vx, labelX = 82),
    rowCells(376, "Body mass index, kg/m 2", c("", "", "", "", ""), vx),
    rowCells(394, "Mean (SD)",
             c("28.4 (5.6)", "28.8 (5.0)", "28.3 (4.8)", "28.3 (5.1)",
               "28.5 (5.1)"), vx, labelX = 82),
    rowCells(412, "Median",
             c("27.3", "27.9", "28.6", "27.6", "27.6"), vx, labelX = 82),
    rowCells(430, "Nonsteroidal anti-inflammatory",
             c("4 (11)", "3 (8)", "6 (16)", "3 (8)", "16 (11)"), vx),
    rowCells(448, "drugs, N (%)", c("", "", "", "", ""), vx),
    list(list(x = 72, y = 478,
              text = "Values are presented as mean (SD) or N (%).",
              adj = 0))
  )
  makeTablePdf(f, cells)
}

test_that("the vocacapsaicin layout parses completely and correctly", {
  res <- parseBaselineTableHeuristics(vocaPdf(), quiet = TRUE)
  d <- res$data

  # the Total column is dropped; four real arms with their printed Ns
  expect_identical(nrow(res$arms), 4L)
  expect_equal(res$arms$N, c(36, 36, 38, 37), ignore_attr = TRUE)
  expect_false(any(grepl("(?i)total", res$arms$arm, perl = TRUE)))
  expect_false(any(d$N %in% 147))

  age <- d[grepl("age", d$ROW, ignore.case = TRUE), ]
  expect_identical(age$MEAN, c(48.9, 44.6, 41.4, 50.7))
  expect_identical(age$SD, c(12.3, 12.3, 12.2, 12.5))

  # n (%) without % signs: counts plus complements, arm N row-local
  fem <- d[d$ROW == "Female sex", ]
  expect_identical(fem[["Female sex"]], c(33L, 25L, 34L, 31L))
  expect_identical(fem[["Not Female sex"]], c(3L, 11L, 4L, 6L))

  # the N (%) block: ONE Race variable, all four levels, counts not
  # means - even though the footnote says "mean (SD)". (The pdf()
  # device renders "-" as a Unicode minus, so hyphenated column names
  # are found by pattern.)
  race <- d[d$ROW == "Race", ]
  expect_identical(nrow(race), 4L)
  whiteNH <- grep("^White [(]non.Hispanic[)]$", names(d), value = TRUE)
  expect_identical(race[[whiteNH]], c(12L, 9L, 11L, 10L))
  expect_identical(race[["White (Hispanic)"]], c(8L, 11L, 8L, 12L))
  expect_identical(race[["Black"]], c(12L, 12L, 14L, 14L))
  expect_identical(race[["Other"]], c(4L, 4L, 5L, 1L))
  expect_true(all(is.na(race$MEAN)))

  # the mixed III row: "0.0" cells and a "1 (2)" cell are all counts
  asa <- d[d$ROW == "ASA Physical Status", ]
  expect_identical(asa[["I"]], c(21L, 25L, 22L, 22L))
  expect_identical(asa[["II"]], c(15L, 11L, 15L, 15L))
  expect_identical(asa[["III"]], c(0L, 0L, 1L, 0L))

  # statistic rows take their variable heading's name; the heading with
  # the superscript exponent survives as a heading
  wt <- d[d$ROW == "Weight, kg", ]
  expect_identical(wt$MEAN, c(76.4, 82.9, 78.6, 77.2))
  bmi <- d[grepl("^Body mass index", d$ROW), ]
  expect_identical(bmi$MEAN, c(28.4, 28.8, 28.3, 28.3))
  expect_identical(bmi$SD, c(5.6, 5.0, 4.8, 5.1))

  # the wrapped label: its "N (%)" tag on the next line makes it counts
  ns <- d[grepl("^Nonsteroidal", d$ROW), ]
  nsCol <- grep("^Nonsteroidal anti.inflammatory$", names(d), value = TRUE)
  expect_identical(ns[[nsCol]], c(4L, 3L, 6L, 3L))
  expect_identical(ns[[paste("Not", nsCol)]], c(32L, 33L, 32L, 34L))

  # the two Median lines are the only skips, with the quartile reason
  expect_identical(nrow(res$skipped), 2L)
  expect_true(all(grepl("median without quartiles", res$skipped$reason)))

  # and the whole thing validates for the app
  v <- shiny::isolate(validateData(d))
  expect_false(v$FAIL)
})

test_that("the rotated watermark rail is stripped; narrow upright words survive", {
  upright <- data.frame(
    text = c("Weight,", "kg", "76.4", "(16.5)", "yr", "Age"),
    x = c(72, 110, 230, 260, 130, 72),
    y = c(100, 100, 100, 100, 130, 130),
    width = c(35, 5, 20, 28, 5, 18), height = 11,
    stringsAsFactors = FALSE)
  rail <- data.frame(
    text = c("Downloaded", "from", "http://pubs.example.org/x", "by",
             "Stanford", "on"),
    x = 560, y = c(100, 140, 160, 480, 500, 560),
    width = 5, height = c(33, 11, 311, 6, 22, 6),
    stringsAsFactors = FALSE)
  out <- .ppStripRotatedText(rbind(upright, rail))
  expect_identical(sort(out$text), sort(upright$text))
  # a page with no rail is untouched, including its narrow words
  out2 <- .ppStripRotatedText(rbind(upright, upright, upright))
  expect_identical(nrow(out2), 18L)
})

test_that("label cleaning keeps qualifiers and strips units", {
  expect_identical(.ppCleanLabel("White (Hispanic)"), "White (Hispanic)")
  expect_identical(.ppCleanLabel("Weight (kg)"), "Weight")
  expect_identical(.ppCleanLabel("Age (yr)"), "Age")
  expect_identical(.ppCleanLabel("MAP (mmHg)"), "MAP")
  expect_identical(.ppCleanLabel("Mean (SD)"), "Mean")
  # control characters (superscript footnote markers gone wrong) vanish
  expect_identical(.ppCleanLabel("\aBlack"), "Black")
})
