# test-repeated-measures-layout.R - arms as ROWS under a Group column,
# timepoints as COLUMNS, only the Baseline column wanted.
#
# NOT the template's "long categorical layout" (LEVEL/CATEGORY columns,
# test-long-layout.R, .iaLongToWide()): that is an input FORMAT for counts;
# this is a printed TABLE SHAPE the PDF engine has to recognise.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1) with            #
# R/parseRepeatedMeasures.R, for ISSUES.md issue 34 (docs/audits/                  #
# 2026-09-24-repeated-measures-parse-finding-cowork.md).                    #
#                                                                          #
# THE DEFECT. On PMID 11375852 (Fujii, Anesth Analg 2001, retracted) the    #
# engine read a three-group, two-timepoint table as TWO arms - the Baseline #
# and after-drug COLUMNS - and each variable's three group rows as three    #
# variables. 36 rows for 18 baseline values, and every after-drug value     #
# filed as baseline data. Post-treatment values are a drug effect, not a    #
# random sample of one population; fed to a homogeneity test they can       #
# return a small p that has nothing to do with data integrity, with nothing #
# flagged. Worse than returning nothing.                                    #
#                                                                          #
# We cannot ship the article, so the typography is rebuilt with the pdf()   #
# device (the convention of test-real-layouts.R), reproducing the three     #
# features that broke the parse. EACH IS ASSERTED SEPARATELY, so that a     #
# single one regressing fails on its own reason rather than hiding inside   #
# a "does it parse" test that would pass again the moment any one of them   #
# came back.                                                               #
############################################################################

