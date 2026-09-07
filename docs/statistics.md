# How IntegrityAnalysis computes and reports its p-value

This is the method as it runs today. How it came to be — every change
from the original Carlisle–Shafer Monte Carlo, dated, with what was
measured — is in [method-history.md](method-history.md), and every
corpus figure quoted here traces to a row of
[the validation ledger](validation-ledger.md).

Provenance: first written by Claude Code (model Claude Fable 5) on
2026-08-17 with the adaptive-replicates implementation; restructured
2026-09-06 to describe the present method only, at Steve Shafer's
request. The design decisions are Steve Shafer's.

## What the p-value means

For every baseline variable (each ROW of the table), IntegrityAnalysis
asks one question: **if the arms really were random samples from a
single population, how often would their printed summaries agree this
well?** The answer is a one-sided p-value toward *excessive
homogeneity*:

- **Small p** = the arms are more alike than random sampling explains —
  the demonstrated fraud signal (it is how Fujii's fabricated trials
  were caught).
- Large p = nothing remarkable *for this screen*. Excessive
  *heterogeneity* is not reported: the app has no heterogeneity alarm,
  and reporting one would invite false accusations against merely
  variable data.

A small p is a reason to verify the table, the allocation method and
the underlying data. It is not the probability that the study is
honest or fraudulent, and a large p does not establish integrity. The
per-variable p's combine across the trial into one trial p, and trial
p's combine across a file into one overall p; each step rests on
assumptions stated below.

## The algorithm in one table

