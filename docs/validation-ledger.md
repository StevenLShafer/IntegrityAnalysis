# Validation ledger

One row per measurement of the engine against Carlisle's 2017 corpus
(the *Anaesthesia* 2017 data — the paper's 5,087 trials, of which 5,080
join, by journal and trial number, from the raw rows of "One Sheet
Carlisle Data.xlsx" to his stored per-trial p-values; the join is
`corpus/validateCarlisle2017.R`'s, and the files are working data, never
committed). Every
figure quoted anywhere in this repository should trace to a row here.
Agreement with Carlisle is agreement with a comparator computed from the
same tables, not a measurement of the false-alarm rate or of sensitivity
to fabrication; the honest-null and synthetic experiments that measure
those live in `docs/statistics.md` and beside the corpus tooling.

Each row is a measurement of the build it names, on the date and at the
replicate ceiling it records; no row is a statement about the current
engine. The statistical changes since the 6 September 2026 rows — the
numerical trial p entering the across-trial combination (issue 78), the
null-law key without SE (issue 167), the stated-grid tolerance (issue
168) — are measured by the two 2026-09-26 rows at 53aa576, at the
10,000 and the 100,000 ceilings, which agree to three decimals. (The app's
wall-clock ceiling and draw budget, issues 165 and 166, change no p.)
Those rows also record a change of population: the arm cap of
2026-09-09 refuses the 63 mega-trials the August pilot scored, so n is
5,014 scored, not 5,080; the two later 2026-09-26 rows admit them again by the
local override of issue 174 (the public cap stays, by Steve's decision).

**Where the two methods part.** Agreement with Carlisle's p is weakest
where a mean's reporting unit exceeds the standard error of the arm
difference, which is where the two methods treat rounding differently:
this engine draws each printed value from the interval its precision
stands for and judges ties by an exact null (the rounding sections of
`statistics.md`; the tie experiment of 2026-09-03), where the 2017
method did not. Across the 5,077 scored trials of the all-arms run,
grouped by the share of a trial's continuous variables whose reporting
unit exceeds that standard error (the pooled SD times √(1/n₁ + 1/n₂) of
its two largest arms), agreement falls steadily with the share:

| share of coarse-unit variables | trials | r | median \|Δp\| | within 0.05 | alarm concordance at 0.05 |
|---|---|---|---|---|---|
| none | 3,785 | 0.9929 | 0.0122 | 93.2% | 98.7% |
| up to 25% | 769 | 0.9817 | 0.0204 | 79.1% | 97.0% |
| 26–50% | 378 | 0.9791 | 0.0298 | 70.1% | 95.5% |
| 51–75% | 78 | 0.9712 | 0.0398 | 57.7% | 96.2% |
| above 75% | 67 | 0.9673 | 0.0313 | 58.2% | 100% (67 trials with very few alarms; it says little) |

and, by the largest arm, near-steadily (the two smallest bins are level
at 91% within 0.05 and the second has the higher r; the fall begins
above 100 per arm), with the bin's mean coarse-unit share rising
alongside:

| largest arm | trials | r | median \|Δp\| | within 0.05 | alarm concordance at 0.05 | mean coarse-unit share |
|---|---|---|---|---|---|---|
| 50 or fewer | 3,159 | 0.9906 | 0.0129 | 91.3% | 98.5% | 0.04 |
| 51–100 | 666 | 0.9943 | 0.0129 | 91.6% | 98.2% | 0.07 |
| 101–500 | 809 | 0.9840 | 0.0176 | 82.6% | 97.5% | 0.12 |
| 501–1,000 | 199 | 0.9860 | 0.0197 | 80.9% | 98.5% | 0.22 |
| 1,001–5,000 | 181 | 0.9788 | 0.0262 | 68.5% | 96.1% | 0.30 |
| above 5,000 | 63 | 0.9635 | 0.0304 | 58.7% | 95.2% | 0.38 |

Both tables sum to the 5,077 scored trials. In that regime the engine's p is usually the larger (NEJM 864
0.58 against 0.21; NEJM 913 0.49 against 0.23; NEJM 204 0.34 against
0.16), occasionally the smaller (JAMA 198, twelve variables at 19,541
and 29,294 per arm: 0.0077 against 0.066). Which treatment is right is a
methods question, not a defect of either run; the tables are in the
run's workbook, sheet "Rounding gradient".

