# How IntegrityAnalysis computes and reports its p-value

Provenance: written by Claude Code (model Claude Fable 5), 2026-08-17,
with the adaptive-replicates implementation; the scheme is Steve Shafer's
decision following the replicate-count analysis (independently convergent
with a Gemini analysis he commissioned). This is the user-facing
explanation; it will fold into the full documentation rewrite (issue 14).

## What the p-value means

For every baseline variable (each ROW of the table), IntegrityAnalysis
asks one question: **if the arms really were random samples from a single
population, how often would their printed summaries agree this well?**
The answer is a one-sided p-value toward *excessive homogeneity*:

- **Small p** = the arms are more alike than random sampling explains —
  the demonstrated fraud signal (it is how Fujii's fabricated trials were
  caught).
- Large p = nothing remarkable. Excessive *heterogeneity* is deliberately
  not reported: it is not a known fabrication signal, and reporting it
  invites false accusations against merely-variable data.

The per-variable p-values combine across the trial into a single trial
p by the **exact combination** described below (a correction made on
2026-09-04; the section "A correction to the combination step" says
what was wrong and what changed).

## Where the numbers come from, and why they carry uncertainty

Each row's p is estimated by simulation: the app draws many replicate
trials under the random-sampling hypothesis, rounds the simulated
summaries exactly as the paper rounded its own, and counts how often the
simulated arms agree at least as well as the printed ones (ties count
half — the "mid-p" convention, which reproduces Carlisle's published
2017 values, r = 0.991 over 5,080 trials).

A simulated p-value is itself an estimate. If 0 of 1,000 replicates
agree as well as the printed data, the true p could still plausibly be
0.003 — so reporting "p < 0.001" from 1,000 replicates overstates the
evidence. IntegrityAnalysis is a screening tool whose verdicts may be
challenged, so it reports only what the simulation actually supports.

## The adaptive scheme

1. **Staged replicates.** Every row starts with 1,000 replicates. If its
   running p is ≥ 0.01, the simulation stops — extra precision on an
   unremarkable p changes nothing. Otherwise it escalates to 10,000, and
   if still < 0.01, to 100,000. Computation concentrates exactly on the
   rows where precision matters.
2. **No literal zeros.** A row where *no* replicate matched is floored at
   1/(replicates + 1) (Davison & Hinkley) — the smallest value the
   simulation can honestly claim.
3. **"< 0.0001" is a confidence statement, not an estimate.** A row
   displays "<0.0001" only when the one-sided 97.5% upper confidence
   bound (exact Clopper–Pearson, ties counted fully — conservative) on
   its simulated count clears 0.0001. At zero exceedances this needs
   roughly 30,000+ replicates; at 100,000 replicates the bound is
   3.7 × 10⁻⁵, comfortably below. Every row also shows its exact
   Clopper–Pearson 95% Monte Carlo interval ("0.27 to 0.33" for an
   unremarkable row at 1,000 replicates; "0 to 3.7e-05" for a row with
   nothing at or below at 100,000), and how many replicates it used.
   The interval is the simulation's uncertainty about the row's p, not
   uncertainty about the trial's data; its lower end comes from the
   strictly-below count and its upper end from the at-or-below count,
   so it brackets the mid-p and errs wide.
4. **The trial p is the exact combination.** The rows' evidence is
   summed as Stouffer's z-scores, and that sum is judged against its own
   simulated null: every replicate of every row is ranked within its
   row, z-scored and summed across rows, replicate by replicate, and the
   trial p is the share of those simulated honest sums that reach the
   observed one (ties half). Accumulation across rows is still the fraud
   signal — eight individually unremarkable rows at p = 0.01 still
   combine to a very small trial p — but the trial p is now bounded by
   what its simulation can resolve: it is floored at 1/(replicates + 1)
   like a row, displays "<0.0001" only when the 97.5% upper bound on the
   reaching count licenses it, and carries an exact Clopper–Pearson 95%
   interval whenever it is below 0.001, e.g. "p < 0.0001 (95% Monte
   Carlo interval 0 to 3.7e-05)". The staging is per trial: every usable
   row draws the same number of replicates at each stage, and the trial
   escalates while its own p or any row's is below 0.01.

## Reading the results table

