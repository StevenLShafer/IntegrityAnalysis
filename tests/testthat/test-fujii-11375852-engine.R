# test-fujii-11375852-engine.R - the engine against a published Monte Carlo
# p computed by the method's own authors. No PDF, no corpus: pure numbers.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1) for ISSUES.md   #
# issue 34, at Steve Shafer's instruction that the fix leave test cases    #
# behind so it cannot regress.                                             #
#                                                                          #
# THE FIXTURE. Table 1 of Carlisle, Dexter, Pandit, Shafer & Yentis,       #
# "Calculating the probability of random sampling for continuous          #
# variables in submitted or published randomised controlled trials",       #
# Anaesthesia 2015;70:848-858 - the paper that introduced the Monte Carlo  #
# method this package implements - prints, as its worked example, the      #
# complete baseline table of Fujii, Hoshi, Uemura & Toyooka, Anesth Analg  #
# 2001;92:1590-3 (PMID 11375852, retracted): three groups of n = 8, nine   #
# variables, mean (SD). The text gives its Monte Carlo result: p = 1.2e-6. #
#                                                                          #
# That is the rarest kind of fixture: a published INPUT and a published    #
# ANSWER from the people who defined the method. The rows are transcribed  #
# exactly as printed, including "RAP(2)", which the 2015 table lists as a  #
# ninth variable. (On the article's own page that row is the after-dose    #
# RAP column - see the corpus check - but this test is of the ENGINE on    #
# Carlisle's table, so his table is what it uses.)                         #
#                                                                          #
# WHAT CAN HONESTLY BE ASSERTED. The app reports the trial p as a display  #
# string, and at its 100,000-replicate ceiling the floor of that display   #
# is "<0.0001". 1.2e-6 lies far below it. So the assertion is not that the #
# engine REPRODUCES 1.2e-6 - it cannot resolve that value - but that it    #
# drives this trial to the ceiling and to the floor, on every seed: the    #
# same verdict, at the resolution the app has. A future engine that read   #
# this table as unremarkable would fail here loudly.                       #
############################################################################

suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

fujii11375852Fixture <- function() {
  v9 <- c("RAP", "RAP(2)", "MPAP", "PAOP", "CO", "Stimulation 20 Hz",
          "Stimulation 100 Hz", "MAP", "HR")
  mean3 <- list(c(5, 5, 5), c(5, 5, 5), c(12, 12, 12), c(8, 8, 8),
                c(2.2, 2.2, 2.3), c(15.5, 15.3, 15.4), c(21.1, 20.9, 20.9),
                c(130, 132, 131), c(141, 143, 140))
  sd3   <- list(c(2, 2, 2), c(2, 1, 2), c(2, 2, 2), c(2, 1, 2),
                c(0.5, 0.4, 0.4), c(2, 1.8, 2.1), c(2, 2.2, 2.1),
                c(15, 12, 11), c(15, 10, 12))
  dec <- function(x) {
    s <- as.character(x)
    ifelse(grepl(".", s, fixed = TRUE), nchar(sub("^[^.]*[.]", "", s)), 0L)
  }
  rows <- list()
  for (i in seq_along(v9)) for (g in 1:3)
    rows[[length(rows) + 1]] <- data.frame(
      TRIAL = "PMID_11375852", ROW = v9[i], N = 8,
      MEAN = mean3[[i]][g], SD = sd3[[i]][g],
      ROUND_MEAN = dec(mean3[[i]][g]), ROUND_DISPERSION = dec(sd3[[i]][g]),
      ROUND_OBSERVATION = dec(mean3[[i]][g]) + 1, stringsAsFactors = FALSE)
  do.call(rbind, rows)
}

test_that("Carlisle's 27-row table of PMID 11375852 validates as printed", {
  d <- fujii11375852Fixture()
  expect_identical(nrow(d), 27L)
  v <- vdShared(d)
  expect_false(isTRUE(v$FAIL))
  expect_identical(sum(v$issues$code == "structural"), 0L)
  expect_identical(nrow(v$DATA), 27L)
})

test_that("the engine drives the trial to the replicate ceiling and the display floor", {
  d <- fujii11375852Fixture()
  v <- vdShared(d)
  for (seed in c(42L, 7L, 2026L)) {
    set.seed(seed); dqrng::dqset.seed(seed)
    x <- suppressWarnings(shiny::isolate(P_Calc(v$TRIALS[1], v$DATA, v$CategoryNames, m)))
    s <- x[which(x$ROW == "Summary")[1], ]
    # "<0.0001" is the display floor at the 100,000-replicate ceiling;
    # Carlisle's 1.2e-6 lies below it, so this is agreement at the
    # resolution the app has, and the strongest verdict it can report.
    expect_identical(as.character(s$P), "<0.0001", info = paste("seed", seed))
    # M is recorded per ROW, not on the Summary line: the escalation to the
    # ceiling shows as some row having run the full m replicates.
    expect_identical(max(as.integer(x$M), na.rm = TRUE), as.integer(m),
                     info = paste("seed", seed))
  }
})

test_that("the same table with its identical-mean rows broken up is not extreme", {
  # A sanity check on the assertion above: it must be the DATA that drive
  # the verdict, not the fixture's shape. Perturb the means so the arms
  # differ by about one SD, and the trial must leave the floor.
  d <- fujii11375852Fixture()
  set.seed(1); dqrng::dqset.seed(1)
  d$MEAN <- d$MEAN + rep(c(-1, 0, 1), times = 9) * d$SD
  v <- vdShared(d)
  x <- suppressWarnings(shiny::isolate(P_Calc(v$TRIALS[1], v$DATA, v$CategoryNames, 10000)))
  p <- as.character(x[which(x$ROW == "Summary")[1], ]$P)
  expect_false(identical(p, "<0.0001"))
})
