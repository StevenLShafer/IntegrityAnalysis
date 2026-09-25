# test-other-population-arm-flag.R - a column headed volunteers or healthy
# controls beside randomised arms raises a review flag (ISSUES.md issue 62,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 9 finding O2 (AAS1998_851, Saitoh): fifteen       #
# volunteers beside three randomised current groups of 40; the cells are  #
# right, the column is not an arm of the trial, and carried as one it     #
# moved P_FULL from 0.34 to 0.043 on the categorical rows.                 #
############################################################################

test_that("a volunteers or healthy-controls arm is flagged; ordinary arms are not", {
  r <- parseBaselineTableHeuristics(syntheticPdfMeanSD(), quiet = TRUE)
  expect_false(any(grepl("different population", reviewFlags(r))))
  for (nm in c("Volunteers", "Healthy controls", "Normal subjects", "volunteer group")) {
    r2 <- r; r2$arms$arm[2] <- nm
    fl <- reviewFlags(r2)
    expect_true(any(grepl("different population", fl)), info = nm)
    expect_true(any(grepl(nm, fl, fixed = TRUE)), info = nm)
  }
  r3 <- r; r3$arms$arm <- c("Control", "Treatment")
  expect_false(any(grepl("different population", reviewFlags(r3))))
  # whole words (CodeRabbit on PR #367): "Unhealthy controls" and "Abnormal subjects" are
  # not healthy controls or normal subjects; a spaced "Non randomised" is flagged
  for (nm in c("Unhealthy controls", "Abnormal subjects")) {
    r4 <- r; r4$arms$arm[2] <- nm
    expect_false(any(grepl("different population", reviewFlags(r4))), info = nm)
  }
  r5 <- r; r5$arms$arm[2] <- "Non randomised controls"
  expect_true(any(grepl("different population", reviewFlags(r5))))
})
