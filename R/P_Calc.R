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
#     its own mid-p or any row's is < 0.1 (leaving 1,000) or < 0.01
#     (leaving 10,000) - the two thresholds in advanceBelow. The trial p is floored at
#     1/(m+1) like a row, displays "<0.0001" under the same bound rule,
#     and carries an exact Clopper-Pearson 95% interval when < 0.001.
#     This replaced the closed-form Stouffer sum and its parametric
#     bootstrap; the error was in the Monte Carlo's combination step,
#     which Steve wrote, not in Carlisle's method.

# The Davison-Hinkley floor and the 0.9999 ceiling, applied to a row's
# mid-p and to every replicate's mid-p alike (the exact combination needs
# both on the same footing).
.floorP <- function(p, m) pmin(pmax(p, 1 / (m + 1)), 0.9999)

# THE NULL LAW'S KEY (full independent audit 2026-09-10, F1). Two rows
# whose simulated nulls are the same distribution share ONE score mapping
# in the exact combination - see the stage loop. A continuous or median
# row's null is fixed by every numeric input its simulation reads, so the
# key is all of them, formatted to full precision; the categorical branch
# keys on its margins (see there). Rows with different inputs get
# different keys and are mapped, as before, through their own draws.
.iaNullKey <- function(kind, ROWS) {
  cols <- intersect(c("N", "MEAN", "SD", "SE", "Q1", "Q3", "ROUND_MEAN",
                      "ROUND_DISPERSION", "ROUND_OBSERVATION"), names(ROWS))
  paste(kind, paste(vapply(cols, function(cn)
    paste(format(ROWS[[cn]], digits = 17), collapse = ","), character(1)),
    collapse = ";"))
}

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
  gap <- diff(s)
  # a non-finite gap (an infinite or missing statistic, unreachable from
  # validated input) starts its own group rather than joining the largest
  # finite one (screen 2026-09-07-1441, I2)
  newGroup <- c(TRUE, gap > .iaTieTol * pmax(abs(s[-1L]), abs(s[-n])) | !is.finite(gap))
  first <- which(newGroup); last <- c(first[-1L] - 1L, n)
  r <- numeric(n); r[o] <- ((first + last) / 2)[cumsum(newGroup)]
  r
}

