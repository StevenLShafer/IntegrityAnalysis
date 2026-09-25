# test-level-code-is-one-word.R - a hyphenated code such as the spinal level
# "L2-3" is one word: the digit after its hyphen starts no token, so the
# label stays whole and no phantom column grows at the label's x
# (ISSUES.md issue 104, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD1 (Kilic 2023, Cukurova Med J, Loadsman     #
# corpus): "L2-3", "L3-4", "L4-5" head three rows of counts; the "3" after  #
# the hyphen became a token, the label was cut to "L2", a phantom third    #
# arm grew at the label's x, and the level rows lost their arm N.          #
############################################################################

mk <- function(words, xs) data.frame(text = words, x = xs, width = nchar(words) * 5, y = 100, height = 8,
                                     stringsAsFactors = FALSE)

test_that("the digit after a letter-digit hyphen starts no token; a range in a cell is untouched", {
  t <- .ppTokenizeLine(mk(c("L2-3", "12(57.1)", "12(57.1)"), c(90, 268, 366)))
  expect_identical(t$type, c("numParen", "numParen"))
  t2 <- .ppTokenizeLine(mk(c("T10-11", "8(38.1)", "7(33.3)"), c(90, 270, 368)))
  expect_identical(t2$type, c("numParen", "numParen"))
  t3 <- .ppTokenizeLine(mk(c("Age", "46.3(31-57)", "47.2(30-57)"), c(90, 260, 315)))
  expect_identical(nrow(t3), 2L)
  expect_true(all(t3$num1 %in% c(46.3, 47.2)))
  t4 <- .ppTokenizeLine(mk(c("Range", "20-30", "25-35"), c(90, 260, 315)))
  expect_identical(nrow(t4), 2L)
})

levelPdf <- function(file = file.path(tempdir(), "levelCodes.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1. Demographics of patients and surgery", adj = 0)),
    rowCells(90, "", c("Group ESP (N:21)", "Group Control (N:21)"), vx),
    rowCells(108, "Age", c("52.33\u00b112.7", "52.95\u00b19.7"), vx),
    rowCells(126, "Male", c("12 (57.1)", "10 (47.6)"), vx),
    rowCells(144, "Female", c("9 (42.9)", "11 (52.4)"), vx),
    rowCells(162, "Weight (kg)", c("75.6\u00b17.4", "83.8\u00b19.7"), vx),
    rowCells(180, "Surgical Level", c("", ""), vx),
    rowCells(198, "L2-3", c("12(57.1)", "12(57.1)"), vx, labelX = 80),
    rowCells(216, "L3-4", c("8(38.1)", "7(33.3)"), vx, labelX = 80),
    rowCells(234, "L4-5", c("1(4.8)", "2(9.5)"), vx, labelX = 80),
    rowCells(252, "Duration of surgery (min)", c("90.14\u00b16.24", "89.52\u00b111.93"), vx),
    list(list(x = 60, y = 280, text = "Data are presented as mean\u00b1SD and percentages are presented as % within group", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt Kilic page reads two arms of 21, the level labels whole, and no phantom arm", {
  r <- parseBaselineTableHeuristics(levelPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$N, c(21L, 21L))
  # (the pdf device sets the hyphen as U+2212, hence the dot in the patterns)
  expect_true(all(vapply(c("^L2.3$", "^L3.4$", "^L4.5$"), function(p) any(grepl(p, r$data$ROW)), logical(1))))
  expect_false(any(grepl("^L[0-9]$", r$data$ROW)))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(75.6, 83.8))
})
