# test-continuous-label-closes-a-count-heading.R - a row labelled as a
# continuous variable ("Height, cm", "Days since last menstrual cycle") under
# an open "no. (%)" heading is a new variable, not a level (ISSUES.md issue
# 160, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 AK4 (ii) and batch 33 (Clin Ther 2003, PMID    #
# 14749148; four arms of 25): Height, Weight, the menstrual row and both   #
# durations were read as levels of "Sex, no. (%)".                         #
############################################################################

sexThenHeightPdf <- function(file = file.path(tempdir(), "sexThenHeight.pdf")) {
  vx <- c(230, 290, 350, 400)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(69, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(69, 60, "Table I. Demographic characteristics of study patients (N = 100; n = 25 in each group).*")),
    list(w(69, 96, "Characteristic"), w(vx[1], 96, "0.15 mg"), w(vx[2], 96, "0.3 mg"), w(vx[3], 96, "0.6 mg"), w(vx[4], 96, "Placebo")),
    list(w(69, 118, "Age, y")),
    row(134, "Mean (SD)", c("45 (14)", "44 (14)", "43 (12)", "44 (10)")),
    row(150, "Range", c("22-65", "20-63", "23-65", "20-65")),
    list(w(69, 168, "Sex, no. (%)")),
    row(184, "Women", c("14 (56)", "14 (56)", "14 (56)", "13 (52)")),
    row(200, "Men", c("11 (44)", "11 (44)", "11 (44)", "12 (48)")),
    row(216, "Height, cm", c("158 (8)", "157 (7)", "161 (8)", "160 (7)")),
    row(232, "Body weight, kg", c("57 (8)", "56 (9)", "57 (8)", "56 (7)")),
    row(248, "Days since last menstrual cycle", c("16 (3)", "16 (3)", "16 (3)", "16 (3)")),
    row(264, "Duration of surgery, min", c("220 (48)", "215 (38)", "218 (40)", "217 (41)")),
    list(w(69, 290, "*Values are expressed as mean (SD) unless otherwise indicated.")))
  makeTablePdf(file, cells)
}

test_that("continuous rows after a Sex, no. (%) block are variables of their own, with the levels still counts", {
  r <- parseBaselineTableHeuristics(sexThenHeightPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Height", cont$ROW)], c(158, 157, 161, 160))
  expect_identical(cont$MEAN[grepl("^Body weight", cont$ROW)], c(57, 56, 57, 56))
  expect_identical(cont$MEAN[grepl("^Days since", cont$ROW)], c(16, 16, 16, 16))
  expect_identical(cont$MEAN[grepl("^Duration", cont$ROW)], c(220, 215, 218, 217))
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(45, 44, 43, 44))
  expect_false(any(grepl("^Women|^Men", cont$ROW)))
  expect_true("Women" %in% names(r$data) || any(grepl("^Sex", r$data$ROW)))
})
