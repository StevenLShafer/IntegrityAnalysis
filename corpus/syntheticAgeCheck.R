# syntheticAgeCheck.R - the tautology test. Both instruments, one
# variable, honest data, nothing else.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) to Steve         #
# Shafer's specification: "a Monte Carlo simulation of age alone, 2        #
# groups, integer measurements, across Ns of 20, 100, 500, and 1000        #
# subjects / arm ... See if both approaches return uniform distributions   #
# from 0 to 1. They should ... the test should be a tautology. If it shows #
# a problem, then that will be informative."                               #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY A TAUTOLOGY TEST IS WORTH THE MACHINE TIME. Every other measurement  #
# in this directory compares an instrument against a null that some other  #
# piece of code generated, and a null is only as good as the code that     #
# built it - a lesson corpus/correlationNull.R learnt the hard way, where  #
# a generator that added noise to each arm's own mean instead of a shared  #
# one manufactured a spectacular finding out of nothing.                   #
#                                                                          #
# Here there is nowhere for such a bug to hide. Participants are drawn     #
# one at a time from ONE normal distribution and split into two arms at    #
# random. There is no treatment, no correlation structure, no second       #
# variable, no registry, no parser. Whatever comes out is the instrument,  #
# because the data have no other content.                                  #
#                                                                          #
# WHAT UNIFORM MEANS FOR EACH INSTRUMENT, since they are not the same      #
# kind of number:                                                          #
#   ours     P_Calc's row p, one-sided toward excessive homogeneity.       #
#            Uniform on (0, 1) under the null.                             #
#   Barnett  a single row gives ONE t-statistic, and his trial-level       #
#            spike-and-slab needs several, so his model cannot run on one  #
#            row. What CAN be checked is the thing his model rests on:     #
#            that t is distributed as t(df). So the tested quantity is     #
#            2 * pt(-|t|, df), which is uniform exactly when that holds.   #
#            If it is not uniform here, his trial-level test is built on   #
#            sand for this variable, and so is any comparison with ours.   #
#                                                                          #
# THE ROUNDING AXIS matters and is swept rather than assumed. Ages are     #
# integers, so the OBSERVATIONS are discrete; the reported mean and SD are #
# then rounded again for publication, usually to one decimal. Our method   #
# models both roundings explicitly (ROUND_OBSERVATION, ROUND_MEAN,         #
# ROUND_DISPERSION). Barnett's t-statistic models neither. Small arms are  #
# where that difference should bite, which is why N = 20 is in the sweep.  #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/syntheticAgeCheck.R [outDir] [trialsPerCell] [mcReps]   #
############################################################################

args   <- commandArgs(trailingOnly = TRUE)
outDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
nPer   <- if (length(args) >= 2) as.integer(args[2]) else 5000L
mcReps <- if (length(args) >= 3) as.integer(args[3]) else 100000L

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis); library(shiny); library(foreach)
  library(MBESS); library(Rfast); library(dqrng)
}))
source(file.path(root, "corpus", "parallelHelper.R"))

# Age in an adult trial population. The registry's own continuous "Age,
# Continuous" rows have a median reported mean near 55 and a median
# reported SD near 13, which is where these come from.
AGE_MEAN <- 55
AGE_SD   <- 13
ARM_NS   <- c(20L, 100L, 500L, 1000L)
# Decimals the mean and SD are REPORTED to. Observations are always
# integers. One decimal is the registry norm; two is the sanity check
# that any effect really is the rounding.
REPORT   <- c(1L, 2L)

cat("synthetic age check\n")
cat("  age ~ Normal(", AGE_MEAN, ",", AGE_SD, "), rounded to integers\n")
cat("  arms per trial: 2, equal size\n")
cat("  trials per cell:", nPer, "\n")
cat("  Monte Carlo replicates in P_Calc:", mcReps, "\n\n")

cells <- expand.grid(n = ARM_NS, rep = REPORT)
cells <- cells[order(cells$rep, cells$n), ]

