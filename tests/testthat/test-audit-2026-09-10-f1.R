# Adjudication of the 2026-09-10 independent statistical audit, finding F1
# (docs/audits/2026-09-10-independent-statistical-audit-chatgpt.md).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/P_Calc.R (.iaZeroSnapTol() takes the
# printed step only). Per the standing rule in AGENTS.md the defect is
# reproduced THROUGH THE PATH THE REPORT NAMES - CSV upload ->
# .apiReadUpload() -> .apiAnalyze() -> validateData() -> P_Calc(), seed
# 42, 100,000 replicates - and judged against the auditor's
# integer-distance reference on the same draws, not against a different
# tolerance constant. Checked to FAIL on 3ac3568 (trial p 0.00609).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

# The audit's six-line fixture, byte for byte the frame it wrote
# (evidence-2026-09-10/three-row-1e+07.csv): row X prints means 0 and
# 10,000,000, rows Y and Z print 0 and 0; arms of 100, SD 1, four
# printed decimals.
auditCsv <- function(delta = 1e7) {
  d <- data.frame(TRIAL = "Audit", ROW = rep(c("X", "Y", "Z"), each = 2),
                  N = 100, MEAN = c(0, delta, 0, 0, 0, 0), SD = 1,
                  ROUND_MEAN = 4, ROUND_OBSERVATION = 4, ROUND_DISPERSION = 3)
  f <- tempfile(fileext = ".csv")
  utils::write.csv(d, f, row.names = FALSE)
  f
}
summaryP <- function(a) {
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", , drop = FALSE]
  suppressWarnings(as.numeric(as.character(s$P[1])))
}

test_that("one very heterogeneous row no longer erases its own null (audit 2026-09-10 F1)", {
  f <- auditCsv(1e7)
  rd <- .apiReadUpload(f, "three-row.csv")
  expect_true(isTRUE(rd$ok))
  a <- shiny::isolate(.apiAnalyze(rd$data, seed = 42))
  expect_true(isTRUE(a$ok))
  # the auditor's reference on these very draws: 1,979 of 100,000
  # strictly beyond, no ties, p = 0.01979, conditional interval
  # 0.01894 to 0.02067; 3ac3568 read 0.00609 (609 beyond), an
  # accusing-direction crossing of 0.01 manufactured by the guard
  p <- summaryP(a)
  expect_true(is.finite(p))
  expect_gt(p, 0.0189)
  expect_lt(p, 0.0207)
  # the heterogeneous row itself is unaffected: its p sits at the ceiling
  x <- a$results[!is.na(a$results$ROW) & a$results$ROW == "X", , drop = FALSE]
  expect_equal(suppressWarnings(as.numeric(as.character(x$P[1]))), 0.9999)
  expect_equal(as.character(x$M[1]), "1e+05")
})

test_that("making a row MORE heterogeneous cannot lower the trial p through the snap", {
  # the audit's second construction: X printing 0 and 1,000 read 0.0196
  # on 3ac3568, and 0 and 10,000,000 read 0.00609 - the alarm was
  # caused by the guard, not by the data. Both now read the same, up to
  # the draws' own resolution.
  pOf <- function(delta) {
    rd <- .apiReadUpload(auditCsv(delta), "three-row.csv")
    summaryP(shiny::isolate(.apiAnalyze(rd$data, seed = 42)))
  }
  p1 <- pOf(1e3); p2 <- pOf(1e7)
  expect_gt(p1, 0.0189); expect_lt(p1, 0.0207)
  expect_gt(p2, 0.0189); expect_lt(p2, 0.0207)
})

test_that("the tolerance is the printed grid's alone - the observed arms cannot enter it", {
  # the audit's repair target: any residual guard must be bounded by the
  # arithmetic of the statistic and preserve distinct attainable values.
  # Four printed decimals: step 1e-4, tolerance 1e-20; the smallest
  # statistic two distinct readings on that grid can produce is at least
  # step^2 / 2 = 5e-9, eleven orders above it.
  expect_false("dd" %in% names(formals(.iaZeroSnapTol)))
  # as a ratio: testthat's tolerance is absolute this close to zero
  expect_equal(.iaZeroSnapTol(.iaMeanStep(4)) / 1e-20, 1)
  expect_lt(.iaZeroSnapTol(.iaMeanStep(4)) * 1e10, (1e-4)^2 / 2)
  # and the 3ac3568 quantity, for the record: 1e-12 * (1e7)^2 = 100
  expect_lt(.iaZeroSnapTol(.iaMeanStep(4)), 0.19)   # the null's whole range
})
