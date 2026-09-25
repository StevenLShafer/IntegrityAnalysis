# test-long-layout-heading-rows.R - in the long (repeated-measures) layout a
# row whose label starts with a number keeps it, and a variable printed as a
# heading above its group rows names them (ISSUES.md issue 91, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 23 on Fujii 2003 (PMID 12933396): the Pdi and     #
# %Edi rows - "20-Hz stimulation" / "100-Hz stimulation" under a heading   #
# on a line of its own - came out as "Unnamed" ... "Unnamed 6", eight of   #
# the table's ten variables nameless while every number was right.        #
############################################################################

headingPdf <- function(file = file.path(tempdir(), "longHeading.pdf")) {
  vx <- c(230, 320, 420)   # Group, Baseline, Fatigued
  row <- function(y, label, g, base, fat) c(
    if (nzchar(label)) list(list(x = 60, y = y, text = label, adj = 0)) else list(),
    if (nzchar(g)) list(list(x = vx[1], y = y, text = g, adj = 0.5)) else list(),
    list(list(x = vx[2], y = y, text = base, adj = 0.5),
         list(x = vx[3], y = y, text = fat, adj = 0.5)))
  cells <- c(
    list(list(x = 60, y = 50, text = "Dogs were randomly divided into three groups of eight each.", adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1. Changes in Hemodynamics, Pdi, and %Edi", adj = 0)),
    list(list(x = 60, y = 108, text = "Variable", adj = 0),
         list(x = vx[1], y = 108, text = "Group", adj = 0.5),
         list(x = vx[2], y = 108, text = "Baseline", adj = 0.5),
         list(x = vx[3], y = 108, text = "Fatigued", adj = 0.5)),
    row(126, "HR (bpm)", "I", "140 \u00b1 13", "141 \u00b1 14"),
    row(138, "", "II", "140 \u00b1 10", "139 \u00b1 10"),
    row(150, "", "III", "139 \u00b1 11", "138 \u00b1 12"),
    list(list(x = 60, y = 168, text = "Pdi (cm H2O)", adj = 0)),
    row(186, "20-Hz stimulation", "I", "15.9 \u00b1 1.5", "11.8 \u00b1 1.4"),
    row(198, "", "II", "15.4 \u00b1 1.3", "12.1 \u00b1 1.6"),
    row(210, "", "III", "15.5 \u00b1 1.6", "12.1 \u00b1 1.8"),
    row(228, "100-Hz stimulation", "I", "22.1 \u00b1 2.2", "22.0 \u00b1 2.1"),
    row(240, "", "II", "22.0 \u00b1 2.1", "22.0 \u00b1 1.7"),
    row(252, "", "III", "21.9 \u00b1 2.7", "21.8 \u00b1 2.7"),
    list(list(x = 60, y = 270, text = "MAP (mm Hg)", adj = 0)),
    row(288, "", "I", "131 \u00b1 15", "130 \u00b1 16"),
    row(300, "", "II", "132 \u00b1 13", "133 \u00b1 12"),
    row(312, "", "III", "132 \u00b1 14", "131 \u00b1 15"),
    list(list(x = 60, y = 340, text = "Values are mean \u00b1 SD. Group I = no study drug, Group II = low-dose midazolam, Group III = high-dose midazolam.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("rows under a heading are named by it, a numeric-led label keeps its words, a heading alone names bare rows", {
  r <- parseBaselineTableHeuristics(headingPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$N, c(8L, 8L, 8L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  rows <- unique(cont$ROW)          # (the pdf device sets the label's hyphen as U+2212, hence "20.Hz")
  expect_identical(length(rows), 4L)
  expect_false(any(grepl("Unnamed", rows)))
  expect_true(any(grepl("^HR", rows)))
  expect_true(any(grepl("^Pdi.*: 20.Hz stimulation$", rows)))
  expect_true(any(grepl("^Pdi.*: 100.Hz stimulation$", rows)))
  expect_true(any(grepl("^MAP", rows)))
  expect_identical(cont$MEAN[grepl("20.Hz", cont$ROW)], c(15.9, 15.4, 15.5))
  expect_identical(cont$MEAN[grepl("100.Hz", cont$ROW)], c(22.1, 22.0, 21.9))
  expect_identical(cont$MEAN[grepl("^MAP", cont$ROW)], c(131, 132, 132))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
