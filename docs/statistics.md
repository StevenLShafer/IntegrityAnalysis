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

The per-variable p-values combine across the trial with Stouffer's
method into a single trial p.

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
   3.7 × 10⁻⁵, comfortably below. Rows with p < 0.001 also show the
   bound explicitly ("<=4.6e-05"), and every row reports how many
   replicates it used.
4. **The trial p is not floored.** Combining rows is exact arithmetic —
   no simulation noise is added — and accumulation across rows is the
   fraud signal: eight individually unremarkable rows at p = 0.01
   legitimately combine to about 5 × 10⁻⁹. What the trial p inherits is
   the rows' simulation uncertainty, which is propagated (parametric
   bootstrap over the rows' binomial counts) and shown as a 95% Monte
   Carlo interval whenever the trial p < 0.001, e.g.
   "p = 3.1e-07 (95% Monte Carlo interval 1.2e-07 to 8.9e-07)".

## Reading the results table

| Column | Meaning |
|---|---|
| P | The one-sided p toward homogeneity. "<0.0001" means the 97.5% upper confidence bound clears 0.0001. Text entries ("Only 1 Row", "Quartiles too skewed to simulate", ...) are refusals: the row could not be analyzed, with the reason. |
| 95% Monte Carlo bound | For rows: the upper confidence bound, shown when P < 0.001. For the Summary row: the 95% bootstrap interval of the trial p. |
| Replicates | Simulations this row actually used (1,000 for unremarkable rows; up to 100,000 for alarming ones). |

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
models the rounding explicitly and fails the other way, becoming
conservative instead. Neither is uniform under those conditions.
