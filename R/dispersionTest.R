# dispersionTest.R - Barnett's Bayesian test for under- and over-dispersion
# in a baseline table, evaluated exactly rather than by MCMC.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction: "We should now implement                             #
# https://f1000research.com/articles/11-783. The reason is that we can     #
# also run this on the clinicaltrials.gov table, and see if the            #
# distributions match our distributions. That will distinguish analysis    #
# failures from randomization or trial level failures."                    #
#                                                                          #
# THE METHOD IS NOT OURS. It is Adrian Barnett's: "Automated detection of  #
# over- and under-dispersion in baseline tables in randomised controlled   #
# trials", F1000Research 2022, 11:783 (CC-BY 4.0). Two reference           #
# implementations were read and transcribed on 2026-08-30:                 #
#   github.com/agbarnett/baseline_tables  - the paper's code (WinBUGS)     #
#   github.com/agbarnett/baseline         - the Shiny app (nimble)         #
# The exported functions carry his name so that no reader of this          #
# codebase can mistake the method for ours.                                #
#                                                                          #
# WHAT IT DOES, and why it is a genuinely different instrument from        #
# P_Calc(). Both ask whether a baseline table is too tidy. They ask it in  #
# ways that fail differently:                                              #
#                                                                          #
#   P_Calc (Carlisle-Shafer) simulates the dispersion of arm means and     #
#     reports a p-value per row, combined across rows by Stouffer. It      #
#     tests the WHOLE distribution and is sensitive to its exact shape.    #
#   Barnett reduces every row to a two-sample t-statistic and asks a       #
#     single question of their scatter: is the spread of the t's the       #
#     spread a t-distribution predicts? It tests ONE MOMENT.               #
#                                                                          #
# Barnett's simulation study is the reason this matters here. A test of    #
# the whole distribution - his "uniform test", which is the family our     #
# P_Calc belongs to - fires on skew, on categorical data, and on rounding, #
# none of which is fraud. A test of the variance alone does not, because   #
# a spike in the middle of a p-value histogram moves the distribution      #
# without moving its variance much.                                        #
#                                                                          #
# So when the two disagree on the SAME table, the disagreement is          #
# diagnostic rather than embarrassing: it localises the anomaly to the     #
# shape of the distribution rather than to its spread. That is exactly     #
# the separation Steve asked for.                                          #
#                                                                          #
# WHY THERE IS NO MCMC HERE, which is the one place this file departs      #
# from the reference. Barnett fits the model with WinBUGS (paper) and      #
# nimble (app). For a SINGLE trial his model has exactly two unknowns: a   #
# binary switch and one continuous parameter, epsilon. Everything else is  #
# data. A posterior over one continuous parameter is a one-dimensional     #
# integral, and a one-dimensional integral of a smooth unimodal function   #
# is a solved problem - quadrature evaluates it to more digits than any    #
# feasible chain, in about a millisecond, with no sampler to converge, no  #
# seed, and no new dependency.                                             #
#                                                                          #
# That is not a shortcut. It is the same posterior, and:                   #
#   * exact where MCMC is approximate. The reference app keeps 1,000       #
#     draws; the Monte Carlo standard error on a probability near 0.95 is  #
#     then about 0.007, which is the same order as the distance from the   #
#     0.95 threshold that the method uses to decide whether to flag a      #
#     trial at all.                                                        #
#   * deterministic. This app is deterministic by design and reports       #
#     numbers an editor may have to defend. A flag that moves when         #
#     setSeed() moves is not a finding one can defend.                     #
#   * dependency-free. nimble needs a C++ toolchain at run time. Adding    #
#     that to a Shiny deployment to compute a one-dimensional integral     #
#     would be a poor trade.                                               #
# tests/testthat/test-dispersion.R pins this equivalence against the       #
# reference model actually run under nimble.                               #
#                                                                          #
# THE MODEL, transcribed from bugs_model.txt in both repositories:         #
#                                                                          #
#   d_j        ~ t(location = 0, precision = tau_j, df = df_j)             #
#   tau_j      = (1 / sem_j^2) * gamma                                     #
#   log(gamma) = 0            if flag = 0   ("spike": no dispersion)       #
#              = epsilon      if flag = 1   ("slab")                       #
#   flag       ~ Bernoulli(prior)          prior = 0.5                     #
#   epsilon    ~ Normal(mean 0, variance 10)                               #
#                                                                          #
# gamma multiplies the PRECISION, so gamma > 1 (epsilon > 0) means the     #
# observed differences are TIGHTER than sampling predicts - under-         #
# dispersion, the fraud direction. gamma < 1 is over-dispersion.           #
#                                                                          #
# Writing t_j = d_j / sem_j, the observed t-statistic, the likelihood      #
# depends on the data only through t_j and df_j:                           #
#                                                                          #
#   log L(epsilon) = sum_j [ log dt(t_j * exp(epsilon/2), df_j) ]          #
#                    + n * epsilon / 2                                     #
#                                                                          #
# the dropped term being sum_j log(1 / sem_j), constant in epsilon and     #
# therefore cancelling from every posterior below. The two marginal        #
# likelihoods are then                                                     #
#                                                                          #
#   M0 = L(0)                                    (spike, a point mass)     #
#   M1 = integral of L(epsilon) * phi(epsilon) d epsilon                   #
#                                                                          #
# and P(flag = 1 | data) follows by Bayes. M1 is the integral this file    #
# evaluates.                                                               #
#                                                                          #
# DEGREES OF FREEDOM. The reference passes df = n1 + n2 - 1 to the model,  #
# while the t-statistic it feeds in is built with n1 + n2 - 2. The paper   #
# states n1 + n2 - 1. Both are followed here, each in its own place, so    #
# that our numbers match his; the difference is immaterial at any          #
# realistic trial size and is recorded only so nobody later "fixes" it.    #
############################################################################

