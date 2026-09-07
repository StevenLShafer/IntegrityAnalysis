# syntheticTiesReport.R - summarise corpus/syntheticTiesCheck.R output.
#
# PROVENANCE: written 2026-09-03 by Claude Code (model Claude Fable 5.1)
# beside the harness. LOCAL CORPUS TOOLING ONLY.
#
# Usage: Rscript corpus/syntheticTiesReport.R <dir or dirs, comma-separated>
#
# For every cell (N x decimals) and every candidate statistic:
#   honest arm   - calibration: % of trials with p < 0.05, % with p > 0.95,
#                  the Kolmogorov-Smirnov p against Uniform(0,1), and the
#                  decile deviations (% over/under 10 % per bin);
#   fab0, fab50  - detection: % of trials with p < 0.05 and p < 0.01.
# A calibrated statistic shows ~5 / ~5 / KS not small / deciles near 0 on
# honest data; a useful one shows high detection on fab0 and some on fab50.

args <- commandArgs(trailingOnly = TRUE)
dirs <- if (length(args)) strsplit(args[1], ",")[[1]] else "."
files <- unlist(lapply(dirs, function(d) list.files(d, "^cell_.*\\.csv$", full.names = TRUE)))
if (!length(files)) stop("no cell files under ", paste(dirs, collapse = ", "))
dat <- do.call(rbind, lapply(files, read.csv))
dat <- dat[!duplicated(dat[, c("N", "dec", "arm", "trial")]), ]
stats <- c("A", "B", "B2", "C0", "C50", "D1", "D2")
labels <- c(A = "A  current Stouffer (normal)", B = "B  exact Stouffer",
            B2 = "B2 exact logit", C0 = "C0 LLR theta=0", C50 = "C50 LLR theta=0.5",
            D1 = "D1 chi-square partition (floor)", D2 = "D2 chi-square partition (median)")
pct <- function(x) sprintf("%5.2f", 100 * mean(x, na.rm = TRUE))
dec10 <- function(p) {
  b <- table(cut(p[!is.na(p)], seq(0, 1, 0.1), include.lowest = TRUE))
  paste(sprintf("%+d", round(100 * (as.numeric(b) / sum(b) / 0.1 - 1))), collapse = " ")
}
cat("tie experiment:", nrow(dat), "trial rows from", length(files), "cells\n")
cat("honest trials per cell:", paste(unique(table(dat$N[dat$arm == "honest"], dat$dec[dat$arm == "honest"])), collapse = "/"), "\n\n")
for (dec in sort(unique(dat$dec))) for (N in sort(unique(dat$N))) {
  h <- dat[dat$arm == "honest" & dat$N == N & dat$dec == dec, ]
  f0 <- dat[dat$arm == "fab0" & dat$N == N & dat$dec == dec, ]
  f5 <- dat[dat$arm == "fab50" & dat$N == N & dat$dec == dec, ]
  if (!nrow(h)) next
  cat(sprintf("=== N = %d per arm, %d decimal(s): honest %d, fab0 %d, fab50 %d trials\n",
              N, dec, nrow(h), nrow(f0), nrow(f5)))
  cat(sprintf("  row mid-p, honest: age %%<0.05 = %s   weight %s   sex %s\n",
              pct(h$pAge < 0.05), pct(h$pWeight < 0.05), pct(h$pSex < 0.05)))
  cat(sprintf("  %-36s %8s %8s %9s   %-32s %8s %8s %8s\n", "statistic", "%p<.05", "%p>.95", "KS p",
              "deciles (honest)", "fab0<.05", "fab0<.01", "fab50<.05"))
  for (s in stats) {
    p <- h[[s]]
    ks <- tryCatch(suppressWarnings(ks.test(p[!is.na(p)], "punif")$p.value), error = function(e) NA)
    cat(sprintf("  %-36s %8s %8s %9s   %-32s %8s %8s %8s\n", labels[s],
                pct(p < 0.05), pct(p > 0.95), format(signif(ks, 3)), dec10(p),
                if (nrow(f0)) pct(f0[[s]] < 0.05) else "", if (nrow(f0)) pct(f0[[s]] < 0.01) else "",
                if (nrow(f5)) pct(f5[[s]] < 0.05) else ""))
  }
  cat("\n")
}
