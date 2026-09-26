# test-sd-with-glued-range-after-sign.R - in the slot repair, an SD with a
# parenthesised range glued to it ("7(29-58)", or "7(2359)" with the dash
# lost) is a number after the sign, so the glyph before it is read
# (ISSUES.md issue 145, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 30 (Anesth Analg 1998, PMID 9495425, a scan; three #
# arms of 50): "Age 44 k 7(2359) 45 + 10(21-63) 43 + 7(29-58)" read nothing #
# while every other row of the table read.                                 #
############################################################################

pm <- "\u00b1"

test_that("the slot repair reads the sign before an SD with its range glued on", {
  line <- function(...) {
    w <- c(...); x <- c(48, 232, 245, 254, 347, 359, 369, 466, 478, 487)
    data.frame(text = w, x = x[seq_along(w)], width = c(30, 7, 4, 23, 7, 5, 29, 7, 5, 25)[seq_along(w)], stringsAsFactors = FALSE)
  }
  lines <- list(line("Table"),
                line("Height", "154", pm, "5", "156", pm, "6", "154", pm, "4"),
                line("Weight", "55", pm, "8", "55", pm, "8", "54", pm, "7"),
                line("Age", "44", "k", "7(2359)", "45", "+", "10(21-63)", "43", "+", "7(29-58)"))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(r$lines[[4]]$text, c("Age", "44", pm, "7(2359)", "45", pm, "10(21-63)", "43", pm, "7(29-58)"))
})

gluedRangePdf <- function(file = file.path(tempdir(), "gluedRange.pdf")) {
  vx <- c(232, 347, 466)
  cell <- function(y, k, mean, sign, sd) list(
    list(x = vx[k], y = y, text = mean, adj = 0), list(x = vx[k] + 22, y = y, text = sign, adj = 0),
    list(x = vx[k] + 32, y = y, text = sd, adj = 0))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 48, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 36, y = 60, text = "Table 1. Patient Demographic Data", adj = 0)),
    rowCells(80, "", c("Granisetron", "Droperidol", "Combination"), vx + 16, labelX = 48),
    rowCells(94, "", c("(n = 50)", "(n = 50)", "(n = 50)"), vx + 16, labelX = 48),
    row(112, "Age (yr)", c("44", "45", "43"), c("k", "+", "+"), c("7(2359)", "10(21-63)", "7(29-58)")),
    row(130, "Height (cm)", c("154", "156", "154"), rep(pm, 3), c("5", "6", "4")),
    row(148, "Weight (kg)", c("55", "55", "54"), rep(pm, 3), c("8", "8", "7")),
    list(list(x = 48, y = 180, text = "Values are expressed as mean +- SD or n.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the Age row whose SDs carry glued ranges", {
  r <- parseBaselineTableHeuristics(gluedRangePdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(50L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(44, 45, 43))
  expect_identical(cont$SD[cont$ROW == "Age"], c(7, 10, 7))
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(154, 156, 154))
})
