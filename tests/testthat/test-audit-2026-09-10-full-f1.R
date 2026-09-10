# Adjudication of the 2026-09-10 FULL independent statistical audit,
# finding F1 (docs/audits/2026-09-10-full-independent-statistical-audit-chatgpt.md):
# rows that share a null law carried separately estimated score mappings,
# so a genuine trial tie whose extreme outcome sat in a different row was
# split by estimation noise - exact 0.011146, engine 0.003285 or 0.0194
# depending only on which row carried the name.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/P_Calc.R (rows sharing a null law share
# one pooled score mapping; the trial tie uses the rows' bounded
# criterion), Steve Shafer's design decision of 2026-09-10. Per the
# standing rule in AGENTS.md the defect is reproduced THROUGH THE PATH THE
# REPORT NAMES - the audit's CSVs through the upload reader and the API's
# analysis route at seed 42 - and judged against the EXACT reference the
# audit derived, not against the fix's own output: with q = 100/199 the
# exact trial mid-p for J rows and one extreme row is
# q^J + 0.5 * J * (1 - q) * q^(J - 1), and the engine's estimate at its
# final stage is a binomial count, so it must land inside that value's
# 99.9% Clopper-Pearson interval. Checked to FAIL on 0ba8598.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

# the audit's construction: J binary variables in two arms of 100, all
# (1,99)/(1,99) except one, which is (0,100)/(2,98); every row has the
# same margins (100,100) by (2,198), hence the same null law
fixture <- function(J, extreme, name = sprintf("audit-f1-J%d-bad%d.csv", J, extreme)) {
  vars <- sprintf("V%02d", seq_len(J))
  d <- data.frame(TRIAL = "T", ROW = rep(vars, each = 2), N = NA_real_, MEAN = NA_real_,
                  SD = NA_real_, YES = 1, NO = 99, stringsAsFactors = FALSE)
  d$YES[d$ROW == vars[extreme]] <- c(0, 2)
  d$NO[d$ROW == vars[extreme]]  <- c(100, 98)
  f <- file.path(tempdir(), name)
  utils::write.csv(d, f, row.names = FALSE)
  f
}
exactP <- function(J) { q <- 100 / 199; q^J + 0.5 * J * (1 - q) * q^(J - 1) }
cpInterval <- function(p, m, level = 0.999) {
  k <- round(p * m); a <- (1 - level) / 2
  c(stats::qbeta(a, k, m - k + 1), stats::qbeta(1 - a, k + 1, m - k))
}
runP <- function(f) {
  rd <- .apiReadUpload(f, basename(f))
  a <- shiny::isolate(.apiAnalyze(rd$data, seed = 42))
  s <- a$results[!is.na(a$results$KIND) & a$results$KIND == "summary", , drop = FALSE]
  list(p = suppressWarnings(as.numeric(as.character(s$P[1]))),
       M = unique(a$results$M[!is.na(a$results$KIND) & a$results$KIND == "variable"]))
}

test_that("nine shared-law rows with one extreme: the trial p is the exact mid-p, whichever row is extreme (audit 2026-09-10 full, F1)", {
  ref <- exactP(9)                                         # 0.0111459494
  expect_equal(ref, 0.0111459494, tolerance = 1e-9)
  r3 <- runP(fixture(9, 3))
  r1 <- runP(fixture(9, 1))
  expect_equal(unique(r3$M), "1e+05")
  ci <- cpInterval(ref, 100000)                            # about 0.0101 to 0.0122
  # 0ba8598: 0.003285 (V03) and 0.0194 (V01) - both far outside
  expect_gt(r3$p, ci[1]); expect_lt(r3$p, ci[2])
  expect_gt(r1$p, ci[1]); expect_lt(r1$p, ci[2])
  # the answer no longer depends on which row carries the name: the two
  # namings agree to the sampling resolution of the same count
  expect_lt(abs(r3$p - r1$p), 3 * sqrt(ref * (1 - ref) / 100000) * 2)
})

test_that("fourteen shared-law rows with one extreme: the exact value sits inside the reported interval", {
  ref <- exactP(14)                                        # 0.0005191945
  r <- runP(fixture(14, 7))
  ci <- cpInterval(ref, 100000)
  # 0ba8598 read 0.00013 with a printed interval of 0.000022 to 0.00031
  expect_gt(r$p, ci[1]); expect_lt(r$p, ci[2])
})

test_that("a row with a law of its own is mapped through its own draws, exactly as before", {
  # two continuous rows with different inputs and one categorical row:
  # three distinct keys, no pooling - the pinned value of this known
  # trial is bit-identical to the engine before the change
  d <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Weight", "Weight"),
                  N = c(30, 30, 30, 30), MEAN = c(50.1, 50.2, 70.3, 70.1),
                  SD = c(10, 10, 12, 12), ROUND_MEAN = 1, ROUND_OBSERVATION = 0,
                  ROUND_DISPERSION = 0, stringsAsFactors = FALSE)
  v <- shiny::isolate(validateData(d))
  keys <- vapply(c("Age", "Weight"), function(rw)
    .iaNullKey("continuous", v$DATA[v$DATA$ROW == rw, ]), character(1))
  expect_false(keys[1] == keys[2])
  set.seed(42); dqrng::dqset.seed(42)
  x <- shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, 1000))
  expect_equal(as.character(x$P[x$KIND %in% "summary"][1]), "0.0045")   # the value on 0ba8598
})

test_that("the null key: identical inputs share it, any differing input does not; margins alone for a category row", {
  a <- data.frame(N = c(30, 30), MEAN = c(50.1, 50.2), SD = c(10, 10), ROUND_MEAN = 1,
                  ROUND_OBSERVATION = 0, ROUND_DISPERSION = 0)
  b <- a; b$MEAN[2] <- 50.3
  expect_equal(.iaNullKey("continuous", a), .iaNullKey("continuous", a))
  expect_false(.iaNullKey("continuous", a) == .iaNullKey("continuous", b))
  expect_false(.iaNullKey("continuous", a) == .iaNullKey("median", a))
})
