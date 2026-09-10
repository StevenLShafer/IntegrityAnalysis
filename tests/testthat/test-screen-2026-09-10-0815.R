# Security screen 2026-09-10-0815, the merged range a4a6840..24a8177.
#
# F1 (HIGH): the scoring gate bounded sum(N[keep]) and called it the grand
#   total, but r2dtable() pays for the sum of the TABLE, and a level
#   printed as a COUNT reaches the fill with no ceiling at all. Two arms
#   of 5,000 with two count levels printing 25,000,000 and one ambiguous
#   percentage - six cells, "grand total" 10,000, admitted - took 95 s and
#   892 MB through the JATS reader and was killed at the child's timeout.
#   The validator refuses exactly this one function later.
# F2 (MEDIUM): on the percentage route the levels need not sum to N, so
#   four arms by 25 levels pinned at N has a table sum of 500,000 and took
#   27 s where the code claimed under ten.
# F3 (LOW): the previous test placed every cell at N / levels, so the two
#   sums could never diverge in the test, and the pin was satisfied by a
#   gate bounding the wrong one.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-10,
# per the AGENTS.md rule: the F1 test reproduces the report through the
# report's own path - a JATS document through parseBaselineTableJats() -
# and every assertion was checked to FAIL on 24a8177.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

peak <- function(expr) {
  gc(reset = TRUE, full = TRUE)
  t <- system.time(force(expr))[["elapsed"]]
  list(t = t, mb = sum(gc(full = TRUE)[, 6]))
}
fill <- function(d) .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE)

# --------------------------------------------------- F1, the report's path ----

test_that("printed counts above the arm ceiling are refused before r2dtable sees them", {
  skip_if_not(file.exists(test_path("helper-syntheticJats.R")))
  jats <- function(count) {
    f <- tempfile(fileext = ".xml")
    makeJatsArticle(f, list(list(caption = "Baseline characteristics",
      rows = list(
        c("", "Control (n = 5000)", "Treatment (n = 5000)"),
        c("Age", "60", "61"),
        c("ASA physical status", "", ""),
        c("Class I",  as.character(count), as.character(count)),
        c("Class II", as.character(count), as.character(count)),
        c("Class X, %", "49.9", "49.98")))))
    f
  }
  # the screen's document: 25,000,000 per count cell. 95 s and 892 MB on
  # 24a8177, then killed at the child's timeout; the validator would have
  # refused the row anyway.
  f <- jats(25000000L)
  r <- peak(res <- suppressWarnings(parseBaselineTableJats(f, trial = "T", quiet = TRUE,
                                                           pctApprox = TRUE)))
  expect_lt(r$t, 5)
  expect_lt(r$mb, 400)
  # and the same document with honest counts still reconstructs its row
  f <- jats(2500L)
  res <- suppressWarnings(parseBaselineTableJats(f, trial = "T", quiet = TRUE,
                                                 pctApprox = TRUE))
  expect_false(is.null(res$data))
  expect_true(length(res$approxCounts) > 0 || length(res$approxUnresolved) > 0)
})

test_that("the fill refuses a row whose counts total more than the arm ceiling", {
  # the validator's rule, applied where the cost is spent: two count
  # levels of `count` plus one ambiguous cell
  block <- function(count) list(
    lo  = rbind(c(count, count, 2495L), c(count, count, 2499L)),
    hi  = rbind(c(count, count, 2499L), c(count, count, 2499L)),
    cnt = rbind(c(count, count, NA_integer_), c(count, count, 2499L)),
    N   = c(5000, 5000))
  for (count in c(500000L, 5000000L)) {
    r <- peak(res <- fill(block(count)))
    expect_false(isTRUE(res$resolved))
    expect_match(res$reason, "total more than")
    expect_lt(r$t, 1)                 # 3.1 s and 20.7 s on 24a8177
  }
  # honest counts, same shape: resolved
  res <- fill(block(1200L))
  expect_true(isTRUE(res$resolved))
})

test_that("a partitioned row at exactly the arm ceiling is still read", {
  # THE OVER-REFUSAL THE FULL SUITE CAUGHT BEFORE IT SHIPPED. Where the
  # levels partition the arm - a binary "n (%)" row - the scored table's
  # row total is exactly N by construction, and the first form of the
  # rule summed the bracket TOPS instead: 2,375 + 2,675 = 5,050 against
  # an N of 5,000, so an honest binary row at the arm ceiling was refused.
  # For a partitioned block the row total is N itself.
  N <- 5000
  lo <- ceiling((47 - 0.5) / 100 * N); hi <- floor((47 + 0.5) / 100 * N)
  res <- .ppFailsafeTableFill(
    rbind(c(lo, N - hi), c(lo, N - hi)),
    rbind(c(hi, N - lo), c(hi, N - lo)),
    matrix(NA_integer_, 2, 2), c(N, N), partition = TRUE)
  expect_true(isTRUE(res$resolved))
  # ...while the same tops in a NON-partitioned block, where they can all
  # be realised at once, are over the ceiling and refused
  res <- .ppFailsafeTableFill(
    rbind(c(lo, N - hi), c(lo, N - hi)),
    rbind(c(hi, N - lo), c(hi, N - lo)),
    matrix(NA_integer_, 2, 2), c(N, N), partition = FALSE)
  expect_false(isTRUE(res$resolved))
  expect_match(res$reason, "total more than")
})

# ------------------------------------------------------------------ F2 ----

test_that("a percentage block whose levels each sit at N is bounded by its table sum", {
  # 25 levels each printing 100.00, six ambiguous in arm 1: the gate saw a
  # grand total of 20,000 and admitted a table whose sum is 500,000.
  # 26.1 s on 24a8177; refused by the row-total ceiling now.
  pct <- function(arms, levels, N = 5000, amb = 6) {
    lo <- matrix(as.integer(N), arms, levels); hi <- lo
    lo[1, seq_len(amb)] <- as.integer(N) - 4L
    list(lo = lo, hi = hi, cnt = matrix(NA_integer_, arms, levels), N = rep(N, arms))
  }
  for (d in list(pct(4, 25), pct(2, 50))) {
    r <- peak(res <- fill(d))
    expect_false(isTRUE(res$resolved))
    expect_lt(r$t, 1)
  }
})

# ------------------------------------------------------------------ F3 ----

test_that("the grand total the gate measures is the table's, so the two sums can diverge", {
  # a shape whose table sum is levels x sum(N): pinned cells at N. The
  # previous test's shape put every cell at N / levels, which made the
  # table sum EQUAL sum(N) and hid F1 and F2 by construction.
  N <- 5000; arms <- 4; levels <- 25
  lo <- matrix(as.integer(N), arms, levels); hi <- lo
  lo[1, 1] <- as.integer(N) - 1L
  d <- list(lo = lo, hi = hi, cnt = matrix(NA_integer_, arms, levels), N = rep(N, arms))
  res <- fill(d)
  expect_false(isTRUE(res$resolved))
  expect_match(res$reason, "total more than|too large to score")
  # ...while the largest ADMITTED shapes of screen 0734 still score in seconds
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
  for (d in list(shape(4, 25, 4900, 14), shape(25, 2, 4900, 14))) {
    r <- peak(res <- fill(d))
    expect_true(isTRUE(res$resolved))
    expect_lt(r$t, 20)
  }
})
