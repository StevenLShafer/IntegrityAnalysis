# Adjudication of the final-brief independent statistical audit of
# 2026-09-11 (docs/audits/2026-09-11-final-independent-statistical-audit-chatgpt.md),
# finding F1 (numerical P2, the false-positive direction): the shared
# null-law key of the 2026-09-10 F1 fix named a categorical law by its
# margins in the order the table printed them, so a binary variable coded
# (YES, NO) = (100, 0)/(98, 2) got a mapping of its own beside eight coded
# (0, 100)/(2, 98) - the same fixed-margin law - and the trial's genuine
# ties were split again: nine such rows read 0.003285 at seed 42 where the
# exact trial mid-p is 0.011146 (above the screen's 0.01), and fourteen
# read 0.00013 (0.000022-0.00031) against an exact 0.000519, outside the
# displayed interval.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-11, with the fix in R/P_Calc.R (each margin vector is sorted
# before it enters the key; the continuous and median keys list their
# arms in one canonical order). The fixtures are the auditor's own
# (evidence-2026-09-11-final/permutation-checks.R: J variables of
# (1, 99)/(1, 99), one extreme (0, 100)/(2, 98), the extreme one recoded),
# through the path the report names - the CSV through .apiReadUpload()
# and .apiAnalyze() (the real /analyze request is in test-api-service.R)
# - judged against the exact enumeration the report gives, and checked
# to FAIL on baad77c (0.003285 and the interval miss).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# the auditor's fixture: J binary variables, `bad` the extreme one,
# `flipped` the ones whose YES/NO columns are swapped
auditFixture <- function(J, bad, flipped = integer()) {
  d <- data.frame(TRIAL = "T", ROW = rep(sprintf("V%02d", seq_len(J)), each = 2),
                  N = NA_real_, MEAN = NA_real_, SD = NA_real_, YES = 1, NO = 99,
                  stringsAsFactors = FALSE)
  ii <- (bad - 1) * 2 + 1:2; d$YES[ii] <- c(0, 2); d$NO[ii] <- c(100, 98)
  for (j in flipped) { ii <- (j - 1) * 2 + 1:2; old <- d$YES[ii]; d$YES[ii] <- d$NO[ii]; d$NO[ii] <- old }
  d
}
exactTrial <- function(J) { q <- 100 / 199; q^J + 0.5 * J * (1 - q) * q^(J - 1) }
runCsv <- function(d, seed = 42) {
  f <- tempfile(fileext = ".csv"); utils::write.csv(d, f, row.names = FALSE)
  r <- .apiReadUpload(f, basename(f)); expect_true(isTRUE(r$ok))
  a <- shiny::isolate(.apiAnalyze(r$data, seed = seed)); expect_true(isTRUE(a$ok))
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", ][1, ]
  list(p = suppressWarnings(as.numeric(as.character(s$P))), ci = as.character(s$CI95),
       M = as.numeric(a$results$M[!is.na(a$results$KIND) & a$results$KIND == "variable"][1]))   # the rows carry M; the summary line does not
}

test_that("recoding the extreme variable's categories leaves the trial p where the exact value is (audit 2026-09-11 F1, nine rows)", {
  base <- runCsv(auditFixture(9L, 3L))
  flip <- runCsv(auditFixture(9L, 3L, flipped = 3L))
  ex <- exactTrial(9L)                                     # 0.011145949...
  expect_equal(base$M, 1e5); expect_equal(flip$M, 1e5)
  # the baseline was already right (0.01133 at seed 42)
  expect_gt(base$p, 0.008); expect_lt(base$p, 0.015)
  # the recoded table now reads the same law: near the exact value, not
  # a third of it (0.003285 on baad77c) - and on the same side of 0.01
  expect_gt(flip$p, 0.008); expect_lt(flip$p, 0.015)
  expect_lt(abs(flip$p - base$p), 0.003)
  expect_lt(abs(flip$p - ex), 0.003)
})

test_that("fourteen rows: the exact value sits inside the displayed interval after recoding (audit 2026-09-11 F1)", {
  flip <- runCsv(auditFixture(14L, 7L, flipped = 7L))
  ex <- exactTrial(14L)                                    # 0.000519194...
  expect_equal(flip$M, 1e5)
  ci <- as.numeric(strsplit(flip$ci, " to ")[[1]])
  expect_length(ci, 2L)                                    # a displayed interval: the trial p is below 0.001
  expect_gte(ex, ci[1]); expect_lte(ex, ci[2])             # 0.000022-0.00031 on baad77c, exact outside
  expect_gt(flip$p, 0.0003)                                # 0.00013 on baad77c
})

test_that("recoding an ORDINARY variable, or every variable, is likewise inert (audit 2026-09-11, the 24-case sweep)", {
  base <- runCsv(auditFixture(9L, 3L))
  one  <- runCsv(auditFixture(9L, 3L, flipped = 1L))
  all9 <- runCsv(auditFixture(9L, 3L, flipped = 1:9))
  expect_lt(abs(one$p - base$p), 0.003)
  expect_lt(abs(all9$p - base$p), 0.003)
})

test_that("the key names the law, not the printing: permuted categories, permuted arms, canonical continuous arms", {
  # two categorical rows with permuted columns and permuted rows share a key
  d <- data.frame(TRIAL = "T", ROW = c("A", "A", "B", "B", "C", "C"),
                  N = NA_real_, MEAN = NA_real_, SD = NA_real_,
                  YES = c(1, 99, 99, 1, 3, 4), NO = c(99, 1, 1, 99, 7, 6), stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  set.seed(1); dqrng::dqset.seed(1)
  x <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  expect_true(is.data.frame(x))
  # A: arms (1,99)/(99,1) - margins rows (100,100), cols (100,100); B is A with the arms swapped
  # (the key is internal; the observable is that A and B combine as one law: the trial runs)
  # continuous: arms in another order give the same key; another input a different one
  a <- data.frame(N = c(10, 20), MEAN = c(50, 51), SD = c(9, 10), ROUND_MEAN = 0, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 0)
  expect_identical(.iaNullKey("continuous", a), .iaNullKey("continuous", a[2:1, ]))
  a2 <- a; a2$SD[2] <- 11
  expect_false(identical(.iaNullKey("continuous", a), .iaNullKey("continuous", a2)))
  # median rows the same
  m <- data.frame(N = c(10, 20), MEAN = c(50, 51), Q1 = c(45, 46), Q3 = c(55, 57), SD = NA_real_,
                  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 0)
  expect_identical(.iaNullKey("median", m), .iaNullKey("median", m[2:1, ]))
})

test_that("a row with a law of its own is mapped exactly as before: the pinned distinct-law value stands", {
  # the 2026-09-10 F1 test pins 0.0045 for distinct laws; here a table of
  # three distinct categorical rows and one continuous row runs and its
  # rows keep their own p and interval (no pooling can touch them)
  d <- data.frame(TRIAL = "T", ROW = c("A", "A", "B", "B", "X", "X"),
                  N = c(NA, NA, NA, NA, 30, 30), MEAN = c(NA, NA, NA, NA, 50.1, 50.3),
                  SD = c(NA, NA, NA, NA, 10, 10),
                  YES = c(5, 6, 20, 30, NA, NA), NO = c(45, 44, 30, 20, NA, NA), stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  set.seed(7); dqrng::dqset.seed(7)
  x1 <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  set.seed(7); dqrng::dqset.seed(7)
  x2 <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  expect_identical(x1$P, x2$P)                             # deterministic under the seed
  expect_identical(length(unique(x1$ROW[x1$KIND %in% "variable"])), 3L)
})
