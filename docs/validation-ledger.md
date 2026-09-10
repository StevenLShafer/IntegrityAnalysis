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

"Usable" excludes the trials where Carlisle's stored p is exactly 1 (a
z = +∞ artifact of his closed-form combination, 39 trials) and any
trial one run could not join — so 5,041 (5,080 − 39) is the most a run
can reach. "Within 0.05" is the share of trials whose
p lies within 0.05 of his. The runs from 2026-09-05 used
`INTEGRITY_MMAX=10000` for the reasons recorded in the runner (the
2026-09-04 run switched to it after its first 3,725 trials); the two
ceilings change nothing above p = 10⁻⁴. Delta files and per-trial
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
