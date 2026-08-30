# ageRowP.R - our own per-row age p-value distribution over the registry.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) to check figures #
# Steve Shafer had drafted into correspondence with Adrian Barnett.        #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY IT EXISTS. The claim being checked was that our row p for age is     #
# "almost exactly 0.05 below 0.05, and about 12% above 0.95". The first    #
# half was right and the second was not, and the only way to know was to   #
# measure it rather than recall it - the earlier per-variable pass had     #
# not saved its output, so the remembered figure could not be audited.     #
# Committed because these numbers have now gone out over Steve's name and  #
# a reader must be able to reproduce them.                                 #
#                                                                          #
# MEASURED, 31,288 registry trials with a usable age row:                  #
#                                                                          #
#   p < 0.05    4.99%   (5% expected)   <- the Monte Carlo is calibrated   #
#   p < 0.01    0.91%   (1% expected)                                      #
#   p > 0.95    9.11%   (5% expected)   <- NOT the 12% that was recalled   #
#   p > 0.99    4.74%   (1% expected)   <- the sharper statement           #
#                                                                          #
# The deciles are flat across the whole range and then jump 40% in the     #
# last one, so the entire departure is in the upper tail. 2.99% sit on     #
# the p >= 0.9999 display cap.                                             #
#                                                                          #
# ONE ROW PER TRIAL, which is why this is affordable. The full screen runs #
# every row of every table and takes over an hour; age alone is one row,   #
# so the same 31,000 trials finish in minutes.                             #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/ageRowP.R          (paths from INTEGRITY_WORK)          #
############################################################################

libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis); library(shiny); library(foreach)
  library(MBESS); library(Rfast); library(dqrng)
}))
root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
source(file.path(root, "corpus", "parallelHelper.R"))

d <- file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
cont <- read.csv(file.path(d, "baselineContinuous.csv"), stringsAsFactors = FALSE)
a <- cont[grepl("^age,? ?continuous$", tolower(trimws(cont$ROW))) &
          !is.na(cont$N) & !is.na(cont$MEAN) & !is.na(cont$SD) & cont$N > 1 &
          is.na(cont$Q1), ]
sp <- split(a, a$TRIAL)
sp <- sp[vapply(sp, nrow, 1L) >= 2]
cat("trials with a usable age row:", length(sp), "\n")

one <- function(nct) {
  g <- sp[[nct]]
  DATA <- data.frame(TRIAL = nct, ROW = "Age", N = g$N, MEAN = g$MEAN,
                     SD = g$SD, SE = NA_real_,
                     ROUND_MEAN = ifelse(is.na(g$ROUND_MEAN), 1, g$ROUND_MEAN),
                     ROUND_DISPERSION = ifelse(is.na(g$ROUND_DISPERSION), 1,
                                               g$ROUND_DISPERSION),
                     ROUND_OBSERVATION = ifelse(is.na(g$ROUND_OBSERVATION), 0,
                                                g$ROUND_OBSERVATION),
                     stringsAsFactors = FALSE)
  tryCatch({
    set.seed(1); dqrng::dqset.seed(1)
    utils::capture.output(pp <- IntegrityAnalysis:::P_Calc(nct, DATA, NULL, 100000))
    r <- pp[!is.na(pp$ROW) & pp$ROW == "Age", , drop = FALSE]
    if (!nrow(r)) return(NULL)
    data.frame(TRIAL = nct, arms = nrow(g), P = suppressWarnings(as.numeric(r$P[1])),
               stringsAsFactors = FALSE)
  }, error = function(e) NULL)
}

res <- iaParallel(names(sp), function(n) one(n), export = c("sp", "one"))
res <- do.call(rbind, Filter(Negate(is.null), res))
p <- res$P[is.finite(res$P)]
write.csv(res, file.path(d, "ageRowP.csv"), row.names = FALSE)

cat("\n=========== OUR per-row age p-values,", length(p), "trials ===========\n")
cat(sprintf("  p < 0.05 : %6.2f%%   (5%% expected)\n", 100 * mean(p < 0.05)))
cat(sprintf("  p < 0.01 : %6.2f%%   (1%% expected)\n", 100 * mean(p < 0.01)))
cat(sprintf("  p > 0.95 : %6.2f%%   (5%% expected)\n", 100 * mean(p > 0.95)))
cat(sprintf("  p > 0.99 : %6.2f%%   (1%% expected)\n", 100 * mean(p > 0.99)))
h <- table(cut(p, breaks = seq(0, 1, 0.1), include.lowest = TRUE))
cat("\n  deciles (% departure from uniform):\n   ",
    paste(sprintf("%+.0f", 100 * (as.numeric(h) / (length(p) / 10) - 1)),
          collapse = " "), "\n")
cat(sprintf("\n  at the upper cap (p >= 0.9999): %.2f%%\n", 100 * mean(p >= 0.9999)))
