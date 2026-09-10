# Security screen 2026-09-10-0923, the merged range ae37f0e..8c54644.
#
# The diff was sound; two LOWs in the same file.
#
# F1 (LOW, verified end to end): .ppCountBracket() has the integer-overflow
#   crash its sibling was just cured of. A header cell "(n=2147000000)"
#   arrives intact through as.integer(), a "100%" cell then makes
#   as.integer(floor(N * 1.005)) NA, the comparison raises, and on the JATS
#   route the whole document fails with a message naming no cell.
# F2 (LOW, verified at the function): the ceiling added by screen 0858
#   broke the invariant that a derived arm size is at least the printed
#   count. .ppNFromCountPct(5010, 100, 0L) returned the DESCENDING
#   sequence 5010..5000 - eleven values, ten above the ceiling - and
#   .ppDeriveArmN() then derived N = 5000 for an arm whose own count is
#   5010, with the provenance "derived from printed n (%) cells".
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-10,
# per the AGENTS.md rule: the F1 test drives the screen's own table
# through parseBaselineTableJats(); every assertion was checked to FAIL
# on 8c54644.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that("a header arm size near the integer limit does not sink the document", {
  skip_if_not(file.exists(test_path("helper-syntheticJats.R")))
  jats <- function(N, cell) {
    f <- tempfile(fileext = ".xml")
    makeJatsArticle(f, list(list(caption = "Baseline characteristics",
      rows = list(c("", sprintf("Control (n=%d)", N), sprintf("Treatment (n=%d)", N)),
                  # a genuinely usable row, so that skipping the percent row
                  # leaves a table rather than nothing - the first fixture had
                  # only "Age 60 61", no dispersion, and the document had no
                  # usable row at all once the percent row was rightly skipped
                  c("Age (yr)", "45.3 ± 12.1", "46.1 ± 11.8"),
                  c("Male sex, %", cell, cell)))))
    f
  }
  # the screen's document: on 8c54644 it failed entirely with "No usable
  # baseline table could be parsed"
  res <- tryCatch(
    suppressWarnings(parseBaselineTableJats(jats(2147000000L, "100%"), trial = "T", quiet = TRUE)),
    error = function(e) e)
  expect_false(inherits(res, "error"))
  expect_false(is.null(res$data))
  # the percent row cannot be read against an arm the analysis would
  # refuse, so it is skipped; the age row survives
  expect_true(any(grepl("Age", res$data$ROW)))
  # and no warning from as.integer() on the way
  expect_silent(.ppCountBracket(100, 0L, 2147000000))
})

test_that(".ppCountBracket() refuses in doubles, before as.integer()", {
  b <- .ppCountBracket(100, 0L, 2147000000)
  expect_true(all(is.na(unlist(b))))
  # an arm above the ceiling yields no bracket at any percentage
  b <- .ppCountBracket(50, 0L, 6000)
  expect_true(all(is.na(unlist(b))))
  # an honest arm still brackets as before
  b <- .ppCountBracket(50, 0L, 200)
  expect_equal(unname(unlist(b)[1:2]), c(99, 101))
})

test_that("a derived arm size is never below the printed count", {
  # the F2 shape: count above the ceiling at a percentage near 100
  expect_length(.ppNFromCountPct(5010, 100, 0L), 0L)
  expect_length(.ppNFromCountPct(5001, 100, 0L), 0L)
  # the derivation that settled on exactly the ceiling on 8c54644
  d <- .ppDeriveArmN(c(5010, 2505), c(100, 50), c(0L, 0L))   # a bare integer
  expect_true(length(d) == 0L || is.na(d))
  # the ceiling itself is still reachable honestly
  expect_true(5000L %in% .ppNFromCountPct(5000, 100, 0L))
  expect_true(5000L %in% .ppNFromCountPct(2500, 50, 0L))
  # and every returned size is at least the count, ascending
  s <- .ppNFromCountPct(4990, 99.9, 1L)
  expect_true(all(s >= 4990))
  expect_true(all(diff(s) >= 0))
})