| Column | Meaning |
|---|---|
| P | The one-sided p toward homogeneity. "<0.0001" means the 97.5% upper confidence bound clears 0.0001. Text entries ("Only 1 Row", "Quartiles too skewed to simulate", ...) are refusals: the row could not be analyzed, with the reason. |
| 95% Monte Carlo interval | For every row: the exact Clopper–Pearson 95% interval of the row p. For the Summary row: the exact interval of the trial p, shown when P < 0.001. |
| Note | "attainable floor" when the row sits at the smallest p its printed precision allows (no honest replicate agrees better than the printed arms). See "Convergence under rounding". Blank otherwise. |
| Replicates | Simulations this row actually used (1,000 for unremarkable rows; up to 100,000 for alarming ones). |

## Convergence under rounding: why a large trial's rows agree, and why that is not evidence

Under honest randomization the arm means are estimates of one
population mean, and as the arms grow they converge on it: the standard
error of an arm mean falls like 1/√N. Once that standard error is
smaller than the printed precision, the arms will often print the same
number. At 1,000 per arm with SD 13, the standard error is 0.4; reported
as integers, the two means agree about half the time. Identical rounded
means in a large trial are the expected outcome of convergence, not an
anomaly.

The row simulation reproduces this exactly, because it rounds its
replicates as the paper rounded its own. Its tie mass at the minimum of
the statistic *is* the convergence, and a row whose arms both report
"55" gets the mid-p of that tie group, about 0.27. That is the correct
value: it says "half of honest tables look like this", and it cannot be
made smaller, because the printing removed everything finer. There is
no unexplained homogeneity in such a row, and the method reports none.
(Steve Shafer, 2026-09-04: "As n goes to infinity, both arms
necessarily converge to the true population value. If you round, then
they will converge to exactly the same number. There is no unexplained
homogeneity in large n, because convergence is expected.")

**The attainable floor.** Every row has a smallest p its printed
precision allows: the mid-p of the most homogeneous outcome the
simulation can produce — both arms printing the same value — which is
half the share of honest replicates that land there. The results table
marks a row that sits at that floor with the note **"attainable
floor"**. For integer age in a large trial the floor is high (about
0.27 at 1,000 per arm) and the note says: this row has said everything
its rounding lets it say, and it cannot alarm however the data were
made. For a finely printed row the floor is small and a row at it
alarms; the note then says: nothing agrees better than this, and this
is as low as the row can go. The floor is a property of the printing
and the sample size, not of the data.

**How this trap was found, twice.** Carlisle's original method used
normal theory for the comparison of arm means. Under normal theory two
random samples never agree exactly, so a row whose arms reported
identical means had p = 0, and Fujii's tables looked statistically
impossible on rows that were merely rounded. Steve Shafer replaced the
normal theory with the Monte Carlo simulation described above, which
rounds its replicates as the paper rounded its own and so gives
identical rounded means the probability they actually have. The
combination step corrected on 2026-09-04 was the same trap one level
up: the closed-form Stouffer sum assumed each row p uniform, which
identical-rounded-means rows are not. Barnett's dispersion test, which
computes t-statistics from the printed means as if they were exact,
falls into the original trap: tied integer means read as
under-dispersion.

The consequences shape the whole method. A coarsely printed row cannot
convict on its own: a copied integer mean is indistinguishable from an
honestly converged one. Evidence therefore comes from two places — the
accumulation of many rows that each sit at the bottom of their tie
groups, which is what the trial p measures and why its combination must
be exact (next section), and rows printed finely enough that
convergence has not erased the sampling scatter. And a test that
ignores rounding reads convergence the wrong way: a t-statistic
computed from tied integer means treats the tie as exact and reports
under-dispersion, so honest large trials alarm. That is the failure
measured for Barnett's test in the synthetic sweeps, and the reason
this method models the rounding rather than the printed number.

## A correction to the combination step (2026-09-04)

**What was wrong.** Until 2026-09-04 the trial p was Stouffer's
closed-form combination: each row's simulated p was converted to a
normal score, the scores were summed, and the sum was read off the
normal distribution. That closed form assumes each row's p is uniformly
distributed when the trial is honest. It is not, whenever the reported
means are rounded coarsely relative to their standard error — integer
means with hundreds of patients per arm, say. A row like that has only
a handful of possible values of its statistic, so its simulated p is
discrete (a row whose two arms both report "55" has a mid-p near 0.27
however honest it is), and the sum of a few such p's was being read off
a smooth table it does not follow. Measured on synthetic honest trials
(`corpus/syntheticTiesCheck.R`): at integer means and 1,000 per arm,
1.4 % of honest trials fell below p = 0.05 instead of 5 %, the lowest
decile of trial p's was 43 % under-filled, and a fabricated table with
identical integer means on every row could not reach p = 0.01 however
many rows agreed. The screen failed in the safe direction — it accused
no one — but it was miscalibrated, and it was blind to a fabrication it
should have seen. The error was in the Monte Carlo's combination step,
which Steve Shafer wrote; it is not part of Carlisle's method, and none
of Carlisle's published values depend on it.

