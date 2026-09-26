# test-p-values-heading-over-no-column.R - a "P values" heading whose column
# holds no token attaches to the last arm's name; the phrase is stripped and
# the arm kept, while a name that is the phrase alone still marks the
# p-value column (ISSUES.md issue 138, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG3 (EJA 1998, PMID 9587723; four arms of 30 on #
# a page printed sideways): the header "(n =30) ... P values" over a       #
# column of "NS" named the fourth arm "Placebo P values", and the p-value  #
# rule dropped the Placebo arm with every cell in it.                      #
############################################################################

pm <- "\u00b1"

pValuesOverNsPdf <- function(file = file.path(tempdir(), "pValuesOverNs.pdf")) {
  vx <- c(200, 280, 360, 440); px <- 488
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Patient demographics and anaesthetic data", adj = 0)),
    rowCells(80, "", c("Granisetron", "Droperidol", "Metoclopramide", "Placebo"), vx, labelX = 60),
    c(rowCells(94, "", c("(n = 30)", "(n = 30)", "(n = 30)", "(n = 30)"), vx, labelX = 60),
      list(list(x = px, y = 94, text = "P-values", adj = 0.5))),
    c(rowCells(112, "Age (years)", c(paste("47.2", pm, "9.4"), paste("47.6", pm, "7.2"), paste("46.9", pm, "9.2"), paste("47.7", pm, "9.1")), vx, labelX = 60),
      list(list(x = px, y = 112, text = "NS", adj = 0.5))),
    c(rowCells(130, "Height (cm)", c(paste("156.9", pm, "6.3"), paste("157.0", pm, "6.9"), paste("156.2", pm, "5.9"), paste("156.2", pm, "6.5")), vx, labelX = 60),
      list(list(x = px, y = 130, text = "NS", adj = 0.5))),
    c(rowCells(148, "Weight (kg)", c(paste("55.7", pm, "6.8"), paste("56.3", pm, "8.4"), paste("55.4", pm, "7.2"), paste("56.9", pm, "8.2")), vx, labelX = 60),
      list(list(x = px, y = 148, text = "NS", adj = 0.5))),
    list(list(x = 60, y = 180, text = paste("All values are expressed as mean", pm, "SD or number."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a P-values heading over a column of NS does not cost the last arm", {
  r <- parseBaselineTableHeuristics(pValuesOverNsPdf(), quiet = TRUE)
  expect_identical(r$arms$arm, c("Granisetron", "Droperidol", "Metoclopramide", "Placebo"))
  expect_identical(r$arms$N, rep(30L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(47.2, 47.6, 46.9, 47.7))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(55.7, 56.3, 55.4, 56.9))
})

pValuesWithNumbersPdf <- function(file = file.path(tempdir(), "pValuesWithNumbers.pdf")) {
  vx <- c(200, 280, 360, 440); px <- 488
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Patient demographics", adj = 0)),
    rowCells(80, "", c("Granisetron", "Droperidol", "Metoclopramide", "Placebo"), vx, labelX = 60),
    c(rowCells(94, "", c("(n = 30)", "(n = 30)", "(n = 30)", "(n = 30)"), vx, labelX = 60),
      list(list(x = px, y = 94, text = "P-values", adj = 0.5))),
    rowCells(112, "Age (years)", c(paste("47.2", pm, "9.4"), paste("47.6", pm, "7.2"), paste("46.9", pm, "9.2"), paste("47.7", pm, "9.1"), "0.83"), c(vx, px), labelX = 60),
    rowCells(130, "Height (cm)", c(paste("156.9", pm, "6.3"), paste("157.0", pm, "6.9"), paste("156.2", pm, "5.9"), paste("156.2", pm, "6.5"), "0.91"), c(vx, px), labelX = 60),
    rowCells(148, "Weight (kg)", c(paste("55.7", pm, "6.8"), paste("56.3", pm, "8.4"), paste("55.4", pm, "7.2"), paste("56.9", pm, "8.2"), "0.77"), c(vx, px), labelX = 60),
    list(list(x = 60, y = 180, text = paste("All values are expressed as mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a P-values column with its own numbers is still dropped", {
  r <- parseBaselineTableHeuristics(pValuesWithNumbersPdf(), quiet = TRUE)
  expect_identical(r$arms$arm, c("Granisetron", "Droperidol", "Metoclopramide", "Placebo"))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(47.2, 47.6, 46.9, 47.7))
})
