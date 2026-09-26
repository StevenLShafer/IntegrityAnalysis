# test-two-line-count-heading.R - a count heading wrapped over two lines
# ("No. (%) of patients using analgesics" / "postoperatively") keeps its tag
# on its continuation, and the levels beneath read as counts (ISSUES.md
# issue 159, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 33 AN1 (Curr Ther Res 2002, PMID 24944401; two    #
# arms of 50): "Indomethacin 31 (62) 32 (64)" scored as a mean of 31 with  #
# an SD of 62 in both arms.                                                 #
############################################################################

twoLineCountHeadingPdf <- function(file = file.path(tempdir(), "twoLineCountHeading.pdf")) {
  vx <- c(270, 375)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(53, y, label)), lapply(1:2, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(53, 60, "Table I. Baseline demographic and clinical characteristics of study patients (N = 100).*")),
    list(w(vx[1], 90, "Ramosetron"), w(vx[2], 90, "Placebo")),
    list(w(53, 104, "Characteristic"), w(vx[1], 104, "(n = 50)"), w(vx[2], 104, "(n = 50)")),
    row(126, "Age, mean (SD), y", c("45 (8)", "47 (9)")),
    row(144, "Height, mean (SD), cm", c("156 (11)", "156 (12)")),
    row(162, "Weight, mean (SD), kg", c("53 (12)", "55 (11)")),
    list(w(53, 184, "No. (%) of patients using analgesics")),
    list(w(53, 196, "postoperatively")),
    row(214, "Indomethacin", c("31 (62)", "32 (64)")),
    row(232, "Pentazocine", c("5 (10)", "5 (10)")),
    list(w(53, 260, "*No significant between-group differences were found.")))
  makeTablePdf(file, cells)
}

test_that("a count heading wrapped over two lines heads its levels, which read as counts", {
  r <- parseBaselineTableHeuristics(twoLineCountHeadingPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(50L, 50L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(45, 47))
  expect_false(any(grepl("^Indomethacin|^Pentazocine", cont$ROW)))
  expect_identical(length(unique(cont$ROW)), 3L)
})

# A wrapped NAME over a label-less value line takes both lines as its name
# (CodeRabbit on PR #471): "Duration of active" / "phase" / "5.25 (0.86)
# 5.31 (0.85)" is one variable, "Duration of active phase".
wrappedNamePdf <- function(file = file.path(tempdir(), "wrappedName.pdf")) {
  vx <- c(270, 375)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(53, y, label)), lapply(1:2, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(53, 60, "Table 1. Baseline characteristics (n = 50 in each group).")),
    list(w(vx[1], 90, "Ramosetron"), w(vx[2], 90, "Placebo")),
    row(114, "Age, y", c("45 (8)", "47 (9)")),
    list(w(53, 132, "Duration of active")),
    list(w(53, 144, "phase, h")),
    list(w(vx[1], 156, "5.25 (0.86)"), w(vx[2], 156, "5.31 (0.85)")),
    row(178, "Weight, kg", c("53 (12)", "55 (11)")),
    list(w(53, 206, "Values are mean (SD).")))
  makeTablePdf(file, cells)
}

test_that("a label-less value line under a two-line name takes both lines as its name", {
  r <- parseBaselineTableHeuristics(wrappedNamePdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_true(any(grepl("^Duration of active phase", cont$ROW)))
  expect_identical(cont$MEAN[grepl("^Duration of active phase", cont$ROW)], c(5.25, 5.31))
  expect_false(any(grepl("^phase", cont$ROW)))
})
