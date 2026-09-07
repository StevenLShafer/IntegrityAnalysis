# What changed from the original Carlisle–Shafer method

The method IntegrityAnalysis runs today is described, without history,
in [statistics.md](statistics.md). This document is the record of how it
got there: every change to the statistical engine since the original
Carlisle–Shafer Monte Carlo, dated, with what was wrong, what changed,
and what was measured. It exists so that the current description can
stay clean and so that nobody repeats an experiment that was already
run. Corpus figures trace to [the validation ledger](validation-ledger.md).

Provenance: assembled 2026-09-06 by Claude Code (model Claude Fable 5.1)
from the dated sections that previously lived in `statistics.md`, at
Steve Shafer's request that the user-facing documents describe the
present method and keep the history apart.

## The original method

John Carlisle's 2012 analysis of Fujii's trials compared baseline arm
means with normal theory and combined the variables with Stouffer's
closed-form sum of z-scores. Under normal theory two random samples
never agree exactly, so a row whose arms reported identical rounded
means had p = 0, and rounded tables looked statistically impossible.
Steve Shafer replaced the normal theory with a Monte Carlo simulation
that rounds its replicates as the paper rounded its own, so that
identical rounded means get the probability they actually have. That
simulation, per variable, with the closed-form Stouffer combination
across variables and across trials, is the Carlisle–Shafer method of the
2015 and 2017 papers, and it is what the app shipped with in August
2026 (r = 0.993 against Carlisle's stored 2017 values over 5,080
trials; 99.0% alarm concordance).

## 2026-08-16 — the mid-p convention

Ties (simulated tables exactly as homogeneous as the printed one) are
counted by halves. Counting every tie ran systematically high on
discretised statistics (median absolute difference from Carlisle's
values 0.076); the mid-p reproduces his values (r 0.995 in the pilot,
0.991 over the full corpus). A mid-p is centred on the right value on
average but is not exactly uniform for every fixed margin of a discrete
table, where an inclusive-tail p would be conservative instead; the
choice is deliberate and documented in the current method.

## 2026-08-17 — one-sided toward homogeneity; staged replicates

The p became one-sided toward excessive homogeneity (small p = arms more
alike than random sampling explains); excessive heterogeneity is not
reported. Replicates became staged: 1,000 per row, escalating to 10,000
and 100,000 while a p was below 0.01 (below 0.1 for the first step
since 2026-09-05). Zero-hit rows were floored at 1/(replicates + 1) and
"<0.0001" was made a confidence statement licensed by the 97.5% upper
Clopper–Pearson bound on the simulated count.

## 2026-09-04 — the exact combination

**What was wrong.** The trial p was Stouffer's closed-form combination:
each row's simulated p converted to a normal score, the scores summed,
the sum read off the normal distribution. That assumes each row's p is
uniformly distributed when the trial is honest. It is not, whenever the
reported means are rounded coarsely relative to their standard error —
integer means with hundreds of patients per arm. Such a row has only a
handful of possible values of its statistic, so its simulated p is
discrete (a row whose two arms both report "55" has a mid-p near 0.27
however honest it is), and the sum of a few such p's was being read off
a smooth table it does not follow. Measured on synthetic honest trials
(`corpus/syntheticTiesCheck.R`): at integer means and 1,000 per arm,
1.4% of honest trials fell below p = 0.05 instead of 5%, the lowest
decile of trial p's was 43% under-filled, and a fabricated table with
identical integer means on every row could not reach p = 0.01 however
many rows agreed. The screen failed in the safe direction but was
miscalibrated and blind to a fabrication it should have seen. The error
was in the Monte Carlo's combination step, which Steve Shafer wrote.
Carlisle's published values were computed by his own closed-form
combination, not by this code, so this correction changed none of them;
the miscalibration described here is a property of the closed form
under coarse rounding, which his values therefore share.

**What changed.** Nothing about the rows. The statistic is still
Stouffer's sum of row z-scores; its null distribution is taken from the
same simulations that produce the row p's (each replicate of each row
ranked within its row, given the mid-p its rank implies, floored and
z-scored as the observed row is, summed across rows replicate by
replicate). The observed sum is compared with the simulated sums, ties
half. On the same synthetic trials 4.8 to 5.8% of honest trials fell
below 0.05 in every integer cell, and the fabricated table was found.

