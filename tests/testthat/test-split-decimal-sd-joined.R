# test-split-decimal-sd-joined.R - a decimal number split at its point
# into two touching words ("5." "I") is joined, and its fused form ("5.I")
# is read, so the slot rule can read the sign before it (ISSUES.md issue
# 127, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 item on CJA 1994, PMID 8004733 (a scan; three  #
# arms of 20): "Height (cm) 152.8 4- 5.9 152.4 4- 4,7 153.5 5: 5. I" -    #
# the third arm's SD "5.1" as "5." and "I", the cell lost.                 #
############################################################################

pm <- "\u00b1"

test_that("the helper joins a digits-and-point word with the touching look-alike digit after it", {
  L <- data.frame(text = c("Height", "(cm)", "153.5", "5:", "5.", "I"),
                  x = c(48, 66, 246, 260, 266, 271), width = c(15, 10, 12, 4, 4, 1), stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(data.frame(text = "Table", x = 48, width = 20), L), capIdx = 1L)
  expect_identical(r$repaired, 1L)
  expect_identical(r$lines[[2]]$text, c("Height", "(cm)", "153.5", "5:", "5.1"))
  expect_equal(r$lines[[2]]$width[5], 272 - 266)
  # a gap wider than two points is two words: a sentence's full stop before a footnote digit
  L2 <- data.frame(text = c("mg.", "1", "Patients"), x = c(100, 112, 120), width = c(14, 4, 30), stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L2))
  expect_identical(r$repaired, 0L)
  L3 <- data.frame(text = c("60.", "l"), x = c(100, 114), width = c(13, 2), stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L3))
  expect_identical(r$lines[[1]]$text, "60.1")
  # a split "o" is a footnote letter as much as a zero: left, like the fused "5.o"
  L5 <- data.frame(text = c("5.", "o", "5.", "O"), x = c(100, 112, 130, 142), width = c(11, 4, 11, 5),
                   stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L5))
  expect_identical(r$repaired, 0L)
  # the fused form, as a layer that sets the pieces closer gives it
  L4 <- data.frame(text = c("153.5", "5:", "5.I", "5.o"), x = c(246, 260, 266, 280), width = c(12, 4, 6, 6),
                   stringsAsFactors = FALSE)
  r <- .ppRepairSplitDecimals(list(L4))
  expect_identical(r$repaired, 1L)
  expect_identical(r$lines[[1]]$text, c("153.5", "5:", "5.1", "5.o"))
})

splitSdPdf <- function(file = file.path(tempdir(), "splitSd.pdf")) {
  vx <- c(200, 290, 380)
  cell <- function(y, k, mean, sign, sd) list(
    list(x = vx[k] - 3, y = y, text = mean, adj = 1),
    list(x = vx[k], y = y, text = sign, adj = 0),
    list(x = vx[k] + 14, y = y, text = sd, adj = 0))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 60, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Patient characteristics", adj = 0)),
    rowCells(90, "", c("Placebo (n = 20)", "Metoclopramide (n = 20)", "Granisetron (n = 20)"), vx, labelX = 60),
    row(108, "Age (yr)", c("47.3", "46.7", "45.5"), rep(pm, 3), c("9.3", "10.1", "8.6")),
    # the third arm's SD split at its point: "5." and a touching "I" (the
    # pdf device sets them close enough that the text layer fuses them: "5.I")
    c(row(126, "Height (cm)", c("152.8", "152.4", "153.5"), c(pm, pm, "5:"), c("5.9", "4.7", "5.")),
      list(list(x = vx[3] + 14 + 9, y = 126, text = "I", adj = 0))),
    row(144, "Weight (kg)", c("54.1", "55.2", "52.5"), rep(pm, 3), c("7.6", "9.1", "6.0")),
    list(list(x = 60, y = 176, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the third arm's Height through the split SD and the lone digit-colon sign", {
  r <- parseBaselineTableHeuristics(splitSdPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(152.8, 152.4, 153.5))
  expect_identical(cont$SD[cont$ROW == "Height"], c(5.9, 4.7, 5.1))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(7.6, 9.1, 6.0))
})
