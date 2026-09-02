# test-safe-match.R - the join guard that the corpus scripts depend on.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-01 by Claude Code (model Claude Opus 5) during the join   #
# audit called for in the 2026-08-31 handoff.                              #
#                                                                          #
# WHY THIS TEST EXISTS AT ALL. Nine defects were found on 2026-08-31 and    #
# NOT ONE of them broke a test - they all presented as success. The         #
# corruption this file pins down was caught by a coverage figure that was   #
# too good (17,035 of 17,035), not by the suite. So the assertions below    #
# are deliberately written as the FAILURE, not as the feature: each one     #
# states what plain match() did wrong, and then that safeMatch() does not.  #
#                                                                          #
# SCOPE, STATED HONESTLY. corpus/ is listed in .Rbuildignore, so it is not  #
# in the tarball that R CMD check builds; this file therefore SKIPS in      #
# GitHub Actions and runs only in a development tree (devtools::test()).    #
# That is a real limitation, not an oversight - moving safeMatch() into R/  #
# to get it checked would ship corpus tooling inside the app, which the     #
# repository deliberately does not do.                                      #
############################################################################

sourceSafeMatch <- function() {
  p <- testthat::test_path("..", "..", "corpus", "safeMatch.R")
  if (!file.exists(p))
    testthat::skip("corpus/ is .Rbuildignore'd - not present in a built package")
  source(p, local = parent.frame())
}

test_that("a blank key is a miss, not a hit on the first blank row", {
  sourceSafeMatch()

  # THE 2026-08-31 CORRUPTION, in miniature. The right-hand table is
  # pmidToPmcid.csv: 11,428 of its 24,541 rows carry a PMID but no PMCID.
  # The left-hand vector is the library: thousands of works - every
  # confidential A&A manuscript among them - carry no PMCID either.
  pmcid <- c("PMC1", "", NA, "PMC2")
  tbl <- data.frame(PMCID = c("PMC1", "", "PMC2"),
                    PMID  = c("111", "999", "222"), stringsAsFactors = FALSE)

  # What went wrong: the work with no PMCID was handed PMID 999 - a real,
  # named stranger's paper - and the coverage report scored it as found.
  expect_identical(tbl$PMID[match(pmcid, tbl$PMCID)],
                   c("111", "999", NA, "222"))

  # What must happen instead: unidentified stays unidentified.
  expect_identical(safeMatch(pmcid, tbl$PMCID), c(1L, NA_integer_, NA_integer_, 3L))
  expect_identical(tbl$PMID[safeMatch(pmcid, tbl$PMCID)],
                   c("111", NA, NA, "222"))
})

test_that("both spellings of missing are refused", {
  sourceSafeMatch()
  # read.csv(colClasses = "character") yields "" where the CSV field was
  # empty and NA where it held the literal text NA. Both reach these
  # joins, and both must be treated as unknown.
  expect_identical(safeMatch(c("", NA), c("a", "b")), c(NA_integer_, NA_integer_))
  expect_identical(safeMatch("x", c("", NA)), NA_integer_)
})

test_that("a real key is unaffected however blank the table is", {
  sourceSafeMatch()
  # This is the property that makes it safe to apply safeMatch to every
  # data-keyed join in corpus/: it can only ever turn a wrong join into a
  # missing one, never a right join into a wrong one.
  expect_identical(safeMatch("b", c("", NA, "b")), 3L)
  expect_identical(safeMatch(c("b", "a"), c("a", "b")), c(2L, 1L))
  expect_identical(safeMatch(character(0), c("a")), integer(0))
})

test_that("non-character keys are coerced before the blankness test", {
  sourceSafeMatch()
  # buildCorpusLibrary.R reads its keys as character, but nothing forces
  # a caller to. nzchar() on a factor tests the integer code, not the
  # label, which would silently pass a blank level through.
  expect_identical(safeMatch(c(1, NA), c(2, 1)), c(2L, NA_integer_))
  expect_identical(safeMatch(factor(c("a", "")), factor(c("", "a"))),
                   c(2L, NA_integer_))
})

test_that("iaBlankKey names the two spellings of missing and nothing else", {
  sourceSafeMatch()
  expect_identical(iaBlankKey(c("a", "", NA, " ", "0")),
                   c(FALSE, TRUE, TRUE, FALSE, FALSE))
  # A space is NOT blank here, deliberately: a key that is whitespace is a
  # data-quality problem for the source reader to trim, and silently
  # treating it as missing would hide that.
})
