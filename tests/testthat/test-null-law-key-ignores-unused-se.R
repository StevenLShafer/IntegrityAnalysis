# test-null-law-key-ignores-unused-se.R - a redundant SE column, which no
# simulate closure reads, must not split a null law (ISSUES.md issue 167;
# outside statistical audit 2026-09-26, F1).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# audit's construction: five continuous variables of two arms (N 30, SD 6, #
# integer means, one-decimal SD), one of them printed (-1, +1) and the     #
# rest (0, 0) - one law; then SE = 6 / sqrt(30) supplied on that one row.  #
# Reproduced THROUGH THE ROUTE THE REPORT NAMES: the CSVs through the      #
# upload reader and the API's analysis handler at seed 42, and judged      #
# against the audit's independent two-million-replicate reference          #
# (0.01073, simultaneous 95% bounds 0.01058-0.01088), not against the fix. #
############################################################################
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

fixture <- function(withSE, name) {
  vars <- sprintf("V%02d", 1:5)
  d <- data.frame(TRIAL = "T", ROW = rep(vars, each = 2), N = 30, MEAN = 0, SD = 6,
                  ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0,
                  stringsAsFactors = FALSE)
  d$MEAN[d$ROW == "V03"] <- c(-1, 1)
  if (withSE) { d$SE <- NA_real_; d$SE[d$ROW == "V03"] <- 6 / sqrt(30) }
  f <- file.path(tempdir(), name)
  utils::write.csv(d, f, row.names = FALSE, na = "")
  f
}
runP <- function(f) {
  rd <- .apiReadUpload(f, basename(f))
  expect_true(isTRUE(rd$ok), info = paste(rd$reasons, collapse = "; "))
  a <- shiny::isolate(.apiAnalyze(rd$data, seed = 42))
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", , drop = FALSE]
  list(p = suppressWarnings(as.numeric(s$.PNUM[1])),
       rows = a$results$.PNUM[!is.na(a$results$KIND) & a$results$KIND == "variable"],
       M = unique(a$results$M[!is.na(a$results$KIND) & a$results$KIND == "variable"]))
}
cpInterval <- function(p, m, level = 0.999) {
  k <- round(p * m); a <- (1 - level) / 2
  c(stats::qbeta(a, k, m - k + 1), stats::qbeta(1 - a, k + 1, m - k))
}

test_that("the null-law key is the inputs the simulation reads: SE is not among them", {
  rows <- data.frame(N = c(30, 30), MEAN = c(-1, 1), SD = c(6, 6),
                     ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0)
  withSE <- rows; withSE$SE <- 6 / sqrt(30)
  blankSE <- rows; blankSE$SE <- NA_real_
  k0 <- .iaNullKey("cont", rows, direct = c(FALSE, FALSE))
  expect_identical(.iaNullKey("cont", withSE, direct = c(FALSE, FALSE)), k0)
  expect_identical(.iaNullKey("cont", blankSE, direct = c(FALSE, FALSE)), k0)
  expect_false(grepl("SE", k0, fixed = TRUE))
  # the inputs the simulation DOES read still distinguish laws
  other <- rows; other$SD <- c(7, 7)
  expect_false(identical(.iaNullKey("cont", other, direct = c(FALSE, FALSE)), k0))
})

test_that("a redundant SE on one row leaves the trial p exactly where it was, and the value is the shared-law one (audit 2026-09-26, F1)", {
  r0 <- runP(fixture(FALSE, "audit-0926-f1-no-se.csv"))
  r1 <- runP(fixture(TRUE,  "audit-0926-f1-with-se.csv"))
  # the same seed, the same draws, ONE law: bit-identical results
  expect_identical(r1$p, r0$p)
  expect_identical(r1$rows, r0$rows)
  # and the value is the shared-law value: the audit's independent
  # reference 0.01073 (95% bounds 0.01058-0.01088), as a 99.9% binomial
  # interval at the stage the engine stopped at (the shared-law trial
  # does not alarm below 0.01, so it rests at 10,000; the split-law one
  # escalated to 100,000 and read 0.008575, outside this interval at
  # either stage)
  ref <- 0.01073
  M <- as.numeric(unique(r0$M)); expect_length(M, 1L)
  ci <- cpInterval(ref, M)
  expect_gt(r0$p, ci[1]); expect_lt(r0$p, ci[2])
  expect_false(0.008575 > cpInterval(ref, 1e5)[1])                    # the unfixed reading fails this bound
})
