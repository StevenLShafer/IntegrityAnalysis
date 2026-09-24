# test-loadsman-layouts.R - the three parser defects of the Loadsman corpus
# finding (docs/audits/2026-09-24-duplicate-rows-and-percent-as-sd-cowork.md,
# ISSUES.md issue 35), each rebuilt on a synthetic page so it cannot return.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1) at Steve       #
# Shafer's direction. The finding came from a Cowork session running the   #
# batch script over 52 randomised trials supplied by John Loadsman; its    #
# checkpoints were produced by a library built 2026-08-21, so the first   #
# defect (duplicated variables under a truncated and a full label) was    #
# ALREADY caught by the value-signature dedupe of 2026-08-25 on current   #
# code - the test here pins that, and the truncation itself is fixed.     #
# The other two were real on current code:                                 #
#   - a rotated download rail whose words' TOPS spanned less than a third  #
#     of the page kept its "Downloaded" over the table's "Mild" line;       #
#   - "18 (90)" in a table with no "%" anywhere was read as mean 18,       #
#     SD 90, though 90 is 18 as a percentage of the arm's 20.               #
# We cannot ship the articles; the pdf() device rebuilds the typography.  #
############################################################################

# ---- 1. the rotated rail is measured by extent, not by its words' tops ----
test_that("a rotated rail whose word tops span little but whose words are tall is stripped", {
  # the real geometry of Akkaya 2015 EJA page 2: five words at x = 22, tops
  # 134..318 (184 points of a 700-point page), but the URL alone is 120
  # points tall and the last token 156, so the rail's extent is 340
  upright <- data.frame(
    text = c("Catheter-related", "Mild", "Moderate", "Severe", "18", "(90)"),
    x = c(45, 45, 45, 45, 200, 220), y = c(121, 138, 147, 157, 138, 138),
    width = c(48, 12, 28, 20, 8, 14), height = 6, stringsAsFactors = FALSE)
  rail <- data.frame(
    text = c("Downloaded", "from", "http://journals.lww.com/ejanaesthesiology",
             "by", "Q+RFU1KzegAlaE94BVx1Xpg9hWm8sCHlQNEyX3G"),
    x = 22, y = c(134, 173, 187, 309, 318), width = 6,
    height = c(36, 13, 120, 6, 156), stringsAsFactors = FALSE)
  filler <- data.frame(text = "text", x = 300, y = c(60, 700), width = 16,
                       height = 6, stringsAsFactors = FALSE)
  out <- .ppStripRotatedText(rbind(upright, rail, filler))
  expect_false(any(out$text %in% rail$text))
  expect_true(all(upright$text %in% out$text))
})

