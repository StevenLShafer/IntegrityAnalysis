# test-glued-digit-colon-marks-slot.R - under an announced notation the
# glued digit-colon form ("5:4.8") marks its column, so the middle arms
# whose every sign is set that way are repaired (ISSUES.md issue 119,
# 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 27 AF3 (CJA 1995, PMID 7614644, a scan): "All     #
# values are expressed as mean + SD." over "154.0 5:3.8 154.9 5:4.8 156.3  #
# 5:6.2 154.4 5:4.9"; the middle arms' cells stayed unread.                #
############################################################################

mk <- function(text, x) data.frame(text = text, x = x, width = nchar(text) * 5, y = 0,
                                   stringsAsFactors = FALSE)

test_that("the helper: '5:' glued forms on two lines at one column are a slot under an announced soup", {
  lines <- list(
    mk(c("TABLE", "I"), c(61, 89)),
    mk(c("Height", "(cm)", "154.0", "5:3.8", "154.9", "5:4.8", "156.3", "5:6.2", "154.4", "5:4.9"), c(62, 85, 195, 213, 243, 261, 296, 315, 356, 374)),
    mk(c("Weight", "(kg)", "54.0", "5:7.3", "53.2", "5:8.0", "54.9", "5:9.0", "54.1", "5:7.6"), c(62, 86, 198, 214, 245, 261, 299, 315, 359, 375)),
    mk(c("Duration", "(min)", "74", "+", "28", "81", "5:24", "78", "+", "32", "83", "+", "25"), c(62, 93, 204, 214, 222, 251, 261, 305, 315, 323, 365, 375, 383)),
    mk(c("All", "values", "are", "expressed", "as", "mean", "+", "SD."), c(62, 74, 95, 107, 140, 149, 169, 177)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  h <- rep$lines[[2]]$text
  expect_identical(h[c(4, 7, 10, 13)], rep("\u00b1", 4))
  expect_identical(h[c(5, 8, 11, 14)], c("3.8", "4.8", "6.2", "4.9"))
  expect_identical(rep$lines[[4]]$text[7:8], c("\u00b1", "24"))
})

gluedColonPdf <- function(file = file.path(tempdir(), "gluedColon.pdf")) {
  # the signs of one column share an x, as on the page (the means are set
  # right-aligned before them): each cell is placed word by word
  vx <- c(200, 300, 400, 500)
  cell <- function(y, k, mean, sign, sd) list(
    list(x = vx[k] - 3, y = y, text = mean, adj = 1),
    list(x = vx[k], y = y, text = sign, adj = 0),
    list(x = vx[k] + 22, y = y, text = sd, adj = 0))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 62, y = y, text = label, adj = 0)),
    unlist(lapply(1:4, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 61, y = 60, text = "TABLE I Patient demographics and types of operation", adj = 0)),
    rowCells(80, "", c("Placebo", "Granisetron", "Dexamethasone", "Both"), vx, labelX = 62),
    rowCells(94, "", c("(n = 22)", "(n = 22)", "(n = 22)", "(n = 22)"), vx, labelX = 62),
    row(112, "Height (cm)", c("154.0", "154.9", "156.3", "154.4"), c("5:3.8", "5:4.8", "5:6.2", "5:4.9"), c("", "", "", "")),
    row(130, "Weight (kg)", c("54.0", "53.2", "54.9", "54.1"), c("5:7.3", "5:8.0", "5:9.0", "5:7.6"), c("", "", "", "")),
    row(148, "Duration of operation (min)", c("74", "81", "78", "83"), c("+", "5:24", "+", "+"), c("28", "", "32", "25")),
    list(list(x = 62, y = 178, text = "All values are expressed as mean + SD.", adj = 0)))
  cells <- Filter(function(z) nzchar(z$text), cells)
  makeTablePdf(file, cells)
}

test_that("a rebuilt page under 'mean + SD' with '5:' signs reads all four arms of every row", {
  r <- parseBaselineTableHeuristics(gluedColonPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(22L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(154.0, 154.9, 156.3, 154.4))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(7.3, 8.0, 9.0, 7.6))
  expect_identical(cont$MEAN[cont$ROW == "Duration of operation"], c(74, 81, 78, 83))
})
