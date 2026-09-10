# Security screen 2026-09-10-0734, the merged range 2260045..a4a6840.
#
# F1 (MEDIUM): the scoring gate of screen 0633 bounded CELLS and its log
#   entry said that bounded the time. Measured, it did not: r2dtable()
#   pays a setup proportional to the GRAND TOTAL on every call, and the
#   fixed chunk of 500 turned one call of 20,000 into forty. A 125-arm
#   binary block at 5,000 per arm - 250 cells, grand total 625,000, inside
#   every gate - RESOLVED in 55.8 s on a4a6840, up from 34 s before the
#   chunking, inside the 60 s child timeout with nothing left for the
#   rest of the document.
# F2 (LOW): the assignment pin missed `->`, `->>`, assign() and a for()
#   rebinding. Mutation-tested in the harness, not here.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-10,
# per the AGENTS.md rule: the test reproduces the report through the
# report's own path - the fill, with the screen's own shapes - and every
# assertion was checked to FAIL on a4a6840.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

peak <- function(expr) {
  gc(reset = TRUE, full = TRUE)
  t <- system.time(force(expr))[["elapsed"]]
  list(t = t, mb = sum(gc(full = TRUE)[, 6]))
}

# the screen's construction: every cell pinned at N/levels, and `amb`
# cells admitting two counts each, so 2^amb candidates
shape <- function(arms, levels, N, amb) {
  base <- as.integer(N / levels)
  lo <- matrix(base, arms, levels); hi <- lo
  k <- 0L
  for (a in seq_len(arms)) for (j in seq_len(levels)) {
    if (k >= amb) break
    hi[a, j] <- base + 1L; k <- k + 1L
  }
  list(lo = lo, hi = hi, cnt = matrix(NA_integer_, arms, levels), N = rep(N, arms))
}
fill <- function(d) .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE)

test_that("the largest block the gate admits scores in seconds, not fifty", {
  # THE assertion the previous screen said was missing: the previous test
  # timed only the shapes that decline. These are the two edges of the
  # gate - 100 cells, and a grand total of 125,000 - each with fourteen
  # ambiguous cells, 16,384 candidates. Measured 7.6 s and 6.9 s here;
  # the budget leaves room for a slower machine.
  for (d in list(shape(4, 25, 5000, 14), shape(25, 2, 5000, 14))) {
    r <- peak(res <- fill(d))
    expect_true(isTRUE(res$resolved))
    expect_equal(res$nTables, 16384L)
    expect_lt(r$t, 20)
    expect_lt(r$mb, 400)
  }
})

test_that("the shapes that took 24 to 56 seconds now decline, and at once", {
  # 55.8 s / 27.1 s / 23.7 s / 10.8 s on a4a6840, every one RESOLVING.
  # The gate depends only on dimensions and arm sizes, so it sits before
  # the enumeration and the decline costs nothing.
  for (d in list(shape(125, 2, 5000, 14), shape(60, 2, 5000, 14),
                 shape(10, 25, 5000, 14), shape(125, 2, 5000, 1))) {
    r <- peak(res <- fill(d))
    expect_false(isTRUE(res$resolved))
    expect_match(res$reason, "too large to score")
    expect_lt(r$t, 1)
  }
})

test_that("an ordinary block is untouched, and the chunk is one call", {
  br <- function(pct, N) list(lo = ceiling((pct - 0.5) / 100 * N),
                              hi = floor((pct + 0.5) / 100 * N))
  b <- br(c(25, 42, 33), 700)
  res <- .ppFailsafeTableFill(rbind(b$lo, b$lo), rbind(b$hi, b$hi),
                              matrix(NA_integer_, 2, 3), c(700, 700),
                              partition = FALSE)
  expect_true(isTRUE(res$resolved))
  expect_equal(res$pBest, 0.1013, tolerance = 1e-3)
  # at or under the cells the gate admits, 1e7 / cells exceeds the refine
  # budget, so the null is ONE r2dtable call again - the forty-call setup
  # cost that made the regression is gone by construction
  expect_gte(floor(.ppTableDrawCells / .ppTableScoreCells), .ppTableRefineReps)
  # and the rank cap still fixes the number of calls
  expect_equal(.ppTableRankMax, 50L)
})
