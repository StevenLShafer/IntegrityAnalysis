# test-parenthesised-fraction-is-label-text.R - a fraction wrapped in
# parentheses at both ends ("(1/2)", "(2/3/4/5)") is a label's level list,
# not a fraction cell (ISSUES.md issue 132, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 29 AH2 (Ozkan, Anaesthesist 2019, Loadsman        #
# corpus; two arms of 26 and 25): "Mallampati score (1/2) (%) 8 (31)/18   #
# (69) 4 (16)/21 (84)" read as a continuous row 8 +/- 31 / 4 +/- 16, with #
# a nameless third arm seeded by the labels' "(1/2)" and "(2/3/4/5)".      #
############################################################################

tokLine <- function(s) {
  w <- strsplit(s, " ")[[1]]
  .ppTokenizeLine(data.frame(text = w, x = cumsum(c(0, head(nchar(w) + 1, -1))) * 6,
                             width = nchar(w) * 6, stringsAsFactors = FALSE))
}
pm <- "\u00b1"

test_that("the tokenizer leaves a parenthesised fraction alone and still reads a bare one", {
  t <- tokLine("Mallampati score (1/2) (%) 8 (31)/18 (69) 4 (16)/21 (84)")
  expect_false(any(t$type == "fraction"))
  expect_identical(t$type[1], "numParen")
  expect_identical(t$start[1], nchar("Mallampati score (1/2) (%) ") + 1L)
  t <- tokLine("ADA score (2/3/4/5) 9/12/4/1 6/15/3/1")
  expect_identical(t$type, c("fraction", "fraction"))
  expect_identical(t$text[1], "9/12/4/1")
  t <- tokLine("Sex (M/F) 12/8 11/9")
  expect_identical(t$type, c("fraction", "fraction"))
})

levelListPdf <- function(file = file.path(tempdir(), "levelList.pdf")) {
  vx <- c(359, 434)
  cells <- c(
    list(list(x = 224, y = 60, text = "Table 1 Demographic data", adj = 0)),
    rowCells(80, "", c("Group V (n = 26)", "Group F (n = 25)"), vx, labelX = 224),
    rowCells(100, "Age (years) (mean and SD)", c(paste("50.5", pm, "8.0"), paste("46.8", pm, "7.3")), vx, labelX = 224),
    rowCells(114, "BMI (kg/m2) (mean and SD)", c(paste("28.2", pm, "4.5"), paste("29.1", pm, "5.6")), vx, labelX = 224),
    rowCells(128, "Gender (F/M) (%)", c("13 (50)/13 (50)", "8 (32)/17 (68)"), vx, labelX = 224),
    rowCells(142, "ADA score (2/3/4/5)", c("9/12/4/1", "6/15/3/1"), vx, labelX = 224),
    rowCells(156, "Mallampati score (1/2) (%)", c("8 (31)/18 (69)", "4 (16)/21 (84)"), vx, labelX = 224))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads two named arms and no continuous Mallampati row", {
  r <- parseBaselineTableHeuristics(levelListPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_false(any(is.na(r$arms$arm)))
  expect_identical(r$arms$N, c(26L, 25L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(sub(" .*", "", cont$ROW)), c("Age", "BMI"))
  expect_false(any(cont$MEAN == 8 & cont$SD == 31))
  expect_true(any(grepl("^Mallampati", c(r$data$ROW, names(r$data)))))
})
