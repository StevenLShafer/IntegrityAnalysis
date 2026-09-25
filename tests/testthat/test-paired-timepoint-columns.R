# test-paired-timepoint-columns.R - a header line of alternating before/
# after pairs under the group names means the arms are the groups and only
# the "before" cells are baseline (ISSUES.md issue 111, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE2 (Takahashi, CJA 2003, PMID 14525825):      #
# "Saline / Milrinone" over "Before a / After b / Before a / After b", two  #
# arms of 9, read as four arms of 9 with p 0.040 on cells that are not     #
# baseline.                                                                #
############################################################################

pairedPdf <- function(file = file.path(tempdir(), "pairedColumns.pdf")) {
  vx <- c(180, 270, 380, 470)
  cells <- c(
    list(list(x = 53, y = 60, text = "TABLE I Hemodynamic changes after saline/milrinone treatment", adj = 0)),
    list(list(x = 225, y = 80, text = "Saline", adj = 0.5), list(x = 425, y = 80, text = "Milrinone", adj = 0.5)),
    list(list(x = vx[1], y = 96, text = "Before a", adj = 0.5), list(x = vx[2], y = 96, text = "After b", adj = 0.5),
         list(x = vx[3], y = 96, text = "Before a", adj = 0.5), list(x = vx[4], y = 96, text = "After b", adj = 0.5)),
    rowCells(114, "SBP (mmHg)", c("144 \u00b1 28", "142 \u00b1 28", "141 \u00b1 29", "140 \u00b1 30"), vx, labelX = 53),
    rowCells(132, "MBP (mmHg)", c("117 \u00b1 20", "116 \u00b1 20", "116 \u00b1 21", "113 \u00b1 22"), vx, labelX = 53),
    rowCells(150, "HR (bpm)", c("119 \u00b1 31", "120 \u00b1 33", "111 \u00b1 28", "116 \u00b1 29"), vx, labelX = 53),
    rowCells(168, "CO (L/min)", c("1.65 \u00b1 0.54", "1.41 \u00b1 0.40", "1.35 \u00b1 0.29", "1.83 \u00b1 0.47"), vx, labelX = 53),
    list(list(x = 53, y = 196, text = "Values are mean \u00b1 SD. Nine dogs were studied in each group.", adj = 0)),
    list(list(x = 53, y = 40, text = "The dogs were divided into two groups of nine each.", adj = 0)),
    # body text across the page, as on a real page, so that no gutter splits the table into columns
    list(list(x = 53, y = 230, text = "Hemodynamic variables did not differ between the groups before treatment, and milrinone increased", adj = 0)),
    list(list(x = 53, y = 242, text = "cardiac output and decreased systemic vascular resistance after treatment in every animal studied.", adj = 0)))
  for (k in seq_along(cells)) if (!is.null(cells[[k]]$adj) && cells[[k]]$adj == 0.5 && !is.null(cells[[k]]$text) && grepl("\u00b1", cells[[k]]$text)) cells[[k]]$adj <- 0.5
  makeTablePdf(file, cells)
}

test_that("two groups over before/after pairs read as two arms from the before columns only", {
  r <- parseBaselineTableHeuristics(pairedPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$arm, c("Saline", "Milrinone"))
  expect_identical(r$arms$N, c(9L, 9L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(nrow(cont), 8L)
  expect_identical(cont$MEAN[cont$ROW == "SBP"], c(144, 141))
  expect_identical(cont$MEAN[grepl("^CO", cont$ROW)], c(1.65, 1.35))
  expect_false(any(grepl("After|Before", c(r$arms$arm, cont$ROW))))
})

test_that("a plain four-arm header is untouched by the pair rule", {
  vx <- c(180, 270, 380, 470)
  f <- file.path(tempdir(), "fourArms.pdf")
  cells <- c(
    list(list(x = 53, y = 60, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(90, "", c("Placebo (n = 20)", "Low (n = 20)", "Mid (n = 20)", "High (n = 20)"), vx, labelX = 53),
    rowCells(108, "Age (yr)", c("45 \u00b1 12", "46 \u00b1 11", "44 \u00b1 10", "47 \u00b1 12"), vx, labelX = 53),
    rowCells(126, "Weight (kg)", c("70 \u00b1 9", "71 \u00b1 8", "69 \u00b1 9", "72 \u00b1 10"), vx, labelX = 53),
    list(list(x = 53, y = 156, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(nrow(r$arms), 4L)
  expect_identical(r$arms$N, rep(20L, 4))
})
