# test-long-layout-k-from-legend.R - when only the first "I" survives in
# the text layer, the legend's "group III received ..." bounds the run,
# and a caption sentence carrying "group" and "baseline" is not taken for
# the header line (ISSUES.md issue 101, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24 AC1's fifth paper (Fujii, Br J Anaesth 2001,   #
# PMID 11573601): every "II" and "III" is gone from the page, and the     #
# caption's legend sentence, with both words, was taken for the header.   #
############################################################################

legendPdf <- function(file = file.path(tempdir(), "legendK.pdf")) {
  vx <- c(230, 320, 420)   # Group, Baseline, Fatigued
  row <- function(y, label, g, base, fat) c(
    if (nzchar(label)) list(list(x = 60, y = y, text = label, adj = 0)) else list(),
    if (nzchar(g)) list(list(x = vx[1], y = y, text = g, adj = 0.5)) else list(),
    list(list(x = vx[2], y = y, text = base, adj = 0.5),
         list(x = vx[3], y = y, text = fat, adj = 0.5)))
  cells <- c(
    list(list(x = 60, y = 40, text = "Dogs were randomly divided into three groups of ten each.", adj = 0)),
    list(list(x = 60, y = 80, text = "Table 1 Changes in hemodynamics. Values are mean (SD). Group I received no study", adj = 0)),
    list(list(x = 60, y = 92, text = "drug, group II received propofol and group III received midazolam; a different from baseline (P<0.05).", adj = 0)),
    list(list(x = 60, y = 110, text = "Variable", adj = 0),
         list(x = vx[1], y = 110, text = "Group", adj = 0.5),
         list(x = vx[2], y = 110, text = "Baseline", adj = 0.5),
         list(x = vx[3], y = 110, text = "Fatigued", adj = 0.5)),
    row(128, "Heart rate", "I", "142 (12)", "141 (11)"),
    row(140, "", "", "143 (11)", "141 (12)"),
    row(152, "", "", "143 (10)", "143 (11)"),
    row(170, "MAP (mm Hg)", "", "126 (10)", "125 (11)"),
    row(182, "", "", "125 (11)", "125 (13)"),
    row(194, "", "", "127 (10)", "127 (9)"),
    row(212, "CO (L/min)", "", "2.0 (0.3)", "2.1 (0.4)"),
    row(224, "", "", "2.2 (0.3)", "1.9 (0.3)"),
    row(236, "", "", "2.1 (0.3)", "1.5 (0.3)"),
    list(list(x = 60, y = 270, text = "a Significantly different from baseline (P<0.05).", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the legend's 'group III' bounds the run when only the first 'I' survives, and the caption sentence is not the header", {
  r <- parseBaselineTableHeuristics(legendPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$N, c(10L, 10L, 10L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(length(unique(cont$ROW)), 3L)
  expect_identical(nrow(cont), 9L)
  byRow <- split(cont$MEAN, factor(cont$ROW, levels = unique(cont$ROW)))
  expect_identical(byRow[[1]], c(142, 143, 143))
  expect_identical(byRow[[2]], c(126, 125, 127))
  expect_identical(byRow[[3]], c(2.0, 2.2, 2.1))
  expect_false(any(grepl("Fatigued|received", c(r$arms$arm, cont$ROW))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
