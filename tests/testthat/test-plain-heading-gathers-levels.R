# test-plain-heading-gathers-levels.R - n (%) rows indented under a
# label-only category heading are the levels of ONE category variable,
# named by the heading; a lone n (%) row with no heading keeps its binary
# form with a complement (ISSUES.md issue 111, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from          #
# CodeRabbit's reading of PR #412 (issue 105), on the corpus session's    #
# batch 25 AD1 (Kilic 2023, Cukurova Med J, Loadsman corpus): under the   #
# plain heading "Surgical Level" the rows "L2-3 12(57.1) 12(57.1)",       #
# "L3-4 8(38.1) 7(33.3)", "L4-5 1(4.8) 2(9.5)" each went out as a binary  #
# variable with a complement ("Lumbar / Not Lumbar", ...) because the     #
# walker gathered levels only under a heading that itself said "N (%)".  #
# The fixtures are rebuilt pages (makeTablePdf / rowCells in              #
# helper-syntheticPdf.R), so no corpus file is needed.                    #
############################################################################

plainHeadingPdf <- function(file = file.path(tempdir(), "plainHeading.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Demographics of patients and surgery", adj = 0)),
    rowCells(90, "", c("Group ESP (n = 21)", "Group Control (n = 21)"), vx),
    rowCells(108, "Age", c("52.3 ± 12.7", "52.9 ± 9.7"), vx),
    rowCells(126, "Weight (kg)", c("75.6 ± 7.4", "83.8 ± 9.7"), vx),
    rowCells(144, "Surgical level", c("", ""), vx),
    rowCells(162, "Lumbar", c("12 (57.1)", "12 (57.1)"), vx, labelX = 80),
    rowCells(180, "Thoracic", c("8 (38.1)", "7 (33.3)"), vx, labelX = 80),
    rowCells(198, "Cervical", c("1 (4.8)", "2 (9.5)"), vx, labelX = 80),
    rowCells(216, "Duration of surgery (min)", c("90.1 ± 6.2", "89.5 ± 11.9"), vx),
    list(list(x = 60, y = 246, text = "Data are presented as mean ± SD and percentages are presented as % within group.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("n (%) rows under a plain heading are one category variable with the heading's name", {
  r <- parseBaselineTableHeuristics(plainHeadingPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(21L, 21L))
  d <- r$data
  # ONE variable, named by the heading, its levels as columns ...
  lev <- d[d$ROW == "Surgical level", ]
  expect_identical(nrow(lev), 2L)
  expect_true(all(c("Lumbar", "Thoracic", "Cervical") %in% names(d)))
  expect_identical(lev[["Lumbar"]],   c(12L, 12L))
  expect_identical(lev[["Thoracic"]], c(8L, 7L))
  expect_identical(lev[["Cervical"]], c(1L, 2L))
  # ... not three binary variables, each with a complement that counts
  # the other levels' patients again
  expect_false(any(c("Lumbar", "Thoracic", "Cervical") %in% d$ROW))
  expect_false(any(grepl("^Not ", names(d))))
  # the continuous rows around the block are untouched, and the table validates
  cont <- d[!is.na(d$MEAN), ]
  expect_setequal(unique(cont$ROW), c("Age", "Weight", "Duration of surgery"))
  expect_false(isTRUE(vdShared(d)$FAIL))
})

test_that("a lone n (%) row with no heading keeps the binary path with its complement", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "loneNPct.pdf")
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Patient characteristics", adj = 0)),
    rowCells(90, "", c("Group A (n = 21)", "Group B (n = 21)"), vx),
    rowCells(108, "Age (yr)", c("52.3 ± 12.7", "52.9 ± 9.7"), vx),
    rowCells(126, "Male sex", c("12 (57.1)", "10 (47.6)"), vx),
    rowCells(144, "Weight (kg)", c("75.6 ± 7.4", "83.8 ± 9.7"), vx),
    list(list(x = 60, y = 176, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data
  male <- d[d$ROW == "Male sex", ]
  expect_identical(nrow(male), 2L)
  expect_identical(male[["Male sex"]], c(12L, 10L))
  expect_identical(male[["Not Male sex"]], c(9L, 11L))
})

test_that("a section heading over a single n (%) row does not make a one-level variable", {
  # "Demographic data" is a section of the table, not a variable; the one
  # n (%) row beneath it is gathered by the new rule and then given back
  # its binary form, because a category with one level is degenerate
  vx <- c(300, 420)
  f <- file.path(tempdir(), "sectionHeading.pdf")
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Patient characteristics", adj = 0)),
    rowCells(90, "", c("Group A (n = 21)", "Group B (n = 21)"), vx),
    rowCells(108, "Demographic data", c("", ""), vx),
    rowCells(126, "Male sex", c("12 (57.1)", "10 (47.6)"), vx, labelX = 80),
    rowCells(144, "Age (yr)", c("52.3 ± 12.7", "52.9 ± 9.7"), vx, labelX = 80),
    rowCells(162, "Weight (kg)", c("75.6 ± 7.4", "83.8 ± 9.7"), vx, labelX = 80),
    list(list(x = 60, y = 194, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  d <- r$data
  expect_false("Demographic data" %in% d$ROW)
  male <- d[d$ROW == "Male sex", ]
  expect_identical(nrow(male), 2L)
  expect_identical(male[["Male sex"]], c(12L, 10L))
  expect_identical(male[["Not Male sex"]], c(9L, 11L))
  expect_false(isTRUE(vdShared(d)$FAIL))
})
