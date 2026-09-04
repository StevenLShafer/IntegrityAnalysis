# syntheticTiesCheck.R - four ways to combine tie-ridden rows into a trial
# p, measured on honest and on fabricated synthetic trials.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-03 by Claude Code (model Claude Fable 5.1) at Steve      #
# Shafer's direction, after the three-row synthetic sweep                  #
# (corpus/syntheticAgeWeightCheck.R) showed the screen failing in the SAFE #
# direction at integer reporting and large N: "we still fail for integer  #
# AGE and large N. That needs to be fixed, if possible. The problem is     #
# that we don't know how to resolve ties." He asked for the proposed       #
# exact-combination and log-likelihood-ratio analyses, for "pivotal        #
# methods and log-of-odds approaches", and for his own idea: "draw         #
# inference from the ties by what we can observe: the counts above and     #
# below the tie. Fit to a distribution (SSE falls in a chi-squared         #
# distribution, I think), it will allow us to peek inside the ties and     #
# figure out how they should be partitioned."                              #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHAT IS WRONG. P_Calc's row statistic is the sum of squared deviations   #
# of the ROUNDED arm means from their grand mean, and its null is          #
# simulated with the table's own rounding (the Carlisle-Shafer            #
# contribution). With integer means and N in the hundreds the rounded     #
# arm means take a handful of values, so the statistic takes a handful    #
# of values and the row's mid-p a handful too. Stouffer then converts     #
# each mid-p to a normal score AS IF it were uniform, and the trial p     #
# inherits the lumps: at integer age and N >= 100, 0 % of honest rows     #
# fall below p = 0.05 and 1.9-2.8 % of honest trials do, against the      #
# nominal 5 %.                                                             #
#                                                                          #
# WHAT IS NOT WRONG, and cannot be fixed at the row: two arms that both    #
# report "55" carry one piece of evidence, how often honest sampling      #
# produces equal integers, and no statistic extracts more.                #
#                                                                          #
# THE CANDIDATES, all computed on the SAME simulated trials:              #
#   A  current: Stouffer on the row mid-p's, normal assumption (sumz).    #
#   B  exact Stouffer: the same sum of normal scores, but its null        #
#      distribution taken from the simulation - every null replicate      #
#      gets its own mid-p rank within its row, its own z, and the sum     #
#      across rows; the trial p is the fraction of replicate sums at or   #
#      beyond the observed sum. Calibrated by construction for any        #
#      rounding; no dice in a reported number.                            #
#   B2 exact logit: as B with the log-odds combining function             #
#      (Mudholkar-George) in place of the normal score.                   #
#   C  log-likelihood ratio: per row log P(cell | arms too similar) -     #
#      log P(cell | honest), the "cell" being the rounded pattern the     #
#      table reports and "too similar" being between-arm dispersion       #
#      shrunk by theta (0 = identical means, 0.5 = halved). Summed over   #
#      rows, null by simulation. Neyman-Pearson optimal for that          #
#      alternative; needs the alternative stated.                         #
#   D  Steve's partition: the tie mass P(eq) is split by the continuous   #
#      chi-square the unrounded statistic follows, rather than in half.   #
#      D1 places the reported value where it sits (a zero difference at   #
#      the cell's floor); D2 places it at the cell's chi-square median.   #
#      Both remain one number per reported pattern; the experiment says  #
#      whether that matters.                                              #
#                                                                          #
# THE TRIALS. As the three-row sweep: age ~ N(55, 13) and weight ~        #
# N(80, 18), each participant's values rounded to integers; sex ~        #
# Bernoulli(0.5). Two equal arms of N. Reported means and SDs to `dec`   #
# decimals. Honest trials are drawn and reported. Fabricated trials are  #
# drawn honestly and then REPORTED with the between-arm differences of   #
# the means (and of the sex proportions) shrunk by thetaFab - the        #
# fabricator who copies one arm's numbers into the other (0) or halves   #
# the disagreement (0.5); SDs stay honest.                                #
#                                                                          #
# THE NULL AND THE ALTERNATIVE, per row, exactly as P_Calc builds them:   #
# common location ~ N(grand mean, SD/sqrt(N)), N observations per arm    #
# ~ N(location, pooled SD) rounded to the observation precision, arm     #
# means rounded to the reported decimals, statistic the unweighted sum   #
# of squared deviations from the N-weighted grand mean. The alternative  #
# for C shrinks the simulated arm means toward their grand mean by       #
# theta BEFORE rounding. Sex rows: chi-square under fixed margins        #
# (r2dtable) as in P_Calc; the alternative shrinks the proportions.      #
############################################################################
#
# Usage:
#   Rscript corpus/syntheticTiesCheck.R <outDir> <nHonest> <nFab> <M> \
#          [decimals=0,1,2] [Ns=20,100,500,1000] [share=k/n] [workers]
# One CSV per cell in <outDir> (resumable: a finished cell is skipped),
# a progress line per 50 trials in <outDir>/progress.log, and a per-trial
# row: cell, arm, trial, the row mid-p's, and the trial p under A, B, B2,
# C0, C50, D1, D2. corpus/syntheticTiesReport.R summarises.

