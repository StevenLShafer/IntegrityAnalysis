# test-slot-plus-and-dropped-sign.R - a plain "+" at a slot two lines mark
# with the sign itself, the sign dropped entirely between two numbers at
# such a slot, and a legend that spells "S D" (ISSUES.md issue 77,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 17 finding W1 (Fujii 1994, Can J Anaesth, PMID    #
# 8055614): the OCR text layer sets the sign as "5:9", "-1-", "+" and, in #
# six cells, as nothing at all ("142 10", "121 14"), and the legend reads  #
# "All values are expressed as mean -t- S D".                              #
############################################################################

mk <- function(text, x, width = 8) data.frame(text = text, x = x, width = width, y = 0,
                                              stringsAsFactors = FALSE)

test_that("a plain '+' between two numbers at a slot two lines mark with the sign itself is the sign", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "46.7", "±", "7.7", "46.3", "±", "11.8"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "164", "±", "7", "163", "±", "7"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Weight", "58", "+", "10", "57", "+", "9"), c(60, 180, 200, 210, 240, 260, 270)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$repaired, 2L)
  expect_identical(rep$lines[[4]]$text, c("Weight", "58", "±", "10", "57", "±", "9"))
  # one line with the sign itself is not enough (issue 45's lone "5 + 2" stays)
  one <- lines[c(1, 2, 4)]
  expect_identical(.ppRepairPlusMinusGlyphs(one, capIdx = 1L)$repaired, 0L)
})

test_that("the sign dropped entirely: two numbers straddling a strong slot with a gap for it", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "46.7", "±", "7.7", "46.3", "±", "11.8"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "164", "±", "7", "163", "±", "7"), c(60, 180, 200, 210, 240, 260, 270)),
    # "142  10": the sign is gone, the gap (188..206) holds the slot at 200
    mk(c("HR", "142", "10", "147", "10"), c(60, 180, 206, 240, 266)),
    # counts forty points apart are not one cell, and a negative second number is never an SD
    mk(c("n", "20", "20"), c(60, 180, 240)),
    mk(c("Change", "-3.2", "-1.0"), c(60, 180, 200)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$repaired, 2L)
  expect_identical(rep$lines[[4]]$text, c("HR", "142", "±", "10", "147", "±", "10"))
  expect_identical(rep$lines[[5]]$text, c("n", "20", "20"))
  expect_identical(rep$lines[[6]]$text, c("Change", "-3.2", "-1.0"))
})

test_that("a legend that spells 'mean -t- S D' announces the soup, and a '+' at any slot is then the sign", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("HR", "146", "5:9", "145", "11"), c(60, 180, 200, 240, 262)),
    mk(c("MAP", "121", "+", "14", "122", "+", "17"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("RAP", "5", "+", "2", "5", "+", "1"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("All", "values", "are", "expressed", "as", "mean", "-t-", "S", "D"),
       c(60, 75, 100, 115, 150, 160, 180, 195, 203)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$lines[[3]]$text, c("MAP", "121", "±", "14", "122", "±", "17"))
  expect_identical(rep$lines[[4]]$text, c("RAP", "5", "±", "2", "5", "±", "1"))
  expect_identical(rep$lines[[2]]$text, c("HR", "146", "±", "9", "145", "±", "11"))
})
