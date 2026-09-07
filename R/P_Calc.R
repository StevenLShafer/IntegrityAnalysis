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
#   - The trial simulates in stages: 1,000 -> 10,000 -> mMax (100,000)
#     replicates. It advances from 1,000 to 10,000 while the trial's
#     running mid-p, or any row's, is < 0.1, and from 10,000 to 100,000
#     while one is < 0.01 (Steve, 2026-09-05: "I would escalate P < 0.1
#     to additional simulations as well. The range 0.034 to 0.057 is a
#     bit broader than I would like" - at 1,000 replicates a p near 0.05
#     resolves to about +/- 0.007; at 10,000 to +/- 0.002). Clean trials
#     stop at 1,000; borderline ones pay ten times; alarming ones a
#     hundred.
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

# TIES BY AN EXPLICITLY BOUNDED NUMERICAL CRITERION (2026-09-07; the GPT-6
# audit's finding F1, docs/audits/). A tie - a replicate exactly as
# homogeneous as the printed table - is the heart of the mid-p, and it
# was decided with `==` on doubles. Two categorical tables with the same
# Pearson statistic (80/63 for margins (2, 2, 6) x (3, 7)) compute to
# 1.2698412698412698 and 1.2698412698412700, and the strict comparison
# split that tie group: the row's mid-p read 0.10 where the exact value
# is 0.35, and five such rows combined to 0.00018 where the exact trial
# p is 0.084. The same hazard reaches the continuous branch when three or
# more arms permute a pattern (a + b + c is not c + b + a in floating
# point) and the attainable-floor test, where identical printed means
# with unequal arm sizes give an observed statistic of about 1e-28
# rather than zero. So: two statistics are one value when they agree to
# within .iaTieTol of the larger in magnitude. The criterion is bounded
# and stated: floating-point error in these sums is below 1e-13
# relative, so mathematically equal values are never split; distinct
# attainable values of these statistics differ by far more than 1e-10
# relative (a rounded-mean sum of squares changes by at least a grid
# step squared; a fixed-margin Pearson statistic by at least
# 1/(n r c), which is 1e-11 only for tables no baseline table
# resembles), so distinct values are not merged. It is applied to the
# observed-versus-replicate counts and to the replicate ranks alike, so
# the observed row and every replicate are judged by one rule.
.iaTieTol <- 1e-10

#' Average ranks with ties decided by .iaTieTol
#' @noRd
.iaTieRank <- function(x) {
  o <- order(x); s <- x[o]; n <- length(s)
  if (n < 2L) return(rep(1, n))
  newGroup <- c(TRUE, diff(s) > .iaTieTol * pmax(abs(s[-1L]), abs(s[-n])))
  first <- which(newGroup); last <- c(first[-1L] - 1L, n)
  r <- numeric(n); r[o] <- ((first + last) / 2)[cumsum(newGroup)]
  r
}

#' The strictly-below and tied counts of `sims` against `obs`, ties by .iaTieTol
#' @noRd
.iaTieCounts <- function(sims, obs) {
  eq <- abs(sims - obs) <= .iaTieTol * pmax(abs(sims), abs(obs))
  c(kLess = sum(sims < obs & !eq), kEq = sum(eq))
}

# THE DIRECT DRAW (Steve, 2026-09-05: "Build the direct draw into P_Calc").
# A continuous row's replicate draws N observations per arm, rounds each
# to the observation precision, averages, and rounds the mean to the
# printed precision. That is exact and it costs N draws per arm per
# replicate, so a 5,000-per-arm row costs 250 times a 20-per-arm row,
# and the exact combination (which escalates every row of an alarming
# trial together) made the Carlisle corpus's largest trials an hour each.
# Above .iaDirectDrawN per arm the arm MEAN is drawn directly: the mean of
# N observations each rounded to a grid of width h is, by the central
# limit theorem, Normal with variance (SD^2 + h^2/12)/N - Sheppard's
# correction adds the rounding's variance - and only the rounding of the
# PRINTED mean is then applied exactly, which is the rounding that makes
# ties. Two conditions, both measured against the full simulation
# (C:/dev/Corpus/synthetic/direct-draw, 2026-09-05, 100,000 replicates per
# cell; recorded in docs/statistics.md). N per arm at least
# .iaDirectDrawN: at 100 the tie mass and the mid-p at a tie agree to the
# third decimal and the largest CDF difference over the statistic's
# support is within Monte Carlo noise (under 0.005) for every ordinary
# grid; at 30 and below the coarse grids diverge. And the SD at least
# .iaDirectDrawSdOverGrid times the observation grid: Sheppard's
# correction assumes the density varies little across one grid step, and
# with SD below the grid (0.7 against integer observations) the rounded
# observations take a few values and the mean is not normal (CDF
# difference 0.019 at N = 100); from 3 grid steps up the difference is
# noise at every N. Either condition unmet, the full simulation runs
# unchanged for that arm, so every pinned known-answer value (N <= 40)
# is untouched.
.iaDirectDrawN          <- 100L
.iaDirectDrawSdOverGrid <- 3
# The three-term metalog is a valid distribution only while |a3|/a2 is
# below 1.66711 (Keelin 2016); a fit beyond that is clipped to this
# limit rather than refused (2026-09-07, see the median branch)
.iaMetalogSkewLimit     <- 1.66

