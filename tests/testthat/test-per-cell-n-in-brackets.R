# test-per-cell-n-in-brackets.R - a bracketed integer that ends a cell's
# word, or follows it, is that cell's N: the number of patients the cell
# summarises, not the arm's (ISSUES.md issue 109, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD6 (Fujii, thyroidectomy, PMID 9924225):      #
# "Last menstrual cycle(days)[n] 15.3(3.2)[17] 16.2(2.9)[16] 16.1(3.6)[17] #
# 15.4(3.8)[16]" read with N 25 in every arm; the bracket is that          #
# variable's n (the premenopausal patients).                               #
############################################################################

bracketPdf <- function(file = file.path(tempdir(), "perCellN.pdf")) {
  vx <- c(200, 300, 400, 500)   # wide enough that the bracketed cells stay separate words
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Patient characteristics (mean (SD or range) or number).", adj = 0)),
    rowCells(90, "", c("Placebo", "20 ug/kg", "40 ug/kg", "100 ug/kg"), vx, labelX = 60),
    rowCells(104, "", c("(n = 25)", "(n = 25)", "(n = 25)", "(n = 25)"), vx, labelX = 60),
    rowCells(122, "Age(yr)", c("46.3(31-57)", "47.2(30-57)", "45.3(31-57)", "46.0(30-57)"), vx, labelX = 60),
    rowCells(140, "Height(cm)", c("156.7(6.4)", "157.2(7.0)", "157.5(7.4)", "156.7(7.7)"), vx, labelX = 60),
    rowCells(158, "Last menstrual cycle(days)[n]", c("15.3(3.2)[17]", "16.2(2.9)[16]", "16.1(3.6)[17]", "15.4(3.8)[16]"), vx, labelX = 60),
    rowCells(176, "Weight(kg)", c("52.3(5.0)", "55.8(7.7)", "52.6(6.5)", "55.2(10.7) [40]"), vx, labelX = 60),
    rowCells(194, "Duration of operation(min)", c("142.9(47.4)", "151.5(38.9)", "146.6(38.0)", "140.0(41.4)"), vx, labelX = 60),
    list(list(x = 60, y = 224, text = "No significant differences among the groups.", adj = 0)))
  for (k in seq_along(cells)) if (!is.null(cells[[k]]$adj) && cells[[k]]$adj == 0.5) cells[[k]]$adj <- 0
  makeTablePdf(file, cells)
}

test_that("a bracketed integer after a cell is that cell's N; larger than the arm N it is ignored; a range is not an n", {
  r <- parseBaselineTableHeuristics(bracketPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  men <- cont[grepl("menstrual", cont$ROW), ]
  expect_identical(nrow(men), 4L)
  expect_identical(men$N, c(17L, 16L, 17L, 16L))
  expect_identical(men$MEAN, c(15.3, 16.2, 16.1, 15.4))
  expect_identical(cont$N[cont$ROW == "Height"], rep(25L, 4))
  expect_identical(cont$N[cont$ROW == "Weight"], rep(25L, 4))      # "[40]" exceeds the arm N: ignored
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