# ---- 2. a row label that wraps onto the next line ---------------------------
wrappedLabelPdf <- function(file = file.path(tempdir(), "wrapped.pdf")) {
  vx <- c(300, 400, 500)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 2 Patient characteristics", adj = 0)),
    rowCells(110, "", c("Group R", "Group D", "Group S"), vx),
    rowCells(128, "", c("(n = 30)", "(n = 30)", "(n = 30)"), vx),
    rowCells(150, "Duration of surgery (min)", c("61.5 ± 34.0", "59.5 ± 25.1", "65.2 ± 20.5"), vx),
    rowCells(168, "Infusion duration of study", c("78.6 ± 32.2", "79.7 ± 28.1", "79.6 ± 30.5"), vx),
    list(list(x = 72, y = 180, text = "drug (min)", adj = 0)),
    rowCells(198, "Amount of intraoperative", c("561.7 ± 164.4", "562.0 ± 200.4", "556.7 ± 175.6"), vx),
    list(list(x = 72, y = 210, text = "fluid (ml)", adj = 0)),
    list(list(x = 72, y = 240, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a label's lower-case second line is joined to it, including on the last row", {
  r <- parseBaselineTableHeuristics(wrappedLabelPdf(), quiet = TRUE)
  expect_identical(sort(unique(r$data$ROW)),
                   sort(c("Duration of surgery", "Infusion duration of study drug",
                          "Amount of intraoperative fluid")))
  expect_identical(nrow(r$data), 9L)
  expect_identical(r$data$MEAN[r$data$ROW == "Amount of intraoperative fluid"],
                   c(561.7, 562.0, 556.7))
  # no continuation line became a block header, so nothing is skipped
  expect_identical(nrow(r$skipped), 0L)
})

test_that("a capitalised next line is the next variable, not a continuation", {
  f  <- file.path(tempdir(), "notwrapped.pdf")
  vx <- c(300, 400)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx),
    rowCells(128, "", c("(n = 15)", "(n = 17)"), vx),
    rowCells(150, "Weight", c("63 ± 13", "68 ± 12"), vx),
    list(list(x = 72, y = 168, text = "Sex, n (%)", adj = 0)),
    rowCells(186, "Male", c("10 (67)", "12 (71)"), vx, labelX = 82),
    list(list(x = 72, y = 220, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_true("Weight" %in% r$data$ROW)
  expect_false(any(grepl("^Weight Sex", r$data$ROW)))
  expect_true(any(grepl("^Male|^Sex", r$data$ROW)))
})

# ---- 3. counts and percentages with no "%" anywhere on the page -------------
countsNoPercentPdf <- function(file = file.path(tempdir(), "countsNoPct.pdf"),
                              withN = TRUE) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Characteristics of the patients", adj = 0)),
    rowCells(110, "", c("Group C", "Group P"), vx))
  if (withN) cells <- c(cells, rowCells(128, "", c("(n = 20)", "(n = 20)"), vx))
  cells <- c(cells,
    rowCells(150, "Catheter discomfort", c("18 (90)", "2 (10)"), vx),
    rowCells(168, "Mild",     c("8 (40)", "2 (10)"), vx, labelX = 82),
    rowCells(186, "Moderate", c("4 (20)", "1 (5)"),  vx, labelX = 82),
    rowCells(204, "Severe",   c("6 (30)", "0 (0)"),  vx, labelX = 82),
    rowCells(222, "Age (yr)", c("40 (12)", "39 (11)"), vx),
    list(list(x = 72, y = 250, text = "Data are presented as shown.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a (b) cells whose b is a as a percentage of the arm N in every arm are counts", {
  r <- parseBaselineTableHeuristics(countsNoPercentPdf(), quiet = TRUE)
  d <- r$data
  # the four count rows carry no mean or SD; "Age (yr)" - 40 (12) is not
  # 100 x 40 / 20 - keeps its mean and SD
  countRows <- d$ROW %in% c("Catheter discomfort", "Mild", "Moderate", "Severe")
  expect_true(all(is.na(d$MEAN[countRows])))
  expect_identical(d$MEAN[d$ROW == "Age"], c(40, 39))
  expect_identical(d$SD[d$ROW == "Age"], c(12, 11))
  catCols <- setdiff(names(d), c(.ppBaseColumns(), "Q1", "Q3"))
  expect_true(length(catCols) >= 2)
  # the counts themselves, not the percentages, are what the categories hold
  cr <- d[d$ROW == "Catheter discomfort", catCols]
  expect_true(any(unlist(cr) == 18, na.rm = TRUE))
  expect_false(any(unlist(cr) == 90, na.rm = TRUE))
  # and nothing about this table is a mean whose SD exceeds it
  cont <- !is.na(d$MEAN) & !is.na(d$SD)
  expect_false(any(d$SD[cont] > d$MEAN[cont]))
})

test_that("without an arm N the cells cannot vouch, and a table of such rows is flagged", {
  # no "(n = 20)" header: the identity has nothing to check against, the
  # rows fall to the vocabulary rules (mean (SD)), and the table-level
  # flag names what a reader should look at
  r <- parseBaselineTableHeuristics(countsNoPercentPdf(withN = FALSE), quiet = TRUE)
  d <- r$data
  cont <- !is.na(d$MEAN) & !is.na(d$SD)
  expect_true(sum(cont & d$SD > d$MEAN) >= 3)
  expect_true(any(grepl("SD larger than the mean", reviewFlags(r))))
})

# ---- 4. the hybrid merge: value duplicates dropped, distinct categories kept
test_that("the merge drops a model row whose values duplicate a deterministic row, and keeps ASA I and ASA II apart", {
  # a deterministic parse with one skipped line (so the fallback is consulted),
  # and a canned model reply: the same fluid volumes under a fuller label
  # (a duplicate by value), and two categorical rows "ASA I" / "ASA II"
  # whose counts differ (distinct variables that share a prefix)
  r0 <- parseBaselineTableHeuristics(wrappedLabelPdf(), quiet = TRUE)
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Group R", "n": 30}, {"name": "Group D", "n": 30}, {"name": "Group S", "n": 30}],
    "continuous": [
      {"label": "Intraoperative fluid volume, ml", "decimalsMean": 1,
       "values": [{"arm": "Group R", "n": 30, "mean": 561.7, "sd": 164.4},
                  {"arm": "Group D", "n": 30, "mean": 562.0, "sd": 200.4},
                  {"arm": "Group S", "n": 30, "mean": 556.7, "sd": 175.6}]}],
    "categorical": [
      {"label": "ASA I", "categories": ["Yes", "No"],
       "values": [{"arm": "Group R", "counts": [9, 21]}, {"arm": "Group D", "counts": [8, 22]}, {"arm": "Group S", "counts": [10, 20]}]},
      {"label": "ASA II", "categories": ["Yes", "No"],
       "values": [{"arm": "Group R", "counts": [21, 9]}, {"arm": "Group D", "counts": [22, 8]}, {"arm": "Group S", "counts": [20, 10]}]}]}',
    simplifyVector = FALSE)
  canned <- .ppAiToTemplate(reply, trial = r0$trial)
  fake <- structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = r0$caption, trial = r0$trial, notes = "", engine = "ai"),
    class = "ParsePDFTable")
  # the deterministic page has nothing open, so add a skipped line to make
  # the fallback consult the (mocked) model
  local_mocked_bindings(
    parseBaselineTableAI = function(...) fake,
    reviewFlags = function(x) "one table line could not be used: forced")
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(wrappedLabelPdf(), ai = "fallback", quiet = TRUE)
  expect_identical(out$engine, "hybrid")
  # the fluid volumes appear ONCE, under the deterministic label
  expect_identical(sum(out$data$ROW == "Amount of intraoperative fluid"), 3L)
  expect_false("Intraoperative fluid volume" %in% out$data$ROW)
  # ASA I and ASA II both survive, as two variables
  expect_identical(sum(out$data$ROW == "ASA I"), 3L)
  expect_identical(sum(out$data$ROW == "ASA II"), 3L)
  # and no (ROW, N, MEAN, SD) tuple is repeated anywhere
  cont <- out$data[!is.na(out$data$MEAN), c("ROW", "N", "MEAN", "SD")]
  expect_false(any(duplicated(cont)))
})
