# test-partial-arm-n-by-name.R - when a table prints some arms' sizes and
# not others, a "(n = k)" mention that NAMES a missing arm fills it; the
# positional rules stay behind the every-arm-lacks-N gate (ISSUES.md
# issue 87, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 22: on the deterministic Carlisle pass PMIDs       #
# 8004733, 9717598, 9350368 and 9512856 read one arm's N from the table    #
# and NA for the rest, and the gate of issue 42 - right for the positional #
# rules - shut out the arm-name match too.                                  #
############################################################################

test_that("the ladder fills a missing arm by name when another arm's size is printed, and by name only", {
  # ("control" is a stop word of the name match, so the arm here is Saline)
  cand <- data.frame(n = c(20L, 22L), context = c("... the saline group (n = 20) received saline ...",
                                                  "... the propofol group (n = 22) ..."),
                     near = c("the saline group (n = 20) received", "the propofol group (n = 22)"),
                     before = c("the saline group ", "the propofol group "),
                     pos = c(100L, 200L), stringsAsFactors = FALSE)
  fill <- .ppFillArmNFromText(c(22L, NA), c("Propofol", "Saline"), cand, integer(0), namesOnly = TRUE)
  expect_identical(fill$N, c(22L, 20L))
  expect_true(grepl("arm name matched", fill$source[2]))
  # an arm the mentions do not name is left alone under namesOnly, even
  # when only one mention is unused (the elimination rule is positional)
  fill2 <- .ppFillArmNFromText(c(22L, NA), c("Propofol", "Placebo"), cand, integer(0), namesOnly = TRUE)
  expect_true(is.na(fill2$N[2]))
  # with every arm unknown the full ladder eliminates: one open arm, one unused mention
  fill3 <- .ppFillArmNFromText(c(NA, NA), c("Propofol", "Placebo"), cand, integer(0))
  expect_identical(fill3$N, c(22L, 20L))
})

partialNPdf <- function(file = file.path(tempdir(), "partialN.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 50, text = "Patients received propofol (n = 20) or saline; the saline group (n = 20) served as control.", adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(120, "", c("Propofol (n = 20)", "Saline"), vx),
    rowCells(138, "Age (yr)", c("45 ± 12", "46 ± 11"), vx),
    rowCells(156, "Weight (kg)", c("70 ± 9", "71 ± 8"), vx),
    rowCells(174, "Height (cm)", c("168 ± 7", "167 ± 8"), vx),
    list(list(x = 60, y = 204, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a table printing one arm's size gets the other from the text by name", {
  r <- parseBaselineTableHeuristics(partialNPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 20L))
  expect_true(is.na(r$armNSource[1]))          # printed
  expect_true(grepl("arm name matched", r$armNSource[2]))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
