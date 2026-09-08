# Security screen 2026-09-07-2339, which screened the previous screen's
# fix and found the same lever open a step further out.
#
# F1 (MEDIUM-HIGH): the fine-precision Note - the whole adjudicated remedy
# for that shape - was still switchable off, and more cheaply than before.
# Both definitions of "the arms are equal" were computed from the same
# attacker-supplied doubles, so widening the perturbation by one decimal
# defeated them: at 1e-15 through 1e-13 the p stayed bitwise identical at
# the reportable floor and the note vanished.
# F2 (LOW-MEDIUM): the coarse-precision note fired on the configuration the
# user guide's own worked example teaches (integer observations beside a
# one-decimal mean), and asserted "a large p" on rows reading 0.005.
# F3 (LOW): .iaDerivedPayload still scanned the whole grid once per
# registry entry - the first of the two quadratics, with only the registry
# capped. F4 (LOW): .iaCapRegistry kept the OLDEST rows.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-08.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runRow <- function(D, m = 4000, seed = 42) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}
mk <- function(means, rm, ro = 1, rd = 1, N = 30, sd = 1)
  data.frame(TRIAL = "T", ROW = "X", N = rep(N, length(means)), MEAN = means,
             SD = rep(sd, length(means)), ROUND_MEAN = rm,
             ROUND_OBSERVATION = ro, ROUND_DISPERSION = rd,
             stringsAsFactors = FALSE)

test_that("F1: the disclosure survives every perturbation that leaves the p where it was", {
  # the engine's own verdict closes the region below its zero-snap; equality
  # at the fewest decimals any arm carries closes the region above it, where
  # the statistic clears the snap but the p is still at the floor
  for (delta in c(0, 2^-52, 1e-15, 1e-14, 1e-13, 1e-12, 1e-11)) {
    row <- runRow(mk(c(0.5, 0.5 + delta, 0.5), 15))
    expect_match(row$NOTE, "stated mean precision",
                 info = paste("perturbation", format(delta)))
  }
  # giving ONE arm more decimals must not raise the bar the stated
  # precision is measured against
  expect_false(.iaStatedPrecisionNotTooFine(c(0.5, 0.5 + 1e-15, 0.5), 15, use = min))
  # ...and arms that genuinely differ where the page can see it say nothing
  expect_false(grepl("stated mean precision", runRow(mk(c(0.5, 1.5, 2.5), 15))$NOTE))
  expect_false(grepl("stated mean precision", runRow(mk(c(0.5, 0.5, 0.5), 1))$NOTE))
})

test_that("F2: the guide's own worked configuration is not accused", {
  # "a mean printed to one decimal is often computed from integer
  # measurements - so when you know the raw precision, say so": that is
  # ROUND_OBSERVATION 0 beside ROUND_MEAN 1, and it must draw no note
  guide <- runRow(mk(c(50.5, 50.6, 50.5), 1, ro = 0, rd = 0, N = 1000, sd = 10))
  expect_false(grepl("coarser", guide$NOTE))
  alarming <- runRow(mk(c(50.5, 50.6, 50.5), 1, ro = 0, rd = 0, N = 1000, sd = 30))
  expect_false(grepl("coarser", alarming$NOTE))
  # the mechanism the note describes - a coarse MEAN grid - is still said
  expect_match(runRow(mk(c(50, 50, 50), -1, ro = 1, rd = 0, N = 100, sd = 30))$NOTE,
               "coarser than the digits")
  # and it no longer asserts that the p is large
  expect_false(grepl("a large p", .iaCoarsePrecisionNote(c(50, 50), -1)))
  expect_match(.iaCoarsePrecisionNote(c(50, 50), -1), "this row's p")
})

test_that("F3: the derived payload scales in the GRID, the dimension nothing caps", {
  mkGrid <- function(n) data.frame(TRIAL = rep("T", n), ROW = paste0("R", seq_len(n)),
                                   N = 1, MEAN = 1, SD = 1, stringsAsFactors = FALSE)
  reg <- data.frame(TRIAL = "T", ROW = paste0("R", seq_len(2000)), COL = "N",
                    KIND = "derived", note = "n", stringsAsFactors = FALSE)
  small <- system.time(a <- .iaDerivedPayload(mkGrid(5000), reg))[["elapsed"]]
  big   <- system.time(b <- .iaDerivedPayload(mkGrid(40000), reg))[["elapsed"]]
  expect_equal(length(a$iss), 2000L)
  expect_equal(length(b$iss), 2000L)
  # eight times the grid, with the registry pinned: the per-entry scan this
  # replaced measured 0.92 s at 10,000 rows and 7.43 s at 100,000
  skip_on_cran()
  expect_lt(big, 3)
  expect_lt(big, max(0.5, small * 24))
})

test_that("F3: the payload still answers what the loop answered", {
  d <- data.frame(TRIAL = rep("T", 6), ROW = paste0("R", 1:6),
                  N = c(10, NA, 10, 10, 10, 10), MEAN = 1, SD = 1,
                  stringsAsFactors = FALSE)
  dv <- data.frame(TRIAL = "T", ROW = c("R1", "R2", "*"), COL = c("N", "N", "MEAN"),
                   KIND = c("derived", "failsafe", "ocr"),
                   note = c("a", "b", "c"), stringsAsFactors = FALSE)
  pay <- .iaDerivedPayload(d, dv)
  expect_equal(pay$iss[["0|2"]], "derived")
  expect_null(pay$iss[["1|2"]])            # R2's N is NA: never painted
  expect_equal(pay$iss[["0|3"]], "ocr")
  expect_equal(pay$note[["0|3"]], "c")
  expect_equal(sum(unlist(pay$iss) == "ocr"), 6L)
  # the last entry for a cell wins, as the per-cell overwrite did
  dv2 <- data.frame(TRIAL = "T", ROW = c("R1", "R1"), COL = c("N", "N"),
                    KIND = c("derived", "failsafe"), note = c("first", "second"),
                    stringsAsFactors = FALSE)
  p2 <- .iaDerivedPayload(d, dv2)
  expect_equal(p2$iss[["0|2"]], "failsafe")
  expect_equal(p2$note[["0|2"]], "second")
})

test_that("F4: the registry cap keeps the newest rows", {
  reg <- data.frame(TRIAL = "T", ROW = paste0("R", seq_len(9000)), COL = "N",
                    KIND = c(rep("derived", 8999), "ocr"), note = "n",
                    stringsAsFactors = FALSE)
  capped <- .iaCapRegistry(reg)
  expect_equal(nrow(capped), .iaMaxRegistryRows)
  # the OCR warning added by the last file survives; the head is dropped
  expect_true("ocr" %in% capped$KIND)
  expect_equal(capped$ROW[nrow(capped)], "R9000")
})
