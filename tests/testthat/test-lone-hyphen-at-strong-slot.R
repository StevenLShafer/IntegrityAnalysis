# test-lone-hyphen-at-strong-slot.R - a hyphen alone between two numbers
# at a slot set by genuine glyphs on two or more lines is the sign
# (ISSUES.md issue 142, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's arm-count audit (CJA 1996, PMID 8955972; two arms of    #
# 30): "Pentazocine - mg 1.6 <bullet> 3.3 1.6 - 3.3" read one cell of two. #
############################################################################

pm <- "\u00b1"; bu <- "\u2022"

test_that("the slot repair reads a lone hyphen at a strong slot as the sign, and leaves one away from the slots", {
  line <- function(...) {
    w <- c(...); x <- c(60, 178, 194, 201, 245, 261, 268)
    data.frame(text = w, x = x[seq_along(w)], width = c(40, 14, 3, 14, 14, 3, 14)[seq_along(w)], stringsAsFactors = FALSE)
  }
  lines <- list(line("Table"),
                line("Height", "122.4", bu, "11.4", "120.7", bu, "12.5"),
                line("Weight", "25.4", bu, "6.8", "25.5", bu, "7.5"),
                line("Pentazocine", "1.6", bu, "3.3", "1.6", "-", "3.3"),
                # a range's hyphen away from the slots is a range
                data.frame(text = c("Age", "range", "3", "-", "12"), x = c(60, 100, 300, 312, 318), width = c(15, 25, 5, 3, 10), stringsAsFactors = FALSE))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(r$lines[[4]]$text, c("Pentazocine", "1.6", bu, "3.3", "1.6", pm, "3.3"))
  expect_identical(r$lines[[5]]$text, c("Age", "range", "3", "-", "12"))
})

# THE PLACEHOLDER DASH OF A LONG-LAYOUT TABLE (issue 142, second cut; Anesth
# Analg 2004, PMID 15281514): "HR (bpm) I 142 <sign> 13 - 142 <sign> 13 ..."
# - the dash is the Fatigue cell of a group without fatigue, at the slot
# where the other groups' rows set a sign. It stands between two numbers
# at a strong slot, but the number before it is an SD (a sign precedes it)
# and the number after it is a mean (a sign follows it): the dash is a
# cell, not a sign.
test_that("a lone dash between two other cells' numbers at a strong slot stays a dash", {
  w <- function(text, x) data.frame(text = text, x = x, width = c(4, 6)[1 + (nchar(text) > 1)] * pmax(1, nchar(text)) / 2 + 2,
                                    stringsAsFactors = FALSE)
  L <- function(...) do.call(rbind, list(...))
  s <- "⫾"
  lines <- list(
    L(w("Table", 44), w("1.", 70)),
    L(w("HR", 44), w("(bpm)", 60), w("I", 144), w("142", 180), w(s, 195), w("13", 205), w("–", 250), w("142", 292), w(s, 308), w("13", 318), w("142", 362), w(s, 378), w("13", 388)),
    L(w("II", 144), w("143", 180), w(s, 195), w("10", 205), w("–", 250), w("127", 292), w(s, 308), w("9*", 318), w("142", 362), w(s, 378), w("11", 388)),
    L(w("III", 144), w("143", 180), w(s, 195), w("12", 205), w("142", 233), w(s, 249), w("11", 259), w("143", 292), w(s, 308), w("11", 318), w("141", 362), w(s, 378), w("10", 388)),
    L(w("IV", 144), w("141", 180), w(s, 195), w("11", 205), w("142", 233), w(s, 249), w("10", 259), w("125", 292), w(s, 308), w("10*", 318), w("142", 362), w(s, 378), w("9", 388)))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  # the genuine glyphs stay as printed (the tokenizer knows them); the
  # dashes stay dashes
  expect_identical(r$lines[[2]]$text, c("HR", "(bpm)", "I", "142", s, "13", "–", "142", s, "13", "142", s, "13"))
  expect_identical(r$lines[[3]]$text, c("II", "143", s, "10", "–", "127", s, "9*", "142", s, "11"))
  expect_identical(r$lines[[4]]$text[6], s)
})

loneHyphenPdf <- function(file = file.path(tempdir(), "loneHyphen.pdf")) {
  vx <- c(178, 245)
  cell <- function(y, k, mean, sign, sd) list(
    list(x = vx[k], y = y, text = mean, adj = 0), list(x = vx[k] + 28, y = y, text = sign, adj = 0),
    list(x = vx[k] + 38, y = y, text = sd, adj = 0))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 60, y = y, text = label, adj = 0)),
    unlist(lapply(1:2, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 60, y = 60, text = "TABLE I Patient characteristics", adj = 0)),
    rowCells(80, "", c("Group S", "Group D"), vx + 14, labelX = 60),
    rowCells(94, "", c("(n = 30)", "(n = 30)"), vx + 14, labelX = 60),
    row(112, "Height (cm)", c("122.4", "120.7"), c(bu, bu), c("11.4", "12.5")),
    row(130, "Weight (kg)", c("25.4", "25.5"), c(bu, bu), c("6.8", "7.5")),
    row(148, "Pentazocine (mg)", c("1.6", "1.6"), c(bu, "-"), c("3.3", "3.3")),
    list(list(x = 60, y = 180, text = paste("Values are mean", bu, "SD."), adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads the second Pentazocine cell through the lone hyphen", {
  r <- parseBaselineTableHeuristics(loneHyphenPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(30L, 30L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Pentazocine"], c(1.6, 1.6))
  expect_identical(cont$SD[cont$ROW == "Pentazocine"], c(3.3, 3.3))
})
