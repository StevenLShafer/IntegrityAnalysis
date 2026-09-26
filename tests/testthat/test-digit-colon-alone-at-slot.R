# test-digit-colon-alone-at-slot.R - a word of one digit and a colon
# ("5:") standing alone between two numbers at a slot the block's other
# rows set is the plus-minus sign, and the number after it may carry a
# footnote mark ("5.5*") (ISSUES.md issue 125, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's AF7 (CJA 1996, PMID 8706192, a scan; four arms of 25):   #
# "Awakening time (min) 6.1 5:2.5 6.2 5:22.8 6.0 5:3.0 9.2 5: 5.5*" read   #
# three arms of four, the fourth arm's "9.2 +/- 5.5" lost.                  #
############################################################################

pm <- "\u00b1"

test_that("the slot repair reads a lone digit-colon word at a slot as the sign", {
  line <- function(label, ...) {
    w <- c(label, ...); x <- c(60, 200, 213, 221, 290, 303, 311, 380, 393, 401)
    data.frame(text = w, x = x[seq_along(w)], width = nchar(w) * 5, stringsAsFactors = FALSE)
  }
  lines <- list(line("Table 1"),
                line("Age", "40.1", pm, "7.5", "45.3", pm, "8.1", "43.2", pm, "8.3"),
                line("Weight", "55.3", pm, "5.4", "53.7", pm, "7.5", "54.0", pm, "7.7"),
                line("Awakening", "6.1", pm, "2.5", "6.2", pm, "22.8", "9.2", "5:", "5.5*"),
                # a ratio line whose "2:" stands away from every slot
                data.frame(text = c("Ratio", "1", "2:", "3"), x = c(60, 240, 252, 262), width = c(25, 5, 10, 5),
                           stringsAsFactors = FALSE))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(r$repaired, 1L)
  expect_identical(r$lines[[4]]$text[9], pm)
  # a digit-colon word away from every slot is left alone
  expect_identical(r$lines[[5]]$text[3], "2:")
})

digitColonPdf <- function(file = file.path(tempdir(), "digitColon.pdf")) {
  vx <- c(200, 290, 380, 470)
  cell <- function(y, k, mean, sign, sd) list(
    list(x = vx[k] - 3, y = y, text = mean, adj = 1),
    list(x = vx[k], y = y, text = sign, adj = 0),
    list(x = vx[k] + 14, y = y, text = sd, adj = 0))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 60, y = y, text = label, adj = 0)),
    unlist(lapply(1:4, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE II Recovery", adj = 0)),
    rowCells(90, "", c("A (n = 25)", "B (n = 25)", "C (n = 25)", "D (n = 25)"), vx, labelX = 60),
    row(108, "Age (yr)", c("40.1", "45.3", "43.2", "42.5"), rep(pm, 4), c("7.5", "8.1", "8.3", "9.4")),
    row(126, "Weight (kg)", c("55.3", "53.7", "54.0", "54.4"), rep(pm, 4), c("5.4", "7.5", "7.7", "8.2")),
    row(144, "Awakening time (min)", c("6.1", "6.2", "6.0", "9.2"), c(pm, pm, pm, "5:"), c("2.5", "22.8", "3.0", "5.5*")),
    list(list(x = 60, y = 176, text = paste("Values are mean", pm, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the fourth arm's Awakening time through the lone digit-colon sign", {
  r <- parseBaselineTableHeuristics(digitColonPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  aw <- cont[grepl("^Awakening", cont$ROW), ]
  expect_identical(aw$MEAN, c(6.1, 6.2, 6.0, 9.2))
  expect_identical(aw$SD, c(2.5, 22.8, 3.0, 5.5))
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(40.1, 45.3, 43.2, 42.5))
})
