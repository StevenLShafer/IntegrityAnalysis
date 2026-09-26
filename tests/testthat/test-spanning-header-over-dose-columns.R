# test-spanning-header-over-dose-columns.R - a heading that spans several
# columns names each of them, and a line of dose sub-heads before the data
# is a header line (ISSUES.md issue 143, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's arm-count audit (Anesth Analg 2005, PMID 15978307; four #
# arms of 30): "Flurbiprofen Axetil" over "25 mg | 50 mg | 75 mg", then    #
# "Vehicle"; the dose line read as data, the arms came out nameless and    #
# the rows beneath were skipped.                                           #
############################################################################

pm <- "\u00b1"

test_that("the dose sub-head test knows a line of doses from a data row", {
  w <- function(...) { t <- c(...); data.frame(text = t, x = cumsum(c(0, head(nchar(t) + 1, -1))) * 6, width = nchar(t) * 6, stringsAsFactors = FALSE) }
  expect_true(.ppDoseHeadLine(w("25", "mg", "50", "mg", "75", "mg", "Vehicle")))
  expect_true(.ppDoseHeadLine(w("0.5", "mg/kg", "1", "mg/kg", "Saline")))
  expect_false(.ppDoseHeadLine(w("Age", "45", "mg", "44", "7")))
  expect_false(.ppDoseHeadLine(w("Weight", "56", pm, "8", "54", pm, "8")))
  expect_false(.ppDoseHeadLine(w("Smokers", "12", "13")))
})

spanningHeadPdf <- function(file = file.path(tempdir(), "spanningHead.pdf")) {
  vx <- c(240, 313, 384, 455)
  cells <- c(
    list(list(x = 94, y = 30, text = "Patients were randomly allocated to one of four groups (n = 30 for each).", adj = 0)),
    list(list(x = 94, y = 60, text = "Table I. Baseline demographic and clinical characteristics of the study population (N = 120).", adj = 0)),
    # the drug's name centred over its three dose columns
    list(list(x = (vx[1] + vx[3]) / 2 + 10, y = 82, text = "Flurbiprofen Axetil", adj = 0.5)),
    rowCells(96, "", c("25 mg", "50 mg", "75 mg", "Vehicle"), vx + 10, labelX = 95),
    # no readable size line, as on the page (its "(n = 30)" is shattered in
    # the layer): every arm takes the Methods' "(n = 30 for each)"
    list(list(x = 95, y = 110, text = "Characteristic", adj = 0)),
    rowCells(130, "Age, y", c("41 (12)", "41 (12)", "41 (11)", "42 (12)"), vx + 10, labelX = 95),
    rowCells(148, "Height, cm", c("161 (8)", "160 (7)", "162 (8)", "161 (8)"), vx + 10, labelX = 95),
    rowCells(166, "Body weight, kg", c("57 (10)", "58 (10)", "56 (9)", "57 (11)"), vx + 10, labelX = 95),
    list(list(x = 94, y = 200, text = "Values are mean (SD).", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page names each dose column with the spanning drug heading and reads four arms of 30", {
  r <- parseBaselineTableHeuristics(spanningHeadPdf(), quiet = TRUE)
  expect_identical(r$arms$arm, c("Flurbiprofen Axetil 25 mg", "Flurbiprofen Axetil 50 mg", "Flurbiprofen Axetil 75 mg", "Vehicle"))
  expect_identical(r$arms$N, rep(30L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(41, 41, 41, 42))
  expect_identical(cont$MEAN[grepl("^Body weight", cont$ROW)], c(57, 58, 56, 57))
  expect_identical(nrow(r$skipped), 0L)
})