# Prior variance of the slab. dnorm(0, 0.1) in BUGS is a PRECISION of 0.1,
# i.e. variance 10 - the value the paper states and both reference
# implementations use. Barnett notes that larger values would not
# converge; here it is simply the prior, and nothing depends on a chain
# converging.
.bdSlabVar <- 10

#' Log likelihood of the dispersion multiplier, up to a constant
#'
#' Vectorised over `eps`; `t` and `df` are the per-comparison statistics.
#' The additive constant dropped (`sum(log(1 / sem))`) does not involve
#' `eps` and cancels from every ratio taken below.
#' @noRd
.bdLogLik <- function(eps, t, df) {
  n <- length(t)
  # Columns are comparisons, rows are eps values. dt() recycles `df` in
  # column-major order, so it must be repeated per eps within each column.
  arg  <- outer(exp(eps / 2), t)
  dens <- stats::dt(arg, df = rep(df, each = length(eps)), log = TRUE)
  dim(dens) <- dim(arg)
  rowSums(dens) + n * eps / 2
}

#' Simpson's rule over an evenly spaced grid with an odd number of points
#' @noRd
.bdSimpson <- function(y, dx) {
  k <- length(y)
  w <- c(1, rep(c(4, 2), length.out = k - 2), 1)
  dx / 3 * sum(w * y)
}

#' All unordered pairs of 1..n, as a list of length-2 vectors
#' @noRd
.bdPairs <- function(n) {
  if (n < 2) return(list())
  p <- utils::combn(n, 2)
  lapply(seq_len(ncol(p)), function(k) p[, k])
}

#' Equal-variance two-sample t for means (reference: t.test2)
#' @noRd
.bdContT <- function(m1, m2, s1, s2, n1, n2, zeroSd) {
  patched <- (s1 == 0) || (s2 == 0)
  if (s1 == 0) s1 <- zeroSd
  if (s2 == 0) s2 <- zeroSd
  se <- sqrt((1 / n1 + 1 / n2) *
             ((n1 - 1) * s1^2 + (n2 - 1) * s2^2) / (n1 + n2 - 2))
  if (!is.finite(se) || se <= 0) return(NULL)
  d <- m1 - m2
  if (!is.finite(d)) return(NULL)
  list(mdiff = d, sem = se, t = d / se, patched = patched)
}

#' Two-sample t for proportions
#'
#' Reference: t.test2.binomial, after D'Agostino, Chase and Belanger
#' (1988), "The appropriateness of some common procedures for testing the
#' equality of two independent binomial populations". The half-count
#' adjustment at 0% and 100% is the reference's, and prevents a zero
#' variance from producing an infinite t.
#' @noRd
.bdBinomT <- function(r1, r2, n1, n2) {
  if (n1 < 2 || n2 < 2) return(NULL)
  p1 <- r1 / n1; p2 <- r2 / n2
  if (p1 == 0) p1 <- 0.5 / n1
  if (p2 == 0) p2 <- 0.5 / n2
  if (p1 == 1) p1 <- (n1 - 0.5) / n1
  if (p2 == 1) p2 <- (n2 - 0.5) / n2
  pooled <- ((n1 - 1) * p1 * (1 - p1) + (n2 - 1) * p2 * (1 - p2)) /
            (n1 + n2 - 2)
  se <- sqrt(pooled) * sqrt(1 / n1 + 1 / n2)
  if (!is.finite(se) || se <= 0) return(NULL)
  list(mdiff = p1 - p2, sem = se, t = (p1 - p2) / se)
}

