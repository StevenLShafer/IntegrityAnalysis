# test-glued-soup-digits.R - a glued plus-minus soup never eats the number
# it is glued to, and "5:" is admitted as a sign at a slot (ISSUES.md
# issue 70, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 15a finding T2 (Fujii 1996, PMID 8706192): the   #
# glued class of issue 65 held "4" and ".", so "+4.9" matched as the soup #
# "+4." and the SD "9" - Height's second arm went out as 154.1 +/- 9.0    #
# for the printed 4.9. The same page sets the sign as "5:" glued to the   #
# SD ("55.3 5:5.4").                                                       #
############################################################################

mk <- function(text, x) data.frame(text = text, x = x, width = rep(8, length(text)),
                                   y = 0, stringsAsFactors = FALSE)

test_that("'+4.9' at a slot is left alone: a plus is never repaired and the number is not eaten", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "43.0", "±", "7.7", "41.9", "±", "8.1"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Weight", "55.3", "±", "5.4", "53.7", "±", "7.5"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "155.0", "-I-", "5.5", "154.1", "+4.9"), c(60, 180, 200, 210, 240, 260)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$repaired, 1L)
  expect_identical(rep$lines[[4]]$text, c("Height", "155.0", "±", "5.5", "154.1", "+4.9"))
})

test_that("'5:5.4' at a slot is the sign glued to its SD; on the announcement alone it is not", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "43.0", "±", "7.7", "41.9", "±", "8.1"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "155.0", "±", "5.5", "154.0", "±", "4.9"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Weight", "55.3", "5:5.4", "53.7", "5:7.5"), c(60, 180, 200, 240, 260)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$repaired, 2L)
  expect_identical(rep$lines[[4]]$text, c("Weight", "55.3", "±", "5.4", "53.7", "±", "7.5"))
  # no slot, only the legend: a digit-colon word stays as it is
  said <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Weight", "55.3", "5:5.4", "53.7", "5:7.5"), c(60, 180, 200, 240, 260)),
    mk(c("Values", "are", "mean", "-t-", "SD."), c(60, 90, 110, 130, 150)))
  expect_identical(.ppRepairPlusMinusGlyphs(said, capIdx = 1L)$repaired, 0L)
})

test_that("a dot is not soup: '.5' or '4.' between two numbers is never a sign", {
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "43.0", "±", "7.7", "41.9", "±", "8.1"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "155.0", "±", "5.5", "154.0", "±", "4.9"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Weight", "55.3", "4.", "5.4", "53.7", ".", "7.5"), c(60, 180, 200, 210, 240, 260, 270)))
  expect_identical(.ppRepairPlusMinusGlyphs(lines, capIdx = 1L)$repaired, 0L)
})
