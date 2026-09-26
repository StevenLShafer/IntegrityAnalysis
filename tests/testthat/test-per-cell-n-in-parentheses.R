# test-per-cell-n-in-parentheses.R - a row of cells with "(n = k*)" after
# each cell is a data row with a per-cell n, not a header or a stratum
# (ISSUES.md issue 131, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG2 (Am J Obstet Gynecol 2000, PMID 10649150;  #
# three arms of 40): "Last menstrual cycle (d, mean +/- SD) 16 +/- 3 (n = #
# 38*) 16 +/- 3 (n = 37*) 16 +/- 3 (n = 38*)" read as a stratum over the  #
# rows beneath, which went out with N 38/37/38 and the prefix "Last       #
# menstrual cycle (d, mean +/- SD) 16 +/- 3:"; the three menstrual cells   #
# were lost.                                                               #
############################################################################

pm <- "\u00b1"

perCellNPdf <- function(file = file.path(tempdir(), "perCellN.pdf")) {
  vx <- c(261, 354, 460)
  cell <- function(y, k, mean, sd, n = NULL) c(
    list(list(x = vx[k], y = y, text = mean, adj = 0), list(x = vx[k] + 10, y = y, text = pm, adj = 0),
         list(x = vx[k] + 17, y = y, text = sd, adj = 0)),
    if (!is.null(n)) list(list(x = vx[k] + 26, y = y, text = paste0("(n = ", n, "*)"), adj = 0)))
  row <- function(y, label, means, sds, ns = NULL) c(
    list(list(x = 63, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], sds[k], ns[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 63, y = 60, text = "Table I. Patient characteristics", adj = 0)),
    rowCells(80, "", c("Granisetron", "Droperidol", "Metoclopramide"), vx + 10, labelX = 63),
    rowCells(94, "", c("(n = 40)", "(n = 40)", "(n = 40)"), vx + 10, labelX = 63),
    row(114, "Age (y, mean and SD)", c("45", "44", "43"), c("8", "7", "10")),
    row(132, "Height (cm, mean and SD)", c("154", "153", "155"), c("5", "4", "6")),
    row(150, "Last menstrual cycle (d)", c("16", "16", "16"), c("3", "3", "3"), c("38", "37", "38")),
    row(168, "Duration of operation (min)", c("76", "78", "76"), c("26", "26", "31")),
    row(186, "Duration of anesthesia (min)", c("99", "98", "101"), c("25", "25", "31")),
    list(list(x = 63, y = 220, text = "*Patients with a regular cycle.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a row of cells with (n = k*) after each cell is a row with its own n, and the rows beneath keep the arm N", {
  r <- parseBaselineTableHeuristics(perCellNPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(40L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  men <- cont[grepl("^Last menstrual", cont$ROW), ]
  expect_identical(men$MEAN, c(16, 16, 16))
  expect_identical(men$N, c(38L, 37L, 38L))
  dur <- cont[grepl("^Duration of operation", cont$ROW), ]
  expect_identical(dur$N, rep(40L, 3))
  expect_identical(dur$MEAN, c(76, 78, 76))
  expect_false(any(grepl("16 .* 3:", cont$ROW)))
  expect_identical(length(unique(cont$ROW)), 5L)
})
