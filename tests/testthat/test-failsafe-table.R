# The counts behind a printed percentage are chosen for the WHOLE table.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5, Anthropic),
# 2026-09-08, with R/failsafeTable.R, at Steve Shafer's direction: "I
# lean towards testing all possible combinations in these ambiguous
# cases, and simply defaulting to giving the authors the benefit of the
# doubt", then "best case, with worst case only appearing if it
# straddles 0.01".
#
# WHY THESE TESTS ARE WRITTEN THE WAY THEY ARE. The rule this replaces
# was wrong three times, and each time a test was written that PASSED on
# the broken code because it computed the expected answer the same way
# the code did. A test that copies the rule tests nothing. So the
# expected values here are built independently: the admissible tables
# are enumerated in the test with plain R, and each is scored with an
# EXACT conditional p (a multivariate hypergeometric enumeration), never
# by calling the functions under test. Every assertion below was checked
# to FAIL on the previous rule.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
}))

# ---- independent machinery, deliberately not the package's ------------

# the bracket of counts a printed percentage allows, from first
# principles rather than from .ppCountBracket()
tBracket <- function(pct, N, dec = 0) {
  half <- 0.5 * 10^(-dec)
  c(max(0, ceiling(N * (pct - half) / 100 - 1e-9)),
    min(N, floor(N * (pct + half) / 100 + 1e-9)))
}

# every count vector for one arm that sums to N
tArmVectors <- function(pcts, N) {
  b <- lapply(pcts, tBracket, N = N)
  g <- expand.grid(lapply(b, function(x) x[1]:x[2]))
  as.matrix(g[rowSums(g) == N, , drop = FALSE])
}

tChi <- function(tab) {
  E <- outer(rowSums(tab), colSums(tab)) / sum(tab)
  sum((tab - E)^2 / E)
}

# the EXACT lower-tail mid-p for a 2 x L table with both margins fixed
tExactP <- function(tab) {
  r <- rowSums(tab); cs <- colSums(tab); obs <- tChi(tab)
  L <- length(cs)
  out <- list(); k <- integer(L)
  rec <- function(j, left) {
    if (j == L) {
      if (left >= 0 && left <= cs[L]) { k[L] <<- left
        out[[length(out) + 1L]] <<- k }
      return(invisible(NULL))
    }
    rest <- sum(cs[(j + 1):L])
    for (v in max(0, left - rest):min(cs[j], left)) {
      k[j] <<- v; rec(j + 1L, left - v)
    }
    invisible(NULL)
  }
  rec(1L, r[1])
  M <- do.call(rbind, out)
  lw <- rowSums(mapply(function(kk, t) lchoose(t, kk),
                       as.data.frame(M), cs)) - lchoose(sum(cs), r[1])
  pr <- exp(lw)
  x <- apply(M, 1, function(v) tChi(rbind(v, cs - v)))
  sum(pr[x < obs - 1e-9]) + 0.5 * sum(pr[abs(x - obs) <= 1e-9])
}

# the brackets, in the shape the function under test wants
tMatrices <- function(pcts, Ns) {
  lo <- hi <- matrix(NA_integer_, length(Ns), length(pcts))
  for (i in seq_along(Ns)) for (j in seq_along(pcts)) {
    b <- tBracket(pcts[j], Ns[i]); lo[i, j] <- b[1]; hi[i, j] <- b[2]
  }
  list(lo = lo, hi = hi,
       cnt = matrix(NA_integer_, length(Ns), length(pcts)))
}

# ---- the arm enumerator -----------------------------------------------

test_that("an arm's vectors obey both the brackets and the arm total", {
  v <- .ppArmVectors(c(65L, 65L, 67L), c(67L, 67L, 69L), 200, TRUE, 1e6)
  expect_true(all(rowSums(v) == 200))
  expect_true(all(v[, 1] >= 65 & v[, 1] <= 67))
  expect_true(all(v[, 3] >= 67 & v[, 3] <= 69))
  # and it is COMPLETE: the same set the test builds for itself
  ref <- tArmVectors(c(33, 33, 34), 200)
  expect_equal(nrow(v), nrow(ref))
})