**What changed.** Nothing about the rows. The row statistic, its
rounding-faithful simulation, the mid-p and the bound rules are exactly
as before, and the row p's shown in the grid are unchanged in kind. The
only change is how the rows are combined. The statistic is still
Stouffer's sum of row z-scores. Its null distribution is no longer
assumed normal; it is taken from the same simulations that produce the
row p's. Each simulated replicate of each row is ranked within its row,
given the mid-p its own rank implies, floored and z-scored exactly as
the observed row is, and the z's are summed across rows replicate by
replicate. That is legitimate because the rows are simulated
independently. The observed sum is then compared with the simulated
sums, ties counting half. The result is a trial p that is uniform under
honest sampling by construction, at every rounding and every N (on the
same synthetic trials: 4.8 to 5.8 % below 0.05 in every integer cell),
and that finds the fabricated table: identical integer means on three
rows now give the share of honest trials whose rows all tie at once,
which is the evidence the table actually holds.

**What it costs.** The trial p can no longer be resolved below
1/(replicates + 1): a trial whose observed sum exceeds every one of
100,000 simulated sums reports "<0.0001" with the interval "0 to
3.7e-05", where the closed form used to print a number like 3 × 10⁻⁹.
That number was never resolvable by the simulation; the new report says
what the simulation supports and no more. Replicates are shared by the
whole trial, so an alarming trial escalates every row rather than only
the alarming ones, which is why the `Replicates` column now shows the
same count on every row of a trial.

**Revalidated against Carlisle 2017 (2026-09-04).** The 5,080 trials of
the 2017 analysis were rerun on the corrected engine. Against Carlisle's
stored trial p-values the agreement is essentially unchanged (r 0.993
before, 0.992 after; alarm concordance at p < 0.05 99.0 % before,
98.3 % after; his values were computed with the same closed-form
combination this correction replaced). Against the previous engine the
typical trial moved by about one hundredth (median |change| 0.013;
r = 0.997), the number of trials below p = 0.05 rose from 348 to 392,
and the largest shifts were in the largest trials (over 300 per arm),
where rounded rows converge and carry the least information each. That
is the intended effect: the trial p now reflects the amount of
information in each row, and for a rounded row that amount falls as N
grows, because convergence takes the arms below what rounded numbers
can distinguish.

**Ideas that were tested and rejected**, so that nobody repeats them:
ignoring ties (placing the observed statistic at the floor of its tie
group) gave 10 to 43 % false alarms at integer rounding; placing it at
the chi-square median of its tie group reproduced the old numbers
exactly, because any rule that assigns one number to each reported
pattern leaves the distribution as lumpy as it found it; a
log-likelihood-ratio combination against a stated fabrication model was
calibrated but sees only the alternative it was built for. The exact
combination needs no alternative and was never worse than the better of
those on that alternative's own ground.

## One sentence for the skeptical reader

Every "<" statement this tool prints is licensed by an exact upper
confidence bound on its own simulation, not by a point estimate — the
number reported is the one the tool is prepared to defend.

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

**How that differs from ours.** The method described above tests the
*shape* of a whole distribution. Barnett's tests *one moment* of it.
That distinction matters because a shape test fires on skew, on
categorical data and on rounding, none of which is misconduct, while a
variance test largely does not. So the two disagreeing about the same
table is diagnostic rather than embarrassing: it localises the anomaly
to the shape of the distribution rather than the spread of the data.

Their agreement should not be over-read either. Both compute from the
same table and both assume the rows are independent — ours in the
`sqrt(k)` denominator of Stouffer's combination, his in treating each
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
models the rounding explicitly, and until 2026-09-04 failed the other
way at the combination step, becoming conservative (see the correction
above); with the exact combination it is uniform under those conditions,
and his is not.
