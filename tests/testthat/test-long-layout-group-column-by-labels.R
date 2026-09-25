# test-long-layout-group-column-by-labels.R - the long (repeated-measures)
# layout whose group column has no header word, and whose later blocks
# lost their roman numerals, is still read: the column is found from the
# numerals that remain, and a value row with no group word takes the next
# index of its run (ISSUES.md issue 95, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24 AC1: five canine papers (PMIDs 10589648,       #
# 10475325, 11004073, 11573601, 10958102) whose Table 1 heads the         #
# timepoints but not the group column ("Variable Baseline Fatigued"), and #
# whose text layer keeps the I / II / III / IV only on the first block;   #
# the wide reader took the timepoints for arms and each row for a         #
# variable, thirty-six rows with N nowhere.                                #
############################################################################

unheadedPdf <- function(file = file.path(tempdir(), "unheadedGroup.pdf")) {
  vx <- c(160, 240)   # Baseline, Fatigued (no Group column header)
  row <- function(y, label, g, base, fat) c(
    if (nzchar(label)) list(list(x = 44, y = y, text = label, adj = 0)) else list(),
    if (nzchar(g)) list(list(x = 53, y = y, text = g, adj = 0)) else list(),
    list(list(x = vx[1], y = y, text = base, adj = 0),
         list(x = vx[2], y = y, text = fat, adj = 0)))
  cells <- c(
    list(list(x = 44, y = 40, text = "Dogs were randomly divided into four groups of ten each.", adj = 0)),
    list(list(x = 44, y = 80, text = "Table 1. Hemodynamic Data and Changes", adj = 0)),
    list(list(x = 62, y = 98, text = "Variable", adj = 0),
         list(x = vx[1], y = 98, text = "Baseline", adj = 0),
         list(x = vx[2], y = 98, text = "Fatigued", adj = 0)),
    list(list(x = 44, y = 114, text = "HR (bpm)", adj = 0)),
    row(128, "", "I",   "141 \u00b1 9",  "139 \u00b1 10"),
    row(140, "", "",    "142 \u00b1 10", "141 \u00b1 9"),     # the II the text layer lost
    row(152, "", "III", "141 \u00b1 10", "141 \u00b1 8"),
    row(164, "", "IV",  "142 \u00b1 11", "142 \u00b1 10"),
    list(list(x = 44, y = 180, text = "MAP (mm Hg)", adj = 0)),
    row(194, "", "", "122 \u00b1 7", "123 \u00b1 7"),           # a whole block without numerals
    row(206, "", "", "121 \u00b1 7", "121 \u00b1 10"),
    row(218, "", "", "121 \u00b1 7", "120 \u00b1 9"),
    row(230, "", "", "122 \u00b1 7", "122 \u00b1 6"),
    list(list(x = 44, y = 246, text = "CO (L/min)", adj = 0)),
    row(260, "", "", "2.0 \u00b1 0.6", "2.0 \u00b1 0.5"),
    row(272, "", "", "2.0 \u00b1 0.5", "2.0 \u00b1 0.6"),
    row(284, "", "", "2.1 \u00b1 0.4", "2.2 \u00b1 0.5"),
    row(296, "", "", "2.0 \u00b1 0.5", "2.1 \u00b1 0.6"),
    list(list(x = 44, y = 320, text = "Values are mean \u00b1 SD. I = Group I (no study drug), II = Group II, III = Group III, IV = Group IV.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("an unheaded group column is found from its numerals, and blocks that lost them are indexed by order", {
  r <- parseBaselineTableHeuristics(unheadedPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 4L)
  expect_identical(r$arms$N, rep(10L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(length(unique(cont$ROW)), 3L)
  expect_identical(nrow(cont), 12L)
  byRow <- split(cont$MEAN, factor(cont$ROW, levels = unique(cont$ROW)))
  expect_identical(byRow[[1]], c(141, 142, 141, 142))       # Baseline only, I / II / III / IV
  expect_identical(byRow[[2]], c(122, 121, 121, 122))
  expect_identical(byRow[[3]], c(2.0, 2.0, 2.1, 2.0))
  expect_false(any(grepl("Fatigued|Baseline", c(r$arms$arm, cont$ROW))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a wide table with a Baseline column and one stack of roman level rows is left to the wide reader", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "wideRoman.pdf")
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(90, "", c("Baseline (n = 20)", "Control (n = 22)"), vx),
    rowCells(108, "Age (yr)", c("45 \u00b1 12", "46 \u00b1 11"), vx),
    rowCells(126, "Weight (kg)", c("70 \u00b1 9", "71 \u00b1 8"), vx),
    rowCells(144, "ASA class", c("", ""), vx),
    rowCells(162, "I", c("12 (60)", "13 (59)"), vx, labelX = 80),
    rowCells(180, "II", c("6 (30)", "7 (32)"), vx, labelX = 80),
    rowCells(198, "III", c("2 (10)", "2 (9)"), vx, labelX = 80),
    rowCells(216, "Height (cm)", c("168 \u00b1 7", "167 \u00b1 8"), vx),
    list(list(x = 60, y = 246, text = "Values are mean \u00b1 SD or n (%).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$N, c(20L, 22L))
  expect_true(all(c("Age", "Weight", "Height") %in% r$data$ROW))
})
