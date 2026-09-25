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

test_that("a lower-case category header with indented children is a header, not a continuation", {
  # CodeRabbit on PR #336: "sex, n (%)" in a manuscript that does not
  # capitalise passes the typography test; eaten as the continuation of
  # the row above, its indented children would lose their header and be
  # skipped as bare numbers. The indented data line beneath it says it
  # is a header.
  f  <- file.path(tempdir(), "lowerHeader.pdf")
  vx <- c(300, 400)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx),
    rowCells(128, "", c("(n = 15)", "(n = 17)"), vx),
    rowCells(150, "weight, kg", c("63 ± 13", "68 ± 12"), vx),
    list(list(x = 72, y = 168, text = "sex, n (%)", adj = 0)),
    rowCells(186, "male",   c("10 (67)", "12 (71)"), vx, labelX = 82),
    rowCells(204, "female", c("5 (33)",  "5 (29)"),  vx, labelX = 82),
    list(list(x = 72, y = 240, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data
  expect_true(any(grepl("^weight", d$ROW)))
  expect_false(any(grepl("^weight, kg sex", d$ROW)))
  # the header survived and its children are counts under it
  sexRows <- d[grepl("^sex", d$ROW), ]
  expect_true(nrow(sexRows) >= 2)
  expect_true(all(is.na(sexRows$MEAN)))
  expect_identical(nrow(r$skipped), 0L)
})

test_that("a level column named from a label never spells a header word the normaliser renames", {
  # The corpus session's F4 on PR #336 (Peker 2020 IJMS): reading the label
  # "Need for rescue medication (number of patients)" whole named the two
  # parts of its "12/30" cells "... (number of patients) 1" and "... 2";
  # the normaliser turns any column containing NUMBER into N, and the
  # table was refused structurally. The name is respelled before it
  # becomes a column; validation passes; the counts are intact.
  expect_identical(.iaSafeColumnName("Need for rescue medication (number of patients) 1"),
                   "Need for rescue medication (no. of patients) 1")
  expect_identical(.iaSafeColumnName("Trial of labour"), "trl of labour")
  expect_identical(.iaSafeColumnName("Brown"), "Brown")     # ROW is not unconditional
  expect_identical(.iaLevelColumnName("Category", "Number"), "category no.")
  f  <- file.path(tempdir(), "numberLabel.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Demographics and clinical data", adj = 0)),
    rowCells(110, "", c("Group A", "Group B"), vx),
    rowCells(128, "", c("(n = 30)", "(n = 30)"), vx),
    rowCells(150, "Age (years)", c("41 ± 9", "43 ± 10"), vx),
    rowCells(168, "Need for rescue medication (number of patients)", c("12/18", "8/22"), vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD or n/n.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data
  expect_false(any(grepl("(?i)number", setdiff(names(d), .ppBaseColumns()), perl = TRUE)))
  v <- vdShared(d)
  expect_false(isTRUE(v$FAIL))
  expect_identical(sum(v$issues$code == "structural"), 0L)
  lv <- grep("(?i)rescue", names(d), value = TRUE)
  expect_true(length(lv) >= 2)
  expect_true(any(unlist(d[, lv]) == 12, na.rm = TRUE))

  # the sanitiser reaches the COLUMN only: a binary n (%) row keeps its
  # printed label as ROW (the hybrid merge matches the model's rows by
  # label), while its level column is respelled (CodeRabbit on PR #336)
  f2 <- file.path(tempdir(), "numberBinary.pdf")
  cells2 <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Group A", "Group B"), vx),
    rowCells(128, "", c("(n = 30)", "(n = 30)"), vx),
    rowCells(150, "Age (years)", c("41 ± 9", "43 ± 10"), vx),
    rowCells(168, "Number of failed attempts, n (%)", c("12 (40)", "9 (30)"), vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(f2, cells2)
  r2 <- parseBaselineTableHeuristics(f2, quiet = TRUE)
  expect_true(any(grepl("^Number of failed attempts", r2$data$ROW)))
  expect_false(any(grepl("(?i)number", setdiff(names(r2$data), .ppBaseColumns()), perl = TRUE)))
  expect_true(any(grepl("^no\\. of failed attempts", names(r2$data))))
  v2 <- vdShared(r2$data)
  expect_false(isTRUE(v2$FAIL))
})

# ---- 3. counts and percentages with no "%" anywhere on the page -------------
countsNoPercentPdf <- function(file = file.path(tempdir(), "countsNoPct.pdf"),
                              withN = TRUE) {
  # three arms of 20 with DISTINCT cells: at integer precision the rule
  # needs three independent (count, bracket, N) tuples
  vx <- c(280, 380, 480)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Characteristics of the patients", adj = 0)),
    rowCells(110, "", c("Group C", "Group P", "Group S"), vx))
  if (withN) cells <- c(cells, rowCells(128, "", c("(n = 20)", "(n = 20)", "(n = 20)"), vx))
  cells <- c(cells,
    rowCells(150, "Catheter discomfort", c("18 (90)", "2 (10)", "14 (70)"), vx),
    rowCells(168, "Mild",     c("8 (40)", "2 (10)", "9 (45)"), vx, labelX = 82),
    rowCells(186, "Moderate", c("4 (20)", "1 (5)",  "3 (15)"), vx, labelX = 82),
    rowCells(204, "Severe",   c("6 (30)", "0 (0)",  "1 (5)"),  vx, labelX = 82),
    rowCells(222, "Age (yr)", c("40 (12)", "39 (11)", "41 (13)"), vx),
    list(list(x = 72, y = 250, text = "Data are presented as shown.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("two arms printing the same integer values are one check, not two: a genuine mean (SD) stays", {
  # PMID 16792606 on the misparse corpus: "Age 43 (15)" in arms of 280 and
  # 279 satisfies 100 x 43 / 280 = 15.4 -> 15 at integer precision, and the
  # two identical cells are not independent evidence. The row is a mean.
  f  <- file.path(tempdir(), "ageCoincidence.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Demographic and morphometric data", adj = 0)),
    rowCells(110, "", c("Oxygen", "Control"), vx),
    rowCells(128, "", c("(n = 280)", "(n = 279)"), vx),
    rowCells(150, "Age; years", c("43 (15)", "43 (15)"), vx),
    rowCells(168, "Duration of anaesthesia; min", c("139 (80)", "137 (77)"), vx),
    list(list(x = 72, y = 200, text = "Values are mean (SD).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  age <- r$data[grepl("^Age", r$data$ROW), ]
  expect_identical(age$MEAN, c(43, 43))
  expect_identical(age$SD, c(15, 15))
})

test_that("a caption's table anchors are listed, and the straddle loses only to a split twin", {
  # PMID 16738291: the full-width candidate joined "TABLE I Baseline
  # characteristics" and "TABLE III Treatment outcomes" into one caption
  # and, once it had one more usable row, outscored the single-column
  # table, filing outcome values under Age and Height. The dock is
  # applied at candidate level, only when a single-anchor candidate for
  # the same first table exists on the page (PMIDs 15681941 and 12193491
  # showed why: a page with no split, and prose running onto the caption).
  expect_identical(.ppCaptionAnchorList("TABLE I Baseline characteristics TABLE III Treatment outcomes"),
                   c("table i", "table iii"))
  expect_identical(.ppCaptionAnchorList("Table 1. Patient Characteristics Table 3. Findings"),
                   c("table 1", "table 3"))
  expect_identical(.ppCaptionAnchorList("Table 1 Patient characteristics (see also the table of outcomes)"),
                   "table 1")
  expect_identical(.ppCaptionAnchorList(NA_character_), character(0))
  # .ppCaptionScore itself is untouched by the anchor count
  expect_identical(.ppCaptionScore("TABLE I Baseline characteristics TABLE III Treatment outcomes"),
                   .ppCaptionScore("TABLE I Baseline characteristics"))

  # the rule itself, on hand-built candidate lists: (a) a twin on the same
  # page sets the straddle aside; (b) a prose candidate whose anchor is
  # mid-sentence is not a twin; (c) a twin on another page is not a twin;
  # (d) a caption running into prose ("... (Table II)") with no twin is
  # left alone
  mk <- function(page, caption, score = 8) list(page = page, caption = caption, capScore = score)
  a <- .ppSetAsideStraddles(list(
    mk(4, "TABLE I Baseline characteristics TABLE III Treatment outcomes"),
    mk(4, "TABLE I Baseline characteristics"),
    mk(4, "TABLE III Treatment outcomes", 0)))
  expect_identical(vapply(a, `[[`, numeric(1), "capScore"), c(-100, 8, 0))
  b <- .ppSetAsideStraddles(list(
    mk(4, "Table 1. Patient Characteristics Table 3. Findings of MRI"),
    mk(4, "sented in table 1. The CSF volume and velocity before", 3)))
  expect_identical(vapply(b, `[[`, numeric(1), "capScore"), c(8, 3))
  cc <- .ppSetAsideStraddles(list(
    mk(4, "TABLE I Baseline characteristics TABLE III Treatment outcomes"),
    mk(5, "TABLE I Baseline characteristics")))
  expect_identical(vapply(cc, `[[`, numeric(1), "capScore"), c(8, 8))
  d <- .ppSetAsideStraddles(list(
    mk(4, "TABLE I Patient characteristics and preoperative risk score (Table II)."),
    mk(4, "TABLE III Patient outcome in ICU", -4)))
  expect_identical(vapply(d, `[[`, numeric(1), "capScore"), c(8, -4))

  # and a page the column splitter does NOT split - a baseline table on
  # the left and an outcome table on the right, both under one full-width
  # band - has no twin, so the straddle is read: the documented limit of
  # the rule, pinned so a change to it is a deliberate one
  f <- file.path(tempdir(), "sideBySide.pdf")
  lx <- c(190, 260); rx <- c(470, 540)
  cells <- c(
    list(list(x = 60,  y = 80, text = "TABLE I Baseline characteristics", adj = 0)),
    list(list(x = 340, y = 80, text = "TABLE III Treatment outcomes", adj = 0)),
    rowCells(104, "", c("Tuohy", "Sprotte"), lx, labelX = 60),
    rowCells(104, "", c("Tuohy", "Sprotte"), rx, labelX = 340),
    rowCells(120, "", c("(n = 537)", "(n = 532)"), lx, labelX = 60),
    rowCells(120, "", c("(n = 537)", "(n = 532)"), rx, labelX = 340),
    rowCells(140, "Age",    c("30.3 ± 5.2", "30.1 ± 5.4"), lx, labelX = 60),
    rowCells(140, "Onset, min", c("84.7 ± 17.3", "68.2 ± 25.3"), rx, labelX = 340),
    rowCells(158, "Weight", c("79.5 ± 14.9", "80.4 ± 15.8"), lx, labelX = 60),
    rowCells(158, "Duration, h", c("1.4 ± 0.8", "1.4 ± 0.7"), rx, labelX = 340),
    rowCells(176, "Height", c("163.9 ± 7.3", "164.4 ± 7.1"), lx, labelX = 60),
    rowCells(176, "Failed blocks", c("12 (2)", "9 (2)"), rx, labelX = 340),
    list(list(x = 60, y = 210, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_match(r$caption, "^TABLE I Baseline characteristics")
  expect_identical(length(.ppCaptionAnchorList(r$caption)), 2L)   # the straddle, read whole
  expect_identical(nrow(r$arms), 4L)
})

test_that("a (b) cells whose b is a as a percentage of the arm N in every arm are counts", {
  r <- parseBaselineTableHeuristics(countsNoPercentPdf(), quiet = TRUE)
  d <- r$data
  # the four count rows carry no mean or SD; "Age (yr)" - 40 (12) is not
  # 100 x 40 / 20 - keeps its mean and SD
  countRows <- d$ROW %in% c("Catheter discomfort", "Mild", "Moderate", "Severe")
  expect_true(all(is.na(d$MEAN[countRows])))
  expect_identical(d$MEAN[d$ROW == "Age"], c(40, 39, 41))
  expect_identical(d$SD[d$ROW == "Age"], c(12, 11, 13))
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
