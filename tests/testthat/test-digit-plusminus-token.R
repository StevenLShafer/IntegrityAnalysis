# test-digit-plusminus-token.R - the announced plus-minus digit as a token
# of its own: "Values are mean 6 sd." and cells "141 6 9" (ISSUES.md issue
# 59, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 8 finding N1 (Fujii 1999, PMID 10475325): the     #
# Symbol-font plus-minus is set as the digit 6, separated from its         #
# numbers by spaces, so every cell was three plain tokens. Issue 45's      #
# "mean2SD" rule handled the fused form ("49.527.9") only.                 #
############################################################################

test_that("with 'mean 6 sd' announced, plain triples around the digit are mean +/- SD cells", {
  f  <- file.path(tempdir(), "digit6.pdf")
  vx <- c(260, 360, 460)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Demographic data", adj = 0)),
    rowCells(100, "", c("Group I (n = 10)", "Group II (n = 10)", "Group III (n = 10)"), vx),
    rowCells(130, "HR (bpm)",    c("141 6 9", "139 6 10", "141 6 7"), vx),
    rowCells(148, "MAP (mm Hg)", c("122 6 7", "123 6 7", "122 6 8"), vx),
    rowCells(166, "CO (L/min)",  c("3.1 6 0.4", "3.0 6 0.5", "3.2 6 0.4"), vx),
    list(list(x = 60, y = 200, text = "Values are mean 6 sd.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$MEAN[d$ROW == "HR"], c(141, 139, 141))
  expect_identical(d$SD[d$ROW == "HR"],   c(9, 10, 7))
  expect_identical(d$SD[grepl("^CO", d$ROW)], c(0.4, 0.5, 0.4))   # "(L/min)" stays in the label (a slash)
  expect_identical(nrow(r$arms), 3L)
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("unannounced, a 6 between two numbers stays three counts", {
  f  <- file.path(tempdir(), "digit6b.pdf")
  vx <- c(260, 360, 460)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Demographic data", adj = 0)),
    rowCells(100, "", c("Group I (n = 10)", "Group II (n = 10)", "Group III (n = 10)"), vx),
    list(list(x = 60, y = 120, text = "ASA class, n", adj = 0)),
    rowCells(138, "I",  c("4", "6", "3"), vx, labelX = 70),
    rowCells(156, "II", c("6", "4", "7"), vx, labelX = 70),
    rowCells(180, "Age (yr)", c("45 ± 12", "46 ± 11", "44 ± 10"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_true(any(r$data$ROW == "ASA class, n"))
  expect_identical(sum(!is.na(r$data$MEAN)), 3L)
})
