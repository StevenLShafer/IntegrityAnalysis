# test-stray-sign-between-cells.R - a stray sign glyph between two whole
# cells does not cost the first cell: a row whose refusing reading (issue
# 118) puts two tokens in one arm column is re-read trusting its SDs when
# that reading puts one token in each column (ISSUES.md issue 122,
# 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 27 AF4/AF5 (CJA 1998, PMID 9717598, a scan whose  #
# text layer is scrambled): "156 <bullet> 10 <pm> 155 <bullet> 9 154       #
# <bullet> 8" on the Height line - a plus-minus of the layer's own between #
# the first and second cells - and the same on both durations, blood loss #
# and fluid replacement. On 0b7ccdd every cell read; after issue 118 the   #
# first cell of each was refused and the fluid row was skipped.           #
############################################################################

bu <- "\u2022"; pm <- "\u00b1"

straySignPdf <- function(file = file.path(tempdir(), "straySign.pdf")) {
  vx <- c(395, 444, 491)
  cell <- function(y, k, mean, sd) list(
    list(x = vx[k], y = y, text = mean, adj = 0),
    list(x = vx[k] + 16, y = y, text = bu, adj = 0),
    list(x = vx[k] + 23, y = y, text = sd, adj = 0))
  row <- function(y, label, means, sds, stray = TRUE) c(
    list(list(x = 307, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], sds[k])), recursive = FALSE),
    if (stray) list(list(x = vx[1] + 31, y = y, text = pm, adj = 0)))
  cells <- c(
    list(list(x = 307, y = 60, text = "TABLE I Demographic data", adj = 0)),
    rowCells(80, "", c("Group C", "Group N", "Group D"), vx + 12, labelX = 307),
    rowCells(94, "", c("(n = 20)", "(n = 18)", "(n = 19)"), vx + 12, labelX = 307),
    row(112, "Age (yr)", c("60", "62", "62"), c("9", "9", "9"), stray = FALSE),
    row(130, "Height (cm)", c("156", "155", "154"), c("10", "9", "8")),
    row(148, "Weight (kg)", c("58", "59", "56"), c("10", "11", "9"), stray = FALSE),
    row(166, "Surgery (min)", c("150", "146", "149"), c("59", "76", "55")),
    row(184, "Blood loss (ml)", c("147", "141", "142"), c("97", "85", "81")),
    list(list(x = 307, y = 216, text = paste("Values are mean", bu, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a stray sign between the first and second cells does not cost the first cell", {
  r <- parseBaselineTableHeuristics(straySignPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 18L, 19L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(156, 155, 154))
  expect_identical(cont$SD[cont$ROW == "Height"], c(10, 9, 8))
  expect_identical(cont$MEAN[grepl("^Surgery", cont$ROW)], c(150, 146, 149))
  expect_identical(cont$MEAN[grepl("^Blood loss", cont$ROW)], c(147, 141, 142))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(58, 59, 56))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

# THE LOST-SD LINE KEEPS THE REFUSING READING: its bare means stand one per
# column, so nothing is re-read (issue 118's page, PMID 9350368).
lostSdStillPdf <- function(file = file.path(tempdir(), "lostSdStill.pdf")) {
  vx <- c(200, 290, 380, 470)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table I Patient characteristics", adj = 0)),
    rowCells(90, "", c("ET (n = 20)", "LMA (n = 20)", "ET (n = 20)", "LMA (n = 20)"), vx, labelX = 60),
    rowCells(108, "Age (yr)", c(paste("62", pm), paste("61", pm), paste("62", pm, "9"), paste("61", pm, "11")), vx, labelX = 60),
    rowCells(126, "Height (cm)", c(paste("157", pm, "7"), paste("156", pm, "6"), paste("155", pm, "8"), paste("157", pm, "7")), vx, labelX = 60),
    rowCells(144, "Weight (kg)", c(paste("56", pm, "7"), paste("53", pm, "8"), paste("54", pm, "6"), paste("55", pm, "7")), vx, labelX = 60),
    list(list(x = 60, y = 176, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a lost-SD line is still read as bare means and whole cells", {
  r <- parseBaselineTableHeuristics(lostSdStillPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 4))
  age <- r$data[r$data$ROW == "Age" & !is.na(r$data$MEAN), ]
  expect_identical(age$MEAN, c(62, 61))
  expect_identical(age$SD, c(9, 11))
})
