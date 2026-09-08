# Counts rebuilt from printed percentages: the fail-safe fill (Steve's
# decision, 2026-09-07, after the GPT-6 audit's finding F3). A percentage
# that fits several counts for the arm size is filled with the count in
# its bracket farthest from the other arms, painted its own colour, and
# named in the review flags; the API makes the same choice.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that("the bracket: exact below 100 per arm, several counts above", {
  expect_equal(.ppCountBracket(47, 0, 40), c(19, 19))          # 47% of 40: 19 alone
  expect_equal(.ppCountFromPct(47, 0, 40), 19L)
  b <- .ppCountBracket(50, 0, 1000)                            # 50% of 1,000: 495..505
  expect_equal(b, c(495, 505))
  expect_true(is.na(.ppCountFromPct(50, 0, 1000)))
  expect_equal(.ppCountBracket(50.0, 1, 1000), c(500, 500))    # one decimal pins it again
  expect_true(all(is.na(.ppCountBracket(101, 0, 40))))
})

# a percent-only table of two or more arms as a synthetic PDF (the fixture
# style of test-derived-green.R), through the deterministic reader
pctPdf <- function(pcts, ns) {
  f  <- file.path(tempdir(), paste0("failsafe", basename(tempfile("")), ".pdf"))
  # the columns must fit a letter-width page: four arms at 120pt apart
  # would put the last one off the page and the reader would see three
  vx <- 220 + 90 * (seq_along(pcts) - 1)
  arms <- c("Ketamine", "Saline", "Propofol", "Etomidate")[seq_along(pcts)]
  sds  <- c("45.3 ± 12.1", "46.1 ± 11.8", "44.8 ± 12.6", "45.9 ± 11.2")
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1. Baseline patient characteristics", adj = 0)),
    rowCells(110, "", arms, vx),
    rowCells(136, "", sprintf("(n = %d)", ns), vx),
    rowCells(164, "Age (yr)", sds[seq_along(pcts)], vx),
    rowCells(190, "Male sex", pcts, vx))
  makeTablePdf(f, cells)
}

test_that("two arms printing the same ambiguous percentage are pushed APART, and the cells carry the fail-safe kind", {
  r <- parseBaselineTableHeuristics(pctPdf(c("50%", "50%"), c(1000, 1000)), pctApprox = TRUE, quiet = TRUE)
  col <- grep("^Male sex$", names(r$data))
  expect_length(col, 1)
  male <- r$data[[col]][r$data$ROW == "Male sex"]
  expect_setequal(male[!is.na(male)], c(495, 505))            # the bracket's two ends, not two 500s
  expect_true(any(r$derivedCells$KIND == "failsafe"))
  expect_match(paste(r$derivedCells$NOTE, collapse = " "), "FAIL-SAFE")
  expect_match(paste(reviewFlags(r), collapse = " "), "FAIL-SAFE")
  # small arms: the same percentages pin exact counts and stay green/exact
  r2 <- parseBaselineTableHeuristics(pctPdf(c("50%", "52%"), c(40, 25)), pctApprox = TRUE, quiet = TRUE)
  expect_false(any(r2$derivedCells$KIND == "failsafe"))
})

