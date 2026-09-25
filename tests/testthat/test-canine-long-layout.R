# test-canine-long-layout.R - the long layout with roman-numbered groups,
# one label lost from the text layer, the plus-minus as U+2AFE, and the
# size from "three groups of eight each" (ISSUES.md issue 88, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 22: 16 of the 18 animal papers among the 48        #
# missing-N Carlisle trials are Fujii canine tables of this shape           #
# ("Variable | Group | Baseline | Fatigued | ...", groups I-III as rows      #
# under each variable, PMID 12933396 the cleanest), read as two arms - the #
# Baseline and Fatigued COLUMNS - until the reader took them.              #
############################################################################

test_that("U+2AFE between two numbers tokenizes as mean +/- SD", {
  line <- data.frame(text = c("140", "⫾", "13", "141", "⫾", "14"),
                     x = c(238, 254, 263, 313, 328, 338), width = c(14, 6, 9, 14, 6, 9),
                     stringsAsFactors = FALSE)
  t <- .ppTokenizeLine(line)
  expect_identical(t$type, c("meanSD", "meanSD"))
  expect_identical(t$num2, c(13, 14))
})

caninePdf <- function(file = file.path(tempdir(), "canine.pdf")) {
  vx <- c(230, 320, 420)   # Group, Baseline, Fatigued
  row <- function(y, label, g, base, fat) c(
    if (nzchar(label)) list(list(x = 60, y = y, text = label, adj = 0)) else list(),
    if (nzchar(g)) list(list(x = vx[1], y = y, text = g, adj = 0.5)) else list(),
    list(list(x = vx[2], y = y, text = base, adj = 0.5),
         list(x = vx[3], y = y, text = fat, adj = 0.5)))
  cells <- c(
    list(list(x = 60, y = 50, text = "Dogs were randomly divided into three groups of eight each.", adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1. Changes in Hemodynamics and Pdi", adj = 0)),
    list(list(x = 60, y = 108, text = "Variable", adj = 0),
         list(x = vx[1], y = 108, text = "Group", adj = 0.5),
         list(x = vx[2], y = 108, text = "Baseline", adj = 0.5),
         list(x = vx[3], y = 108, text = "Fatigued", adj = 0.5)),
    row(126, "HR (bpm)", "I", "140 ± 13", "141 ± 14"),
    row(138, "", "", "140 ± 10", "139 ± 10"),          # the "II" the text layer lost
    row(150, "", "III", "139 ± 11", "138 ± 12"),
    row(168, "MAP (mm Hg)", "I", "131 ± 15", "130 ± 16"),
    row(180, "", "", "132 ± 13", "133 ± 12"),
    row(192, "", "III", "132 ± 14", "131 ± 15"),
    row(210, "Pdi (cm H2O)", "I", "15.9 ± 1.5", "11.8 ± 1.4"),
    row(222, "", "", "15.4 ± 1.3", "12.1 ± 1.6"),
    row(234, "", "III", "15.5 ± 1.6", "12.1 ± 1.8"),
    list(list(x = 60, y = 264, text = "Values are mean ± SD. Group I = no study drug, Group II = low-dose midazolam, Group III = high-dose midazolam.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("roman groups with a lost II read as three arms of eight from the Baseline column, named by the legend", {
  r <- parseBaselineTableHeuristics(caninePdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$N, c(8L, 8L, 8L))
  expect_true(all(grepl("\\(Group (I|II|III)\\)$|^Group (I|II|III)$", r$arms$arm)))
  expect_true(grepl("no study drug", r$arms$arm[1]))
  cont <- r$data[!is.na(r$data$MEAN), ]
  # the mixed-case units "(mm Hg)" and "(cm H2O)" stay on the label, as the unit rule leaves them
  expect_identical(length(unique(cont$ROW)), 3L)
  expect_true(all(grepl("^(HR|MAP|Pdi)", unique(cont$ROW))))
  expect_identical(cont$MEAN[grepl("^HR", cont$ROW)], c(140, 140, 139))     # Baseline only, I / II / III
  expect_identical(cont$SD[grepl("^Pdi", cont$ROW)], c(1.5, 1.3, 1.6))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
