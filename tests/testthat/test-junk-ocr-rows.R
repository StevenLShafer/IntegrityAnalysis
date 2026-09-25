# test-junk-ocr-rows.R - the OCR of a figure beneath a scanned table, and a
# footnote sentence between caption and header, stay out of the arms and
# the rows (ISSUES.md issue 46, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's junk-label finding G3 (CJA 1995;42:1096, a scanned      #
# page = Fujii/PMID_8595684): beneath Table I the OCR of a figure's axis   #
# ("30", "20", "10" down the left, "15 20 25 30 35 40" along the bottom)   #
# seeded three columns no cell used, the arm count went to five, the      #
# fence that keeps prose out of the arm names widened with it, and the    #
# footnote sentence between caption and header named the arms "were no",  #
# "differences in", ...; the axis ticks became levels "Category" 1-3 of a #
# heading "Sr". The page cannot ship; the layout is rebuilt here.         #
############################################################################

scannedPdf <- function(file = file.path(tempdir(), "scanned.pdf")) {
  vx <- c(200, 260)
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Demographic data (Number or mean ± SD). PTBC = post-tetanic", adj = 0)),
    list(list(x = 60, y = 74, text = "were no differences in number of patients, age, sex, height, or body weight", adj = 0)),
    rowCells(94,  "", c("PTBC", "PTC"), vx),
    rowCells(110, "Number of patients", c("15", "15"), vx),
    rowCells(126, "Age (yr)",         c("45.5 ± 11.4", "45.0 ± 9.5"), vx),
    rowCells(142, "Height (cm)",      c("167.1 ± 10.0", "166.9 ± 10.2"), vx),
    rowCells(158, "Body weight (kg)", c("56.7 ± 6.9", "57.1 ± 6.7"), vx),
    # the figure beneath, as OCR delivers it: an axis label, ticks with no row label
    list(list(x = 239, y = 180, text = "Sr", adj = 0)),
    list(list(x = 78, y = 196, text = "30", adj = 0)),
    list(list(x = 78, y = 212, text = "20", adj = 0)),
    list(list(x = 78, y = 228, text = "10", adj = 0)),
    list(list(x = 112, y = 244, text = "i I | I I t", adj = 0)),
    list(list(x = 111, y = 260, text = "15", adj = 0)), list(list(x = 145, y = 260, text = "20", adj = 0)),
    list(list(x = 179, y = 260, text = "25", adj = 0)), list(list(x = 213, y = 260, text = "30", adj = 0)),
    list(list(x = 247, y = 260, text = "35", adj = 0)), list(list(x = 275, y = 260, text = "40", adj = 0)),
    list(list(x = 170, y = 280, text = "Time (min)", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("axis ticks with no row label feed no arm column; the footnote sentence names no arm; the ticks are not levels", {
  r <- parseBaselineTableHeuristics(scannedPdf(), quiet = TRUE)
  expect_identical(r$arms$arm, c("PTBC", "PTC"))
  expect_identical(r$arms$N, c(15L, 15L))
  rows <- unique(r$data$ROW)
  expect_setequal(rows, c("Age", "Height", "Body weight"))
  expect_false(any(grepl("^Sr|^Time|Category", names(r$data))))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(45.5, 45.0))
  # since issue 93 the tick line is dropped as an axis before the level
  # step, so it is neither a level nor a skipped one
  expect_false(any(grepl("^15$|15 20 25", c(r$skipped$label, r$data$ROW))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a table whose every line is labelled is untouched by the column rule", {
  r <- parseBaselineTableHeuristics(syntheticPdfMeanSD(), quiet = TRUE)
  expect_identical(r$arms$arm, c("Control", "Treatment"))
  expect_identical(r$arms$N, c(15L, 17L))
  expect_true(all(c("Age", "Weight", "Height") %in% r$data$ROW))
})
