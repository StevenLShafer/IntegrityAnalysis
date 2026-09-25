# test-upright-column-not-rail.R - a column of short upright words ("II"
# down a long table's group column) is not a rotated rail; a rail's words
# are far taller than wide (ISSUES.md issue 96, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1). Issue 93     #
# took every word at a rail's x within its span; the fixture of issue 91  #
# (a long-layout table with I / II / III on twelve rows) then lost its    #
# whole group column, because four upright "II"s - five points wide,      #
# eight tall - at one x spanning a third of the page passed the rail test. #
############################################################################

test_that("four upright 'II's at one x are not a rail, and the words beside them stay", {
  blk <- function(y0, lbl, v1, v2, v3) data.frame(
    text = c(lbl, "I", v1, "II", v2, "III", v3),
    x = c(60, 228, 300, 227, 300, 225, 300),
    y = c(y0, y0, y0, y0 + 12, y0 + 12, y0 + 24, y0 + 24),
    width = c(14, 2, 16, 5, 16, 8, 16), height = 8, stringsAsFactors = FALSE)
  page <- rbind(blk(126, "HR", "140", "140", "139"), blk(186, "Pdi", "15.9", "15.4", "15.5"),
                blk(246, "MAP", "131", "132", "132"), blk(306, "CO", "2.0", "2.2", "2.1"))
  body <- data.frame(text = paste0("w", 1:12), x = seq(60, 500, length.out = 12), y = 400,
                     width = 12, height = 8, stringsAsFactors = FALSE)
  page <- rbind(page, body)
  out <- .ppStripRotatedText(page)
  expect_identical(nrow(out), nrow(page))
  expect_identical(sum(out$text == "II"), 4L)
  expect_identical(sum(out$text == "I"), 4L)
  expect_identical(sum(out$text == "III"), 4L)
})

test_that("a genuine rail, with its tall words, is still stripped whole", {
  page <- data.frame(
    text = c("Age", "45", "\u00b1", "12", "Downloaded", "http://bja.oxfordjournals.org/", "at", "University", "on", "2015"),
    x = c(60, 200, 215, 225, 575, 575, 575, 575, 575, 575),
    y = c(100, 100, 100, 100, 266, 326, 420, 429, 520, 566),
    width = c(16, 10, 6, 10, 7, 7, 7, 7, 7, 7),
    height = c(8, 8, 8, 8, 40, 92, 8, 33, 8, 16),
    stringsAsFactors = FALSE)
  body <- data.frame(text = paste0("w", 1:12), x = seq(60, 500, length.out = 12), y = 300,
                     width = 12, height = 8, stringsAsFactors = FALSE)
  page <- rbind(page, body)
  out <- .ppStripRotatedText(page)
  expect_false(any(out$x == 575))
  expect_true(all(c("Age", "45", "\u00b1", "12") %in% out$text))
})