suppressPackageStartupMessages({ library(parallel) })
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("usage: outDir nHonest nFab M [decimals] [Ns] [share] [workers]")
outDir  <- args[1]; nHonest <- as.integer(args[2]); nFab <- as.integer(args[3])
M       <- as.integer(args[4])
decs    <- if (length(args) >= 5) as.integer(strsplit(args[5], ",")[[1]]) else c(0L, 1L, 2L)
Ns      <- if (length(args) >= 6) as.integer(strsplit(args[6], ",")[[1]]) else c(20L, 100L, 500L, 1000L)
share   <- if (length(args) >= 7) as.integer(strsplit(args[7], "/")[[1]]) else c(1L, 1L)
workers <- if (length(args) >= 8) as.integer(args[8]) else max(1L, detectCores() - 1L)
dir.create(outDir, showWarnings = FALSE, recursive = TRUE)
logf <- file.path(outDir, "progress.log")
say  <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n", file = logf, append = TRUE)

# ---- the population -------------------------------------------------------
POP <- list(age = c(mu = 55, sd = 13), weight = c(mu = 80, sd = 18))
thetas <- c(0, 0.5)          # alternatives for C, and fabrication strengths

# ---- one continuous row: null / alternative statistics -------------------
# mean1, mean2, sd1, sd2 as REPORTED (rounded); N per arm; dec decimals.
# Returns the observed statistic and the simulated null and alternative
# statistic vectors (length M each), all on the rounded scale.
rowSims <- function(means, sds, N, dec, M, thetas) {
  Nt <- 2 * N
  grand <- mean(means)                       # equal arms: N-weighted = plain
  sdPool <- sqrt(mean(sds^2))
  sem <- sdPool / sqrt(N)
  obs <- sum((means - grand)^2)
  loc <- rnorm(M, grand, sem)
  # arm means before rounding, honest: the mean of N rounded observations
  armMean <- function() {
    x <- matrix(rnorm(N * M, rep(loc, N), sdPool), nrow = M)
    rowMeans(round(x, 0))                    # observations to integers
  }
  m1 <- armMean(); m2 <- armMean()
  statOf <- function(a, b) {
    ra <- round(a, dec); rb <- round(b, dec)
    g <- (ra + rb) / 2
    (ra - g)^2 + (rb - g)^2
  }
  nullS <- statOf(m1, m2)
  g <- (m1 + m2) / 2
  altS <- lapply(thetas, function(th) statOf(g + th * (m1 - g), g + th * (m2 - g)))
  list(obs = obs, null = nullS, alt = altS,
       # for D: the unrounded chi-square scale of the statistic
       scale = sdPool^2 / N, dec = dec)
}

# ---- one categorical row (sex): counts of males per arm -------------------
catSims <- function(k, N, M, thetas) {
  tab <- rbind(c(k[1], N - k[1]), c(k[2], N - k[2]))
  tab <- tab[, colSums(tab) > 0, drop = FALSE]
  if (ncol(tab) < 2) return(NULL)
  E <- outer(rowSums(tab), colSums(tab)) / sum(tab)
  chi <- function(t) sum((t - E)^2 / E)
  obs <- chi(tab)
  nullS <- vapply(r2dtable(M, rowSums(tab), colSums(tab)), chi, numeric(1))
  pbar <- sum(k) / (2 * N)
  altS <- lapply(thetas, function(th) {
    p1 <- rbinom(M, N, pbar) / N; p2 <- rbinom(M, N, pbar) / N
    g <- (p1 + p2) / 2
    a <- round(N * (g + th * (p1 - g))); b <- round(N * (g + th * (p2 - g)))
    Ea <- E   # the observed margins' expectation, as the statistic is defined
    (a - Ea[1, 1])^2 / Ea[1, 1] + (N - a - Ea[1, 2])^2 / Ea[1, 2] +
      (b - Ea[2, 1])^2 / Ea[2, 1] + (N - b - Ea[2, 2])^2 / Ea[2, 2]
  })
  list(obs = obs, null = nullS, alt = altS, scale = NA_real_, dec = NA_integer_)
}

