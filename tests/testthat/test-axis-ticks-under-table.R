# test-axis-ticks-under-table.R - a figure's axis running on under the
# table, its ticks closer together than the arm columns, is not a row and
# does not vote on the columns; the rail's short words go with the rail
# (ISSUES.md issue 93, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 23b AB1 (Saitoh, Br J Anaesth 1995;74:293,        #
# Loadsman corpus): once issue 86 stripped the OUP rail, the block ran    #
# on into the time axis of Figure 2 - "15 20 25 ... 100", eleven points   #
# apart - which bridged the two arm columns into one, and the table read  #
# one arm; the rail's "at" stayed, glued to the label "Weight (kg) at".   #
############################################################################

test_that("the rail's short upright-shaped words at its x, within its span, are stripped with it", {
  page <- data.frame(
    text = c("Age", "(yr)", "45", "±", "12", "of", "by", "kg",
             "Downloaded", "http://bja.oxfordjournals.org/", "at", "University", "on", "2015", "at"),
    x = c(60, 80, 200, 215, 225, 300, 320, 340, 575, 575, 575, 575, 575, 575, 575),
    y = c(100, 100, 100, 100, 100, 120, 120, 120, 266, 326, 420, 429, 520, 566, 700),
    width = c(16, 14, 10, 6, 10, 8, 8, 9, 7, 7, 7, 7, 7, 7, 7),
    height = c(8, 8, 8, 8, 8, 8, 8, 8, 40, 92, 8, 33, 8, 16, 8),
    stringsAsFactors = FALSE)
  body <- data.frame(text = paste0("w", 1:12), x = seq(60, 500, length.out = 12), y = 300,
                     width = 12, height = 8, stringsAsFactors = FALSE)
  page <- rbind(page, body)
  out <- .ppStripRotatedText(page)
  expect_false(any(grepl("Downloaded|oxfordjournals|University|^on$|^2015$", out$text)))
  expect_false(any(out$text == "at" & out$y == 420))    # inside the span: rail
  expect_true(any(out$text == "at" & out$y == 700))     # below the span: not the rail
  expect_true(all(c("Age", "45", "±", "of", "by", "kg") %in% out$text))
})

# The rebuilt page: Table 1 in the right-hand column and the figure's
# time axis (seventeen ticks thirteen points apart, no label) straight
# beneath it, as on the real page once the rail is gone. (The rail itself
# cannot be rebuilt here: makeTablePdf() sets every word nine points
# wide, and the stripper's rail test needs seven; the helper test above
# covers its short words.)
axisPdf <- function(file = file.path(tempdir(), "axisTicks.pdf")) {
  vx <- c(420, 490)
  tickVals <- seq(15, 95, by = 5)
  ticks <- lapply(seq_along(tickVals), function(j)
    list(x = 356 + 13 * (j - 1), y = 200, text = as.character(tickVals[j]), adj = 0))
  cells <- c(
    list(list(x = 325, y = 60, text = "Table 1 Patient data in the PTB and PTT groups", adj = 0)),
    rowCells(90,  "", c("PTB group", "PTT group"), vx, labelX = 340),
    rowCells(108, "Age (years)", c("49.1 (28-71)", "51.4 (29-69)"), vx, labelX = 340),
    rowCells(126, "Sex (M/F)", c("7/8", "7/8"), vx, labelX = 340),
    rowCells(144, "Height (cm)", c("166.2 (11.0)", "164.9 (10.5)"), vx, labelX = 340),
    rowCells(162, "Weight (kg)", c("57.7 (9.4)", "56.5 (9.9)"), vx, labelX = 340),
    ticks,
    list(list(x = 429, y = 220, text = "Time (min)", adj = 0)),
    list(list(x = 325, y = 240, text = "Figure 2 Time courses of evoked responses to PTB and PTT.", adj = 0)),
    list(list(x = 325, y = 270, text = "Two groups of 15 patients were studied.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the axis under the table bridges no columns: two arms, both cells of every row, a clean label", {
  r <- parseBaselineTableHeuristics(axisPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(166.2, 164.9))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(57.7, 56.5))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(9.4, 9.9))
  expect_true("Weight" %in% r$data$ROW)
  expect_false(any(grepl("Time|Figure", c(r$data$ROW, r$skipped$label))))
  expect_false(any(grepl("^Sex", cont$ROW)))
  expect_false(any(grepl("15 20 25", c(r$data$ROW, names(r$data)))))
})
