# Adjudication of the fourth full-pass independent statistical audit of
# 2026-09-11 (docs/audits/2026-09-11-full2-independent-statistical-audit-chatgpt.md),
# finding F1 (numerical P2, both directions): the continuous and median
# null-law keys listed each arm's MEAN, but a simulate closure never reads
# an arm's mean - the common location is drawn about the N-weighted
# pooled mean and the statistic measures the replicate's own arms about
# their own centre - so two rows printed (0, 0) and (-1, 1) with the same
# N, SD and precision are ONE law with two keys, and their genuine trial
# ties were split: five such continuous rows read 0.008575 at seed 42
# where the same draws mapped through one law give 0.010285 (the other
# side of the screen's 0.01; an independent reference 0.0107); seven
# median rows read 0.01074 at seed 43 for a same-draw 0.009825 (reference
# 0.0096). The auditor's same-draw trace: 342 genuine ties lost in the
# accusing direction (continuous), 184 counted as strictly more
# homogeneous (median).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-11, with the fix in R/P_Calc.R (.iaNullKey(): the key carries
# the pooled mean and, per arm, the size, dispersion, precisions and - for
# a continuous row - the simulation route; never the individual means).
# The fixtures are the auditor's (evidence-2026-09-11-full2/
# fixture-symmetric-refined-continuous-J5-s42.csv and
# fixture-symmetric-refined-median-J7-s43.csv, written here line for line),
# through the path the report names - the CSV through .apiReadUpload() and
# .apiAnalyze() (the real /analyze request is in test-api-service.R) -
# judged against the auditor's same-draw common-law values and checked to
# FAIL on 7c6583f (0.008575 and 0.01074).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

contFixture <- function(J = 5L, apart = 3L) {
  d <- data.frame(TRIAL = "T", ROW = rep(sprintf("V%02d", seq_len(J)), each = 2),
                  N = 30, MEAN = 0, SD = 6, ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0,
                  stringsAsFactors = FALSE)
  ii <- (apart - 1) * 2 + 1:2; d$MEAN[ii] <- c(-1, 1)
  d
}
medFixture <- function(J = 7L, apart = 3L) {
  d <- data.frame(TRIAL = "T", ROW = rep(sprintf("V%02d", seq_len(J)), each = 2),
                  N = 9, MEAN = 0, SD = NA_real_, ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0,
                  Q1 = -1, Q3 = 1, stringsAsFactors = FALSE)
  ii <- (apart - 1) * 2 + 1:2; d$MEAN[ii] <- c(-1, 1)
  d
}
runCsv <- function(d, seed) {
  f <- tempfile(fileext = ".csv"); utils::write.csv(d, f, row.names = FALSE)
  r <- .apiReadUpload(f, basename(f)); expect_true(isTRUE(r$ok))
  a <- shiny::isolate(.apiAnalyze(r$data, seed = seed)); expect_true(isTRUE(a$ok))
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", ][1, ]
  list(p = suppressWarnings(as.numeric(as.character(s$P))), ci = as.character(s$CI95),
       M = as.numeric(a$results$M[!is.na(a$results$KIND) & a$results$KIND == "variable"][1]))
}

test_that("five continuous rows with one pooled mean read one law: the trial p crosses back over 0.01 (audit 2026-09-11 full2, F1)", {
  x <- runCsv(contFixture(), 42)
  # on 7c6583f the trial read 0.008575 at 100,000 replicates; mapped
  # through one law it sits above 0.01 (the auditor's integer-event
  # count on those draws: 0.010285; an independent two-million-replicate
  # reference 0.0107, bounds 0.0105-0.0110), so the staging no longer
  # escalates past 10,000 and the reported value is the 10,000-replicate
  # one: 0.0116 at seed 42, within Monte Carlo noise (SE about 0.001) of
  # the reference - and on the other side of 0.01
  expect_equal(x$M, 1e4)                                   # 1e5 on 7c6583f: it escalated
  expect_gt(x$p, 0.01); expect_lt(x$p, 0.0135)
  expect_lt(abs(x$p - 0.0107), 0.0025)
})

test_that("seven median rows with one pooled median read one law: the trial p crosses back under 0.01 (audit 2026-09-11 full2, F1)", {
  x <- runCsv(medFixture(), 43)
  expect_equal(x$M, 1e5)
  # 0.009825 on the same draws through one law; 0.01074 on 7c6583f
  expect_lt(x$p, 0.01); expect_gt(x$p, 0.0085)
  expect_lt(abs(x$p - 0.009825), 0.0008)
})