**What it costs.** The trial p can no longer be resolved below
1/(replicates + 1); a trial beyond every simulated sum reports
"<0.0001" with an interval, where the closed form printed numbers like
3 × 10⁻⁹ that the simulation never supported. Replicates are shared by
the whole trial, so an alarming trial escalates every row.

**Revalidated.** The 5,080 trials of Carlisle 2017 rerun against his
stored values (the comparator, computed with his closed-form
combination): the August engine, with the same closed form, agreed at
r 0.993 and 99.0% alarm concordance; the corrected engine at r 0.992
and 98.3%. The small drop is the difference between the two
combinations, not a loss of accuracy against the truth, which his
values do not represent. Against the previous
engine the typical trial moved by about one hundredth (median |change|
0.013), trials below 0.05 rose from 348 to 392, and the largest shifts
were in the largest trials, where rounded rows converge and carry the
least information each.

**Tested and rejected:** ignoring ties (10 to 43% false alarms at
integer rounding); placing the observed statistic at the chi-square
median of its tie group (reproduces the old numbers exactly: any rule
that assigns one number to each reported pattern leaves the
distribution as lumpy as it found it); a log-likelihood-ratio
combination against a stated fabrication model (calibrated, but sees
only the alternative it was built for).

## 2026-09-05 — the attainable floor note

A row whose arms print exactly the same value, and which no honest
replicate beats, is marked "attainable floor". Since 2026-09-06 the
note requires both conditions: a row whose arms differ, however
slightly, never carries it even when no replicate happened to beat it
(an outside audit found 77 vs 77.000001 labelled).

## 2026-09-05 — the 0.1 escalation and the seed

Twelve unseeded runs of the guide's worked example (77 vs 78, SD 30,
n = 6) spread 0.034 to 0.057 at 1,000 replicates, so a trial or row
below 0.1 now advances to 10,000 (below 0.01 to 100,000). A seed can be
set (`?seed=` in the app, `seed` in the API) for exact reproduction.

## 2026-09-05 — the pooled SD

The code weighted the arms' variances by N<sub>i</sub> rather than
N<sub>i</sub> − 1, corrected the square root with N − 1 degrees of
freedom rather than N − k (one too many per arm beyond the first), and
only below N = 30, leaving a 1% step. The shortfall was 3.8% for two
arms of two and under 0.1% for two arms of twelve; a low SD is
conservative for this test. Now: pooling by degrees of freedom, c₄ with
N − k, at every N. Honest null (two arms of 3 to 50, 2,000 trials per
cell, fine and coarse printing): both engines nominal at 0.05 and 0.01,
each cell moved by ≤ 0.1 point. Carlisle corpus: median |Δp| 0.007;
r 0.9922 → 0.9925. Worked example 0.0481 → 0.0475.

## 2026-09-05 — the direct draw for large arms

A continuous row's replicate drew every one of the N observations per
arm; the largest Carlisle trials took an hour each once the exact
combination escalated every row together. When an arm has at least 100
patients and the SD is at least three observation-grid steps, the arm
mean is drawn directly with variance (SD² + h²/12)/N (Sheppard's
correction) and then rounded as printed. Tested against the full
simulation on the two-arm statistic, 100,000 replicates per cell, N 10
to 300, printed to 0 or 1 decimals, grids at 1/13 and 1/45 of the SD:
largest difference in the cumulative distributions 0.007, tie masses
agreeing to the third decimal. With the grid comparable to the SD the
direct draw is wrong at small N (0.047 at N = 10 for SD 0.7 against
integer observations), hence the two thresholds. Thirty times faster on
a six-row table at 5,000 per arm.

**Corrected 2026-09-06.** N observations on a grid of width h have a
mean on a grid of width h/N whatever the printed precision. The
continuous draw ignored that grid, so with integer observations and a
six-decimal printed mean (N = 100, SD 3, identical means) it reported
p < 0.0001 where the full simulation gives 0.0045. The drawn mean is
now snapped to the h/N grid before the printed rounding; where the
printed precision is coarser than h/N (every cell of the test above)
the snap changes nothing. Found by an outside audit.

## 2026-09-06 — the SD is drawn per replicate

