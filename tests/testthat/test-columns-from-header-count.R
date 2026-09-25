# test-columns-from-header-count.R - the header's "(n = k)" count is a
# second opinion when the gap rule fuses two narrow columns (ISSUES.md
# issue 71, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 15a finding T1 (Fujii & Itakura 2009, PMID        #
# 19358990): three columns 35 points apart, the "(n = 30)" header tokens  #
# 8 points right of the cells, so the gap between the first two columns'  #
# tokens is 22 points and the 25-point gap rule fused them - two arms on   #
# every build, "Placebo Propofol, 0.25" and "g/kg Propofol, 0.5 mg/kg".    #
############################################################################

test_that(".ppClusterColumns(k = ) cuts at the widest gaps, and refuses a cut that is not a column gap", {
  # two real columns fused by jitter: 150..158 and 182..190, then 245..253
  mids <- c(150, 152, 158, 182, 184, 190, 245, 247, 253)
  expect_identical(.ppClusterColumns(mids)$n, 2L)
  c3 <- .ppClusterColumns(mids, k = 3L)
  expect_identical(c3$n, 3L)
  expect_identical(c3$assign(c(151, 185, 250)), c(1L, 2L, 3L))
  # asked for one column too many: the fourth cut would split a real column
  expect_null(.ppClusterColumns(mids, k = 4L))
  # a column whose own spread exceeds the narrowest cut gap is not split
  expect_null(.ppClusterColumns(c(100, 110, 120, 130, 141, 150), k = 2L))
  expect_null(.ppClusterColumns(c(100, 120), k = 3L))
})

narrowPdf <- function(file = file.path(tempdir(), "narrowCols.pdf")) {
  # columns 35 points apart, the header's "(n = 30)" tokens 10 points right
  # of the cells: the gap between the first two columns' tokens is 25, and
  # the gap rule (which needs MORE than 25) fuses them
  vx <- c(150, 185, 250)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient characteristics according to group", adj = 0)),
    rowCells(100, "", c("Placebo", "Low", "High"), vx),
    rowCells(112, "", c("(n = 30)", "(n = 30)", "(n = 30)"), vx + 10),
    rowCells(130, "Age, y", c("43 (9)", "43 (8)", "43 (8)"), vx),
    rowCells(148, "Height, cm", c("159 (8)", "158 (8)", "158 (8)"), vx),
    rowCells(166, "Weight, kg", c("57 (6)", "55 (10)", "55 (10)"), vx),
    rowCells(184, "No. of smokers", c("8", "9", "9"), vx),
    list(list(x = 60, y = 214, text = "Values are mean (SD) or number.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a table whose columns the gap rule fuses is read with the header's three arms", {
  r <- parseBaselineTableHeuristics(narrowPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$arm, c("Placebo", "Low", "High"))
  expect_identical(r$arms$N, rep(30L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(43, 43, 43))
  expect_identical(cont$SD[grepl("^Weight", cont$ROW)], c(6, 10, 10))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
