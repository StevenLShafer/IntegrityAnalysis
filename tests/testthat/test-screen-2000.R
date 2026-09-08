# Security screen 2026-09-07-2000, which screened the fix for screen 1907
# and found the same false-accusation lever twice more.
#
# F1 (HIGH): the location-side observation-grid rule is vacuous wherever
# hObs/N is finer than the printed mean's own step, which an attacker
# arranges by picking N. The dispersion side closes it, and it is a
# theorem: N values on a grid of width h have a sample SD that is either
# exactly 0 or at least h/sqrt(N). Three arms of 1,000 printing mean 500
# and SD 1 read p = 0.5 honestly and 9.999e-05 at ROUND_OBSERVATION = -3.
# F2 (HIGH): every grid test is one-sided - a decimal sits on every FINER
# grid - so a stated precision finer than the printed value passed them
# all, and an over-fine ROUND_MEAN erases the tie mass an honest row with
# identical printed means lives on: 0.4185 -> 9.999e-05 at ROUND_MEAN 15.
# F3 (MEDIUM): the skipped-line cap was applied at one of its two call
# sites, and the registry it feeds was consumed by an O(entries x rows)
# loop - 45 seconds per grid render at 60,000 of each, measured.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runRow <- function(D, m = 2000, seed = 3) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}
flat <- function(k, N, mean, sd, rm, ro, rd)
  data.frame(TRIAL = "T", ROW = "X", N = rep(N, k), MEAN = rep(mean, k),
             SD = rep(sd, k), ROUND_MEAN = rm, ROUND_OBSERVATION = ro,
             ROUND_DISPERSION = rd, stringsAsFactors = FALSE)

test_that("F1: an SD no sample on the stated observation grid could produce is refused", {
  # the screen's rows, through the engine
  expect_false(grepl("stated precision", runRow(flat(3, 1000, 500, 1, 0, 0, 0))$P))
  expect_match(runRow(flat(3, 1000, 500, 1, 0, -3, 0))$P, "stated precision")
  expect_match(runRow(flat(2, 1000, 500, 1, 0, -3, 0))$P, "stated precision")
  expect_match(runRow(flat(2, 100, 50, 1, 0, -2, 0))$P, "stated precision")
})

test_that("F1: the bound itself, and what it must never refuse", {
  # The signature and the bound both changed the next hour (screen
  # 2026-09-07-2101): the arguments carry the printed value's own
  # precision and the mean, the bound is h times the mean's lattice
  # offset rather than h/sqrt(N), and it applies only where a COARSER
  # observation grid is stated. These calls are updated to that shape;
  # test-screen-2101.R holds the cases for the sharpened rule.
  expect_true(.iaSdReachesGrid(10, 0, 0, 0, 40, 50))       # ordinary
  expect_false(.iaSdReachesGrid(1, 0, -3, 0, 1000, 500))   # 1 against 499.5
  expect_false(.iaSdReachesGrid(1, 0, -2, 0, 100, 50))     # 1 against 50
  # an SD of exactly zero: allowed only where the mean could BE one of the
  # identical values, i.e. where its interval holds a multiple of the grid
  # (CodeRabbit on PR #222; a mean of 500 on a grid of 1,000 cannot)
  expect_true(.iaSdReachesGrid(0, 0, -3, 0, 1000, 1000))
  expect_false(.iaSdReachesGrid(0, 0, -3, 0, 1000, 500))
  # the printed SD's own interval is used, so an honestly coarse SD passes
  expect_true(.iaSdReachesGrid(1, 0, 0, 0, 4, 50))
  expect_true(.iaSdReachesGrid(c(NA, 10), c(0, 0), c(0, 0), c(0, 0), c(40, 40), c(50, 50)))
  # A BLANK or ABSENT dispersion precision is inferred from the SD's own
  # printed decimals, as the simulation infers it - an absent column made
  # the whole test vacuous and an NA made it falsely strict (CodeRabbit on
  # PR #221)
  expect_false(.iaSdReachesGrid(1, NULL, -3, 0, 1000, 500))   # still caught
  expect_false(.iaSdReachesGrid(1, NA, -3, 0, 1000, 500))
  expect_true(.iaSdReachesGrid(10, NULL, 0, 0, 40, 50))       # honest, still passes
})

test_that("F1 reaches a direct caller that supplies no ROUND_DISPERSION column", {
  D <- data.frame(TRIAL = "T", ROW = "X", N = rep(1000, 3), MEAN = rep(500, 3),
                  SD = rep(1, 3), ROUND_MEAN = 0, ROUND_OBSERVATION = -3,
                  stringsAsFactors = FALSE)
  expect_match(runRow(D)$P, "stated precision")
})

test_that("F1's rows are all judged on a STATED coarse observation grid", {
  # the bound is confined to that case since screen 2026-09-07-2101's F5;
  # every row this file refuses states ROUND_OBSERVATION coarser than
  # ROUND_MEAN, which is what makes the refusal a statement about the
  # table rather than about a default
  expect_false(grepl("stated precision", runRow(flat(3, 1000, 500, 1, 0, 0, 0))$P))
})

