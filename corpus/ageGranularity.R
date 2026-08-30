# ageGranularity.R - is the age excess a reporting artefact or a
# property of the trials?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5), as the control  #
# for the age finding in corpus/tStatsByVariable.R.                        #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY IT WAS NEEDED. Age exceeds |t| > 1.96 in 13.5% of registry           #
# comparisons against about 6% expected. Steve's tautology test then       #
# showed that COARSE REPORTING alone inflates that rate on honest data -   #
# to 8.8% at 500 per arm when the mean is reported as an integer - and     #
# 10.4% of registry age rows are reported to zero decimals. So a real      #
# part of the excess might have been arithmetic rather than trials, and    #
# saying which needed a matched control rather than an argument.           #
#                                                                          #
# HOW IT IS MATCHED. Nothing here is assumed. For every real age           #
# comparison an honest one is simulated carrying THAT comparison's own arm #
# sizes, pooled SD and reported decimals: arms drawn from one common       #
# population, then rounded exactly as the sponsor rounded. Observed and    #
# simulated exceedance rates are then compared INSIDE bins of reporting    #
# granularity - the rounding step divided by the standard error of the arm #
# mean - so the comparison is like for like at every level of coarseness.  #
#                                                                          #
# THE ANSWER. The excess is present in every bin, including the finest,    #
# where 71% of comparisons live and rounding is negligible:                #
#                                                                          #
#   granularity        n    observed    honest   excess                    #
#   [0, 0.1]       83949      12.67%     6.21%    +6.46                    #
#   (0.5, 1]        5121      16.77%     6.21%   +10.56                    #
#   (2, Inf)         993      37.46%    14.90%   +22.56                    #
#   ALL           118311      13.52%     6.24%    +7.28                    #
#                                                                          #
# Rounding is real and it adds - the honest rate itself climbs from 6.2%   #
# to 14.9% across the bins, which is the tautology test showing up in the  #
# registry. But it is not the explanation. Age arms differ more than       #
# randomisation predicts at roughly twice the expected rate even where     #
# the reported precision is ample.                                         #
############################################################################

.libPaths(c(file.path(Sys.getenv("HOME"), "Rlib_barnett"),
            readLines(file.path(Sys.getenv("HOME"), "deps_lib.txt"))[1],
            .libPaths()))
d <- file.path(Sys.getenv("HOME"), "work", "ctgov_corpus")
cont <- read.csv(file.path(d, "baselineContinuous.csv"), stringsAsFactors = FALSE)
a <- cont[grepl("^age,? ?continuous$", tolower(trimws(cont$ROW))) &
          !is.na(cont$N) & !is.na(cont$MEAN) & !is.na(cont$SD) & cont$N > 1, ]

# Rebuild the real pairwise t-statistics for age, and the honest ones.
set.seed(20260830)
key <- paste(a$TRIAL, a$ROW)
sp  <- split(a, key)
cat("age row-groups:", length(sp), "\n")

obs <- list(); sim <- list(); gran <- list()
for (g in sp) {
  if (nrow(g) < 2) next
  rp <- g$ROUND_MEAN; rp[is.na(rp)] <- 1
  # pooled mean and SD: the honest common population
  M <- sum(g$N * g$MEAN) / sum(g$N)
  S <- sqrt(sum((g$N - 1) * g$SD^2) / sum(g$N - 1))
  if (!is.finite(S) || S <= 0) next
  # honest arm means, rounded exactly as this trial rounded
  mS <- round(M + S / sqrt(g$N) * stats::rnorm(nrow(g)), rp)
  sS <- round(S * sqrt(stats::rchisq(nrow(g), g$N - 1) / (g$N - 1)), rp)
  for (i in 1:(nrow(g) - 1)) for (j in (i + 1):nrow(g)) {
    n1 <- g$N[i]; n2 <- g$N[j]
    se <- function(s1, s2) sqrt((1/n1 + 1/n2) *
            ((n1-1)*s1^2 + (n2-1)*s2^2) / (n1+n2-2))
    e1 <- se(g$SD[i], g$SD[j]); e2 <- se(sS[i], sS[j])
    if (!is.finite(e1) || e1 <= 0 || !is.finite(e2) || e2 <= 0) next
    obs[[length(obs)+1]]  <- (g$MEAN[i] - g$MEAN[j]) / e1
    sim[[length(sim)+1]]  <- (mS[i] - mS[j]) / e2
    gran[[length(gran)+1]] <- (10^(-min(rp[i], rp[j]))) / (S / sqrt(min(n1, n2)))
  }
}
obs <- unlist(obs); sim <- unlist(sim); gran <- unlist(gran)
ok <- is.finite(obs) & is.finite(sim) & is.finite(gran)
obs <- obs[ok]; sim <- sim[ok]; gran <- gran[ok]
cat("age comparisons:", length(obs), "\n\n")

br <- c(0, 0.1, 0.25, 0.5, 1, 2, Inf)
b  <- cut(gran, br, include.lowest = TRUE)
cat("Exceedance of |t| > 1.96, observed vs an honest simulation matched\n")
cat("row by row on arm size, pooled SD and REPORTED DECIMALS.\n")
cat("granularity = rounding step / standard error of the arm mean.\n\n")
cat(sprintf("%-14s %8s %10s %10s %9s\n",
            "granularity", "n", "observed", "honest", "excess"))
for (lv in levels(b)) {
  s <- b == lv
  if (sum(s) < 200) next
  o <- 100 * mean(abs(obs[s]) > 1.959964)
  e <- 100 * mean(abs(sim[s]) > 1.959964)
  cat(sprintf("%-14s %8d %9.2f%% %9.2f%% %+8.2f\n", lv, sum(s), o, e, o - e))
}
o <- 100 * mean(abs(obs) > 1.959964); e <- 100 * mean(abs(sim) > 1.959964)
cat(sprintf("\n%-14s %8d %9.2f%% %9.2f%% %+8.2f\n", "ALL", length(obs), o, e, o - e))
