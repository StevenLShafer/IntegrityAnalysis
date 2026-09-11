# Adjudication of the third full-pass independent statistical audit of
# 2026-09-11 (docs/audits/2026-09-11-full-independent-statistical-audit-chatgpt.md),
# finding F1 (numerical P2, the false-positive direction): the shared
# null-law key sorted each margin vector (the final-brief F1 fix, #297)
# but kept the two vectors in order, so TRANSPOSING one categorical table
# - the extreme variable's (0, 100)/(2, 98) read as (0, 2)/(100, 98), arm
# totals 2 and 198 where every other variable's are 100 and 100 - gave it
# a mapping of its own beside eight rows of the very same fixed-margin law
# (the law and the Pearson statistic are symmetric in the two margins),
# and the trial's genuine ties were split again: nine such rows read
# 0.003285 at seed 42 where the exact trial mid-p is 0.011146 (above the
# screen's 0.01), and fourteen read 0.00013 (0.000022-0.00031) against an
# exact 0.000519, outside the displayed interval.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-11, with the fix in R/P_Calc.R (.iaCategoryKey(): the key is the
# UNORDERED pair of the two sorted margin vectors). The fixtures are the
# auditor's own (evidence-2026-09-11-full/transpose-checks.R and the
# fixture-transpose-J9/J14-extreme-s42.csv files: J binary variables of
# (1, 99)/(1, 99), one extreme (0, 100)/(2, 98), the extreme one
# transposed), through the path the report names - the CSV through
# .apiReadUpload() and .apiAnalyze() (the real /analyze request is in
# test-api-service.R) - judged against the exact enumeration the report
# gives, q^J + J(1-q)q^(J-1)/2 with q = 100/199, and checked to FAIL on
# 6db32ee (0.003285 and the interval miss).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# the auditor's fixture: J binary variables, `bad` the extreme one,
# `transposed` the ones whose 2x2 table is transposed (arm 1 becomes the
# YES column, arm 2 the NO column)
auditFixture <- function(J, bad, transposed = integer()) {
  d <- data.frame(TRIAL = "T", ROW = rep(sprintf("V%02d", seq_len(J)), each = 2),
                  N = NA_real_, MEAN = NA_real_, SD = NA_real_, YES = 1, NO = 99,
                  stringsAsFactors = FALSE)
  ii <- (bad - 1) * 2 + 1:2; d$YES[ii] <- c(0, 2); d$NO[ii] <- c(100, 98)
  for (j in transposed) {
    ii <- (j - 1) * 2 + 1:2
    tab <- t(cbind(d$YES[ii], d$NO[ii]))
    d$YES[ii] <- tab[, 1]; d$NO[ii] <- tab[, 2]
  }
  d
}
exactTrial <- function(J) { q <- 100 / 199; q^J + 0.5 * J * (1 - q) * q^(J - 1) }
runCsv <- function(d, seed = 42) {
  f <- tempfile(fileext = ".csv"); utils::write.csv(d, f, row.names = FALSE)
  r <- .apiReadUpload(f, basename(f)); expect_true(isTRUE(r$ok))
  a <- shiny::isolate(.apiAnalyze(r$data, seed = seed)); expect_true(isTRUE(a$ok))
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", ][1, ]
  list(p = suppressWarnings(as.numeric(as.character(s$P))), ci = as.character(s$CI95),
       M = as.numeric(a$results$M[!is.na(a$results$KIND) & a$results$KIND == "variable"][1]))
}

test_that("the fixture is the auditor's: the transposed extreme row has arm totals 2 and 198", {
  d <- auditFixture(9L, 3L, transposed = 3L)
  # the auditor's CSV lines: "V03",NA,NA,NA,0,2 and "V03",NA,NA,NA,100,98
  expect_identical(d$YES[5:6], c(0, 100)); expect_identical(d$NO[5:6], c(2, 98))
  expect_identical(d$YES[5:6] + d$NO[5:6], c(2, 198))      # arm totals 2 and 198
  expect_identical(c(sum(d$YES[5:6]), sum(d$NO[5:6])), c(100, 100))   # category totals 100 and 100
  b <- auditFixture(9L, 3L)                                # the baseline: arm totals 100 and 100
  expect_identical(b$YES[5:6] + b$NO[5:6], c(100, 100))
})