A plug-in SD, however well unbiased, understates the null spread of the
arm means (the z test where a t test belongs). Each replicate draws its
own population variance σ² = s² · df / χ²(df) from the scaled inverse
chi-square implied by the pooled variance. Honest null: the 5% and 1%
rates were nominal before and after; the body of the distribution was
not — at three per arm the mean row p was 0.52 and the
Kolmogorov–Smirnov distance from uniform 0.07, now 0.50 and 0.016; at
ten per arm and above the two are indistinguishable. Carlisle corpus
(5,041 usable trials, 10,000 ceiling): r 0.9925 → 0.9929, within 0.05
88.5% → 89.1%, alarm concordance 98.5% either way; median |Δp| 0.009,
confined to trials of 30 or fewer per arm; one trial of 20 per arm
moved by 0.34 (0.28 → 0.62; Carlisle 0.25). Worked example 0.0475 →
0.0442.

## 2026-09-06 — the trial interval's lower end

The trial's 95% Monte Carlo interval took both ends from the
at-or-beyond count while the mid-p counts ties by halves, so at the
attainable floor — where every "beyond" is a tie — the trial printed
below its own interval ("0.00042, interval 0.00067 to 0.001"). The lower
end now comes from the strictly-beyond count, as a row's does. Found by
an outside review and reproduced six times in six.

## 2026-09-06 — precision inference

Decimal places were counted on `as.character()`, which prints 0.0001
as "1e-04": 5 decimals for 0.0001, 5 for 0.000015, 5 for 1e-10. A
helper reads a plain rendering (capped at 20). An explicitly supplied
per-arm precision is no longer overwritten by the variable's maximum;
only blank cells take it. An observation precision left blank follows
the mean's after the decimal bump, not the zero it was copied from
before it.

## 2026-09-06 — the SD's printed rounding is drawn

**What was wrong.** The printed SD was taken as exact. A statistical
audit the same day (report in Steve Shafer's working files) measured how
much the row p depends on where in its printed interval the true SD
lies: seeded runs, two arms of 30 with means tied at one decimal, the
true SD varied across the interval a printed "1" covers — p 0.128 at
0.5, 0.100 at 0.75, 0.074 at 1, 0.060 at 1.25, 0.050 at 1.49: a factor
of 2.5. A printed "3" (N 100, means tied): 0.058 to 0.041. With two
significant figures ("1.0", "13") the spread is a few percent. The
mean's rounding is handled by construction (the simulation rounds its
own means the same way and the tie mass is the mechanism); the SD's was
not, because the SD enters the null as a parameter, so its rounding is
unmodelled parameter uncertainty — the same class the sigma draw
models. The audit's first framing read that spread as the size of the
correction; it is not (see "Measured").

