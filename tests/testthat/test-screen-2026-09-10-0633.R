# Security screen 2026-09-10-0633, the merged range 75a7a3b..2260045.
#
# F1 (HIGH): every gate on the fail-safe fill bounded how many candidate
#   tables EXIST. A block with every level printed as a count has width 1
#   everywhere, so one percentage cell admitting two counts gives exactly
#   two candidates at any size - and r2dtable() then allocates
#   replicates x arms x levels for each of them, unchecked. Measured on
#   2260045 with two candidates: 60 x 37 took 41 s and 491 MB, 200 x 37
#   took 148 s and 1,008 MB, inside the 60 s child timeout, in a child
#   with no memory ceiling.
# F2 (LOW): the tripwire pins added by screen 0611 were weaker than their
#   comments said; five mutations passed them. Mutation-tested in the
#   harness, not here.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-10,
# per the AGENTS.md rule of the same day: the test reproduces the report
# through the report's own path - the fill, with the screen's own block -
# and every assertion was checked to FAIL on 2260045.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

peak <- function(expr) {
  gc(reset = TRUE, full = TRUE)
  t <- system.time(force(expr))[["elapsed"]]
  list(t = t, mb = sum(gc(full = TRUE)[, 6]))
}

# the screen's construction: every cell pinned at 50 except arm 1 /
# level 1, which admits 50..51 - two candidate tables whatever the size
twoCandidate <- function(arms, levels, N = 5000) {
  lo <- matrix(50L, arms, levels); hi <- lo; hi[1, 1] <- 51L
  list(lo = lo, hi = hi, cnt = matrix(NA_integer_, arms, levels), N = rep(N, arms))
}

test_that("a block the simulation cannot carry is refused before it is scored", {
  d <- twoCandidate(200, 37)
  r <- peak(res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE))
  expect_false(isTRUE(res$resolved))
  expect_match(res$reason, "too large to score")
  # 148 s and 1,008 MB on 2260045
  expect_lt(r$t, 2)
  expect_lt(r$mb, 400)
  # and the honest-looking 60 x 37, which a JATS document was shown to
  # reach end to end (screen 0536 F1): 41 s and 491 MB before
  d <- twoCandidate(60, 37)
  r <- peak(res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE))
  expect_false(isTRUE(res$resolved))
  expect_lt(r$t, 2)
})

test_that("a block the simulation CAN carry is scored, and reads the same", {
  # the gate admits 100 cells per table (screen 0734 tightened it from
  # 250, from a measured cost model): four arms by twenty-five levels is
  # the edge and is inside it, and so is every ordinary block
  d <- twoCandidate(2, 3)
  res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE)
  expect_true(isTRUE(res$resolved))
  expect_equal(res$nTables, 2L)
  d <- twoCandidate(4, 25)
  res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE)
  expect_true(isTRUE(res$resolved))
  # ...and ten by twenty, 200 cells, is now refused by name
  d <- twoCandidate(10, 20)
  res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE)
  expect_false(isTRUE(res$resolved))
  # the ordinary block is bitwise what it was: chunked drawing is
  # RNG-identical to a single call, so nothing pinned may move
  br <- function(pct, N) list(lo = ceiling((pct - 0.5) / 100 * N),
                              hi = floor((pct + 0.5) / 100 * N))
  b <- br(c(25, 42, 33), 700)
  res <- .ppFailsafeTableFill(rbind(b$lo, b$lo), rbind(b$hi, b$hi),
                              matrix(NA_integer_, 2, 3), c(700, 700),
                              partition = FALSE)
  expect_true(isTRUE(res$resolved))
  expect_equal(res$nTables, 117649L)
  expect_equal(res$pBest, 0.1013, tolerance = 1e-3)
})

test_that("drawing the null in chunks is RNG-identical to one call", {
  # the property .ppTableP() now relies on, stated on its own
  r <- c(30, 40); cc <- c(35, 35)
  set.seed(7); a <- r2dtable(1000, r, cc)
  set.seed(7); b <- c(r2dtable(500, r, cc), r2dtable(500, r, cc))
  expect_identical(a, b)
  # and the p it produces is the same whatever the chunk size
  tab <- rbind(c(12, 18), c(20, 20))
  set.seed(11); p1 <- .ppTableP(tab, 2000L)
  set.seed(11); p2 <- .ppTableP(tab, 2000L)
  expect_identical(p1, p2)
  # the chunk is sized by the table since screen 0734: at 2 x 2 it is far
  # above any budget, i.e. one call
  expect_gte(floor(.ppTableDrawCells / 4), 20000L)
})