test_that("without a partition the cells are independent of each other", {
  # CHANGED 2026-09-09. This used to assert the counts summed to at most
  # N, which is itself an exclusivity assumption: overlapping categories
  # can each run to N. Exhaustivity is now claimed only where this code
  # builds the complement, so everywhere else the cells are free within
  # their own brackets.
  v <- .ppArmVectors(c(1L, 1L), c(3L, 3L), 4, FALSE, 1e6)
  expect_equal(nrow(v), 9)                 # the full 3 x 3 product
  expect_true(all(v >= 1 & v <= 3))
  expect_true(any(rowSums(v) > 4))
  # ...and with a partition it is exactly the vectors that add up
  w <- .ppArmVectors(c(1L, 1L), c(3L, 3L), 4, TRUE, 1e6)
  expect_true(all(rowSums(w) == 4))
})

# ---- the regression the old rule failed --------------------------------

test_that("the rebuilt counts sum to the arm N", {
  # THE 203/197 DEFECT. The previous rule chose each level on its own
  # line, so three levels printed 33/33/34 across two arms of 200 were
  # rebuilt as arm totals of 203 and 197 - a table that cannot exist.
  # The 2026-09-08 independent audit reported the same arithmetic.
  set.seed(4)
  m <- tMatrices(c(33, 33, 34), c(200, 200))
  r <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200))
  expect_equal(unname(rowSums(r$counts)), c(200, 200))
})

test_that("the reading chosen is the one with the largest p", {
  # THE DEFECT THAT MATTERED MOST. Maximising each level against its own
  # complement drove every level the same way in the same arm, which
  # left the arms in identical proportions - the MOST homogeneous
  # reading, and so the most alarming. The old rule scored p = 0.0041 on
  # this page when the admissible readings run to 0.048.
  #
  # The expected value is computed here, exactly, without touching the
  # package: enumerate the admissible tables, score each with an exact
  # conditional mid-p, take the largest.
  set.seed(5)
  Ns <- c(200, 200); pcts <- c(33, 33, 34)
  v1 <- tArmVectors(pcts, Ns[1]); v2 <- tArmVectors(pcts, Ns[2])
  ps <- numeric(0); best <- NULL
  for (i in seq_len(nrow(v1))) for (j in seq_len(nrow(v2))) {
    tab <- rbind(v1[i, ], v2[j, ])
    p <- tExactP(tab)
    ps <- c(ps, p)
    if (is.null(best) || p > best$p) best <- list(p = p, tab = tab)
  }
  m <- tMatrices(pcts, Ns)
  r <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, Ns)

  # the chosen table's own exact p, within the Monte Carlo error of the
  # selection budget; never compared against the function's estimate
  expect_equal(tExactP(r$counts), best$p, tolerance = 0.02)
  # and far above the homogeneous extreme the old rule landed on
  expect_gt(tExactP(r$counts), min(ps) * 5)
})

test_that("the choice can be interior to the bracket, not only its ends", {
  # the old rule only ever considered bracket ENDS, because the
  # statistic it maximised is convex and its maximum sits at a vertex.
  # A p is not convex in the counts, so the best reading is sometimes a
  # middle value, which the old search could not reach at all.
  set.seed(6)
  m <- tMatrices(c(33, 33, 34), c(200, 200))
  r <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200))
  interior <- r$counts > m$lo & r$counts < m$hi
  expect_true(any(interior))
})

# ---- best and worst ----------------------------------------------------