**What changed.** Each replicate first draws every arm's sample SD
uniformly within its printed interval, half a printed unit either side
(`ROUND_DISPERSION`; `validateData()` now infers a blank value from the
SD's printed decimals, raised to the variable's maximum across its arms
as the mean's precision is; a direct caller of `P_Calc` without the
column gets the same inference), never below zero, pools those by
degrees of freedom, and only then applies the chi-square draw. A printed
SD of exactly zero is kept at zero: it declares that the variable did
not vary (PR #182), and drawing a spread there would manufacture one.
Known answers re-pinned: the worked example 0.0442 → 0.0462, three
identical arms 0.00025 → 0.00015 — mostly the RNG stream (one extra
uniform per arm per replicate), since a printed "30" or "9.2" is a
narrow interval.

**Measured** (data `C:/dev/Corpus/synthetic/sd-round/`). *The integrated
effect, computed directly* (2,000,000 replicates, no staging): the
mid-p at a tie moves from 0.0760 to 0.0776 for a printed "1" at two arms
of 30 (+2%), 0.0384 → 0.0387 for "2", 0.0256 → 0.0257 for "3", and not
at all at two significant figures — far below the naive E[1/σ] guide
(+10% for "1"), because pooling the drawn SDs by their squares raises the
pooled variance by the rounding's h²/12 and nearly cancels the convexity
gain from smaller draws. *Honest null* with coarsely printed SDs (X ~
N(5, 1.3), SD printed to 0 or 1 decimals, two arms of 5 to 100, 2,000
trials per cell, identical data and seeds): rejection rates, mean p and
Kolmogorov–Smirnov distance identical to the displayed precision in
every cell; paired |Δp| median 0.007–0.010, the Monte Carlo noise of
two draws — as it must be, since an honest table's rounding error is
symmetric. *Carlisle corpus* (5,041 usable, 10,000 ceiling, against the
sigma-draw run): r 0.9929 → 0.9932, within 0.05 89.1% → 89.2%, alarm
concordance 98.5% either way, alarms 420 → 418 (5 crossing down, 7 up),
median |Δp| 0.0077 with no direction in any arm-size band. The change
is right in principle and nearly invisible in practice; it is kept
because a printed SD *is* an interval and the engine should say so.

## 2026-09-07 — the median/IQR branch: the parameter draw, and the skew limit clipped

**What was wrong.** Two things, found by the 2026-09-06 audit (finding
F2) and measured on honest two-arm trials whose arms were summarised as
the median and type-7 quartiles of observations recorded to one decimal
(1,000 trials per cell, `C:/dev/Corpus/tools/medianNull.R`). First, a
fit beyond the three-term metalog's feasibility bound (|a₃|/a₂ >
1.667) refused the row as "too skewed", and sample quartiles of ten
observations are noisy enough that honest rows met that refusal often:
9% of normal, 16% of lognormal, 11% of uniform and 12% of heavy-tailed
(t₃) rows at ten per arm; 2 to 6% at thirty. Second, the pooled
quartiles were taken as exact — the plug-in σ of the mean/SD branch
before its sigma draw — and the body of the row p's distribution
showed it: at ten per arm the mean p was 0.54 to 0.56 and the
Kolmogorov–Smirnov distance from uniform 0.07 to 0.12; the 5% and 1%
rates themselves were roughly nominal.

| population | N/arm | < 0.05 | < 0.01 | mean p | KS | refused |
|---|---|---|---|---|---|---|
| normal | 10 | 0.042 | 0.010 | 0.545 | 0.074 | 9.0% |
| normal | 30 | 0.048 | 0.014 | 0.518 | 0.040 | 1.5% |
| normal | 100 | 0.051 | 0.006 | 0.520 | 0.052 | 0 |
| lognormal | 10 | 0.045 | 0.012 | 0.562 | 0.115 | 16.1% |
| lognormal | 30 | 0.040 | 0.011 | 0.521 | 0.041 | 5.9% |
| lognormal | 100 | 0.043 | 0.006 | 0.513 | 0.034 | 0.3% |
| uniform | 10 | 0.044 | 0.004 | 0.559 | 0.101 | 10.8% |
| uniform | 30 | 0.030 | 0.000 | 0.553 | 0.093 | 1.7% |
| uniform | 100 | 0.049 | 0.000 | 0.527 | 0.054 | 0 |
| t₃ | 10 | 0.047 | 0.015 | 0.538 | 0.073 | 11.5% |
| t₃ | 30 | 0.052 | 0.007 | 0.506 | 0.028 | 1.6% |
| t₃ | 100 | 0.045 | 0.000 | 0.502 | 0.024 | 0 |

**What changed.** A fit beyond the bound is clipped to it (|a₃| ≤
1.66 a₂): the closest feasible metalog is used and the results table's
Note column says "quartiles beyond the metalog's skew limit; fitted at
the limit". Only quartiles that do not increase are refused. And each
replicate draws its own scale, by the median/IQR analogue of the sigma
draw. The obvious construction was tried first and rejected: a
parametric bootstrap (every arm resampled from the fit, summarised,
pooled and refitted; the replicate drawn from the refit) made the null
*wider* — mean p 0.60, KS 0.16 to 0.19 at ten per arm — because it draws
the sample's scale given the population, when the null needs the
population's scale given the sample, and for a scale parameter the two
are reciprocals (σ² = s²·df/χ²(df) is the reciprocal of the bootstrap's
s²·χ²(df)/df). So every arm is resampled from the fitted metalog,
recorded to the observation precision, its type-7 quartiles printed to
the median's precision and pooled by N, giving a bootstrap scale a₂\*;
the replicate's population has scale a₂²/a₂\*, the observed skew term
re-clipped to that scale, and the pooled median plus the location draw
the branch always made. Measured side by side on identical honest
trials (600 per cell, `C:/dev/Corpus/synthetic/median-draw/variants.R`),
mean p and KS at ten per arm: point fit 0.54–0.57 / 0.07–0.13;
bootstrap 0.58–0.62 / 0.15–0.19; reciprocal 0.48–0.52 / 0.03–0.06, with
the 5% and 1% rates nominal. Known answer re-pinned: the median/IQR
pair 0.0464 → 0.04545.

