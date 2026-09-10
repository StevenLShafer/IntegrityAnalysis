# Adjudication of security screen 2026-09-10-1523 (over the range #261-#265
# merged), finding F1 (HIGH): the shared-law score mapping of the full
# audit's F1 fix was quadratic in the rows sharing a law and held every
# row's draws for the stage, and every API gate admitted the table.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/P_Calc.R (sorted pool + two binary
# searches per row; only shared rows' draws held; .iaMaxPoolDraws refused
# before a draw). Reproduced through the path the report names - the
# engine on a trial of identical rows, timed - and checked to FAIL on
# d6496e0 (250 rows, two stages: 31.6 s there; 3.9 s on the engine
# before the shared mapping).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

identicalRows <- function(G) {
  data.frame(TRIAL = "T", ROW = rep(sprintf("V%04d", seq_len(G)), each = 2),
             N = 2, MEAN = c(50, 50), SD = 10, ROUND_MEAN = 0, ROUND_OBSERVATION = 0,
             ROUND_DISPERSION = 0, stringsAsFactors = FALSE)
}

test_that("the sorted-pool counts equal the bounded tie criterion, ties and near-ties included", {
  set.seed(1)
  # near-ties inside the tolerance (3e-11 of 1e-10) and clear non-ties
  # (5e-10); a pair sitting exactly AT the tolerance is decided by the
  # rounding of whichever expression computes it, in both functions
  x <- c(round(stats::rexp(2000), 2), 0, 0, 0, 1, 1, 1 + 3e-11, 1 - 3e-11, 1 + 5e-10)
  sp <- sort(x)
  for (obs in c(0, 1, 0.37, 2.5, 1 + 3e-11, max(x), max(x) + 1)) {
    a <- .iaTieCounts(x, obs); b <- .iaPoolCounts(sp, obs)
    expect_equal(unname(b[["kLess"]]), unname(a[["kLess"]]), info = as.character(obs))
    expect_equal(unname(b[["kEq"]]), unname(a[["kEq"]]), info = as.character(obs))
  }
})

test_that("250 rows sharing one law: the shared mapping is linear, not quadratic (screen 1523 F1)", {
  d <- identicalRows(250L)
  v <- shiny::isolate(validateData(d))
  set.seed(42); dqrng::dqset.seed(42)
  elapsed <- system.time(x <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 10000)))[["elapsed"]]
  # d6496e0: 31.6 s for this trial; the engine before the shared mapping: 3.9 s
  expect_lt(elapsed, 20)
  expect_true(is.finite(suppressWarnings(as.numeric(as.character(x$P[x$KIND %in% "summary"][1])))))
})

test_that("a trial whose shared rows would need more than the pool ceiling is refused before a draw", {
  G <- ceiling(.iaMaxPoolDraws / 100000) + 1L                  # one row past the ceiling at m = 100,000
  d <- identicalRows(G)
  v <- shiny::isolate(validateData(d))
  elapsed <- system.time(
    expect_error(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 100000)),
                 "share a null law")
  )[["elapsed"]]
  expect_lt(elapsed, 5)                                        # refused before anything is simulated
  # and the same trial at a ceiling of 1,000 replicates is within the bound and runs
  set.seed(42); dqrng::dqset.seed(42)
  x <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  expect_true(nrow(x) > G)
})

test_that("the API refuses it at the analysis stage with the reason, not a 500 and not a hang", {
  G <- ceiling(.iaMaxPoolDraws / 100000) + 1L
  d <- identicalRows(G)
  a <- shiny::isolate(.apiAnalyze(d, seed = 42))
  expect_false(isTRUE(a$ok))
  expect_equal(a$stage, "analysis")
  expect_match(a$issues$note[1], "share a null law")
})
