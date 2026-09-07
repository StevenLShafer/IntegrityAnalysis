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

test_that("the fail-safe rule itself: the ambiguous arms are split against EACH OTHER, not against one pooled number", {
  # replicate the choice in isolation, as the heuristics apply it. The
  # first version compared every ambiguous arm with one pooled proportion,
  # so arms on the same side of it all took the same endpoint - security
  # screen 2026-09-07-1609, finding F1.
  choose <- function(lo, hi, cnt, N) {
    approx <- is.na(cnt)
    mid <- ifelse(approx, (lo + hi) / 2, cnt)
    prop <- mid / N
    amb <- which(approx)
    if (length(amb) == 1L) {
      pooled <- sum(mid) / sum(N)
      cnt[amb] <- if (prop[amb] >= pooled) hi[amb] else lo[amb]
    } else {
      r <- rank(prop[amb], ties.method = "first")
      take <- ifelse(r <= length(amb) / 2, "lo", "hi")
      for (g in split(seq_along(amb), format(prop[amb], digits = 15)))
        if (length(g) > 1L) take[g] <- c("lo", "hi")[1 + (seq_along(g) - 1) %% 2]
      cnt[amb] <- ifelse(take == "hi", hi[amb], lo[amb])
    }
    cnt
  }
  # two ambiguous arms at the same percentage: pushed apart
  expect_equal(choose(c(495, 495), c(505, 505), c(NA, NA), c(1000, 1000)), c(495, 505))
  # THREE arms printing the same percentage beside a small pinned arm: the
  # old rule gave all three 990 - identical proportions, the very defect
  # the fill exists to prevent. They must not all take one endpoint.
  got <- choose(c(990, 990, 990, NA), c(1010, 1010, 1010, NA),
                c(NA, NA, NA, 31), c(2000, 2000, 2000, 60))
  expect_true(length(unique(got[1:3])) > 1)
  expect_equal(sort(unique(got[1:3])), c(990, 1010))
  # one pinned arm (30% of 40 = 12), one ambiguous arm at 35% of 1000 (345..355): away from 30%
  expect_equal(choose(c(NA, 345), c(NA, 355), c(12, NA), c(40, 1000)), c(12, 355))
  # the ambiguous arm below the pooled proportion takes the bottom
  expect_equal(choose(c(NA, 245), c(NA, 255), c(20, NA), c(40, 1000)), c(20, 245))
  # two ambiguous arms at DIFFERENT percentages still take opposite ends
  expect_equal(choose(c(327, 303), c(333, 309), c(NA, NA), c(702, 695)), c(333, 303))
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
