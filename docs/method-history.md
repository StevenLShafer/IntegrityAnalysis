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
one part in 10¹⁰ of the larger; a statistic within 10⁻²⁶ of the centre
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
## 2026-09-07 — the summary line is identified by kind, not by its label

**What was wrong.** The engine's per-trial summary line carried the
label "Summary" in the ROW column and nothing else marked it, and the
API's across-trial combination, the results workbook's Summary sheet
and the graphs all found it by that text. The validator accepts a
variable called "Summary", so such a variable's row was taken for a
second trial summary and entered the closed-form combination across
trials as another trial: on the worked example the overall p moved from
0.046 to 0.0087 by renaming the row (the GPT-6 audit's finding F2,
`docs/audits/`; reproduced).

**What changed.** Every line of the engine's output now says what it is
in a `KIND` column — "variable", "summary", or blank on the spacer — and
every consumer reads that, never the label. The API's `resultsCsv`
carries the column so that a client can do the same; the workbook's
Test Results sheet keeps its six printed columns. No number changes for
any table without a variable named "Summary".

## 2026-09-07 — the SD's printed interval when some precisions are blank

The helper that turns a printed SD into its interval used a supplied
`ROUND_DISPERSION` only when every arm had one and otherwise re-inferred
every arm, so a supplied two-decimal "1.00" beside a blank became
[0.5, 1.5] (the GPT-6 audit's finding F5, `docs/audits/`). A blank cell
is now inferred on its own, taking the variable's maximum printed
decimals across its arms — the validator's rule — so a direct call and a
validated one agree. Only rows reaching `P_Calc` without the validator
and with a partly blank column were affected.

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
intervals. The bootstrap prints its quartiles to that precision. The
second half — integrating the quartiles' printed rounding into the fit
itself — is the next section.

## 2026-09-07 — the quartiles' printed intervals enter the fit

**What was wrong.** The metalog was fitted to the printed quartiles as
if they were exact. A printed quartile is not exact: it stands for an
interval half a printed unit either side, exactly as a printed standard
deviation does (2026-09-06). Where a variable's interquartile range is
comparable to one printed unit — a measurement near 5 with an
interquartile range of about 0.7, printed as integers — both quartiles
print the same digit much of the time, and the branch refused the row
("Quartiles do not increase"). On honest two-arm tables from that
population the refusal rate was 45% at ten per arm, 67% at thirty and
85% at a hundred (1,000 tables per cell,
`C:/dev/Corpus/synthetic/quartile-draw/`, the "narrow" population). The
tables that survived were fitted to a spuriously skewed metalog and
clipped at the skew limit.

**What changed** (Steve Shafer's decision, 2026-09-07, the GPT-6 audit's
finding F4). Every replicate now draws each arm's Q1 and Q3 uniformly
within their printed intervals, orders the pair, pools them by N, and
fits *that* replicate's metalog; the scale draw then resamples from the
replicate's own fit and inverts the ratio as before, and the location
draw uses the replicate's own scale, and the location's standard
deviation is computed from that scale rather than from the pre-bootstrap
fit. Quartiles that print the same value are admissible, and the row's
Note says so ("printed quartiles do not separate in k arm(s); the fit
uses their printed intervals"). Only quartiles printed in the wrong order
are still refused, and that test is applied per ARM: because each drawn
pair is ordered, one arm's reversed quartiles would otherwise be silently
repaired whenever the other arms kept the pooled pair in order. A blank
`ROUND_DISPERSION` cell is inferred on its own from the printed
quartiles' decimals, the rule a printed SD has followed since the audit's
finding F5, so a direct caller who supplies the precision for some arms
only keeps what it supplied.

**What it measured** (the same honest null, 1,000 tables per cell, two
equal arms, m = 1,000, five populations at 10, 30 and 100 per arm):

| | before | after |
| --- | --- | --- |
| Refused, narrow population, integer quartiles | 45%, 67%, 85% | 0%, 0%, 0% |
| p ≤ 0.05, all other populations | 0.027–0.078 | 0.027–0.078 |
| Kolmogorov–Smirnov distance from uniform, all other populations | ≤ 0.075 | ≤ 0.075 |
| Median/IQR pin (`test-known-answer.R`) | 0.04545 | 0.0427 |

Nothing outside the coarse case moved by more than Monte Carlo noise:
the draw's width is one printed unit, negligible beside an
interquartile range printed to two or three significant digits.

**What it did not fix, and the direction of the error.** The coarse
case is still conservative: for the narrow population with integer
quartiles the honest p averages 0.66–0.72 and never falls below 0.05.
Two printed quartiles that agree say only that the population's width is
under one printed unit; drawing them uniformly inside their intervals
implies a width of a third of a unit on average, narrower than the truth
(about two thirds here), and a model narrower than the truth ties its
rounded replicate medians more often than the data do, which inflates p.
The adversarial version of that worry — a median printed finely enough
that ties are rare, beside quartiles too coarse to pin the width, where
a narrow model could **false-alarm** instead — was measured and does
not occur: integer quartiles with two-decimal medians give an honest
p ≤ 0.05 rate of 0.003, 0.000 and 0.000 at 10, 30 and 100 per arm
(`null-draw-q0-med2.csv` against `null-point-q0-med2.csv`). A less
conservative treatment would need a prior on the population's width
given the printed digits, which is the dispersion-fabrication question
the screen deliberately leaves alone.

## 2026-09-09 — the fail-safe fill declines rather than guesses

The whole-table reconstruction of the previous day kept its guarantee —
that the counts analysed are the reading of the page most favourable to
the authors — by *sampling* when the admissible set grew too large. An
independent audit measured what that bought, and the answer was three
separate defects, all in the false-alarm direction.

**It restored the rule it replaced, silently.** When one ARM alone
allowed more vectors than could be enumerated, the search returned
"complete" with no p, and the caller kept whatever the old per-level rule
had already written. On a five-category page with 4,000 per arm that
produced arm totals of 4,100 and 3,900 against a stated 4,000, and a row
reading p < 0.0001 where valid counts behind the same percentages give an
exact 0.594.

**It invented complete partitions.** The test for "do these categories
divide the arm" was whether the bracket midpoints summed to within 2% of
N. That treats arithmetic as evidence about what the categories *mean*.
A page printing 24/24/24/26 with the footnote "Other categories omitted"
was rebuilt as an exhaustive partition in both arms and read p = 0.00003,
where the honest reading including the omitted category gives 0.064. The
reverse error was there too: honest counts summing to N but printing 97%
were called non-exhaustive.

**Its fallback could not be allocated.** Each arm was capped and the
arms were then multiplied, so 32 arms proposed 2³² tables despite a
20,000 sample cap; and where it did run, an eight-arm page missed a valid
reading worth 0.094 in p.

**What changed** (Steve Shafer's decision, 2026-09-09: "Skip"). The
search is complete or it does not happen. Beyond `.ppTableEnumMax`
candidates — or beyond it for a single arm — the block is UNRESOLVED:
the ambiguous cells go back to blank, the row is named in the flags with
the reason, and it is not analysed, which the summary's "k of n rows
analysed" line already reports. The 2% test is gone; no partition is
assumed except where this code builds the complement itself, so a chosen
reading may total a little more or less than the arm's N and the cell's
note says so when it does.

The cost is coverage, and it is small: one manuscript in 558 of the local
corpus triggers the fill at all, and the rows it now drops are the large
multi-arm tables where a reconstruction deserves least trust. The
alternative was to keep analysing them under a weaker claim — "the best
reading we searched" — which is not a claim an editor can act on.

**Three further repairs in the same commit.** The selector scored
candidates with its own probability helper, which used literal floating
equality for ties and a different floor: on one small table it returned
0.0998 where the exact answer is 0.35. It now shares the engine's
statistic, its zero-level handling, `.iaTieCounts()` and `.floorP()`.
Its grouping key now carries **both** margins, since the monotonicity
that lets a group be represented by its extreme tables holds only within
one null. And scoring simulates, so the reader now sets and restores its
own seed: extraction was stochastic, which both guides promise it is not.

**One claim narrowed rather than repaired.** The API guide said the
trial p is therefore the most favourable reading the page permits. It is
not: the trial combines rows and does not move monotonically with any one
of them, and the audit gave an exact counterexample where choosing the
greatest row p costs 0.142 in trial p. The guarantee is now stated for
the row, which is what it is.

## 2026-09-08 — the fail-safe fill chooses a whole table, by p

**What was wrong.** The rule of 2026-09-07 maximised, for each category
LEVEL on its own table line, that level's fixed-margin statistic against
its own complement. Three things were wrong with it, and they compound.

1. *It optimised a statistic the engine does not compute.* `P_Calc()`
   scores the whole arms-by-levels table with both margins fixed
   (`R/P_Calc.R`, `r2dtable`), not a level against its complement.

2. *The levels did not have to agree about the arm.* Each level was
   chosen alone, so three levels printed 33 / 33 / 34 % across two arms
   of 200 were rebuilt with arm totals of 203 and 197 — a table that
   cannot exist. The 2026-09-08 independent audit reported the same
   arithmetic (its F2, `docs/audits/`).

3. *It ran backwards.* For one level the maximising choice is the high
   count in one arm and the low in another, and the enumeration reached
   the same orientation first every time. Applied level by level that
   scaled one arm up and the other down uniformly, leaving the two arms
   in identical proportions — the most homogeneous table there is.
   Measured chi-square of the table the engine actually scores:

   | page | the old rule | range over admissible readings |
   |---|---|---|
   | 3 levels 33/33/34, arms of 200 | 0.000 | 0.000 to 0.061 |
   | 4 levels 25 each, arms of 200 | 0.000 | 0.000 to 0.160 |
   | 3 levels 33/33/34, three arms of 200 | 0.000 | 0.000 to 0.090 |
   | 4 levels 10/20/30/40, arms of 300 | 0.032 | 0.000 to 0.139 |

   In p terms for the first of those the admissible readings run from
   0.0041 to 0.0482, and the old rule returned 0.0041. The guarantee
   stated in seven user-facing places — "the row can look less alike
   than the truth, never more" — was false in the direction that makes
   an honest paper look fabricated. On the audit's own synthetic
   fixture the trial p moved from 0.00072 to 0.0043 when this was fixed.

**Why maximising the statistic was never going to be enough**, even done
jointly. A p is the statistic judged against the fixed-margin null, and
one of those margins is the level total — the very thing being chosen.
Raising a count moves the statistic and moves the null it is measured
against. Over 72 three-level rows with unequal arms the
statistic-maximising table was not the p-maximising table in 44 of them,
worst case p = 0.0148 chosen against 0.0247 available. The old rule
could not reach the answer even in principle for a second reason: a
convex statistic is maximised at a bracket end, so the search only ever
considered ends, and the largest p is sometimes at a middle value.

**What changed** (Steve Shafer's decision, 2026-09-08: "testing all
possible combinations in these ambiguous cases, and simply defaulting to
giving the authors the benefit of the doubt", then "best case, with
worst case only appearing if it straddles 0.01"). Every whole
arms-by-levels table the printed percentages allow is enumerated — each
cell inside its own bracket, each arm's counts summing to that arm's N
where the levels partition it — and each is scored with the engine's own
statistic and null. **The reading analysed is the one with the largest
p**, the best case for the authors. The smallest p over the same
candidates is carried beside it, and when the two fall on opposite sides
of p = 0.01 the row is named in the flags and in its hover note, because
for those rows the printed counts decide the answer and the percentages
do not. `R/failsafeTable.R` holds it.

**Scoring every candidate was wrong twice over** (security screens
2026-09-08-2100 and 2026-09-09-0721, both finding F1; Steve Shafer's
decision, 2026-09-09). It was, first, unaffordable, and the cost was
attacker-chosen. An entirely ordinary Table 1 — two arms of 700, a
three-level "ASA physical status, %" row printing 25/42/33 and 28/39/33
— allows 117,649 readings falling into 20,449 distinct nulls, each of
which was simulated separately: 190 s end to end, against a 60 s
subprocess timeout, so the manuscript did not parse slowly, it **failed
to parse at all**. The author of the paper under investigation decided
that, by printing a category as percentages.

*(The two paragraphs that follow are the reasoning as it stood on
2026-09-09. They were superseded on 2026-09-10 by the entry "the ranked
selection is a heuristic, and is described as one": the ordering across
margin groups is a heuristic, and the winner's-curse explanation of the
measured direction did not hold in general. They are kept because this
document records what was believed and when.)*

It was also, and less obviously, **less accurate than ranking**. Ranking
20,449 noisy 2,000-replicate estimates and refining the best six selects
on upward noise, and the refinement then takes it back — the winner's
curse — so the reported best case was biased low, which in this
instrument is the accusing direction and the one the whole fail-safe
exists to avoid. Measured against the ranked selection on nine shapes:
every `partition = TRUE` shape chose identical counts, and every
disagreement was a `partition = FALSE` shape where the exhaustive pass
returned the *smaller* p — 0.09517 against 0.1013, 0.1331 against
0.1363, 0.03583 against 0.03617, and on a three-arm row near the alarm
threshold 0.00135 against 0.001575.

So the candidates are now **ordered by the statistic and only the
extremes are scored**. The ordering is free, deterministic, and not a
heuristic: this p is the probability that a replicate is at least as
homogeneous as the printed table, so within one null it rises with the
statistic, and `pchisq(stat, df)` — the asymptotic form of the same
quantity — orders the groups by the statistic itself when the degrees of
freedom are shared. Every reading is still enumerated; the user-facing
sentences now say "enumerated, and the least alike scored", because
"enumerated and scored" had become a guarantee the engine no longer
gives. Two further costs went with it: the admissible vectors for an arm
are **counted** before any is built (a closed-form convolution, so a
block past the bound declines in milliseconds instead of the 153 s it
took to discover the same thing by enumerating), and the statistic is
computed for every candidate in whole columns through the identity
`sum (T − E)²/E = n (sum T²/(r c) − 1)`, which is exact and is pinned
against `.ppTableStat()` candidate by candidate. The same ordinary Table
1 now takes 1.6 s.

**What makes it affordable.** The null depends only on the margins.
Constraining each arm to its N pins the arm margin, so only the level
totals vary, and within one level-total group the mid-p is
non-decreasing in the statistic — so only that group's extreme tables
can be its best or its worst. Three levels across two arms of 200 admit
49 tables but 19 distinct nulls; five levels admit 2,601 tables and 381
nulls. Measured with the engine's own `r2dtable`, nineteen nulls cost
0.3 s staged. Beyond `.ppTableEnumMax` candidates — a hostile document
chooses the arm count, the level count and the arm sizes, and three
levels across arms of 5,000 admit 3.8 million tables — the search is
bounded rather than complete, and the row says so rather than letting a
guarantee quietly stop holding.

**Two things fixed alongside it, because the disclosure depends on
them.** A hybrid parse (heuristics plus the AI assist) dropped
`derivedCells` and `approxCounts` at the merge, so those parses painted
no orange cell and showed no hover note although the flag text named the
rows; they are carried through now. And the note attached to a
fail-safe cell was matched by `identical()` against a named character
vector, which never matched, so the note kept describing a choice that
was no longer the one made.

**What is still a proxy, and is stated rather than promised.**
Maximising each row's p does not exactly maximise the TRIAL p: the trial
null is simulated from the row nulls, and those shift with the margins
being chosen. It is the same mechanism as the defect above, one level
up, and it is small — but it is a proxy, and the documentation says so
rather than claiming an exactness the code does not have.

## 2026-09-07 — counts rebuilt from percentages: the fail-safe fill

**What was wrong.** The opt-in approximation of 2026-08-21 rebuilt a
count from a printed percentage as round(N × percentage/100) when the
percentage fit several counts, which it does for arms above 100 at
integer percentages (1,000 at one decimal). The categorical engine then
treated the count as exact. Two honest arms whose percentages happened
to round the same — a third of pairs at 5,000 per arm, where the
honest difference has a standard deviation near one percentage point —
were rebuilt with identical proportions, an agreement the real counts
never had. The GPT-6 audit's exact enumeration (finding F3,
`docs/audits/`) put 38% of honest 5,000-per-arm pairs below p = 0.01.
Arms of 100 or fewer were never affected: there every count has its own
percentage and the conversion is exact.

**What changed** (Steve Shafer's decision, 2026-09-07). Of every set of
counts the row's printed percentages allow — one end of each ambiguous
arm's bracket, the exactly pinned arms held fixed — the row is built from
the set that leaves the arms least alike, so it can look less alike than
the truth but never more, and its p is conservative.

That guarantee took three attempts, and the two that failed are worth
recording, because each was a plausible rule that optimised a proxy
instead of the thing promised.

1. *Away from the pooled proportion* (the first version). Every
   ambiguous arm on the same side of one pooled number took the same end
   of its bracket, so three arms printing 50% of 2,000 beside a small arm
   printing 52% of 60 all became 990 — identical proportions, the defect
   the rule exists to prevent — and an honest row of that shape read
   p = 0.0094 (security screen 2026-09-07-1609, finding F1).
2. *Split the ambiguous arms against each other by rank.* This fixed that
   case and left another: the ordering looked only at the ambiguous arms,
   so the exactly pinned arms had no vote, and two pairs of arms could be
   split correctly against each other while both moved toward the rest of
   the row. Over 86,310 synthetic rows the assignment fell short of the
   most heterogeneous consistent reading in 57.9% of rows, and in the
   worst case measured — five arms printing 49%, 45%, 47%, 47% and 49% —
   it built a row reading p = 0.116 where an equally consistent reading
   reads p = 0.872 (screen 2026-09-07-1654, finding F1).
3. *Maximisation* (what runs now). The objective is the statistic the
   engine simulates for a categorical row: the fixed-margin Pearson
   statistic of the level against its complement. It is convex in the
   counts, so its maximum over the box of admissible counts sits at a
   vertex, and every vertex is one lo/hi choice per ambiguous arm. Up to
   twelve ambiguous arms every vertex is enumerated, and there the answer
   is the maximum by construction — verified against exhaustive search on
   3,000 random rows. Beyond twelve — the arm count follows the columns a
   document declares, so it is not ours to bound — coordinate ascent runs
   from both corners, which is a local maximum and matched the exhaustive
   answer on every row measured but is not proven to be the global one. A
   baseline table with thirteen or more arms whose percentages are all
   ambiguous is not a shape that has been seen; the guarantee is exact
   below the bound and empirical above it. Splitting arms that print
   alike is no longer a rule but a consequence, and where the brackets
   force two rebuilt counts to coincide they are allowed to: what the
   editor reads is the row's p, not the appearance of the counts.

How conservative the rule is, measured (lower-tail mid-p of the Pearson
statistic under `r2dtable`, 200,000 draws): a two-arm row of 5,000 per
arm printed as the counts 2,500 and 2,500 reads p = 0.008; printed as
"50%" and "50%" the same row is filled to 2,475 and 2,525 and reads
p = 0.68. A row that would alarm on printed counts usually will not alarm
on printed percentages. The guides and the app legend say so, since under
this screen's threat model the author chooses the notation. The app paints such cells orange (a colour of their own,
apart from the green of exact conversions) with the bracket in the
hover note; the API applies the same rule and names the rows in its
response flags — on both routes, since `/analyze` returned the p without
them until the same screen's finding F2 — and the user guide, the API
guide and statistics.md state it as a design decision for incomplete
data. Exact conversions are untouched.

## 2026-09-07 — a row whose printed precision the arithmetic cannot carry

**What was wrong.** The validator caps a value's magnitude (10¹²) and its
printed decimals separately, and neither cap asks whether the two are
compatible. A double carries about 15.7 significant digits, so a table
printing twenty decimals beside a value of 10¹¹ is asking for a
resolution the arithmetic does not have; the simulation then rounds on
the floating-point grid instead of the printed one, silently. The GPT-6
audit's demonstration (finding F7, `docs/audits/`): 100 and 101 per arm,
identical means, a standard deviation of 10⁻⁶ and twenty printed
decimals reaches the replicate floor (0.000999) at means of zero and
reports **0.5** with both means moved to 10¹¹ — the draws collapse. Both
inputs pass validation. Reproduced, and the drift is visible long before
the collapse: 0.004 at 10⁴, 0.046 at 10⁵, 0.35 at 10⁶.

**What changed.** A row is refused by name — "Printed precision beyond
this magnitude's numerical resolution" — when the finest grid it asks for
(the mean's, the observations', and for a median row the quartiles')
falls below eight times the spacing between representable numbers at its
own largest printed magnitude. Eight is three bits of headroom: rounding
to a grid a few units of least precision wide is arithmetic, not
measurement. Ordinary tables are far from it — two decimals at 10¹², the
validator's ceiling, still leaves 45 representable steps per printed step
— and every shape the security screens pinned (a thousand arms printing
10⁹ + 0.25 at two decimals; five thousand per arm at 10⁹) is unaffected.

The same test is applied to the direct draw, which snaps a drawn mean to
h/N, the grid a mean of N rounded observations lives on. Where that grid
falls below the arithmetic's spacing the snap makes no ties at all, and
missing ties is the *alarming* direction, so those arms simulate in full
instead. That is a narrower condition than the row refusal, since h/N is
N times finer than the printed grid.

## 2026-09-07 — a stated precision has to describe the number beside it

**What was wrong.** The precision columns say what grid a printed value
sits on, and since 2026-09-06 for a standard deviation and 2026-09-07 for
a quartile the engine reads that grid as the *interval* the printed value
stands for. Nothing bounded the grid against the value it describes. The
validator accepted any precision in [−20, 20], so one cell of a supplied
spreadsheet or a posted template — `ROUND_DISPERSION = −5` — multiplied
the width of the null by a hundred thousand while the observed statistic
stayed put. Measured on an honest two-arm median row (N = 40, medians 50
and 52, quartiles 45–55 and 47–57, m = 10,000):

| `ROUND_DISPERSION` | 0 | −1 | −2 | −3 | −5 | −10 | −20 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| p | 0.64 | 0.718 | 0.629 | 0.187 | 0.0049 | 9.999e−05 | 9.999e−05 |

9.999e−05 is the floor of the reportable range: a maximal alarm on an
honest trial, produced by a cell nobody would look at twice. The mean/SD
branch carried the same lever (0.624, 0.037, 9.999e−05). The quartile
draw had made the failure *worse* in the sense that counts: before it, a
coarse `ROUND_DISPERSION` collapsed the bootstrap scale and every row read
p ≈ 1, a false clearance; after it, the same cell produces a false
accusation (security screen 2026-09-07-1758, finding F1).

**What changed.** A row is refused — "The stated precision does not match
the printed values" — when a printed value does not sit on the grid its
own precision column names, checked per column: means against
`ROUND_MEAN`, standard deviations and quartiles against
`ROUND_DISPERSION`, with a tolerance proportional to the value and never
to the grid (a grid of 10²⁰ would otherwise swallow every number ever
printed). The next day's screen found the gate had left two ways in, both
now closed (2026-09-07-1907). The **third precision column** was not
tested at all: `ROUND_OBSERVATION` sets the grid every simulated
observation is rounded to, and a coarse one moved five honest arms of 40
from p = 0.433 to 0.0125. A statistic built from N observations on a grid
of h lies on a grid no coarser than h/N, so the interval the printed value
stands for must contain a multiple of h/N — vacuous for every ordinary
table, and refusing both of the screen's rows. And **zero sits on every
grid**, so a row printing nothing but zeros — "0 (0–0)", a shape many
analgesia trials carry — passed at any stated precision and went from its
honest p = 0.5 to below 0.0001 at `ROUND_DISPERSION = -20`; such a row
states no scale of its own, so what is checked instead is that its
precision columns agree with each other.

The screen after that one (2026-09-07-2000) found the location-side rule
vacuous wherever the observation grid divided by N is finer than the
printed mean's own step — which the arm size decides, so the choice was
the manipulator's — and closed it from the dispersion side, where the
bound is a theorem rather than a heuristic: **N values on a grid of width
h have a sample SD that is either exactly zero or at least h/√N**. A table
claiming an SD of 1 for a thousand values on a grid of a thousand is
arithmetically impossible, and was being simulated: three arms of 1,000
printing mean 500 and SD 1 read p = 0.5 honestly and 9.999e−05 — the
reportable floor — at `ROUND_OBSERVATION = -3`.

The same screen found the whole gate one-sided. Every decimal sits on
every *finer* grid, so a precision finer than the printed value passed
every test, and an over-fine `ROUND_MEAN` erases the rounding of the
simulated arm means — which is the tie mass by which an honest table with
identical printed means earns a large p (0.4185 to 9.999e−05 at
`ROUND_MEAN = 15`). The anchor in that direction can only be the value's
own digits — and there the engine stops short of refusing, deliberately. A
mean stored as 50 may have been printed "50" or "50.000000"; a spreadsheet
keeps no trailing zeros, so the honest row and the manipulated one are the
same numbers, and the 2026-09-06 audit's own case is the honest one
(integer observations beside a six-decimal printed mean, where the small p
IS the right answer). The row is therefore analysed as the table claims
and the claim travels with the answer: a Note says that the stated mean
precision is finer than the printed values and that the p depends on it,
on the rows where it decides anything. The same claim was measured and
rejected for the other two columns, which are inert in the fine
direction. The test is consistency, not coarseness, which matters because
two honest shapes look coarse: quartiles of 40 and 60 reported to the
nearest ten are consistent and analyzed, and a variable whose
interquartile range is smaller than one printed unit — the case the
quartile draw was built for — is untouched.

## 2026-09-08 — the dispersion bound, sharpened and confined

The bound added the previous evening — N values on a grid of width *h*
have a sample SD of exactly zero or at least *h*/√N — was both too weak
and too strong, and the screen that found it (2026-09-07-2101) measured
each half.

**Too weak.** 1/√N is the smallest the lattice offset can be. The sharp
statement has two parts, and the larger governs: values on a lattice of
width *h* whose sample mean sits a fraction α of a step from a multiple of
*h* have SD ≥ *h*·α, and separately the smallest non-zero sample SD N
values on that lattice can have is *h*/√N whatever the mean. They are
different quantities — α itself can be as small as 1/N — so a row must
clear both. The manipulation needs α near ½ — a printed mean near a half-grid point,
which the earlier screen had itself named as the operating point. At a
thousand per arm that is a factor of sixteen of headroom, and honest
tables of 1,000 printing means 500/501/499 with an SD of 40 read p = 0.414
at an honest observation precision and 0.00235 at −3, or the reportable
floor when the means were equal. α is now computed over the printed
mean's own interval, so no honest table is refused for the width of its
printing.

**Too strong.** A blank `ROUND_OBSERVATION` defaults to `ROUND_MEAN`, and
that default is a guess: "a mean printed to *d* decimals means the
observations lie on a grid of 10^−*d*" is false for any continuous
variable whose mean happens to print without decimals. Turning the guess
into a refusal threw out honest rows — "2 ± 0.2" at eight patients, with
no precision columns supplied at all — and a refused row left the trial
silently, so a Summary reported a combined p from two of three rows with
nothing saying so. Worse, an *impossible* row is the strongest signal the
instrument has, and silencing it hands an author a way to remove a row
from the analysis by printing an impossible SD. The bound is therefore
applied only where a table states an observation grid coarser than the
printed value's own, and **every** refusal, whatever its reason, is now
counted on the Summary line: "k of n rows analysed".

## 2026-09-08 — the precision claim, in both directions

The note that discloses a stated mean precision finer than the printed
digits was adjudicated as the whole remedy for that shape: refusal was
considered and rejected, because a spreadsheet drops trailing zeros and
the honest row and the manipulated one are the same numbers. A remedy the
manuscript can switch off is no remedy, and this one could be: the filter
that limited the note to rows whose arms print alike compared **raw
doubles**, so perturbing one arm by a single unit in the last place —
invisible to `format(digits = 15)`, to `.iaDecimals()` and to the grid —
removed the note while the row still read the reportable floor. The arms
are now compared at the precision their values carry (security screen
2026-09-07-2241, F1) — and, after the next screen defeated that too by
widening the perturbation one decimal, on EITHER of two tests, so that
both must be defeated: the engine's own verdict that the arms are equal
(the observed statistic snapped to zero) and equality at the fewest
decimals any arm carries. The lesson is worth keeping: when a disclosure
is chosen instead of a refusal, its trigger must be the same quantity the
engine itself acts on, not a second and stricter definition computed from
the same numbers (screen 2026-09-07-2339, F1).

The same screen made a larger point. Every guard added over 2026-09-07
points at the **accusing** direction: a stated precision that drives a p
down. The mirror direction is the one an author benefits from, and it was
neither refused nor disclosed. Three arms of 100 printing an integer 50
with an SD of 30 read p = 9.999e−05 at `ROUND_MEAN = 1` and 0.275 at −1; a
median row's `ROUND_OBSERVATION` took p = 0.0557 to 0.5. Neither is
impossible — a paper printing "50" may honestly have rounded to tens — so
neither is refused; both are now disclosed by a Note, on the rows where
the claim decides the answer.

Not done, and a decision for Steve Shafer: the screen also asks for a
dispersion-side consistency test on the median branch, requiring the
printed quartiles to be reachable as type-7 quantiles of N values on the
stated observation lattice. That is a new refusal, and the two screens
before this one each caught a new refusal throwing out honest rows. It
wants its own measurement against the corpus first.

## 2026-09-09 — a replicate is translated by its own first arm

Independent audit 2026-09-09, finding F6. The engine's zero snap decides
when a replicate is *exactly as homogeneous* as the printed table, and
that decision was being made by a tolerance where it should have needed
none.

**What was wrong.** The observed row is translated by its own first arm
(`dd <- ROWS$MEAN - ROWS$MEAN[1]`), so arms that print alike give a
statistic that is structurally, bitwise zero. Every replicate was
translated by that same *observed* constant. When all arms of a replicate
draw the same value the translated values are equal — but their
N-weighted centre is not bitwise equal to them, so the statistic came out
as dust rather than zero, and a tolerance had to forgive it. The
tolerance is proportional to the finest printed step squared, so the
finer the printed precision the smaller it gets; below about eleven
decimals it falls under the dust and genuine ties start being dropped.
Screen 2026-09-07-1459's own comment states the intent — the translation
exists so that identical means are exactly zero "in the observed row and
in every replicate" — and subtracting a single constant only ever
delivered the first half of it.

**Measured.** The audit's construction is two arms of 30 with `MEAN` 2.3,
`SD` 3.007, integer observations; an arithmetically feasible integer
sample exists (nine 3s, eight 6s, eight −2s, five 2s). Both six and
fourteen printed decimals distinguish adjacent possible sample means,
whose spacing is 1/30, so equality is the *same event* at both. A
reference that compares integer sample **sums**, never a floating
statistic, puts the mid-p at 0.008474 over a million draws (0.008529 over
400,000 here). Applying the two centrings to the same draws:

| `ROUND_MEAN` | ties | lost before | lost after |
|---|---|---|---|
| 6 | 6,823 | 0 (0.00%) | 0 (0.00%) |
| 14 | 6,823 | 1,243 (**18.22%**) | 0 (0.00%) |

End to end the row read 0.00816 at six decimals and 0.0066 at fourteen;
it now reads 0.00816 at both.

**The median branch had the same defect, and the audit did not test it.**
It is invisible on an integer observation grid, because a median is then
a multiple of a half and halves are exact in binary, so no dust can
arise. On a tenths grid it appears: two arms of 31 (odd, so the median
*is* an observation and rounding it to one or to fourteen decimals
changes nothing) read 0.01995 at one and six decimals and drifted to
0.01755 from eleven on. They now read 0.01995 at every precision. At an
*even* N the median is a multiple of 0.05, so rounding to one decimal
genuinely coarsens it and the p is still expected to differ — that is a
different equality event, and a test pins the difference so it cannot be
flattened later.

**What changed.** `MCMean <- MCMean - MCMean[, 1]` and
`MCMed <- MCMed - MCMed[, 1]`. The statistic is translation-invariant, so
this is the same quantity; only the floating point differs. Nothing moves
at any precision a real paper prints — the pinned ordinary rows are
bitwise unchanged — and the units and origin invariance the earlier
audits established is unaffected.

The general lesson is the one the fail-safe rule taught in a different
place: **an exact property should be arranged structurally, not defended
with a tolerance.** A tolerance has to be tuned against two moving
quantities, and here one of them was under the manuscript's control.

## 2026-09-10 — the zero-snap floor is the printed grid's alone

Independent audit 2026-09-10, finding F1 (P1). The one moving quantity
the entry above left in the tolerance was the observed row itself, and
the audit showed a manuscript moving a trial p across 0.01 with it.

**What was wrong.** The tolerance was `1e-12 × max(largest observed
translated arm difference², finest printed step²)`, applied to every
simulated statistic before ranking. An unusually large *observed* arm
difference therefore decided what counted as zero in an otherwise
ordinary *simulated* null. The audit's construction is three rows of two
arms of 100, SD 1, four printed decimals: row X prints means 0 and
10,000,000, rows Y and Z print 0 and 0. Row X's tolerance came out at
100; its 100,000 replicate statistics range from 0 to 0.19 (4,292
distinct integer arm distances, 31 genuine zeros) and every one of them
snapped to zero, so X's null contributed a constant z to the
combination where it should have contributed its rank. The observed
statistic of X was nowhere near zero, so its own contribution stayed —
the observed combination and its null no longer described the same
calculation.

**Measured.** Through CSV upload, the API's analysis route, validation
and the engine, seed 42, 100,000 replicates: trial p **0.00609**. An
integer-distance reference on the *same draws* — the statistic is
`(mean₁ − mean₂)²/2` for equal arms, and the printed means sit on the
0.0001 grid, so `round(sqrt(2·stat)/0.0001)` recovers an exact integer
distance that ordinary integer ranking then combines without any
tolerance — gives **0.01979** (1,979 of 100,000 strictly beyond, no
ties). Collapsing only row X reproduces the production 609. Setting the
tolerance to zero in a diagnostic copy gave 0.01978. Reducing X's
difference to 1,000 gave 0.0196 in production: the alarm was caused by
making X *more* heterogeneous, which is the accusing direction, and it
was manufactured by the guard.

**What changed.** `.iaZeroSnapTol()` takes only the printed step:
`1e-12 × min(step)²`, and zero when no precision is stated. The
observed deviations no longer enter it. Since the entry above, a
replicate whose arms drew the same rounded mean is structurally zero, so
no dust arises to be forgiven; the audit measured the repaired
continuous, median and unequal-N cases bit-identical with the snap
removed entirely. The floor is kept as the guard it was always meant to
be, and it is inert by construction: the smallest statistic two distinct
readings on the printed grid can produce is at least half the step
squared (one arm a step from the rest gives deviations `step·(1 − w)`
and `step·w`, whose squares sum to at least `step²/2`), eleven orders
above the tolerance, while the floating error in the sums is many orders
below it. The audit's three-row CSV, run through the same route with the
same seed, now reads inside the reference's interval
(`tests/testthat/test-audit-2026-09-10-f1.R`), and the ordinary pinned
rows are unchanged.
## 2026-09-10 — rows the validator leaves out are counted

Independent audit 2026-09-10, finding F3 (P2). The method document
promises that every reconstruction refusal is counted on the Summary's
"k of n rows analysed" line. It was not met when all cells of the
refused block became blank.

**What was wrong.** A category block the parser could not reconstruct
(the audit's ASA status, 33/33/34% of 1,200 per arm, about 4.8 million
readings) reaches the validator as label-only lines — every cell blank.
The validator soft-flags such lines and removes them from the analysed
frame, which is right for the engine, but the engine was then handed
three variables and had no way to count the fourth: the Summary's note
was blank instead of "3 of 4 rows analysed", and the row was absent
from the results, the journal-style table and the API's returned
template, where a caller could have typed the counts in.

**What changed.** `validateData()` returns the rows it left out, with
the reason, beside the analysed frame; `P_Calc()` lists each such
variable once, with P "Not analysed" and the reason in its note, so the
coverage count includes it — it never enters the combination. The API
puts those rows back into `templateCsv` and the journal table (a blank
line under the variable's label). The audit's JATS and Word fixtures now
read "3 of 4 rows analysed" through the API's analysis route and through
the actual `/analyze` handler, with the ASA row in the returned template
(`tests/testthat/test-audit-2026-09-10-f3.R`). The trial p is unchanged:
it is the same three rows' combination, now labelled as such.

## 2026-09-10 — the ranked selection is a heuristic, and is described as one

Independent audit 2026-09-10, findings F2 and F5; Steve Shafer's
decision, 2026-09-10.

**What was claimed.** Since 2026-09-09 the fail-safe fill ranks the
candidate tables' margin groups by the Pearson statistic and scores only
the fifty at each end (the entry above: scoring every group took 190 s
on an ordinary Table 1 and the document failed to parse). The code and
the documents said the ranking was "not a heuristic in disguise" —
within one null the mid-p is monotone in the statistic — and explained
the measured direction of the disagreements with the exhaustive pass
(always a larger p) as the exhaustive pass's winner's curse, which a
noiseless ranking could not have.

**What the audit showed.** Monotonicity holds within one fixed-margin
null; across margins it need not, because the finite conditional
distributions differ. By exact enumeration of the 2×2 hypergeometric
reference: on a 1000/200 page printing (2,25)/(1,27), the group holding
the table with the largest exact p (0.93204) ranked 85th of 689, and the
selector — through the JATS and Word routes alike — took a reading with
exact p 0.92934; on a 2000/200 page printing (1,10)/(0,11), the
minimising group ranked 313th of 1,846 and the reported worst case was
0.0208 above the true one. A sweep of 171 configurations found five
with a better best case omitted and 33 with a lower worst case omitted;
none crossed 0.01 and no partitioned row was affected. The winner's-
curse explanation was tested with the exact score sampling distribution
(2,000 selection repetitions per shape): the ranked selector chose a
reading with a lower true p on two shapes (by 0.0030 and 0.0024) and a
higher one on the third (by 0.0003), and both selectors' reported
estimates sit above the chosen reading's true p because the final
choice still maximises a noisy refined score. Selection loss and
estimation bias are different quantities, and neither has a fixed sign.

**What was decided.** The certified optimum — scoring every group, or a
bound across the omitted groups — is not worth its cost for a screen
whose purpose is to flag tables for review: the first is what failed to
parse, and the second has no method on the table. The ranked runtime
stays. The claim changes: the reading analysed is the most favourable
**among the readings scored**, and the worst case beside it the least
favourable among them; the straddle warning stays; the measurements are
recorded as measurements. `statistics.md`, the user guide, the API
guide and the selector's commentary in `R/failsafeTable.R` now say
exactly that.

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
