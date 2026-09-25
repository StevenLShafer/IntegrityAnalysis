# test-single-token-column-not-arm.R - a column fed by one token across a
# block of four or more data lines, while every other column holds three
# or more, is a stray and not an arm column (ISSUES.md issue 113,
# 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE7 (CJA 1998, PMID 9717598, a scan): the      #
# level "-Lower extremity" prints as "-Lower extremit 3," and the "3," at  #
# the label's edge seeded a fourth column; the table read four arms with   #
# the first nameless and N-less and every row flagged "3 of 4".            #
############################################################################

strayPdf <- function(file = file.path(tempdir(), "strayColumn.pdf")) {
  vx <- c(395, 444, 491)
  cells <- c(
    list(list(x = 307, y = 60, text = "TABLE I Demographic data", adj = 0)),
    rowCells(80, "", c("Group C", "Group N", "Group D"), vx, labelX = 307),
    rowCells(94, "", c("(n = 20)", "(n = 20)", "(n = 20)"), vx, labelX = 307),
    rowCells(112, "Age (yr)", c("60 \u00b1 9", "62 \u00b1 9", "62 \u00b1 9"), vx, labelX = 307),
    rowCells(130, "Height (cm)", c("156 \u00b1 10", "155 \u00b1 9", "154 \u00b1 8"), vx, labelX = 307),
    rowCells(148, "Weight (kg)", c("58 \u00b1 10", "59 \u00b1 11", "56 \u00b1 9"), vx, labelX = 307),
    rowCells(166, "Types of surgery", c("", "", ""), vx, labelX = 307),
    rowCells(184, "- Upper extremity", c("7", "8", "8"), vx, labelX = 307),
    list(list(x = 307, y = 202, text = "- Lower extremit", adj = 0), list(x = 364, y = 202, text = "3,", adj = 0),
         list(x = 396, y = 202, text = "13", adj = 0), list(x = 444, y = 202, text = "12", adj = 0), list(x = 491, y = 202, text = "12", adj = 0)),
    list(list(x = 307, y = 232, text = "Values are mean \u00b1 SD or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a stray digit at a label's edge feeds no arm column: three named arms of 20", {
  r <- parseBaselineTableHeuristics(strayPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$arm, c("Group C", "Group N", "Group D"))
  expect_identical(r$arms$N, c(20L, 20L, 20L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(60, 62, 62))
  expect_identical(nrow(cont), 9L)
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