**Measured after** (the same 12,000 trials, identical data and seeds;
data `C:/dev/Corpus/synthetic/median-draw/`). No honest row is refused;
the "clipped" column is the share whose fit was clipped at the skew
limit, the rows that used to be refused.

| population | N/arm | < 0.05 | < 0.01 | mean p | KS | clipped |
|---|---|---|---|---|---|---|
| normal | 10 | 0.047 | 0.009 | 0.500 | 0.040 | 9.0% |
| normal | 30 | 0.047 | 0.015 | 0.502 | 0.021 | 1.5% |
| normal | 100 | 0.050 | 0.001 | 0.515 | 0.042 | 0 |
| lognormal | 10 | 0.048 | 0.010 | 0.504 | 0.033 | 16.4% |
| lognormal | 30 | 0.045 | 0.013 | 0.499 | 0.024 | 6.2% |
| lognormal | 100 | 0.046 | 0.003 | 0.507 | 0.032 | 0.3% |
| uniform | 10 | 0.049 | 0.007 | 0.511 | 0.033 | 10.9% |
| uniform | 30 | 0.038 | 0.000 | 0.537 | 0.066 | 1.9% |
| uniform | 100 | 0.049 | 0.000 | 0.520 | 0.049 | 0 |
| t₃ | 10 | 0.054 | 0.011 | 0.484 | 0.044 | 11.7% |
| t₃ | 30 | 0.056 | 0.008 | 0.489 | 0.027 | 1.6% |
| t₃ | 100 | 0.051 | 0.000 | 0.497 | 0.022 | 0 |

At ten per arm the mean p is 0.48 to 0.51 and the distance from uniform
0.03 to 0.04 (was 0.54 to 0.56 and 0.07 to 0.12); the standard error of
a 5% rate here is 0.007. The one cell still off (uniform, thirty per
arm, mean p 0.54) is the bounded population's convergence at one-decimal
printing, the attainable-floor effect, and it is unchanged by the
draw. The Carlisle corpus has no median rows, so there is no corpus
figure for this change.

## 2026-09-07 — the rounding convention: banker's rounding kept

The 2026-09-06 audit (finding F3) noticed that the simulation rounds
with R's `round()`, half to even, while the software behind most printed
tables rounds a half away from zero, and measured the difference (pure
R, 400,000 replicates per cell, the same seed both ways): where a mean
of N grid observations can land exactly on a printed half, banker's
rounding inflates the tie mass and the mid-p at a tie — by 8.8% for
N = 20 integer observations printed to one decimal (0.00692 against
0.00631), 3.0% for the worked example (6 per arm, integers), 2.4% at
N = 40, 1.4% at N = 100 with one-decimal observations printed to two,
1.0% at N = 10 printed to integers, and 0% where no exact half is
reachable. The direction is conservative. Steve Shafer decided
(2026-09-07) to keep banker's rounding: the convention a paper's own
software used cannot be read from its table, the effect is bounded and
one-directional, and a change would move every seeded known answer for
no gain in validity. The convention is now stated in statistics.md.
Data: `C:/dev/Corpus/reviews/audit-2026-09-06/roundconv.R`.

## 2026-09-07 — ties decided by a bounded numerical criterion

**What was wrong.** A tie — a replicate exactly as homogeneous as the
printed table — was decided with exact equality of floating-point
numbers, and the replicate ranks that feed the exact combination by
ordinary ranking. The independent GPT-6 audit of the same day
(`docs/audits/`, finding F1) enumerated a categorical row with margins
(2, 2, 6) × (3, 7) whose three minimum tables have the same Pearson
statistic, 80/63, computed as 1.2698412698412698 for one and
1.2698412698412700 for the other two: the strict comparison split the
tie group, the row's mid-p read 0.10 where the exact value is 0.35, and
five such rows combined to 0.00018 where the exact trial p is 0.084.
Reproduced here. The same hazard reached the continuous branch when
three or more arms permute a pattern (a + b + c is not c + b + a in
floating point), and the attainable-floor test: identical printed means
with unequal arm sizes give an observed statistic of about 10⁻²⁸ rather
than zero, and the replicates' statistics carry different dust (Rfast's
row sums against base R's), so such rows never received the note and
their floor ties were split by dust.

