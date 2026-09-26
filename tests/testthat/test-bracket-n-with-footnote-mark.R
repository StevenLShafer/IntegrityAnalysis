# test-bracket-n-with-footnote-mark.R - a per-cell n in brackets after the
# SD may carry the paper's footnote mark, "3[35]*" (ISSUES.md issue 135,
# 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG6 (CJA 1999, PMID 10522590; two arms of 40): #
# "Last menstrual cycle (days) 16 <bullet> 3[35]* 16 <bullet> 3[35]*" took #
# the arm's 40 for its N; the page says 35 and 35.                         #
############################################################################

pm <- "\u00b1"

bracketStarPdf <- function(file = file.path(tempdir(), "bracketStar.pdf")) {
  vx <- c(430, 520)   # room for the bracket word before the next arm's mean
  cells <- c(
    list(list(x = 308, y = 60, text = "TABLE I Patient characteristics", adj = 0)),
    rowCells(80, "", c("G (n = 40)", "P (n = 40)"), vx + 8, labelX = 308),
    rowCells(100, "Age (yr)", c(paste("42", pm, "9"), paste("41", pm, "8")), vx, labelX = 308),
    rowCells(114, "Weight (kg)", c(paste("55", pm, "7"), paste("54", pm, "8")), vx, labelX = 308),
    rowCells(128, "Last menstrual cycle (days)", c(paste("16", pm, "3[35]*"), paste("16", pm, "3[35]*")), vx, labelX = 308),
    list(list(x = 308, y = 160, text = "*Patients with a regular cycle.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the bracket n with a footnote star gives the row its own N", {
  r <- parseBaselineTableHeuristics(bracketStarPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(40L, 40L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  men <- cont[grepl("^Last menstrual", cont$ROW), ]
  expect_identical(men$MEAN, c(16, 16))
  expect_identical(men$SD, c(3, 3))
  expect_identical(men$N, c(35L, 35L))
  expect_identical(cont$N[cont$ROW == "Age"], c(40L, 40L))
})
