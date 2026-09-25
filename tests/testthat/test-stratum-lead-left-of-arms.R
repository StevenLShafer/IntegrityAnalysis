# test-stratum-lead-left-of-arms.R - a stratum's name stands at the
# row-label margin; a wrapped arm name's second line with its "(n = k)"
# is not a stratum (ISSUES.md issue 73, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 16 finding V1 (Akkus 2020, J Anesth, Loadsman     #
# corpus, page 4): "Group stand-" over "ard (n = 49)" beside "Group        #
# triple (n = 49)" - the second line was taken for a stratum named "ard",  #
# arm 1 lost its N and every row was prefixed "ard: ".                     #
############################################################################

wrappedArmPdf <- function(file = file.path(tempdir(), "wrappedArm.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Characteristics of patients and procedures", adj = 0)),
    rowCells(100, "", c("Group stand-", "Group triple (n = 49)"), vx),
    rowCells(112, "", c("ard (n = 49)", ""), vx),
    rowCells(130, "Age (years)", c("51 ± 16", "47 ± 14"), vx),
    rowCells(148, "Gender female n (%)", c("24 (49%)", "24 (49%)"), vx),
    rowCells(166, "BMI kg/m2", c("28 ± 4", "29 ± 3"), vx),
    rowCells(184, "Neck circumference (cm)", c("40 ± 4", "40 ± 5"), vx),
    list(list(x = 60, y = 214, text = "Values are mean ± SD or n (%).", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a wrapped arm name's second line with its (n = k) is the header's, not a stratum", {
  r <- parseBaselineTableHeuristics(wrappedArmPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$N, c(49L, 49L))
  expect_false(any(grepl("^ard", r$data$ROW)))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(51, 47))
  expect_identical(cont$SD[grepl("^Neck", cont$ROW)], c(4, 5))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("a stratum line at the row-label margin is still a stratum", {
  f  <- file.path(tempdir(), "stratumKept.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(100, "", c("Placebo (n = 50)", "Drug (n = 50)"), vx),
    list(list(x = 60, y = 118, text = "Young patients (n = 50) (n = 25) (n = 25)", adj = 0)),
    rowCells(136, "Age, y", c("30 ± 5", "31 ± 6"), vx),
    list(list(x = 60, y = 154, text = "Older patients (n = 50) (n = 25) (n = 25)", adj = 0)),
    rowCells(172, "Age, y", c("70 ± 5", "71 ± 6"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_true(any(grepl("^Young patients: Age", r$data$ROW)))
  expect_true(any(grepl("^Older patients: Age", r$data$ROW)))
})