#' The strictly-below and tied counts of `sims` against `obs`, ties by .iaTieTol
#' @noRd
.iaTieCounts <- function(sims, obs) {
  # a non-finite statistic is never a tie (Inf <= Inf would say otherwise)
  eq <- is.finite(sims) & abs(sims - obs) <= .iaTieTol * pmax(abs(sims), abs(obs))
  eq[is.na(eq)] <- FALSE
  c(kLess = sum(sims < obs & !eq, na.rm = TRUE), kEq = sum(eq))
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
# below 1.66711 (Keelin 2016); a fit beyond that is clipped to the limit
# below - 1.66, just inside Keelin's bound - rather than refused
# (2026-09-07, see the median branch)
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

# THE NUMERICAL-RESOLUTION REFUSAL (GPT-6 audit F7, 2026-09-07).
# The validator caps a value's magnitude (1e12) and its printed decimals
# separately, and neither cap asks whether the two are compatible. A
# double carries about 15.7 significant digits: at a magnitude of 1e11 the
# spacing between representable numbers is about 2e-5, so a table printing
# twenty decimals there is asking for a resolution the arithmetic does not
# have. The simulation then rounds on the floating-point grid instead of
# the printed one, silently. The audit's demonstration: 100 and 101 per
# arm, identical means, SD 1e-6, twenty decimals: at means of zero the row
# reaches the replicate floor (0.000999), and translating both means to
# 1e11 gives 0.5 - the draws collapse. The drift is visible well before
# the collapse (0.004 at 1e4, 0.046 at 1e5, 0.35 at 1e6).
#
# So the row is refused when the finest printed grid it asks for is not
# comfortably representable at its own magnitude. The factor of 8 is three
# bits of headroom: rounding to a grid only a few units of least precision
# wide is arithmetic, not measurement. Ordinary tables are nowhere near
# it - two decimals at 1e12, the validator's ceiling, still has 45 units
# of least precision per printed step - and the shapes the screens pinned
# (a thousand arms printing 1e9 + 0.25, five thousand per arm at 1e9)
# pass unchanged.
.iaResolutionFactor <- 8

# `mag` the row's largest printed magnitude, `dec` its printed decimals
# (every column that sets a grid); NULL when the row is representable.
.iaResolutionRefusal <- function(mag, dec) {
  mag <- suppressWarnings(max(abs(mag[is.finite(mag)]), 0))
  dec <- suppressWarnings(max(dec[is.finite(dec)], 0))
  if (!is.finite(mag) || mag <= 0 || !is.finite(dec)) return(NULL)
  ulp  <- .Machine$double.eps * mag
  grid <- 10^(-dec)
  if (grid >= .iaResolutionFactor * ulp) return(NULL)
  sprintf(paste("Printed precision beyond this magnitude's numerical resolution",
                "(%d decimals at %s needs more than the 15 significant digits",
                "a double carries)"), as.integer(dec), format(mag, digits = 3))
}

# THE STATED PRECISION MUST MATCH THE PRINTED DIGITS (security screen
# 2026-09-07-1758, finding F1). A precision column says what grid the
# printed number sits on, and the engine turns that grid into an interval:
# a printed SD stands for +/- half a grid step (2026-09-06), and since the
# quartile draw a printed quartile does too (2026-09-07). Nothing bounded
# the grid against the number it describes. A single cell of a supplied
# spreadsheet or a posted template - ROUND_DISPERSION = -5, which the
# validator accepted anywhere in [-20, 20] - therefore multiplied the
# null's spread by 100,000 and drove an honest row to the reportable
# floor. Measured on an honest two-arm median row (N = 40, medians 50 and
# 52, quartiles 45-55 and 47-57, m = 10,000): p = 0.64 at 0, 0.187 at -3,
# 0.0049 at -5, and 9.999e-05 - a maximal alarm - at -10 and below. The
# mean/SD branch carried the same lever: 0.624, 0.037, 9.999e-05.
#
# The test is not "is the grid coarse" - a table may honestly report
# quartiles to the nearest ten, and a variable whose interquartile range
# is smaller than one printed unit is exactly the case the quartile draw
# was built for. It is whether the PRINTED VALUE SITS ON THE STATED GRID.
# Quartiles of 40 and 60 with a grid of 10 are consistent and analyzed;
# quartiles of 45 and 55 with a grid of 10, or of 100,000, are not a
# reading of that page, and the row is refused with the reason instead of
# simulated on a fabricated interval.
# `x` the printed values and `dec` the precision stated for EACH of them
# (recycled, one column's precision against that column's numbers - the
# coarsest grid is what matters, so a value must never be judged against
# another column's finer one).
.iaOnStatedGrid <- function(x, dec) {
  dec <- suppressWarnings(as.numeric(rep(dec, length.out = length(x))))
  ok <- is.finite(x) & is.finite(dec)
  if (!any(ok)) return(TRUE)
  x <- x[ok]; h <- 10^(-dec[ok])
  # a value is on the grid when it is a whole number of steps from zero,
  # within the arithmetic's own dust at that magnitude
  # the tolerance absorbs floating-point dust, which is proportional to the
  # VALUE - never to the grid, or a grid of 1e20 would swallow every number
  # ever printed
  all(abs(x - round(x / h) * h) <= 1e-9 * abs(x))
}

# ...and the two holes the first version of that gate left (security screen
# 2026-09-07-1907).
#
# F2, zero. Zero sits on every grid, so a row whose printed values are all
# zero - "rescue analgesia, median (IQR): 0 (0-0)", a shape a large share
# of analgesia trials carry - passed the gate at any stated precision, and
# ROUND_DISPERSION = -20 drew its quartiles across 1e19 and drove the row
# from its honest p = 0.5 to below 0.0001. Such a row states no scale of
# its own, so the only thing left to check is that its precision columns
# agree with each other: a dispersion grid coarser than the location's is
# a claim the page cannot be making.
.iaZeroRowGridOK <- function(values, decLoc, decDisp) {
  v <- values[is.finite(values)]
  if (!length(v) || max(abs(v)) > 0) return(TRUE)     # not a zero row
  n <- max(length(decLoc), length(decDisp))
  dl <- suppressWarnings(as.numeric(rep(decLoc, length.out = n)))
  dd <- suppressWarnings(as.numeric(rep(decDisp, length.out = n)))
  ok <- is.finite(dl) & is.finite(dd)
  if (!any(ok)) return(TRUE)
  # ARM BY ARM, not minimum against minimum: precisions of c(-20, 0) beside
  # c(-20, -20) pass a comparison of minima while the second arm still
  # claims a dispersion grid of 1e20 against a location grid of 1
  # (CodeRabbit on PR #220)
  all(dd[ok] >= dl[ok])                    # dispersion no coarser than location
}

# F1, the third precision column. ROUND_OBSERVATION sets the grid every
# simulated observation is rounded to, and a coarse one quantises the
# replicates while the printed values stay put: the null's spread inflates
# and honest data looks impossibly alike. Measured by the screen on honest
# rows: five arms of 40 read p = 0.433 at an honest 0 and p = 0.0125 at -2;
# integer means near 50,000 read 0.586 and 0.00013 at -5. The consistency
# rule for it: a statistic computed from N observations on a grid of hObs
# lies on a grid no coarser than hObs/divisor, so the interval the printed
# value stands for must contain a multiple of it. The test is vacuous
# whenever that step is no coarser than the printed value's own, which is
# every ordinary table.
#
# The divisor is the caller's, because it differs by statistic: a MEAN of N
# observations moves in steps of hObs/N, but a MEDIAN moves in steps of
# hObs (odd N, it is an observation) or hObs/2 (even N, the average of the
# two central ones) - far coarser, so passing N there would accept medians
# no rounded sample could produce (CodeRabbit on PR #220).
# F1 of screen 2026-09-07-2000: the location-side rule above is vacuous
# wherever hObs/N is finer than the printed mean's own step, which an
# attacker arranges by picking N - at a thousand per arm and integer means,
# an observation grid of a thousand passes unconditionally. The
# DISPERSION side closes it, and it is a theorem rather than a heuristic:
# N values on a grid of width h have a sample SD that is either exactly 0
# (every value the same) or at least h/sqrt(N). A table claiming SD 1 for
# a thousand values on a grid of a thousand is arithmetically impossible,
# and it was simulated anyway - three arms of 1,000 printing mean 500 and
# SD 1 read p = 0.5 honestly and 9.999e-05, the reportable floor with the
# "attainable floor" note, at ROUND_OBSERVATION = -3.
#
# The printed SD's own interval is used (its upper end), so no honestly
# coarse table is refused for the width of its own printing.
.iaSdReachesGrid <- function(sd, decDisp, decObs, decVal, N, meanVal) {
  n <- max(length(sd), length(decDisp), length(decObs), length(decVal),
           length(N), length(meanVal))
  sd <- rep(sd, length.out = n); decDisp <- rep(decDisp, length.out = n)
  decObs <- rep(decObs, length.out = n); decVal <- rep(decVal, length.out = n)
  N <- rep(N, length.out = n); meanVal <- rep(meanVal, length.out = n)
  ok <- is.finite(sd) & is.finite(decObs) & is.finite(decVal) &
        is.finite(meanVal) & is.finite(N) & N > 0
  if (!any(ok)) return(TRUE)
  sdN <- sd[ok]; Nn <- N[ok]
  # the printed SD's interval, from the same helper the simulation uses,
  # so a blank or absent ROUND_DISPERSION is INFERRED from the SD's own
  # printed decimals rather than leaving the test vacuous (an absent
  # column made hDisp empty, and every row passed) or falsely strict (an
  # NA made it zero) - CodeRabbit on PR #221
  sdHi  <- .iaSdInterval(sdN, if (is.null(decDisp)) NULL else decDisp[ok])$hi
  hObs  <- 10^(-decObs[ok])
  hVal  <- 10^(-decVal[ok])
  # ONLY where the observation grid is genuinely coarser than the printed
  # value's own (screen 2026-09-07-2101, finding F5). A blank
  # ROUND_OBSERVATION defaults to ROUND_MEAN, which is a GUESS - "a mean
  # printed to d decimals means the observations lie on a grid of 10^-d" -
  # and it is false for any continuous variable whose mean happens to
  # print without decimals. Turning that guess into a refusal threw out
  # honest rows: "2 +/- 0.2" at eight patients was refused, and a refused
  # row leaves the trial silently. Where the two grids agree the
  # quantisation this bound is about cannot happen, so the test does not
  # apply; where the table STATES a coarser observation grid, it does.
  stated <- hObs > hVal * (1 + 1e-9)
  if (!any(stated)) return(TRUE)
  # ...and the sharp form of the theorem (finding F1). For values on a
  # lattice of width h whose sample mean is m, SD >= h * alpha with
  # alpha = dist(m/h, integers) - the previous version used alpha's
  # minimum feasible value, 1/sqrt(N), which at a thousand per arm is a
  # factor of sixteen of headroom left exactly at the operating point the
  # earlier screen had named (a mean sitting near a half-grid point).
  # alpha is minimised over the printed mean's OWN interval, so no honest
  # table is refused for the width of its own printing.
  a <- (meanVal[ok] - hVal / 2) / hObs
  b <- (meanVal[ok] + hVal / 2) / hObs
  spansInt <- floor(b + 1e-12) >= ceiling(a - 1e-12)
  dist2int <- function(x) abs(x - round(x))
  alpha <- ifelse(spansInt, 0, pmin(dist2int(a), dist2int(b)))
  # two different quantities, and the larger governs: hObs * alpha is what
  # the mean's own offset from the lattice forces, and hObs / sqrt(N) is
  # the smallest NON-ZERO sample SD any N values on that lattice can have
  # (one value a step away from the rest). alpha itself can be as small as
  # 1/N, so neither implies the other.
  bound <- hObs * pmax(alpha, 1 / sqrt(Nn))
  # An SD of exactly zero means every value was identical, so the mean IS
  # one of them and must itself sit on the lattice - which it cannot when
  # the printed mean's interval holds no multiple of the grid. The zero
  # carve-out therefore needs that interval to span one (CodeRabbit on PR
  # #222); without the condition, "mean 500, SD 0" on a grid of 1,000
  # passed as an honest constant arm.
  all(!stated | (sdN == 0 & spansInt) | sdHi >= bound * (1 - 1e-9))
}

# F2 of the same screen: .iaOnStatedGrid is one-sided by construction -
# every decimal sits on every FINER grid - so a stated precision finer than
# the printed value passes every check above. An over-fine ROUND_MEAN
# erases the rounding of the simulated arm means, and the tie mass that
# rounding creates IS how an honest table with identical printed means
# earns a large p: three arms of 30 printing mean 0.5 read 0.4185 at
# ROUND_MEAN = 1 and 9.999e-05 at 15.
#
# This one is NOT a refusal, and the reason matters. A mean stored as 50
# may have been printed "50" or "50.000000" - a spreadsheet keeps no
# trailing zeros - so the honest row and the manipulated one are the same
# numbers. The engine cannot tell them apart, and the 2026-09-06 outside
# audit's own case is the honest one: integer observations with a
# six-decimal printed mean, where the small p IS the right answer, because
# means agreeing to six decimals is remarkable. So the row is analysed as
# the table claims and the claim is DISCLOSED in the Note, where an editor
# reading a small p can see what it rests on. The two decimals of slack
# cover the trailing zeros a spreadsheet drops when it stores "1.20".
# The slack is ZERO for the note (screen 2026-09-07-2101, finding F2). At
# two decimals of slack the row was already at the reportable floor with
# no note at all: printed means of 0.5 with ROUND_MEAN 3 read 9.999e-05
# and said nothing. A note is the cheap side of an error - one on an
# honest row that lost a trailing zero costs nothing, one missing from a
# manipulated row costs an accusation - so any stated mean precision past
# the printed digits is disclosed.
.iaMeanPrecisionSlack <- 0L
# the Note the row carries when that claim is made, so a small p never
# arrives without the thing it rests on
.iaFinePrecisionNote <- function(value, dec, identical = TRUE) {
  # THE ENGINE'S OWN TEST OF "these arms are equal", not a second and
  # stricter one (security screen 2026-09-07-2339, finding F1). Two
  # patches tried to define equality here - bitwise, then to the values'
  # own decimals - and each was defeated by perturbing one arm a little
  # further, because both quantities are computed from the same
  # attacker-supplied doubles. The engine already has an answer: it snaps
  # an observed statistic below zeroTol to zero, so for means near 0.5
  # every perturbation up to about 1.4e-13 gives a bitwise-identical p at
  # the reportable floor. The caller passes THAT verdict in, and the gap
  # the two definitions left between them closes by construction.
  v <- value[is.finite(value)]
  if (length(v) < 2) return("")
  # EITHER definition of "the arms are equal" is enough, so an attacker
  # must defeat both: the engine's own verdict (the observed statistic
  # snapped to zero), and equality at the fewest decimals any arm carries.
  # A perturbation small enough to keep the p at the floor but large
  # enough to clear zeroTol - 1e-12 on means of 0.5 - passes the first and
  # not the second (security screen 2026-09-07-2339, F1).
  shownMin <- min(vapply(v, .iaDecimals, integer(1)))
  shownMax <- max(vapply(v, .iaDecimals, integer(1)))
  # ...AND the arms must actually be close (security screen
  # 2026-09-08-0709, F1). Rounding to the FEWEST decimals any arm carries
  # is not on its own evidence that the arms agree, because a spreadsheet
  # stores 45.0 as the double 45 and .iaDecimals() then reports zero
  # decimals for that arm. On a perfectly ordinary row printing
  # 45.2 / 45.0 / 44.8 the minimum is 0, all three round to 45, and the
  # note fired - telling the editor the arms "print alike" when the page
  # shows them differing in the first decimal. Worse, the inferred
  # ROUND_MEAN is the row MAXIMUM across arms, so on any row with mixed
  # decimal counts the suppression gate below could never fire either.
  # The note is the whole adjudicated remedy for the shape screen 2000
  # declined to refuse, and a note that appears on most rows discloses
  # nothing; it is also a cheap lever, since printing one arm with a
  # trailing zero would have hung the note on any row an author chose.
  # So the arms must also lie within one step of the FINEST precision
  # printed - the same "within one step, or the claim did not decide the
  # answer" gate .iaCoarsePrecisionNote() applies below. The 1e-3 is dust
  # allowance, not slack: 0.5000000000001 - 0.5 reads 1.000311e-13, so a
  # 1e-9 allowance would fail the pinned 1e-13 perturbation.
  alike <- isTRUE(identical) ||
           (length(unique(round(v, shownMin))) == 1L &&
            diff(range(v)) <= 10^(-shownMax) * (1 + 1e-3))
  if (!alike) return("")
  # ...and the digits the values carry is the MINIMUM across the arms, not
  # the maximum: giving one arm fifteen decimals must not raise the bar
  # the stated precision is measured against, which is how the same
  # perturbation slipped past the first gate as well.
  if (.iaStatedPrecisionNotTooFine(v, dec, use = min)) return("")
  d <- suppressWarnings(as.numeric(dec))
  # Worded for what the engine can actually see. A spreadsheet stores
  # "5.0" as 5, so a stated precision past the surviving digits may be
  # perfectly honest - the note must not assert otherwise, only say what
  # rests on it (screen 2026-09-07-2101, F2, at slack zero).
  # "equal at the digits they print" rather than "print alike": the
  # first branch of `alike` admits arms the engine judged equal by its
  # own zero snap, which is not the same as printing the same characters
  # (screen 2026-09-08-0709, F1, second half).
  paste0("the stated mean precision (", max(d[is.finite(d)]),
         " decimals) exceeds the digits these values carry, and the arms ",
         "are equal at the digits they print, so the p rests on that ",
         "precision - check it against the page")
}

# The mirror of the note above (security screen 2026-09-07-2241, finding
# F2). Every guard added this week points at the ACCUSATION direction - a
# stated precision that drives p down. A precision stated COARSER than the
# printed digits drives p the other way, by manufacturing tie mass in the
# simulated arms, and it is the direction an author benefits from: three
# arms of 100 printing an integer 50 with SD 30 read p = 9.999e-05 at
# ROUND_MEAN 1 and p = 0.275 at ROUND_MEAN -1, and a median row's
# ROUND_OBSERVATION took p = 0.0557 to 0.5. Neither is refused, because
# neither is impossible - a paper printing "50" may honestly have rounded
# to tens - so the claim is disclosed instead, on the rows where it
# decides the answer.
.iaCoarsePrecisionNote <- function(value, decLoc) {
  # ROUND_OBSERVATION is deliberately NOT part of this (security screen
  # 2026-09-07-2339, finding F2). A measurement recorded as an integer
  # beside a mean printed to one decimal is the normal case, and the
  # user guide's own worked example teaches it, so a note there fires on
  # honest rows - including alarming ones, where it asserted that a large
  # p rested on a claim that had moved the p by nothing. The mechanism
  # the note describes is the MEAN's own grid. The observation grid's
  # effect on a median row is real and undisclosed, and is part of the
  # dispersion-side test left open for Steve Shafer in the log.
  v <- value[is.finite(value)]
  if (!length(v)) return("")
  shown <- max(vapply(v, .iaDecimals, integer(1)))
  d <- suppressWarnings(as.numeric(decLoc))
  d <- d[is.finite(d)]
  if (!length(d) || min(d) >= shown) return("")
  # ...and only where the coarse grid can actually change the answer: the
  # printed locations must fall within one step of it, so that rounding
  # could merge them. Locations 0 and 100 on a grid of ten stay ten steps
  # apart and their large p owes nothing to the claim - saying otherwise
  # would be a false causal statement (CodeRabbit on PR #224).
  h <- 10^(-min(d))
  if (diff(range(v)) > h * (1 + 1e-9)) return("")
  paste0("the stated mean precision (", min(d),
         " decimals) is coarser than the digits these values carry, which ",
         "widens the rounding the arms are judged against; this row's p ",
         "rests on that claim - check it against the page")
}

# THE ZERO SNAP, defined once (security screens 2026-09-08-0709 F4 and
# -1048 F1). Two separate defects met here.
#
# F4 was that the note's idea of "the arms are equal" and the engine's
# were the same expression WRITTEN TWICE, six lines apart, in each of two
# branches. They agreed, but nothing made them agree, and the tolerance
# has already been changed three times on the record. One binding, used
# by both, is the property the commit that introduced them claimed.
#
# 1048 F1 was that the expression itself - 1e-26 * (1 + centre^2) - is a
# property of the COORDINATE SYSTEM, not of the thing it thresholds. The
# statistic is a sum of squared DIFFERENCES of means: unchanged when a
# constant is added to every arm, multiplied by k^2 when the units are
# scaled by k. The old tolerance was quadratic in an arbitrary origin and
# had an absolute floor of 1e-26 at small magnitudes, so an author's free
# choice of origin or units moved it independently of the data. Measured
# on this machine, three arms of 1,000 with SD 0.001 and means differing
# by 2e-5, 3e-5 and 5e-5:
#
#     printed difference     at origin 0     at origin 1e9
#     2e-5                   p = 0.3105      p = 0.492
#     3e-5                   p = 0.573       p = 0.492
#     5e-5                   p = 0.897       p = 0.492
#
# At the large origin the tolerance (1e-8) swallowed the observed
# statistic and almost every replicate, so the p stopped depending on the
# data at all and sat at the tie-dominated 0.49 whatever the arms said.
# Nothing refused those rows: the resolution refusal, the stated-grid
# check and the validator's ceiling all pass.
#
# The 1048 fix scaled the tolerance to the TRANSLATED deviations of the
# observed row, 1e-12 * max(dd^2), floored at 1e-12 * step^2 so that it
# did not collapse to exactly zero when the arms agree - which, until the
# 2026-09-09 audit's F6, was the one case the snap existed for.
#
# THE OBSERVED TERM IS GONE (independent audit 2026-09-10, F1). It made
# what counts as zero in an ordinary SIMULATED null depend on how far
# apart the OBSERVED arms are: a row printing 0 and 10,000,000 (four
# decimals, arms of 100) set the tolerance to 100, every one of its
# 100,000 replicate statistics (range 0 to 0.19, 4,292 distinct integer
# distances, 31 genuine zeros) snapped to zero, and the row's null
# contributed a constant z where it should have contributed its rank.
# The observed row itself was nowhere near zero, so its own contribution
# stayed - the observed combination and its null no longer described
# the same calculation, and the trial p read 0.00609 where an
# integer-distance reference on the same draws gives 0.01979: an
# accusing-direction crossing of 0.01 manufactured by the guard. The
# audit's repair target is followed: the observed range must not erase
# simulated variation, and any residual guard must be bounded by the
# arithmetic of the statistic and preserve distinct attainable values.
#
# WHAT REMAINS is the printed grid alone: 1e-12 times the square of the
# finest printed step of the row's means. Since F6 every replicate is
# translated by its own first arm, so arms that drew the same rounded
# mean are the same double and their statistic is structurally zero -
# no dust arises to be forgiven, and the audit measured the p bit-
# identical with the snap removed entirely (continuous, median, unequal
# N). The floor is kept as the guard it was always meant to be, and it
# is inert by construction: the statistic is a sum of squared deviations
# from the N-weighted centre of means on the printed grid, and the
# smallest value two DISTINCT readings on that grid can produce is at
# least half the step squared (one arm a step from the rest: the two
# deviations are step*(1 - w) and step*w with w its share of N, whose
# squares sum to at least step^2/2) - eleven orders above the tolerance
# - while the floating error in these sums is many orders below it. So
# mathematically equal statistics are not split and distinct ones are
# never merged, at any origin, in any units, whatever the observed arms
# say. The step has the invariances an origin did not: it does not move
# when a constant is added to every arm, and it scales with the units
# exactly as the statistic does.
.iaZeroSnapTol <- function(h = numeric(0)) {
  hh <- h[is.finite(h) & h > 0]
  if (!length(hh)) return(0)
  1e-12 * min(hh)^2
}

# the finest printed step among the arms' stated mean precisions, which is
# what .iaZeroSnapTol() floors on
.iaMeanStep <- function(dec) {
  d <- suppressWarnings(as.numeric(dec))
  d <- d[is.finite(d)]
  if (!length(d)) return(numeric(0))
  10^(-d)
}

.iaStatedPrecisionNotTooFine <- function(value, dec, use = max) {
  n <- max(length(value), length(dec))
  value <- rep(value, length.out = n); dec <- suppressWarnings(as.numeric(rep(dec, length.out = n)))
  ok <- is.finite(value) & is.finite(dec)
  if (!any(ok)) return(TRUE)
  # `use` is the caller's: max() asks whether ANY printed value carries
  # that many digits (the right question for a refusal), min() whether
  # EVERY one does (the right question for the note, where one arm given
  # extra decimals must not raise the bar - screen 2026-09-07-2339, F1)
  shown <- use(vapply(value[ok], .iaDecimals, integer(1)))
  all(dec[ok] <= shown + .iaMeanPrecisionSlack)
}

.iaObservationGridOK <- function(value, decValue, decObs, N) {
  n <- max(length(value), length(decValue), length(decObs), length(N))
  value <- rep(value, length.out = n); decValue <- rep(decValue, length.out = n)
  decObs <- rep(decObs, length.out = n); N <- rep(N, length.out = n)
  ok <- is.finite(value) & is.finite(decValue) & is.finite(decObs) & is.finite(N) & N > 0
  if (!any(ok)) return(TRUE)
  value <- value[ok]; hVal <- 10^(-decValue[ok]); step <- 10^(-decObs[ok]) / N[ok]
  # the printed value stands for [value - hVal/2, value + hVal/2]; is there
  # a multiple of `step` inside it? (with the arithmetic's dust allowed for)
  half <- hVal / 2 + 1e-9 * pmax(abs(value), step)
  all(abs(value - round(value / step) * step) <= half)
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
#'     \item{`ROUND_DISPERSION`}{decimals printed for the dispersion
#'       measure: SD/SE on a mean line, the quartiles on a median line.
#'       Absent or blank: inferred from the printed decimals of `SD`
#'       (or, on a median line, of `Q1` and `Q3`).}
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
P_Calc <- function(TRIAL, DATA, CategoryNames, m, graphs = NULL,
                   excluded = NULL)
{
  # excluded: optional frame of the rows validateData() left out of DATA
  # (its Excluded element: TRIAL, ROW, REASON, ...), so that they are
  # counted on the Summary line and listed in the results - independent
  # audit 2026-09-10, F3; see the note where they are appended below.
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
        else if (!(.iaOnStatedGrid(ROWS$MEAN, ROWS$ROUND_MEAN) &&
                   .iaOnStatedGrid(ROWS$SD, ROWS$ROUND_DISPERSION) &&
                   (!isQuartile ||
                    (.iaOnStatedGrid(ROWS$Q1, ROWS$ROUND_DISPERSION) &&
                     .iaOnStatedGrid(ROWS$Q3, ROWS$ROUND_DISPERSION))) &&
                   # every arm's printed location must be reachable from
                   # observations on the stated OBSERVATION grid (screen
                   # 1907 F1: the third precision column drove the same
                   # false-accusation lever the other two were closed for)
                   .iaObservationGridOK(ROWS$MEAN, ROWS$ROUND_MEAN,
                                        ROWS$ROUND_OBSERVATION,
                                        # a median's own lattice, not a mean's
                                        if (isQuartile)
                                          ifelse(ROWS$N %% 2 == 0, 2, 1)
                                        else ROWS$N) &&
                   # ...and a row of nothing but zeros, which sits on every
                   # grid, must at least have precision columns that agree
                   # with each other (screen 1907 F2)
                   .iaZeroRowGridOK(c(ROWS$MEAN, ROWS$SD,
                                      if (isQuartile) c(ROWS$Q1, ROWS$Q3)),
                                    ROWS$ROUND_MEAN, ROWS$ROUND_DISPERSION) &&
                   # the dispersion side of the observation grid: values on
                   # a lattice cannot have an SD below h/sqrt(N) unless they
                   # are all identical (screen 2000 F1). The median branch
                   # needs no analogue - its divisor of 1 or 2 already holds
                   # hObs to within a factor of two of the median's grid.
                   (isQuartile ||
                    .iaSdReachesGrid(ROWS$SD, ROWS$ROUND_DISPERSION,
                                     ROWS$ROUND_OBSERVATION, ROWS$ROUND_MEAN,
                                     ROWS$N, ROWS$MEAN))))
        {
          # a stated grid the printed numbers do not sit on (screen 1758 F1,
          # extended by screen 1907's F1 and F2)
          Pdisp <- paste("The stated precision does not match the printed",
                         "values (check ROUND MEAN, ROUND DISPERSION and",
                         "ROUND OBSERVATION)")
        }
        else if (!is.null(resRefusal <- .iaResolutionRefusal(
                   c(ROWS$MEAN, if (isQuartile) c(ROWS$Q1, ROWS$Q3)),
                   c(ROWS$ROUND_MEAN, ROWS$ROUND_OBSERVATION,
                     # a median row's quartile precision is inferred from the
                     # printed quartiles where the column is blank, which is
                     # how the row arrives from the parser - and the inferred
                     # value can be FINER than the median's, so inferring
                     # after this test would let such a row through
                     # (CodeRabbit on PR #218)
                     if (isQuartile) {
                       qd <- if (!is.null(ROWS$ROUND_DISPERSION))
                         suppressWarnings(as.numeric(ROWS$ROUND_DISPERSION))
                       else rep(NA_real_, nrow(ROWS))
                       if (any(is.na(qd)))
                         qd[is.na(qd)] <- max(vapply(c(ROWS$Q1, ROWS$Q3),
                                                     .iaDecimals, integer(1)))
                       qd
                     }))))
        {
          # the printed grid is finer than this magnitude can carry, so
          # the simulation would round on the floating-point grid instead
          # of the printed one and say nothing about it (GPT-6 audit F7)
          Pdisp <- resRefusal
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
          # THE QUARTILES' PRINTED INTERVALS (Steve's decision, 2026-09-07,
          # after the GPT-6 audit's F4). A printed quartile stands for an
          # interval half a printed unit either side, exactly as a printed
          # SD does (2026-09-06). Fitting the metalog to the printed
          # values as if exact mattered where the quartiles print coarsely
          # relative to their spread: integer quartiles of a variable with
          # an interquartile range near 0.7 print the SAME integer half
          # the time - the row was refused ("Quartiles do not increase")
          # for 45-85% of honest tables, and the rest were fitted to a
          # spuriously skewed metalog, clipped, and read p = 0.72 on
          # average (C:/dev/Corpus/synthetic/quartile-draw/, the "narrow"
          # population). Each replicate now draws every arm's quartiles
          # within their printed intervals (the two draws ordered, so the
          # pair is what a truth inside both intervals could have been),
          # pools them by N, and fits THAT replicate's metalog; the scale
          # draw below then resamples from the replicate's fit and inverts
          # its ratio as before. Quartiles that print the same value are
          # therefore admissible; only quartiles that print in the wrong
          # order are refused - and per ARM (CodeRabbit on PR #214), since
          # drawQuartiles() orders each drawn pair, so one arm's reversed
          # quartiles would otherwise be silently repaired whenever the
          # other arms kept the pooled pair in order.
          if (any(ROWS$Q3 < ROWS$Q1 - 1e-9 * (1 + abs(ROWS$Q1))))
          {
            Pdisp <- "Quartiles do not increase (Q3 must exceed Q1)"
          } else {
          a1 <- fit$a1; a2 <- fit$a2; a3 <- fit$a3
          # the quartiles' printed precision, per arm: ROUND_DISPERSION (the
          # dispersion measure of a median line IS its quartiles). A blank
          # cell is inferred on its own from the printed quartiles' decimals,
          # taking the variable's maximum across its arms - the validator's
          # rule, and the rule .iaSdInterval() applies to a printed SD - so a
          # direct caller who supplies the precision for some arms only keeps
          # what it supplied (CodeRabbit on PR #214; the same shape as the
          # GPT-6 audit's finding F5).
          qPrec <- if (!is.null(ROWS$ROUND_DISPERSION))
            suppressWarnings(as.numeric(ROWS$ROUND_DISPERSION))
          else rep(NA_real_, COLS)
          qBlank <- is.na(qPrec)
          if (any(qBlank))
            qPrec[qBlank] <- max(vapply(c(ROWS$Q1, ROWS$Q3), .iaDecimals, integer(1)))
          hQ <- 10^(-qPrec)
          # the note reports the PRINTED quartiles' fit; the replicates' own
          # fits are clipped individually below without a note. A pooled fit
          # with no width at all (every arm printing Q1 = Q3) has no skew to
          # judge, so it earns the second note instead of the first.
          skewNote <- if (fit$a2 > 0 && fit$clipped)
            "quartiles beyond the metalog's skew limit; fitted at the limit" else ""
          # "flat" means the pair prints the same value; a pair one printed
          # unit apart must not be caught by floating-point dust (0.1 read
          # back from two one-decimal values can be a hair under hQ)
          nFlat <- sum(ROWS$Q3 - ROWS$Q1 < hQ * (1 - 1e-9))
          if (nFlat > 0)
            skewNote <- paste(c(skewNote[nzchar(skewNote)], sprintf(
              "printed quartiles do not separate in %d arm(s); the fit uses their printed intervals",
              nFlat)), collapse = "; ")
          center     <- sum(ROWS$N * ROWS$MEAN) / N
          # TRANSLATED before the statistic (screen 2026-09-07-1459, F1): the
          # statistic is translation-invariant, and measuring from the first
          # arm's printed value makes identical medians EXACTLY zero in the
          # observed row and in every replicate, whatever their magnitude -
          # the N-weighted centre of untranslated values left floating-point
          # dust that differed between base R's sum() and Rfast's row sums,
          # and no fixed tolerance fits every shape (a thousand arms at 1e9
          # with two decimals defeated 1e-26 of the centre squared).
          dd         <- ROWS$MEAN - ROWS$MEAN[1]
          DiffSample <- sum((dd - sum(ROWS$N * dd) / N)^2)
          # a chunk's worth of quartiles drawn within their printed intervals,
          # per arm, the pair ordered, pooled by N: length-ch vectors of the
          # replicate's pooled Q1 and Q3
          drawQuartiles <- function(ch) {
            q1 <- numeric(ch); q3 <- numeric(ch)
            for (i in 1:COLS) {
              d1 <- ROWS$Q1[i] + hQ[i] * (dqrunif(ch) - 0.5)
              d3 <- ROWS$Q3[i] + hQ[i] * (dqrunif(ch) - 0.5)
              w <- ROWS$N[i] / N
              q1 <- q1 + w * pmin(d1, d3); q3 <- q3 + w * pmax(d1, d3)
            }
            list(q1 = q1, q3 = q3)
          }
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
              # ...and by the arm count, as the continuous branch has been
              # since screen 2026-09-07-1459's F2: the same four ch x arms
              # matrices are built below, and a row of many one-subject arms
              # would otherwise reach 2.5e7 doubles apiece where the
              # continuous branch deliberately stops at 1e7 (the observation
              # closing screen 2026-09-07-1758)
              ch <- min(left, max(1, floor(2.5e7 / max(1, N))),
                        max(1, floor(1e7 / COLS)))
              # THIS replicate's population: the quartiles drawn within their
              # printed intervals and refitted (a2q > 0 almost surely; floored
              # at a hundredth of a printed unit so the ratios below stay
              # finite when two draws coincide)
              qd <- drawQuartiles(ch)
              fq <- fitMetalog(a1, qd$q1, qd$q3)
              a2q <- pmax(fq$a2, 0.01 * min(hQ) / (2 * log(3)))
              a3q <- pmin(pmax(fq$a3, -.iaMetalogSkewLimit * a2q), .iaMetalogSkewLimit * a2q)
              # the scale draw: resample every arm from the replicate's fit,
              # take its printed quartiles, pool - the bootstrap scale a2* -
              # and invert the ratio: the replicate's population scale is
              # a2q^2 / a2* (a degenerate resample with a2* = 0 is floored
              # at one printed unit, so the ratio stays finite)
              bq1 <- numeric(ch); bq3 <- numeric(ch)
              for (i in 1:COLS)
              {
                S <- Rfast::rowSort(round(drawMetalog(ch, ROWS$N[i], a1, a2q, a3q),
                                          ROWS$ROUND_OBSERVATION[i]))
                w <- ROWS$N[i] / N
                # printed to the QUARTILES' precision (ROUND_DISPERSION, which
                # the validator infers from the quartiles' decimals), not the
                # median's (GPT-6 audit F4, 2026-09-07)
                bq1 <- bq1 + w * round(rowQ(S, 0.25), qPrec[i])
                bq3 <- bq3 + w * round(rowQ(S, 0.75), qPrec[i])
              }
              a2boot <- pmax((bq3 - bq1) / (2 * log(3)), 10^(-max(qPrec)) / (2 * log(3)))
              a2rep  <- a2q^2 / a2boot
              a3rep  <- pmin(pmax(a3q, -.iaMetalogSkewLimit * a2rep), .iaMetalogSkewLimit * a2rep)
              # the common location: the pooled median plus its sampling draw,
              # SD 2 a2 / sqrt(n) (the metalog density at its median is
              # 1/(4 a2)) - computed from a2rep, the scale of the population
              # the observations are actually drawn from on the next line,
              # not from the pre-bootstrap a2q (CodeRabbit on PR #214)
              a1rep  <- a1 + dqrnorm(ch, 0, 1) * (2 * a2rep / sqrt(mean(ROWS$N)))
              MCMed <- matrix(NA_real_, ch, COLS)
              for (i in 1:COLS)
              {
                X <- drawMetalog(ch, ROWS$N[i], a1rep, a2rep, a3rep)
                MCMed[,i] <- round(
                  Rfast::rowMedians(round(X, ROWS$ROUND_OBSERVATION[i])),
                  ROWS$ROUND_MEAN[i])
              }
              # each replicate translated by its own first arm, exactly as the
              # continuous branch is and for the same reason (audit 2026-09-09,
              # F6 - see the long note there). THE AUDIT DID NOT TEST THIS
              # BRANCH; the defect was identical here by reading, and is
              # measured in tests/testthat/test-audit-2026-09-09-f6.R. The
              # N-weighted centre is still a matrix product, without a ch x arms
              # weight matrix (screen 1459, F2).
              MCMed <- MCMed - MCMed[, 1]
              MedC <- drop(MCMed %*% ROWS$N) / N
              out <- c(out, rowsums((MCMed - MedC)^2))
              left <- left - ch
            }
            out
          }
          zt <- .iaZeroSnapTol(.iaMeanStep(ROWS$ROUND_MEAN))         # ONE binding: the note and the
                                       # engine cannot drift apart; the
                                       # printed step only (audit 2026-09-10 F1)
          simRow <- list(simulate = simulate, obs = DiffSample, kind = "median",
                         note = { same <- isTRUE(DiffSample <= zt)
                                  nt <- c(skewNote,
                                          .iaFinePrecisionNote(ROWS$MEAN, ROWS$ROUND_MEAN, same),
                                          .iaCoarsePrecisionNote(ROWS$MEAN, ROWS$ROUND_MEAN))
                                  paste(nt[nzchar(nt)], collapse = "; ") },
                         zeroTol = zt, key = .iaNullKey("median", ROWS))
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
          # Squared difference of column means, TRANSLATED by the first arm's
          # printed mean first (screen 2026-09-07-1459, F1): the statistic is
          # translation-invariant, and measuring from a printed value makes
          # identical means exactly zero in the observed row and in every
          # replicate at any magnitude, where the untranslated N-weighted
          # centre left floating-point dust that differed between base R's
          # sum() and Rfast's row sums (a thousand arms printing 1e9 + 0.25
          # reported the stage floor instead of p = 0.5).
          dd         <- ROWS$MEAN - ROWS$MEAN[1]
          DiffSample <- sum((dd - sum(ROWS$N * dd) / N)^2)
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
          # ...and only where the mean's own grid, h/N, is representable at
          # this magnitude: the direct draw snaps to that grid to reproduce
          # the ties a rounded sample mean makes, and a snap finer than the
          # arithmetic silently makes none, which is the alarming direction
          # (GPT-6 audit F7; the row-level refusal above catches the printed
          # grid, this catches the finer grid the draw itself uses)
          drawableGrid <- hObs / ROWS$N >=
            .iaResolutionFactor * .Machine$double.eps * max(abs(ROWS$MEAN))
          direct <- ROWS$N >= .iaDirectDrawN & Meansd >= .iaDirectDrawSdOverGrid * hObs &
                    drawableGrid
          # the chunk size is set by the arms still simulated in full;
          # a row of direct-draw arms costs one draw per arm per replicate
          Nfull <- sum(ROWS$N[!direct])
          simulate <- function(n) {
            out <- numeric(0); left <- n
            while (left > 0) {
              # the chunk is bounded by the fully simulated subjects AND by the
              # arm count: a row of direct-draw arms has Nfull = 0, and its
              # four ch x arms matrices were 100,000 x arms at the top stage -
              # 2.3 GB at a thousand arms, 4.5 GB at two thousand, unbounded in
              # the app (screen 2026-09-07-1459, F2). At 1e7 doubles each they
              # stay near 80 MB, and with the translation, deviation and square
              # copies alive at once the row's peak stays under half a
              # gigabyte (measured 0.68 GB at 2.5e7); the chunk only shrinks
              # below the stage size above 100 arms at 100,000 replicates, so
              # no known answer moves.
              ch <- min(left, max(1, floor(1e8 / max(1, Nfull))), max(1, floor(1e7 / COLS)))
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
              # EACH REPLICATE IS TRANSLATED BY ITS OWN FIRST ARM (independent
              # audit 2026-09-09, F6), which is what the OBSERVED row has always
              # done: dd <- ROWS$MEAN - ROWS$MEAN[1] a hundred lines above makes
              # arm 1 exactly zero, so printed means that agree give a
              # structurally exact zero. Subtracting the OBSERVED constant from
              # a REPLICATE does not do the same job: when every arm of a
              # replicate draws the same value the translated values are equal
              # but their N-weighted centre is not bitwise equal to them, and
              # the residual dust survives. Screen 1459's own comment says the
              # translation exists so that identical means are exactly zero "in
              # the observed row and in every replicate" - one constant only
              # ever delivered the first half.
              #
              # The statistic is translation-invariant, so this is the same
              # quantity; only the floating point differs. MEASURED on the
              # audit's construction (two arms of 30, MEAN 2.3, SD 3.007,
              # ROUND_OBSERVATION 0, ROUND_DISPERSION 3), 400,000 replicates,
              # comparing integer sample sums so the reference never touches a
              # floating statistic:
              #
              #   ROUND_MEAN  ties   lost before   lost after   reference mid-p
              #      6        6823    0 (0.00%)     0 (0.00%)      0.008529
              #     14        6823  1243 (18.22%)   0 (0.00%)      0.008529
              #
              # Before, the row read 0.006975 at fourteen decimals against
              # 0.008529 at six - the same equality event, a different answer,
              # and the difference was arithmetic rather than data. Nothing
              # moves at ordinary printed precision, where the tolerance already
              # sat far above the dust: the loss needs 1e-12 * step^2 to fall
              # below it, which takes about eleven decimals.
              #
              # The N-weighted centre is still a matrix product, without a
              # ch x arms weight matrix (screen 1459, F2).
              MCMean <- MCMean - MCMean[, 1]
              MS <- drop(MCMean %*% ROWS$N) / N
              out <- c(out, rowsums((MCMean - MS)^2))
              left <- left - ch
            }
            out
          }
          zt <- .iaZeroSnapTol(.iaMeanStep(ROWS$ROUND_MEAN))         # ONE binding, see the median branch
          simRow <- list(simulate = simulate, obs = DiffSample, kind = "continuous",
                         note = { same <- isTRUE(DiffSample <= zt)
                                  nt <- c(.iaFinePrecisionNote(ROWS$MEAN, ROWS$ROUND_MEAN, same),
                                          .iaCoarsePrecisionNote(ROWS$MEAN, ROWS$ROUND_MEAN))
                                  paste(nt[nzchar(nt)], collapse = "; ") },
                         zeroTol = zt, key = .iaNullKey("continuous", ROWS))
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
          # the categorical null depends on the MARGINS alone (r2dtable), so
          # two rows with the same margins share one law whatever their cells
          simRow <- list(simulate = simulate, obs = statObs, kind = "category", zeroTol = 0,
                         key = paste("category", paste(rowSums(tab), collapse = ","),
                                     paste(colSums(tab), collapse = ",")))
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
    # EVERY ROW IS DRAWN FIRST, in the same order as before (the RNG stream
    # is consumed identically, so every pinned value stands), because the
    # combination's mapping below may need the draws of several rows at
    # once (full independent audit 2026-09-10, F1).
    simsAll <- vector("list", length(rows))
    for (j in usable) simsAll[[j]] <- rows[[j]]$sim$simulate(s)
    # ROWS THAT SHARE A NULL LAW SHARE ONE SCORE MAPPING. Each row used to
    # map its statistics to a mid-p through the ranks of its OWN draws -
    # exact within the row, since a tied replicate gets the observed row's
    # own average rank - but two rows with the same law carried two
    # different ESTIMATES of the same mapping. A replicate whose one extreme
    # outcome sat in a different row from the observed one is a genuine
    # trial tie, yet its Stouffer sum differed from the observed sum by
    # that estimation noise, and the exact comparison below split the tie
    # class by the noise's sign: nine binary rows of (1,99)/(1,99) with one
    # (0,100)/(2,98) - exact trial mid-p 0.011146 - read 0.003285 with the
    # extreme row named V03 and 0.0194 with it named V01. The answer
    # depended on which row carried the name. So the mapping of rows that
    # share a law is now one pooled empirical distribution over ALL their
    # draws; each row keeps its own independent replicates, and only the
    # function statistic -> mid-p is shared. A row with a law of its own
    # is mapped through its own draws, exactly as before. The row's own
    # displayed p, interval and replicate count are unchanged; this is the
    # combination's mapping only.
    keyOf <- vapply(usable, function(j) {
      k <- rows[[j]]$sim$key
      if (is.null(k) || !nzchar(k)) paste0("row", j) else k
    }, character(1))
    poolRank <- list(); poolOf <- list()
    for (k in unique(keyOf[duplicated(keyOf)])) {
      grp <- usable[keyOf == k]
      pool <- unlist(simsAll[grp], use.names = FALSE)
      # the zero snap, exactly as each row applies it to its own draws
      # below; rows sharing a law share a printed step, so one tolerance
      pool[pool <= rows[[grp[1]]]$sim$zeroTol] <- 0
      poolOf[[k]] <- pool
      poolRank[[k]] <- .iaTieRank(pool)
    }
    for (j in usable) {
      sims <- simsAll[[j]]
      obs  <- rows[[j]]$sim$obs
      # A statistic that is zero up to floating-point dust IS zero. Since
      # screen 2026-09-07-1459 the branches translate their means before
      # the statistic: the OBSERVED row by the first arm's printed value,
      # and - since the 2026-09-09 audit's F6 - each REPLICATE by its own
      # first arm, which is what makes identical means exactly zero in a
      # replicate too, at any magnitude and arm count. Saying "the first
      # arm's printed value" of both was right for the observed row and
      # wrong for replicates (screen 2026-09-09-1614, F2). This snap is a
      # guard rather than the mechanism. (History: identical means left about 1e-28 of dust
      # in the N-weighted centre, differing between base R's sum() and
      # Rfast's row sums, so the floor's ties were split; a tolerance of
      # 1e-20 of the centre squared outgrew the printed grid at means near
      # 1e10 - screen 1441, I1 - and 1e-26 was defeated by a thousand arms
      # at 1e9 with two decimals - screen 1459, F1. No single factor fits
      # every admissible shape; translation removes the dust instead.)
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
      k <- keyOf[match(j, usable)]
      if (!is.null(poolOf[[k]])) {
        # this row's draws sit at a known offset in its group's pool
        grp <- usable[keyOf == k]
        off <- sum(lengths(simsAll[grp[seq_len(match(j, grp) - 1L)]]))
        mP <- length(poolOf[[k]])
        pRep <- .floorP((poolRank[[k]][off + seq_len(s)] - 0.5) / mP, mP)
        kp <- .iaTieCounts(poolOf[[k]], obs)
        zObs <- zObs + stats::qnorm(.floorP((kp[["kLess"]] + kp[["kEq"]] / 2) / mP, mP),
                                    lower.tail = FALSE)
      } else {
        pRep <- .floorP((.iaTieRank(sims) - 0.5) / s, s)
        zObs <- zObs + stats::qnorm(.floorP((kLess + kEq / 2) / s, s), lower.tail = FALSE)
      }
      sumZ <- sumZ + stats::qnorm(pRep, lower.tail = FALSE)
    }
    rowMid <- vapply(usable, function(j)
      (rowStat[[j]]$kLess + rowStat[[j]]$kEq / 2) / s, numeric(1))
    if (length(usable) > 1) {
      # A TRIAL TIE BY THE SAME BOUNDED CRITERION THE ROWS USE (full
      # independent audit 2026-09-10, F1). Exact equality was right while
      # a tied replicate accumulated the same row values in the same
      # order; with a shared mapping the tied replicate accumulates the
      # same VALUES in a different order, and floating addition is not
      # associative. .iaTieTol (one part in 1e10) absorbs that and nothing
      # else: distinct trial outcomes differ by a whole row's z.
      kk <- .iaTieCounts(-sumZ, -zObs)         # "less" of the negatives is "greater"
      kG <- kk[["kLess"]]; kE <- kk[["kEq"]]
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
  # A TRIAL WITH NOTHING TO SIMULATE (full independent audit 2026-09-10,
  # F2): every row left out by the validator. rows is empty, so x is
  # NULL here; it becomes an empty frame of the right shape, the excluded
  # lines are appended below, and the Summary says "No values" with the
  # coverage count - the trial is reported, not dropped.
  if (is.null(x))
    x <- data.frame(ROW = character(0), P = character(0), CI95 = character(0),
                    M = character(0), NOTE = character(0), KIND = character(0),
                    .PNUM = numeric(0), .KLE = numeric(0), stringsAsFactors = FALSE)
  x <- cbind(TRIAL = if (nrow(x)) c(TRIAL, rep(NA, nrow(x) - 1L)) else character(0),
             x, stringsAsFactors = FALSE)

  # ROWS THE VALIDATOR LEFT OUT ARE COUNTED HERE (independent audit
  # 2026-09-10, F3). A category block whose every cell the parser left
  # blank - a percentage block it could not reconstruct - reaches
  # validateData() as label-only lines and is excluded from the analysed
  # frame; until now that made it invisible to this function, so the
  # Summary's coverage line, which the method document promises counts
  # EVERY refusal, said nothing, and the row was absent from the
  # results. Each such variable is one line: no p, no interval, the
  # reason in its note, KIND "variable" so the Summary's "k of n" counts
  # it. It never enters the combination (.PNUM is NA).
  if (!is.null(excluded) && nrow(excluded))
  {
    ex <- excluded[!is.na(excluded$TRIAL) & excluded$TRIAL == TRIAL, , drop = FALSE]
    ex <- ex[!duplicated(as.character(ex$ROW)), , drop = FALSE]
    # ...and never a label that is ALSO an analysed variable of this trial:
    # that line already has its own row (screen 2026-09-10-1143, observation)
    ex <- ex[!(as.character(ex$ROW) %in% as.character(x$ROW)), , drop = FALSE]
    if (nrow(ex))
      x <- rbind(x, data.frame(
        TRIAL = NA, ROW = as.character(ex$ROW), P = "Not analysed", CI95 = "",
        M = NA_character_,
        NOTE = ifelse(ex$REASON == "label only",
          paste("no values in any cell of this row - a label without N, mean,",
                "dispersion or counts. If a document parser left it blank, the",
                "document's flags say why (a percentage block it could not",
                "reconstruct, for instance); the counts can be typed in"),
          "a categorical line with no matching line in another arm"),
        KIND = "variable", .PNUM = NA_real_, .KLE = NA_real_,
        stringsAsFactors = FALSE))
    # the trial's name prints on its first line, whichever line that is
    if (nrow(x) && is.na(x$TRIAL[1])) x$TRIAL[1] <- TRIAL
  }

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
  # WHAT THE TRIAL P WAS COMPUTED FROM (security screen 2026-09-07-2101,
  # finding F5). A row the engine refuses - a precision the printed values
  # contradict, quartiles the wrong way round, an arm under two patients -
  # is dropped from the combination, and until now the Summary reported a
  # trial p as though the table were complete. Refusing can be the right
  # answer and still leave the reader misinformed about what the number
  # covers, so the count travels with it whenever anything was left out.
  analysed <- sum(!is.na(x$.PNUM))
  offered  <- sum(x$KIND == "variable", na.rm = TRUE)
  summaryNote <- if (offered > analysed)
    sprintf("%d of %d rows analysed; the rest were refused - see their P cells",
            analysed, offered) else ""
  lastline <- data.frame(
    TRIAL = c(NA, NA),
    ROW = c("Summary", NA),
    P = c(as.character(P), NA),
    CI95 = c(ciStr, NA),
    M = c(NA, NA),
    NOTE = c(summaryNote, NA),
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