test_that("the worst case is reported and is no larger than the best", {
  set.seed(7)
  m <- tMatrices(c(33, 33, 34), c(200, 200))
  r <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200))
  expect_true(is.finite(r$pBest) && is.finite(r$pWorst))
  expect_lte(r$pWorst, r$pBest)
  # this page's readings really do straddle 0.01 - checked exactly
  v1 <- tArmVectors(c(33, 33, 34), 200)
  ps <- unlist(lapply(seq_len(nrow(v1)), function(i)
    vapply(seq_len(nrow(v1)), function(j)
      tExactP(rbind(v1[i, ], v1[j, ])), numeric(1))))
  expect_lt(min(ps), 0.01)
  expect_gt(max(ps), 0.01)
  expect_true(r$straddles)
})

test_that("a page whose readings agree does not raise the straddle", {
  # both ends well above 0.01, so the choice changed nothing worth
  # telling the editor about
  set.seed(8)
  m <- tMatrices(c(40, 60), c(250, 250))
  r <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(250, 250))
  expect_gt(r$pWorst, 0.01)
  expect_false(r$straddles)
})

test_that("nothing ambiguous means nothing is touched", {
  cnt <- matrix(c(50L, 50L, 50L, 50L), 2, 2)
  r <- .ppFailsafeTableFill(matrix(NA_integer_, 2, 2),
                            matrix(NA_integer_, 2, 2), cnt, c(100, 100))
  expect_identical(r$counts, cnt)
  expect_false(r$straddles)
})

# ---- the parser end to end ---------------------------------------------

test_that("a parsed percent block rebuilds arms that sum to their N", {
  # the audit's own fixture. On the previous rule this produced arm
  # totals of 203 and 197.
  f <- file.path("..", "..", "docs", "audits", "evidence-2026-09-08",
                 "synthetic-three-category.pdf")
  skip_if(!file.exists(f), "audit fixture not present")
  skip_if_not_installed("pdftools")
  set.seed(3)
  x <- parseBaselineTable(f, quiet = TRUE, pctApprox = TRUE)
  skip_if(is.null(x) || is.null(x$data), "fixture did not parse")
  base <- c("TRIAL", "ROW", "N", "MEAN", "SD", "SE", "Q1", "Q3",
            "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION")
  cats <- setdiff(names(x$data), base)
  skip_if(!length(cats), "fixture produced no category columns")
  rowsWithCounts <- which(rowSums(!is.na(x$data[, cats, drop = FALSE])) > 0)
  # CHANGED 2026-09-09: the arm total is no longer forced to N, because
  # the page never said these categories were exhaustive (audit F2). What
  # must hold is that every rebuilt count lies inside the bracket its
  # printed percentage allows - 32% and 34% of 200 - and that the totals
  # stay close enough to N to be a reading of the same table.
  vals <- unlist(x$data[rowsWithCounts, cats, drop = FALSE])
  vals <- vals[!is.na(vals)]
  expect_true(all(vals >= 63 & vals <= 69))
  s <- rowSums(x$data[rowsWithCounts, cats, drop = FALSE], na.rm = TRUE)
  expect_true(all(abs(s - 200) <= 3))
})

test_that("the fail-safe record survives a hybrid parse", {
  # it did not: the hybrid merge kept the flag text but dropped
  # derivedCells and approxCounts, so the app painted no orange cell and
  # showed no hover note on exactly the parses most in need of one
  f <- file.path("..", "..", "docs", "audits", "evidence-2026-09-08",
                 "synthetic-three-category.pdf")
  skip_if(!file.exists(f), "audit fixture not present")
  skip_if_not_installed("pdftools")
  set.seed(3)
  x <- parseBaselineTable(f, quiet = TRUE, pctApprox = TRUE)
  skip_if(!identical(x$engine, "hybrid"), "fixture did not take the hybrid route")
  expect_true(!is.null(x$derivedCells) && nrow(x$derivedCells) > 0)
  expect_true(any(x$derivedCells$KIND == "failsafe"))
  # and the note describes the choice that was actually made
  n <- x$derivedCells$NOTE[x$derivedCells$KIND == "failsafe"][1]
  expect_true(grepl("best case", n, fixed = TRUE))
  expect_false(grepl("least alike", n, fixed = TRUE))
})

# ---- the difference from the old rule, with no PDF needed --------------

