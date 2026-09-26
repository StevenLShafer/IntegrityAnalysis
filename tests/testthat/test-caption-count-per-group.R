# test-caption-count-per-group.R - a caption's or footnote's "n = 20 patients
# per study group", "(N = 100; n = 25 in each group)", "n = 60 per group." and
# "n = 45in each group" are statements of every arm's size (ISSUES.md issue
# 150, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 (Clin Ther 2014, PMID 24672087; Clin Ther      #
# 2004, PMID 15336470; Clin Ther 2003, PMID 14749148; A&A 1998, PMID       #
# 9768766; A&A 1997, PMID 9322479): every cell read, no arm had an N.      #
############################################################################

test_that("the caption's and footnote's spellings of 'n per group' are statements for every arm", {
  for (txt in c("Table I. Baseline characteristics of the study patients (n = 20 patients per group).*",
                "Table I. Baseline characteristics of study patients (n = 20 patients per study group).*",
                "Table I. Demographics of the study population (N = 100; n = 20 in each group).",
                "Values are mean (SD). n = 20 per group.",
                "Values are mean +/- SD. n = 20in each group.",
                "n = 20 patients in each treatment group")) {
    g <- .ppGroupsOfN(txt)
    expect_false(is.null(g), info = txt)
    if (!is.null(g)) { expect_identical(g$n, 20L, info = txt); expect_true(is.na(g$groups), info = txt) }
  }
  # the power calculation stays a hypothesis
  expect_null(.ppGroupsOfN("a sample size of n = 20 per group would provide 80% power to detect"))
  # and a bare "(n = 20)" beside one arm's name is not a statement for every arm
  expect_null(.ppGroupsOfN("the granisetron group (n = 20) received"))
})

captionCountPdf <- function(file = file.path(tempdir(), "captionCount.pdf")) {
  vx <- c(200, 290, 380, 470)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(55, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(54, 60, "Table I. Baseline demographic and clinical characteristics of the study patients (n = 20 patients per group).*")),
    list(w(55, 100, "Characteristic"), w(vx[1], 100, "Granisetron 10"), w(vx[2], 100, "Granisetron 20"), w(vx[3], 100, "Granisetron 40"), w(vx[4], 100, "Placebo")),
    row(126, "Age, y", c("45 (9)", "46 (8)", "44 (9)", "45 (10)")),
    row(144, "Height, cm", c("158 (6)", "157 (7)", "159 (6)", "158 (7)")),
    row(162, "Weight, kg", c("57 (8)", "56 (9)", "58 (8)", "57 (9)")),
    list(w(54, 200, "*Values are mean (SD) unless otherwise noted.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page whose only sizes are the caption's 'n = 20 patients per group' gives every arm 20", {
  r <- parseBaselineTableHeuristics(captionCountPdf(), quiet = TRUE, parenIsSD = "sd")
  expect_identical(r$arms$N, rep(20L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(45, 46, 44, 45))
})
