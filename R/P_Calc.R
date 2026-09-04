# P_Calc.R — the Monte Carlo analysis of one trial.
#
# PROVENANCE: moved out of app_server() in phase 2 of the package
# restructure (Claude Code, model Claude Fable 5, 2026-08-16); the function
# takes DATA, CategoryNames and m as explicit arguments so it can be called
# (and tested) without a running Shiny session. Every FIX comment from the
# 2026-08-14 bug-fix pass travels with its code. 2026-08-17: one-sided
# toward homogeneity (issue 6), median/IQR metalog branch (issue 12),
# degenerate-category refusal, and the ADAPTIVE STAGED scheme below
# (Steve's decision after the replicate-count discussion; independently
# convergent with a Gemini analysis he commissioned).
#
# THE STAGED SCHEME, in brief (full user documentation: docs/statistics.md):
#   - Each row simulates in stages: 1,000 -> 10,000 -> mMax (100,000)
#     replicates, advancing only while the running mid-p is < 0.01. Clean
#     rows stop at 1,000; only alarming rows pay for precision.
#   - Point estimate: mid-p (ties count half - the Carlisle-validated
#     convention), floored at 1/(m+1) (Davison & Hinkley: the Monte Carlo
#     test is exact-valid; a simulated p of literally 0 is never reported).
#   - Display: a row shows "<0.0001" ONLY when the one-sided 97.5%
#     Clopper-Pearson upper bound on the exceedance count clears 0.0001 -
#     the claim is licensed by the upper confidence limit, not the point
#     estimate. Ties count FULLY toward the bound (conservative).
#   - The trial p is the EXACT COMBINATION (2026-09-04, Steve's decision
#     after the tie experiment, corpus/syntheticTiesCheck.R): the same
#     Stouffer sum of row z-scores, but its null distribution is taken
#     from the row simulations themselves rather than from the normal
#     table. Every replicate is ranked within its own row, z-scored and
#     summed across rows, replicate by replicate; the trial p is the
#     share of replicate sums at or beyond the observed sum, ties half.
#     WHY: Stouffer's closed form assumes each row p is uniform under the
#     null. A row whose reported means are rounded coarsely relative to
#     their standard error (integer means at N in the hundreds) has a
#     handful of possible statistics, so its mid-p is discrete and the
#     closed form read a lumpy sum off a smooth table: 1.4% of honest
#     trials below p = 0.05 at N = 1,000 and integer means, and a
#     fabricated table with identical integer means capped near p = 0.01
#     however many rows agreed. The exact combination is calibrated by
#     construction at every rounding and every N, and the fabricated
#     table's p becomes the (small) share of honest trials whose rows all
#     tie at their minima - the evidence the table actually holds. The
#     staging is therefore per TRIAL: all usable rows draw the same
#     number of replicates at each stage, and the trial escalates while
#     its own mid-p or any row's is < 0.01. The trial p is floored at
#     1/(m+1) like a row, displays "<0.0001" under the same bound rule,
#     and carries an exact Clopper-Pearson 95% interval when < 0.001.
#     This replaced the closed-form Stouffer sum and its parametric
#     bootstrap; the error was in the Monte Carlo's combination step,
#     which Steve wrote, not in Carlisle's method.

# The Davison-Hinkley floor and the 0.9999 ceiling, applied to a row's
# mid-p and to every replicate's mid-p alike (the exact combination needs
# both on the same footing).
.floorP <- function(p, m) pmin(pmax(p, 1 / (m + 1)), 0.9999)

# A trial p as a number, for the closed-form combination ACROSS trials
# (results workbook, graphs, API): the exact combination reports
# "<0.0001" when its bound licenses it, and that enters the combination
# as 1e-4 - conservative, since the true value is smaller. Anything
# that is not a number ("No values") stays NA and is left out.
.trialPNumeric <- function(p) {
  p <- as.character(p)
  suppressWarnings(as.numeric(sub("^\\s*<\\s*", "", p)))
}

