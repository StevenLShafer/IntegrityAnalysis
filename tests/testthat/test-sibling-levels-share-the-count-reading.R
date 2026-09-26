# test-sibling-levels-share-the-count-reading.R - once a level under an
# open category heading has read as n (%) by its own cells, its sibling
# levels' "a (b)" cells are counts too, a misprinted percentage
# notwithstanding (ISSUES.md issue 133, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 29 AH1 (Biricik 2024, J PeriAnesthesia Nursing,   #
# Loadsman corpus; four arms of 28): under "Type of surgery" the           #
# Tonsillectomy row "11 (39.3) 13 (46.3) 10 (35.7) 9 (32.1)" read as a     #
# continuous variable 11 +/- 39.3 because 13 of 28 is 46.4, not the        #
# page's 46.3, while its siblings read as counts.                          #
############################################################################

pm <- "\u00b1"

typeOfSurgeryPdf <- function(file = file.path(tempdir(), "typeOfSurgery.pdf")) {
  vx <- c(197, 283, 363, 448)
  cells <- c(
    list(list(x = 48, y = 60, text = "Table 2 Demographic and clinical data", adj = 0)),
    rowCells(80, "", c("Group A", "Group B", "Group C", "Group D"), vx, labelX = 48),
    rowCells(94, "", c("(n = 28)", "(n = 28)", "(n = 28)", "(n = 28)"), vx, labelX = 48),
    rowCells(114, "Age (year)", c(paste("7.08", pm, "2.9"), paste("7.21", pm, "3"), paste("6.58", pm, "2.2"), paste("6.12", pm, "2.3")), vx, labelX = 48),
    rowCells(132, "Duration of surgery (min)", c(paste("47.14", pm, "13.2"), paste("42.14", pm, "9.1"), paste("43.93", pm, "13.7"), paste("41.79", pm, "11.4")), vx, labelX = 48),
    list(list(x = 48, y = 150, text = "Type of surgery", adj = 0)),
    rowCells(162, "Adenoidectomy", c("7 (25)", "10 (35.7)", "8 (28.6)", "8 (28.6)"), vx, labelX = 54),
    # the page's misprint: 13 of 28 is 46.4
    rowCells(174, "Tonsillectomy", c("11 (39.3)", "13 (46.3)", "10 (35.7)", "9 (32.1)"), vx, labelX = 54),
    rowCells(186, "Adenoidectomy and tonsillectomy", c("10 (35.7)", "5 (17.9)", "10 (35.7)", "11 (39.3)"), vx, labelX = 54),
    rowCells(204, "Extubating time (sec)", c(paste("370.93", pm, "154"), paste("359", pm, "142"), paste("371.89", pm, "133"), paste("314.57", pm, "125")), vx, labelX = 48),
    list(list(x = 48, y = 236, text = paste("Values are mean", pm, "SD or n (%)."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a level with a misprinted percentage under a heading whose sibling read as n (%) is a count row", {
  r <- parseBaselineTableHeuristics(typeOfSurgeryPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(28L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_false(any(cont$MEAN == 11 & cont$SD == 39.3))
  expect_false(any(grepl("^Tonsillectomy", cont$ROW)))
  expect_setequal(unique(sub(" .*", "", cont$ROW)), c("Age", "Duration", "Extubating"))
  expect_true(any(grepl("Tonsillectomy", c(r$data$ROW, names(r$data)))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