| Component | What runs | What it assumes |
|---|---|---|
| Mean/SD variable | Common mean (N-weighted); each replicate draws every arm's SD within its printed interval, pools the variances with weights N<sub>i</sub> − 1 (df = ΣN − k), draws σ² = s²·df/χ²(df), then N observations per arm around a common location, rounds each to the observation precision, averages, rounds the mean as printed; statistic = sum of squared deviations of the arm means from their N-weighted centre | Independent normal observations from one population; the printed SDs and Ns are the sample's; the rounding columns are right |
| Large arms (N ≥ 100 and SD ≥ 3 observation-grid steps) | The arm mean is drawn directly with variance (σ² + h²/12)/N, snapped to the h/N grid the observations force on a mean, then rounded as printed | The central limit theorem at that N; Sheppard's correction for the grid |
| Median/IQR variable | A three-term metalog fitted to the N-weighted arm medians and quartiles (a skew beyond the metalog's limit is clipped to it, and the Note says so); each replicate first draws that population's scale from the quartiles' own sampling uncertainty (every arm resampled from the fit, its quartiles printed to the quartiles' own precision and pooled, and the resampled scale's ratio to the fit inverted, as the sigma draw inverts the chi-square), then draws N observations per arm from it, rounded; the sample median rounded as printed; the same statistic on the medians | The metalog represents the population well enough near its median; the unbounded form may put mass outside a measurement's support |
| Categorical variable | Random 2 × c tables with the observed arm and category totals fixed (`r2dtable`); the lower tail of Pearson's chi-square | Mutually exclusive, exhaustive levels; the counts are the arms' |
| Row p | The share of replicates at least as homogeneous as the printed row, ties counted by halves (mid-p), floored at 1/(replicates + 1) | — |
| Trial p | Stouffer's sum of the rows' z-scores, judged against the same sum computed for every replicate (rows simulated independently), ties by halves | The variables are independent |
| Overall p (several trials) | The closed-form Stouffer combination of the trial p's against the normal table; a trial reported as "<0.0001" enters as 0.0001 | Independent trials; continuous trial p's |

Every trial starts with 1,000 replicates per row and escalates to 10,000
while the trial's p or any row's is below 0.1, and to 100,000 while
below 0.01. Each stage draws afresh; the `Replicates` column reports the
final batch, and every usable row of a trial shares it.

## Where the numbers come from, and why they carry uncertainty

Each row's p is estimated by simulation: the app draws many replicate
trials under the random-sampling hypothesis, rounds the simulated
summaries exactly as the paper rounded its own, and counts how often
the simulated arms agree at least as well as the printed ones. Ties
count half — the mid-p convention, a deliberate choice. A mid-p is
centred on the right value on average, and it reproduces Carlisle's
published 2017 values (r = 0.993 over 5,041 usable trials in the current engine, [ledger](validation-ledger.md)), but it is not
exactly uniform for every fixed margin of a discrete table: where the
tie mass is large, the share of honest tables below 0.05 can sit above
or below 5%. (An inclusive-tail p, counting every tie, would be
conservative instead.) A tie is decided by a stated numerical
criterion, not by exact equality of floating-point numbers: two
statistics within one part in 10¹⁰ of each other are one value, for the
observed row against its replicates and for the replicates among
themselves alike, and a statistic that is zero up to floating-point
dust is zero. Floating-point error in these sums is far below that
tolerance and the gap between distinct attainable values far above it,
so mathematically equal statistics are never split and distinct ones
never merged (an independent audit found the strict comparison
splitting a categorical tie group into 0.10 where the exact mid-p was
0.35; see [method-history.md](method-history.md)).

A simulated p-value is itself an estimate. If 0 of 1,000 replicates
agree as well as the printed data, the true p could still plausibly be
0.003 — so reporting "p < 0.001" from 1,000 replicates would overstate
the evidence. IntegrityAnalysis is a screening tool whose verdicts may
be challenged, so it reports only what the simulation supports:

- **No literal zeros.** A row where no replicate matched is floored at
  1/(replicates + 1) (Davison & Hinkley).
- **"<0.0001" is a confidence statement.** A row displays "<0.0001" only
  when the one-sided 97.5% upper Clopper–Pearson bound on its simulated
  count (ties counted fully — conservative) clears 0.0001. At zero hits
  this needs about 37,000 replicates (at 30,000 the bound is still 1.2 × 10⁻⁴); at 100,000 the bound is
  3.7 × 10⁻⁵.
- **Every row carries a 95% Monte Carlo interval**, exact
  Clopper–Pearson, its lower end from the strictly-below count and its
  upper end from the at-or-below count, so it brackets the mid-p and
  errs wide ("0.27 to 0.33" for an unremarkable row at 1,000
  replicates; "0 to 3.7e-05" for a row with nothing at or below at
  100,000). It is the simulation's uncertainty about the row's p, not
  uncertainty about the trial's data.
- **Precision by stage.** At 1,000 replicates a p near 0.05 has a Monte
  Carlo standard error of about 0.007 (95% half-width about 0.014); at
  10,000 about 0.002 (half-width 0.004). This is why a borderline row is
  escalated.
- **One qualification.** The batch the interval is computed from is the
  one the staging chose to stop at, and that choice looks at the batch's
  own p, so the interval is not exactly a fixed-sample 95% interval. By
  exact enumeration, coverage is about 93.5% for a row whose true p is
  near an escalation threshold (93.7% at p = 0.008, 93.4% at 0.085,
  93.6% at 0.09) and the nominal 95% away from them (95.2% at 0.05, 0.10
  and 0.20). The interval is a guide to the simulation's precision, not
  a certified confidence statement; the "<0.0001" bound is unaffected.

## The mean/SD model

**The population SD.** Each arm reports an SD computed about its own
mean, so arm *i* carries N<sub>i</sub> − 1 degrees of freedom and the
pooled variance — each arm's variance weighted by its degrees of
freedom — has N − k of them for k arms: the minimum-variance unbiased
estimate of a common variance. The simulation does not treat that
pooled SD as known. Each replicate draws its own population variance,
σ² = s² · df / χ²(df), from the scaled inverse chi-square the pooled
variance implies, and generates that replicate's observations and its
common location with that σ. The observed between-arm statistic is
therefore judged against replicates whose σ varies as the data's own
uncertainty says it should — the simulated statistic behaves like the F
it should rather than the chi-square a fixed σ gives. This matters
below about ten patients per arm; above that the draws are so tight
that nothing changes.

**The SD's printed rounding.** A printed SD is an interval, not a
number: "1" at integer precision means a sample SD anywhere from 0.5 to
1.5. The mean's rounding needs no special treatment, because the
simulation rounds its own means the same way and the tie mass is the
mechanism; the SD is different because it enters the null as a
parameter. So each replicate first draws every arm's sample SD uniformly
within its printed interval — half a printed unit either side
(`ROUND_DISPERSION`, inferred from the printed decimals when the column is
blank), never below zero — pools those by degrees of freedom, and only
then applies the chi-square draw above. A printed SD of exactly zero is
not an interval: it declares that the variable did not vary, and is kept
at zero. The row p is sensitive to where in its interval the true SD
lies (two arms of 30, means tied at one decimal: 0.128 if the SD printed
"1" were really 0.5, 0.050 if it were 1.49), but that is uncertainty the
table cannot resolve, not bias; averaged over the interval the p moves
little — about 2% upward for a printed "1", under 1% for "2" or "3",
nothing at two significant figures — because pooling the drawn SDs by
their squares raises the pooled variance by the rounding's own h²/12 and
nearly cancels the gain from smaller draws. The draw makes the p the
right average over what the printed SD can mean; it does not make a
one-digit SD say more than it does.

What is still taken as given: the common location (estimated from the
printed table), the printed rounding of the means, and the arm sizes. (A
point estimate of σ from the printed SDs, corrected for the square root's
small-sample bias with c₄ at N − k degrees of freedom, survives only to
decide whether an arm qualifies for the direct draw.)

**The common location.** Each replicate draws one true mean for all
arms, Normal about the N-weighted pooled mean with standard deviation
σ/√(mean N). For unrounded data this draw cancels from the statistic,
which measures the arms' deviations from their own centre; it matters
only through where the location sits relative to the rounding grid,
which decides how often two arm means print the same value. The scale
is inherited from the original simulation (the pooled mean's own
sampling standard deviation would be σ/√ΣN, narrower by √k); see the
notes at the end of [method-history.md](method-history.md).

**The direct draw for large arms.** When an arm has at least 100
patients and the SD is at least three observation-grid steps, the arm
mean is drawn directly: one Normal draw with variance (σ² + h²/12)/N,
where h is the observation grid (Sheppard's correction for rounding
each observation), snapped to the grid of width h/N that N rounded
observations force on their mean, and then rounded as the printed mean
was. Below either threshold every observation is simulated. Tested
against the full simulation on the two-arm statistic, 100,000 replicates
per cell, N from 10 to 300, printed to 0 or 1 decimals, and on the
integer-observation, six-decimal-mean case that first exposed the need
for the snap; the two agree to Monte Carlo precision, and the direct
draw is about thirty times faster at 5,000 per arm. Median rows always
draw their observations.

## Rounding, convergence, and the attainable floor

Under honest randomization the arm means are estimates of one
population mean, and as the arms grow they converge on it: the standard
error of an arm mean falls like 1/√N. Once that standard error is
smaller than the printed precision, the arms will often print the same
number. At 1,000 per arm with SD 13, the standard error is 0.4;
reported as integers, the two means agree about half the time.
Identical rounded means in a large trial are the expected outcome of
convergence, not an anomaly.

The row simulation reproduces this exactly, because it rounds its
replicates as the paper rounded its own. Its tie mass at the minimum of
the statistic *is* the convergence, and a row whose arms both report
"55" gets the mid-p of that tie group, about 0.27. That is the correct
value: it says "half of honest tables look like this", and it cannot be
made smaller, because the printing removed everything finer. (Steve
Shafer: "As n goes to infinity, both arms necessarily converge to the
true population value. If you round, then they will converge to exactly
the same number. There is no unexplained homogeneity in large n,
because convergence is expected.")

**The attainable floor.** Every row has a smallest p its printed
precision allows: the mid-p of the most homogeneous outcome the
simulation can produce — the arms printing exactly the same value —
which is half the share of honest replicates that land there. The
results table marks a row with the note **"attainable floor"** when its
arms agree exactly *and* no honest replicate agreed better. For integer
age in a large trial the floor is high (about 0.27 at 1,000 per arm)
and the note says: this row has said everything its rounding lets it
say, and it cannot alarm however the data were made. For a finely
printed row the floor is small and a row at it alarms; the note then
says: nothing agrees better than this. The floor's value depends on the
printing, the sample size and where the population sits relative to
the grid, never on the data. A row whose arms differ, however slightly,
never carries the note, even when no replicate happened to beat it.

The consequences shape the whole method. A coarsely printed row cannot
carry a finding on its own: a copied integer mean is indistinguishable
from an honestly converged one. Evidence comes from two places — the
accumulation of many rows that each sit at the bottom of their tie
groups, which is what the trial p measures and why its null must be
simulated rather than assumed (next section), and rows printed finely
enough that convergence has not erased the sampling scatter. A test
that ignores rounding reads convergence the wrong way: a t-statistic
computed from tied integer means treats the tie as exact and reports
under-dispersion, so honest large trials alarm. That is why this method
models the rounding rather than the printed number.

**Which way a half rounds.** The simulation rounds with R's `round()`,
which sends an exact half to the even neighbour (2.5 → 2, 3.5 → 4:
banker's rounding). The software that produced most printed tables
(Excel, SPSS, SAS, GraphPad) rounds a half away from zero. The two
differ only when a simulated mean lands exactly on a printed half, which
happens with positive probability when the observations sit on a grid
(N = 20 integer observations printed to one decimal put every other grid
point on a half). Because banker's rounding alternates wide and narrow
printed bins, it makes exact ties slightly likelier: measured
(2026-09-06), the mid-p at a tie is higher than under half-away-from-zero
by 9% in that N = 20 case, 3% for the guide's worked example, 1 to 2% at
N = 40 and 100, and not at all where no exact half is reachable (N = 50
integer observations printed to one decimal). The difference is in the
conservative direction, and the convention a given paper's software used
cannot be read from its table, so banker's rounding is kept as the
standing convention (Steve Shafer's decision, 2026-09-07) and recorded
here so that the discrepancy is not rediscovered as a defect.

## Combining rows into a trial p

The rows' evidence is summed as Stouffer's z-scores, and that sum is
judged against its own simulated null: every replicate of every row is
ranked within its row, given the mid-p its rank implies, floored and
z-scored exactly as the observed row is, and the z's are summed across
rows replicate by replicate. That is legitimate because the rows are
simulated independently. The observed sum is compared with the
simulated sums, ties counting half. The result is a trial p judged at
the same rounding and the same N as the data — not against a normal
table that assumes continuous, uniform row p's — and so one that is
centred where it should be at every rounding and every N (on synthetic
honest trials: 4.8 to 5.8% below 0.05 in every integer cell). It is a
mid-p on a discrete statistic, so it is not exactly uniform and does not
promise exactly 5% below 0.05 for every table. It finds the fabricated
table: identical integer means on three rows give the share of honest
trials whose rows all tie at once, which is the evidence the table
actually holds.

Accumulation across rows is the fraud signal — eight rows each at
p = 0.05, none alarming on its own, combine to about 1.6 × 10⁻⁶ by the
closed form; the simulation, floored at 1/(replicates + 1), reports that
as "<0.0001" with its Monte Carlo interval. And it rests on the rows
being independent: weight and BMI, or a measurement and its
categorised version, repeat some of their evidence, and a summary table
gives no way to recover the correlation, so a table with overlapping
variables understates its trial p — overstates the evidence — by an
amount the reader must judge (ten copies of one row at p = 0.044
combine to "<0.0001" and contain no more evidence than the one). Before
reading a trial p, identify duplicated or derived variables.

The trial p is bounded by what its simulation can resolve: it is
floored at 1/(replicates + 1) like a row, displays "<0.0001" only when
the 97.5% upper bound on the reaching count licenses it, and carries an
exact Clopper–Pearson 95% interval whenever it is below 0.001, built
like a row's (lower end from the strictly-beyond count, upper end from
the at-or-beyond count, so it brackets the mid-p), e.g. "p < 0.0001
(95% Monte Carlo interval 0 to 3.7e-05)". Replicates are shared by the
whole trial, so an alarming trial escalates every row.

## Combining trials into an overall p

When a file holds several trials, the Summary sheet's closing row is
the closed-form Stouffer combination of the trial p's against the normal
table — a different procedure from the within-trial combination, which
is judged against its own simulated null. It treats the trial p's as
continuous and independent; a trial reported as "<0.0001" enters as
0.0001, on the conservative side; trials that could not be computed are
left out and the row says how many combined. This is the step Carlisle
took to reach a single p for the whole body of Fujii's work. Define the
set of trials before looking at their p's: combining only papers already
flagged, or counting several publications of one trial as independent
studies, biases the result.

## Reproducibility, and the seed

A Monte Carlo result is not meant to be identical from run to run. Two
unseeded runs of the same table give p-values that differ, usually on
the scale of their Monte Carlo standard errors, and the interval is
there so that the difference is never a surprise. When identical
numbers are wanted — to reproduce a published screen, to compare two
builds, to show a reviewer exactly what was run — set the seed: in the
app, add `?seed=12345` to the page's address before pressing Analyze (or
start a local copy with `run_app(seed = 12345)`); in the API, send
`seed` with the request. The same normalized table, the same seed and
the same build then give the same numbers on any machine; the log and
the results workbook record the seed, and the API echoes it. The build
matters as much as the seed, because any change to how the simulation
draws changes what a seed produces: record the build commit (the health
endpoint's `commit`, or the workbook's Provenance sheet) beside the
seed. Re-extracting a document through OCR or the AI assist is not part
of that guarantee; the guarantee starts at the normalized table. A seed
makes a number reproducible; it does not make it more precise.

## Reading the results table

| Column | Meaning |
|---|---|
| P | The one-sided p toward homogeneity. "<0.0001" means the 97.5% upper confidence bound clears 0.0001. Text entries ("Only 1 Row", "Quartiles do not increase (Q3 must exceed Q1)", ...) are refusals: the row could not be analyzed, with the reason. |
| 95% Monte Carlo interval | For every row: the exact Clopper–Pearson 95% interval of the row p. For the Summary row: the exact interval of the trial p, shown when P < 0.001. Its coverage is discussed above. |
| Note | "attainable floor" when the arms agree exactly and no honest replicate agreed better (see "Rounding, convergence, and the attainable floor"); for a median row, "quartiles beyond the metalog's skew limit; fitted at the limit" when the printed quartiles imply more skew than a three-term metalog can carry, so the closest feasible one was used. Blank otherwise. |
| Replicates | Simulations this row's final stage used (1,000 for unremarkable trials; up to 100,000 for alarming ones; the same for every row of a trial). |

## What this method assumes, and what it does not measure

- **Eligibility.** A baseline variable measured before allocation in a
  trial that randomized individuals. Covariate-adaptive allocation,
  matching, cluster randomization, or a table restricted to completers
  changes the reference distribution and is not modelled. A variable
  measured after allocation (the duration of surgery, say) is an
  outcome, not a baseline.
- **Independence of variables** within a trial, and of trials across a
  file, as above.
- **The row models**: normal observations for mean/SD rows; a metalog
  for median/IQR rows, re-drawn per replicate from the printed
  quartiles' own sampling uncertainty (measured on honest normal,
  lognormal, uniform and heavy-tailed populations at 10 to 100 per arm
  in [method-history.md](method-history.md)); fixed margins for
  categorical rows.
- **The printed values and the rounding columns are right.** A misread
  digit, a standard error entered as a standard deviation, or an
  observation precision guessed wrongly changes the answer; the app
  infers a missing precision from the printed decimals and says so, and
  that inference should be checked.
- **Counts rebuilt from percentages are a design decision for
  incomplete data, and it errs toward the null.** A table that prints
  only a percentage for a categorical level gives the count exactly
  when the arm has 100 or fewer patients (at one printed decimal, 1,000
  or fewer), because then every count has its own percentage. Above
  that, several counts share a printed percentage, and any single
  choice is a guess about data the page does not hold. Taking the
  middle of the bracket would be the worst guess for this screen: two
  honest arms whose percentages happen to round the same would be
  rebuilt with identical proportions, an agreement the real counts never
  had (by exact enumeration, 38% of honest 5,000-per-arm pairs would
  fall below p = 0.01). So the ambiguous cells of a row are
  split against **each other**: ordered by the proportion their brackets
  imply, the lower half take the bottom of their bracket and the upper
  half the top, and cells whose percentages imply the same proportion
  alternate, so arms printing the same percentage are spread across both
  ends of their bracket rather than all taking one end. The row can look less alike than the truth, never
  more, and its p is conservative. How conservative is worth stating: a
  two-arm row of 5,000 per arm printed as counts 2,500 and 2,500 reads
  p = 0.008, and the same row printed as "50%" and "50%" reads p = 0.68.
  A row that would alarm on printed counts usually will not alarm on
  printed percentages. The app paints such cells orange and states the
  bracket; both API routes name the rows in their response flags. The
  printed counts, if the author supplies them, replace the guess.
- **The Monte Carlo interval** describes the simulation's precision
  under the model. It does not include extraction error, an unsuitable
  randomization model, dependence, or the probability of fraud, and
  more replicates cannot correct those.

## One sentence for the skeptical reader

Every "<" statement this tool prints is licensed by an exact upper
confidence bound on its own simulation, not by a point estimate — the
number reported is the one the simulation supports.

## A second, independent instrument: Barnett's dispersion test

The package also implements the Bayesian test for under- and
over-dispersion published by Adrian Barnett (*F1000Research* 2022,
**11**:783), exported as `barnettTStats()` and `barnettDispersion()`.
It is not a variant of the method above. It is a different instrument,
and the difference is the point of having it.

**What it tests.** Every table row, for every pair of arms, is reduced
to a two-sample t-statistic — categorical rows included, via the normal
approximation to a difference in proportions. Under honest
randomisation those t-statistics follow a t-distribution. The model asks
one question of them: is their *spread* the spread that distribution
predicts? A spike-and-slab prior puts a posterior probability on the
answer, together with a multiplier saying by how much. Arms that are too
alike read as under-dispersion; arms too far apart read as
over-dispersion.

**How that differs from ours.** The method described above asks, one
variable at a time, whether the arm means sit closer together than
random sampling *with the paper's rounding* allows, against a null
simulated for that variable, and combines the variables by Stouffer's
sum judged against its own simulated null. Barnett's reduces every
variable to a t-statistic that takes the printed numbers as exact,
categorical rows included, and asks one question of the whole set: is
their spread the spread a t-distribution predicts? The two differ in
what they take as input (a rounding-aware null versus exact printed
values), in what they test (each variable's homogeneity versus the
dispersion of the collection), and in framework (a simulated one-sided
p versus a posterior under a spike-and-slab prior). When they disagree
about a table, any of those differences can be the reason — rounding is
the one we have documented, with the exclusion rule Barnett's method
needs at the attainable floor — so a disagreement is a prompt to look,
not a diagnosis.

Their agreement should not be over-read either. Both compute from the
same table and both assume the rows are independent — ours in the
simulated sum of independently generated rows, his in treating each
t-statistic as a separate draw. That is a *common-mode* assumption, so
the two agreeing says nothing about whether it holds.

**Why it is quadrature and not MCMC.** For a single trial the model has
exactly two unknowns: a binary switch and one continuous parameter.
Everything else is data. A posterior over one continuous parameter is a
one-dimensional integral, so it is evaluated directly rather than
sampled. That is deterministic, needs no C++ toolchain at run time, and
is more precise than a finite chain — at the 0.95 flag threshold, 1,000
kept draws carry a Monte Carlo standard error near 0.007, which is the
same order as the distance being judged. `tests/testthat/test-dispersion.R`
pins the equivalence against Barnett's own model file run under nimble;
across eight scenarios the worst disagreement was 0.0024 against a
sampler standard error of 0.0018.

**Two limits worth knowing.** A single row yields one t-statistic and
the model needs several, so this is a trial-level test and cannot judge
one variable alone. And it does not model rounding: when the reported
precision is coarse relative to the standard error of the arm mean —
integer-reported means in a large trial, say — the t-statistics
concentrate at zero and honest data reads as under-dispersed. Ours
models the rounding explicitly and is centred under those conditions;
his is not.