#' Two-sample t-statistics from a validated baseline frame
#'
#' Reduces a validated trial to the vector of t-statistics Barnett's model
#' consumes: one per table row per pair of arms, pooling continuous rows
#' by the usual equal-variance formula and categorical rows by the normal
#' approximation to a difference in proportions.
#'
#' The exclusions follow the paper:
#' \itemize{
#'   \item Medians are dropped. A median with quartiles cannot be turned
#'     into a t-statistic, and the paper excludes them explicitly.
#'   \item For a categorical row with exactly two levels the second level
#'     is dropped. Male and female counts give perfectly anti-correlated
#'     t-statistics, and keeping both would inflate the number of
#'     statistics the model believes it has. Rows with three or more
#'     levels are kept whole, as the paper does - they are correlated on
#'     average but not perfectly, and dropping one would be arbitrary.
#'   \item All pairs of arms are compared. A three-arm trial contributes
#'     A-B, A-C and B-C, per the paper.
#' }
#'
#' @param DATA a validated data frame - the `$DATA` from [validateData()].
#' @param CategoryNames the `$CategoryNames` from [validateData()]. When
#'   `NULL`, every column outside the standard contract is treated as a
#'   category column.
#' @param zeroSd standard deviation substituted when a reported SD is
#'   zero. The reference uses 0.001. **This is scale-dependent**: the same
#'   table in grams and in kilograms gives different t-statistics. Rows
#'   that needed it are marked in the returned `zeroSd` column rather than
#'   silently patched, so they can be excluded or inspected.
#' @return a data frame with one row per comparison: `TRIAL`, `ROW`,
#'   `statistic` ("continuous" or "categorical"), `level`, `arm1`, `arm2`,
#'   `mdiff`, `sem`, `t`, `df`, `size`, `zeroSd`. Zero rows if nothing in
#'   the trial is usable.
#' @seealso [barnettDispersion()], which consumes this.
#' @export
barnettTStats <- function(DATA, CategoryNames = NULL, zeroSd = 0.001) {
  if (is.null(CategoryNames))
    CategoryNames <- setdiff(names(DATA), c(.ppBaseColumns(), "Q1", "Q3"))
  CategoryNames <- intersect(CategoryNames, names(DATA))
  out <- list()
  add <- function(x) out[[length(out) + 1L]] <<- x
  for (trial in unique(DATA$TRIAL)) {
    tr <- DATA[DATA$TRIAL == trial, , drop = FALSE]
    for (row in unique(tr$ROW)) {
      R <- tr[tr$ROW == row, , drop = FALSE]
      if (nrow(R) < 2) next
      isCat <- length(CategoryNames) > 0 &&
               any(!is.na(R[, CategoryNames, drop = FALSE]))
      # Medians: the model needs a mean and an SD, and the paper says so.
      if (!isCat && "Q1" %in% names(R) &&
          (any(!is.na(R$Q1)) || any(!is.na(R$Q3)))) next
      if (isCat) {
        tab <- as.matrix(R[, CategoryNames, drop = FALSE])
        storage.mode(tab) <- "double"
        tab[is.na(tab)] <- 0
        tab <- tab[, colSums(tab) > 0, drop = FALSE]
        if (ncol(tab) < 2) next
        armN <- rowSums(tab)
        if (any(armN < 2)) next
        # Two complementary levels carry one degree of freedom, not two.
        levs <- if (ncol(tab) == 2L) 1L else seq_len(ncol(tab))
        for (k in levs) for (pr in .bdPairs(nrow(tab))) {
          i <- pr[1]; j <- pr[2]
          st <- .bdBinomT(tab[i, k], tab[j, k], armN[i], armN[j])
          if (is.null(st)) next
          add(data.frame(
            TRIAL = trial, ROW = row, statistic = "categorical",
            level = colnames(tab)[k], arm1 = i, arm2 = j,
            mdiff = st$mdiff, sem = st$sem, t = st$t,
            df = armN[i] + armN[j] - 1, size = armN[i] + armN[j],
            zeroSd = FALSE, stringsAsFactors = FALSE))
        }
      } else {
        R <- R[!is.na(R$N) & !is.na(R$MEAN) & !is.na(R$SD) & R$N > 1, ,
               drop = FALSE]
        if (nrow(R) < 2) next
        for (pr in .bdPairs(nrow(R))) {
          i <- pr[1]; j <- pr[2]
          st <- .bdContT(R$MEAN[i], R$MEAN[j], R$SD[i], R$SD[j],
                         R$N[i], R$N[j], zeroSd)
          if (is.null(st)) next
          add(data.frame(
            TRIAL = trial, ROW = row, statistic = "continuous",
            level = NA_character_, arm1 = i, arm2 = j,
            mdiff = st$mdiff, sem = st$sem, t = st$t,
            df = R$N[i] + R$N[j] - 1, size = R$N[i] + R$N[j],
            zeroSd = st$patched, stringsAsFactors = FALSE))
        }
      }
    }
  }
  if (!length(out))
    return(data.frame(TRIAL = character(0), ROW = character(0),
                      statistic = character(0), level = character(0),
                      arm1 = integer(0), arm2 = integer(0),
                      mdiff = numeric(0), sem = numeric(0),
                      t = numeric(0), df = numeric(0), size = numeric(0),
                      zeroSd = logical(0), stringsAsFactors = FALSE))
  do.call(rbind, out)
}

