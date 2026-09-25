# test-n-of-each-statement.R - "(n = 20 of each)" after the arms are named
# is the size of every arm, and it fills the arms a scanned header left
# blank when the printed arms agree with it (ISSUES.md issue 99,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24: four CJA scans (PMIDs 9717598, 9350368,       #
# 9512856, 9836028) print one arm's "(n = 20)" and lose the other's, and   #
# issue 87's fill by name found no name to match; two of them say         #
# "diltiazem or saline (n = 20 of each)" in the Methods.                   #
############################################################################

test_that("'(n = 20 of each)' and its kin are statements for every arm, the group count unstated", {
  g <- .ppGroupsOfN("Patients received diltiazem or saline (as a control) (n = 20 of each) iv before tracheal extubation.")
  expect_true(is.na(g$groups)); expect_identical(g$n, 20L)
  expect_identical(.ppGroupNFor(g, 2L)$n, 20L)
  expect_identical(.ppGroupsOfN("normotensive and hypertensive patients (n=40 per group) were studied")$n, 40L)
  expect_identical(.ppGroupsOfN("four groups (n = 15 in each group) received")$n, 15L)
  expect_null(.ppGroupsOfN("the diltiazem group (n = 20) received 0.2 mg/kg"))   # one arm's own size: the name match's business
  expect_null(.ppGroupsOfN("a sample size of 20 per group (n = 20 of each) would be sufficient to detect"))
})

partialPdf <- function(file, prose) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 50, text = prose, adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(120, "", c("Diltiazem (n = 20)", "Saline"), vx),
    rowCells(138, "Age (yr)", c("45 \u00b1 12", "46 \u00b1 11"), vx),
    rowCells(156, "Weight (kg)", c("70 \u00b1 9", "71 \u00b1 8"), vx),
    rowCells(174, "Height (cm)", c("168 \u00b1 7", "167 \u00b1 8"), vx),
    list(list(x = 60, y = 204, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the statement fills the blank arm when the printed arm agrees, and not otherwise", {
  r <- parseBaselineTableHeuristics(partialPdf(file.path(tempdir(), "ofEach.pdf"),
         "Patients received diltiazem or saline (n = 20 of each) before extubation."), quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 20L))
  expect_true(is.na(r$armNSource[1]))
  expect_true(grepl("document text", r$armNSource[2]))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
  r2 <- parseBaselineTableHeuristics(partialPdf(file.path(tempdir(), "ofEach2.pdf"),
         "Normotensive and hypertensive patients (n = 40 of each) were studied."), quiet = TRUE)
  expect_identical(r2$arms$N, c(20L, NA))
})