**What changed.** Two statistics are one value when they agree to within
one part in 10¹⁰ of the larger; a statistic within 10⁻²⁰ of the centre
squared of zero is zero. The rule is applied to the observed row's
strictly-below and tied counts and to the replicate ranks alike. The
tolerance is bounded and stated: floating-point error in these sums is
below 10⁻¹³ relative, so equal values are never split; distinct
attainable values differ by far more (a rounded-mean sum of squares by
at least a grid step squared; a fixed-margin Pearson statistic by at
least 1/(n·r·c)), so distinct values are not merged. Known answers were
unchanged: none of the pinned rows had a dust-split tie. The audit's
row now reads 0.35 and its five-row trial 0.084, to Monte Carlo
precision.

## 2026-09-07 — the quartiles' printed precision

**What was wrong.** The validator's order check for a median row
compared the printed numbers without regard to their precision, so
quartiles printed as integers beside a two-decimal median — "5, 4.99, 6"
for the observations 4.50, 4.80, 4.99, 5.60, 6.00, whose type-7
quartiles 4.80 and 5.60 print as 5 and 6 — were refused as incongruent:
391 of 400 honest thirty-per-arm tables printed that way (the GPT-6
audit's finding F4, `docs/audits/`; reproduced). And the median branch
printed its bootstrap quartiles to the median's precision whatever the
quartiles' own.

**What changed.** A median line's `ROUND_DISPERSION` is the quartiles'
precision, inferred from their decimals when blank, exactly as an SD's
is. The order check allows each printed value half a printed unit either
side and refuses only when no ordered quantiles can exist inside those
intervals. The bootstrap prints its quartiles to that precision. Not yet
done, and a decision for Steve Shafer: integrating the quartiles'
printed rounding into the fit itself (drawing each quartile within its
interval per replicate, as the SD is drawn since 2026-09-06) — a table
whose quartiles print coarsely relative to their interquartile range is
otherwise fitted to a spuriously skewed metalog and clipped.

## Ideas noted for later

- The interval computed from the batch the staging stopped at is not a
  fixed-sample 95% interval: coverage is 93.4–93.7% for a true p near an
  escalation threshold and 95% elsewhere (exact enumeration, 2026-09-06).
  A confirmatory batch after the stopping decision, or a sequentially
  valid interval, would restore nominal coverage at the cost of more
  replicates on borderline trials.
- The common location of a replicate is drawn with standard deviation
  σ/√(mean N) — a choice inherited from the original simulation. The
  pooled mean's own sampling standard deviation is σ/√(ΣN), narrower by
  √k. The draw cancels from unrounded contrasts and matters only through
  where the location sits relative to the rounding grid. **Measured
  2026-09-06:** the two scales were run side by side on the honest null
  (two arms of 3 to 50, 2,000 trials per cell, identical data and seeds)
  and on the Carlisle corpus (5,041 usable trials, 10,000 ceiling). The
  null's rejection rates, mean p and distance from uniform are identical
  to the displayed precision in every cell, and the paired row p's
  differ by a median of 0.0015 at coarse printing (Monte Carlo noise)
  and under 0.0005 at fine printing. On the corpus: r against Carlisle
  0.9931 vs 0.9932, within 0.05 89.3% vs 89.9%, alarm concordance 98.5%
  either way, 419 vs 420 alarms with 7 crossing each way, and a median
  change of 0.0000 to 0.0007 by arm size with no direction. The scale
  has no measurable effect; the inherited choice stands unless the
  derivable one (σ/√ΣN) is preferred for its own sake, which would cost
  only a re-pinning of the seeded known answers. Data:
  `C:/dev/Corpus/synthetic/location-scale/`.
- The median/IQR branch's calibration is now measured (above) on four
  populations at 10 to 100 per arm; bounded measurements (a score with
  a floor, a percentage) and quartiles printed at a coarser precision
  than the median are not yet in that table.
- Median rows still draw their N observations; the direct draw could be
  extended to them if a large-trial median row proves costly.
