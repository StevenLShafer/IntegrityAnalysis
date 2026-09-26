# test-arm-columns-as-slots.R - when a text layer has no plus-minus glyph at
# all, the header's "(n = k)" groups mark the arm columns and two numbers
# straddling an arm's centre are its mean and SD (ISSUES.md issue 152,
# 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 3 AL1-AL4 (J Clin Anesth 1999, PMID       #
# 10386280, three arms of 50: "Age(yrs) 45  12 44  11 45  11"; A&A 1999,   #
# PMID 10357343; Paediatr Anaesth 2001, PMID 11123735): the page prints    #
# the sign, the layer does not, and every row read as bare counts.         #
############################################################################

pm <- "\u00b1"

test_that("with no sign glyph in the block, two numbers straddling a header group's centre take the sign", {
  w <- function(text, x, width) data.frame(text = text, x = x, width = width, stringsAsFactors = FALSE)
  L <- function(...) do.call(rbind, list(...))
  lines <- list(
    L(w("Table", 55, 22), w("1", 80, 4)),
    L(w("Granisetron", 272, 44), w("Droperidol", 392, 41), w("Combination*", 506, 52)),
    L(w("(n", 278, 7), w("=", 288, 4), w("50)", 298, 12), w("(n", 397, 7), w("=", 407, 4), w("50)", 417, 12), w("(n", 517, 7), w("=", 527, 4), w("50)", 537, 12)),
    L(w("Age(yrs)", 55, 31), w("45", 273, 8), w("12", 294, 8), w("44", 392, 8), w("11", 412, 8), w("45", 512, 8), w("11", 532, 8)),
    L(w("Gender(male/female)", 55, 83), w("(n)", 141, 12), w("26/24", 283, 22), w("26/24", 402, 22), w("26/24", 521, 22)),
    L(w("Weight", 55, 26), w("(kg)", 84, 16), w("58", 273, 8), w("9", 294, 4), w("58", 392, 8), w("8", 412, 4), w("59", 512, 8), w("8", 532, 4)),
    L(w("Indomethacin", 55, 52), w("(n)", 111, 12), w("32", 290, 8), w("32", 409, 8), w("31", 528, 8)))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(r$lines[[4]]$text, c("Age(yrs)", "45", pm, "12", "44", pm, "11", "45", pm, "11"))
  expect_identical(r$lines[[6]]$text, c("Weight", "(kg)", "58", pm, "9", "58", pm, "8", "59", pm, "8"))
  expect_identical(r$lines[[5]]$text, c("Gender(male/female)", "(n)", "26/24", "26/24", "26/24"))
  expect_identical(r$lines[[7]]$text, c("Indomethacin", "(n)", "32", "32", "31"))
  # without the header's groups there is nothing to stand the sign on
  r0 <- .ppRepairPlusMinusGlyphs(lines[-3], capIdx = 1L)
  expect_identical(r0$lines[[3]]$text, c("Age(yrs)", "45", "12", "44", "11", "45", "11"))
  expect_identical(r0$repaired, 0L)
})

noGlyphPdf <- function(file = file.path(tempdir(), "noGlyph.pdf")) {
  vx <- c(273, 392, 512)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, means, sds) c(list(w(55, y, label)),
    unlist(lapply(1:3, function(k) list(w(vx[k], y, means[k]), w(vx[k] + 21, y, sds[k]))), recursive = FALSE))
  cells <- c(
    list(w(55, 60, "Table 1. Patient characteristics")),
    list(w(272, 88, "Granisetron"), w(392, 88, "Droperidol"), w(506, 88, "Combination*")),
    lapply(1:3, function(k) w(vx[k] + 5, 98, "(n = 50)")),
    row(119, "Age (yrs)", c("45", "44", "45"), c("12", "11", "11")),
    list(w(55, 129, "Gender (male/female) (n)"), w(283, 129, "26/24"), w(402, 129, "26/24"), w(521, 129, "26/24")),
    row(139, "Height (cm)", c("160", "159", "160"), c("10", "11", "10")),
    row(149, "Weight (kg)", c("58", "58", "59"), c("9", "8", "8")),
    row(169, "Duration of operation (min)", c("223", "228", "225"), c("48", "44", "44")),
    list(w(55, 189, "Indomethacin used postoperatively (n)"), w(290, 189, "32"), w(409, 189, "32"), w(528, 189, "31")),
    list(w(55, 250, "*Combination granisetron plus droperidol. Values are means SD, or number.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page whose text layer has no sign glyph reads its rows as mean and SD", {
  r <- parseBaselineTableHeuristics(noGlyphPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(50L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(45, 44, 45))
  expect_identical(cont$SD[grepl("^Age", cont$ROW)], c(12, 11, 11))
  expect_identical(cont$MEAN[grepl("^Duration", cont$ROW)], c(223, 228, 225))
  expect_identical(length(unique(cont$ROW)), 4L)
})