#' Barnett's dispersion test for one trial, evaluated by quadrature
#'
#' Computes the posterior probability that a baseline table is under- or
#' over-dispersed under the spike-and-slab model of Barnett
#' (F1000Research 2022, 11:783), together with the estimated dispersion
#' multiplier. See the file header for the model, and for why this is a
#' quadrature rather than an MCMC.
#'
#' @param tstats a data frame from [barnettTStats()], or any data frame
#'   with numeric columns `t` (the two-sample t-statistic for one table
#'   row and one pair of arms) and `df` (its degrees of freedom).
#' @param prior prior probability of the slab. 0.5, the reference default.
#' @param slabVar prior variance of `epsilon`. 10, the reference value.
#' @param points grid points for the quadrature; must be odd. 513 agrees
#'   with an 8,193-point grid to better than 1e-9 on every quantity
#'   returned, which the tests pin.
#'
#' @return a one-row data frame:
#'   \describe{
#'     \item{`nStat`}{number of t-statistics used.}
#'     \item{`pDispersed`}{posterior probability of the slab - Barnett's
#'       trial-specific probability. His threshold for flagging is 0.95.}
#'     \item{`epsilon`}{posterior mean of `epsilon` GIVEN the slab.
#'       Positive is under-dispersion, negative over-dispersion.}
#'     \item{`gamma`}{`exp(epsilon)`, the multiplier on the precision. A
#'       gamma of 2 means the differences between arms are tighter than
#'       sampling predicts by a factor of `sqrt(2)` in standard
#'       deviation.}
#'     \item{`direction`}{"under-dispersed", "over-dispersed" or "none".}
#'     \item{`multiplier`, `multiplierLo`, `multiplierHi`}{the reference
#'       app's reported multiplier and its 5-95% interval, computed from
#'       the MIXTURE posterior (slab draws and prior draws together) so
#'       that these three columns are directly comparable with what his
#'       Shiny app prints. When `pDispersed` is low the mixture is mostly
#'       prior, so `multiplier` heads for 1 while its interval stays
#'       enormous; that is a property of his summary rather than a defect
#'       here, and it is why `epsilon` is reported separately above.}
#'   }
#' @seealso [barnettTStats()] to build the input from a validated frame.
#' @export
barnettDispersion <- function(tstats, prior = 0.5, slabVar = .bdSlabVar,
                              points = 513L) {
  empty <- data.frame(nStat = 0L, pDispersed = NA_real_,
                      epsilon = NA_real_, gamma = NA_real_,
                      direction = NA_character_, multiplier = NA_real_,
                      multiplierLo = NA_real_, multiplierHi = NA_real_,
                      stringsAsFactors = FALSE)
  if (is.null(tstats) || !nrow(tstats)) return(empty)
  ok <- is.finite(tstats$t) & is.finite(tstats$df) & tstats$df > 0
  t  <- tstats$t[ok]
  df <- tstats$df[ok]
  # One statistic carries no information about a SCALE: a single t can be
  # explained by any gamma at all. The reference model would return a
  # number here; the number would be the prior.
  if (length(t) < 2L) { empty$nStat <- length(t); return(empty) }
  slabSd <- sqrt(slabVar)

  # Log posterior kernel of epsilon under the slab.
  h <- function(e) .bdLogLik(e, t, df) + stats::dnorm(e, 0, slabSd, log = TRUE)

  # Locate the mode. A coarse sweep FIRST, because h is not guaranteed
  # unimodal - strongly clustered t-statistics can in principle give it
  # shoulders - and optimize() would happily settle into the wrong one.
  #
  # The sweep starts at five prior standard deviations and EXPANDS while
  # the best point is still at an edge. It has to: a table whose arms are
  # numerically identical gives every t = 0, the log likelihood then rises
  # linearly in epsilon forever, and the mode sits where the prior finally
  # overtakes it - at n * slabVar / 2, which for a dozen statistics is 60,
  # far outside any fixed window. That table is not a pathology to be
  # guarded against but the strongest under-dispersion the model can see,
  # so the search must be able to reach it. The doubling stops at the
  # provable bound, because the likelihood's slope in epsilon is at most
  # n / 2 and the prior's pull grows without limit.
  lim  <- 5 * slabSd
  cap  <- 5 * slabSd + length(t) * slabVar / 2
  repeat {
    sweep <- seq(-lim, lim, length.out = 201L)
    k     <- which.max(h(sweep))
    if ((k > 1L && k < 201L) || lim >= cap) break
    lim <- min(lim * 2, cap)
  }
  m0    <- sweep[k]
  step  <- sweep[2] - sweep[1]
  mode  <- stats::optimize(h, c(m0 - step, m0 + step), maximum = TRUE)$maximum

  # Curvature at the mode sets the grid width, via a Laplace standard
  # deviation and a generous multiple of it. The step for the second
  # difference is deliberately coarse: h is smooth, and a tiny step would
  # be dominated by floating-point cancellation.
  hStep <- 0.05
  d2  <- (h(mode + hStep) - 2 * h(mode) + h(mode - hStep)) / hStep^2
  sdL <- if (is.finite(d2) && d2 < 0) sqrt(-1 / d2) else slabSd
  half <- max(8 * sdL, 2)

  # Widen until the grid ends are negligible against its peak, so the
  # quadrature cannot silently truncate mass. exp(-30) is about 1e-13.
  # Re-centre on whatever the grid itself says is highest, so that a mode
  # search which landed off-target still produces a centred grid rather
  # than a lopsided one.
  for (k in 1:12) {
    grid <- seq(mode - half, mode + half, length.out = points)
    hv   <- h(grid)
    peak <- max(hv)
    top  <- grid[which.max(hv)]
    if (max(hv[1], hv[points]) - peak < -30 && abs(top - mode) < half / 4)
      break
    if (abs(top - mode) >= half / 4) mode <- top else half <- half * 2
  }
  dx <- grid[2] - grid[1]
  w  <- exp(hv - peak)                   # unnormalised slab posterior

  # M1 (slab) and M0 (spike). M0 is the likelihood at epsilon = 0 with no
  # prior factor: the spike is a point mass, not a density.
  mass  <- .bdSimpson(w, dx)
  logM1 <- peak + log(mass)
  logM0 <- .bdLogLik(0, t, df)

  # Bayes, in logs, so a decisive table cannot overflow.
  pDisp <- 1 / (1 + exp(log(1 - prior) - log(prior) + logM0 - logM1))

  # Posterior mean of epsilon GIVEN the slab.
  eps <- .bdSimpson(w * grid, dx) / mass

  # The reference app's summary, reproduced for comparability. Its chain
  # visits the slab a fraction pDisp of the time and the PRIOR the rest,
  # so the quantity it averages is a mixture. The mixture mean is
  # pDisp * eps, because the prior contributes mean zero; the quantiles
  # come from the mixture CDF below.
  cdfSlab <- cumsum(c(0, (w[-1] + w[-points]) / 2 * dx)) / mass
  mixCdf <- function(x) {
    fs <- stats::approx(grid, cdfSlab, xout = x, rule = 2)$y
    pDisp * fs + (1 - pDisp) * stats::pnorm(x, 0, slabSd)
  }
  qMix <- function(p) {
    lo <- min(grid[1], -6 * slabSd)
    hi <- max(grid[points], 6 * slabSd)
    stats::uniroot(function(x) mixCdf(x) - p, c(lo, hi), tol = 1e-10)$root
  }

  data.frame(
    nStat        = length(t),
    pDispersed   = pDisp,
    epsilon      = eps,
    gamma        = exp(eps),
    direction    = if (!is.finite(pDisp) || pDisp < 0.5) "none" else
                   if (eps > 0) "under-dispersed" else "over-dispersed",
    multiplier   = exp(pDisp * eps),
    multiplierLo = exp(qMix(0.05)),
    multiplierHi = exp(qMix(0.95)),
    stringsAsFactors = FALSE)
}
