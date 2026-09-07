> Kept verbatim as delivered on 2026-09-06 (audited tree: main at 166dc5b),
> including the erratum on F1 added the same day. What happened next:
> F1 (the SD rounding draw) merged as #198; F2 (the median/IQR scale draw
> and the skew refusal) merged as #202, with a reciprocal draw after the
> bootstrap this report proposed was measured and rejected; F3 (the
> rounding convention) was decided in favour of keeping banker's rounding,
> documented in statistics.md; F4 (direct-call defaults) merged as #201;
> F5, F6 and the documentation findings of Part 2 merged as #197. Paths
> under `C:/dev/Corpus/` are the auditor's working files, not the
> repository.

# Audit of the Monte Carlo engine and the documentation — 2026-09-06

Claude Code (model Claude Fable 5.1), at Steve Shafer's request in the
session that began by reading the 2026-09-06 handoff. Read-only: no file
in the repository was changed. The tree audited is main at 166dc5b
(PR #195). Scripts and raw output: `C:/dev/Corpus/reviews/audit-2026-09-06/`.

The questions asked: is `R/P_Calc.R` robust, can it be made more
accurate, and are the markdown, HTML and docx documents accurate and
clear.

## Summary

**The engine is sound.** Every derivation in the continuous branch checks
out; the exact combination is calibrated to Monte Carlo precision; 300
random edge-case trials produced no error and no out-of-range value;
seeded runs are bit-identical. Three things would make it more accurate,
in this order:

1. **The SD's printed rounding is taken as exact, and it matters.** A row
   whose SD is printed to one significant figure ("1", "3", "0.05") has a
   p at a tie that varies by a factor of 1.4 to 2.5 across the SD's own
   rounding interval. The fix is one uniform draw per arm per replicate.
2. **The median/IQR branch has no analogue of the sigma draw.** Its null
   is roughly nominal at the 5% level for 30 or more per arm, but at ten
   per arm the body of its p distribution is off (mean row p 0.57,
   Kolmogorov–Smirnov distance 0.12) and it refuses 8 to 18% of honest
   rows as "too skewed".
3. **R rounds an exact half to even; papers round it up.** Where a mean of
   N grid observations can land exactly on a printed half (integer ages,
   N = 20, mean to one decimal) the engine's tie mass is inflated and the
   p at a tie is about 9% too high, in the conservative direction.

**The documentation has one serious inaccuracy and much drift.** The
serious one: README and the data-handling statement say the AI assist
sends only "the pages the deterministic reader could not read"; the code
also sends a readable page whose table did not parse and, failing that,
up to 60,000 characters of the article's prose. The drift: the user guide
describes the engine as it was two weeks ago in six places, calls the
analysis "fully deterministic", lists a planned API and progress display
that exist, and cites figures the ledger does not hold; `docs/api-spec.md`
describes an API that was never built; ISSUES.md's "Where things stand" is
forty PRs behind; two served/shipped HTML and docx files are stale.
Everything else in `statistics.md` and `method-history.md` matched the
code line by line.

---

## Part 1 — `R/P_Calc.R`

### 1.1 What was verified (and how)

**The sigma draw is the exact test.** Under normality the between-arm sum
of squares and the pooled within-arm variance are independent, so the
frequentist pivot is their ratio, F-distributed. Drawing σ² = s²·df/χ²(df)
and then the arm means given σ makes SS_between/s² marginally
(df/χ²_df) × (weighted χ²_{k−1}) — the same F. The sigma draw is therefore
not an approximation to the t/F construction; it *is* that construction,
extended to rounded data. The code's own reasoning (P_Calc.R comments,
statistics.md "The population SD") is correct.

**The pooled variance, c₄ and its use.** `Meanvar` weights by N_i − 1 over
df = N − k; `c4` uses lgamma; `Meansd` reaches only the direct-draw
threshold. Matches statistics.md exactly.

