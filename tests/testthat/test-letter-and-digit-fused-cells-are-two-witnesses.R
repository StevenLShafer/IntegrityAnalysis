# test-letter-and-digit-fused-cells-are-two-witnesses.R - a line with one
# letter-fused cell ("53.7?7.1") and one digit-fused cell of the same
# precision ("54.626.6") has the two witnesses the fused-sign repair wants
# (ISSUES.md issue 137, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG5 (EJA 1997, PMID 9241336, a scan; two arms   #
# of 25): "Weight (kg) 54.626.6 53.7?7.1 NS" and "Peroperative blood loss   #
# (ml) 209.42136.7 211.7?130.9 NS" read nothing, the Height line with two   #
# digit-fused cells read.                                                   #
############################################################################

pm <- "\u00b1"

test_that("the fused-sign repair splits a letter-fused and a digit-fused cell on one line", {
  w <- function(...) { t <- c(...); data.frame(text = t, x = cumsum(c(0, head(nchar(t) + 1, -1))) * 6, width = nchar(t) * 6, stringsAsFactors = FALSE) }
  lines <- list(w("Table"),
                w("Weight", "(kg)", "54.626.6", "53.7?7.1", "NS"),
                w("Peroperative", "blood", "loss", "(ml)", "209.42136.7", "211.7?130.9", "NS"),
                # one letter-fused cell alone is still no evidence
                w("Dose", "(mg)", "5.3k1.2", "NS"),
                # and a digit-fused word beside a letter-fused cell of another precision is not its witness
                w("Time", "(min)", "12.345.6", "1.2?0.34"))
  r <- .ppRepairFusedSigns(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Weight", "(kg)", "54.6", pm, "6.6", "53.7", pm, "7.1", "NS"))
  expect_identical(r$lines[[3]]$text, c("Peroperative", "blood", "loss", "(ml)", "209.4", pm, "136.7", "211.7", pm, "130.9", "NS"))
  expect_identical(r$lines[[4]]$text, c("Dose", "(mg)", "5.3k1.2", "NS"))
  expect_identical(r$lines[[5]]$text, c("Time", "(min)", "12.345.6", "1.2?0.34"))
})

twoWitnessPdf <- function(file = file.path(tempdir(), "twoWitness.pdf")) {
  vx <- c(343, 433)
  cells <- c(
    list(list(x = 57, y = 60, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(80, "", c("Group I (n = 25)", "Group II (n = 25)"), vx, labelX = 57),
    rowCells(100, "Age (yr)", c(paste("42.3", pm, "8.1"), paste("41.6", pm, "7.9")), vx, labelX = 57),
    rowCells(118, "Height (cm)", c("154.625.4", "154.824.8"), vx, labelX = 57),
    rowCells(136, "Weight (kg)", c("54.626.6", "53.7?7.1"), vx, labelX = 57),
    rowCells(154, "Peroperative blood loss (ml)", c("209.42136.7", "211.7?130.9"), vx, labelX = 57),
    list(list(x = 57, y = 190, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the Weight and blood loss rows through the two fused forms", {
  r <- parseBaselineTableHeuristics(twoWitnessPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(25L, 25L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(54.6, 53.7))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(6.6, 7.1))
  expect_identical(cont$MEAN[grepl("^Peroperative", cont$ROW)], c(209.4, 211.7))
  expect_identical(cont$SD[grepl("^Peroperative", cont$ROW)], c(136.7, 130.9))
})