# The page: a Methods sentence stating the group size (no N in the table),
# then a caption, a stacked legend "(Group k)", a "Variable Group Baseline
# After" header, and three variables x three groups with a baseline AND an
# after-drug value on every row. The after-drug values are chosen to be
# distinct from every baseline value, so their presence is detectable.
repeatedMeasuresPdf <- function(dir = tempdir(), file = "long.pdf",
                          methods = "Twenty-four mongrel dogs were divided into three groups of eight each.",
                          blankBaseline = NULL) {
  # blankBaseline = c(variable index, group index): leave that one Baseline
  # cell empty, with its after-drug value still printed to the right
  f  <- file.path(dir, file)
  xG <- 250; xB <- 320; xA <- 400        # Group, Baseline, After column centres
  cells <- list(
    list(x = 72,  y = 60,  text = methods, adj = 0),
    list(x = 72,  y = 96,  text = "Table 1. Hemodynamic Data", adj = 0),
    list(x = 380, y = 116, text = "No study drug", adj = 0.5),
    list(x = 380, y = 130, text = "(Group 1)", adj = 0.5),
    list(x = 380, y = 148, text = "Sedative dose", adj = 0.5),
    list(x = 380, y = 162, text = "of midazolam", adj = 0.5),
    list(x = 380, y = 176, text = "(Group 2)", adj = 0.5),
    list(x = 380, y = 194, text = "Anesthetic dose", adj = 0.5),
    list(x = 380, y = 208, text = "of midazolam", adj = 0.5),
    list(x = 72,  y = 226, text = "Variable", adj = 0),
    list(x = xG,  y = 226, text = "Group",    adj = 0.5),
    list(x = xB,  y = 226, text = "Baseline", adj = 0.5),
    list(x = 380, y = 226, text = "(Group 3)", adj = 0.5))
  vars <- list(
    list(label = "HR (bpm)",    base = c("141 ± 15", "143 ± 10", "140 ± 12"),
                                after = c("162 ± 17", "163 ± 10", "173 ± 10")),
    list(label = "MAP (mm Hg)", base = c("130 ± 15", "132 ± 12", "131 ± 11"),
                                after = c("101 ± 17", "91 ± 11",  "80 ± 10")),
    list(label = "CO (L/min)",  base = c("2.2 ± 0.5", "2.2 ± 0.4", "2.3 ± 0.4"),
                                after = c("3.2 ± 0.6", "4.8 ± 0.4", "5.3 ± 0.5")))
  y <- 250
  for (vi in seq_along(vars)) for (g in 1:3) {
    v <- vars[[vi]]
    if (g == 1) cells <- c(cells, list(list(x = 72, y = y, text = v$label, adj = 0)))
    cells <- c(cells, list(list(x = xG, y = y, text = as.character(g), adj = 0.5)))
    if (!identical(as.integer(blankBaseline), c(vi, g)))
      cells <- c(cells, list(list(x = xB, y = y, text = v$base[g], adj = 0.5)))
    cells <- c(cells, list(list(x = xA, y = y, text = v$after[g], adj = 0.5)))
    y <- y + 18
  }
  cells <- c(cells, list(list(x = 72, y = y + 10,
                              text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
}

# every after-drug value on the synthetic page, as (MEAN, SD) pairs
afterPairs <- data.frame(
  MEAN = c(162, 163, 173, 101, 91, 80, 3.2, 4.8, 5.3),
  SD   = c(17, 10, 10, 17, 11, 10, 0.6, 0.4, 0.5))

test_that("the parse stops at the Baseline column: no after-drug value is read", {
  # THE assertion. 3 variables x 3 groups = 9 rows, and not one of the nine
  # after-drug (MEAN, SD) pairs appears anywhere in the output.
  r <- parseBaselineTableHeuristics(repeatedMeasuresPdf(), quiet = TRUE)
  d <- r$data
  expect_identical(nrow(d), 9L)
  seen <- paste(d$MEAN, d$SD)
  leaked <- paste(afterPairs$MEAN, afterPairs$SD) %in% seen
  expect_false(any(leaked),
               info = paste("after-drug values leaked into the parse:",
                            paste(paste(afterPairs$MEAN, afterPairs$SD)[leaked],
                                  collapse = ", ")))
  # and the baseline values are all there, each exactly once
  expect_identical(d$MEAN[grepl("^HR", d$ROW)],  c(141, 143, 140))
  expect_identical(d$SD[grepl("^HR", d$ROW)],    c(15, 10, 12))
  expect_identical(d$MEAN[grepl("^CO", d$ROW)],  c(2.2, 2.2, 2.3))
  expect_identical(sort(unique(d$ROW)), sort(c("HR", "MAP (mm Hg)", "CO (L/min)")))
})

test_that("a row with no Baseline cell does not take the after-drug value, and is reported", {
  # CodeRabbit on PR #330: the tolerance alone let an after-drug cell stand
  # in for a missing Baseline cell. MAP group 2's baseline is blank here;
  # its after value (91 +/- 11) sits 80 pt to the right, inside the old
  # tolerance. It must not be read, the row must be listed in `skipped`
  # with the reason, and every other row must still be read.
  r <- parseBaselineTableHeuristics(
    repeatedMeasuresPdf(file = "longBlank.pdf", blankBaseline = c(2L, 2L)),
    quiet = TRUE)
  d <- r$data
  expect_identical(nrow(d), 8L)
  expect_false(any(paste(d$MEAN, d$SD) %in% paste(afterPairs$MEAN, afterPairs$SD)))
  expect_identical(d$MEAN[d$ROW == "MAP (mm Hg)"], c(130, 131))
  expect_identical(nrow(r$skipped), 1L)
  expect_match(r$skipped$reason, "repeated-measures layout: no mean .* Baseline column beside group 2")
  expect_match(r$skipped$text, "91")
  # and the flag the user reads names the loss
  expect_true(any(grepl("could not be used", reviewFlags(r), fixed = TRUE)))
})

test_that("three arms, each named from the table's own (Group k) legend", {
  # The engine used to return two arms - <NA> and a header fragment - for a
  # three-group table. The names come from the stacked legend above the
  # header, so they carry both the phrase and the group number.
  r <- parseBaselineTableHeuristics(repeatedMeasuresPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_false(any(is.na(r$arms$arm)))
  expect_match(r$arms$arm[1], "No study drug")
  expect_match(r$arms$arm[2], "Sedative dose of midazolam")
  expect_match(r$arms$arm[3], "Anesthetic dose of midazolam")
  expect_true(all(grepl("\\(Group [123]\\)$", r$arms$arm)))
})

test_that("with no N in the table, the group size is recovered from the Methods", {
  # "divided into three groups of eight each" - the only place an animal
  # study states its N. Recovered, flagged as recovered, and refused when
  # the stated number of groups does not match the arms actually read.
  r <- parseBaselineTableHeuristics(repeatedMeasuresPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(8L, 3))
  expect_true(all(grepl("^document text", r$armNSource)))
  expect_true(all(r$data$N == 8))

  # a sentence naming a DIFFERENT number of groups is not applied
  r2 <- parseBaselineTableHeuristics(
    repeatedMeasuresPdf(file = "long2.pdf",
                  methods = "Animals were divided into four groups of eight each."),
    quiet = TRUE)
  expect_true(all(is.na(r2$arms$N)))

  # and with no such sentence at all, N stays honestly missing - the
  # reviewFlags path then says so, which is what the app shows the user
  r3 <- parseBaselineTableHeuristics(
    repeatedMeasuresPdf(file = "long3.pdf", methods = "Mongrel dogs were studied."),
    quiet = TRUE)
  expect_true(all(is.na(r3$arms$N)))
  expect_true(any(grepl("arm N is missing", reviewFlags(r3))))
})

test_that("the parsed long table validates and analyses end to end", {
  r <- parseBaselineTableHeuristics(repeatedMeasuresPdf(), quiet = TRUE)
  v <- vdShared(r$data)
  expect_false(isTRUE(v$FAIL))
  expect_identical(sum(v$issues$code == "structural"), 0L)
})

test_that("a wide table that merely mentions Group is left to the wide reader", {
  # The detector must not fire on an ordinary arms-as-columns table whose
  # header happens to say "Group" - that is the layout that must not move.
  f  <- file.path(tempdir(), "wideGroup.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1. Baseline characteristics", adj = 0)),
    rowCells(110, "Variable", c("Group A", "Group B"), vx),
    rowCells(128, "",         c("(n = 15)", "(n = 17)"), vx),
    rowCells(150, "Age (yr)",    c("45.3 ± 12.1", "46.1 ± 11.8"), vx),
    rowCells(168, "Weight (kg)", c("63 ± 13",     "68 ± 12"),     vx),
    rowCells(186, "Height (cm)", c("165 ± 7",     "167 ± 7"),     vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(nrow(r$data), 6L)
  expect_identical(r$arms$N, c(15L, 17L))
  expect_identical(r$arms$arm, c("Group A", "Group B"))
})
