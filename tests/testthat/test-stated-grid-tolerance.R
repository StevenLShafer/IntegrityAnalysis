# test-stated-grid-tolerance.R - the stated-grid check's tolerance is the
# floating-point arithmetic's, not a share of the value, so an invalid
# precision declaration is refused at every measurement origin (ISSUES.md
# issue 168; outside statistical audit 2026-09-26, F2).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# audit's construction: three arms of N 40, median L, quartiles L - 0.5    #
# and L + 0.5, integer median and observation precision; quartile          #
# precision 1 (valid) against -5 (a grid of 100,000, invalid), at L = 0    #
# and L = 1e9. Reproduced through the upload reader and the analysis       #
# handler at seed 42.                                                      #
############################################################################
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that(".iaOnStatedGrid: the audit's cases, the earlier screens' cases, and the unresolvable grid", {
  # the audit: half a unit off a grid of 100,000 is off it at any origin
  expect_false(.iaOnStatedGrid(c(-0.5, 0.5), -5))
  expect_false(.iaOnStatedGrid(c(1e9 - 0.5, 1e9 + 0.5), -5))          # 27eaf9a: TRUE
  expect_true(.iaOnStatedGrid(c(1e9 - 0.5, 1e9 + 0.5), 1))            # the valid declaration
  expect_true(.iaOnStatedGrid(1e9, -5))                               # on the grid of 100,000
  # screen 1758's cases still hold
  expect_true(.iaOnStatedGrid(c(45, 55), c(0, 0)))
  expect_true(.iaOnStatedGrid(c(40, 60), c(-1, -1)))
  expect_false(.iaOnStatedGrid(c(45, 55), c(-1, -1)))
  expect_false(.iaOnStatedGrid(45, -20))
  expect_true(.iaOnStatedGrid(1e9 + 0.25, 2))                          # screen 1459's shape
  expect_true(.iaOnStatedGrid(c(NA, NaN), c(0, NA)))
  expect_true(.iaOnStatedGrid(0, -20))
  # ordinary printed values, whose binary representation is inexact
  expect_true(.iaOnStatedGrid(c(54.1, 0.3, 0.7, 9.2, 1.15), c(1, 1, 1, 1, 2)))
  expect_true(.iaOnStatedGrid(c(0.001, 123456.789), c(3, 3)))
  # a grid the arithmetic cannot resolve at that magnitude is not judged
  # here (one decimal at 1e15: the double's spacing there is 0.125); the
  # over-fine claim is the stated-precision notes' business (screen 2000)
  expect_true(.iaOnStatedGrid(1e15 + 0.1, 1))
  expect_true(.iaOnStatedGrid(1e15, -1))
  expect_false(.iaOnStatedGrid(1e15 + 50, -2))                         # a grid of 100 there IS judged (dust 14): off it
  # screen 2000's shape: a precision finer than the printed digits passes
  # here and is disclosed downstream, as adjudicated there
  expect_true(.iaOnStatedGrid(50, 15))
})

medianFixture <- function(L, decQ, name) {
  d <- data.frame(TRIAL = "T", ROW = "Time", N = 40, MEAN = L, SD = NA_real_,
                  Q1 = L - 0.5, Q3 = L + 0.5, ROUND_MEAN = 0, ROUND_DISPERSION = decQ,
                  ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  d <- d[rep(1, 3), ]
  f <- file.path(tempdir(), name)
  utils::write.csv(d, f, row.names = FALSE, na = "")
  f
}
runRow <- function(f) {
  rd <- .apiReadUpload(f, basename(f))
  expect_true(isTRUE(rd$ok), info = paste(rd$reasons, collapse = "; "))
  a <- shiny::isolate(.apiAnalyze(rd$data, seed = 42))
  v <- a$results[!is.na(a$results$KIND) & a$results$KIND == "variable", , drop = FALSE]
  list(P = as.character(v$P[1]), pnum = suppressWarnings(as.numeric(v$.PNUM[1])))
}

test_that("an invalid quartile precision is refused at a location of zero and of one billion alike; the valid one reads the same p at both (audit 2026-09-26, F2)", {
  v0 <- runRow(medianFixture(0,   1, "audit-0926-f2-valid-0.csv"))
  v9 <- runRow(medianFixture(1e9, 1, "audit-0926-f2-valid-1e9.csv"))
  expect_true(is.finite(v0$pnum)); expect_identical(v9$pnum, v0$pnum)
  i0 <- runRow(medianFixture(0,   -5, "audit-0926-f2-invalid-0.csv"))
  i9 <- runRow(medianFixture(1e9, -5, "audit-0926-f2-invalid-1e9.csv"))
  expect_true(is.na(i0$pnum)); expect_match(i0$P, "precision", ignore.case = TRUE)
  expect_true(is.na(i9$pnum)); expect_match(i9$P, "precision", ignore.case = TRUE)   # 27eaf9a: <0.0001
})
