# test-heading-with-bare-digit.R - in the long (repeated-measures) layout a
# heading line that carries a bare number - a subscript or superscript set
# as a word of its own - is a heading, not a data row, and the rows
# beneath it take its name (ISSUES.md issue 106, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD7 (PMID 10589648: the cardiac output rows    #
# under "CO (L/min-1)", whose superscript prints as "21", came out as     #
# "PAOP (mm Hg) 2", the heading above plus a dedupe suffix) and the "2"    #
# of "Pdi (cm H2O)" on 11573601 and 11004073.                              #
############################################################################

digitHeadingPdf <- function(file = file.path(tempdir(), "digitHeading.pdf")) {
  vx <- c(230, 320, 420)   # Group, Baseline, Fatigued
  row <- function(y, label, g, base, fat) c(
    if (nzchar(label)) list(list(x = 60, y = y, text = label, adj = 0)) else list(),
    if (nzchar(g)) list(list(x = vx[1], y = y, text = g, adj = 0.5)) else list(),
    list(list(x = vx[2], y = y, text = base, adj = 0.5),
         list(x = vx[3], y = y, text = fat, adj = 0.5)))
  cells <- c(
    list(list(x = 60, y = 50, text = "Dogs were randomly divided into three groups of eight each.", adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1. Hemodynamic Data", adj = 0)),
    list(list(x = 60, y = 108, text = "Variable", adj = 0),
         list(x = vx[1], y = 108, text = "Group", adj = 0.5),
         list(x = vx[2], y = 108, text = "Baseline", adj = 0.5),
         list(x = vx[3], y = 108, text = "Fatigued", adj = 0.5)),
    list(list(x = 60, y = 126, text = "PAOP (mm Hg)", adj = 0)),
    row(140, "", "I",   "8 \u00b1 2", "8 \u00b1 2"),
    row(152, "", "II",  "8 \u00b1 2", "8 \u00b1 1"),
    row(164, "", "III", "8 \u00b1 2", "8 \u00b1 2"),
    # the superscript of "L/min-1" set as its own word, "21", on the heading line
    list(list(x = 60, y = 182, text = "CO (L/min", adj = 0), list(x = 108, y = 182, text = "21", adj = 0), list(x = 118, y = 182, text = ")", adj = 0)),
    row(196, "", "I",   "2.0 \u00b1 0.3", "2.1 \u00b1 0.4"),
    row(208, "", "II",  "2.2 \u00b1 0.3", "1.9 \u00b1 0.3"),
    row(220, "", "III", "2.1 \u00b1 0.3", "1.5 \u00b1 0.3"),
    # the subscript of "H2O" set as its own word on the heading line
    list(list(x = 60, y = 238, text = "Pdi (cm H", adj = 0), list(x = 98, y = 238, text = "2", adj = 0), list(x = 104, y = 238, text = "O)", adj = 0)),
    row(252, "20-Hz stimulation", "I",   "15.9 \u00b1 1.5", "11.8 \u00b1 1.4"),
    row(264, "", "II",  "15.4 \u00b1 1.3", "12.1 \u00b1 1.6"),
    row(276, "", "III", "15.5 \u00b1 1.6", "12.1 \u00b1 1.8"),
    list(list(x = 60, y = 310, text = "Values are mean \u00b1 SD. Group I = no study drug, Group II = low-dose, Group III = high-dose.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a heading line carrying a bare number names the rows beneath it", {
  r <- parseBaselineTableHeuristics(digitHeadingPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  cont <- r$data[!is.na(r$data$MEAN), ]
  rows <- unique(cont$ROW)
  expect_identical(length(rows), 3L)
  expect_true(any(grepl("^PAOP", rows)))
  expect_true(any(grepl("^CO", rows)))
  expect_true(any(grepl("^Pdi.*20.Hz stimulation$", rows)))
  expect_false(any(grepl("PAOP.* 2$|Unnamed", rows)))
  expect_identical(cont$MEAN[grepl("^CO", cont$ROW)], c(2.0, 2.2, 2.1))
  expect_identical(cont$MEAN[grepl("^Pdi", cont$ROW)], c(15.9, 15.4, 15.5))
})
