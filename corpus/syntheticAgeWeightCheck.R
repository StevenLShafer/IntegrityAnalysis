# syntheticAgeWeightCheck.R - the tautology test with TWO rows. Both
# instruments, two independent variables, honest data, nothing else.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-03 by Claude Code (model Claude Fable 5.1) to Steve      #
# Shafer's specification, after Adrian Barnett replied to the single-row   #
# result (corpus/syntheticAgeCheck.R) that his test "was not designed for  #
# a single row of data":                                                   #
#   "repeat the test, but with two rows. The first row is age. The second  #
#   row is weight. Participants are drawn from one normal age              #
#   distribution, rounded to integer years, and one normal weight          #
#   distribution, rounded to integer kilograms. Participants are split at  #
#   random into two equal arms. Simulate five thousand trials per cell.    #
#   Ours is scored by P_Calc's row p; Barnett's by the t-statistic's own   #
#   tail probability ... The reported-decimals axis is swept. This will    #
#   test whether the presence of a second row, WEIGHT, ameliorates the     #
#   issue identified with Barnett's test when we simulated AGE alone."     #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHAT CHANGES WITH A SECOND ROW. With one row Barnett's trial-level       #
# model cannot run at all (one t-statistic says nothing about a SCALE), so #
# the single-row script could only test the assumption his model rests    #
# on: that each t is distributed as t(df). With two rows his model runs,   #
# and this script scores it BOTH ways:                                     #
#   per row    2 * pt(-|t|, df) for age and for weight - uniform exactly   #
#              when the t(df) assumption holds, as before;                 #
#   per trial  barnettDispersion() on the two statistics, his posterior    #
#              probability of dispersion, flagged at his threshold 0.95.   #
# Ours is likewise scored per row (P_Calc's row p, one-sided toward        #
# excessive homogeneity) and per trial (the Summary row: Stouffer across   #
# the two rows, uniform under the null when the rows are).                 #
#                                                                          #
# THE HYPOTHESIS UNDER TEST is Steve's: that a second row will NOT repair  #
# the integer-reporting failure, because the failure is rounding, which    #
# the t-statistic does not model however many of them there are. If the   #
# per-row uniformity breaks at exactly the arm sizes and decimals it broke #
# at with one row, and the trial-level flag rate follows it, the second    #
# row has not helped. If the flag rate stays near its honest calibration  #
# while the per-row tails go wrong, the model has absorbed the damage.    #
#                                                                          #
# THE POPULATIONS. Age as in the single-row script (registry medians for   #
# reported mean and SD of "Age, Continuous"). Weight: an adult trial       #
# population, mean 80 kg, SD 18 kg - an ASSUMPTION stated here rather than #
# measured, because the registry does not carry a weight row often enough #
# to give a median worth quoting. Age and weight are drawn INDEPENDENTLY:  #
# correlation between the two rows is a separate question (it is what     #
# corpus/correlationNull.R prices), and adding it here would muddy the     #
# only thing this script asks. Each participant's two values are rounded  #
# to integers, so both rows have ROUND_OBSERVATION = 0.                    #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/syntheticAgeWeightCheck.R [outDir] [trialsPerCell]      #
#                                            [mcReps] [reportDecimals]     #
#     reportDecimals  comma-separated, default "0,1,2" - the integer case  #
#                     is where the single-row test broke both methods, so  #
#                     it is in the default sweep this time.                #
#   INTEGRITY_SNAPSHOT_LIB  an installed snapshot library; the workers     #
#                     load the installed package, never a live tree.       #
############################################################################

args   <- commandArgs(trailingOnly = TRUE)
outDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
nPer   <- if (length(args) >= 2) as.integer(args[2]) else 5000L
mcReps <- if (length(args) >= 3) as.integer(args[3]) else 100000L
# REPORT (4th arg) is set below, after the constants it belongs with.

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis); library(shiny); library(foreach)
  library(MBESS); library(Rfast); library(dqrng)
}))
# Provenance: the number this script prints must come from the library it
# was asked to use, never from a stale copy elsewhere on the path.
if (nzchar(libDir) &&
    !startsWith(normalizePath(find.package("IntegrityAnalysis"), "/"),
                normalizePath(libDir, "/")))
  stop("IntegrityAnalysis did not load from ", libDir)
cat("engine from:", find.package("IntegrityAnalysis"), "\n")
source(file.path(root, "corpus", "parallelHelper.R"))

AGE_MEAN    <- 55
AGE_SD      <- 13
WEIGHT_MEAN <- 80
WEIGHT_SD   <- 18
ARM_NS      <- c(20L, 100L, 500L, 1000L)
REPORT      <- if (length(args) >= 4)
  as.integer(strsplit(args[4], ",")[[1]]) else c(0L, 1L, 2L)

