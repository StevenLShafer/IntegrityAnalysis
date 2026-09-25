# test-identical-n-pct-cells-under-heading.R - under a category heading,
# two arms printing the same "n(%)" cell are two pieces of evidence, not
# one: the row is n (%), not mean (SD) (ISSUES.md issue 105, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD1 (Kilic 2023, Cukurova Med J, Loadsman     #
# corpus): "L2-3 12(57.1) 12(57.1)" under "Surgical Level", two arms of   #
# 21, read as a continuous row with mean 12 and SD 57.1 while its sibling #
# rows were n (%).                                                        #
############################################################################

identicalPdf <- function(file = file.path(tempdir(), "identicalCells.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Demographics of patients and surgery", adj = 0)),
    rowCells(90, "", c("Group ESP (n = 21)", "Group Control (n = 21)"), vx),
    rowCells(108, "Age", c("52.3 \u00b1 12.7", "52.9 \u00b1 9.7"), vx),
    rowCells(126, "Weight (kg)", c("75.6 \u00b1 7.4", "83.8 \u00b1 9.7"), vx),
    rowCells(144, "Surgical level", c("", ""), vx),
    rowCells(162, "Lumbar", c("12 (57.1)", "12 (57.1)"), vx, labelX = 80),
    rowCells(180, "Thoracic", c("8 (38.1)", "7 (33.3)"), vx, labelX = 80),
    rowCells(198, "Cervical", c("1 (4.8)", "2 (9.5)"), vx, labelX = 80),
    rowCells(216, "Duration of surgery (min)", c("90.1 \u00b1 6.2", "89.5 \u00b1 11.9"), vx),
    list(list(x = 60, y = 246, text = "Data are presented as mean \u00b1 SD and percentages are presented as % within group.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("identical n (%) cells in both arms under a category heading read as counts, not mean (SD)", {
  r <- parseBaselineTableHeuristics(identicalPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(21L, 21L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Weight", "Duration of surgery"))
  expect_false(any(grepl("Lumbar", cont$ROW)))
  lev <- r$data[grepl("Lumbar|Thoracic|Cervical", r$data$ROW), ]
  expect_true(nrow(lev) >= 2)
  expect_true(all(is.na(lev$MEAN)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("outside a category heading the rule is unchanged: one signature echoed in two arms is not enough", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "echoCells.pdf")
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Patient characteristics", adj = 0)),
    rowCells(90, "", c("Group A (n = 20)", "Group B (n = 20)"), vx),
    rowCells(108, "Age (yr)", c("45.2 (6.1)", "44.8 (5.9)"), vx),
    rowCells(126, "Score", c("10 (50.0)", "10 (50.0)"), vx),
    rowCells(144, "Weight (kg)", c("70.1 (8.2)", "71.4 (7.9)"), vx),
    list(list(x = 60, y = 176, text = "Values are mean (SD).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_true("Score" %in% cont$ROW)
})