#' The interval a printed SD stands for
#'
#' The SD rounding draw (2026-09-06; see the continuous branch of P_Calc)
#' draws each arm's sample SD uniformly within the interval its printed
#' value covers: half a printed unit either side, never below zero. A
#' blank or missing `ROUND_DISPERSION` is inferred from the SD's own
#' printed decimals (a direct caller without the column gets what
#' `validateData()` would have inferred). A printed ZERO is not an
#' interval: it declares that the variable did not vary (13 rows of
#' Carlisle's corpus; PR #182 accepted them, and identical arms with SD 0
#' report p = 0.5 at the attainable floor). Drawing from [0, h/2) there
#' would manufacture a spread the paper denies, so zero stays zero.
#' A blank cell is inferred on its own, cell by cell (2026-09-07; the GPT-6
#' audit's finding F5): the first version used the supplied precisions
#' only when EVERY arm had one and otherwise re-inferred every arm, so a
#' supplied two-decimal "1.00" beside a blank became [0.5, 1.5]. A blank
#' cell now takes the variable's maximum printed decimals across its arms,
#' which is the validator's inference, so a direct call and a validated
#' one agree.
#' @param sd numeric, the arms' printed SDs
#' @param roundDisp the printed decimals of each, or NULL/NA to infer
#' @return list(lo, hi), numeric vectors the length of `sd`
#' @noRd
.iaSdInterval <- function(sd, roundDisp = NULL) {
  dec <- if (is.null(roundDisp) || length(roundDisp) != length(sd)) rep(NA_real_, length(sd))
         else suppressWarnings(as.numeric(roundDisp))
  blank <- is.na(dec)
  if (any(blank)) dec[blank] <- max(vapply(sd, .iaDecimals, integer(1)))
  h <- 10^(-dec)
  list(lo = ifelse(sd == 0, 0, pmax(0, sd - h / 2)),
       hi = ifelse(sd == 0, 0, sd + h / 2))
}

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
#'       SD. NOT converted here: [validateData()] refuses a row with an
#'       SE and no SD, and the app asks the user to supply the SD (SD =
#'       SE x sqrt(N) only when the SE describes the plain sample mean).
#'       A direct caller must supply SD.}
#'     \item{`Q1`, `Q3`}{the quartiles, for a median row.}
#'     \item{`ROUND_MEAN`}{decimal places the MEAN was PRINTED to. This
#'       is not cosmetic - the whole method rests on rounding simulated
#'       values exactly as the paper rounded its own. 0 means integers.
#'       Absent or blank: inferred from the printed decimals of `MEAN`,
#'       raised to the variable's maximum across its arms (so 1.20 beside
#'       1.25 is a two-decimal variable on both lines).}
#'     \item{`ROUND_DISPERSION`}{decimals printed for SD/SE. Absent or
#'       blank: inferred from the printed decimals of `SD`.}
#'     \item{`ROUND_OBSERVATION`}{decimals the UNDERLYING OBSERVATIONS
#'       were recorded to, which is often finer than the printed mean -
#'       ages recorded whole but a mean printed to one decimal. Absent or
#'       blank: taken equal to `ROUND_MEAN`.}
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
#' @return a data.frame with columns TRIAL, ROW, P, CI95, M, NOTE, KIND
#'   (KIND is "variable" on a variable's line, "summary" on the trial's
#'   summary line, NA on the spacer - consumers identify the summary by
#'   KIND, never by the text in ROW, which a variable may also carry): one
#'   row per data ROW (M = replicates used; CI95 = the exact
#'   Clopper-Pearson 95% Monte Carlo interval of the row p, on every row;
#'   NOTE = "attainable floor" when the row sits at the smallest p its
#'   printed precision allows, else blank), then a "Summary"
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
  # DIRECT CALLERS (2026-09-07; audit finding F4, Steve: "the default
  # columns in P_Calc"). validateData() supplies the rounding columns and
  # this function documents itself as callable without it - yet without
  # ROUND_OBSERVATION it died in 10^(-NULL) ("invalid argument to unary
  # operator"), with a blank one in rnorm ("invalid arguments"), and with
  # one patient per arm in a missing-value `if`. A missing or blank
  # rounding column is now inferred exactly as the validator infers it:
  # the mean's precision from its printed decimals, raised to the
  # variable's maximum across its arms; the observation precision equal
  # to the mean's. (ROUND_DISPERSION is inferred where it is used, in
  # .iaSdInterval.) An arm of fewer than two patients is refused by name
  # below, as the validator refuses it.
  for (col in c("ROUND_MEAN", "ROUND_OBSERVATION"))
    if (is.null(data[[col]])) data[[col]] <- NA_real_
  data$ROUND_MEAN <- suppressWarnings(as.numeric(data$ROUND_MEAN))
  data$ROUND_OBSERVATION <- suppressWarnings(as.numeric(data$ROUND_OBSERVATION))
  if (nrow(data) > 0 && any(is.na(data$ROUND_MEAN))) {
    dec <- vapply(data$MEAN, .iaDecimals, integer(1))
    grpMax <- stats::ave(dec, data$ROW, FUN = max)
    blank <- is.na(data$ROUND_MEAN)
    data$ROUND_MEAN[blank] <- grpMax[blank]
  }
  blankObs <- is.na(data$ROUND_OBSERVATION)
  data$ROUND_OBSERVATION[blankObs] <- data$ROUND_MEAN[blankObs]
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
        if (all(!is.na(ROWS$N)) && any(ROWS$N < 2))
        {
          # the validator refuses this before the app or API gets here; a
          # direct caller gets the refusal by name rather than a crash
          Pdisp <- "An arm with fewer than 2 patients cannot be simulated"
        }
        else if (isQuartile && all(!is.na(ROWS$N)))
        {
          # Median/IQR row (issue 12): the common population is a 3-term
          # METALOG matched to the pooled median and quartiles (Keelin
          # 2016) - exact including asymmetry, closed-form sampling,
          # logistic in the symmetric case. Coefficients (NOTE: a shared
          # Gemini analysis printed a3 = 4(...)/ln3, a factor-of-2 slip
          # against its own derivation; exact quantile recovery is pinned
          # by a unit test):
          #   a1 = m,  a2 = IQR/(2 ln 3),  a3 = 2(Q1 + Q3 - 2m)/ln 3
          #
          # THE SKEW LIMIT AND THE PARAMETER DRAW (2026-09-07; audit finding
          # F2 of 2026-09-06, Steve: "yes to median IQR scale draw and
          # refusal of honest small rows"). Two things were wrong with the
          # branch as first built. (1) |a3|/a2 beyond Keelin's feasibility
          # bound (1.66711) REFUSED the row - and sample quartiles of ten
          # observations are so noisy that 8% (normal) to 18% (lognormal)
          # of honest ten-per-arm rows were refused as "too skewed". The
          # skew term is now clipped to the bound: the closest feasible
          # metalog is fitted, and the results table says so in the Note
          # column. (2) The pooled quartiles were taken as exact, the
          # analogue of a plug-in sigma: at ten per arm the honest row p
          # averaged 0.55 with a Kolmogorov-Smirnov distance of 0.07-0.12
          # from uniform (docs/method-history.md). Each replicate now
          # draws its own scale. HOW, and why not the obvious way: a
          # parametric bootstrap (every arm resampled from the fit,
          # summarised, pooled, refitted; the population = the refit) was
          # tried first and made things WORSE (mean p 0.60, KS 0.16-0.19
          # at ten per arm) - it draws the SAMPLE's scale given the
          # population, when what is needed is the POPULATION's scale
          # given the sample, and for a scale parameter the two are
          # reciprocals. That is exactly the normal branch's sigma draw:
          # sigma^2 = s^2 df / chisq(df) is the reciprocal of the
          # bootstrap's s^2 chisq(df) / df. So: every arm is resampled
          # from the fitted metalog, recorded to the observation
          # precision, its type-7 quartiles printed to the median's
          # precision and pooled by N, giving a bootstrap scale a2*; the
          # replicate's population scale is a2^2 / a2* (its a3 is the
          # observed one, re-clipped to that scale; its location is the
          # pooled median plus the usual draw). Measured side by side on
          # identical honest trials (C:/dev/Corpus/synthetic/median-draw/
          # variants.R): mean p 0.48-0.52 and KS 0.03-0.06 at ten per arm
          # for this construction, against 0.54-0.57 / 0.07-0.13 for the
          # point fit and 0.58-0.62 / 0.15-0.19 for the bootstrap.
          if (any(is.na(ROWS$Q1)) || any(is.na(ROWS$Q3)))
          {
            Pdisp <- "Mixed SD and quartile lines"
          } else {
          COLS <- nrow(ROWS)
          N <- sum(ROWS$N)
          # the fit, vectorised over replicates: scalars for the observed
          # table, length-ch vectors for the bootstrap refits
          fitMetalog <- function(med, q1, q3) {
            a2  <- (q3 - q1) / (2 * log(3))
            a3  <- 2 * (q1 + q3 - 2 * med) / log(3)
            lim <- .iaMetalogSkewLimit * a2
            list(a1 = med, a2 = a2, a3 = pmin(pmax(a3, -lim), lim), clipped = abs(a3) > lim)
          }
          medPool <- sum(ROWS$N * ROWS$MEAN) / N
          q1Pool  <- sum(ROWS$N * ROWS$Q1) / N
          q3Pool  <- sum(ROWS$N * ROWS$Q3) / N
          fit <- fitMetalog(medPool, q1Pool, q3Pool)
          if (fit$a2 <= 0)
          {
            Pdisp <- "Quartiles do not increase (Q3 must exceed Q1)"
          } else {
          a1 <- fit$a1; a2 <- fit$a2; a3 <- fit$a3
          skewNote <- if (fit$clipped)
            "quartiles beyond the metalog's skew limit; fitted at the limit" else ""
          center     <- sum(ROWS$N * ROWS$MEAN) / N
          DiffSample <- sum((ROWS$MEAN - center)^2)
          # Per-replication uncertainty in the common location: asymptotic
          # SD of a sample median is 1/(2 f(m) sqrt(n)); metalog density
          # at its median is 1/(4 a2), so SD_median = 2 a2 / sqrt(n).
          sdShift <- 2 * a2 / sqrt(mean(ROWS$N))
          # a chunk of replicates from a metalog whose coefficients may be
          # one number or one per replicate (a length-ch vector recycles
          # down the columns of a ch-row matrix, one value per replicate);
          # U kept off 0 and 1, where the logit is infinite
          drawMetalog <- function(ch, n, a1, a2, a3) {
            U <- matrix(dqrunif(n * ch, 1e-12, 1 - 1e-12), nrow = ch)
            L <- log(U / (1 - U))
            a1 + a2 * L + a3 * (U - 0.5) * L
          }
          # type-7 quantile of every row of a row-sorted matrix (R's and
          # SPSS's default, Excel's QUARTILE.INC)
          rowQ <- function(S, p) {
            n <- ncol(S); h <- (n - 1) * p + 1; lo <- floor(h); hi <- min(n, lo + 1)
            S[, lo] + (h - lo) * (S[, hi] - S[, lo])
          }
          simulate <- function(n) {
            out <- numeric(0); left <- n
            while (left > 0) {
              # chunk so chunk*N stays bounded: three ch x N_i matrices are
              # alive in a draw, twice per replicate here, so a quarter of
              # the continuous branch's chunk keeps the peak comparable
              ch <- min(left, max(1, floor(2.5e7 / max(1, N))))
              # the scale draw: resample every arm from the fit, take its
              # printed quartiles, pool - the bootstrap scale a2* - and
              # invert the ratio: the replicate's population scale is
              # a2^2 / a2* (a degenerate resample with a2* = 0 is floored
              # at one printed unit, so the ratio stays finite)
              bq1 <- numeric(ch); bq3 <- numeric(ch)
              for (i in 1:COLS)
              {
                S <- Rfast::rowSort(round(drawMetalog(ch, ROWS$N[i], a1, a2, a3),
                                          ROWS$ROUND_OBSERVATION[i]))
                w <- ROWS$N[i] / N
                bq1 <- bq1 + w * round(rowQ(S, 0.25), ROWS$ROUND_MEAN[i])
                bq3 <- bq3 + w * round(rowQ(S, 0.75), ROWS$ROUND_MEAN[i])
              }
              a2boot <- pmax((bq3 - bq1) / (2 * log(3)), 10^(-max(ROWS$ROUND_MEAN)) / (2 * log(3)))
              a2rep  <- a2^2 / a2boot
              a3rep  <- pmin(pmax(a3, -.iaMetalogSkewLimit * a2rep), .iaMetalogSkewLimit * a2rep)
              a1rep  <- a1 + dqrnorm(ch, mean = 0, sd = sdShift)
              MCMed <- matrix(NA_real_, ch, COLS)
              for (i in 1:COLS)
              {
                X <- drawMetalog(ch, ROWS$N[i], a1rep, a2rep, a3rep)
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
          simRow <- list(simulate = simulate, obs = DiffSample, kind = "median", note = skewNote,
                         zeroTol = 1e-20 * (1 + center^2))
          }
          }
        }
        else if (all(!is.na(ROWS$N)))
        {
          COLS <- nrow(ROWS)
          N <- sum(ROWS$N)
          Meanmean <- sum(ROWS$N*ROWS$MEAN) / N
          # THE POOLED SD (Steve's decision 2026-09-05, after the outside
          # review's finding 8). Each arm's SD was computed about its own
          # mean, so arm i carries N_i - 1 degrees of freedom and the
          # pooled variance has N - k of them (k arms). Pooling by those
          # degrees of freedom is the minimum-variance unbiased estimate
          # of a common variance, and exactly the chi-square shape the
          # square-root correction below assumes.
          #
          # Its square root is biased low (Jensen): E[s] = c4 * sigma
          # with c4 = sqrt(2/df) * Gamma((df+1)/2) / Gamma(df/2). The
          # previous code corrected with MBESS::s.u(sd, N), i.e. df = N - 1
          # - one degree of freedom too many per arm beyond the first -
          # and only below N = 30, leaving a 1% step there and a 3.8%
          # shortfall for two arms of two. Now: df = N - k, at every N,
          # through lgamma so it neither steps nor overflows.
          df <- N - COLS
          Meanvar <- sum((ROWS$N - 1) * ROWS$SD^2) / df
          c4 <- sqrt(2 / df) * exp(lgamma((df + 1) / 2) - lgamma(df / 2))
          Meansd <- sqrt(Meanvar) / c4          # the point estimate: direct-draw threshold only
          # THE SIGMA DRAW (Steve's decision 2026-09-06, "step 3"). With
          # N - k degrees of freedom the population SD is not a number but
          # an uncertain quantity, and a plug-in value - however well
          # unbiased - understates the null spread of the arm means, the
          # difference between a z test and a t test. Each replicate now
          # draws its own sigma from the scaled inverse chi-square implied
          # by the pooled variance, sigma^2 = s^2 * df / chisq(df), so the
          # simulated between-arm statistic behaves like the F it should
          # rather than the chi-square a fixed sigma gives. Measured
          # (docs/statistics.md): at three per arm the row p's distance
          # from uniform under an honest null fell 0.07 -> 0.016; the
          # 5% and 1% rates were unchanged; on the Carlisle corpus the
          # agreement with his values rose (r 0.9925 -> 0.9931), the shift
          # confined to trials of 30 or fewer per arm. No c4 correction is
          # applied to the draw: no point estimate is plugged in.
          # THE SD'S PRINTED ROUNDING (audit 2026-09-06, finding F1; Steve:
          # "do the SD rounding draw first"). A printed SD is an interval,
          # not a number: "1" at integer precision means a true sample SD
          # anywhere in [0.5, 1.5), and the row p at a tie varied by a
          # factor of 2.5 across that interval when the printed value was
          # taken as exact (0.128 at 0.5 to 0.050 at 1.49 for two arms of
          # 30, means tied at one decimal; a factor of 1.4 for a printed
          # "3", negligible at two significant figures - the audit report,
          # C:/dev/Corpus/reviews/AUDIT-2026-09-06-statistics-and-docs.md).
          # The mean's rounding needs no such treatment because the
          # simulation rounds its own means the same way and the tie mass
          # IS the mechanism; the SD is different because it enters the
          # null as a PARAMETER, so its rounding is unmodelled parameter
          # uncertainty - the same class of thing the sigma draw above
          # models. Each replicate therefore draws every arm's sample SD
          # uniformly within its printed interval (half a printed unit
          # either side, never below zero), pools those by degrees of
          # freedom exactly as Meanvar pools the printed values, and only
          # then applies the chi-square draw. hDisp is 10^-ROUND_DISPERSION;
          # validateData() infers a blank ROUND_DISPERSION from the SD's
          # printed decimals, and a direct caller without the column gets
          # the same inference here. (Meanvar itself survives for the
          # direct-draw threshold, through Meansd.)
          sdIv <- .iaSdInterval(ROWS$SD, ROWS$ROUND_DISPERSION)
          sdLo <- sdIv$lo; sdHi <- sdIv$hi
          pooledVarDraw <- function(ch) {
            v <- numeric(ch)
            for (i in 1:COLS)
              v <- v + (ROWS$N[i] - 1) * (sdLo[i] + (sdHi[i] - sdLo[i]) * stats::runif(ch))^2
            v / df
          }
          sigmaDraw <- function(ch) sqrt(pooledVarDraw(ch) * df / stats::rchisq(ch, df))
          DiffSample <- sum((ROWS$MEAN - Meanmean)^2) # Squared difference of column means
          # Monte Carlo Simulation. The simulation body is unchanged from
          # the Carlisle-validated implementation (issue 3, r = 0.991);
          # the staging wrapper only decides HOW MANY replications run.
          # FIX (2026-08-14, carried): meansim must have exactly as many
          # entries as replication rows, or the column-major fill would
          # misalign arms within a replication; simulated column means
          # round to ROUND_MEAN (the printed precision), observations to
          # ROUND_OBSERVATION.
          # per arm: the full simulation below .iaDirectDrawN, the direct
          # draw of the arm mean at or above it (see the constant's note)
          hObs   <- 10^(-ROWS$ROUND_OBSERVATION)
          direct <- ROWS$N >= .iaDirectDrawN & Meansd >= .iaDirectDrawSdOverGrid * hObs
          # the chunk size is set by the arms still simulated in full;
          # a row of direct-draw arms costs one draw per arm per replicate
          Nfull <- sum(ROWS$N[!direct])
          simulate <- function(n) {
            out <- numeric(0); left <- n
            while (left > 0) {
              ch <- min(left, max(1, floor(1e8 / max(1, Nfull))))
              sig <- sigmaDraw(ch)                      # one sigma per replicate
              # (rnorm, not dqrnorm: dqrnorm takes a scalar sd)
              meansim <- rnorm(ch, Meanmean, sig / sqrt(mean(ROWS$N)))
              MCMean <- matrix(NA_real_, ch, COLS)
              for (i in 1:COLS)
                MCMean[,i] <- if (direct[i]) {
                  # THE MEAN'S OWN GRID (outside audit, 2026-09-06): N
                  # observations on a grid of width h have a mean on a grid
                  # of width h/N, whatever precision the mean is printed
                  # to. A continuous draw ignored that grid, so with
                  # integer observations and a six-decimal printed mean
                  # (N = 100, SD 3, identical means) the direct draw gave
                  # p < 0.0001 where the full simulation gives 0.0045: the
                  # ties the grid creates were erased. The draw is snapped
                  # to that grid before the printed rounding. Where the
                  # printed precision is coarser than h/N the snap changes
                  # nothing, which is why the 0- and 1-decimal validation
                  # cells never showed it.
                  g <- hObs[i] / ROWS$N[i]
                  round(round(rnorm(ch, meansim, sqrt((sig^2 + hObs[i]^2 / 12) / ROWS$N[i])) / g) * g,
                        ROWS$ROUND_MEAN[i])
                } else round(
                  # standard normals scaled by column recycling: a length-ch
                  # vector recycles down each column of a ch-row matrix,
                  # which is exactly what rep(x, N) with byrow = FALSE gave,
                  # without two more N x ch vectors alive at the peak
                  # (screen 2026-09-06-1118 F2: 2.4 GB -> 1.6 GB on the
                  # worst 5,000-per-arm row). rnorm(n, m, s) is m + s * z,
                  # so the numbers are bit-identical under the same seed -
                  # with one edge (nightly screen 2026-09-06-2100): rnorm()
                  # consumes no draw when its sd is exactly 0, and this form
                  # always does, so a row whose arms all print SD 0 shifts
                  # the seeded stream for everything after it. The values
                  # are unchanged; only cross-build reproducibility of such
                  # a file is, and the seed is documented as build-specific.
                  rowmeans(round(
                    matrix(rnorm(ROWS$N[i] * ch), nrow = ch) * sig + meansim,
                    ROWS$ROUND_OBSERVATION[i])),
                  ROWS$ROUND_MEAN[i])
              Nmat <- matrix(ROWS$N, ch, COLS, byrow = TRUE)
              MS <- rowsums(MCMean * Nmat) / N
              out <- c(out, rowsums((MCMean - MS)^2))
              left <- left - ch
            }
            out
          }
          simRow <- list(simulate = simulate, obs = DiffSample, kind = "continuous",
                         zeroTol = 1e-20 * (1 + Meanmean^2))
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
          simRow <- list(simulate = simulate, obs = statObs, kind = "category", zeroTol = 0)
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
  # trial escalates while its own mid-p or any row's is < 0.1 (to 10,000)
  # and < 0.01 (to 100,000), so an innocuous trial costs 1,000 replicates
  # per row - and, under an honest null, a trial of k rows advances to
  # 10,000 with probability about 1 - 0.9^k (a 25-row trial: 93%), so the
  # TYPICAL cost is nearer 10,000 per row than 1,000. The worst case
  # (every row at the ceiling) is unchanged.
  usable <- which(vapply(rows, function(r) !is.null(r$sim), logical(1)))
  stages <- unique(pmin(c(1000, 10000, m), m))
  # the mid-p below which the NEXT stage runs: < 0.1 to leave 1,000,
  # < 0.01 to leave 10,000 (see the header)
  advanceBelow <- c(0.1, 0.01)
  rowStat <- vector("list", length(rows))
  trialStat <- NULL
  for (s in stages) {
    sumZ <- numeric(s); zObs <- 0
    for (j in usable) {
      sims <- rows[[j]]$sim$simulate(s)
      obs  <- rows[[j]]$sim$obs
      # A statistic that is zero up to floating-point dust IS zero: the
      # N-weighted centre of identical means leaves about 1e-28 behind,
      # and not the same 1e-28 in the replicate (Rfast's row sums) as in
      # the observed row (base R's sum), so without this snap the floor's
      # ties were split by dust and the note never appeared for unequal
      # arms. zeroTol is 1e-20 of the centre squared, far below the
      # smallest genuine difference a printed grid can make.
      zt <- rows[[j]]$sim$zeroTol
      sims[sims <= zt] <- 0; if (obs <= zt) obs <- 0
      kk <- .iaTieCounts(sims, obs)            # ties by the bounded criterion, see .iaTieTol
      kLess <- kk[["kLess"]]; kEq <- kk[["kEq"]]
      # Distribution graphs (issue 16): keep the FIRST stage's simulated
      # statistics - they ARE the expected distribution under honest
      # sampling, generated anyway and normally discarded.
      draws <- if (!is.null(graphs) && is.null(rowStat[[j]])) sims else rowStat[[j]]$draws
      # THE ATTAINABLE FLOOR (Steve, 2026-09-04). A row sits at its floor
      # when no honest replicate agrees better than the printed table:
      # the observed statistic is at (or below) the smallest simulated
      # one, so its mid-p is the smallest value this row's printed
      # precision allows. For integer means in a large trial that floor
      # is high - both arms converge on the same integer, as they must -
      # and the row cannot alarm however the data were made; for a
      # finely printed row it is small and the row alarms. Either way
      # the note tells the reader the row has said everything its
      # rounding lets it say.
      rowStat[[j]] <- list(kLess = kLess, kEq = kEq, m = s, draws = draws,
                           # the floor is a property of the OUTCOME, not of a
                           # simulation that happened not to visit the tail:
                           # the observed statistic must be the minimum
                           # (zero: the arms agree exactly) AND no replicate
                           # beat it. Two means of 77 and 77.000001 used to
                           # carry the note (outside audit, 2026-09-06).
                           # (obs was snapped to exactly zero above when it
                           # was zero up to floating-point dust)
                           atFloor = kLess == 0 && isTRUE(obs == 0))
      pRep <- .floorP((.iaTieRank(sims) - 0.5) / s, s)
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
    k <- match(s, stages)
    if (k >= length(stages)) break
    # an NA mid-p (a degenerate row the validator did not catch) must not
    # crash the stage loop - treat it as resolved (break test, 2026-09-06)
    if (is.na(trialMid)) trialMid <- 1
    rowMid[is.na(rowMid)] <- 1
    if (trialMid >= advanceBelow[k] && all(rowMid >= advanceBelow[k])) break
  }

  # The rows' report lines, from the final stage's counts.
  x <- do.call(rbind, lapply(seq_along(rows), function(j) {
    r <- rows[[j]]
    if (is.null(r$sim))
      return(data.frame(ROW = r$Row, P = r$Pdisp, CI95 = "", M = NA_character_,
                        NOTE = "", KIND = "variable", .PNUM = NA_real_, .KLE = NA_real_,
                        stringsAsFactors = FALSE))
    rep <- .rowReport(rowStat[[j]])
    if (!is.null(graphs))
      graphs$rows[[length(graphs$rows) + 1]] <-
        # the slide prints the row's DISPLAY string and final stage size,
        # not a number judged against the first stage's 1,000 draws
        # (screen 2026-09-06-0814, informational)
        list(trial = TRIAL, row = r$Row, kind = r$sim$kind,
             obs = r$sim$obs, draws = rowStat[[j]]$draws, p = rep$p,
             disp = rep$disp, m = rep$m)
    data.frame(ROW = r$Row, P = rep$disp, CI95 = rep$ci, M = as.character(rep$m),
               # the notes a row can carry, joined: the attainable floor
               # and, for a median row, a clipped skew term
               NOTE = paste(c(if (isTRUE(rowStat[[j]]$atFloor)) "attainable floor",
                              if (!is.null(r$sim$note) && nzchar(r$sim$note)) r$sim$note),
                            collapse = "; "),
               KIND = "variable", .PNUM = rep$p, .KLE = rep$kLE, stringsAsFactors = FALSE)
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
      # The lower end comes from the STRICTLY-beyond count and the upper
      # end from the at-or-beyond count, exactly as the row interval is
      # built, so the interval brackets the mid-p. It used to take both
      # ends from the at-or-beyond count: at the attainable floor, where
      # every "beyond" is a tie (three integer rows of two arms of 20
      # tie the observed sum ~90 times in 100,000 and never exceed it),
      # the mid-p is half the tie count and sat BELOW its own interval -
      # "0.00042, interval 0.00067 to 0.001". Found by an outside review,
      # reproduced, 2026-09-06.
      kG <- trialStat$kG
      lower <- if (kG == 0) 0 else stats::qbeta(0.025, kG, mT - kG + 1)
      ciStr <- paste0(signif(lower, 2), " to ", signif(upper, 2))
    }
  } else {
    # FIX (carried): length(Pv[use]) == 1 vs the old length(x == 1) trap
    # FIX (outside review, 2026-09-05): with one usable row the trial IS
    # that row, so the Summary carries the row's display and interval.
    # It used to print the row's numeric floor raw - a zero-hit row
    # showing "<0.0001 (0 to 3.7e-05)" gave a Summary of
    # 9.99990000099999e-06 with no interval, more precise-looking
    # exactly where the simulation had reached its resolution limit.
    if (sum(use) == 1)
    {
      P <- x$P[use]
      ciStr <- x$CI95[use]
    }
    if (sum(use) == 0)
      P = "No values"
  }

  # THE KIND COLUMN (2026-09-07; the GPT-6 audit's finding F2, docs/audits/).
  # The trial's summary line used to be recognisable only by the text
  # "Summary" in ROW, and the API, the results workbook and the graphs
  # all found it that way - so a VARIABLE the paper happened to call
  # "Summary" was taken for a second trial summary, entered the
  # across-trial combination as another trial, and moved the overall p
  # (0.046 -> 0.0087 on the worked example, reproduced). Every line now
  # says what it is: "variable", "summary", or NA on the spacer. Consumers
  # read KIND, never the label.
  lastline <- data.frame(
    TRIAL = c(NA, NA),
    ROW = c("Summary", NA),
    P = c(as.character(P), NA),
    CI95 = c(ciStr, NA),
    M = c(NA, NA),
    NOTE = c("", NA),
    KIND = c("summary", NA),
    .PNUM = c(NA, NA),
    .KLE = c(NA, NA)
  )

  x <- rbind(x, lastline)
  # internal bookkeeping columns stay out of the results
  x <- x[, c("TRIAL", "ROW", "P", "CI95", "M", "NOTE", "KIND")]
  outputComments(
    paste0("Trial ", TRIAL,": p = ", P,
           if (nzchar(ciStr)) paste0(" (95% Monte Carlo interval ",
                                     ciStr, ")")
           else "", "\n")
  )
  return(x)
}
