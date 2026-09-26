# test-equal-summaries-warning.R - a row whose arms print the same mean
# AND SD with dispersion is flagged to be checked, not called "not a
# sample" nor advised out; a row with no dispersion anywhere still is
# (ISSUES.md issue 169; outside statistical audit 2026-09-26, F3).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# audit's example: three arms of N 40, mean 54.1, SD 9.2, one-decimal      #
# precision - a positive-SD row that read 0.000195 and was told, in every #
# arm, that it was not a sample and should be removed.                     #
############################################################################

test_that("equal mean and SD with dispersion: a factual warning, no removal advice; no dispersion: the removal advice stands", {
  d <- data.frame(TRIAL = "T", ROW = c(rep("Age", 3), rep("Score", 2)),
                  N = 40, MEAN = c(54.1, 54.1, 54.1, 5, 5), SD = c(9.2, 9.2, 9.2, 0, 0),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  w <- .iaRowWarnings(d)
  if (!is.data.frame(w)) w <- do.call(rbind, w)
  age <- w$note[w$row %in% 1:3]
  expect_length(age, 3L)
  expect_true(all(grepl("the same mean and SD printed in every arm", age, fixed = TRUE)))
  expect_false(any(grepl("not a sample", age, fixed = TRUE)))
  expect_false(any(grepl("removing", age, fixed = TRUE)))
  expect_true(all(grepl("stays in", age, fixed = TRUE)))
  score <- w$note[w$row %in% 4:5]
  expect_length(score, 2L)
  expect_true(all(grepl("no dispersion: fixed by design or by a floor, not a sample", score, fixed = TRUE)))
  expect_true(all(grepl("consider removing", score, fixed = TRUE)))
})

test_that("the positive-SD row passes validation with the warning and analyses", {
  d <- data.frame(TRIAL = "T", ROW = "Age", N = 40, MEAN = 54.1, SD = 9.2,
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)[rep(1, 3), ]
  v <- validateData(d)
  expect_false(v$FAIL)
  notes <- v$issues$note[v$issues$code == "warning"]
  expect_true(any(grepl("the same mean and SD printed in every arm", notes, fixed = TRUE)))
  expect_false(any(grepl("not a sample", notes, fixed = TRUE)))
})
