# Adjudication of security screens 2026-09-08-0709 and -1048.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5, Anthropic),
# 2026-09-08, with the fixes in R/P_Calc.R and R/app_globals.R. Each
# test below pins one finding, and each was checked to FAIL on the code
# as it stood before the fix - the screens' own standard, and the reason
# three earlier versions of the fail-safe rule shipped broken.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

runP <- function(d, m = 10000) {
  set.seed(42); dqrng::dqset.seed(42)
  v <- shiny::isolate(validateData(d))
  if (isTRUE(v$FAIL)) return(NULL)
  suppressWarnings(shiny::isolate(P_Calc("T", v$DATA, v$CategoryNames, m)))
}
pOf <- function(x) if (is.null(x)) NA_character_ else
  as.character(x$P[which(x$KIND == "summary")[1]])
noteOf <- function(x) if (is.null(x)) NA_character_ else as.character(x$NOTE[1])

cont <- function(means, sd, N, rm, rd = 1) data.frame(
  TRIAL = "T", ROW = "X", N = N, MEAN = means, SD = sd, SE = NA_real_,
  ROUND_MEAN = rm, ROUND_DISPERSION = rd, ROUND_OBSERVATION = rm,
  stringsAsFactors = FALSE)

# =================================================== screen 1048, F1
# the zero snap was a property of the coordinate system, not of the
# statistic it thresholds

test_that("the zero-snap tolerance is translation-invariant", {
  h  <- .iaMeanStep(c(5, 5, 5))
  # the tolerance takes only the printed step, so neither an origin nor
  # the observed arms can enter it (the observed term was removed by the
  # 2026-09-10 audit's F1; the old expression was 1e-26 * (1 + centre^2),
  # quadratic in the origin)
  expect_false("dd" %in% names(formals(.iaZeroSnapTol)))
  # compared as a RATIO: for values this small testthat's tolerance is
  # absolute, so expect_equal(x, 1e-22) accepts any small positive x
  # (CodeRabbit on PR #246)
  expect_equal(.iaZeroSnapTol(h) / (1e-12 * 1e-10), 1)
  expect_gt(.iaZeroSnapTol(h), 0)
  # the OLD expression, for contrast: the same row at two origins gave
  # tolerances eighteen orders of magnitude apart
  oldTol <- function(centre) 1e-26 * (1 + centre^2)
  expect_gt(oldTol(1e9) / oldTol(0), 1e17)
})

test_that("the zero-snap tolerance scales with the units, as the statistic does", {
  h <- .iaMeanStep(1)
  for (k in c(1e-3, 1e3)) {
    # statistic scales by k^2, so the tolerance must too - checked as a
    # relative error, since at k = 1e-3 the expected value is 1e-20 and
    # an absolute tolerance would accept anything (CodeRabbit on #246)
    ratio <- .iaZeroSnapTol(h * k) / .iaZeroSnapTol(h)
    expect_lt(abs(ratio / k^2 - 1), 1e-9)
  }
})

test_that("the tolerance is the printed grid's alone, and zero without one", {
  # HISTORY: the screen's proposal, 1e-12 * max(dd^2) alone, was exactly
  # zero for tied arms, and at the time that mattered (a replicate was
  # translated by the OBSERVED first arm and left dust; it moved a pinned
  # value in test-sd-rounding-draw.R by 0.013). Since the 2026-09-09
  # audit's F6 a tie is structurally zero, and since the 2026-09-10
  # audit's F1 the observed term is gone: the floor is the finest printed
  # step squared, times 1e-12, and nothing else.
  expect_gt(.iaZeroSnapTol(.iaMeanStep(1)), 0)
  expect_equal(.iaZeroSnapTol(.iaMeanStep(c(1, 3, 2))) / (1e-12 * 1e-6), 1)
  expect_identical(.iaZeroSnapTol(numeric(0)), 0)
})

test_that("an arbitrary origin no longer decides the p", {
  # THE REPRODUCTION. Three arms of 1,000, SD 0.001, means differing by
  # 2e-5 at five printed decimals. On the old tolerance the same row read
  # p = 0.3105 at origin 0 and p = 0.492 at origin 1e9 - the tolerance
  # (1e-8 there) swallowed the observed statistic and nearly every
  # replicate, so the answer stopped depending on the data.
  d <- c(0, 2e-5, -2e-5); sd <- rep(1e-3, 3); N <- rep(1000, 3)
  atZero <- pOf(runP(cont(d, sd, N, 5, 3), m = 100000))
  atBig  <- pOf(runP(cont(1e9 + d, sd, N, 5, 3), m = 100000))
  skip_if(is.na(atZero) || is.na(atBig) || atZero == "No values",
          "row refused in this build")
  a <- suppressWarnings(as.numeric(atZero)); b <- suppressWarnings(as.numeric(atBig))
  skip_if(is.na(a) || is.na(b), "p reported below the floor")
  expect_lt(abs(a - b), 0.05)
  # and it is not merely that both sit at 0.5: the row is genuinely
  # unremarkable-but-not-tied, so the shared answer carries information
  expect_lt(b, 0.45)
})

# =================================================== screen 0709, F1
# the fine-precision note fired on ordinary honest rows

