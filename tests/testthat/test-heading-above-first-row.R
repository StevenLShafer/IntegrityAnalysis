# test-heading-above-first-row.R - a variable printed as a heading line
# with its statistics on legend-labelled lines beneath, and the stretched
# watermark letters threaded through such a table (ISSUES.md issue 44,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 4b (Fujii 2002, PMID 12182258, Carlisle-168):    #
# every variable of that Table 1 is set as "Age, y" / "Mean +/- SD 46 +/- #
# 8 ..." / "Range 33-57 ...". The first variable's heading lies above the  #
# first data line, where the block walker never looked, so its row went   #
# out named "Mean +/- SD"; each Range line became a category row named    #
# "<heading> 2"; and single letters of a stretched watermark ("A", "R",   #
# 130 points wide each) became label lines and a label prefix ("R        #
# Duration of anesthesia"). The page cannot ship; the layout is rebuilt   #
# with the pdf() device, and the stretched glyphs are tested on a frame.  #
############################################################################

stackedPdf <- function(file = file.path(tempdir(), "stacked.pdf")) {
  vx <- c(250, 320, 390, 460)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Demographic characteristics.", adj = 0)),
    rowCells(96,  "", c("0.15 mg", "0.3 mg", "0.6 mg", "Placebo"), vx),
    rowCells(112, "", c("(n = 20)", "(n = 20)", "(n = 20)", "(n = 20)"), vx),
    list(list(x = 60, y = 134, text = "Age, y", adj = 0)),
    rowCells(150, "Mean ± SD", c("46 ± 8", "47 ± 8", "47 ± 8", "48 ± 6"), vx, labelX = 66),
    rowCells(166, "Range",     c("33-57", "34-63", "35-58", "28-56"), vx, labelX = 66),
    list(list(x = 60, y = 186, text = "Sex, no.", adj = 0)),
    rowCells(202, "Male",   c("5", "5", "6", "6"),     vx, labelX = 66),
    rowCells(218, "Female", c("15", "15", "14", "14"), vx, labelX = 66),
    list(list(x = 60, y = 238, text = "Height, cm", adj = 0)),
    rowCells(254, "Mean ± SD", c("156 ± 11", "157 ± 8", "158 ± 10", "156 ± 9"), vx, labelX = 66),
    rowCells(270, "Range",     c("140-185", "142-174", "138-184", "143-177"), vx, labelX = 66),
    rowCells(292, "Duration of surgery, min", c("170 ± 38", "172 ± 47", "177 ± 43", "174 ± 48"), vx),
    list(list(x = 60, y = 320, text = "*N = 49. Patients who had experienced menopause were excluded.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the heading above the first data line names it; Range lines are skipped with a reason", {
  r <- parseBaselineTableHeuristics(stackedPdf(), quiet = TRUE)
  rows <- unique(r$data$ROW)
  expect_true("Age, y" %in% rows)
  expect_true("Height, cm" %in% rows)
  expect_false(any(grepl("^Mean", rows)))
  expect_false(any(grepl(" 2$", rows)))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age, y"], c(46, 47, 47, 48))
  expect_identical(cont$SD[cont$ROW == "Height, cm"], c(11, 8, 10, 9))
  expect_identical(cont$N[cont$ROW == "Age, y"], rep(20L, 4))
  # the category under its heading is intact
  expect_true(any(grepl("^Sex", rows)))
  # the range lines are declined by name, under their heading
  expect_identical(sum(grepl("range without mean or SD", r$skipped$reason)), 2L)
  expect_true(all(grepl("Range$", r$skipped$label[grepl("range without", r$skipped$reason)])))
  expect_true(any(grepl("^Age, y Range", r$skipped$label)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("an arm-name line above the first data line is not taken for a heading", {
  # no "(n = k)" line: the arm names are the label line directly above the data
  f  <- file.path(tempdir(), "armsAbove.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1. Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx),
    rowCells(150, "Age (yr)",    c("45.3 ± 12.1", "46.1 ± 11.8"), vx),
    rowCells(168, "Weight (kg)", c("63 ± 13",     "68 ± 12"),     vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_setequal(unique(r$data$ROW), c("Age", "Weight"))   # units stripped by .ppCleanLabel
  expect_identical(r$arms$arm, c("Control", "Treatment"))
})

test_that("stretched watermark letters are dropped; ordinary and rotated words are kept", {
  w <- data.frame(text = c("A", "Age,", "y", "R", "Mean", "I", "Downloaded"),
                  x = c(122, 47, 60, -62, 51, 200, 590),
                  y = c(300, 310, 310, 400, 320, 330, 100),
                  width = c(133, 20, 6, 128, 24, 3, 5),
                  height = c(9, 9, 9, 9, 9, 9, 60), stringsAsFactors = FALSE)
  out <- .ppStripStretchedGlyphs(w)
  expect_identical(out$text, c("Age,", "y", "Mean", "I", "Downloaded"))
  expect_identical(.ppStripStretchedGlyphs(w[-c(1, 4), ]), w[-c(1, 4), ])
})

test_that("a one-letter label line does not replace the open heading, and a '<word> ±' fragment leaves the label", {
  f  <- file.path(tempdir(), "glyphLine.pdf")
  vx <- c(250, 320, 390)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Patient data", adj = 0)),
    rowCells(96,  "", c("A (n = 10)", "B (n = 10)", "C (n = 10)"), vx),
    rowCells(130, "Age (yr)", c("45 ± 12", "46 ± 11", "44 ± 10"), vx),
    list(list(x = 60, y = 150, text = "Weight, kg", adj = 0)),
    list(list(x = 60, y = 166, text = "R", adj = 0)),
    rowCells(182, "Mean ± SD", c("63 ± 13", "68 ± 12", "66 ± 11"), vx, labelX = 66),
    rowCells(204, "Duration of anesthesia, min 20l ±", c("40", "205 ± 40", "207 ± 41"), c(200, 320, 390)),
    list(list(x = 60, y = 230, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  rows <- unique(r$data$ROW)
  expect_true("Weight, kg" %in% rows)
  expect_false("R" %in% rows)
  expect_true("Duration of anesthesia, min" %in% rows)
  d <- r$data[r$data$ROW == "Duration of anesthesia, min" & !is.na(r$data$MEAN), ]
  expect_identical(d$MEAN, c(205, 207))
})