test_that("the fail-safe rule is a maximisation, and the helper itself is what the parser calls", {
  # The rule is not a heuristic any more (security screen 2026-09-07-1654,
  # finding F1): .ppFailsafeCounts() enumerates the lo/hi choices and takes
  # the assignment with the largest fixed-margin Pearson statistic - the
  # most heterogeneous reading the printed page permits, which is the
  # guarantee the app and the guides state. The earlier tests replicated
  # the rule in the test file, so they could not have failed when the rule
  # was wrong; these call the function the parser calls.
  brackets <- function(pcts, Ns, dec = 0) {
    b <- t(vapply(seq_along(pcts), function(i) as.numeric(.ppCountBracket(pcts[i], dec, Ns[i])),
                  numeric(2)))
    cnt <- ifelse(b[, 1] == b[, 2], b[, 1], NA_real_)
    lo <- ifelse(is.na(cnt), b[, 1], NA_real_); hi <- ifelse(is.na(cnt), b[, 2], NA_real_)
    list(lo = lo, hi = hi, cnt = cnt)
  }
  fill <- function(pcts, Ns, dec = 0) {
    b <- brackets(pcts, Ns, dec); .ppFailsafeCounts(b$lo, b$hi, b$cnt, Ns)
  }

  # two arms at the same percentage: the ends of the bracket
  expect_setequal(fill(c(50, 50), c(1000, 1000)), c(495, 505))
  # two arms at different percentages: pushed apart, not together
  expect_equal(fill(c(47, 44), c(702, 695)), c(333, 303))
  # one ambiguous arm beside a pinned one: away from it
  expect_equal(fill(c(30, 35), c(40, 1000)), c(12, 355))
  expect_equal(fill(c(50, 25), c(40, 1000)), c(20, 245))

  # THE SCREEN'S WORST CASE. The rank rule split the two arms printing 47%
  # and the two printing 49% correctly against each other and wrongly
  # against the rest of the row, building 1455/18/93/2375/74 - row
  # statistic 1.16 - where 1485/18/93/2325/74 is equally consistent with
  # the page and reads 7.15. The maximiser must find the second.
  Ns <- c(3000, 40, 200, 5000, 150)
  got <- fill(c(49, 45, 47, 47, 49), Ns)
  expect_equal(got, c(1485, 18, 93, 2325, 74))
  expect_gt(.ppRowStat(got, Ns), .ppRowStat(c(1455, 18, 93, 2375, 74), Ns))

  # and it IS the maximum, checked against every admissible assignment
  bestOf <- function(pcts, Ns, dec = 0) {
    b <- brackets(pcts, Ns, dec); amb <- which(is.na(b$cnt))
    best <- -Inf
    for (v in 0:(2^length(amb) - 1)) {
      pick <- bitwAnd(bitwShiftR(v, seq_along(amb) - 1L), 1L) == 1L
      tr <- b$cnt; tr[amb] <- ifelse(pick, b$hi[amb], b$lo[amb])
      best <- max(best, .ppRowStat(tr, Ns))
    }
    best
  }
  set.seed(4)
  for (i in 1:40) {
    k <- sample(2:5, 1)
    Ns <- sample(c(40, 150, 200, 700, 1000, 2000, 5000), k, replace = TRUE)
    pcts <- sample(20:80, k, replace = TRUE)
    expect_gte(.ppRowStat(fill(pcts, Ns), Ns), bestOf(pcts, Ns) - 1e-9)
  }

  # an arm that reports nothing on this line is not an arm reporting zero:
  # it must stay out of the statistic and out of the fill
  out <- .ppFailsafeCounts(c(495, NA), c(505, NA), c(NA, NA), c(1000, 800))
  expect_true(out[1] %in% c(495, 505))   # filled from its own bracket
  expect_true(is.na(out[2]))             # and the silent arm stays silent
  # with one arm reporting there is nothing to be alike TO: every choice
  # gives the same statistic, and the fill takes the bracket's bottom
  expect_equal(.ppRowStat(c(495), c(1000)), .ppRowStat(c(505), c(1000)))
  # add a second reporting arm and the choice becomes real again
  expect_equal(.ppFailsafeCounts(c(495, NA), c(505, NA), c(NA, 300), c(1000, 800))[1], 505)
})

test_that("arms printing the same percentage are not rebuilt identically when a fourth arm shifts the pooled proportion (screen 1609, F1)", {
  # end to end, through the reader. This is the screen's own reproduction:
  # three arms print 50% of 2,000 and a small fourth arm prints 52% of 60
  # (31, uniquely pinned). That fourth arm pulls the pooled proportion
  # above 0.50, so under the first rule ALL THREE big arms sat below it
  # and all three took 990 - identical proportions, and an honest row read
  # p = 0.0094. Three equal arms ALONE do not reproduce it: they sit
  # exactly on the pooled proportion, where even the first rule
  # alternated. Verified to fail on the code this test was written for.
  r <- parseBaselineTableHeuristics(
    pctPdf(c("50%", "50%", "50%", "52%"), c(2000, 2000, 2000, 60)),
    pctApprox = TRUE, quiet = TRUE)
  male <- r$data[r$data$ROW == "Male sex", grep("^Male sex$", names(r$data))]
  male <- as.numeric(male[!is.na(male)])
  expect_length(male, 4)
  expect_gt(length(unique(male[1:3])), 1)
  expect_true(all(male[1:3] %in% c(990, 1010)))
  expect_equal(male[4], 31)
})

test_that("the review flags name the row and say fail-safe", {
  # a real parse, not a hand-built list: reviewFlags() dispatches on the
  # ParsePDFTable class, so a bare list silently skipped this check
  # (CodeRabbit on PR #213, 2026-09-07)
  r <- parseBaselineTableHeuristics(pctPdf(c("50%", "50%"), c(1000, 1000)),
                                    pctApprox = TRUE, quiet = TRUE)
  fl <- reviewFlags(r)
  expect_true(any(grepl("FAIL-SAFE counts", fl)))
  expect_true(any(grepl("Male sex", fl)))
})
