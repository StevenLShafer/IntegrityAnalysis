# test-hybrid-merge-arms.R - the hybrid merge compares continuous variables
# arm by arm, and a header's "(n = k)" belongs to the name on its left
# (ISSUES.md issue 37, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's findings F2, F3, G1 and H2 on the Loadsman and Fujii    #
# corpora, each diagnosed read-only from its checkpoint:                   #
#   - a deterministic row that read only SOME arms never matched the       #
#     model's complete row by whole signature, so the variable survived    #
#     twice ("Height; cm" 2 of 3 arms on Anaesthesia2002_218; "BMI kg/m"   #
#     1 of 2 on Akkus 2020; every variable of PMID 9602596);               #
#   - a deterministic arm with no N never matched the model's arm with     #
#     one (Kulturoglu 2024), and the model's N was not taken;              #
#   - a model level column differing only by case from a deterministic    #
#     one made two columns that normalise to one (Sener 2008);             #
#   - "RIB group (n=24)  PECS group (n=24)  Control group (n=24)": each     #
#     count's midpoint fell nearer the NEXT column, arm 3 had no N.        #
# The model is mocked (a canned reply through .ppAiToTemplate), as         #
# test-loadsman-layouts.R does; the pages are synthetic.                   #
############################################################################

# A three-arm page whose header sets "(n" "=" "24)" as separate words to the
# RIGHT of each name, over data columns narrower than the headings - the
# Kulturoglu geometry, with the numbers as printed there.
kulturogluPdf <- function(file = file.path(tempdir(), "kulturoglu.pdf")) {
  cells <- list(
    list(x = 51,  y = 80,  text = "Table 1 Patient characteristics", adj = 0),
    list(x = 273, y = 100, text = "RIB", adj = 0),  list(x = 289, y = 100, text = "group", adj = 0),
    list(x = 311, y = 100, text = "(n", adj = 0),   list(x = 319, y = 100, text = "=", adj = 0),
    list(x = 326, y = 100, text = "24)", adj = 0),
    list(x = 346, y = 100, text = "PECS", adj = 0), list(x = 368, y = 100, text = "group", adj = 0),
    list(x = 390, y = 100, text = "(n", adj = 0),   list(x = 398, y = 100, text = "=", adj = 0),
    list(x = 405, y = 100, text = "24)", adj = 0),
    list(x = 425, y = 100, text = "Control", adj = 0), list(x = 454, y = 100, text = "group", adj = 0),
    list(x = 475, y = 100, text = "(n", adj = 0),   list(x = 484, y = 100, text = "=", adj = 0),
    list(x = 491, y = 100, text = "24)", adj = 0),
    list(x = 511, y = 100, text = "p value*", adj = 0))
  rows <- list(
    list("Age, year (mean ± SD)",  c("53 ± 9.4",   "51.9 ± 8.5", "52.6 ± 8.5"),  "0.913"),
    list("BMI, kg/m2 (mean ± SD)", c("28.1 ± 6.1", "28 ± 5.4",   "29.5 ± 10.5"), "0.731"),
    list("Duration of surgery, min", c("96.4 ± 17.9", "100.4 ± 12.3", "101.2 ± 12.6"), "0.55"))
  y <- 120
  for (r in rows) {
    cells <- c(cells, list(list(x = 178, y = y, text = r[[1]], adj = 0),
                           list(x = 273, y = y, text = r[[2]][1], adj = 0),
                           list(x = 346, y = y, text = r[[2]][2], adj = 0),
                           list(x = 425, y = y, text = r[[2]][3], adj = 0),
                           list(x = 511, y = y, text = r[[3]], adj = 0)))
    y <- y + 12
  }
  cells <- c(cells, list(list(x = 51, y = y + 12, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a header's (n = k) is read for the arm whose name precedes it, all three arms", {
  r <- parseBaselineTableHeuristics(kulturogluPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$N, c(24L, 24L, 24L))
  # the count's words never open the next arm's name (the real page reads
  # "RIB group / PECS group / Control group"; the pdf() device's metrics
  # place this synthetic header's words differently, so only the absence
  # of the stray "24)" is asserted here)
  expect_false(any(grepl("24\\)|\\(n", r$arms$arm)))
  expect_identical(r$data$N[grepl("^Age", r$data$ROW)], c(24L, 24L, 24L))
  v <- vdShared(r$data)
  expect_false(isTRUE(v$FAIL))
})

# ---- the merge, arm by arm ---------------------------------------------------
# a deterministic parse of a two-arm page whose "Height" reads normally and
# whose "Weight" is going to be compared against a model that read more
withMockedModel <- function(reply, pdfFile) {
  canned <- .ppAiToTemplate(reply, trial = "T")
  fake <- structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = "Table 1", trial = "T", notes = "", engine = "ai"),
    class = "ParsePDFTable")
  local_mocked_bindings(
    parseBaselineTableAI = function(...) fake,
    reviewFlags = function(x) "one table line could not be used: forced")
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  parseBaselineTable(pdfFile, ai = "fallback", quiet = TRUE)
}