# ---- the row summaries every candidate needs ------------------------------
floorP <- function(p, M) pmin(pmax(p, 1 / (M + 1)), 0.9999)
midpOf <- function(obs, sims) {
  M <- length(sims)
  (sum(sims < obs) + sum(sims == obs) / 2) / M
}
# mid-p of EVERY replicate within its own null: average ranks give exactly
# (kLess + kEq/2 + 1/2), so (rank - 1/2)/M is the mid-p
midpAll <- function(sims) (rank(sims, ties.method = "average") - 0.5) / length(sims)
zUpper  <- function(p) qnorm(p, lower.tail = FALSE)
logitUp <- function(p) log((1 - p) / p)

# log-likelihood ratio of a statistic VALUE against the empirical null and
# alternative frequencies (values are on a grid, so exact ties are real;
# add-half smoothing keeps an unseen cell finite)
llrTable <- function(nullS, altS) {
  key <- function(v) as.character(signif(v, 10))
  kn <- key(nullS); ka <- key(altS)
  fn <- table(kn); fa <- table(ka)
  M <- length(nullS); eps <- 0.5 / M
  f <- function(v) {
    k <- key(v)
    pn <- as.numeric(fn[k]); pa <- as.numeric(fa[k])
    pn[is.na(pn)] <- 0; pa[is.na(pa)] <- 0
    log((pa / M + eps) / (pn / M + eps))
  }
  f
}

# Steve's partition (D) for a continuous row: the tie mass at the observed
# rounded statistic is split by the continuous chi-square(1) the UNROUNDED
# statistic follows (for two equal arms, stat / (sd^2/N) ~ chi-square with
# 1 df up to the observation rounding). The reported pattern's cell in
# difference space is |diff| in [d - h, d + h], h = 10^-dec (each mean is
# rounded independently, so the difference's cell is twice the half-width).
# D1 puts the reported value at its own position (a zero difference at the
# floor); D2 at the chi-square median of the cell.
partitionD <- function(obs, sims, scale, dec) {
  M <- length(sims)
  kLess <- sum(sims < obs); kEq <- sum(sims == obs)
  if (kEq == 0) return(c(D1 = (kLess) / M, D2 = (kLess) / M))
  d  <- sqrt(2 * obs)                       # |diff| implied by the statistic
  h  <- 10^(-dec)
  lo <- max(0, d - h); hi <- d + h
  # chi-square(1) CDF of the statistic scale: stat = diff^2/2, so
  # u = diff^2 / (2 * scale) ... F(diff) = P(|Z| <= diff / sqrt(2 scale))
  Fd <- function(x) 2 * pnorm(x / sqrt(2 * scale)) - 1
  Flo <- Fd(lo); Fhi <- Fd(hi)
  w1 <- if (Fhi > Flo) (Fd(d) - Flo) / (Fhi - Flo) else 0.5
  # the cell's median under the chi-square: the x with F(x) = (Flo+Fhi)/2
  xm <- sqrt(2 * scale) * qnorm(((Flo + Fhi) / 2 + 1) / 2)
  w2 <- if (Fhi > Flo) (Fd(xm) - Flo) / (Fhi - Flo) else 0.5
  c(D1 = (kLess + kEq * w1) / M, D2 = (kLess + kEq * w2) / M)
}

