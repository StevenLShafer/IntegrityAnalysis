# Independent statistical audit of IntegrityAnalysis

Date: 2026-09-07. Auditor: GPT-6 (Codex).
Audited commit: `ae81725148bc64e55b842123b66e5f6ff71bcdf5` (`main`).
Disposition: findings await adjudication; this audit changes no application code.

## Scope and evidence

I read `statistics.md`, `method-history.md`, `validation-ledger.md`, the
available previous audit and its disposition, then the engine, validator,
combination function and output consumers. The previous ChatGPT and Gemini
reports themselves are absent from `docs/audits/`; their recorded resolutions
were available. I have not repeated the settled mid-p, staging, sigma-draw,
metalog-skew or rounding-convention findings.

Experiments ran with R 4.5.3, dqrng 0.4.1, Rfast 2.1.5.2, MBESS 4.9.42
and shiny 1.13.0 in the project's renv library. Installed versions match
the lockfile after normalizing R's equivalent hyphen/dot version notation.
All data were synthetic. Evidence and runnable scripts are in
[`evidence-2026-09-07/`](evidence-2026-09-07/README.md).

**Conclusion:** ordinary-path tests pass, but two confirmed defects can
substantially exaggerate evidence: numerical splitting of categorical ties
and confusing a variable named `Summary` with a trial summary. Approximate
percentage conversion also has a large, demonstrated calibration failure.

Priorities: **P1** = address before relying on affected results;
**P2** = correct a narrower defect or qualify an unsupported use;
**P3** = low-impact robustness limitation.

## Findings

### F1 — P1, demonstrated defect: mathematically equal categorical statistics are not treated as ties

**Location:** `R/P_Calc.R:649–650,672–674,715,738–740`.

For three arms, enter category counts `(1,1)`, `(1,1)`, `(1,5)`.
Validation accepts this table. Arm totals are `(2,2,6)` and category
totals `(3,7)`. Exact enumeration gives three minimum-statistic tables:
their first-category counts are `(1,1,1)`, `(1,0,2)` and `(0,1,2)`, with
probabilities 0.20, 0.25 and 0.25. All have Pearson statistic **80/63**.
The intended lower mid-p is therefore **0.35**.

**Run:** the engine's arithmetic gives the first table
`1.2698412698412698`, and the other two `1.26984126984127`.
Strict `<` and `==`, followed by ordinary ranking, split this one tie
group. The limiting implemented mid-p for the first table is 0.10;
the seeded engine returned **0.1065** at 1,000 replicates.

This propagates into the trial calculation. Five distinct independent
variables with these observed counts returned **0.000175**, using
100,000 replicates. Under the documented statistic, the exact trial
mid-p is **0.5 × 0.7⁵ = 0.084035**: every row must occupy its genuine
minimum tie group. This example assumes independent variables; it is
not the previously documented duplicated-variable problem.