twoArmPdf <- function(file = file.path(tempdir(), "twoArm.pdf"), nHeader = TRUE) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx))
  if (nHeader) cells <- c(cells, rowCells(128, "", c("(n = 15)", "(n = 17)"), vx))
  cells <- c(cells,
    rowCells(150, "Age (yr)",    c("45.3 ± 12.1", "46.1 ± 11.8"), vx),
    rowCells(168, "Height (cm)", c("165 ± 7",     "167 ± 7"),     vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a model variable whose arms contain the deterministic arms is the same variable: dropped, not doubled", {
  # the model calls Height "Height; cm" and reads the same two arms
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}],
    "continuous": [
      {"label": "Height; cm", "decimalsMean": 0,
       "values": [{"arm": "Control", "n": 15, "mean": 165, "sd": 7},
                  {"arm": "Treatment", "n": 17, "mean": 167, "sd": 7}]},
      {"label": "Weight; kg", "decimalsMean": 0,
       "values": [{"arm": "Control", "n": 15, "mean": 70, "sd": 11},
                  {"arm": "Treatment", "n": 17, "mean": 72, "sd": 12}]}],
    "categorical": []}', simplifyVector = FALSE)
  out <- withMockedModel(reply, twoArmPdf())
  expect_identical(out$engine, "hybrid")
  expect_identical(sum(out$data$ROW == "Height"), 2L)
  expect_false("Height; cm" %in% out$data$ROW)
  expect_identical(sum(out$data$ROW == "Weight; kg"), 2L)   # genuinely new: added
  cont <- out$data[!is.na(out$data$MEAN), c("ROW", "N", "MEAN", "SD")]
  expect_false(any(duplicated(cont[, c("N", "MEAN", "SD")])))
})

test_that("arms the deterministic pass did not read are appended under the deterministic label, and a missing N is taken from the model", {
  # the deterministic page has no N header and only two of the model's
  # three arms; the model has all three with their Ns
  f <- file.path(tempdir(), "threeArmPartial.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx),
    rowCells(150, "Age (yr)",    c("45.3 ± 12.1", "46.1 ± 11.8"), vx),
    rowCells(168, "Height (cm)", c("165 ± 7",     "167 ± 7"),     vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}, {"name": "Placebo", "n": 16}],
    "continuous": [
      {"label": "Height, cm", "decimalsMean": 0,
       "values": [{"arm": "Control", "n": 15, "mean": 165, "sd": 7},
                  {"arm": "Treatment", "n": 17, "mean": 167, "sd": 7},
                  {"arm": "Placebo", "n": 16, "mean": 166, "sd": 8}]}],
    "categorical": []}', simplifyVector = FALSE)
  out <- withMockedModel(reply, f)
  h <- out$data[out$data$ROW == "Height", ]
  expect_identical(nrow(h), 3L)                              # the third arm joined the deterministic variable
  expect_identical(sort(h$MEAN), c(165, 166, 167))
  expect_identical(h$N[order(h$MEAN)], c(15L, 16L, 17L))     # the model's Ns filled the deterministic blanks
  expect_false("Height, cm" %in% out$data$ROW)
  expect_true(any(grepl("arm N for 1 variable\\(s\\) taken from the model", out$flags)))
  expect_true(any(out$provenance$ROW == "Height" & out$provenance$ENGINE == "ai"))
})

test_that("a model level column differing only by case from a deterministic one is that column", {
  f <- file.path(tempdir(), "sexCase.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx),
    rowCells(128, "", c("(n = 35)", "(n = 35)"), vx),
    rowCells(150, "Age (yr)",          c("45.3 ± 12.1", "46.1 ± 11.8"), vx),
    rowCells(168, "Sex (male/female)", c("15/20", "21/14"), vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD or n.", adj = 0)))
  makeTablePdf(f, cells)
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 35}, {"name": "Treatment", "n": 35}],
    "continuous": [
      {"label": "Weight, kg", "decimalsMean": 0,
       "values": [{"arm": "Control", "n": 35, "mean": 70, "sd": 11},
                  {"arm": "Treatment", "n": 35, "mean": 72, "sd": 12}]}],
    "categorical": [
      {"label": "Gender", "categories": ["male", "female"],
       "values": [{"arm": "Control", "counts": [15, 20]}, {"arm": "Treatment", "counts": [21, 14]}]}]}',
    simplifyVector = FALSE)
  out <- withMockedModel(reply, f)
  nm <- names(out$data)
  expect_false(any(duplicated(tolower(nm))))                 # no "male" beside "Male"
  v <- vdShared(out$data)
  expect_false(isTRUE(v$FAIL))
  expect_identical(sum(v$issues$code == "structural"), 0L)
})