# ---- one trial: all candidates ---------------------------------------------
trialP <- function(rows, M, thetas) {
  # rows: list of rowSims/catSims results (NULL entries dropped)
  rows <- rows[!vapply(rows, is.null, logical(1))]
  k <- length(rows)
  midObs <- vapply(rows, function(r) floorP(midpOf(r$obs, r$null), M), numeric(1))
  # A: current
  zObs <- zUpper(midObs)
  pA <- pnorm(sum(zObs) / sqrt(k), lower.tail = FALSE)
  # B / B2: exact null of the sum
  Zrep <- sapply(rows, function(r) zUpper(floorP(midpAll(r$null), M)))     # M x k
  Lrep <- sapply(rows, function(r) logitUp(floorP(midpAll(r$null), M)))
  Tobs <- sum(zObs); Trep <- rowSums(Zrep)
  pB  <- (sum(Trep > Tobs) + sum(Trep == Tobs) / 2) / M
  Lobs <- sum(logitUp(midObs)); Lr <- rowSums(Lrep)
  pB2 <- (sum(Lr > Lobs) + sum(Lr == Lobs) / 2) / M
  # C: log-likelihood ratio per theta
  pC <- vapply(seq_along(thetas), function(j) {
    fs <- lapply(rows, function(r) llrTable(r$null, r$alt[[j]]))
    obsL <- sum(vapply(seq_along(rows), function(i) fs[[i]](rows[[i]]$obs), numeric(1)))
    repL <- rowSums(sapply(seq_along(rows), function(i) fs[[i]](rows[[i]]$null)))
    (sum(repL > obsL) + sum(repL == obsL) / 2) / M
  }, numeric(1))
  # D1 / D2: Steve's partition on continuous rows, mid-p elsewhere, Stouffer
  pd <- sapply(rows, function(r) {
    if (is.na(r$scale)) { p <- midpOf(r$obs, r$null); c(D1 = p, D2 = p) }
    else partitionD(r$obs, r$null, r$scale, r$dec)
  })
  pD1 <- pnorm(sum(zUpper(floorP(pd["D1", ], M))) / sqrt(k), lower.tail = FALSE)
  pD2 <- pnorm(sum(zUpper(floorP(pd["D2", ], M))) / sqrt(k), lower.tail = FALSE)
  out <- c(unname(midObs[1]), unname(midObs[2]), if (k >= 3) unname(midObs[3]) else NA,
           pA, pB, pB2, pC[1], pC[2], pD1, pD2)
  names(out) <- c("pAge", "pWeight", "pSex", "A", "B", "B2", "C0", "C50", "D1", "D2")
  out
}

# ---- draw one trial, report it, score it -----------------------------------
oneTrial <- function(N, dec, arm, thetaFab, M, thetas) {
  draw <- function(pop) round(rnorm(2 * N, pop["mu"], pop["sd"]), 0)
  rows <- list()
  for (v in c("age", "weight")) {
    x <- draw(POP[[v]]); a <- x[1:N]; b <- x[(N + 1):(2 * N)]
    means <- c(mean(a), mean(b)); sds <- c(sd(a), sd(b))
    if (arm != "honest") { g <- mean(means); means <- g + thetaFab * (means - g) }
    means <- round(means, dec); sds <- round(sds, max(dec, 1L))
    rows[[v]] <- rowSims(means, sds, N, dec, M, thetas)
  }
  s <- rbinom(2 * N, 1, 0.5); k <- c(sum(s[1:N]), sum(s[(N + 1):(2 * N)]))
  if (arm != "honest") { g <- mean(k); k <- round(g + thetaFab * (k - g)) }
  rows[["sex"]] <- catSims(k, N, M, thetas)
  trialP(rows, M, thetas)
}

# ---- cells, shares, resume ---------------------------------------------------
cells <- expand.grid(N = Ns, dec = decs, arm = c("honest", "fab0", "fab50"),
                     stringsAsFactors = FALSE)
cells$n <- ifelse(cells$arm == "honest", nHonest, nFab)
cells$thetaFab <- ifelse(cells$arm == "fab0", 0, ifelse(cells$arm == "fab50", 0.5, NA))
cells$seed <- seq_len(nrow(cells))          # per-cell offset; see set.seed below
mine <- which(((seq_len(nrow(cells)) - 1L) %% share[2]) == (share[1] - 1L))
say("start: ", length(mine), " of ", nrow(cells), " cells (share ", share[1], "/", share[2],
    "), M=", M, ", workers=", workers)
for (ci in mine) {
  cell <- cells[ci, ]
  fn <- file.path(outDir, sprintf("cell_N%d_dec%d_%s.csv", cell$N, cell$dec, cell$arm))
  if (file.exists(fn) && nrow(read.csv(fn)) >= cell$n) { say("skip done ", basename(fn)); next }
  t0 <- Sys.time()
  say("cell ", basename(fn), ": ", cell$n, " trials")
  res <- mclapply(seq_len(cell$n), function(i) {
    set.seed(20260904L + cell$seed * 100000L + i)   # < 2^31, per cell and trial
    p <- tryCatch(oneTrial(cell$N, cell$dec, cell$arm, cell$thetaFab, M, thetas),
                  error = function(e) rep(NA_real_, 10))
    if (i %% 50 == 0) say("  ", basename(fn), " trial ", i)
    c(trial = i, p)
  }, mc.cores = workers, mc.set.seed = FALSE)
  out <- as.data.frame(do.call(rbind, res))
  out$N <- cell$N; out$dec <- cell$dec; out$arm <- cell$arm
  write.csv(out, fn, row.names = FALSE)
  say("done ", basename(fn), " in ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")
}
say("all cells done")
