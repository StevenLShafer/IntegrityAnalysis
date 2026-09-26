# test-count-heading-may-run-longer.R - a category heading that carries the
# count notation ("Type of surgery, no. (%) of patients") may run to ten
# words; its levels read as counts, not mean (SD) (ISSUES.md issue 156,
# 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 32 AM1 (Clin Ther 2003, PMID 14749148; four arms  #
# of 25): "Tympanoplasty 17 (68) 18 (72) 18 (72) 18 (72)" scored as a      #
# mean of 17 with an SD of 68 in four arms.                                 #
############################################################################

longCountHeadingPdf <- function(file = file.path(tempdir(), "longCountHeading.pdf")) {
  vx <- c(230, 320, 410, 500)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(55, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(55, 60, "Table I. Demographic characteristics of the study patients (N = 100; n = 25 in each group).*")),
    list(w(vx[1], 90, "Ramosetron"), w(vx[2], 90, "Ramosetron"), w(vx[3], 90, "Ramosetron"), w(vx[4], 90, "Placebo")),
    list(w(vx[1], 102, "0.15 mg"), w(vx[2], 102, "0.3 mg"), w(vx[3], 102, "0.6 mg")),
    row(126, "Age, y", c("45 (14)", "44 (14)", "43 (12)", "44 (10)")),
    row(144, "Height, cm", c("158 (8)", "157 (8)", "161 (8)", "160 (7)")),
    list(w(55, 162, "Type of surgery, no. (%) of patients")),
    row(180, "Tympanoplasty", c("17 (68)", "18 (72)", "18 (72)", "18 (72)")),
    row(198, "Radical mastoidectomy", c("8 (32)", "7 (28)", "7 (28)", "7 (28)")),
    list(w(55, 230, "*Values are mean (SD) unless otherwise noted.")))
  makeTablePdf(file, cells)
}

test_that("levels under a seven-word count heading read as counts, and the table's means are unharmed", {
  r <- parseBaselineTableHeuristics(longCountHeadingPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(45, 44, 43, 44))
  expect_false(any(grepl("^Tympanoplasty|^Radical", cont$ROW)))
  expect_true("Tympanoplasty" %in% names(r$data) || any(grepl("^Type of surgery", r$data$ROW)))
})