test_that("transposing the extreme variable's table leaves the trial p where the exact value is (audit 2026-09-11 full, F1, nine rows)", {
  base <- runCsv(auditFixture(9L, 3L))
  tr <- runCsv(auditFixture(9L, 3L, transposed = 3L))
  ex <- exactTrial(9L)                                     # 0.011145949...
  expect_equal(base$M, 1e5); expect_equal(tr$M, 1e5)
  expect_gt(base$p, 0.008); expect_lt(base$p, 0.015)       # 0.01133 at seed 42, already right
  # the transposed table now reads the same law: near the exact value,
  # not a third of it (0.003285 on 6db32ee) - and on the same side of 0.01
  expect_gt(tr$p, 0.008); expect_lt(tr$p, 0.015)
  expect_lt(abs(tr$p - base$p), 0.003)
  expect_lt(abs(tr$p - ex), 0.003)
})

test_that("fourteen rows: the exact value sits inside the displayed interval after transposition (audit 2026-09-11 full, F1)", {
  tr <- runCsv(auditFixture(14L, 7L, transposed = 7L))
  ex <- exactTrial(14L)                                    # 0.000519194...
  expect_equal(tr$M, 1e5)
  ci <- as.numeric(strsplit(tr$ci, " to ")[[1]])
  expect_length(ci, 2L)                                    # a displayed interval: the trial p is below 0.001
  expect_gte(ex, ci[1]); expect_lte(ex, ci[2])             # 0.000022-0.00031 on 6db32ee, exact outside
  expect_gt(tr$p, 0.0003)                                  # 0.00013 on 6db32ee
})

test_that("transposing an ORDINARY variable, or every variable, is likewise inert", {
  base <- runCsv(auditFixture(9L, 3L))
  one  <- runCsv(auditFixture(9L, 3L, transposed = 1L))    # (1,1)/(99,99): totals 2 and 198 too
  all9 <- runCsv(auditFixture(9L, 3L, transposed = 1:9))
  expect_lt(abs(one$p - base$p), 0.003)
  expect_lt(abs(all9$p - base$p), 0.003)
})

test_that("the categorical key is the unordered pair of sorted margins: transposes and permutations share it, other laws do not", {
  tab <- matrix(c(0, 2, 100, 98), 2)                       # rows = arms, cols = categories
  k <- .iaCategoryKey(tab)
  expect_identical(.iaCategoryKey(t(tab)), k)              # transposed
  expect_identical(.iaCategoryKey(tab[2:1, ]), k)          # arms permuted
  expect_identical(.iaCategoryKey(tab[, 2:1]), k)          # categories permuted
  expect_identical(.iaCategoryKey(t(tab)[2:1, 2:1]), k)    # both, then transposed
  # a 2x3 table and its 3x2 transpose
  t3 <- matrix(c(1, 2, 3, 4, 5, 6), 2)
  expect_identical(.iaCategoryKey(t(t3)), .iaCategoryKey(t3))
  expect_identical(.iaCategoryKey(t3[, c(3, 1, 2)]), .iaCategoryKey(t3))
  # the ordinary rows of the fixture, (1,99)/(1,99), ARE the same law
  # (margins (100,100) and (2,198)); (2,98)/(2,98) is not (cols (4,196))
  expect_identical(.iaCategoryKey(matrix(c(1, 1, 99, 99), 2)), k)
  expect_false(identical(.iaCategoryKey(matrix(c(2, 2, 98, 98), 2)), k))
  expect_false(identical(.iaCategoryKey(matrix(c(0, 2, 100, 98, 0, 0), 2)), k))   # a third, empty category is a column of its own
})