test_that("which row carries the apart arms is immaterial, and the arms' order is too", {
  a <- runCsv(contFixture(apart = 1L), 42)
  b <- runCsv(contFixture(apart = 5L), 42)
  expect_lt(abs(a$p - b$p), 0.002)
  expect_gt(a$p, 0.01); expect_gt(b$p, 0.01)
  d <- contFixture(); d$MEAN[5:6] <- c(1, -1)               # V03's arms listed the other way round
  c2 <- runCsv(d, 42)
  expect_gt(c2$p, 0.01); expect_lt(abs(c2$p - a$p), 0.002)
})

test_that("the key is the simulation's inputs: pooled mean and the arms' sizes, dispersions, precisions and route", {
  rows <- function(mean, n = c(30, 30), sd = c(6, 6))
    data.frame(N = n, MEAN = mean, SD = sd, ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0)
  k0 <- .iaNullKey("continuous", rows(c(0, 0)), c(FALSE, FALSE))
  expect_identical(.iaNullKey("continuous", rows(c(-1, 1)), c(FALSE, FALSE)), k0)     # the audit's pair
  expect_identical(.iaNullKey("continuous", rows(c(5, -5)), c(FALSE, FALSE)), k0)
  expect_false(identical(.iaNullKey("continuous", rows(c(0, 1)), c(FALSE, FALSE)), k0))   # pooled mean 0.5: another law
  expect_false(identical(.iaNullKey("continuous", rows(c(0, 0), sd = c(6, 7)), c(FALSE, FALSE)), k0))
  expect_false(identical(.iaNullKey("continuous", rows(c(0, 0), n = c(30, 31)), c(FALSE, FALSE)), k0))
  # equal-sized arms exchanging their SDs: the same multiset, the same law
  expect_identical(.iaNullKey("continuous", rows(c(0, 0), sd = c(5, 7)), c(FALSE, FALSE)),
                   .iaNullKey("continuous", rows(c(0, 0), sd = c(7, 5)), c(FALSE, FALSE)))
  # unequal arms exchanging their SDs: (30, 5)/(40, 7) is not (30, 7)/(40, 5)
  expect_false(identical(.iaNullKey("continuous", rows(c(0, 0), n = c(30, 40), sd = c(5, 7)), c(FALSE, FALSE)),
                         .iaNullKey("continuous", rows(c(0, 0), n = c(30, 40), sd = c(7, 5)), c(FALSE, FALSE))))
  # the same pooled mean with a different weighting is a different law only if the pooled value differs
  expect_identical(.iaNullKey("continuous", rows(c(2, -2), n = c(10, 10)), c(FALSE, FALSE)),
                   .iaNullKey("continuous", rows(c(0, 0), n = c(10, 10)), c(FALSE, FALSE)))
  # the route is part of the law: an arm drawn directly is another simulation
  expect_false(identical(.iaNullKey("continuous", rows(c(0, 0)), c(TRUE, FALSE)), k0))
  # arms in another order: the same key
  expect_identical(.iaNullKey("continuous", rows(c(0, 0), n = c(30, 40), sd = c(5, 7))[2:1, ], c(FALSE, FALSE)),
                   .iaNullKey("continuous", rows(c(0, 0), n = c(30, 40), sd = c(5, 7)), c(FALSE, FALSE)))
  # median rows: the same rules on the quartiles
  mrows <- function(med, q1 = c(-1, -1), q3 = c(1, 1))
    data.frame(N = c(9, 9), MEAN = med, Q1 = q1, Q3 = q3, SD = NA_real_, ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0)
  expect_identical(.iaNullKey("median", mrows(c(-1, 1))), .iaNullKey("median", mrows(c(0, 0))))
  expect_false(identical(.iaNullKey("median", mrows(c(0, 1))), .iaNullKey("median", mrows(c(0, 0)))))
  expect_identical(.iaNullKey("median", mrows(c(0, 0), q1 = c(-2, -1), q3 = c(1, 2))),
                   .iaNullKey("median", mrows(c(0, 0), q1 = c(-1, -2), q3 = c(2, 1))))
  expect_false(identical(.iaNullKey("median", mrows(c(0, 0), q3 = c(1, 2))), .iaNullKey("median", mrows(c(0, 0)))))
})

test_that("a row with a law of its own still runs through its own draws: the distinct-law fixture is deterministic and unpooled", {
  d <- data.frame(TRIAL = "T", ROW = c("A", "A", "B", "B", "C", "C"),
                  N = c(30, 30, 30, 30, 40, 40), MEAN = c(50.1, 50.3, 60.2, 60.2, 50.1, 50.3),
                  SD = c(10, 10, 10, 10, 12, 12), stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  set.seed(7); dqrng::dqset.seed(7)
  x1 <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  set.seed(7); dqrng::dqset.seed(7)
  x2 <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  expect_identical(x1$P, x2$P)
  expect_identical(length(unique(x1$ROW[x1$KIND %in% "variable"])), 3L)
})
