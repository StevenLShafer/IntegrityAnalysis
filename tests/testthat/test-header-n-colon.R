# test-header-n-colon.R - "(n:25)" under the arm names is the arm-size line
# as surely as "(n = 25)": it makes the line a header, counts the arms for
# the column cut of issue 71, and gives each arm its N (ISSUES.md issue
# 97, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24 AC3 (Fujii, thyroidectomy, PMID 9924225):     #
# "Placebo 20 ug/kg 40 ug/kg 100 ug/kg" over "(n:25) (n:25) (n:25) (n:25)",  #
# cells such as "46.3(31-57)" set five points apart; two arms read where   #
# four are printed, N missing, because every header rule wanted "n =".    #
############################################################################

colonHeaderPdf <- function(file = file.path(tempdir(), "colonHeader.pdf")) {
  # the cells are wide and the columns close, as on the page: the gap rule
  # alone fuses them, and only the header count cuts four
  vx <- c(260, 315, 368, 422)
  cells <- c(
    list(list(x = 107, y = 60, text = "Table 1 Patient characteristics (mean (SD or range) or number).", adj = 0)),
    rowCells(90, "", c("Placebo", "20 ug/kg", "40 ug/kg", "100 ug/kg"), vx, labelX = 107),
    rowCells(104, "", c("(n:25)", "(n:25)", "(n:25)", "(n:25)"), vx, labelX = 107),
    rowCells(122, "Age(yr)", c("46.3(31-57)", "47.2(30-57)", "45.3(31-57)", "46.0(30-57)"), vx, labelX = 107),
    rowCells(140, "Height(cm)", c("156.7(6.4)", "157.2(7.0)", "157.5(7.4)", "156.7(7.7)"), vx, labelX = 107),
    rowCells(158, "Weight(kg)", c("52.3(5.0)", "55.8(7.7)", "52.6(6.5)", "55.2(10.7)"), vx, labelX = 107),
    rowCells(176, "Duration of operation(min)", c("142.9(47.4)", "151.5(38.9)", "146.6(38.0)", "140.0(41.4)"), vx, labelX = 107),
    list(list(x = 107, y = 210, text = "No significant differences among the groups.", adj = 0)))
  for (k in seq_along(cells)) if (!is.null(cells[[k]]$adj) && cells[[k]]$adj == 0.5) cells[[k]]$adj <- 0
  makeTablePdf(file, cells)
}

test_that("'(n:25)' heads four arms of 25 and the columns are cut by that count", {
  r <- parseBaselineTableHeuristics(colonHeaderPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 4L)
  expect_identical(r$arms$N, rep(25L, 4))
  expect_false(any(grepl(":", r$arms$arm, fixed = TRUE)))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(156.7, 157.2, 157.5, 156.7))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(5.0, 7.7, 6.5, 10.7))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
