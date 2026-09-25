# test-size-sentence-shapes.R - three more ways a paper states its arm
# sizes, and the power statement that is not one (ISSUES.md issue 89,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 22 spec, every size-stating sentence of the 48    #
# missing-N Carlisle trials: "(n:50 each)" with a colon (PMID 9861126),    #
# "150 female patients ... allocated randomly to one of three groups"      #
# (9861126), "Twenty patients were randomly assigned to each treatment     #
# group" (14749151), and "60 patients per group would be sufficient"       #
# (10357343), a power statement that must not be read as an allocation.   #
############################################################################

test_that("'(n:50 each)' is a size mention, with the colon", {
  cand <- .ppArmNCandidatesFromText("Patients were randomly allocated to one of three groups (n:50 each).")
  expect_true(any(cand$n == 50L))
  g <- .ppGroupsOfN("Patients were randomly allocated to one of three groups (n:50 each).")
  expect_identical(g$groups, 3L); expect_identical(g$n, 50L)
  expect_identical(.ppGroupNFor(g, 3L)$n, 50L)
  expect_true(is.na(.ppGroupNFor(g, 4L)$n))
})

test_that("a total divided by the group count gives the size when it divides", {
  g <- .ppGroupsOfN("We studied 150 female patients, who were allocated randomly to one of three groups.")
  expect_identical(g$groups, 3L); expect_identical(g$n, 50L)
  expect_identical(.ppGroupNFor(g, 3L)$n, 50L)
  g2 <- .ppGroupsOfN("One hundred and eighty patients were enrolled and assigned to one of three groups.")
  expect_true(is.null(g2) || !any(g2$groups == 3L & g2$n == 60L))   # "One hundred and eighty" is not read: no guess
  g3 <- .ppGroupsOfN("A total of 125 patients were randomly assigned to one of three groups.")
  expect_true(is.null(g3))                                             # 125 does not divide by 3
})

test_that("'Twenty patients were randomly assigned to each treatment group' serves any arm count", {
  g <- .ppGroupsOfN("Twenty patients were randomly assigned to each treatment group by a computer-generated list.")
  expect_true(is.na(g$groups)); expect_identical(g$n, 20L)
  expect_identical(.ppGroupNFor(g, 2L)$n, 20L)
  expect_identical(.ppGroupNFor(g, 4L)$n, 20L)
  # a statement naming this k is preferred over the unstated one
  both <- .ppGroupsOfN(paste("Twenty patients were randomly assigned to each treatment group.",
                             "Patients were divided into two groups of 25 each."))
  expect_identical(.ppGroupNFor(both, 2L)$n, 25L)
  expect_identical(.ppGroupNFor(both, 3L)$n, 20L)
})

test_that("a power statement is not an allocation", {
  expect_null(.ppGroupsOfN("A sample size calculation showed that 60 patients per group would be sufficient to detect a 30% difference."))
  expect_null(.ppGroupsOfN("Twenty-five patients per group would be sufficient; 25 patients were assigned to each group was not stated."))
  cand <- .ppArmNCandidatesFromText("Power analysis indicated that n = 60 per group would be sufficient.")
  expect_identical(nrow(cand), 0L)
})

test_that("the number words now reach fifty and one hundred", {
  expect_identical(.ppNumberWord("fifty"), 50L)
  expect_identical(.ppNumberWord("hundred"), 100L)
  expect_true(is.na(.ppNumberWord("dozens")))
})

# the end-to-end route: a rebuilt page with no N in the table and the
# size on a sentence of its own (the noNPdf builder of
# test-deterministic-arm-n-from-text.R, repeated here so this file
# stands alone)
sizeSentencePdf <- function(file, prose) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 50, text = prose, adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(120, "", c("Propofol", "Control"), vx),
    rowCells(138, "Age (yr)", c("45 \u00b1 12", "46 \u00b1 11"), vx),
    rowCells(156, "Weight (kg)", c("70 \u00b1 9", "71 \u00b1 8"), vx),
    rowCells(174, "Height (cm)", c("168 \u00b1 7", "167 \u00b1 8"), vx),
    list(list(x = 60, y = 204, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("'Twenty patients were randomly assigned to each treatment group' fills a table with no N", {
  f <- sizeSentencePdf(file.path(tempdir(), "sizeSentence.pdf"),
                       "Twenty patients were randomly assigned to each treatment group and received propofol or saline.")
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$N, c(20L, 20L))
  expect_true(all(grepl("document text", r$armNSource)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
  # the power statement alone leaves the table without N
  f2 <- sizeSentencePdf(file.path(tempdir(), "powerSentence.pdf"),
                        "A sample size calculation showed that 20 patients per group would be sufficient to detect a difference.")
  r2 <- parseBaselineTableHeuristics(f2, quiet = TRUE)
  expect_true(all(is.na(r2$arms$N)))
})
