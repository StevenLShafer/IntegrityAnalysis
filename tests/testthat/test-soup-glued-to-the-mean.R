# test-soup-glued-to-the-mean.R - at a slot the block's other rows set, a
# single letter or question mark between two numbers is the sign, and a
# number with such a glyph glued to its end, followed by a number, is the
# mean and its sign (ISSUES.md issue 129, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG1 (Anesth Analg 1998, PMID 9495425, a scan;  #
# three arms of 50 under "Values are expressed as mean +- SD or n"):       #
# "Height (cm) 154 ? 5 156 + 6 154 + 4", "Weight (kg) 55? 8 55 + 8 54 +   #
# 7", "Duration of operation (min) 72 + 27 71+ 29 75? 27", "Duration of   #
# anesthesia (min) ... 98 k 27" - the third arm read nowhere and the table #
# fell to two arms with cells from the wrong arms.                         #
############################################################################

pm <- "\u00b1"

test_that("the slot repair reads a lone letter or question mark, and soup glued to the mean, at a slot", {
  line <- function(...) {
    w <- c(...); x <- c(48, 228, 245, 253, 342, 359, 368, 462, 478, 486)
    data.frame(text = w, x = x[seq_along(w)], width = c(30, 15, 5, 5, 15, 5, 5, 11, 5, 5)[seq_along(w)],
               stringsAsFactors = FALSE)
  }
  lines <- list(line("Table"),
                # two rows of genuine signs set the three slots (a slot needs two lines)
                line("Age", "44", pm, "7", "45", pm, "10", "43", pm, "7"),
                line("BMI", "22", pm, "3", "23", pm, "3", "22", pm, "2"),
                line("Height", "154", "?", "5", "156", pm, "6", "154", "k", "4"),
                # "55?" is one word of width 20 ending at the slot; "71+" likewise
                data.frame(text = c("Weight", "55?", "8", "55", pm, "8", "71+", "7"),
                           x = c(48, 233, 253, 342, 359, 368, 462, 486), width = c(30, 17, 5, 15, 5, 5, 21, 5),
                           stringsAsFactors = FALSE),
                # a letter between two numbers away from every slot is left alone
                data.frame(text = c("Dose", "5", "k", "3", "mg"), x = c(48, 120, 132, 140, 150), width = c(25, 5, 4, 5, 10),
                           stringsAsFactors = FALSE))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(r$repaired, 4L)
  expect_identical(r$lines[[4]]$text, c("Height", "154", pm, "5", "156", pm, "6", "154", pm, "4"))
  expect_identical(r$lines[[5]]$text, c("Weight", "55", pm, "8", "55", pm, "8", "71", pm, "7"))
  expect_identical(r$lines[[6]]$text, c("Dose", "5", "k", "3", "mg"))
  # the split keeps the sign in the glyph's place
  L <- r$lines[[5]]
  expect_equal(L$x[L$text == pm][1], 233 + 17 * 2 / 3)
})

meanGluedPdf <- function(file = file.path(tempdir(), "meanGlued.pdf")) {
  vx <- c(230, 345, 465)
  cell <- function(y, k, mean, sign, sd) c(
    list(list(x = vx[k], y = y, text = mean, adj = 0)),
    if (nzchar(sign)) list(list(x = vx[k] + 15, y = y, text = sign, adj = 0)),
    list(list(x = vx[k] + 23, y = y, text = sd, adj = 0)))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 48, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 36, y = 60, text = "Table 1. Patient Demographic Data", adj = 0)),
    rowCells(80, "", c("Group G", "Group D", "Group GD"), vx + 10, labelX = 48),
    rowCells(94, "", c("(n = 50)", "(n = 50)", "(n = 50)"), vx + 10, labelX = 48),
    row(112, "Age (yr)", c("44", "45", "43"), rep(pm, 3), c("7", "10", "7")),
    row(130, "Height (cm)", c("154", "156", "154"), c("?", pm, pm), c("5", "6", "4")),
    row(148, "Weight (kg)", c("55?", "55", "54"), c("", pm, pm), c("8", "8", "7")),
    row(166, "Duration of operation (min)", c("72", "71+", "75?"), c(pm, "", ""), c("27", "29", "27")),
    row(184, "Duration of anesthesia (min)", c("97", "95", "98"), c(pm, pm, "k"), c("29", "23", "27")),
    list(list(x = 48, y = 216, text = "Values are expressed as mean +- SD or n.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with the lone and glued glyphs reads three arms and every cell", {
  r <- parseBaselineTableHeuristics(meanGluedPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(50L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(154, 156, 154))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(55, 55, 54))
  expect_identical(cont$MEAN[grepl("^Duration of operation", cont$ROW)], c(72, 71, 75))
  expect_identical(cont$SD[grepl("^Duration of anesthesia", cont$ROW)], c(29, 23, 27))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