**The direct draw's arithmetic.** `matrix(rnorm(N·ch), nrow = ch) * sig +
meansim` recycles the length-ch vectors down each column, one σ and one
location per replicate, as claimed; the snap `round(x/g)·g` with
g = h/N then the printed rounding is the documented order.

**The metalog.** With M(y) = a₁ + a₂L + a₃(y − ½)L, L = ln(y/(1−y)):
Q3 − Q1 = 2a₂ ln3 and Q1 + Q3 − 2a₁ = ½a₃ ln3, giving exactly the coded
a₂ = IQR/(2 ln3) and a₃ = 2(Q1 + Q3 − 2m)/ln3. The density at the median
is 1/(4a₂), so the median's asymptotic SD is 2a₂/√n as coded. Keelin's
feasibility bound |a₃|/a₂ < 1.667 is the right one. `Rfast::rowMedians`
averages the middle pair at even N (checked).

**Replicate mid-p equals the observed formula.** For a replicate whose
tie group among the s replicates has t members, (average rank − ½)/s =
(kLess + t/2)/s; for the observed value tied with the same t replicates,
(kLess + t/2)/s. Identical, so the trial's `kE` ties at the attainable
floor are exact, not floating-point accidents. The two formulas differ
by ½/s when the observed is *not* tied, and at the floor (observed p
1/(s+1) against the best replicate's ½/s). Measured (script `combo.R`,
continuous statistic, 10,000 honest trials at s = 1,000; 3,000 at
10,000; k = 2, 5, 25 rows): rejection below 0.05 between 0.046 and 0.051,
below 0.01 between 0.0083 and 0.0106, mean trial p 0.498 to 0.506 — all
within two standard errors of nominal, and a fully symmetric variant
(observed ranked among the s + 1) is no closer. **No action.**

**The unweighted statistic.** For two arms Σ(x̄_i − x̄_w)² is a monotone
function of |x̄₁ − x̄₂| and ranks every table exactly as the N-weighted
(likelihood-ratio) form does. For three or more unequal arms it is a
valid test (the null is simulated with the same statistic) but not the
most powerful. Measured (script `power.R`, arm means with their sampling
variance shrunk to a quarter, α = 0.05): 20/20/200 power 0.182 vs 0.185;
10/100/1000 0.186 vs 0.203; 30/60/120/240 0.275 vs 0.284. **No action**;
a sentence in statistics.md that the statistic is unweighted and why it
does not matter for two arms would pre-empt the reviewer who asks.

**Robustness (script `fuzz.R`).** 300 random trials of 1 to 4 rows and 2
to 5 arms mixing continuous, median and categorical rows: N from 2 to
1,000, means from −3 to 10⁴, SDs from 0 to 1,000 (including exactly 0),
mean precision 0 to 4 decimals, observation precision 0 to 6 decimals
independently (coarser and finer than the mean's), identical means in 30%
of rows, empty categories and empty arms, skewed and degenerate
quartiles. **Zero errors, zero out-of-range p, every usable row carried
an interval and a replicate count, every refusal was a named refusal.**
Two seeded runs at 100,000 replicates were `identical()`.

**The escalation, floor, bound and interval code** (`.floorP`,
`.mcUpper`, `.rowReport`, the trial block) do what statistics.md says:
one-sided 97.5% Clopper–Pearson upper bound on the at-or-below count,
lower end from the strictly-below count, floor 1/(m + 1), ceiling 0.9999.

**Things considered and left alone, with the reason.** The location
draw's scale (measured by the project 2026-09-06: no effect). The
staged interval's coverage near the thresholds (documented; a
confirmatory batch is the remedy if one is ever wanted). Memory chunking
by 1e8/N_full and 1e7/cells (correct, and RNG-consumption-neutral as
verified in the code's own notes). The categorical branch (fixed
margins, lower tail of Pearson's X², E computed once because the margins
are fixed — correct).

### 1.2 Findings

> **Erratum, added later the same day after implementing F1.** The table
> below measures how much the p depends on *where in its interval* the
> true SD lies. That spread is irreducible uncertainty, not bias, and I
> wrongly read it as the size of the correction. Computed directly
> (`C:/dev/Corpus/synthetic/sd-round/tieProbability.R`, 2,000,000
> replicates, no staging): integrating the SD over its printed interval
> moves the mid-p at a tie by +2.2% for a printed "1" at N 30, +0.7% for
> "2", +0.5% for "3", nothing at two significant figures — because
> pooling the drawn SDs by their squares raises the pooled variance by
> the rounding's h²/12 and nearly cancels the 1/σ convexity gain. The
> honest null is unchanged in aggregate (identical rates, mean p and KS
> in every cell). The draw is still the right average over what a
> printed SD can mean, and it is cheap, but its effect on any reported
> number is small. Severity should read **low**, not medium.

**F1 — The printed rounding of the SD is not modelled (accuracy, low; see the erratum above).**
statistics.md says so ("The SD's own printed rounding (`ROUND_DISPERSION`)
is not integrated over"); the question was whether it matters. It does
when the SD is printed to one significant figure. Seeded engine runs at
100,000 replicates, the SD varied across its rounding interval
(script `sdround.R`):

| Row | true SD across the printed interval → row p |
|---|---|
| SD printed "1", N 30/30, means 2.3 = 2.3 (1 dp) | 0.5 → 0.128; 0.75 → 0.100; 1 → 0.074; 1.25 → 0.060; 1.49 → 0.050 |
| SD printed "1", N 30/30, means 2.3 vs 2.5 | 0.5 → 0.88; 1 → 0.58; 1.49 → 0.40 |
| SD printed "1.0", N 30/30, means tied | 0.95 → 0.078; 1 → 0.074; 1.05 → 0.071 |
| SD printed "3", N 100/100, means 24.6 = 24.6 | 2.5 → 0.058; 3 → 0.047; 3.49 → 0.041 |
| SD printed "13", N 50/50, means 55 = 55 (integers) | 12.5 → 0.076; 13 → 0.074; 13.49 → 0.073 |
| SD printed "0.05", N 20/20, means 7.38 = 7.38 | 0.045 → 0.088; 0.05 → 0.080; 0.055 → 0.070 |

A factor of 2.5 for "1", 1.4 for "3", 1.25 for "0.05"; negligible at two
significant figures. The mean's printed rounding is handled correctly by
construction (the simulation rounds its means the same way, and the tie
mass is the mechanism); the SD is different because it enters the null
as a *parameter*, so its rounding is unmodelled parameter uncertainty —
exactly the class of thing the sigma draw was added to model.

*Recommendation.* Per replicate, per arm, draw the SD uniformly on
[s_i − h_d/2, s_i + h_d/2) where h_d = 10^−ROUND_DISPERSION, then pool and
apply the chi-square draw as now. `validateData()` already carries
`ROUND_DISPERSION` when supplied; infer it from the printed decimals when
it is blank, as ROUND_MEAN is inferred. The effect is convex (p is more
sensitive at the low end), so integrating raises the p at a tie modestly
on average (for the "1" case, about 0.074 → 0.08) — conservative, and
honest about what a one-digit SD tells us. Cost: one uniform per arm per
replicate. Known-answer pins move only for rows whose SD is coarsely
printed; measure on the honest null and the corpus as the sigma draw
was.

**F2 — The median/IQR branch: no scale-uncertainty draw, and a refusal
rate on honest data (accuracy and robustness, medium).** method-history.md
records this branch as validated by a smoke test only. Measured
(script `mednull.R`): honest two-arm trials, arms summarised as median and
type-7 quartiles recorded to one decimal, one row at 1,000 replicates,
400 trials per cell.

| population | N/arm | < 0.05 | < 0.01 | mean p | KS | refused |
|---|---|---|---|---|---|---|
| normal | 10 | 0.049 | 0.014 | 0.567 | 0.125 | 32 |
| normal | 30 | 0.038 | 0.003 | 0.529 | 0.059 | 1 |
| normal | 100 | 0.058 | 0.005 | 0.512 | 0.045 | 0 |
| lognormal | 10 | 0.040 | 0.006 | 0.581 | 0.125 | 74 |
| lognormal | 30 | 0.058 | 0.018 | 0.514 | 0.061 | 21 |
| lognormal | 100 | 0.050 | 0.003 | 0.522 | 0.055 | 1 |
| uniform | 10 | 0.042 | 0.006 | 0.556 | 0.110 | 42 |
| uniform | 30 | 0.025 | 0.000 | 0.554 | 0.100 | 4 |
| uniform | 100 | 0.065 | 0.000 | 0.514 | 0.050 | 0 |
| t (3 df) | 10 | 0.055 | 0.016 | 0.531 | 0.066 | 35 |
| t (3 df) | 30 | 0.045 | 0.005 | 0.500 | 0.028 | 4 |
| t (3 df) | 100 | 0.045 | 0.000 | 0.496 | 0.031 | 0 |

Standard error of a 5% rate here is 0.011. Reading: the 5% rate is
roughly nominal everywhere except the bounded population at N = 30
(conservative, 0.025). The body of the distribution is not uniform at
small N — mean p 0.55 to 0.58 and KS 0.11 to 0.125 at ten per arm — the
same symptom the continuous branch showed before the sigma draw (KS 0.07
at three per arm), and larger, because quartiles of ten observations are
very noisy and are taken as exact. Separately, the feasibility rule
refuses 8% (normal) to 18% (lognormal) of honest ten-per-arm rows with
"Quartiles too skewed to simulate", and 5% of lognormal rows at thirty.

*Recommendation.* (a) Draw the metalog's parameters per replicate from
their sampling uncertainty — simplest is a parametric bootstrap: draw N
observations per arm from the fitted metalog, take their quartiles, refit
the pooled coefficients, and simulate from that fit (one extra draw of
the same size as the replicate; cheap). (b) At the feasibility bound,
clip a₃ to ±1.66·a₂ (a legal, maximally skewed metalog) with a note in
the results, rather than refusing; the refusal should be kept for
a₂ ≤ 0. (c) Whatever is decided, record this table in method-history.md
so the "smoke test only" line can be replaced by what was measured.

**F3 — Rounding convention (accuracy, low to medium; conservative
direction).** R's `round()` sends an exact half to the even neighbour
(2.5 → 2; 61.35 → 61.4 but 61.45 → 61.4). Excel, SPSS, SAS and GraphPad
round half away from zero, and papers are built in those. A mean of N
grid observations lands *exactly* on a printed half with positive
probability: N = 20 integer observations printed to one decimal put every
other grid point on a half. Under half-even the printed bins alternate
wide and narrow, which inflates the tie mass. Measured (script
`roundconv.R`, 400,000 replicates per cell, same seed both ways):

| N/arm | obs dp | mean dp | cells that differ | mid-p at a tie, R round | half-up | relative change |
|---|---|---|---|---|---|---|
| 20 | 0 | 1 | 24.9% | 0.00692 | 0.00631 | −8.8% |
| 40 | 0 | 1 | 12.4% | 0.00904 | 0.00882 | −2.4% |
| 6 (the guide's example) | 0 | 0 | 8.4% | 0.0119 | 0.0115 | −3.0% |
| 100 | 1 | 2 | 4.9% | 0.00937 | 0.00924 | −1.4% |
| 10 | 0 | 0 | 5.0% | 0.0446 | 0.0442 | −1.0% |
| 50 | 0 | 1 | 0% | 0.00997 | 0.00997 | 0 |
| 200 | 0 | 0 | 0.2% | 0.146 | 0.146 | 0 |

Where no exact half is reachable the conventions agree; where it is,
the engine's p at a tie is up to 9% too high. The direct-draw snap
`round(x/g)·g` inherits the same rule.

*Recommendation.* Round the simulated summaries half up
(`floor(x·10^d + 0.5)/10^d`, with a small epsilon against binary
representation) in both branches and in the snap, and say so in
statistics.md; or, if the convention is to stay, document that it is
conservative by up to about a tenth of the p at the floor in the
affected configurations. Either way the known-answer pins move by that
much in those configurations only.

**F4 — Direct calls without the validator crash unhelpfully (robustness,
low).** The roxygen invites direct calls ("Running DATA through
`validateData()` first is recommended but not required") and documents
ROUND_MEAN and ROUND_OBSERVATION as *optional*. Without them:
`P_Calc("T1", d, NULL, 1000)` fails with "invalid argument to unary
operator" (from `10^(-NULL)`); with ROUND_OBSERVATION NA it fails with
"invalid arguments" after an NA warning; with N = 1 per arm it fails
with "missing value where TRUE/FALSE needed". Inside the app and the API
the validator prevents all three.

*Recommendation.* Either default the rounding columns inside P_Calc
(ROUND_MEAN from the printed decimals, ROUND_OBSERVATION = ROUND_MEAN)
and refuse N < 2 with a named refusal, or change the roxygen to say the
validator is required and the columns mandatory.

**F5 — Cosmetic.** (a) A row every replicate beats displays P 0.9999
beside an interval "1 to 1" (lower end 0.996 rounds to 1 at two
significant figures). Show the interval to enough figures that it
brackets the display, or display the row's p as 1. (b) The trial's
interval appears only below 0.001 while every row carries one; the
asymmetry is documented but will be asked about.

**F6 — One number in statistics.md is wrong by a quarter.** "At zero hits
this needs roughly 30,000 replicates" for "<0.0001": the one-sided 97.5%
upper bound at zero hits is 1 − 0.025^(1/m), which clears 10⁻⁴ only at
m ≥ 36,887; at 30,000 it is 1.23 × 10⁻⁴ and the claim is *not* licensed.
Write "about 37,000". (The 100,000 figure, 3.7 × 10⁻⁵, is right.)

### 1.3 Suggested order

1. F6 and the statistics.md sentence on the unweighted statistic — with
   the documentation PR below.
2. F1 (SD-rounding draw): the biggest accuracy gain per line of code;
   measure on the honest null (`C:/dev/Corpus/tools/sdNull.R`) and the
   corpus before adopting, as for the sigma draw.
3. F3 (half-up rounding): small, measurable, re-pin.
4. F2 (median branch): a design decision first — bootstrap vs asymptotic
   draw, clip vs refuse — then the calibration table goes into
   method-history.md whichever way it goes.
5. F4/F5 whenever convenient.

---

## Part 2 — Documentation

Method: three parallel read-only reviews (the user guide; the two API
documents; README, data-handling, ledger, parser architecture and
ISSUES), each checking every claim against the code by file and line,
plus my own line-by-line check of statistics.md and method-history.md
against P_Calc.R, and freshness checks of the generated HTML and docx.
Line numbers are for main at 166dc5b.

### 2.1 Generated files — are they in sync?

| File | State |
|---|---|
| `inst/extdata/IntegrityAnalysis.html` | **In sync** with `docs/user-guide.md` (regenerated with the header's pandoc command: zero differing lines). |
| `inst/extdata/data-handling.html` | **Stale.** Built 2026-09-03; the markdown changed 2026-09-06 (PR #191) to stop calling the analysis deterministic. The served page still says "The default analysis is deterministic and runs entirely on the server". |
| `C:/dev/Corpus/WAME/IntegrityAnalysis-data-handling.docx` | **Stale**, same sentence (built 2026-09-04). |
| `C:/dev/Corpus/WAME/IntegrityAnalysis-introduction.docx` / `.md` | **Stale figures**: "agree 99.0% of the time" and "5,080 trials" are the August engine; the current run is 98.5% over 5,041 usable (ledger row 6). Off-repo. |
| user-guide, statistics, method-history, api-users-guide docx | **Current** (built 11:18 after the 11:17 commit; the #194 sigma-draw wording is present). |

### 2.2 `docs/statistics.md` and `docs/method-history.md`

Checked line by line against the engine. Every algorithmic statement is
correct: the table of components, the stages and thresholds, the floor,
the bound, the interval construction, the sigma draw, the location draw,
the direct draw's two thresholds and the snap, the attainable floor's two
conditions, the exact combination, the closed form across trials, the
seed. Two corrections:

1. L79 "roughly 30,000 replicates" → about 37,000 (F6 above).
2. L62 "r = 0.991 over 5,080 trials" is the 2026-08-17 mid-p build
   (ledger row 1). The current engine is r 0.9929 over 5,041 usable
   (row 6). Say which is meant, or quote the current one.

Clarity: the document is good. Two additions would forestall reviewer
questions: that the between-arm statistic is unweighted and why that is
immaterial for two arms (§1.1), and, once F2 is measured, the median
branch's calibration.

method-history.md is consistent with the ledger except that two figures
it quotes have no ledger row: the location-scale re-run (0.9931 vs
0.9932, 89.3% vs 89.9%, 419 vs 420 alarms) and the mid-p pilot's
"r 0.995". The ledger's rule is that every figure traces to a row; add
the rows (or say the ledger holds full-corpus runs only). Also in the
ledger: row 3's "0.0135 vs old" sits in the "vs Carlisle" column; the
trial total is given as 5,087 here, 5,080 in ISSUES.md and 5,088 in
`corpus/README.md`; and "runs of 2026-09-04 onward used 10,000"
contradicts row 3.

### 2.3 `docs/user-guide.md` (and the served HTML)

**Accuracy — wrong or stale (fix these):**

1. L39 "The deployed analysis is fully deterministic" — the Monte Carlo
   is unseeded by default; the guide itself says so at L744. Only the
   extraction is deterministic.
2. L96–100 "the conventional SD is a biased estimate ... this app
   corrects for it" — the c₄ correction now survives only for the
   direct-draw threshold; the sigma draw replaced the plug-in.
3. L565–567 and L801–820 describe the mean/SD model without the direct
   draw for arms of 100 or more and say observations are drawn "with the
   pooled mean" — each replicate draws its own common location.
4. L815–817 "the simulated sample's quartiles are rounded like the
   printed ones" — the sample *median* is rounded; no quartiles are
   computed.
5. L757–759 "upper 95% confidence bound" — it is the one-sided 97.5%
   Clopper–Pearson bound; and the P column shows the estimate alone, the
   interval sits in its own column.
6. L776 "floored at one over the replicate count" — 1/(replicates + 1).
7. L751 "the About sheet carries it" — the build commit is on the
   Provenance sheet (L884 has it right).
8. L359–362 "the results workbook's audit trail records which engine read
   each line" — it does not; engine provenance reaches the grid (green)
   and the log only.
9. L382–398 the colour list omits green (derived / AI-read), which the
   legend paints and L685 refers to; L400 "no colors ... and the Analyze
   button appears" — Analyze appears with soft-warning colours too.
10. L385–389 hover text quoted is the old wording; current: "median
    [range] - the analysis needs quartiles (Q1/Q3), not the range".
11. L310 the deterministic reader yields an analyzable trial "roughly a
    third of the time" — the repo's records say 84.9% on curated journal
    PDFs and 44.8 to 48.8% fully corroborated against Carlisle; nothing
    supports a third.
12. L944–949 the 61-article numbers (r 0.94, factor 1.05, 97%) — the
    ledger excludes that run and no file in the repo records those
    values. Confirm the source or remove.
13. L825–827 and L1073–1075 "live progress display is a known limitation
    / planned" and "planned ... a REST API" — both exist (progress per
    trial in app_server.R; the API has its own section at L951).
14. L842 TRIAL "blank on the Summary row" — blank on every row after a
    trial's first.
15. **L588 renders literally**: the bold span "** Research fraud should
    never be alleged ..." is broken by an inserted parenthetical, and the
    served HTML shows the asterisks (confirmed in
    `inst/extdata/IntegrityAnalysis.html`).
16. Code-side, found while checking the guide: `R/app_ui.R:224` still
    says "csv, xls or xlsx"; the accept list and the guide exclude .xls.

**Clarity (the user's rule: describe today; history to method-history.md):**
dated narrative to remove or move at L164, L172–174, L573–575, L664–672,
L1030–1037, L1067–1070, L405 ("you rarely need this section any more"),
L1056 ("public hosting is being stood up"); the "<0.0001" rule is stated
at L735–764 and again at L776–779 — once; the two workbook layouts are
described twice (L849–863, L923–931); the API size limits sit under the
app heading "Trials too large to analyze" (L993–1046) and belong in the
API section; L775 "ten rows each at p = 0.02 still combine to a far
smaller number" wants the number; decoder internals at L211–234 are too
technical for an editor; reference 7 (GRIM/GRIMMER) is orphaned at L731;
"Stouffer", "Clopper–Pearson", "metalog", "scaled inverse chi-square"
appear without a gloss; L845 calls the interval "exact 95%" without
statistics.md's coverage qualification.

**Verified correct** (so nobody re-checks): the worked example's "about
0.044" (three seeds, 0.0418–0.0441); the stages, thresholds and standard
errors; zip limits (50 MB, 300 files, 300 MB); timeouts 60/300 s; the
25-document AI cap; the seed range and plumbing; key validation; colour
semantics and hex values; sheet names and column headers; graphs at
p ≤ 0.01; button labels; the accepted-extension list; the 5,000 ceiling;
all refusal texts; the API's three routes and status codes. The
abbreviation "CI" appears nowhere in any audited document.

### 2.4 `docs/api-users-guide.md` and `docs/api-spec.md`

**`api-spec.md` describes an API that does not exist** — `/v1/` paths, a
caller-chosen `m` (default 15,000), a `format` field, `status`/
`retention` objects, a 50 MB cap, `.xls` accepted. Its header admits it is
a design document; the guide (L14) still calls it "the design document
this describes the implementation of", and the spec calls the guide the
as-built reference — circular. Retire it (move the August design notes to
method-history.md or delete) and point every reference at the guide.

**`api-users-guide.md` accuracy:**

1. L227 the 500 body "carries a request id" — it does not
   (`apiService.R:846`); the message is "Internal error processing the
   request."
2. L180 the captured `resultsCsv` header shows five columns; there are
   six (NOTE), as the table at L192 says.
3. L209/L217 the example issue `note: "no arm N printed for 'Weight'"`
   exists nowhere in the code (`validateData.R:494` emits `code:
   "missing"`, `note: null`); and `row` is the data-frame index, i.e.
   `templateCsv` line row + 1.
4. L191 `overallP` "arrives as the string '<0.0001' when licensed" —
   true for a single trial only; with several it is always numeric with
   "<0.0001" folded in as 1e-4.
5. L192 "floored at one over the replicate count" — 1/(m + 1).
6. L216/L266 `/parse` failures carry `stage: "parse"` — the `/parse` 422
   has no `stage` (L162 has it right).
7. L131 "every reply is a JSON object with ok, file ... and deleted" —
   400/401/411/413/500 carry `ok` and `error` only.
8. L199 sanitised prefixes omit tab and carriage return; L114/L262
   "25 MiB" vs the 413 text's "25 MB"; L225 the chunked-upload claim is
   asserted, not established (the test accepts 411 or 413).

**Undocumented behaviour worth a line:** 400 for `%00` in the query or a
malformed multipart part; 422 stage `request` for an empty part; 422
stage `analysis` code `error` when P_Calc throws; the 10,000 × 500 sheet
caps; duplicate column names refused; `.jpeg` accepted; the temp-path
scrub in error reasons (so callers know why a docx error names only the
file). List all `stage` and `code` values in one place; add `?seed=` to
one of the two worked examples; link the data-handling statement.

### 2.5 README, data-handling, parser architecture, ISSUES

**The AI-assist scope claim is wrong in both public documents** (README
L26–27, L38; data-handling L34–35, L76–78, L110–112): "the pages the
deterministic reader could not read". `parseBaselineTable.R:387–403`
sends a page whose text *was* readable but did not parse as a table, and
if that fails sends up to 60,000 characters of the article's prose
(`aiFallback.R:615`, `prose = TRUE` by default in both the app and the
API). For a security or legal reviewer this is the most consequential
sentence in the statement. Say: "the page or pages whose table the
deterministic reader could not extract, and if that fails, up to 60,000
characters of the article's text".

Also in data-handling.md: L8 the published URL
`integrityanalysis.io/data-handling.html` returns 404 (guide.html is
200); L66 "no log that records document content" — the API's error
handler logs the condition message, which can quote a fragment
(`apiService.R:826`); L123 "stores only irreversible hashes" — plain-text
tokens are also accepted for local testing (`apiService.R:83`); name the
usage counter (GoatCounter) and the 25-document AI cap.

README: no run instructions, R version or size limits anywhere (AGENTS.md
has them); "1,000+ assertions" vs ISSUES's 1,453 — drop the count or say
"about 1,450". Its validation figures (0.993, 98.5%, 5,041) match ledger
row 6.

`docs/parsepdf-architecture.md` is an earlier design: says the deployed
app runs `ai = "never"` billed to the maintainer (false since BYOK,
PR #67); no JATS route; the Files table omits parseDocx, parseJats,
parseWideTable, armNRecovery; "no Collate field" while DESCRIPTION has
one; "the app will ... expose an API"; 72% parse rate vs 84.9%;
`MBESS::s.u()` in `server.R` (neither exists); a non-existent
`architecture.html`. Either bring it to today or mark it historical in
its first line.

ISSUES.md: "Where things stand" is dated 2026-09-03 and predates the
exact combination, pooled SD, sigma draw, seed, direct draw, .xls drop
and the docs split (PRs #156–#195); its citable numbers are the August
run. Issue 32's render cap is done (`.ppRenderablePages`, pinned) — mark
bullet 2 closed; the R parse child still has no memory ceiling. Issue 1a
still lists xls and omits docx/xml/images. Issue 8 says per-request BYOK
"remaining" while issue 1 says live-verified. Issue 1 follow-up 1
(httpuv buffering) is superseded by the 413 cap of #194 for
Content-Length requests; chunked stays open. Parse-rate and trial-total
figures disagree across README (85%), ISSUES (84.9%),
parsepdf-architecture (72%), corpus/README (71.9%); 5,087/5,080/5,088.

### 2.6 A documentation PR, in one pass

Docs-only, one PR: the user-guide items 1–16 (then regenerate the HTML);
regenerate data-handling.html; statistics.md L62 and L79; README and
data-handling AI-scope sentence; data-handling URL/log/token lines;
`app_ui.R:224`; ISSUES "Where things stand" and issues 1a/8/32; retire
api-spec.md; the ledger rows and column fix; then rebuild the four docx
and the introduction (off-repo) and refresh its two figures.

---

## What this audit did not do

No code was changed. The experiments used 400 trials per cell for the
median branch (standard error 0.011 on a 5% rate) — enough for the
qualitative conclusions, not for a final calibration table; the SD and
rounding experiments are seeded and exact to their replicate counts. The
docx files were checked for freshness against their markdown sources and
for the specific stale sentences, not re-read in full: they are pandoc
renderings of the audited markdown. The Barnett dispersion test
(`R/dispersionTest.R`) and the parsers were out of scope.
