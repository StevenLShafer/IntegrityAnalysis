# correlationNull.R - what an HONEST corpus of correlated baseline tables
# looks like to both instruments.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5), as the control  #
# for corpus/barnettCorpus.R. LOCAL CORPUS TOOLING ONLY.                   #
#                                                                          #
# WHY THIS EXISTS, and it is the most important comment in this directory. #
#                                                                          #
# Running both instruments over the registry corpus produced two findings  #
# that look like evidence of anomalous trials and are not:                 #
#                                                                          #
#   * Barnett flags 12.7% of trials (5.0% under-, 7.7% over-dispersed),    #
#     against 0.2% for a simulated null.                                   #
#   * Our own trial p-values pile up at BOTH ends: +15.6% in the lowest    #
#     decile, +34.1% in the highest, with a -16.7% trough in the middle.   #
#                                                                          #
# The simulated null those were measured against drew each t-statistic     #
# INDEPENDENTLY. Real baseline tables are nothing like that. Age, weight   #
# and BMI are one variable measured three ways; height and weight track    #
# each other; a panel of labs moves together. When the rows of a table     #
# are correlated, the t-statistics are correlated, and the spread of a     #
# correlated set of t-statistics is more variable than the spread of an    #
# independent set - in BOTH directions. Sometimes they cluster near zero   #
# (reads as under-dispersion), sometimes they cluster away from it (reads  #
# as over-dispersion).                                                     #
#                                                                          #
# BOTH INSTRUMENTS ASSUME THE ROWS ARE INDEPENDENT. Barnett's likelihood   #
# treats each t as a separate draw. Ours combines per-row p-values across  #
# rows by Stouffer, whose variance term sqrt(k) is only correct when the   #
# rows are independent. This is a COMMON-MODE assumption, so the two       #
# agreeing with each other says nothing about whether it holds - which is  #
# exactly the trap this script exists to avoid.                            #
#                                                                          #
# Barnett measured it himself (Table 2 of the paper), on honest simulated  #
# data with an exchangeable correlation between variables:                 #
#                                                                          #
#     scenario                        not flagged / under / over           #
#     correlated continuous, rho 0.2      99.0 / 1.0 / 0                   #
#     correlated continuous, rho 0.6      89.0 / 5.6 / 5.4                 #
#     our registry corpus                 87.3 / 5.0 / 7.7                 #
#                                                                          #
# The corpus sits essentially on top of his honest rho = 0.6 row. That is  #
# the hypothesis this script tests against OUR table shapes rather than    #
# his simulated ones, because agreement with a published simulation run    #
# on different shapes is suggestive, not conclusive.                       #
#                                                                          #
# HOW THE SIMULATION WORKS. Every trial keeps its real geometry - its arm  #
# sizes, its number of rows, its pooled means and SDs, its rounding - and  #
# only the randomisation is redone, honestly, with a chosen correlation    #
# between variables. For arm a and variable j:                             #
#                                                                          #
#   mean[a,j] = m[j] + s[j]/sqrt(n[a]) * z[a,j],  cor(z[a,]) = rho         #
#   sd[a,j]   = s[j] * sqrt(chisq(n[a]-1) / (n[a]-1))                      #
#                                                                          #
# then rounded to the decimals the registry actually reported. This is     #
# exact under normality, and far cheaper than simulating participants.     #
#                                                                          #
# CONSERVATIVE BY CONSTRUCTION: categorical rows are simulated             #
# INDEPENDENTLY of each other and of the continuous rows, because          #
# correlating them needs a latent model this does not attempt. Real        #
# tables correlate those too, so any correlation-induced flag rate here    #
# UNDERSTATES the real one. If the simulated rate still reaches the        #
# observed rate, the argument holds a fortiori.                            #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/correlationNull.R [outDir] [nTrials] [rho,rho,...]      #
############################################################################

args    <- commandArgs(trailingOnly = TRUE)
outDir  <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
nTrials <- if (length(args) >= 2) as.integer(args[2]) else 3000L
rhos    <- if (length(args) >= 3)
  as.numeric(strsplit(args[3], ",")[[1]]) else c(0, 0.2, 0.4, 0.6, 0.8)

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis); library(shiny); library(foreach)
  library(MBESS); library(Rfast); library(dqrng)
}))
source(file.path(root, "corpus", "parallelHelper.R"))

cont <- utils::read.csv(file.path(outDir, "baselineContinuous.csv"),
                        stringsAsFactors = FALSE)
cats <- utils::read.csv(file.path(outDir, "baselineCategorical.csv"),
                        stringsAsFactors = FALSE)

