# Validation ledger

One row per measurement of the engine against Carlisle's 2017 corpus
(the *Anaesthesia* 2017 data: 5,087 trials, "One Sheet Carlisle Data.xlsx"
and his stored per-trial p-values — working data, never committed). Every
figure quoted anywhere in this repository should trace to a row here.
Agreement with Carlisle is agreement with a comparator computed from the
same tables, not a measurement of the false-alarm rate or of sensitivity
to fabrication; the honest-null and synthetic experiments that measure
those live in `docs/statistics.md` and beside the corpus tooling.

| Date | Engine (commit / PR) | Trials compared | Replicate ceiling | r vs Carlisle | median \|Δp\| | within 0.05 | alarm concordance (p < 0.05 both ways) | Notes |
|---|---|---|---|---|---|---|---|---|
| 2026-08-17 | mid-p build (PR #8) | 5,080 | 100,000 | 0.991 | 0.0095 | 92% | 97.4% | first full run after mid-p adopted; per-row early stop |
| 2026-08-21 | shipped engine (issue 3 runner, `corpus/validateCarlisle2017.R`) | 5,080 | 100,000 | 0.9930 | 0.0127 | 90.3% | 99.0% | the "citable" run of ISSUES.md; 121 outliers unadjudicated |
| 2026-09-04 | exact combination (#170, c31bb51) | 5,030 usable | 100,000 for 3,725, then 10,000 | 0.9917 | 0.0135 vs old | — | 98.3% | per-trial staging; alarms 348 → 392 |
| 2026-09-05 | main + zero-SD fix (e9b710f + #182) | 5,011 usable | 10,000 | 0.9922 | 0.0160 | 88.0% | 98.6% | baseline for the SD decision; the 0.1 escalation rule |
| 2026-09-05 | pooled SD, N − k (#183) | 5,011 usable | 10,000 | 0.9925 | 0.0150 | 88.5% | 98.5% | median \|Δp\| vs baseline 0.007 |
| 2026-09-06 | sigma draw (#185, from merged main) | 5,041 usable | 10,000 | 0.9929 | 0.0142 | 89.1% | 98.5% | median \|Δp\| vs pooled 0.009, confined to ≤ 30 per arm |
| 2026-09-06 | SD rounding draw (feature/sd-rounding-draw, from 166dc5b) | 5,041 usable | 10,000 | 0.9932 | 0.0138 | 89.2% | 98.5% | vs the sigma-draw run: median \|Δp\| 0.0077, r 0.9982, alarms 420 → 418 (5 down, 7 up), no direction by arm size; data `C:/dev/Corpus/synthetic/sd-round/` |

"Usable" excludes the trials where Carlisle's stored p is exactly 1 (a
z = +∞ artifact of his closed-form combination, 39 trials) and any
trial one run could not join. "Within 0.05" is the share of trials whose
p lies within 0.05 of his. The runs of 2026-09-04 onward used
`INTEGRITY_MMAX=10000` for the reasons recorded in the runner; the two
ceilings change nothing above p = 10⁻⁴. Delta files and per-trial
results: `C:/dev/Corpus/synthetic/sd-null/` and
`C:/dev/Corpus/synthetic/exact/` (off the repository).

Not on this ledger, because they measure something else: the parser's
yield (`corpus/README.md`), the 61-article end-to-end comparison
(`corpus/validateEndToEnd.R`; a set selected for successful parsing), the
honest-null rejection rates and the direct-draw and sigma-draw
experiments (`docs/statistics.md`).
