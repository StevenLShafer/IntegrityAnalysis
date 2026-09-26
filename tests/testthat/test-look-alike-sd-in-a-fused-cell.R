# test-look-alike-sd-in-a-fused-cell.R - a letter-fused cell whose SD came
# through as a look-alike letter ("5tl" for 5 +/- 1) is a cell beside a
# plain letter-fused cell with the same sign letter, and a three-digit
# digit-fused cell splits at a one-digit mean when every witness's mean is
# one digit ("521" for 5 +/- 1) (ISSUES.md issue 146, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 30 (Br J Anaesth 1998, PMID 9689270, a scan; four #
# arms of 30): "Morphine (mg, epidurally) 6t1 5tl 521 6tl NS" read         #
# nothing - two of its four cells had an "l" for the SD's "1" and the     #
# third a "2" for the sign before a one-digit mean.                        #
############################################################################

pm <- "\u00b1"

test_that("the fused-sign repair reads look-alike SDs beside a plain letter-fused cell, and a one-digit-mean digit-fused cell", {
  line <- function(...) {
    w <- c(...); x <- c(60, 230, 297, 374, 451, 522)
    data.frame(text = w, x = x[seq_along(w)], width = c(40, 15, 14, 15, 14, 11)[seq_along(w)], stringsAsFactors = FALSE)
  }
  lines <- list(line("Table"),
                line("Morphine", "6t1", "5tl", "521", "6tl", "NS"))
  r <- .ppRepairFusedSigns(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Morphine", "6", pm, "1", "5", pm, "1", "5", pm, "1", "6", pm, "1", "NS"))
  expect_identical(r$repaired, 4L)
  # a look-alike form with no plain cell of the same sign letter on the
  # line is not a cell: "5ml" stays a word
  lines2 <- list(line("Table"),
                 line("Saline", "5ml", "2.1", pm, "0.3", "2.2"))
  r2 <- .ppRepairFusedSigns(lines2, capIdx = 1L)
  expect_identical(r2$lines[[2]]$text, c("Saline", "5ml", "2.1", pm, "0.3", "2.2"))
})

lookAlikeSdPdf <- function(file = file.path(tempdir(), "lookAlikeSd.pdf")) {
  vx <- c(225, 293, 370, 447)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  cell <- function(y, k, mean, sd) list(w(vx[k], y, mean), w(vx[k] + 22, y, pm), w(vx[k] + 30, y, sd))
  row <- function(y, label, means, sds) c(list(w(52, y, label)),
    unlist(lapply(1:4, function(k) cell(y, k, means[k], sds[k])), recursive = FALSE), list(w(522, y, "NS")))
  cells <- c(
    list(w(53, 60, "Table 1 Patient characteristics")),
    rowCells(80, "", c("Placebo", "Granisetron 1 mg", "Granisetron 2 mg", "Granisetron 4 mg"), vx + 12, labelX = 52),
    rowCells(94, "", c("(n = 30)", "(n = 30)", "(n = 30)", "(n = 30)"), vx + 12, labelX = 52),
    row(112, "Age (years)", c("45", "44", "43", "44"), c("8", "7", "9", "8")),
    row(130, "Weight (kg)", c("56", "54", "54", "56"), c("8", "8", "8", "7")),
    list(w(52, 148, "Morphine (mg, epidurally)"), w(vx[1], 148, "6t1"), w(vx[2], 148, "5tl"), w(vx[3], 148, "521"), w(vx[4], 148, "6tl"), w(522, 148, "NS")),
    list(w(52, 180, "Values are mean (SD) or number.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the Morphine row through its look-alike and digit-fused cells", {
  r <- parseBaselineTableHeuristics(lookAlikeSdPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(30L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Morphine", cont$ROW)], c(6, 5, 5, 6))
  expect_identical(cont$SD[grepl("^Morphine", cont$ROW)], c(1, 1, 1, 1))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(45, 44, 43, 44))
})