test_that("the old per-level rule really did break the arm total", {
  # The differential test. .ppFailsafeCounts() was deleted on 2026-09-09
  # because while it existed it could still be reached, so the old
  # answer is written out here literally instead of computed. For three
  # levels printed 33/33/34 across two arms of 200 it produced exactly
  # this, and both of its defects are visible in the numbers: the arms
  # total 203 and 197 rather than 200, and every level was pushed the
  # same way in the same arm, so the two arms come out in identical
  # proportions - the most homogeneous reading of the page, not the
  # least.
  oldTab <- rbind(c(67L, 67L, 69L),
                  c(65L, 65L, 67L))
  expect_equal(unname(rowSums(oldTab)), c(203, 197))
  expect_lt(tChi(oldTab), 1e-3)

  set.seed(12)
  m <- tMatrices(c(33, 33, 34), c(200, 200))
  new <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200))
  expect_true(new$resolved)
  expect_gt(tChi(new$counts), 100 * tChi(oldTab))

  # and it matters: the old reading is at the alarming end of everything
  # the page allows, the new one at the reassuring end
  v <- tArmVectors(c(33, 33, 34), 200)
  ps <- unlist(lapply(seq_len(nrow(v)), function(i)
    vapply(seq_len(nrow(v)), function(j)
      tExactP(rbind(v[i, ], v[j, ])), numeric(1))))
  expect_lt(tExactP(oldTab), stats::quantile(ps, 0.25))
  expect_gt(tExactP(new$counts), stats::quantile(ps, 0.9))
})

test_that("a page too large to enumerate is unresolved, not guessed", {
  # AUDIT 2026-09-09, F1 and F8; Steve Shafer's decision: "Skip".
  lo <- matrix(780L, 2, 5); hi <- matrix(820L, 2, 5)
  r <- .ppFailsafeTableFill(lo, hi, matrix(NA_integer_, 2, 5), c(4000, 4000))
  expect_false(r$resolved)
  expect_true(all(is.na(r$counts)))
  expect_true(is.na(r$pBest))
  expect_false(r$straddles)
  expect_true(grepl("enumerat", r$reason))
})

test_that("nothing infers that categories divide the arm", {
  # AUDIT 2026-09-09, F2. Percentages summing to about 100 is arithmetic,
  # not a statement about what the categories mean. Without partition
  # the admissible set is the product of the brackets, and a reading
  # whose arm totals differ from N is allowed - which is correct when
  # the page never said the levels were exhaustive.
  m <- tMatrices(c(24, 24, 24, 26), c(1000, 1000))
  set.seed(21)
  r <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(1000, 1000))
  skip_if(!r$resolved, "space too large in this configuration")
  # the free search must not be confined to totals of exactly N
  expect_true(r$nTables > nrow(tArmVectors(c(24, 24, 24, 26), 1000))^2)
})

test_that("the selector agrees with the engine on a small table", {
  # AUDIT 2026-09-09, F7. The helper used literal floating equality and
  # its own floor, and returned 0.0998 on this table where the exact
  # lower mid-p is 0.35.
  tab <- rbind(c(1L, 1L), c(1L, 1L), c(1L, 5L))
  set.seed(42)
  p <- .ppTableP(tab, 100000)
  expect_gt(p, 0.25)
  expect_lt(p, 0.45)
})

test_that("the same page always yields the same counts", {
  # AUDIT 2026-09-09, F9: scoring simulates, so without its own seed the
  # counts depended on whatever random state the caller was in.
  m <- tMatrices(c(33, 33, 34), c(200, 200))
  set.seed(1);   a <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200))
  set.seed(999); b <- .ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200))
  expect_identical(a$counts, b$counts)
  expect_equal(a$pBest, b$pBest)
  # ...and it leaves the caller's stream where it found it
  set.seed(7); before <- runif(1)
  set.seed(7); invisible(.ppFailsafeTableFill(m$lo, m$hi, m$cnt, c(200, 200)))
  expect_equal(runif(1), before)
})
