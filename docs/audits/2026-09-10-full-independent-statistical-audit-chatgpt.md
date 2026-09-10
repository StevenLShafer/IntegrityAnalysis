# Full independent statistical audit — 2026-09-10

Auditor: Codex. Audited source: **`a796e51d6a66b590fc09394488811f8cac2c8060`**, exactly as requested in the [full brief](evidence-2026-09-10-full/review-brief.md). Execution used an isolated archive of that commit. No engine, application, test-suite, dependency, or deployment code was changed.

**The requested engine sign-off does not pass.** There is one new **numerical P2**, in the combination of discrete rows: a trial with an exact reference p of **0.011146** reports **0.003285**. A second construction puts the exact reference outside the interval the app actually prints. Two further P2 findings concern omitted-trial coverage and the newly documented API `null` contract. The earlier numerical reproductions all passed; the new combination case contains both minimum and nonminimum row outcomes, which those reproductions did not cover.

The ranked reconstruction remains the accepted heuristic. Its optimization and bias questions are not reopened. Previously accepted, queued matters listed in the brief are not counted as findings here.

## Execution and limits

R **4.5.3**, locale `C`; `shiny`, `dqrng`, `foreach`, `Rfast`, and `MBESS` attached before `pkgload::load_all()`. Dependencies were copied to a private library. **All 121 copied dependencies also present in `renv.lock` matched their locked versions.** Startup warned that the requested `C.UTF-8` locale was unavailable; execution used `C`. [Runtime and version evidence](evidence-2026-09-10-full/runtime.txt), [lock comparison](evidence-2026-09-10-full/lockfile-comparison.csv), [source hashes](evidence-2026-09-10-full/audited-source-SHA256.txt).

**39 existing test files, 250 test blocks, 1,631 passing assertions, zero assertion failures, zero errors, 11 skips.** This includes every test file named in the brief and six additional files exercising reconstruction bounds and chunking. It is not a claim to have rerun the complete 3,287-assertion package suite. [Per-file totals](evidence-2026-09-10-full/regression-summary.csv) and [per-test skips](evidence-2026-09-10-full/skips-and-failures.csv) are retained. Eight API integration tests and the optional nimble comparison skipped under `skip_on_cran()`; two fail-safe tests skipped because their fixture did not take the hybrid route or exceeded the configuration's enumeration limit. Other executed cases cover non-partitioning and large-space refusal. The hybrid-route assertion itself remains unverified in this run.

Independent checks used synthetic data exclusively: finite categorical enumeration; an integer reference on the engine's very same simulated tables; continuous F-distribution limits; a separate implementation of the median simulation using base R order statistics; a full-observation reference for the direct draw; origin/unit transformations; and independent numerical integration for `sumz()`. A real plumber service was also started on loopback and stopped after five HTTP checks. Those checks include actual multipart decoding, handler execution, and JSON serialization; they are not calls to the handler alone.

Unless stated otherwise, the engine seed is **42**, both RNGs are seeded, and **100,000 is the ceiling**. Tables below give the actual final **M**. Exact enumeration has no Monte Carlo interval. A blank trial CI is reported as “not displayed,” never interpreted as zero uncertainty. All reproduction scripts, fixtures, outputs, and launch instructions are in the [evidence directory](evidence-2026-09-10-full/README.md).

## F1 — P2, numerical: independent row-CDF estimates split genuine trial ties

**Verified through CSV → `.apiReadUpload()` → `.apiAnalyze()` → validation → `P_Calc()`, through real HTTP `/analyze?seed=42`, and against an integer calculation on the same draws.**

The engine estimates each row's mid-p mapping separately, then [sums the resulting z-scores and compares the sums](https://github.com/StevenLShafer/IntegrityAnalysis/blob/a796e51d6a66b590fc09394488811f8cac2c8060/R/P_Calc.R#L1496). Even rows with identical fixed-margin null distributions consequently receive slightly different estimated score mappings. Trial outcomes that have exactly the same Stouffer sum under the true row distributions cease to tie. The reported interval accounts for the final reaching count, but not this instability in the score mapping.

This is **not** the repaired floating-point comparison of row statistics, nor the zero-snap defect. Every row statistic here has only two clearly separated values. Increasing a machine-arithmetic tolerance does not address uncertainty in an estimated CDF.

### A small exact reference with ordinary arm sizes

