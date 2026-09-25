# test-header-n-tilde.R - "(n ~ 20)" and "(n~20)" under the arm names are
# the arm-size line: the OCR of an equals sign in a small font is a tilde
# (ISSUES.md issue 98, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24: the CJA scans PMIDs 9717598, 9350368 and      #
# 9836028 head one arm "(n = 20)" and the next "(n ~ 20)" or "(n~20)", and #
# the arm so headed had no N while its neighbour did.                      #
############################################################################

tildePdf <- function(file = file.path(tempdir(), "tildeHeader.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(90, "", c("Group C", "Group N"), vx),
    list(list(x = 288, y = 104, text = "(n ~ 20)", adj = 0), list(x = 408, y = 104, text = "(n~20)", adj = 0)),
    rowCells(122, "Age (yr)", c("45 \u00b1 12", "46 \u00b1 11"), vx),
    rowCells(140, "Height (cm)", c("168 \u00b1 7", "167 \u00b1 8"), vx),
    rowCells(158, "Weight (kg)", c("70 \u00b1 9", "71 \u00b1 8"), vx),
    list(list(x = 60, y = 190, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a tilde for the equals sign heads two arms of 20 with clean names", {
  r <- parseBaselineTableHeuristics(tildePdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 20L))
  expect_false(any(grepl("~", r$arms$arm, fixed = TRUE)))
  expect_identical(r$arms$arm, c("Group C", "Group N"))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