| Date | Engine (commit / PR) | Trials compared | Replicate ceiling | r vs Carlisle | median \|Δp\| | within 0.05 | alarm concordance (p < 0.05 both ways) | Notes |
|---|---|---|---|---|---|---|---|---|
| 2026-08-17 | mid-p build (PR #8) | 5,080 | 100,000 | 0.991 | 0.0095 | 92% | 97.4% | first full run after mid-p adopted; per-row early stop |
| 2026-08-21 | shipped engine (issue 3 runner, `corpus/validateCarlisle2017.R`) | 5,080 | 100,000 | 0.9930 | 0.0127 | 90.3% | 99.0% | the "citable" run of ISSUES.md; 121 outliers unadjudicated |
| 2026-09-04 | exact combination (#170, c31bb51) | 5,030 usable | 100,000 for 3,725, then 10,000 | 0.9917 | — | — | 98.3% | per-trial staging; alarms 348 → 392; median \|Δp\| against the PREVIOUS ENGINE (not Carlisle) 0.0135 |
| 2026-09-05 | main + zero-SD fix (e9b710f + #182) | 5,011 usable | 10,000 | 0.9922 | 0.0160 | 88.0% | 98.6% | baseline for the SD decision; the 0.1 escalation rule |
| 2026-09-05 | pooled SD, N − k (#183) | 5,011 usable | 10,000 | 0.9925 | 0.0150 | 88.5% | 98.5% | median \|Δp\| vs baseline 0.007 |
| 2026-09-06 | sigma draw (#185, from merged main) | 5,041 usable | 10,000 | 0.9929 | 0.0142 | 89.1% | 98.5% | median \|Δp\| vs pooled 0.009, confined to ≤ 30 per arm; **the citable row** |
| 2026-09-06 | sigma-draw engine, location-scale pair (recorded in #193) | 5,041 usable | 10,000 | 0.9931 / 0.9932 | — | 89.3% / 89.9% | 98.5% either way | a PAIRED RE-RUN of the row above, not a new engine: the replicate's common location drawn at σ/√(mean N) (as shipped) vs σ/√ΣN, identical data and seeds; 419 vs 420 alarms, 7 crossing each way; median change 0.0000–0.0007 by arm size, no direction. The 0.9931 differs from the row above's 0.9929 only because it is a fresh run. Data: `C:/dev/Corpus/synthetic/location-scale/` |
| 2026-09-06 | SD rounding draw (feature/sd-rounding-draw, from 166dc5b) | 5,041 usable | 10,000 | 0.9932 | 0.0138 | 89.2% | 98.5% | vs the sigma-draw run: median \|Δp\| 0.0077, r 0.9982, alarms 420 → 418 (5 down, 7 up), no direction by arm size; data `C:/dev/Corpus/synthetic/sd-round/` |
| 2026-09-26 | release build after the fifth audit's numerical fixes (53aa576: #483 null-law key without SE, #484 stated-grid tolerance, #486 app draw budget) | 4,976 usable of 5,014 scored | 10,000 | 0.9916 (Spearman 0.9916) | 0.0141 | 88.9% | 98.2% at 0.05 (his 356 alarms, ours 405); 99.1% at 0.01 (111, 139) | seed 42 re-set per trial; run by the corpus session's `_tools/carlisle2017_compare.R`, John's One Sheet cells through validateData → P_Calc, his stored one-sided p joined with the A&A numbering offset; 66 of 5,080 not scored: 63 refused `too_large` (an arm above `.iaMaxArmN` = 5,000, the mega-trials, which the August pilot scored before the 2026-09-09 cap), 3 `incongruent`; 38 scored trials with his p exactly 1 dropped as usable-rule; 34 with his p in [0.9999, 1) stay in. On all 5,014 scored: r 0.9894, Spearman 0.9891, same medians and concordances. 39.7% within 0.01. Summary workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_53aa576_m1e4_summary.xlsx`. The difference from the 6 September rows combines the engine's changes since then with the 63 mega-trials now refused; the ceiling contributes nothing measurable (next row) |
| 2026-09-26 | the same release build, 53aa576 | 4,976 usable of 5,014 scored | 100,000 | 0.9916 (Spearman 0.9916) | 0.0141 | 88.8% | 98.2% at 0.05 (his 356, ours 406); 99.0% at 0.01 (111, 139) | seed 42 re-set per trial, same runner and join as the row above; the 10,000-ceiling figures to three decimals, with the same twelve largest differences at the same p's, so the replicate ceiling contributes nothing measurable to the agreement with Carlisle. On all 5,014 scored: r 0.9894, Spearman 0.9891. 39.9% within 0.01. Workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_53aa576_m1e5_summary.xlsx` |
| 2026-09-26 | the release build with the arm cap raised for the run (4c5bcc5, whose R/ is identical to 89bc836; `INTEGRITY_MAX_ARM_N=1000000`, issue 174) | 5,038 usable of 5,077 scored | 10,000 | 0.9913 (Spearman 0.9913) | 0.0142 | 88.5% | 98.2% at 0.05 (his 358 alarms, ours 410); 99.0% at 0.01 (111, 142) | Steve's request: the 63 mega-trials (arms 5,006 to 34,644; 41 NEJM, 22 JAMA) admitted; only the 3 incongruent trials refused. On all 5,077 scored: r 0.9891, Spearman 0.9888, 88.3% within 0.05, 39.6% within 0.01. Admitting the mega-trials moves the corpus figures by 0.0003 in r and 0.4 points within 0.05 against the 53aa576 rows. Seed 42 per trial, same runner; workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_4c5bcc5_m1e4_allarms_summary.xlsx` |
| 2026-09-26 | the 63 mega-trials alone, same run | 63 | 10,000 (and 100,000: the same p to four decimals) | 0.9635 | 0.0304 | 58.7% | 95.2% at 0.05 (his 2 alarms, ours 5) | the weaker agreement is not Monte Carlo noise (rescoring at 100,000 reproduces every p to four decimals in under a second each); it is the rounding gradient described below the table. Example: NEJM 864 (PMID 25014686), arms 12,838 and 12,835, age 64.9 vs 64.9 with SD 7.5 - the SE of the arm difference is 0.09 against a reporting unit of 0.1, the engine's rows sit at their attainable floor and the trial reads 0.58 against Carlisle's 0.21 |

### A single published trial, computed by the method's own authors

The table above is agreement in aggregate. This entry ties the engine to **one
published Monte Carlo p computed by the people who defined the method** —
the worked example of Carlisle, Dexter, Pandit, Shafer & Yentis, *Anaesthesia*
2015;70:848–858, whose Table 1 prints the complete baseline table of Fujii et
al., *Anesth Analg* 2001;92:1590–3 (PMID 11375852, retracted; reference 10 of
the 2015 paper), and whose text gives its result: **p = 1.2 × 10⁻⁶**.

| Date | Engine | Input | Replicate ceiling | Result | Notes |
|---|---|---|---|---|---|
| 2026-09-24 | issue-34 branch (from e16e185) | Carlisle's 27 rows as printed: 9 variables × 3 arms, n = 8 | 100,000 | **`<0.0001`** on seeds 42, 7, 2026; escalated to the ceiling on every seed | the display floor at that ceiling; 1.2 × 10⁻⁶ lies below it, so this is agreement at the resolution the app has, not a reproduction of the value. Pinned by `tests/testthat/test-fujii-11375852-engine.R`, which also checks that perturbing the means by one SD lifts the trial off the floor |
| 2026-09-24 | same | the article's Table 1 parsed by the deterministic engine: 6 variables × 3 arms, N = 8 from the Methods, no after-dose value | 100,000 | **1.2 × 10⁻⁴** | six variables, not nine: the published figure includes Table 2's two Stimulation variables and the after-dose RAP that the 2015 table lists as "RAP(2)". The engine reads one table. Checked by `corpus/checkFujii11375852.R` (skips when the article is absent) |

"Usable" excludes the trials where Carlisle's stored p is exactly 1 (a
z = +∞ artifact of his closed-form combination, 39 trials) and any
trial one run could not join — so 5,041 (5,080 − 39) is the most a run
can reach. "Within 0.05" is the share of trials whose
p lies within 0.05 of his. The runs from 2026-09-05 used
`INTEGRITY_MMAX=10000` for the reasons recorded in the runner (the
2026-09-04 run switched to it after its first 3,725 trials); the two
ceilings agree wherever a row stops before the third stage, but a row
that escalates to 100,000 replicates is re-estimated on a fresh batch,
so the ceiling changes p's near and below 10⁻³ as well as the floor
(the same seed reads 0.00015 at 10,000 and 0.000195 at 100,000 on the
2026-09-26 audit's equal-summaries fixture), not only values below
10⁻⁴. Delta files and per-trial
results: `C:/dev/Corpus/synthetic/sd-null/`,
`C:/dev/Corpus/synthetic/exact/` and
`C:/dev/Corpus/synthetic/location-scale/` (off the repository).

Before the first row: the mid-p pilot of 2026-08-16 (the scripts lived
only in a session scratchpad; `corpus/validateCarlisle2017.R` was written
2026-08-21 to make the validation reproducible) measured r 0.995 on the
pilot subset of trials with the mid-p, where counting every tie in full
had put the median absolute difference from Carlisle's values at 0.076.
It is quoted in `docs/method-history.md`; it is not a full-corpus run
and is not comparable row for row with the table.

**The engine has changed since the last row, and the rows still stand.**
The zero floor was repaired on 2026-09-09 (independent audit F6): each
simulated replicate is now translated by its own first arm, so arms that
drew the same value give a structurally exact zero instead of dust a
tolerance had to forgive. The effect is confined to printed precisions
of about eleven decimals and finer — below that the tolerance already sat
far above the floating-point dust — and no row of the Carlisle corpus
states a precision anywhere near it, so no figure in the table above
moves. Said here rather than left to be inferred, because a ledger whose
last row predates the engine is exactly the thing a reader cannot check
for themselves. The same holds for the percentage reconstruction rewritten
on 2026-09-08 and 09: it changes which COUNTS a document yields, not how a
given table is scored, and the corpus is supplied as counts.

Not on this ledger, because they measure something else: the parser's
yield (`corpus/README.md`), the 61-article end-to-end comparison
(`corpus/validateEndToEnd.R`; a set selected for successful parsing), the
honest-null rejection rates and the direct-draw and sigma-draw
experiments (`docs/statistics.md`).
