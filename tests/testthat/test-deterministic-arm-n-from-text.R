# test-deterministic-arm-n-from-text.R - a deterministic table whose arms
# all lack N gets the model route's arm-size ladder: the "k groups of n"
# statement, then the document text by arm name (ISSUES.md issue 84,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 21: on the deterministic Carlisle-168 pass 48 of  #
# the 55 validation failures were "missing N", and 39 of those state the  #
# sizes in the text - "divided into three groups of 20" or "(n = 20)"     #
# beside the arm's name - which only the model-read table had been given  #
# since issue 42.                                                          #
############################################################################

noNPdf <- function(file, prose) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 50, text = prose, adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(120, "", c("Propofol", "Control"), vx),
    rowCells(138, "Age (yr)", c("45 ± 12", "46 ± 11"), vx),
    rowCells(156, "Weight (kg)", c("70 ± 9", "71 ± 8"), vx),
    rowCells(174, "Height (cm)", c("168 ± 7", "167 ± 8"), vx),
    list(list(x = 60, y = 204, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("'divided into two groups of 20' gives every arm its size, with the sentence as its source", {
  f <- noNPdf(file.path(tempdir(), "groupsOfN.pdf"),
              "Patients were randomly divided into two groups of 20 each and received propofol or saline.")
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 20L))
  expect_true(all(grepl("document text", r$armNSource)))
  expect_identical(unique(r$data$N[!is.na(r$data$MEAN)]), 20L)
  expect_true(any(grepl("CONSORT", reviewFlags(r))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("'(n = 20)' beside each arm's name in the text gives that arm its size", {
  f <- noNPdf(file.path(tempdir(), "namedN.pdf"),
              "Sixty patients were allocated to the propofol group (n = 30) or the control group (n = 30).")
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$N, c(30L, 30L))
  expect_true(all(!is.na(r$armNSource)))
})

test_that("a table that prints one arm's size keeps the deterministic reading as it is", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "oneN.pdf")
  cells <- c(
    list(list(x = 60, y = 50, text = "Patients were randomly divided into two groups of 20 each.", adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(120, "", c("Propofol (n = 25)", "Control"), vx),
    rowCells(138, "Age (yr)", c("45 ± 12", "46 ± 11"), vx),
    rowCells(156, "Weight (kg)", c("70 ± 9", "71 ± 8"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$N[1], 25L)
  expect_true(is.na(r$arms$N[2]))      # the gate: every arm without N, or nothing
})
