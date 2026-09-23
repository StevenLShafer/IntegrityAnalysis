# test-validate-row-synonyms.R - the variable-name column under another name.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-23 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request, from remi.v2.xlsx.                                    #
#                                                                          #
# WHY THIS EXISTS. Transcribing a manuscript's baseline table by hand,     #
# the natural heading for the column of variable names is "Variable". The  #
# template calls it ROW, and a sheet using any other word was refused      #
# outright with "missing column labeled ROW" - accurate, and no help at    #
# all, because the column was right there. The workaround was to add a     #
# SECOND column literally named ROW (remi.v3.xlsx), which then held row    #
# numbers rather than variable names and made the grid worse.             #
#                                                                          #
# The rule lives in .iaNormalizeNames(), NOT in validateData: the comment  #
# above .iaTrialColumn is explicit that two implementations of one rule    #
# set is the defect, and the reader and the validator must agree about     #
# what heads a column of variable names.                                   #
############################################################################

test_that("a variable-name column headed Variable is read as ROW", {
  d <- data.frame(Variable = c("Age", "Age", "BMI", "BMI"),
                  MEAN = c(49, 45, 24.3, 24.3), SD = c(9, 11, 2.3, 3.5),
                  N = c(11, 10, 11, 10), stringsAsFactors = FALSE)
  v <- vdShared(d)
  expect_false(any(v$issues$code == "structural"))
  expect_true("ROW" %in% names(v$DATA))
  expect_identical(v$DATA$ROW[1], "Age")
})

test_that("Characteristic, Parameter, Outcome and Item work too", {
  for (word in c("Characteristic", "Parameter", "Outcome", "Item",
                 "Variables", "Characteristics")) {
    d <- data.frame(a = c("Age", "Age"), MEAN = c(49, 45),
                    SD = c(9, 11), N = c(11, 10), stringsAsFactors = FALSE)
    names(d)[1] <- word
    v <- vdShared(d)
    expect_false(any(v$issues$code == "structural"), info = word)
  }
})

test_that("an explicit ROW column still wins over a synonym", {
  # The template's own name is never overridden by a synonym. A sheet
  # carrying both is ambiguous only in appearance: ROW is what the
  # template documents, so ROW is what is used.
  d <- data.frame(Variable = c("Age", "BMI"), ROW = c("realRow1", "realRow2"),
                  MEAN = c(49, 24), SD = c(9, 2), N = c(11, 11),
                  stringsAsFactors = FALSE)
  v <- vdShared(d)
  expect_identical(v$DATA$ROW, c("realRow1", "realRow2"))
})

test_that("a sheet with no variable-name column at all is still refused", {
  # The synonym list must not become a way for any sheet to pass. This is
  # the assertion that keeps the change a widening of vocabulary rather
  # than a removal of the requirement.
  d <- data.frame(MEAN = c(49, 45), SD = c(9, 11), N = c(11, 10))
  v <- vdShared(d)
  expect_true(any(v$issues$code == "structural" & v$issues$col == "ROW"))
})

test_that("a near-miss word is NOT accepted as the row column", {
  # "Variable" is accepted; "Variability" and "Notes" are not. The
  # pattern is anchored, so the list stays a list rather than becoming a
  # substring match that swallows anything containing "item" or "row".
  # NB "Grouping" is NOT in this list: .iaNormalizeNames greps "GROUP",
  # which has matched "Grouping" since long before this change. Verified
  # against main. Asserting otherwise would have been testing a baseline
  # that never existed.
  for (word in c("Variability", "Notes", "Comment", "Summary")) {
    d <- data.frame(a = c("Age", "Age"), MEAN = c(49, 45),
                    SD = c(9, 11), N = c(11, 10), stringsAsFactors = FALSE)
    names(d)[1] <- word
    v <- vdShared(d)
    expect_true(any(v$issues$code == "structural" & v$issues$col == "ROW"),
                info = word)
  }
})
