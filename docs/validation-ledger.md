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

**Where agreement is weakest.** In this comparator run, agreement with
Carlisle's stored trial p-values is weaker when more of a trial's
continuous variables have a coarse reporting unit relative to the
standard error of an arm difference. An earlier version of this
paragraph explained that as "the two methods treat rounding
differently: this engine draws each printed value from its interval,
the 2017 method did not"; the follow-up statistical audit of 2026-09-27
showed both halves wrong, and the explanation is withdrawn. Carlisle's
2017 Methods adjust the Monte Carlo "for the precision to which mean
(SD) were reported", take the per-variable result nearest 0.5 and
combine by Stouffer, and the 2015 method paper defines the half-tie
mid-p; this engine rounds each *simulated* arm mean to the printed
precision and draws the SD from its interval while the observed printed
means stay as the statistic, and judges the trial against the simulated
null of the summed z-scores. Both procedures account for reporting
precision; their input declarations, row calculations and within-trial
combination need not coincide, and which of those produces the gradient
is not identified. What follows is the association in the all-arms run
of 2026-09-26 with the precision INFERRED from the printed digits (the
runner then discarded the workbook's declarations; the declared-precision
rerun is described after it), across its 5,077 scored trials, grouped by
the share of a trial's
continuous variables whose reporting unit exceeds that standard error
(the pooled SD times √(1/n₁ + 1/n₂) of its two largest arms, with the
largest arm's declared DECM). The correlation falls steadily with the
share; the median difference and the share within 0.05 do not, quite,
in the last bin:

| share of coarse-unit variables | trials | r | median \|Δp\| | within 0.05 | alarm concordance at 0.05 |
|---|---|---|---|---|---|
| none | 3,785 | 0.9929 | 0.0122 | 93.2% | 98.7% |
| up to 25% | 769 | 0.9817 | 0.0204 | 79.1% | 97.0% |
| 26–50% | 378 | 0.9791 | 0.0298 | 70.1% | 95.5% |
| 51–75% | 78 | 0.9712 | 0.0398 | 57.7% | 96.2% |
| above 75% | 67 | 0.9673 | 0.0313 | 58.2% | 100% (67 trials with very few alarms; it says little) |

and, by the largest arm, near-steadily in r (the two smallest bins are
level at 91% within 0.05 and the second has the higher r; the fall
begins above 100 per arm), with the bin's mean coarse-unit share rising
alongside:

| largest arm | trials | r | median \|Δp\| | within 0.05 | alarm concordance at 0.05 | mean coarse-unit share |
|---|---|---|---|---|---|---|
| 50 or fewer | 3,159 | 0.9906 | 0.0129 | 91.3% | 98.5% | 0.04 |
| 51–100 | 666 | 0.9943 | 0.0129 | 91.6% | 98.2% | 0.07 |
| 101–500 | 809 | 0.9840 | 0.0176 | 82.6% | 97.5% | 0.12 |
| 501–1,000 | 199 | 0.9860 | 0.0197 | 80.9% | 98.5% | 0.22 |
| 1,001–5,000 | 181 | 0.9788 | 0.0262 | 68.5% | 96.1% | 0.30 |
| above 5,000 | 63 | 0.9635 | 0.0304 | 58.7% | 95.2% | 0.38 |

Both tables sum to the 5,077 scored trials; they are in the run's
workbook, sheet "Rounding gradient", and were reproduced independently
by the follow-up audit.

**The differences run in both directions, and in the coarse-unit
regime the engine's p is more often the smaller.** An earlier version
of this paragraph said "usually the larger"; the follow-up audit counted
the Trials sheet: across all 5,077 scored trials the engine's p is
larger in 2,329 and smaller in 2,747 (one equal); among the 1,292
trials with at least one coarse-unit variable it is larger in 464
(35.9%) and smaller in 827 (64.0%), with a median signed difference of
−0.009, and every nonzero coarse-share bin has more decreases than
increases; only the 63 mega-trials show a modest majority of increases
(35 larger, 27 smaller, one equal). Neither a larger nor a smaller p is
evidence about either method's calibration:

| share of coarse-unit variables | trials | engine p larger | engine p smaller | equal |
|---|---|---|---|---|
| none | 3,785 | 1,865 | 1,920 | 0 |
| up to 25% | 769 | 279 | 490 | 0 |
| 26–50% | 378 | 124 | 254 | 0 |
| 51–75% | 78 | 31 | 47 | 0 |
| above 75% | 67 | 30 | 36 | 1 |

**The worked example is a provenance question first.** NEJM 864 (PMID
25014686) reads 0.58 here against Carlisle's stored 0.21. The runner
builds TRIAL, ROW, N, MEAN and SD from the One Sheet and discards its
DECM and DECSD columns, so the validator infers precision from the
printed digits; for that trial's cholesterol row the workbook declares
one decimal (128.0 (22.0)) while the article's Table 1 prints "128 ±
22", so the inferred integer precision matches the article and the
workbook's declaration does not. Supplying the workbook's declarations
instead moves the trial from 0.5815 to 0.1613 at seed 42; independent
fixed-SD references give 0.577 at the article's precision and 0.163 at
the workbook's, and a normal-reference Stouffer at the workbook's
precision gives 0.217, close to the stored 0.2119. The example therefore
mixes an input-declaration question with a methods question and settles
neither; the declarations must be reconciled with the article and the
historical calculation before it can. The age row itself is sound: for
arms of 12,838 and 12,835 with SD 7.5 printed to 0.1, the honest-null
probability that the two printed means agree is 0.390 by independent
quadrature (insensitive to where the population mean sits on the grid),
so its mid-p is 0.195, which is what the engine reads. Equal printed
means at this size are weak evidence one row at a time - about two
honest trials in five - and are not thereby no evidence: five
independent such rows all agreeing carry a mid-p of about 0.0045. With
the declared precision carried through (below) the trial reads 0.161
against the stored 0.212, and the example dissolves into the
declaration question it always was.

The follow-up audit's statement of the caveat, adopted here: in this
comparator run, agreement with Carlisle's stored trial p-values is
weaker when more variables have coarse reporting units relative to the
standard error of an arm difference; both procedures account for
reporting precision, but their input declarations, row calculations and
within-trial combination need not coincide; the differences occur in
both directions, and in this run the engine's p is smaller in about 64%
of trials with at least one coarse-unit variable; this comparison does
not establish either method's calibration.

**With Carlisle's declared precision.** After the follow-up audit the
corpus session's runner gained the option to carry the One Sheet's
DECM and DECSD columns into ROUND_MEAN and ROUND_DISPERSION instead of
inferring precision from the stored digits. The census of the two
sources on the 72,151 cells: 8,697 disagree. 4,098 means are declared
finer than their stored digits (4,015 by one decimal, 81 by two, 2 by
ten) - trailing zeros the workbook lost, where the declaration is the
better source; 105 means in 48 trials (93 JAMA and NEJM) are declared
coarser than their digits (171.5, 166.75 declared as integers), which
look like arms combined by hand and each want a page check; and 4,494
disagreements are SD-only, 2,401 of them in 144 trials carrying five or
more digits beyond the declaration (NEJM 736, Anesthesiology 431, JAMA
388, A&A 388, BJA 250, CJA 131, EJA 67, Anaesthesia 10) - SDs Carlisle
computed from standard errors or confidence intervals. That last group
is why the pure declaration cannot be the comparison of record: under a
declared one-decimal grid those SDs are off it, the engine rightly
refuses the rows, and 124 trials validate without a summary p. **The
comparison of record is therefore "declared-floor"**: each cell takes
the finer of its declaration and its own digits. Its rows are above
(2026-09-27). One caveat on that group under the floor: a nine-digit
computed SD is then treated as printed to nine decimals, so the engine
draws it from a negligible interval, whereas the article printed a
standard error or a confidence interval at one or two decimals and the
honest interval for the derived SD is that printed value's rounding
interval scaled by √n - wider than nine decimals, narrower than one.
Neither treatment has it exactly; the floor is the better of the two
available, and the error is small, since the SD's interval matters
little beside the mean's grid at these sample sizes. Were the engine to
accept a standard error with its own precision as a row type, the
runner could pass those cells as what they are and the caveat would go. Against the inferred-precision run on the same 5,077
trials the floor run agrees at r 0.9974, leaves 71.5% of trial p's
unchanged to four decimals, moves 89 by more than 0.05 and 51 by more
than 0.10, gains 14 alarms at 0.05 and loses one, and raises agreement
with Carlisle from r 0.9891 and 88.3% within 0.05 to 0.9911 and 89.4%
(usable: 0.9913 to 0.9937). The largest movers (Carlisle / inferred /
floor): JAMA 16 0.336 / 0.858 / 0.409; A&A 21 0.779 / 0.329 / 0.761;
NEJM 864 0.212 / 0.582 / 0.161; NEJM 98 0.187 / 0.578 / 0.171; NEJM 452
0.342 / 0.454 / 0.072; NEJM 346 0.151 / 0.500 / 0.149; NEJM 913 0.231 /
0.486 / 0.175; NEJM 204 0.165 / 0.340 / 0.102.

Under the declared precision the gradient in r largely disappears -
much of it was the inferred precision - while the spread within 0.05
remains and the direction is downward: the engine's p is the smaller in
every nonzero bin (427 larger against 864 smaller across the four
coarse bins). The 63 mega-trials read r 0.9905 (from 0.9635), 63.5%
within 0.05 (from 58.7%), alarm concordance 90.5% (his 2 alarms, ours
8):

| share of coarse-unit variables | trials | r | median \|Δp\| | within 0.05 | concordance at 0.05 | engine larger | smaller | equal |
|---|---|---|---|---|---|---|---|---|
| none | 3,785 | 0.9944 | 0.0119 | 93.7% | 98.8% | 1,849 | 1,936 | 0 |
| up to 25% | 769 | 0.9847 | 0.0197 | 81.5% | 96.9% | 256 | 513 | 0 |
| 26–50% | 378 | 0.9842 | 0.0287 | 73.8% | 95.8% | 114 | 264 | 0 |
| 51–75% | 78 | 0.9878 | 0.0403 | 59.0% | 96.2% | 27 | 51 | 0 |
| above 75% | 67 | 0.9732 | 0.0296 | 59.7% | 100% (few alarms) | 30 | 36 | 1 |

| largest arm | trials | r | median \|Δp\| | within 0.05 | concordance at 0.05 | engine larger | smaller | equal | mean coarse-unit share |
|---|---|---|---|---|---|---|---|---|---|
| 50 or fewer | 3,159 | 0.9917 | 0.0128 | 92.0% | 98.6% | 1,577 | 1,582 | 0 | 0.04 |
| 51–100 | 666 | 0.9936 | 0.0123 | 91.7% | 98.6% | 259 | 407 | 0 | 0.07 |
| 101–500 | 809 | 0.9883 | 0.0167 | 85.0% | 98.0% | 272 | 537 | 0 | 0.12 |
| 501–1,000 | 199 | 0.9929 | 0.0195 | 83.9% | 97.5% | 75 | 124 | 0 | 0.22 |
| 1,001–5,000 | 181 | 0.9875 | 0.0256 | 70.2% | 96.7% | 65 | 116 | 0 | 0.30 |
| above 5,000 | 63 | 0.9905 | 0.0296 | 63.5% | 90.5% | 28 | 34 | 1 | 0.38 |

Workbooks: `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_4c5bcc5_m1e4_allarms_declfloor_summary.xlsx`
and `..._declared_summary.xlsx` (Summary, Trials, Largest differences,
Usable subset, Rounding gradient); the census
`..._declfloor_precision_disagreements.csv`.

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
| 2026-09-26 | release build after the fifth audit's numerical fixes (53aa576: #483 null-law key without SE, #484 stated-grid tolerance, #486 app draw budget) | 4,976 usable of 5,014 scored | 10,000 | 0.9916 (Spearman 0.9916) | 0.0141 | 88.9% | 98.2% at 0.05 (his 356 alarms, ours 405); 99.1% at 0.01 (111, 139) | seed 42 re-set per trial; run by the corpus session's `_tools/carlisle2017_compare.R`, John's One Sheet cells through validateData → P_Calc, his stored one-sided p joined with the A&A numbering offset; 66 of 5,080 not scored: 63 refused `too_large` (an arm above `.iaMaxArmN` = 5,000, the mega-trials, which the August pilot scored before the 2026-09-09 cap), 3 `incongruent`; 38 scored trials with his p exactly 1 dropped as usable-rule; 34 with his p in [0.9999, 1) stay in. On all 5,014 scored: r 0.9894, Spearman 0.9891, same medians and concordances. 39.7% within 0.01. Summary workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_53aa576_m1e4_summary.xlsx`. The difference from the 6 September rows combines the engine's changes since then with the 63 mega-trials now refused; the ceiling leaves r, Spearman and the median |Δp| unchanged at three decimals and moves the shares within 0.05 and 0.01 by 0.1 point (next row), which is not a statement about individual trials |
| 2026-09-26 | the same release build, 53aa576 | 4,976 usable of 5,014 scored | 100,000 | 0.9916 (Spearman 0.9916) | 0.0141 | 88.8% | 98.2% at 0.05 (his 356, ours 406); 99.0% at 0.01 (111, 139) | seed 42 re-set per trial, same runner and join as the row above; r, Spearman and the median |Δp| are the 10,000-ceiling figures to three decimals, the shares within 0.05 and within 0.01 move by 0.1 point (88.9% → 88.8%, 99.1% → 99.0%), and the twelve largest differences are the same trials at the same p's: the replicate ceiling changes the aggregate agreement with Carlisle by no more than that. It does change individual trials that reach the third stage, and a trial that stops earlier repeats the same batch at either ceiling under the same seed, so this pair of rows is not a Monte Carlo error assessment (follow-up audit 2026-09-27, N4). On all 5,014 scored: r 0.9894, Spearman 0.9891. 39.9% within 0.01. Workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_53aa576_m1e5_summary.xlsx` |
| 2026-09-26 | the release build with the arm cap raised for the run (4c5bcc5, whose R/ is identical to 89bc836; `INTEGRITY_MAX_ARM_N=1000000`, issue 174) | 5,038 usable of 5,077 scored | 10,000 | 0.9913 (Spearman 0.9913) | 0.0142 | 88.5% | 98.2% at 0.05 (his 358 alarms, ours 410); 99.0% at 0.01 (111, 142) | Steve's request: the 63 mega-trials (arms 5,006 to 34,644; 41 NEJM, 22 JAMA) admitted; only the 3 incongruent trials refused. On all 5,077 scored: r 0.9891, Spearman 0.9888, 88.3% within 0.05, 39.6% within 0.01. Admitting the mega-trials moves the corpus figures by 0.0003 in r and 0.4 points within 0.05 against the 53aa576 rows. Seed 42 per trial, same runner; workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_4c5bcc5_m1e4_allarms_summary.xlsx` |
| 2026-09-26 | the 63 mega-trials alone, same run | 63 | 10,000 (and 100,000: the same p to four decimals in 60 of 63; JAMA 112 0.006400 → 0.006315, JAMA 198 0.007700 → 0.008330, NEJM 460 0.002700 → 0.002450) | 0.9635 | 0.0304 | 58.7% | 95.2% at 0.05 (his 2 alarms, ours 5) | an earlier version of this row called the agreement at the two ceilings proof that the weaker agreement is not Monte Carlo noise; it is not that (follow-up audit 2026-09-27, N4): a trial that stops at 1,000 draws repeats the same batch at either ceiling under the same seed. For NEJM 864 (PMID 25014686; arms 12,838 and 12,835) the systematic difference does hold by a different argument - three seeds give 0.5815, 0.5755 and 0.5935 at either ceiling, a fixed 100,000-draw batch gives 0.5767, 0.5760 and 0.5786, and an independent discrete-normal reference gives 0.5775 at the runner's inferred precision - but see the provenance note below the table: at the workbook's declared precision the same trial reads 0.16. These 63 trials are the association's tail, described below; the cause is not identified. Under the declared precision (rows below) they read r 0.9905 |
| 2026-09-27 | **the comparison of record**: the release build (4c5bcc5, R/ identical to 89bc836), all arms (`INTEGRITY_MAX_ARM_N=1000000`), Carlisle's DECLARED precision carried through as "declared-floor" (each cell the finer of DECM/DECSD and its own digits) | 5,038 usable of 5,077 scored | 10,000 | **0.9937** (Spearman 0.9937) | 0.0139 | 89.5% | 98.3% at 0.05 (his 358 alarms, ours 423); 99.1% at 0.01 (111, 144) | seed 42 per trial, `_tools/carlisle2017_compare.R` with its fifth argument `declared-floor`; the 3 incongruent trials refused. On all 5,077 scored: r 0.9911, Spearman 0.9908, 89.4% within 0.05, 40.1% within 0.01. Why "floor" rather than the declaration as given, the census of the two precision sources, and the movers against the inferred run are in the paragraph below the table. NEJM 864 reads 0.1613 against Carlisle's 0.2119. Workbook `C:/dev/Fujii Boldt Reuben/_batch/Carlisle2017_4c5bcc5_m1e4_allarms_declfloor_summary.xlsx` |
| 2026-09-27 | the same, with the declaration as given ("declared"), for the record of what it loses | 4,916 usable of 4,953 scored | 10,000 | 0.9909 (Spearman 0.9908) | 0.0141 | 88.9% | 98.1% at 0.05 (his 331, ours 397); 99.0% at 0.01 (98, 131) | 124 trials validate but return no summary p: every row off the declared grid, the computed-SD group (SDs Carlisle derived from standard errors or intervals, carrying five or more digits against a declared one decimal). On the 4,953 both runs score, declared and declared-floor agree at r 0.9970 with a median difference of 0.0000. Workbook `..._allarms_declared_summary.xlsx` |
| 2026-09-27 | the 63 mega-trials alone, declared-floor (identical under "declared": none of the 63 has a computed-SD cell) | 63 | 10,000 | 0.9905 | 0.0296 | 63.5% | 90.5% at 0.05 (his 2 alarms, ours 8) | from r 0.9635 and 58.7% within 0.05 with inferred precision: the mega-trials' weaker agreement was largely the inferred precision. Their alarm concordance falls (one of the 63 his, eight ours at 0.05) - the direction of the remaining differences is downward |

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