test_that("the fine-precision note stays silent on an ordinary honest row", {
  # 45.0 is stored as the double 45, so .iaDecimals() reports 0 for that
  # arm; the minimum across arms is 0, all three round to 45, and the
  # note used to fire - telling the editor the arms print alike when the
  # page shows them differing in the first decimal.
  expect_identical(.iaFinePrecisionNote(c(45.2, 45.0, 44.8), 1, FALSE), "")
  expect_identical(.iaFinePrecisionNote(c(102, 101.5, 102.4), 1, FALSE), "")
})

test_that("the fine-precision note still fires where it was adjudicated to", {
  # the perturbations pinned by screen 2026-09-07-2339's F1: small enough
  # to keep the p at the floor, large enough to clear the zero snap
  for (delta in c(0, 2^-52, 1e-15, 1e-14, 1e-13, 1e-12, 1e-11))
    expect_true(nzchar(.iaFinePrecisionNote(c(0.5, 0.5 + delta, 0.5), 15, FALSE)),
                info = paste("delta", delta))
  expect_true(nzchar(.iaFinePrecisionNote(c(77, 77.000001), 6, FALSE)))
})

test_that("the fine-precision note stays silent on arms that plainly differ", {
  expect_identical(.iaFinePrecisionNote(c(0.5, 1.5, 2.5), 15, FALSE), "")
  expect_identical(.iaFinePrecisionNote(c(0.5, 0.5, 0.5), 1, FALSE), "")
})

test_that("the honest row carries no note end to end", {
  x <- runP(cont(c(50, 50.1, 49.9), c(10, 10, 10), c(50, 50, 50), 1))
  skip_if(is.null(x), "row refused")
  expect_false(grepl("exceeds the digits", noteOf(x), fixed = TRUE))
})

# =================================================== screen 0709, F3
# the registry cap evicted the warnings instead of the ordinary rows

test_that("the registry cap keeps the warning rows and drops the ordinary ones", {
  cap <- 100L
  reg <- data.frame(
    TRIAL = "T",
    ROW = c("ocrRow", paste0("r", seq_len(9000))),
    COL = "*",
    KIND = c("ocr", rep("derived", 9000)),
    note = "n", stringsAsFactors = FALSE)
  out <- .iaCapRegistry(reg, cap = cap)
  expect_equal(nrow(out), cap)
  # the OCR warning is the FIRST row of 9,001 - tail truncation dropped it
  expect_true("ocr" %in% out$KIND)
  expect_true("ocrRow" %in% out$ROW)
  # registry order is preserved, because the payload resolves a shared
  # cell last-entry-wins
  expect_false(is.unsorted(match(out$ROW, reg$ROW)))
})

test_that("more warning rows than the cap keeps the newest of them", {
  cap <- 10L
  reg <- data.frame(TRIAL = "T", ROW = paste0("r", 1:50), COL = "*",
                    KIND = "ocr", note = "n", stringsAsFactors = FALSE)
  out <- .iaCapRegistry(reg, cap = cap)
  expect_equal(nrow(out), cap)
  expect_identical(out$ROW, paste0("r", 41:50))
})

test_that("a registry within the cap is returned untouched", {
  reg <- data.frame(TRIAL = "T", ROW = c("a", "b"), COL = "*",
                    KIND = c("ocr", "derived"), note = "n",
                    stringsAsFactors = FALSE)
  expect_identical(.iaCapRegistry(reg, cap = 10L), reg)
})

# =================================================== screen 0709, S1
# the composite key could be forged by document text

test_that("no trial or row label can forge another pair's cell key", {
  cr <- rawToChar(as.raw(13))
  # the collision the screen described: these two pairs produced the
  # same key when the fields were pasted with a carriage return between
  expect_false(identical(.iaCellKey("A", paste0("B", cr, "C")),
                         .iaCellKey(paste0("A", cr, "B"), "C")))
  # ...and the same shape for any separator, because the encoding is
  # length-prefixed rather than delimited
  expect_false(identical(.iaCellKey("A", "B|C"), .iaCellKey("A|B", "C")))
  expect_false(identical(.iaCellKey("", "AB"), .iaCellKey("A", "B")))
  # equal pairs still key equal, which is the whole point of the key
  expect_identical(.iaCellKey("A", "B"), .iaCellKey("A", "B"))
  expect_identical(.iaCellKey(c("A", "A"), c("B", "B"))[1],
                   .iaCellKey("A", "B"))
  # NA is a value, not a hole, and never collides with the literal "NA"
  expect_false(identical(.iaCellKey(NA, "B"), .iaCellKey("NA", "B")))
})

test_that("a row label carrying a carriage return still paints its own cell", {
  cr <- rawToChar(as.raw(13))
  d <- data.frame(TRIAL = c("A", "A"), ROW = c(paste0("B", cr, "C"), "D"),
                  MEAN = c(1, 2), stringsAsFactors = FALSE)
  dv <- data.frame(TRIAL = paste0("A", cr, "B"), ROW = "C", COL = "MEAN",
                   KIND = "ocr", note = "should not paint anything",
                   stringsAsFactors = FALSE)
  p <- .iaDerivedPayload(d, dv)
  # the registry entry names a (TRIAL, ROW) pair no grid row has, so it
  # must paint nothing; with the old key it claimed row 1
  expect_equal(length(p$iss), 0)
})
