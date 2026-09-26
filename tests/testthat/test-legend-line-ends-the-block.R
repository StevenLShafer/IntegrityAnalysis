# test-legend-line-ends-the-block.R - a line that defines two or more
# abbreviations ("A = words; B = words") after the table's rows is its
# legend and ends the block (ISSUES.md issue 151, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 2 AK5 (Clin Ther 2007, PMID 17697904;     #
# four arms of 60): the legend's doses seeded a fifth column under the     #
# label heading, which took the first arm's "(n = 60)".                    #
############################################################################

legendLinePdf <- function(file = file.path(tempdir(), "legendLine.pdf")) {
  vx <- c(205, 288, 372, 457)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(97, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(96, 60, "Table I. Demographic and clinical characteristics of the study population.*")),
    list(w(203, 80, "LID/MET"), w(287, 80, "LID/MET"), w(371, 80, "LID/MET")),
    list(w(208, 92, "40/2.5"), w(295, 92, "40/5"), w(376, 92, "40/10"), w(453, 92, "LID/Saline")),
    c(list(w(97, 104, "Characteristic")), lapply(1:4, function(k) w(vx[k], 104, "(n = 60)"))),
    row(126, "Age, y", c("44 (12)", "43 (12)", "42 (12)", "43 (13)")),
    row(144, "Height, cm", c("160 (7)", "160 (9)", "161 (8)", "160 (9)")),
    row(162, "Weight, kg", c("58 (9)", "56 (10)", "58 (10)", "58 (9)")),
    list(w(97, 184, "LID/MET 40/2.5 = lidocaine/metoclopramide 40/2.5 mg; LID/MET 40/5 = lidocaine/metoclopramide 40/5 mg;")),
    list(w(97, 196, "LID/MET 40/10 = lidocaine/metoclopramide 40/10 mg.")),
    list(w(97, 214, "*No significant differences in demographic characteristics were observed.")))
  makeTablePdf(file, cells)
}

test_that("a legend line of abbreviations after the rows ends the block, and the first arm keeps its size", {
  r <- parseBaselineTableHeuristics(legendLinePdf(), quiet = TRUE, parenIsSD = "sd")
  expect_identical(nrow(r$arms), 4L)
  expect_identical(r$arms$N, rep(60L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(44, 43, 42, 43))
  expect_false(any(grepl("lidocaine|LID/MET 40/2.5 =", r$data$ROW)))
})