There are two arms of **100**, and nine independent binary baseline variables, `V01` through `V09`. Eight variables have counts `(YES, NO) = (1,99)` in each arm. `V03` instead has `(0,100)` and `(2,98)`. The template's `N`, `MEAN`, and `SD` cells are blank because these are categorical rows; arm totals come from the counts. [Complete 18-line fixture](evidence-2026-09-10-full/fixture-ordinary-N100-J9-bad3.csv).

Every row has the same margins: `(100,100)` by `(2,198)`. Under that null:

- `(1,99)/(1,99)` has probability **q = 100/199**, Pearson statistic zero, and exact row mid-p `q/2`.
- The two possible extreme tables together have probability `1-q`, the same positive statistic, and exact row mid-p `(1+q)/2`.

Thus the exact Stouffer sum depends only on the **number G of zero-statistic rows**, with `G ~ Binomial(J,q)`. For one extreme row among J rows, the correct trial mid-p is

`P(G=J) + 0.5 P(G=J-1) = q^J + 0.5 J (1-q) q^(J-1)`.

No normal approximation or numerical tie criterion is needed for this reference. The allocation probabilities follow directly from choosing the two YES observations among 200 subjects; this is the fixed-margin distribution sampled by [`r2dtable`](https://stat.ethz.ch/R-manual/R-patched/library/stats/html/r2dtable.html), with the [hypergeometric mass](https://stat.ethz.ch/R-manual/R-patched/library/stats/html/Hypergeometric.html).

| Construction, seed 42 | Engine trial p | App's printed 95% MC interval | M | Exact mid-p |
|---|---:|---|---:|---:|
| 9 variables, extreme counts in V03 | **0.003285** | Not displayed | 100000 | **0.0111459494** |
| Same nine variables, extreme counts in V01 | **0.0194** | Not displayed | 100000 | **0.0111459494** |
| 14 variables, extreme counts in V07 | **0.00013** | **0.000022 to 0.00031** | 100000 | **0.0005191945** |

The first two inputs differ only in which variable name is attached to the extreme row. Their exact reference is invariant. This is much larger than ordinary sampling variation in the final count. The third case provides a direct contradiction of an interval actually printed by the application. [All ordinary-arm results](evidence-2026-09-10-full/ordinary-combination-routes.csv), [nine-row HTTP reply](evidence-2026-09-10-full/http-ordinary-N100-J9-bad3.json), [fourteen-row HTTP reply](evidence-2026-09-10-full/http-ordinary-N100-J14-bad7.json). The numerical trial p quoted above is from `resultsCsv`; JSON's separate `overallP` is rounded by serialization.

### The same draws identify the mechanism

An observational trace copied the final simulated row statistics and Stouffer sums without changing any draw or returned value. Counting zero-statistic rows gives an integer representation of the exact trial ordering.

| On those identical 100,000 simulated trials | Nine-row case | Fourteen-row case |
|---|---:|---:|
| All rows at their minimum: strictly beyond the observation | 227 | 6 |
| Exactly one extreme row: genuinely tied with the observation | 1812 | 96 |
| Of those genuine ties, counted as tied by production | **203** | **14** |
| Of those genuine ties, counted below the observed Stouffer sum | **1609** | **82** |
| Integer-reference mid-p | **0.01133** | **0.00054** |
| Production mid-p | **0.003285** | **0.00013** |

The independent same-draw intervals, using the existing strict/inclusive-tail convention, are respectively `0.001985–0.021285` and `0.00002202–0.001238`. Their width reflects the genuine tie mass. Production's corresponding count intervals are `0.001985–0.004725` and `0.00002202–0.0003089`; the first is computed diagnostically because the app suppresses it at that p. **Both exclude the exact reference.** [Counts and intervals](evidence-2026-09-10-full/same-draw-combination.csv), [executable integer reference](evidence-2026-09-10-full/same-draw-combination.R).

The all-minimum constructions still agree with their exact references, explaining why the earlier combination tests remain green. Mixed outcomes expose the missing tie classes. Smaller `(2,2)` margins and additional seeds reproduce the same mechanism; those exploratory cases and their actual stage sizes are retained too.

**Why increasing M alone is insufficient.** For identical row laws, the true score difference between these permutations is exactly zero. Independent CDF estimation errors shrink with M, but their signs still choose which side of a discontinuous comparison an entire positive-probability tie class occupies. This can act like an additional random ordering of tied outcomes. That may be a defensible alternative test if explicitly chosen and calibrated, but it is not the documented exact mid-p with only the displayed count uncertainty. This audit does not estimate its corpus-wide false-positive rate.

**Required resolution:** preserve the appropriate equality of discrete trial outcomes, or explicitly redesign and validate the randomized combination and its uncertainty. Do not merely widen the floating-point row tolerance. A regression must use these CSVs and seed through the API route, and judge the final-stage output against the independently counted G classes; it must not pin whatever p a replacement happens to produce. The 0.01 crossing is in the accusing direction, so this numerical P2 blocks the brief's requested engine sign-off.

## F2 — P2: an entirely excluded trial has no results or coverage line

**Verified over actual HTTP.** The prior F3 fixture, with one excluded category beside usable variables in the same trial, remains fixed. The unhandled boundary is a file in which **one entire trial** is excluded while another is usable.

[Four-line fixture](evidence-2026-09-10-full/fixture-all-excluded-trial.csv): trial A has two Age lines, N 30, means 50/50.2, SD 10. Trial B has two lines labeled `Unresolved category`, with all analytical cells blank.

`/analyze?seed=42` returns HTTP 200. Trial A reports **0.05825**, interval **0.038–0.08**, **M=10000**. The template still contains both B lines, and the journal tables contain B's blank variable. **The results contain no B variable, no B Summary, and no warning that this trial was left out.** A's Summary note is empty. The response says `trials: 1`, which is consistent with that field's definition as trials analysed; the defect is the absent disclosure of the other offered trial, not that counter by itself. [Actual reply](evidence-2026-09-10-full/http-all-excluded-trial.json).

The cause is [construction of `TRIALS` after removing excluded rows](https://github.com/StevenLShafer/IntegrityAnalysis/blob/a796e51d6a66b590fc09394488811f8cac2c8060/R/validateData.R#L912). The API loops only over that list. The app uses the same list by source inspection; the new boundary was executed through HTTP, not separately through a Shiny session.

**Required result:** retain B in coverage reporting, with its variable marked “Not analysed” and a `0 of 1 rows analysed` Summary or equivalent explicit disclosure. It contributes no p to the overall combination. Preserve A's numerical result. The test must submit this complete two-trial file, not just call `P_Calc()` with a partly excluded trial.

## F3 — P2, API contract: structural issue rows serialize as `"NA"`, not null

**Verified over actual HTTP.** A CSV with columns `N` and `Number` correctly returns HTTP 422, stage `validation`, code `structural`, the original header names in its note, and both columns' values in the returned template. Those repaired properties remain fixed.

However, the actual response contains:

```json
{"row":"NA","col":"N","code":"structural"}
```

The API guide explicitly promises `row: null` for a whole-table issue. [Fixture](evidence-2026-09-10-full/fixture-http-duplicate.csv), [actual response bytes, pretty-printed only](evidence-2026-09-10-full/http-http-duplicate.json), [guide contract](https://github.com/StevenLShafer/IntegrityAnalysis/blob/a796e51d6a66b590fc09394488811f8cac2c8060/docs/api-users-guide.md#L324).

The [handler turns the issue data-frame row into an R list](https://github.com/StevenLShafer/IntegrityAnalysis/blob/a796e51d6a66b590fc09394488811f8cac2c8060/inst/api/plumber.R#L243) containing `NA_integer_`; `unboxedJSON` emits the string `"NA"`. The existing structural tests invoke the handler directly and assert `is.na()`, so they pass without exercising the promised wire representation. Clients expecting an integer or null can reject or mishandle the error response.

**Required result:** explicit JSON null, verified after serialization or through HTTP. Keep the structural code, header-specific explanation and unchanged input values. This is a failed verification of the newly promised boundary; this audit does not establish that an earlier release ever serialized it correctly.

## Regression checklist

“VERIFIED STILL FIXED” below means the named reproduction was executed, not merely read. The numbers are checklist identifiers; test counts are in the linked per-file evidence. Existing tests retain their original fixtures and seeds. New references are identified separately.

| ID / earlier round | Property rechecked | Result and executable evidence |
|---|---|---|
| R01 / Sep 6 | Direct draw retains the h/N mean grid | **VERIFIED STILL FIXED.** Independent full-observation, integer-sum reference: engine **0.0047**, CI **0–0.01**, M=100000; reference **0.004815**, CI **0–0.010255**, B=100000. `direct-grid-reference.R`. |
| R02 / Sep 6 | Population SD drawn per replicate; pooled variance uses N−k df | **VERIFIED STILL FIXED.** Known-answer tests plus independent small-N and unequal-N F references; see numerical table below. |
| R03 / Sep 6 | Sample SD drawn within its own printed interval, including mixed blank cells | **VERIFIED STILL FIXED.** `test-sd-rounding-draw.R`, `test-sd-interval-cells.R`; 30 assertions. |
| R04 / Sep 6 | Explicit per-arm precision retained, missing precision inferred | **VERIFIED STILL FIXED** for the adjudicated contract. `test-validate-rounding.R`, `test-pcalc-direct.R`, `test-text-precision.R`. The broader supplied-precision policy remains the accepted open decision. |
| R05 / Sep 6 | Attainable-floor note only when the arms agree | **VERIFIED STILL FIXED.** `test-adaptive-m.R`, `test-tie-criterion.R`, `test-audit-2026-09-09-f6.R`; includes unequal arm sizes. |
| R06 / Sep 6 | Trial CI lower end uses strictly-beyond count | **VERIFIED STILL FIXED.** `test-adaptive-m.R`; all-minimum trial reference in `independent.R`. F1 is a different source of interval error. |
| R07 / Sep 7 | Bounded row ties; categorical exact reference 0.35 | **VERIFIED STILL FIXED.** `test-tie-criterion.R`; own enumeration gives 0.35 versus engine **0.346**, CI **0–0.72**, M=1000. |
| R08 / Sep 7 | Summary identified by KIND, including a variable named Summary | **VERIFIED STILL FIXED.** `test-summary-kind.R`: engine, API, workbook; 11 assertions. |
| R09 / Sep 7 | Median parameter draw and clipped metalog skew | **VERIFIED STILL FIXED.** `test-median-iqr.R`, `test-quartile-draw.R`; independent symmetric, asymmetric and clipped references below. |
| R10 / Sep 7 | Quartile precision and printed intervals reach the fit | **VERIFIED STILL FIXED.** `test-quartile-precision.R`, `test-quartile-draw.R`; mixed precision, tied quartiles, reversed pairs, reproducibility. |
| R11 / Sep 7 | Numerical-resolution refusal | **VERIFIED STILL FIXED.** `test-numeric-resolution.R`, 21 assertions. |
| R12 / Sep 7 | Stated precision must describe the adjoining value | **VERIFIED STILL FIXED.** `test-numeric-resolution.R`, `test-quartile-draw.R`, `test-text-precision.R`; consistent coarse grids remain admitted. |
| R13 / Sep 8 | Zero tolerance invariant to origin/units | **VERIFIED STILL FIXED.** `test-screen-2026-09-08.R`; additional validated continuous and median transformations in `invariances.csv`. |
| R14 / Sep 8 | Fill chooses a whole table by its row p | **VERIFIED STILL FIXED** within the accepted ranked search. `test-failsafe-table.R`, `test-screen-2026-09-09.R`; no new optimum claim. |
| R15 / Sep 8 | Dispersion bound sharpened and confined | **VERIFIED STILL FIXED.** `test-screen-2026-09-08.R`, `test-screen-2026-09-09.R`; the already accepted sharpness refinement is not reopened. |
| R16 / Sep 8 | Precision disclosure in both directions | **VERIFIED STILL FIXED** for the adjudicated cases. Same screen tests and `test-text-precision.R`; no reclassification of queued precision-policy findings. |
| R17 / Sep 9 F1/F8 | Complete enumeration or decline; no 2^arms fallback | **VERIFIED STILL FIXED.** `test-failsafe-table.R`, `test-screen-2026-09-09.R`, `test-screen-2026-09-09-1532.R`. |
| R18 / Sep 9 F2 | No inferred category partition | **VERIFIED STILL FIXED** by executed screen cases. One redundant test in `test-failsafe-table.R` skipped at the enumeration cap; that skipped case is not called verified. |
| R19 / Sep 9 F7 | Selector uses the engine's statistic, tie convention, floor and both margins | **VERIFIED STILL FIXED.** `test-screen-2026-09-09.R`, `test-screen-2026-09-09-1532.R`, `test-failsafe-table.R`. |
| R20 / Sep 9 F9 | Extraction owns its seed and restores caller state | **VERIFIED STILL FIXED.** `test-failsafe-table.R`, `test-screen-2026-09-09.R`, `test-seed-and-ranges.R`. |
| R21 / Sep 9 F3–F5 | Supplied precision, exponent handling, CSV digits in any header case | **VERIFIED STILL FIXED.** `test-text-precision.R`, 53 assertions. |
| R22 / Sep 9 F6 | Each replicate translated by its own first arm | **VERIFIED STILL FIXED.** `test-audit-2026-09-09-f6.R`, 29 assertions; continuous, median and unequal-N paths. |
| R23 / Sep 10 F1 | Observed arm separation cannot enter zero snap | **VERIFIED STILL FIXED.** `test-audit-2026-09-10-f1.R`, 15 assertions. Original CSV/seed returns **0.01978**, M=100000, no displayed trial CI, inside the audit's same-draw reference interval **0.01894–0.02067**. |
| R24 / Sep 10 F3 | Blank category within a usable trial counted, retained and listed once | **VERIFIED STILL FIXED** on the original JATS/Word/API paths. `test-audit-2026-09-10-f3.R`, `test-screen-2026-09-10-1143.R`. The entirely excluded trial is new F2 above. |
| R25 / Sep 10 F4 | Any-case trial header; entirely blank trial column filled | **VERIFIED STILL FIXED.** `test-audit-2026-09-10-f4.R`, `test-screen-2026-09-10-1119.R`. |
| R26 / Sep 10 F4 | Partly blank TRIAL refused per cell | **VERIFIED STILL FIXED.** Same tests plus actual HTTP: row 2, column TRIAL, code missing, 422. |
| R27 / Sep 10 F4 | Structural issue entry, named column, original input returned | **VERIFIED STILL FIXED** through HTTP for these properties. `test-api-structural-issues.R`, `test-screen-2026-09-10-1222.R`, `http-routes.R`. |
| R28 / Sep 10 F4 | Whole-table issue row is JSON null | **REGRESSED / CONTRACT NOT SATISFIED at HTTP boundary.** R-level tests pass; wire value is `"NA"`. F3 above. No claim that the wire contract previously worked. |
| R29 / older | Lower-tail homogeneity and mid-p convention | **VERIFIED STILL FIXED** per row. `test-known-answer.R`, `test-tie-criterion.R`, own finite enumeration. Mixed-row trial equality is F1. |
| R30 / older | Staged replicates, 0.1 escalation, fixed seeds | **VERIFIED STILL FIXED.** `test-adaptive-m.R`, `test-known-answer.R`, `test-seed-and-ranges.R`; actual M recorded throughout. |
| R31 / older | Exact combination on the previously repaired all-minimum examples | **VERIFIED STILL FIXED.** Existing adaptive/tie tests and independent all-minimum binomial references. This status does not extend to the new mixed-outcome example. |
| R32 / older | Banker's rounding retained | **VERIFIED STILL FIXED.** Known-answer rounding cases and full-observation grid reference execute the convention; the engine's use of R `round()` was also checked by reading. Worked example **0.0462**, CI **0.022–0.073**, M=10000. |
| R33 / remaining engine | Five reconstruction bounds and chunked drawing | **VERIFIED STILL FIXED.** Additional `test-screen-2026-09-10-{0536,0633,0734,0815,0858,0923}.R`, 111 assertions, including admitted boundary cases as well as refusals. |

**COULD NOT TEST:** the hybrid-route assertion that skipped in `test-failsafe-table.R`; optional nimble/MCMC validation; the eight skipped repository HTTP tests as written. The five separate HTTP cases described above were executed and should not be conflated with those skipped tests.

**Sep 10 F2/F5 decision — verified by reading, with residual wording below.** The current statistical-method section, user-guide bullet, API-guide bullet and latest history entry describe a heuristic and scope the result to scored readings. No counterexample search or winner's-curse experiment was repeated.

## Other independent numerical checks

| Check | Engine p and displayed interval | Actual M | Independent reference |
|---|---|---:|---|
| Small-N normal, 3/3 patients, means 0/0.2, SD 1 | 0.181; 0.16–0.21 | 1000 | F(1,4) lower tail **0.18145093** |
| Unequal-N normal, 5/17 patients, means 0/0.02, SD 1/2 | 0.0136; 0.011–0.016 | 10000 | F(1,20) lower tail **0.01679839**, outside this batch's interval |
| Direct-draw normal, 100/125 patients, means 0/0.0008, SD 1 | 0.004645; 0.0042–0.0051 | 100000 | F(1,223) lower tail **0.00475231** |
| Three equal normal arms, N 10, means −0.02/0/0.02, SD 1 | 0.004; 0.0036–0.0044 | 100000 | F(2,27) lower tail **0.00399142** |
| Symmetric median model | 0.02285; 0.018–0.029 | 10000 | **0.02223**, independent MC interval 0.01916–0.02542, B=100000 |
| Asymmetric median model, unequal N | 0.06185; 0.056–0.069 | 10000 | **0.061615**, interval 0.05825–0.06505, B=100000 |
| Clipped-skew median model | 0.0436; 0.021–0.069 | 10000 | **0.04019**, interval 0.01939–0.06162, B=100000 |

The F comparisons use six-decimal observation, mean and SD grids, so they are fine-grid limits rather than a claim that rounded data has an exactly continuous F law. The derivation is the pooled-variance t/F pivot, using the [F distribution's ratio-of-squares definition](https://stat.ethz.ch/R-manual/R-patched/library/stats/html/Fdist.html). The isolated unequal-N miss was followed through **20 seeds, 42–61**: mean **0.0162925**, empirical between-batch 95% interval **0.015718–0.016867**, containing the reference. Two individual intervals miss. This is consistent with ordinary Monte Carlo variation and is not classified as a systematic defect. Both the initial disagreement and the follow-up are retained rather than dropping the inconvenient seed. [Comparisons](evidence-2026-09-10-full/independent-comparisons.csv), [replications](evidence-2026-09-10-full/F-unequal-replications.csv).

The independent median implementation uses base R `quantile(type=7)` and `median`, its own random stream, printed-interval draws and the documented inverse bootstrap scale. It checks implementation agreement, **not** calibration of the model against every possible population. [Fixtures, code and results](evidence-2026-09-10-full/median-reference.R).

Six exact categorical examples cover 2×2, 3×2, 4×2 and 2×3 tables, unequal margins, minimum and nonminimum observations. Every row reference lies inside its displayed interval. The continuous and median origin/unit transformations also agree within their intervals. `sumz()` agrees with a separate normal-density integration/root-finding implementation to **5.9×10⁻¹⁵** over four probability vectors, including 0.0001 as the input for a censored trial; these deterministic calculations have no MC interval. [Enumeration](evidence-2026-09-10-full/independent.R), [invariances](evidence-2026-09-10-full/invariances.csv), [quadrature](evidence-2026-09-10-full/sumz-quadrature.csv).

## Contract inspection and decision rationale

| Direction requested | Assessment |
|---|---|
| Documentation overstates a guarantee | The combination's count interval omits the row-CDF ordering uncertainty demonstrated in F1. The promised coverage does not include an entirely excluded trial (F2). The explicit JSON-null claim fails on the wire (F3). |
| Behavior not adequately described | Rows with identical discrete nulls receive separately estimated score maps; their numerical differences can reorder population-level ties. The selector also has a 2,000-replicate screening pass and a 20,000-replicate refinement of six contenders per end; explaining that final selection stage would make “among those scored” more precise. |
| Claims inconsistent across places | The latest history entry correctly retracts the heuristic/selection-bias claims, but older present-tense paragraphs still say “not a heuristic” and “biased low” (`method-history.md`, around lines 637–653). Preserve the history, but mark those paragraphs superseded and link the adjudication. `statistics.md` around line 384 still says “one end of each ambiguous arm's bracket,” although interior readings are enumerated and tested. The API guide's unqualified “No partition is assumed” omits the constructed binary-complement exception described in the other guides. These are minor read-across corrections, not new optimization findings. |

The five reconstruction limits match the code's numerical ceilings. The arm-total preflight is conservatively evaluated at bracket upper bounds for nonpartitioning rows; the constrained binary case uses N itself. This is an implementation choice to bound work before reconstruction. It can decline a block without proving that every candidate is too large; the existing “decline rather than guess” policy provides the rationale.

The method/history documents explain the choices of mid-p, independent row simulation, the direct-draw threshold and grid, per-replicate dispersion uncertainty, the reciprocal median-scale draw, skew clipping, coarse-precision modeling, staged computation and banker's rounding. The rationale is generally sufficient. The remaining explanation owed is the statistical treatment of estimated discrete row scores in F1; calling the final comparison “exact” does not settle it. A deliberate additional randomization would need its own stated target and uncertainty assessment.

**My views on the three open decisions are unchanged:** accept, bound and disclose supplied precision; measure the median dispersion-side problem on suitable data before adding another test; and do not describe a row-p proxy as a trial-p guarantee. This audit adds no new experiment on that proxy and does not reopen the ranked-selection decision.

## Disposition

The audit is complete; the engine is **not ready for the requested “done” declaration** because F1 is a reproduced numerical P2 crossing 0.01. F2 and F3 need output-contract fixes. No claim of corpus-wide error rates follows from these constructions. After adjudication, regression tests should reproduce each finding through its actual route, including final JSON serialization for F3; existing green tests alone do not cover these boundaries.