# Only trials the real run could actually test.
b <- utils::read.csv(file.path(outDir, "barnett.csv"), stringsAsFactors = FALSE)
b <- b[b$nStat >= 3 & is.finite(b$pDispersed), ]
set.seed(20260830)
pick <- sample(b$TRIAL, min(nTrials, nrow(b)))
cont <- cont[cont$TRIAL %in% pick, ]
cats <- cats[cats$TRIAL %in% pick, ]
contBy <- split(cont, cont$TRIAL)
catsBy <- split(cats, cats$TRIAL)
cat("simulating", length(pick), "trials at rho =",
    paste(rhos, collapse = ", "), "\n")

simTrial <- function(nct, rho) {
  cn <- contBy[[nct]]; ct <- catsBy[[nct]]
  parts <- list(); categoryNames <- character(0)

  if (!is.null(cn) && nrow(cn)) {
    cn <- cn[!is.na(cn$N) & !is.na(cn$MEAN) & !is.na(cn$SD) & cn$N > 1, ]
    if (nrow(cn)) {
      rows <- unique(cn$ROW)
      k <- length(rows)
      arms <- unique(cn$ARM)
      # One exchangeable draw per ARM across the k variables. Correlation
      # is between VARIABLES within an arm, which is what a participant-
      # level correlation between variables induces in the arm means.
      z <- matrix(NA_real_, length(arms), k)
      for (a in seq_along(arms)) {
        e <- stats::rnorm(k)
        common <- stats::rnorm(1)
        z[a, ] <- sqrt(rho) * common + sqrt(1 - rho) * e
      }
      # THE ARMS MUST SHARE ONE TRUE MEAN. Under honest randomisation
      # every arm is drawn from the same population, so the simulated
      # arm means have to be centred on a COMMON value - the pooled mean
      # across the real arms - with fresh independent noise added to
      # each. Adding noise to each arm's OWN reported mean instead would
      # keep the real between-arm differences and pile new ones on top,
      # inflating between-arm dispersion by sqrt(2) and manufacturing
      # exactly the skew toward p = 1 that this script is meant to
      # measure. (Written after doing precisely that and getting a
      # spectacular, wrong answer.)
      pooled <- do.call(rbind, lapply(rows, function(r) {
        k <- cn[cn$ROW == r, ]
        data.frame(ROW = r,
                   M = sum(k$N * k$MEAN) / sum(k$N),
                   S = sqrt(sum((k$N - 1) * k$SD^2) / sum(k$N - 1)),
                   stringsAsFactors = FALSE)
      }))
      d <- cn
      for (i in seq_len(nrow(d))) {
        ai <- match(d$ARM[i], arms); ri <- match(d$ROW[i], rows)
        n <- d$N[i]
        s <- pooled$S[ri]
        if (!is.finite(s) || s <= 0) s <- d$SD[i]
        d$MEAN[i] <- round(pooled$M[ri] + s / sqrt(n) * z[ai, ri],
                           if (is.na(d$ROUND_MEAN[i])) 2 else d$ROUND_MEAN[i])
        d$SD[i] <- round(s * sqrt(stats::rchisq(1, n - 1) / (n - 1)),
                         if (is.na(d$ROUND_DISPERSION[i])) 2 else
                           d$ROUND_DISPERSION[i])
      }
      parts$cont <- data.frame(
        TRIAL = nct, ROW = d$ROW, N = d$N, MEAN = d$MEAN, SD = d$SD,
        SE = NA_real_, Q1 = NA_real_, Q3 = NA_real_,
        ROUND_MEAN = d$ROUND_MEAN, ROUND_DISPERSION = d$ROUND_DISPERSION,
        ROUND_OBSERVATION = d$ROUND_OBSERVATION, stringsAsFactors = FALSE)
    }
  }

  if (!is.null(ct) && nrow(ct)) {
    # Each categorical ROW resimulated honestly: arm totals kept, counts
    # redrawn from the pooled proportions. Independent across rows - see
    # the header on why that makes this conservative.
    lev <- unique(ct$CATEGORY)
    categoryNames <- paste0("C", seq_along(lev)); names(categoryNames) <- lev
    key <- paste(ct$ROW, ct$ARM, sep = "\r"); ord <- !duplicated(key)
    w <- data.frame(TRIAL = nct, ROW = ct$ROW[ord], N = NA_real_,
                    MEAN = NA_real_, SD = NA_real_, SE = NA_real_,
                    Q1 = NA_real_, Q3 = NA_real_, ROUND_MEAN = NA_real_,
                    ROUND_DISPERSION = NA_real_, ROUND_OBSERVATION = NA_real_,
                    stringsAsFactors = FALSE)
    for (nm in categoryNames) w[[nm]] <- NA_real_
    idx <- match(key, key[ord])
    obs <- matrix(0, nrow(w), length(lev))
    for (i in seq_len(nrow(ct)))
      obs[idx[i], match(ct$CATEGORY[i], lev)] <- ct$COUNT[i]
    for (r in unique(w$ROW)) {
      rr <- which(w$ROW == r)
      tab <- obs[rr, , drop = FALSE]
      keep <- colSums(tab) > 0
      if (sum(keep) < 2) next
      p <- colSums(tab[, keep, drop = FALSE]) / sum(tab[, keep])
      for (a in seq_along(rr)) {
        tot <- sum(tab[a, keep])
        if (tot < 1) next
        obs[rr[a], keep] <- stats::rmultinom(1, tot, p)[, 1]
      }
    }
    for (j in seq_along(lev)) w[[categoryNames[j]]] <- obs[, j]
    parts$cat <- w
  }

  if (!length(parts)) return(NULL)
  allCols <- unique(unlist(lapply(parts, names)))
  parts <- lapply(parts, function(p) {
    for (nm in setdiff(allCols, names(p))) p[[nm]] <- NA_real_
    p[, allCols, drop = FALSE]
  })
  DATA <- do.call(rbind, parts)
  ts <- barnettTStats(DATA, CategoryNames = unname(categoryNames))
  r  <- barnettDispersion(ts)

  # OUR OWN INSTRUMENT ON THE SAME HONEST TABLE. This is the number the
  # app most needs. P_Calc combines per-row p-values across rows by
  # Stouffer, whose sqrt(k) denominator is correct only when the rows are
  # independent. If our trial p-values are non-uniform HERE - on data
  # generated honestly, carrying the real corpus's arm sizes, row counts,
  # multi-arm comparisons, category levels and rounding - then the
  # pile-up seen in the real corpus is a property of that combination
  # rule and of the table geometry, not of the trials.
  ourP <- tryCatch({
    set.seed(1); dqrng::dqset.seed(1)
    utils::capture.output(
      pp <- IntegrityAnalysis:::P_Calc(nct, DATA, unname(categoryNames),
                                       100000))
    sm <- pp[!is.na(pp$ROW) & pp$ROW == "Summary", , drop = FALSE]
    if (nrow(sm)) suppressWarnings(as.numeric(sm$P[1])) else NA_real_
  }, error = function(e) NA_real_)

  data.frame(TRIAL = nct, rho = rho, nStat = r$nStat,
             pDispersed = r$pDispersed, epsilon = r$epsilon,
             ourP = ourP, stringsAsFactors = FALSE)
}

