# test-mean-sd-label-declares-the-notation.R - a row labelled "Mean (SD)"
# (or the OCR's "Mean (SO)") under a variable's heading reads its "a (b)"
# cells as mean (SD), whatever the footnote says or fails to say, and the
# look-alike letters the OCR puts in its bracketed SDs - "(I 0)", "(t2)",
# "(l i)" - are digits (ISSUES.md issue 149, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 3 AL7/AL8 (Clin Ther 2003, PMID 12809962, #
# three arms of 25; Clin Ther 2004, PMID 15336470): the "Mean (SO)"       #
# sub-rows read as a category level named Mean and the table failed with  #
# "two columns normalize to the same name: MEAN".                          #
############################################################################

meanSubRowPdf <- function(file = file.path(tempdir(), "meanSubRow.pdf")) {
  vx <- c(230, 320, 410)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  sub3 <- function(y, label, cells) c(list(w(70, y, label)), lapply(1:3, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(57, 60, "Table I. Patient demographic data.")),
    list(w(vx[1], 100, "Granisetron"), w(vx[2], 100, "Droperidol"), w(vx[3], 100, "Metoclopramide")),
    lapply(1:3, function(k) w(vx[k] + 8, 114, "(n = 25)")),
    list(w(57, 136, "Age, y")),
    sub3(148, "Mean (SO)", c("53 (6)", "53 (7)", "54 (7)")),
    sub3(160, "Range", c("41-65", "43-64", "43-65")),
    list(w(57, 176, "Height, cm")),
    c(list(w(70, 188, "Mean (SD)")), list(w(vx[1], 188, "154"), w(vx[1] + 18, 188, "(I"), w(vx[1] + 28, 188, "0)"),
                                          w(vx[2], 188, "154"), w(vx[2] + 18, 188, "(L I)"),
                                          w(vx[3], 188, "155"), w(vx[3] + 18, 188, "(I I)"))),
    sub3(200, "Range", c("143-163", "142-164", "143-163")),
    list(w(57, 216, "Body weight, kg")),
    sub3(228, "Mean (SD)", c("55 (11)", "54 (t2)", "53 (l i)")),
    sub3(240, "Range", c("44-68", "42-70", "42-67")),
    sub3(258, "History of motion sickness, no.", c("3", "2", "2")))
  makeTablePdf(file, cells)
}