#' One-sided 97.5% Clopper-Pearson upper bound on a Monte Carlo p
#'
#' `kLE` counts simulations at or below the observed statistic (ties
#' fully - conservative for the bound). This is the number that licenses
#' a "<0.0001" claim: the claim is made only when this bound clears it.
#' @noRd
.mcUpper <- function(kLE, m) stats::qbeta(0.975, kLE + 1, pmax(m - kLE, 0))

#' Turn staged-tail counts into the row's report fields
#'
#' @return list: `p` (numeric mid-p, DH-floored), `disp` (display string:
#'   "<0.0001" when licensed, else the number), `ci` (upper-bound string,
#'   the exact Clopper-Pearson 95% interval on every row, "lower to
#'   upper": lower from the strictly-below count, upper from the
#'   at-or-below count, so the interval brackets the mid-p and errs wide
#'   - Steve, 2026-09-04: "add the row confidence intervals"), `kLE`, `m`.
#' @noRd
.rowReport <- function(sc) {
  midp <- (sc$kLess + sc$kEq / 2) / sc$m
  p <- max(midp, 1 / (sc$m + 1))
  if (p >= 1) p <- 0.9999
  kLE <- sc$kLess + sc$kEq
  upper <- .mcUpper(kLE, sc$m)
  disp <- if (upper < 1e-4) "<0.0001" else as.character(signif(p, 4))
  lower <- if (sc$kLess == 0) 0 else stats::qbeta(0.025, sc$kLess, sc$m - sc$kLess + 1)
  ci <- paste0(signif(lower, 2), " to ", signif(upper, 2))
  list(p = p, disp = disp, ci = ci, kLE = kLE, m = sc$m)
}

