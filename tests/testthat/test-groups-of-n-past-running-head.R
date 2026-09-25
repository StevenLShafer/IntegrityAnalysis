# test-groups-of-n-past-running-head.R - "divided into three groups of
# Methods D 10 each": a two-column page's running head, interleaved into
# the sentence by the text extractor, does not hide the group size when
# "each" follows it (ISSUES.md issue 103, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 25 AD8 (Fujii, PMID 11004073): every cell read    #
# with names after issues 91 and 95, but N stayed missing because the      #
# Methods sentence came out of pdf_text() with the running head inside it. #
############################################################################

test_that("up to three stray words between 'of' and the size are stepped over when 'each' follows", {
  g <- .ppGroupsOfN("The dogs were randomly divided into three groups of Methods D 10 each: Group I received no study drug.")
  expect_identical(g$groups, 3L); expect_identical(g$n, 10L)
  expect_identical(.ppGroupNFor(g, 3L)$n, 10L)
  # the plain sentence still reads, and stray words without "each" after the number license nothing
  expect_identical(.ppGroupsOfN("The dogs were randomly divided into three groups of eight each.")$n, 8L)
  expect_null(.ppGroupsOfN("The dogs were divided into three groups of Methods D and received 10 mg each day."))
  expect_null(.ppGroupsOfN("The dogs were divided into three groups of Methods and Results Discussion 10 each."))   # four stray words: too far
})
