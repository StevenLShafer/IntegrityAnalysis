# The adaptive staged Monte Carlo and confidence-bounded reporting
# (Steve's decision, 2026-08-17; scheme described in docs/statistics.md).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

meanrow <- function(mean, sd, n = 40) data.frame(
  TRIAL = "T", ROW = "X",
  N = n, MEAN = mean, SD = sd,
  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)

runP <- function(d, m = 100000) suppressWarnings(shiny::isolate(
  P_Calc("T", d, NULL, m)))

test_that("unalarming rows stop at 1,000 replicates; alarming rows escalate", {
  dqrng::dqset.seed(11); set.seed(11)
  quiet <- runP(rbind(meanrow(54.1, 9.2), meanrow(51.0, 8.9)))
  i <- which(quiet$ROW == "X")[1]
  expect_equal(as.numeric(quiet$M[i]), 1000)

  alarm <- runP(rbind(meanrow(54.1, 9.2), meanrow(54.1, 9.2),
                      meanrow(54.1, 9.2)))
  i <- which(alarm$ROW == "X")[1]
  expect_gt(as.numeric(alarm$M[i]), 1000)
})

test_that("'<0.0001' appears only when the upper bound licenses it", {
  # licensing arithmetic, tested directly on the report builder
  r0 <- .rowReport(list(kLess = 0, kEq = 0, m = 100000))
  expect_identical(r0$disp, "<0.0001")          # upper 3.7e-5 < 1e-4
  r1 <- .rowReport(list(kLess = 0, kEq = 0, m = 10000))
  expect_false(identical(r1$disp, "<0.0001"))   # upper 3.7e-4 - NOT licensed
  expect_equal(as.numeric(r1$disp), 1 / 10001, tolerance = 1e-6)  # DH floor
  # one-sided 97.5% bound (= Gemini's two-sided 95% table): at m = 1e5
  # the licensing cutoff is k <= 3 (k=3 upper ~8.8e-5; k=4 ~1.02e-4)
  r4 <- .rowReport(list(kLess = 4, kEq = 0, m = 100000))
  expect_false(identical(r4$disp, "<0.0001"))
  r3 <- .rowReport(list(kLess = 3, kEq = 0, m = 100000))
  expect_identical(r3$disp, "<0.0001")
})

test_that("every row carries its exact 95% Monte Carlo interval (2026-09-04)", {
  r <- .rowReport(list(kLess = 10, kEq = 0, m = 100000))
  expect_identical(r$ci, "4.8e-05 to 0.00018")
  r <- .rowReport(list(kLess = 300, kEq = 0, m = 1000))
  expect_identical(r$ci, "0.27 to 0.33")          # an unremarkable row, honestly wide
  r <- .rowReport(list(kLess = 0, kEq = 0, m = 100000))
  expect_identical(r$ci, "0 to 3.7e-05")           # nothing at or below: lower is 0
  # ties widen the upper end only: the mid-p sits inside
  r <- .rowReport(list(kLess = 100, kEq = 100, m = 1000))
  lo <- as.numeric(sub(" to .*", "", r$ci)); hi <- as.numeric(sub(".* to ", "", r$ci))
  expect_lt(lo, r$p); expect_gt(hi, r$p)
})

test_that("the combined trial p is the exact combination: bounded, licensed, with its own interval", {
  dqrng::dqset.seed(12); set.seed(12)
  # four strongly homogeneous variables: each row small; the trial's
  # Stouffer sum is beyond every one of the 100,000 simulated honest
  # sums, so the trial p is floored at 1/(m+1), displays "<0.0001"
  # because the 97.5% bound (3.7e-05 at zero reaching sums) licenses it,
  # and carries the exact Clopper-Pearson interval "0 to 3.7e-05".
  # Before 2026-09-04 the closed-form Stouffer sum reported ~1e-9 here
  # with a bootstrap interval; the exact combination cannot resolve
  # below 1/(m+1), and says so.
  d <- do.call(rbind, lapply(1:4, function(k) {
    r <- rbind(meanrow(50 + k, 8.0), meanrow(50 + k, 8.0),
               meanrow(50 + k, 8.0))
    r$ROW <- paste0("V", k); r
  }))
  x <- runP(d)
  s <- which(x$ROW == "Summary")
  expect_identical(x$P[s], "<0.0001")
  expect_identical(x$CI95[s], "0 to 3.7e-05")
  expect_true(all(x$M[seq_len(s - 1)] == "1e+05"))   # every row escalated with the trial
})

test_that("the exact combination judges tie-ridden rows by their own null (the 2026-09-04 correction)", {
  # Three rows of identical INTEGER means at N = 1,000 per arm: each
  # row's statistic ties with about half of its honest replicates, so
  # each row mid-p is about 0.28 and the closed-form Stouffer sum read
  # p ~ 0.16 off the normal table. The exact combination asks how often
  # honest trials tie on all three rows at once (ties half): about
  # 0.08. Neither number is an alarm - three all-tied integer rows are
  # what a sixth of honest large trials look like - but the exact one
  # is the true share, and it is what makes the trial p calibrated at
  # coarse rounding (corpus/syntheticTiesCheck.R, run 1).
  dqrng::dqset.seed(21); set.seed(21)
  d <- do.call(rbind, lapply(1:3, function(k) data.frame(
    TRIAL = "T", ROW = paste0("V", k), N = 1000, MEAN = c(55, 55),
    SD = c(13, 13), ROUND_MEAN = 0, ROUND_OBSERVATION = 0,
    stringsAsFactors = FALSE)))
  x <- runP(d, m = 10000)
  s <- which(x$ROW == "Summary")
  p <- as.numeric(x$P[s])
  rows <- as.numeric(x$P[seq_len(s - 1)])
  expect_true(all(rows > 0.2 & rows < 0.35))
  expect_gt(p, 0.04); expect_lt(p, 0.13)
  # ...and the closed-form Stouffer of those row p's is larger: the lump
  expect_gt(sumz(rows)$p, p)
})

test_that("mid-p point estimates are unchanged in spirit: direction holds", {
  dqrng::dqset.seed(13); set.seed(13)
  hom <- runP(rbind(meanrow(54.1, 9.2), meanrow(54.1, 9.2),
                    meanrow(54.1, 9.2)), m = 10000)
  het <- runP(rbind(meanrow(40.0, 9.2), meanrow(54.1, 9.2),
                    meanrow(68.0, 9.2)), m = 10000)
  pH <- suppressWarnings(as.numeric(
    hom$P[hom$ROW == "Summary" & !is.na(hom$ROW)]))[1]
  pT <- suppressWarnings(as.numeric(
    het$P[het$ROW == "Summary" & !is.na(het$ROW)]))[1]
  expect_lt(pH, 0.05)
  expect_gt(pT, 0.9)
})