test_that("the bracketed-SD repair reads look-alike letters on a Mean row and leaves other rows alone", {
  line <- function(...) { w <- c(...); data.frame(text = w, x = seq(60, by = 30, length.out = length(w)), width = 12, stringsAsFactors = FALSE) }
  lines <- list(line("Table"),
                line("Mean", "(SD)", "154", "(I", "0)", "154", "(L", "I)", "155", "(tt)", "53", "(l", "i)", "55", "(11)"),
                line("ASA", "class", "12", "(I)", "13", "(II)"),
                line("Mean", "(SD)", "12", "(n)", "13", "(no)"))
  r <- .ppRepairLookAlikeBracketSd(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Mean", "(SD)", "154", "(10)", "154", "(11)", "155", "(11)", "53", "(11)", "55", "(11)"))
  expect_identical(r$lines[[3]]$text, c("ASA", "class", "12", "(I)", "13", "(II)"))
  expect_identical(r$lines[[4]]$text, c("Mean", "(SD)", "12", "(n)", "13", "(no)"))
  expect_identical(r$repaired, 4L)
})

test_that("a Mean (SD) or Mean (SO) sub-row under a variable heading reads as mean (SD), named after the heading", {
  r <- parseBaselineTableHeuristics(meanSubRowPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(25L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(53, 53, 54))
  expect_identical(cont$SD[grepl("^Age", cont$ROW)], c(6, 7, 7))
  expect_identical(cont$MEAN[grepl("^Height", cont$ROW)], c(154, 154, 155))
  expect_identical(cont$MEAN[grepl("^Body weight", cont$ROW)], c(55, 54, 53))
  expect_false(any(grepl("^Mean", r$data$ROW)))
  expect_false("Mean" %in% names(r$data))
})

# THE MEAN'S LEADING DIGITS AS LETTERS, ON A ROW THAT SAYS "MEAN (SD)" IN ITS
# TAIL (issue 161; Clin Ther 2004, PMID 15336470): "t 6 (3)" is 16 (3), "II
# 7 (33)" is 117 (33), and "155 (I I)" is 155 (11) on such a row too.
test_that("look-alike letters before a mean, on a row whose label says mean (SD), are its first digits", {
  # words with their x and width: the look-alike stands against its number
  # (a gap of two or three points), the label's words far to the left
  W <- function(text, x, width) data.frame(text = text, x = x, width = width, stringsAsFactors = FALSE)
  L <- function(...) do.call(rbind, list(...))
  lines <- list(
    L(W("Table", 52, 22)),
    L(W("Last", 52, 13), W("menstrual", 68, 33), W("cycle,", 107, 18), W("mean", 128, 18), W("(SD),", 151, 17), W("d", 171, 4),
      W("t", 261, 1), W("6", 264, 3), W("(3)", 272, 8), W("16", 454, 7), W("(3)", 464, 9), W("l", 508, 1), W("6", 511, 3), W("(3)", 518, 9)),
    L(W("Duration", 52, 29), W("of", 86, 6), W("anesthesia,", 96, 35), W("mean", 135, 18), W("(SD),", 158, 17), W("min", 178, 11),
      W("106", 257, 11), W("(35)", 272, 13), W("II", 322, 4), W("7", 329, 3), W("(33)", 337, 13), W("II", 503, 4), W("8", 511, 3), W("(29)", 518, 13)),
    L(W("Height,", 52, 23), W("mean", 78, 18), W("(SD),", 101, 17), W("cm", 121, 9), W("159", 257, 11), W("(10)", 272, 13), W("155", 388, 11), W("(I", 403, 4), W("I)", 411, 4)),
    # a label's unit "l" (litres) a column away from the first cell is not a digit
    L(W("Volume,", 52, 26), W("mean", 82, 18), W("(SD),", 105, 17), W("l", 126, 2), W("6", 257, 3), W("(3)", 264, 8), W("7", 388, 3), W("(2)", 395, 8)),
    # no "mean" in the label: untouched
    L(W("Smokers", 52, 30), W("(n)", 86, 12), W("t", 261, 1), W("6", 264, 3), W("(30)", 272, 13)))
  r <- .ppRepairLookAlikeBracketSd(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Last", "menstrual", "cycle,", "mean", "(SD),", "d", "16", "(3)", "16", "(3)", "16", "(3)"))
  expect_identical(r$lines[[3]]$text, c("Duration", "of", "anesthesia,", "mean", "(SD),", "min", "106", "(35)", "117", "(33)", "118", "(29)"))
  expect_identical(r$lines[[4]]$text, c("Height,", "mean", "(SD),", "cm", "159", "(10)", "155", "(11)"))
  expect_identical(r$lines[[5]]$text, c("Volume,", "mean", "(SD),", "l", "6", "(3)", "7", "(2)"))
  expect_identical(r$lines[[6]]$text, c("Smokers", "(n)", "t", "6", "(30)"))
})

# THE EXCLUSION BRACKET AFTER THE SD, OCR'D WITH THE SAME LETTERS (issue
# 163; Clin Ther 2004, PMID 15336470): "[t0]" is [10] and "[t t]" - two
# words - is [11] on a "mean (SD)" row; a bracket on a count row is untouched.
test_that("look-alike letters in the square bracket after the SD are its digits", {
  W <- function(text, x, width) data.frame(text = text, x = x, width = width, stringsAsFactors = FALSE)
  L <- function(...) do.call(rbind, list(...))
  lines <- list(
    L(W("Table", 52, 22)),
    L(W("Last", 52, 13), W("menstrual", 68, 33), W("cycle,", 107, 18), W("mean", 128, 18), W("(SD),", 151, 17), W("d", 171, 4),
      W("t", 261, 1), W("6", 264, 3), W("(3)", 272, 8), W("[t0]", 285, 11),
      W("t", 326, 1), W("6", 329, 3), W("(3)", 337, 9), W("[t", 350, 4), W("t]", 359, 4),
      W("16", 454, 7), W("(3)", 464, 9), W("[9]", 478, 8)),
    # a square bracket that is no count - a citation - is not touched on a count row
    L(W("Smokers", 52, 30), W("(n)", 86, 12), W("6", 264, 3), W("(30)", 272, 13), W("[t0]", 285, 11)))
  r <- .ppRepairLookAlikeBracketSd(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Last", "menstrual", "cycle,", "mean", "(SD),", "d",
                                        "16", "(3)", "[10]", "16", "(3)", "[11]", "16", "(3)", "[9]"))
  expect_identical(r$lines[[2]]$x[12], 350)
  expect_identical(r$lines[[2]]$width[12], 13)
  expect_identical(r$lines[[3]]$text, c("Smokers", "(n)", "6", "(30)", "[t0]"))
})