cat("synthetic age + weight check\n")
cat("  age    ~ Normal(", AGE_MEAN, ",", AGE_SD, "), rounded to integer years\n")
cat("  weight ~ Normal(", WEIGHT_MEAN, ",", WEIGHT_SD, "), rounded to integer kg\n")
cat("  the two are independent; arms per trial: 2, equal size\n")
cat("  trials per cell:", nPer, "\n")
cat("  Monte Carlo replicates in P_Calc:", mcReps, "\n")
cat("  reported decimals swept:", paste(REPORT, collapse = ", "), "\n\n")

cells <- expand.grid(n = ARM_NS, rep = REPORT)
cells <- cells[order(cells$rep, cells$n), ]

# A displayed p of "<0.0001" is P_Calc's licensed claim, not a number;
# under the null it should occur in about one trial in ten thousand. It
# is read as the midpoint of the interval it names rather than dropped,
# so the low tail is not quietly emptied.
pNum <- function(s) {
  v <- suppressWarnings(as.numeric(s))
  v[is.na(v) & grepl("^<", s)] <- 0.00005
  v
}

oneTrial <- function(spec) {
  n <- spec$n; rp <- spec$rep; id <- spec$id
  # ONE population per variable, split at random. There is no difference
  # between the arms to find, in either row.
  age <- round(stats::rnorm(2 * n, AGE_MEAN, AGE_SD))
  wt  <- round(stats::rnorm(2 * n, WEIGHT_MEAN, WEIGHT_SD))
  g   <- sample(rep(1:2, each = n))
  arm <- function(x) c(mean(x[g == 1]), mean(x[g == 2]))
  arms <- function(x) c(stats::sd(x[g == 1]), stats::sd(x[g == 2]))

  DATA <- data.frame(
    TRIAL = id, ROW = rep(c("Age", "Weight"), each = 2), N = rep(n, 4),
    MEAN = round(c(arm(age), arm(wt)), rp),
    SD   = round(c(arms(age), arms(wt)), rp),
    SE = NA_real_, ROUND_MEAN = rp, ROUND_DISPERSION = rp,
    ROUND_OBSERVATION = 0L, stringsAsFactors = FALSE)

  ours <- tryCatch({
    set.seed(id); dqrng::dqset.seed(id)
    utils::capture.output(pp <- IntegrityAnalysis:::P_Calc(id, DATA, NULL,
                                                           mcReps))
    pick <- function(row) {
      r <- pp[!is.na(pp$ROW) & pp$ROW == row, , drop = FALSE]
      if (nrow(r)) pNum(r$P[1]) else NA_real_
    }
    c(age = pick("Age"), weight = pick("Weight"), trial = pick("Summary"))
  }, error = function(e) c(age = NA_real_, weight = NA_real_, trial = NA_real_))

  ts <- barnettTStats(DATA, CategoryNames = character(0))
  tOf <- function(row) {
    r <- ts[ts$ROW == row, , drop = FALSE]
    if (nrow(r)) r$t[1] else NA_real_
  }
  tA <- tOf("Age"); tW <- tOf("Weight")
  # Barnett's t is built with n1 + n2 - 2; his MODEL is handed n1 + n2 - 1.
  # The uniformity of the two-sided p is a statement about the statistic,
  # so it uses the statistic's own degrees of freedom.
  tail2 <- function(tv) if (is.finite(tv)) 2 * stats::pt(-abs(tv), 2 * n - 2) else NA_real_
  bd <- tryCatch(barnettDispersion(ts), error = function(e) NULL)

  data.frame(n = n, rep = rp,
             ourAge = ours[["age"]], ourWeight = ours[["weight"]],
             ourTrial = ours[["trial"]],
             tAge = tA, tWeight = tW, bAge = tail2(tA), bWeight = tail2(tW),
             bDispersed = if (is.null(bd)) NA_real_ else bd$pDispersed,
             bEpsilon   = if (is.null(bd)) NA_real_ else bd$epsilon,
             bDirection = if (is.null(bd)) NA_character_ else bd$direction,
             stringsAsFactors = FALSE)
}