#' Monte Carlo integrity analysis of one trial's baseline table
#'
#' Reports a single **one-sided p-value toward excessive homogeneity**
#' (issue 6): P = the probability, under the null hypothesis of random
#' sampling, of baseline data **at least as homogeneous** as observed.
#' Small p = suspiciously homogeneous - the demonstrated fraud signal
#' (Fujii). Heterogeneity is deliberately not reported.
#'
#' Per row: continuous rows (all arms carry an N) simulate rounded
#' per-arm means under a common population (Carlisle-validated, issue 3);
#' median/IQR rows (Q1/Q3 filled; MEAN read as the median) use a 3-term
#' metalog matched to the pooled quartiles and compare rounded arm
#' MEDIANS; categorical rows simulate contingency tables under fixed
#' margins (`r2dtable`) and take the LOWER chi-square tail (counts more
#' alike than chance). All rows use the staged replicate scheme and
#' confidence-bounded reporting described at the top of this file, and
#' combine across the trial by the EXACT COMBINATION: Stouffer's sum of
#' row z-scores, judged against its own simulated null rather than the
#' normal table (see the header; the closed-form [sumz()] survives only
#' for combining trial p-values across a file).
#'
#' @section Calling P_Calc directly:
#'
#' IntegrityAnalysis declines trials with more than 5,000 subjects in any
#' arm (see the user guide, "Trials too large to analyze"). An
#' investigator with adequate computing horsepower can run the same
#' Monte Carlo by calling this function themselves - it has no
#' dependency on Shiny, on the parser, or on the size ceiling, which is
#' enforced in `validateData()` rather than here. Source this file, or
#' the package, and call it directly.
#'
#' The four arguments are described below. `DATA` is the one that
#' repays attention: everything else is a scalar or a name list.
#'
#' @param TRIAL the trial identifier. `P_Calc` analyses ONE trial per
#'   call and selects its rows with `DATA$TRIAL == TRIAL`, so `DATA` may
#'   hold many trials; loop over `unique(DATA$TRIAL)` for a whole file.
#'
#' @param DATA a data frame, **one row per variable per arm**. A
#'   two-arm trial reporting age, weight and sex is six rows: age twice,
#'   weight twice, sex twice. Rows are grouped by `ROW` within `TRIAL`,
#'   and the rows sharing a `ROW` value ARE the arms of that variable -
#'   there is no separate arm column, and arm order is the order the
#'   rows appear.
#'
#'   Required columns:
#'   \describe{
#'     \item{`TRIAL`}{trial identifier; matched against the `TRIAL` argument.}
#'     \item{`ROW`}{the variable name, e.g. "Age". Its repeats are the arms.}
#'     \item{`N`}{subjects in that arm for that variable.}
#'     \item{`MEAN`}{the arm mean - or, for a median row, the MEDIAN
#'       (see the row kinds below; the column is reused, not renamed).}
#'     \item{`SD`}{the arm standard deviation. `NA` for median and
#'       categorical rows.}
#'   }
#'
#'   Optional columns:
#'   \describe{
#'     \item{`SE`}{standard error, if the paper printed SE rather than
#'       SD; converted internally. Give one or the other, not both.}
#'     \item{`Q1`, `Q3`}{the quartiles, for a median row.}
#'     \item{`ROUND_MEAN`}{decimal places the MEAN was PRINTED to. This
#'       is not cosmetic - the whole method rests on rounding simulated
#'       values exactly as the paper rounded its own. 0 means integers.}
#'     \item{`ROUND_DISPERSION`}{decimals printed for SD/SE.}
#'     \item{`ROUND_OBSERVATION`}{decimals the UNDERLYING OBSERVATIONS
#'       were recorded to, which is often finer than the printed mean -
#'       ages recorded whole but a mean printed to one decimal.}
#'     \item{category columns}{one column per category level, holding
#'       COUNTS, named in `CategoryNames`. See below.}
#'   }
#'
#'   **The three kinds of row, and how they are told apart** - by which
#'   columns are filled, never by a type flag:
#'   \describe{
#'     \item{continuous}{every arm has a non-NA `N`, and `MEAN`/`SD` are
#'       filled. Simulates rounded per-arm means under one common
#'       population.}
#'     \item{median / IQR}{`Q1` and `Q3` are filled and every arm has an
#'       `N`; `MEAN` carries the MEDIAN and `SD` is `NA`. Fits a 3-term
#'       metalog to the pooled quartiles and compares rounded arm
#'       medians.}
#'     \item{categorical}{the category columns hold counts and `N`,
#'       `MEAN`, `SD` are all `NA` on those rows. Simulates contingency
#'       tables under fixed margins and takes the LOWER chi-square tail.
#'       `validateData()` enforces the exclusivity: a line carrying a
#'       category value must not also carry N/MEAN/SD.}
#'   }
#'
#'   A minimal two-arm continuous example:
#'   \preformatted{
#'   DATA <- data.frame(
#'     TRIAL = "T1",
#'     ROW   = c("Age", "Age", "Weight", "Weight"),
#'     N     = c(50, 52, 50, 52),
#'     MEAN  = c(60.1, 60.3, 72.4, 72.9),
#'     SD    = c(10.2, 9.8, 12.1, 11.7),
#'     ROUND_MEAN = 1, ROUND_OBSERVATION = 1,
#'     stringsAsFactors = FALSE)
#'   P_Calc("T1", DATA, NULL, 100000)
#'   }
#'
#'   Running `DATA` through [validateData()] first is recommended but not
#'   required - it normalises column names, checks the contract, and
#'   returns `$DATA` and `$CategoryNames` ready for this function. It
#'   also applies the 5,000 ceiling, so callers who deliberately want a
#'   larger trial should skip it and supply a well-formed frame directly.
#'
#' @param CategoryNames character vector naming the category (count)
#'   columns in `DATA`, or `NULL` when the trial has none. These are the
#'   columns treated as contingency-table counts; any column not named
#'   here and not a base column is ignored. `validateData()` returns the
#'   right value in `$CategoryNames`.
#'
#' @param m maximum replicates per row - the final stage of the adaptive
#'   scheme. The app uses 100,000. A trial resolves at 1,000 per row
#'   unless it, or one of its rows, looks alarming, so this is a
#'   ceiling, not a cost. Lower it to trade precision for speed on a
#'   large trial; the reported `M` column says what the rows used.
#' @return a data.frame with columns TRIAL, ROW, P, CI95, M: one row per
#'   data ROW (M = replicates used; CI95 = the exact Clopper-Pearson 95%
#'   Monte Carlo interval of the row p, on every row), then a "Summary"
#'   row with the exact-combination trial p and its interval when
#'   P < 0.001, then a blank spacer row.
#' @noRd
P_Calc <- function(TRIAL, DATA, CategoryNames, m, graphs = NULL)
{
  # graphs: optional collector environment from newGraphCollector()
  # (issue 16). When present, each simulated row deposits its observed
  # statistic and the expected distribution's draws for the PowerPoint
  # graphs; the returned results are bit-identical either way.
  data <- DATA[DATA$TRIAL == TRIAL,]
  RowIDs <- unique(data$ROW)

  # Pass 1: per row, either a refusal (Pdisp) or the simulation closure
  # and the observed statistic. Nothing is simulated here: the exact
  # combination needs every usable row drawn at the same replicate
  # count, so the drawing happens in pass 2, stage by stage.
  rows <- lapply(seq_along(RowIDs), function(j)
    {
      Row <- RowIDs[j]
      ROWS <- data[data$ROW == Row,]

      Pdisp <- NA_character_
      simRow <- NULL

      # Greater than 1 line?
      if (nrow(ROWS) > 1)
      {
        isQuartile <- "Q1" %in% names(ROWS) &&
                      (any(!is.na(ROWS$Q1)) || any(!is.na(ROWS$Q3)))
        if (isQuartile && all(!is.na(ROWS$N)))
        {
          # Median/IQR row (issue 12): the common population is a 3-term
          # METALOG matched to the pooled median and quartiles (Keelin
          # 2016) - exact including asymmetry, closed-form sampling,
          # logistic in the symmetric case. Coefficients (NOTE: a shared
          # Gemini analysis printed a3 = 4(...)/ln3, a factor-of-2 slip
          # against its own derivation; exact quantile recovery is pinned
          # by a unit test):
          #   a1 = m,  a2 = IQR/(2 ln 3),  a3 = 2(Q1 + Q3 - 2m)/ln 3
          # |a3/a2| > 1.667 (Keelin validity) refuses the row.
          if (any(is.na(ROWS$Q1)) || any(is.na(ROWS$Q3)))
          {
            Pdisp <- "Mixed SD and quartile lines"
          } else {
          COLS <- nrow(ROWS)
          N <- sum(ROWS$N)
          medPool <- sum(ROWS$N * ROWS$MEAN) / N
          q1Pool  <- sum(ROWS$N * ROWS$Q1) / N
          q3Pool  <- sum(ROWS$N * ROWS$Q3) / N
          a1 <- medPool
          a2 <- (q3Pool - q1Pool) / (2 * log(3))
          a3 <- 2 * (q1Pool + q3Pool - 2 * medPool) / log(3)
          if (a2 <= 0 || abs(a3) / a2 > 1.667)
          {
            Pdisp <- "Quartiles too skewed to simulate"
          } else {
          center     <- sum(ROWS$N * ROWS$MEAN) / N
          DiffSample <- sum((ROWS$MEAN - center)^2)
          # Per-replication uncertainty in the common location: asymptotic
          # SD of a sample median is 1/(2 f(m) sqrt(n)); metalog density
          # at its median is 1/(4 a2), so SD_median = 2 a2 / sqrt(n).
          sdShift <- 2 * a2 / sqrt(mean(ROWS$N))
          simulate <- function(n) {
            out <- numeric(0); left <- n
            while (left > 0) {
              # chunk so chunk*N stays bounded (memory guard, successor
              # of the old fixed m1 <- 1e9/N cap)
              ch <- min(left, max(1, floor(1e8 / max(1, N))))
              shiftsim <- dqrnorm(ch, mean = 0, sd = sdShift)
              MCMed <- matrix(NA_real_, ch, COLS)
              for (i in 1:COLS)
              {
                U <- matrix(dqrunif(ROWS$N[i] * ch), nrow = ch)
                L <- log(U / (1 - U))
                X <- (a1 + shiftsim) + a2 * L + a3 * (U - 0.5) * L
                MCMed[,i] <- round(
                  Rfast::rowMedians(round(X, ROWS$ROUND_OBSERVATION[i])),
                  ROWS$ROUND_MEAN[i])
              }
              Nmat <- matrix(ROWS$N, ch, COLS, byrow = TRUE)
              MedC <- rowsums(MCMed * Nmat) / N
              out <- c(out, rowsums((MCMed - MedC)^2))
              left <- left - ch
            }
            out
          }
          simRow <- list(simulate = simulate, obs = DiffSample, kind = "median")
          }
          }
        }
        else if (all(!is.na(ROWS$N)))
        {
          COLS <- nrow(ROWS)
          N <- sum(ROWS$N)
          Meanmean <- sum(ROWS$N*ROWS$MEAN) / N
          # The calculation of Meanvar is OK. SD^2 is an unbiased estimate
          # of variance
          Meanvar <-  sum(ROWS$N*ROWS$SD^2) / N

          # However, this next calculatiion is biased. s.u. will correct it
          # If N > 30, then the correction is < 1 %. It blows up if N > 343!
          if (N < 30)
          {
            Meansd <- s.u(sqrt(Meanvar), N)
          } else {
            Meansd <- sqrt(Meanvar)
          }
          SEMsample <- Meansd/sqrt(mean(ROWS$N))
          DiffSample <- sum((ROWS$MEAN - Meanmean)^2) # Squared difference of column means
          # Monte Carlo Simulation. The simulation body is unchanged from
          # the Carlisle-validated implementation (issue 3, r = 0.991);
          # the staging wrapper only decides HOW MANY replications run.
          # FIX (2026-08-14, carried): meansim must have exactly as many
          # entries as replication rows, or the column-major fill would
          # misalign arms within a replication; simulated column means
          # round to ROUND_MEAN (the printed precision), observations to
          # ROUND_OBSERVATION.
          simulate <- function(n) {
            out <- numeric(0); left <- n
            while (left > 0) {
              ch <- min(left, max(1, floor(1e8 / max(1, N))))
              meansim <- dqrnorm(ch, mean = Meanmean, sd = SEMsample)
              MCMean <- matrix(NA_real_, ch, COLS)
              for (i in 1:COLS)
                MCMean[,i] <- round(
                  rowmeans(round(
                    matrix(rnorm(ROWS$N[i] * ch,
                                 rep(meansim, ROWS$N[i]), Meansd),
                           nrow = ch, byrow = FALSE),
                    ROWS$ROUND_OBSERVATION[i])),
                  ROWS$ROUND_MEAN[i])
              Nmat <- matrix(ROWS$N, ch, COLS, byrow = TRUE)
              MS <- rowsums(MCMean * Nmat) / N
              out <- c(out, rowsums((MCMean - MS)^2))
              left <- left - ch
            }
            out
          }
          simRow <- list(simulate = simulate, obs = DiffSample, kind = "continuous")
        } else {
          # FIX: drop = FALSE added. With a single category column,
          # ROWS[,CategoryNames] dropped to a bare vector and the
          # ROWS[,NAME] <- NULL loop below crashed with "incorrect number
          # of dimensions".
          ROWS <- ROWS[,CategoryNames, drop = FALSE]
          for (NAME in CategoryNames)
          {
            if (all(is.na(ROWS[,NAME])))
              ROWS[,NAME] <- NULL
          }
          # One-sided toward homogeneity (issue 6): the LOWER mid-p tail
          # of the chi-square statistic under fixed margins (r2dtable,
          # chisq.test's own null) - counts more alike than chance.
          tab <- as.matrix(ROWS)
          # FIX (2026-08-17, found by the corpus/TEST mass run):
          # degenerate tables (NA cells, zero-margin columns) made the
          # statistic NaN and crashed the analysis; refuse instead.
          if (any(is.na(tab)))
          {
            Pdisp <- "Incomplete category counts across arms"
          } else {
          tab <- tab[, colSums(tab) > 0, drop = FALSE]
          if (ncol(tab) < 2 || any(rowSums(tab) == 0))
          {
            Pdisp <- "Degenerate category table (an arm or every remaining category is empty)"
          } else {
          E <- outer(rowSums(tab), colSums(tab)) / sum(tab)
          statObs <- sum((tab - E)^2 / E)
          # CHUNKED (2026-08-28 screen, F1). This called r2dtable with
          # the FULL stage size - up to 100,000 tables in one
          # allocation - while the other two branches chunk by 1e8/N.
          # Cost here is driven by arms x categories, not by N, so a
          # 100-arm x 190-category table asks for 6 GB at full
          # escalation and the gate maxima reach ~330 GB. tryCatch
          # cannot catch a cgroup OOM.
          #
          # RNG-IDENTICAL, verified rather than assumed: r2dtable draws
          # one table at a time from the stream, so r2dtable(1000) and
          # 10 x r2dtable(100) produce the same 1,000 tables under the
          # same seed. Checked at 2-way and 3-way splits before this
          # was written, because the known-answer tests pin Monte Carlo
          # values and a changed RNG consumption pattern would silently
          # move every categorical p.
          simulate <- function(n) {
            cells <- max(1, nrow(tab) * ncol(tab))
            ch <- max(1, floor(1e7 / cells))
            out <- numeric(0); left <- n
            while (left > 0) {
              k <- min(left, ch)
              out <- c(out, vapply(r2dtable(k, rowSums(tab), colSums(tab)),
                                   function(s) sum((s - E)^2 / E),
                                   numeric(1)))
              left <- left - k
            }
            out
          }
          simRow <- list(simulate = simulate, obs = statObs, kind = "category")
          }
          }
        }
      } else {
        Pdisp <- "Only 1 Row"
      }

      list(Row = as.character(Row), Pdisp = Pdisp, sim = simRow)
    })

  # Pass 2: the exact combination, staged per TRIAL. At each stage every
  # usable row draws the same number of replicates; each replicate is
  # ranked within its row (average ranks: (rank - 1/2)/s is exactly the
  # mid-p its own tie group would report), floored and z-scored like the
  # observed row, and the z's are summed across rows replicate by
  # replicate - legitimately, because the rows are simulated
  # independently. The observed sum is judged against those sums. The
  # trial escalates while its own mid-p or any row's is < 0.01, so an
  # innocuous trial still costs 1,000 replicates per row.
  usable <- which(vapply(rows, function(r) !is.null(r$sim), logical(1)))
  stages <- unique(pmin(c(1000, 10000, m), m))
  rowStat <- vector("list", length(rows))
  trialStat <- NULL
  for (s in stages) {
    sumZ <- numeric(s); zObs <- 0
    for (j in usable) {
      sims <- rows[[j]]$sim$simulate(s)
      obs  <- rows[[j]]$sim$obs
      kLess <- sum(sims < obs); kEq <- sum(sims == obs)
      # Distribution graphs (issue 16): keep the FIRST stage's simulated
      # statistics - they ARE the expected distribution under honest
      # sampling, generated anyway and normally discarded.
      draws <- if (!is.null(graphs) && is.null(rowStat[[j]])) sims else rowStat[[j]]$draws
      rowStat[[j]] <- list(kLess = kLess, kEq = kEq, m = s, draws = draws)
      pRep <- .floorP((rank(sims, ties.method = "average") - 0.5) / s, s)
      sumZ <- sumZ + stats::qnorm(pRep, lower.tail = FALSE)
      zObs <- zObs + stats::qnorm(.floorP((kLess + kEq / 2) / s, s), lower.tail = FALSE)
    }
    rowMid <- vapply(usable, function(j)
      (rowStat[[j]]$kLess + rowStat[[j]]$kEq / 2) / s, numeric(1))
    if (length(usable) > 1) {
      kG <- sum(sumZ > zObs); kE <- sum(sumZ == zObs)
      trialStat <- list(kG = kG, kE = kE, m = s)
      trialMid <- (kG + kE / 2) / s
    } else trialMid <- 1
    if (trialMid >= 0.01 && all(rowMid >= 0.01)) break
  }

  # The rows' report lines, from the final stage's counts.
  x <- do.call(rbind, lapply(seq_along(rows), function(j) {
    r <- rows[[j]]
    if (is.null(r$sim))
      return(data.frame(ROW = r$Row, P = r$Pdisp, CI95 = "", M = NA_character_,
                        .PNUM = NA_real_, .KLE = NA_real_, stringsAsFactors = FALSE))
    rep <- .rowReport(rowStat[[j]])
    if (!is.null(graphs))
      graphs$rows[[length(graphs$rows) + 1]] <-
        list(trial = TRIAL, row = r$Row, kind = r$sim$kind,
             obs = r$sim$obs, draws = rowStat[[j]]$draws, p = rep$p)
    data.frame(ROW = r$Row, P = rep$disp, CI95 = rep$ci, M = as.character(rep$m),
               .PNUM = rep$p, .KLE = rep$kLE, stringsAsFactors = FALSE)
  }))
  x <- cbind(TRIAL = c(TRIAL, rep(NA, nrow(x) - 1L)), x, stringsAsFactors = FALSE)

  Pv   <- x$.PNUM
  use  <- !is.na(Pv)

  ciStr <- ""
  if (sum(use) > 1)
  {
    # The trial p: the share of simulated honest trials whose Stouffer
    # sum reaches the observed one (ties half), floored like a row and
    # displayed "<0.0001" only when the one-sided 97.5% upper bound on
    # the reaching count licenses it. The 95% interval is exact
    # Clopper-Pearson on that count - the Monte Carlo uncertainty of the
    # trial p itself, no bootstrap needed.
    kGE <- trialStat$kG + trialStat$kE
    mT  <- trialStat$m
    Pnum <- max((trialStat$kG + trialStat$kE / 2) / mT, 1 / (mT + 1))
    if (Pnum >= 1) Pnum <- 0.9999
    upper <- .mcUpper(kGE, mT)
    P <- if (upper < 1e-4) "<0.0001" else signif(Pnum, 4)
    if (Pnum < 0.001)
    {
      lower <- if (kGE == 0) 0 else stats::qbeta(0.025, kGE, mT - kGE + 1)
      ciStr <- paste0(signif(lower, 2), " to ", signif(upper, 2))
    }
  } else {
    # FIX (carried): length(Pv[use]) == 1 vs the old length(x == 1) trap
    if (sum(use) == 1)
      P <- Pv[use]
    if (sum(use) == 0)
      P = "No values"
  }

  lastline <- data.frame(
    TRIAL = c(NA, NA),
    ROW = c("Summary", NA),
    P = c(as.character(P), NA),
    CI95 = c(ciStr, NA),
    M = c(NA, NA),
    .PNUM = c(NA, NA),
    .KLE = c(NA, NA)
  )

  x <- rbind(x, lastline)
  # internal bookkeeping columns stay out of the results
  x <- x[, c("TRIAL", "ROW", "P", "CI95", "M")]
  outputComments(
    paste0("Trial ", TRIAL,": p = ", P,
           if (nzchar(ciStr)) paste0(" (95% Monte Carlo interval ",
                                     ciStr, ")")
           else "", "\n")
  )
  return(x)
}
