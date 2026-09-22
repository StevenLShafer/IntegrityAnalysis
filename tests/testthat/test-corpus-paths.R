# test-corpus-paths.R - where a corpus file lives, given its share class.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-22 by Claude Code (model Claude Opus 5) at Steve          #
# Shafer's request, alongside the move of the confidential tier out of      #
# master/ into master-confidential/.                                       #
#                                                                          #
# WHY THIS TEST EXISTS. On 2026-09-22 a routine whole-folder backup copied  #
# all 6,328 confidential A&A peer-review manuscripts to a third-party       #
# cloud. Nothing failed, nothing warned. The obvious exclusion pattern -    #
# matching "aa-peer-review" against the path - matched NOTHING, because     #
# confidential files were stored as master/pdf/IA000013.pdf, interleaved    #
# with 31,763 others and distinguishable only by consulting the index.      #
#                                                                          #
# The fix is structural: the share class decides the directory. These       #
# assertions are written as the FAILURE MODE, not the feature, because the  #
# feature is trivially obvious and the failure is what actually happened.   #
############################################################################

# test_path("..", ".."), not rprojroot: rprojroot is not in DESCRIPTION, so
# it is not guaranteed present under R CMD check even though it resolves
# locally. This is the convention the rest of the suite already uses.
source(testthat::test_path("..", "..", "corpus", "corpusPaths.R"))

test_that("a confidential file never resolves inside the shared tree", {
  p <- corpusFilePath("C:/dev/Corpus", "confidential", "pdf", "IA000013.pdf")
  # The whole point: an exclusion written against the PATH must be able to
  # catch this file. Before the split it could not.
  expect_true(grepl("master-confidential", p, fixed = TRUE))
  expect_false(grepl("/master/", gsub("\\\\", "/", p), fixed = TRUE))
})

test_that("a non-confidential file stays in master/", {
  for (s in c("public", "noncommercial", "verbatim-only", "restricted")) {
    p <- corpusFilePath("C:/dev/Corpus", s, "pdf", "IA000002.pdf")
    expect_true(grepl("/master/", gsub("\\\\", "/", p), fixed = TRUE), info = s)
    expect_false(grepl("master-confidential", p, fixed = TRUE), info = s)
  }
})

test_that("the two tiers cannot collide on one path", {
  a <- corpusFilePath("r", "confidential", "pdf", "IA000013.pdf")
  b <- corpusFilePath("r", "public",       "pdf", "IA000013.pdf")
  expect_false(identical(a, b))
})

test_that("an unknown share class is refused, not guessed", {
  # Guessing has two failure modes and both are bad: guess "master" for a
  # confidential file and it is exposed to every path-based copy; guess
  # "master-confidential" for a public one and it vanishes from extraction.
  expect_error(corpusShareDir(NA_character_), "no SHARE class")
  expect_error(corpusShareDir(""),            "no SHARE class")
  expect_error(corpusFilePath("r", c("public", NA), "pdf", c("a.pdf", "b.pdf")),
               "no SHARE class")
})

test_that("the resolver is vectorised, so a mixed index is handled row-wise", {
  # The call sites pass whole columns of master.csv. A resolver that only
  # honoured the first element would file every row under one tier - which
  # is precisely the bug being fixed, reintroduced.
  share <- c("public", "confidential", "restricted", "confidential")
  p <- corpusFilePath("r", share, "pdf", paste0("IA", 1:4, ".pdf"))
  expect_length(p, 4L)
  expect_equal(grepl("master-confidential", p), c(FALSE, TRUE, FALSE, TRUE))
})