test_that("F2: a stated precision finer than the printed value is DISCLOSED, not refused", {
  # Refusing was tried and rejected: a mean stored as 50 may have been
  # printed "50" or "50.000000" - a spreadsheet keeps no trailing zeros -
  # so the honest row and the manipulated one are the same numbers, and
  # the 2026-09-06 audit's own case is the honest one (integer
  # observations with a six-decimal printed mean, where the small p is
  # right). The row is analysed as the table claims, and the claim rides
  # with the answer.
  honest <- runRow(flat(3, 30, 0.5, 0.1, 1, 1, 1))
  expect_false(grepl("stated mean precision", honest$NOTE))
  expect_gt(as.numeric(sub("^<", "", honest$P)), 0.05)
  fine <- runRow(flat(3, 30, 0.5, 0.1, 15, 1, 1))
  expect_match(fine$NOTE, "stated mean precision")
  expect_match(fine$NOTE, "15 decimals", fixed = TRUE)
  expect_match(runRow(flat(3, 30, 50, 10, 13, 0, 0))$NOTE, "stated mean precision")
  # ...and a median row carries it beside its own notes
  med <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(12.4, 12.4),
                    SD = NA_real_, Q1 = c(10.2, 10.2), Q3 = c(15.1, 15.1),
                    ROUND_MEAN = 12, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 1,
                    stringsAsFactors = FALSE)
  expect_match(runRow(med)$NOTE, "stated mean precision")
})

test_that("F2: the slack is enough for the trailing zeros a spreadsheet drops", {
  # the 2026-09-06 audit's own row - integer observations, a six-decimal
  # printed mean - must be ANALYSED, which is why this is a note and not
  # a refusal
  expect_false(grepl("stated precision", runRow(flat(2, 100, 50, 3, 6, 0, 0))$P))
  # The slack went to ZERO the next hour (screen 2026-09-07-2101, F2): at
  # two decimals the row was already at the reportable floor with no note
  # at all, and a note is the cheap side of an error. The note's wording
  # carries the trailing-zero caveat instead of the threshold doing it.
  expect_false(.iaStatedPrecisionNotTooFine(1.2, 2))
  expect_false(.iaStatedPrecisionNotTooFine(50, 2))
  expect_true(.iaStatedPrecisionNotTooFine(1.2, 1))
  expect_true(.iaStatedPrecisionNotTooFine(50, 0))
  expect_false(.iaStatedPrecisionNotTooFine(50, 13))
  expect_false(.iaStatedPrecisionNotTooFine(0.5, 15))
  # judged on the finest printed value in the row, not arm by arm
  expect_true(.iaStatedPrecisionNotTooFine(c(50, 50.25), 2))
  expect_true(.iaStatedPrecisionNotTooFine(c(NA, NaN), c(NA, 2)))
})

test_that("the honest shapes every earlier screen pinned still run", {
  expect_false(grepl("precision", runRow(flat(2, 40, 50, 10, 0, 0, 0))$P))
  med <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(12.4, 12.9),
                    SD = NA_real_, Q1 = c(10.2, 10.8), Q3 = c(15.1, 15.4),
                    ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 1,
                    stringsAsFactors = FALSE)
  expect_false(grepl("precision", runRow(med)$P))
  big <- data.frame(TRIAL = "T", ROW = "X", N = c(5000, 5000),
                    MEAN = c(1e9 + 0.25, 1e9 + 0.25), SD = c(0.05, 0.05),
                    ROUND_MEAN = 2, ROUND_OBSERVATION = 2, ROUND_DISPERSION = 2,
                    stringsAsFactors = FALSE)
  expect_false(grepl("precision", runRow(big, m = 1000)$P))
  # an arm whose values are all identical prints SD 0 and must survive
  expect_false(grepl("precision", runRow(flat(2, 40, 5, 0, 0, 0, 0), m = 1000)$P))
})

test_that("F3: the cap itself, and both producers sharing it", {
  # the function both producers call: a 250-row frame comes back capped
  # with its marker, whatever columns the parser's frame carries
  sk <- data.frame(label = paste("line", seq_len(250)),
                   reason = paste("reason", seq_len(250)),
                   text = paste("text", seq_len(250)), stringsAsFactors = FALSE)
  expect_equal(nrow(.iaCapSkipped(sk)), .iaMaxSkippedRows + 1L)
  # ...and that BOTH call sites use it. The source is not installed with
  # the package, so this half runs from a source checkout only; the same
  # property is pinned in tools/securityCheck.R, which the security screen
  # runs before every screen.
  src <- file.path("..", "..", "R", "app_server.R")
  skip_if(!file.exists(src), "not a source checkout")
  txt <- readLines(src)
  # the wide branch caps its whole FILE, since one sheet may hold thousands
  # of "Trial:" blocks and a per-block cap bounds nothing (screen
  # 2026-09-07-2101, F4); the document branch caps its own frame
  expect_true(any(grepl(".iaCapSkippedFile(", txt, fixed = TRUE)))
  expect_true(any(grepl("r$skipped <- .iaCapSkipped(", txt, fixed = TRUE)))
})
