# test-label-fragment-above-values.R - a row label whose first line stands
# above the value line, the value line keeping the second half ("Duration
# of" over "surgery (min) 150 ± 59 ..."), is one label (ISSUES.md issue
# 112, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE6 (CJA 1998, PMID 9717598; 11240988;         #
# 8825534): "Duration of surgery" read as "surgery", "Peroperative blood   #
# loss" as "loss", "Duration of operation (min)" as "Unnamed", the         #
# fragment above taken for a category heading.                             #
############################################################################

fragmentPdf <- function(file = file.path(tempdir(), "labelFragment.pdf")) {
  vx <- c(330, 420, 510)
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Demographic data", adj = 0)),
    rowCells(80, "", c("Group C", "Group N", "Group D"), vx, labelX = 60),
    rowCells(92, "", c("(n = 20)", "(n = 20)", "(n = 20)"), vx, labelX = 60),
    rowCells(98, "Age (yr)", c("60 \u00b1 9", "62 \u00b1 9", "62 \u00b1 9"), vx, labelX = 60),
    rowCells(116, "Height (cm)", c("156 \u00b1 10", "155 \u00b1 9", "154 \u00b1 8"), vx, labelX = 60),
    list(list(x = 60, y = 134, text = "Duration of", adj = 0)),
    rowCells(146, "surgery (min)", c("150 \u00b1 59", "146 \u00b1 76", "149 \u00b1 55"), vx, labelX = 60),
    list(list(x = 60, y = 164, text = "Peroperative blood", adj = 0)),
    rowCells(176, "loss (ml)", c("147 \u00b1 97", "141 \u00b1 85", "142 \u00b1 81"), vx, labelX = 60),
    list(list(x = 60, y = 194, text = "Duration of anaesthesia", adj = 0)),
    rowCells(206, "(min)", c("178 \u00b1 59", "176 \u00b1 74", "179 \u00b1 55"), vx, labelX = 60),
    list(list(x = 60, y = 224, text = "Types of surgery", adj = 0)),
    rowCells(236, "Upper extremity", c("7", "8", "8"), vx, labelX = 75),
    rowCells(254, "Lower extremity", c("13", "12", "12"), vx, labelX = 75),
    list(list(x = 60, y = 284, text = "Values are mean \u00b1 SD or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a label fragment above the value line is joined to the row's own label; a true heading over capitalised levels stays a heading", {
  r <- parseBaselineTableHeuristics(fragmentPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 20L, 20L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Height", "Duration of surgery", "Peroperative blood loss", "Duration of anaesthesia"))
  expect_identical(cont$MEAN[cont$ROW == "Duration of surgery"], c(150, 146, 149))
  expect_identical(cont$MEAN[cont$ROW == "Duration of anaesthesia"], c(178, 176, 179))
  expect_false(any(grepl("^surgery$|^loss$|Unnamed", r$data$ROW)))
  expect_true(any(grepl("Upper extremity|Lower extremity", c(r$data$ROW, names(r$data)))))   # the levels of the heading
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