oneTrial <- function(spec) {
  n <- spec$n; rp <- spec$rep; id <- spec$id
  # ONE population, split at random. This is the whole point: there is no
  # difference between the arms to find.
  x <- round(stats::rnorm(2 * n, AGE_MEAN, AGE_SD))
  g <- sample(rep(1:2, each = n))
  m <- c(mean(x[g == 1]), mean(x[g == 2]))
  s <- c(stats::sd(x[g == 1]), stats::sd(x[g == 2]))
  mR <- round(m, rp); sR <- round(s, rp)

  DATA <- data.frame(
    TRIAL = id, ROW = "Age", N = c(n, n), MEAN = mR, SD = sR,
    SE = NA_real_, ROUND_MEAN = rp, ROUND_DISPERSION = rp,
    ROUND_OBSERVATION = 0L, stringsAsFactors = FALSE)

  ourP <- tryCatch({
    set.seed(id); dqrng::dqset.seed(id)
    utils::capture.output(pp <- IntegrityAnalysis:::P_Calc(id, DATA, NULL,
                                                           mcReps))
    r <- pp[!is.na(pp$ROW) & pp$ROW == "Age", , drop = FALSE]
    if (nrow(r)) suppressWarnings(as.numeric(r$P[1])) else NA_real_
  }, error = function(e) NA_real_)

  ts <- barnettTStats(DATA, CategoryNames = character(0))
  tv <- if (nrow(ts)) ts$t[1] else NA_real_
  dfv <- if (nrow(ts)) ts$df[1] else NA_real_
  # Barnett's t is built with n1 + n2 - 2; his MODEL is handed n1 + n2 - 1.
  # The uniformity of the two-sided p is a statement about the statistic,
  # so it uses the statistic's own degrees of freedom.
  bP <- if (is.finite(tv)) 2 * stats::pt(-abs(tv), 2 * n - 2) else NA_real_

  data.frame(n = n, rep = rp, ourP = ourP, t = tv, bP = bP,
             stringsAsFactors = FALSE)
}

specs <- list(); k <- 0L
for (i in seq_len(nrow(cells)))
  for (j in seq_len(nPer)) {
    k <- k + 1L
    specs[[k]] <- list(n = cells$n[i], rep = cells$rep[i], id = k)
  }
cat("running", length(specs), "trials\n")
t0 <- Sys.time()
res <- iaParallel(specs, function(s)
         tryCatch(oneTrial(s), error = function(e) NULL),
       export = c("oneTrial", "AGE_MEAN", "AGE_SD", "mcReps"))
res <- do.call(rbind, Filter(Negate(is.null), res))
cat("  done in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
    "min\n")
utils::write.csv(res, file.path(outDir, "syntheticAge.csv"), row.names = FALSE)

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
  cat(sprintf("  %-10s n=%6d  KS p=%-9.3g  %%p<0.05=%5.2f  %%p>0.95=%5.2f\n",
              lab, u$n, u$ks, u$lo, u$hi))
  cat("             deciles:",
      paste(sprintf("%+.0f", u$dec), collapse = " "), "\n")
}

cat("\n================= SYNTHETIC AGE, TWO HONEST ARMS =================\n")
cat("Uniform is the correct answer everywhere below. Deciles are shown as\n")
cat("percent departure from uniform; 5% and 95% tails should read 5.00.\n")
for (rp in REPORT) {
  cat("\n--- mean and SD reported to", rp, "decimal(s) ---\n")
  for (n in ARM_NS) {
    s <- res[res$n == n & res$rep == rp, ]
    cat("\nN =", n, "per arm\n")
    show("ours",    s$ourP)
    show("Barnett", s$bP)
    tt <- s$t[is.finite(s$t)]
    cat(sprintf("  t-statistic: SD=%.4f (1 expected)  %%|t|>1.96=%5.2f (5 expected)\n",
                stats::sd(tt), 100 * mean(abs(tt) > 1.959964)))
  }
}
cat("\nwritten:", file.path(outDir, "syntheticAge.csv"), "\n")
