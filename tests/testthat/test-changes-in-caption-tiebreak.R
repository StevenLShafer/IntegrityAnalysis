# test-changes-in-caption-tiebreak.R - a "Changes in X" caption with no
# baseline word heads a time-course table and loses a point; on equal
# scores the lower table number wins the candidate contest (ISSUES.md
# issue 102, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD3 (Fujii, Anesth Analg 2001;92:762, PMID     #
# 11226115): Table 1 "Hemodynamic Data and Changes" and Table 2 "Changes   #
# in Pdi, % Edi-cru, and % Edi-cost" parse to the same score, and the      #
# hemodynamic penalty on Table 1's caption let Table 2 win.                #
############################################################################

test_that("the table number is read from the caption, and 'Changes in X' costs a point without a baseline word", {
  expect_identical(.ppTableNumber("Table 1. Hemodynamic Data and Changes"), 1)
  expect_identical(.ppTableNumber("TABLE II Patient characteristics"), 2)
  expect_identical(.ppTableNumber("Tab. 3 Outcomes"), 3)
  expect_identical(.ppTableNumber("Patient data"), Inf)
  expect_identical(.ppTableNumber(NA_character_), Inf)
  expect_lt(.ppCaptionScore("Table 2. Changes in Pdi, % Edi-cru, and % Edi-cost"),
            .ppCaptionScore("Table 2. Pdi, % Edi-cru, and % Edi-cost"))
  expect_identical(.ppCaptionScore("Table 2. Changes in hemodynamics from baseline characteristics"),
                   .ppCaptionScore("Table 2. Changes in hemodynamics from baseline characteristics"))
  expect_equal(.ppCaptionScore("Table 3. Changes in baseline demographic data"),
               .ppCaptionScore("Table 3. Baseline demographic data"))   # a baseline word: no penalty
})

twoTablesPdf <- function(file = file.path(tempdir(), "twoTables.pdf")) {
  vx <- c(170, 250, 330, 410)   # close enough that the page has no gutter to split on
  cells <- c(
    list(list(x = 60, y = 40, text = "Dogs were randomly divided into four groups of eight each.", adj = 0)),
    list(list(x = 60, y = 70, text = "Table 1. Hemodynamic Data and Changes", adj = 0)),
    rowCells(90, "", c("Group 1", "Group 2", "Group 3", "Group 4"), vx),
    rowCells(108, "HR (bpm)", c("140 \u00b1 10", "141 \u00b1 9", "139 \u00b1 11", "142 \u00b1 10"), vx),
    rowCells(126, "MAP (mm Hg)", c("125 \u00b1 8", "126 \u00b1 9", "124 \u00b1 8", "125 \u00b1 10"), vx),
    rowCells(144, "CO (L/min)", c("2.0 \u00b1 0.3", "2.1 \u00b1 0.3", "2.0 \u00b1 0.4", "2.2 \u00b1 0.3"), vx),
    list(list(x = 60, y = 170, text = "Values are mean \u00b1 SD.", adj = 0)),
    # body text across the page, as on a real page, so that no gutter splits it into columns
    list(list(x = 60, y = 250, text = "With an infusion of the study drug in the treatment groups, heart rate and mean arterial pressure", adj = 0)),
    list(list(x = 60, y = 262, text = "decreased from baseline values, while no hemodynamic changes were observed in the control group.", adj = 0)),
    list(list(x = 60, y = 400, text = "Table 2. Changes in Pdi, % Edi-cru, and % Edi-cost", adj = 0)),
    rowCells(420, "", c("Group 1", "Group 2", "Group 3", "Group 4"), vx),
    rowCells(438, "Pdi 20 Hz", c("15.9 \u00b1 1.5", "15.4 \u00b1 1.3", "15.5 \u00b1 1.6", "15.7 \u00b1 1.4"), vx),
    rowCells(456, "Pdi 100 Hz", c("22.1 \u00b1 2.2", "22.0 \u00b1 2.1", "21.9 \u00b1 2.7", "22.3 \u00b1 2.0"), vx),
    rowCells(474, "% Edi-cru", c("100.0 \u00b1 0.0", "100.0 \u00b1 0.0", "100.0 \u00b1 0.0", "100.0 \u00b1 0.0"), vx),
    list(list(x = 60, y = 500, text = "Values are mean \u00b1 SD.", adj = 0)),
    list(list(x = 60, y = 560, text = "Transdiaphragmatic pressure at both stimulation frequencies decreased during the infusion and", adj = 0)),
    list(list(x = 60, y = 572, text = "returned toward baseline values sixty minutes after the end of the study drug administration.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("with equal parse scores Table 1 beats Table 2 'Changes in ...'", {
  r <- parseBaselineTableHeuristics(twoTablesPdf(), quiet = TRUE)
  expect_true(grepl("^Table 1", r$caption))
  expect_true(all(c("HR", "MAP", "CO") %in% sub(" .*", "", unique(r$data$ROW))))
  expect_false(any(grepl("Pdi|Edi", r$data$ROW)))
  expect_identical(r$arms$N, rep(8L, 4))
})