# One cell at a time, each APPENDED to the CSV as it finishes, and a cell
# already in the CSV is skipped - so a run that dies at 90 minutes (the
# first full run did, 2026-09-03, with nothing written) resumes from the
# next cell rather than from the start. Trial ids are fixed by cell
# position, so a resumed run seeds every trial exactly as a single run
# would have.
dir.create(outDir, showWarnings = FALSE, recursive = TRUE)
outCsv <- file.path(outDir, "syntheticAgeWeight.csv")
done <- if (file.exists(outCsv)) utils::read.csv(outCsv, stringsAsFactors = FALSE) else NULL
cat("running", nrow(cells) * nPer, "trials in", nrow(cells), "cells\n")
t0 <- Sys.time()
for (i in seq_len(nrow(cells))) {
  n <- cells$n[i]; rp <- cells$rep[i]
  if (!is.null(done) && sum(done$n == n & done$rep == rp) >= nPer) {
    cat(sprintf("  cell N=%d rep=%d: already in %s, skipped\n", n, rp, basename(outCsv)))
    next
  }
  specs <- lapply(seq_len(nPer), function(j) list(n = n, rep = rp, id = (i - 1L) * nPer + j))
  t1 <- Sys.time()
  # a seed per cell: each cell's worker pool is new, and the helper seeds
  # a pool from its `seed`, so one seed for all would hand every cell the
  # same participant draws - a paired design, not the independent one the
  # single-row test used
  res <- iaParallel(specs, function(s)
           tryCatch(oneTrial(s), error = function(e) NULL),
         export = c("oneTrial", "pNum", "AGE_MEAN", "AGE_SD",
                    "WEIGHT_MEAN", "WEIGHT_SD", "mcReps"),
         seed = 20260903L + i)
  res <- do.call(rbind, Filter(Negate(is.null), res))
  utils::write.table(res, outCsv, sep = ",", row.names = FALSE,
                     col.names = !file.exists(outCsv), append = file.exists(outCsv))
  cat(sprintf("  cell N=%d rep=%d: %d trials in %.1f min\n", n, rp, nrow(res),
              as.numeric(difftime(Sys.time(), t1, units = "mins"))))
}
cat("  done in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
    "min\n")
res <- utils::read.csv(outCsv, stringsAsFactors = FALSE)

## ---- report --------------------------------------------------------------
unif <- function(p) {
  p <- p[is.finite(p)]
  if (length(p) < 50) return(NULL)
  h <- table(cut(p, breaks = seq(0, 1, 0.1), include.lowest = TRUE))
  list(n = length(p), ks = suppressWarnings(stats::ks.test(p, "punif"))$p.value,
       dec = 100 * (as.numeric(h) / (length(p) / 10) - 1),
       lo = 100 * mean(p < 0.05), hi = 100 * mean(p > 0.95))
}

show <- function(lab, p) {
  u <- unif(p)
  if (is.null(u)) return(invisible())
  cat(sprintf("  %-16s n=%6d  KS p=%-9.3g  %%p<0.05=%5.2f  %%p>0.95=%5.2f\n",
              lab, u$n, u$ks, u$lo, u$hi))
  cat("                   deciles:",
      paste(sprintf("%+.0f", u$dec), collapse = " "), "\n")
}

cat("\n============ SYNTHETIC AGE + WEIGHT, TWO HONEST ARMS ============\n")
cat("Uniform is the correct answer for every p below. Deciles are shown as\n")
cat("percent departure from uniform; 5% and 95% tails should read 5.00.\n")
cat("Barnett's trial-level number is a posterior probability, not a p: the\n")
cat("line reports his flag rate at 0.95 and the direction of the flags.\n")
for (rp in REPORT) {
  cat("\n--- mean and SD reported to", rp, "decimal(s) ---\n")
  for (n in ARM_NS) {
    s <- res[res$n == n & res$rep == rp, ]
    cat("\nN =", n, "per arm\n")
    show("ours: age",     s$ourAge)
    show("ours: weight",  s$ourWeight)
    show("ours: trial",   s$ourTrial)
    show("Barnett: age",    s$bAge)
    show("Barnett: weight", s$bWeight)
    for (v in c("tAge", "tWeight")) {
      tt <- s[[v]][is.finite(s[[v]])]
      cat(sprintf("  t (%s): SD=%.4f (1 expected)  %%|t|>1.96=%5.2f (5 expected)  %%t==0=%5.2f\n",
                  sub("^t", "", v), stats::sd(tt), 100 * mean(abs(tt) > 1.959964),
                  100 * mean(tt == 0)))
    }
    d <- s$bDispersed[is.finite(s$bDispersed)]
    fl <- is.finite(s$bDispersed) & s$bDispersed > 0.95
    cat(sprintf("  Barnett trial: n=%6d  mean pDispersed=%.3f  flagged(>0.95)=%5.2f%%  of which under=%d over=%d\n",
                length(d), mean(d), 100 * mean(fl),
                sum(fl & s$bDirection %in% "under-dispersed"),
                sum(fl & s$bDirection %in% "over-dispersed")))
  }
}
cat("\nwritten:", file.path(outDir, "syntheticAgeWeight.csv"), "\n")