**Fix:** use a common, numerically stable tie representation for both
observed and simulated categorical statistics, including replicate ranks.
Use exact arithmetic where feasible or an explicitly bounded numerical
error criterion; do not apply an arbitrary absolute tolerance to all
continuous statistics. Pin these enumerated margins and arm/category
permutations. Fixing only `kEq` leaves the replicate ranks wrong.
R explicitly documents the limitations of floating-point equality in its
[comparison reference](https://stat.ethz.ch/R-manual/R-patched/library/base/html/Comparison.html).

### F2 — P1, demonstrated defect: a variable label changes the overall p-value

**Location:** `R/P_Calc.R:774,834–837`; `R/apiService.R:750–756`;
`R/baselineTable.R:271–295`.

The validator accepts `ROW = "Summary"`. The engine returns that
variable's result and also generates its own row with the same label.
The API and workbook identify trial summaries solely by that text, so
the variable's p enters the across-trial combination as another trial.

**Run:** one trial, one variable, N = 6 per arm, means 77 and 78, SDs 30,
integer precisions, seed 42. Calling `.apiAnalyze()` with label `X`
returns `overallP = 0.0462`; changing only the label to `Summary`
returns **0.008658**. The underlying row and trial calculation remain
0.0462. The workbook follows the same faulty selection by reading;
I did not generate a workbook for this example.

**Fix:** carry a structural row type or explicit per-trial result object;
never identify calculated summaries by user-controlled display text.
Add an API/workbook regression asserting that renaming a variable
cannot change any numerical result or number of combined trials.

### F3 — P1, demonstrated modelling limitation: approximate percentage counts can massively over-flag honest data

**Location:** `R/parseBaselineTableHeuristics.R:695–706`;
`R/P_Calc.R:627–650,672–679`.

The opt-in percentage approximation reconstructs
`round(N × printed_percent / 100)`. The categorical engine then treats
these as exact counts. It does not reproduce percentage printing in its
null simulation. This creates artificial agreement between arms.

**Run and exact calculation:** generate two independent Binomial(5000, 0.5)
counts, print each percentage to an integer, and reconstruct the count.
Exact enumeration of this honest experiment gives **37.56008% below
0.01**, and the same percentage below 0.05, when judged by the exact
count-based mid-p the engine estimates. These are limiting rejection
rates, not an empirical measurement of the staged Monte Carlo algorithm.
Two reconstructed counts of 2500 have exact mid-p **0.007978247**;
the engine returned **0.00781** at 100,000 replicates.

The default unique-count bracket correctly refuses this ambiguous
conversion: `.ppCountFromPct(50, 0, 5000)` returned NA. Approximation
is opt-in and already labelled; the new finding is its measured
statistical consequence, not an undisclosed default.

**Fix:** exclude ambiguous reconstructed counts from inferential
combinations until original counts are supplied, or develop and calibrate
a null that reproduces percentage rounding and count reconstruction.
Preserve the uncertainty metadata through analysis. Checking the
approximation against the same rounded percentage cannot recover the
missing information.

### F4 — P2, demonstrated defect and model gap: coarse quartiles can reject valid samples

**Location:** `R/validateData.R:561–563`;
`R/P_Calc.R:408–414,458–461`.

The validator tests the printed numbers' order without allowing different
printing intervals. Actual observations
`4.50, 4.80, 4.99, 5.60, 6.00` have type-7 quartiles 4.80 and 5.60,
and median 4.99. Printing quartiles as integers gives **5, 4.99, 6**.
These are accurate printed summaries, but the validator marks them
incongruent because 5 > 4.99.

**Run:** this explicit sample, paired with a second valid five-subject
sample, was refused. In 400 independent synthetic two-arm normal trials
(N = 30, population mean 5, SD 0.5, observations and medians at two
decimals, quartiles at zero decimals), **391 were refused by validation**.
This is distinct
from the previously fixed metalog-skew refusal.

For accepted data, the bootstrap always prints quartiles using
`ROUND_MEAN`, not a quartile-specific precision. Changing
`ROUND_DISPERSION` from 0 to 2 in the recorded example left the entire
output identical. The current method history explicitly describes using
the median precision; that implementation is faithful to that restricted
model, but cannot represent unequal quartile printing.

**Fix:** represent quartile precision explicitly, validate whether ordered
underlying quantiles can exist within the printed intervals, and handle
their uncertainty in fitting/resampling. Distinguish insufficient
quartile resolution from genuinely inconsistent data. Do not merely
relax the order check and pass a zero/negative fitted IQR onward.

### F5 — P2, demonstrated defect: a blank direct-call SD precision discards supplied precisions

**Location:** `R/P_Calc.R:112–117,307–311`;
`R/validateData.R:644–652`.

`.iaSdInterval()` uses supplied precision only if **every** arm has one.
Otherwise it re-infers **every** arm independently. Thus
`SD = c(1,1.1)`, `ROUND_DISPERSION = c(2,NA)` yields intervals
**[0.5,1.5]** and [1.05,1.15]; the explicit first-arm interval should be
**[0.995,1.005]**. Missing-column inference also differs from the
validator's across-arm maximum rule.

**Run:** the helper demonstrated the interval error. With N = 30,
tied means 2.3, mean/observation precision 1 and seed 42, direct analysis
returned 0.07045; validation followed by analysis returned 0.07225.
The interval construction, not that small stochastic difference, proves
the defect. Normal app/API calls already fill these blanks correctly.

**Fix:** fill missing SD precisions per cell, preserving supplied values,
and share the validator's group inference with direct calls. Test mixed
explicit/missing values and mixed inferred decimal lengths.

### F6 — P2, demonstrated sensitivity limitation: fabrication confined to arm dispersions is invisible

**Location:** `R/P_Calc.R:505–507,546–555,567`.

Arm SDs enter principally through their pooled variance; their disagreement
is not itself a tested statistic. **Run:** N = 100 per arm, means 50 and
52, mean/observation precision 2, dispersion precision 15, seed 42.
Replacing SDs `(10,10)` by **`(0,sqrt(200))`** left the reported p
identical at **0.8365**. Both frames passed validation. Their pooled
variance is identical, despite a radical change in the arm dispersions.

This is not a request to reverse the homogeneity tail: it demonstrates
a separate unexamined feature of the table. Synthetic data generated
from the assumed null can also evade a screen based solely on these
summaries. No general sensitivity claim follows from null calibration.

**Recommendation:** state explicitly that dispersion fabrication is
outside the screen's detection target. If needed, evaluate a separate,
rounding-aware dispersion-consistency check with its own calibration;
do not silently add its evidence to this combination.

### F7 — P3, demonstrated numerical limitation: accepted values can exceed useful floating-point resolution

**Location:** `R/validateData.R:282,394–399`;
`R/P_Calc.R:488,577,594`.

**Run:** N = `(100,101)`, identical means, SD = 10⁻⁶, mean/observation
precision 20, dispersion precision 6. At means zero the result reaches
the 1,000-replicate floor (0.000999); translating both means to 10¹¹
gives **0.5**. Both inputs pass validation. At that location, binary64
cannot represent the simulated fluctuations, so the draws collapse.

This is an extreme-scale example, not a demonstrated ordinary clinical
failure. **Fix:** detect incompatible location/spread/grid resolutions
and refuse with a numerical-resolution explanation, or simulate centered
contrasts while preserving the rounding grid's origin. A magnitude cap
and independent decimal cap do not ensure joint numerical adequacy.

## Additional calibration and clean checks

Exploratory independent-null runs used **400 trials per cell and a fixed
1,000-replicate ceiling**, not production staging:

| Scenario | Computed | p < 0.05 | p < 0.01 | Mean p |
|---|---:|---:|---:|---:|
| Bounded Beta(½,½), median/IQR, N = 30, all printing at 2 decimals | 400 | 3.25% | 0% | 0.560 |
| Normal mean/SD, six arms with N = 3/5/10/30/100/300, 4 decimals | 400 | 7.25% | 1.5% | 0.487 |

The 95% binomial intervals for the 5% rates are **1.74–5.49%** and
**4.91–10.25%**. Neither establishes a 5%-level calibration defect.
The bounded cell's non-uniform body reinforces the stated model
limitation; neither experiment certifies universal calibration or power.

Verified clean by reading: degrees-of-freedom pooling, sigma draw,
direct-draw eligibility and grid order, median coefficient algebra,
categorical fixed margins/lower-tail direction, stated staging, floors,
and conservative substitution of `<0.0001` across trials. The use of
fixed-margin tables agrees with the
[R reference](https://stat.ethz.ch/R-manual/R-patched/library/stats/html/r2dtable.html).

Verified by running: all eight selected statistical/input test files
passed, including every known-answer pin; exhaustive 2×2 searches with
arm totals 2–20 found no numerical tie split; 18 fully converged
continuous configurations returned 0.5; 27 finite numerical edge cases
produced no exception (with F7's qualification).

I did not rerun confidential corpora, the full repository suite,
production deployment, cross-platform reproducibility, or a dependence
experiment already covered by the previous audit. Application code
remains unchanged; fixes above are recommendations, not verified patches.