out <- list()
for (rho in rhos) {
  t0 <- Sys.time()
  r <- iaParallel(pick, function(nct)
         tryCatch(simTrial(nct, rho), error = function(e) NULL),
       export = c("contBy", "catsBy", "simTrial", "rho"), quiet = TRUE)
  r <- do.call(rbind, Filter(Negate(is.null), r))
  r <- r[r$nStat >= 3 & is.finite(r$pDispersed), ]
  out[[length(out) + 1L]] <- r
  cat(sprintf("  rho %.1f: %5d trials, %5.1f%% flagged (%4.1f%% under, %4.1f%% over)  [%.1f min]\n",
              rho, nrow(r), 100 * mean(r$pDispersed > 0.95),
              100 * mean(r$pDispersed > 0.95 & r$epsilon > 0),
              100 * mean(r$pDispersed > 0.95 & r$epsilon < 0),
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
sim <- do.call(rbind, out)
utils::write.csv(sim, file.path(outDir, "correlationNull.csv"),
                 row.names = FALSE)

cat("\nobserved in the real corpus: 12.7% flagged (5.0% under, 7.7% over)\n")
cat("Barnett's own honest rho=0.6 simulation: 11.0% (5.6% under, 5.4% over)\n")

# Our own p-values on the honest simulated tables. Uniform is what an
# honest corpus SHOULD give; any departure is the combination rule and
# the table geometry, because these data were generated honestly.
cat("\nOUR trial p on the same honest tables - deciles, % departure from uniform\n")
cat("(the real corpus showed +15.6% in the lowest decile and +34.1% in the\n")
cat(" highest, with a -16.7% trough in the middle)\n\n")
for (rho in rhos) {
  q <- sim$ourP[sim$rho == rho & is.finite(sim$ourP)]
  if (length(q) < 100) next
  h <- table(cut(q, breaks = seq(0, 1, 0.1), include.lowest = TRUE))
  cat(sprintf("  rho %.1f (n=%d): ", rho, length(q)))
  cat(paste(sprintf("%+.0f%%", 100 * (as.numeric(h) / (length(q) / 10) - 1)),
            collapse = " "), "\n")
  cat(sprintf("           alarm rate p < 0.01: %.2f%%  (1%% expected)\n",
              100 * mean(q < 0.01)))
}

cat("\nwritten:", file.path(outDir, "correlationNull.csv"), "\n")
