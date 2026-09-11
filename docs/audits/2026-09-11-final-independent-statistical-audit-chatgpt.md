# Independent statistical audit — final-brief pass, 2026-09-11

**Audited commit:** `7fd654589ddbbaa5bf03e96aad2aecbca9576bb7`, exactly the commit requested by `REVIEW-BRIEF-chatgpt-statistics-2026-09-10-final.md`. **Outcome: one new numerical P2; no P1 found. The brief's condition for declaring the engine done is not met.** There is also one minor documentation inconsistency.

The previous full audit's original F1–F3 cases remain fixed. The new numerical counterexample changes one variable's category labels. This leaves its exact statistical law unchanged but defeats the new shared-mapping key, splitting genuine trial ties again. It is a residual limitation of the fix, not a claim that its original regression fixtures fail.

All work used synthetic inputs and an isolated source worktree. No engine code was patched, no production endpoint was called, and no model request was sent. The evidence and this report are the deliverables; they do not imply deployment or a complete proof of statistical correctness.

## Execution and limits

R 4.5.3, Windows x86-64, locale `C`; `shiny`, `dqrng`, `foreach`, `Rfast`, and `MBESS` attached before `pkgload::load_all()`. The existing private dependency snapshot was used without changing it: **121 of 121 lockfile package versions matched**. A normal startup attempted an unavailable `renv` bootstrap; the audit therefore used `--vanilla` and explicitly selected the verified library. No dependency upgrade was used to obtain these results.

The source worktree's HEAD was checked before and after execution, and its tracked diff was empty. The later shared checkout was not substituted for the requested commit. The optional comparison against the preceding audited implementation uses `a796e51d6a66b590fc09394488811f8cac2c8060` and is labeled separately.

**Executed:** 44 relevant regression files, 270 test blocks, **1,820 passing assertions, zero failures/errors/warnings, three skips**; independent categorical enumeration, continuous F references, a full-observation direct-draw reference, an independent median reference, exact binary trial combinations, 24 category-relabeling cases, four traces of actual simulated draws, six unique-law old/new comparisons, and eight actual authenticated loopback HTTP requests. This is not a claim to have rerun all approximately 3,600 repository assertions. The security tripwire and live-service security audit were outside this statistical pass.

**Inspected by reading:** the statistical branches and their combination, validation and reader contracts, fail-safe selection, API serialization, and the relevant method, history, API, and agent documentation. Executable regression checks and independent numerical checks are distinguished below from documentation conclusions.

The [evidence README](evidence-2026-09-11-final/README.md) gives execution order and environment requirements. Every quoted engine p below includes its **displayed** interval, or says that no interval is displayed. Exact probabilities and deterministic calculations do not have Monte Carlo intervals. `m = 100000` is a ceiling; tables give the actual final batch M.

## F1 — numerical P2: category relabeling defeats the shared null-law mapping

**Impact:** an admissible table whose exact trial mid-p is above the screen's 0.01 threshold can be reported below it merely because one variable uses the opposite category coding. This is the false-positive direction. Other seeds move the answer the other way, so the error is not a consistently conservative adjustment.

**Location at the audited commit:** `R/P_Calc.R:1459–1460` constructs the categorical key from ordered row and column margins; `R/P_Calc.R:1508–1532` identifies shared keys, and `R/P_Calc.R:1587–1609` applies the pooled mapping. The bounded comparison at line 1620 cannot repair mappings that differ by sampling noise.

### Input and independent answer

There are two arms of 100 and J independent binary variables. Each ordinary variable has counts `(YES, NO) = (1,99)` in both arms. One extreme variable has `(0,100)` and `(2,98)`. Leave template `N`, `MEAN`, and `SD` blank: these are category counts. Use V03 as the extreme for J = 9, V07 for J = 14.

For the new counterexample, **swap YES and NO only in that extreme variable**: its two rows become `(100,0)` and `(98,2)`. No patient count or information changes. The ordinary variables still have column margins `(2,198)`; the recoded variable has `(198,2)`. These are the same fixed-margin Pearson-statistic distribution under a permutation of category labels.

Each variable has only two statistic states. The homogeneous state has exact probability

`q = choose(100,1)^2 / choose(200,2) = 100/199`.

The two extreme allocations together have probability `1-q`. Since every variable has the same two mid-p scores, its Stouffer sum depends only on the number of homogeneous states. With one observed extreme, the exact trial mid-p is

`q^J + 0.5 * J * (1-q) * q^(J-1)`.

Thus the exact answer is **0.0111459494027611** for J = 9 and **0.000519194541114** for J = 14, with or without the recoding. These are exact enumeration results, not another Monte Carlo run.

### Executed results

All rows below use seed 42, ceiling 100,000, and actually use **M = 100,000**. The values are the Summary values in the returned `resultsCsv`; HTTP `overallP` is rounded separately.

| Input | Engine p | Displayed 95% Monte Carlo interval | Exact answer | Consequence |
|---|---:|---|---:|---|
| Nine variables, original coding | 0.01133 | Not displayed | 0.011145949403 | Original fix works; above 0.01 |
| Nine variables, extreme variable recoded | **0.003285** | **Not displayed** | 0.011145949403 | Crosses below 0.01 |
| Fourteen variables, original coding | 0.00054 | 0.000022–0.0012 | 0.000519194541 | Exact answer inside interval |
| Fourteen variables, extreme variable recoded | **0.00013** | **0.000022–0.00031** | 0.000519194541 | Exact answer outside displayed interval |

The service returned **HTTP 200** for all four. This is not a direct-call-only defect. Evidence: [nine-row HTTP response](evidence-2026-09-11-final/http-J9-flip-extreme-seed42.json), [fourteen-row HTTP response](evidence-2026-09-11-final/http-J14-flip-extreme-seed42.json), and their baseline controls.

The fourteen-row recoding also gave **0.00010 (0.000016–0.00025), M = 100,000 at seed 43**, and **0.00009 (0.000016–0.00022), M = 100,000 at seed 44**. The exact answer is outside all three displayed intervals. The nine-row recoding gave **0.0192 at seed 43** and **0.017 at seed 44**, both **M = 10,000, interval not displayed**. All 24 exploratory cases, including ordinary-variable, alternating-variable, and all-variable recodings, are retained in [permutation-results.csv](evidence-2026-09-11-final/permutation-results.csv). Recoding every variable together preserves the baseline result; splitting equivalent laws into different keys is the trigger.

### The same draws establish the cause

The tracing script copies actual production statistics without changing the calculation or RNG consumption; it asserts equality with each untraced output. It independently counts homogeneous tables using integer indicators and judges the trial by that integer count.

| Case, seed 42 | All-homogeneous replicates | Genuine trial ties | Counted as ties by engine | Genuine ties counted below the observed Stouffer sum |
|---|---:|---:|---:|---:|
| J = 9, baseline | 227 | 1,812 | 1,812 | 0 |
| J = 9, recoded extreme | 227 | 1,812 | **203** | **1,609** |
| J = 14, baseline | 6 | 96 | 96 | 0 |
| J = 14, recoded extreme | 6 | 96 | **14** | **82** |

For the recoded fourteen-row case, the integer reference on those very draws is **0.00054**, with a count-based audit interval **0.0000220193–0.00123808**, rather than the engine's **0.00013 (displayed 0.000022–0.00031)**. For nine rows, the same-draw integer reference is **0.01133**; its audit interval is **0.00198456–0.0212850**. Neither nine-row audit interval is displayed by the app. This is a change in tie classification, not an unlucky independent reference simulation or ordinary interval noncoverage.

The recoding changes one pooled group into two keys. The extreme variable gets its own noisy mapping and the other variables share another. Mathematically tied allocations then receive different sums. Increasing the bounded numerical tolerance would confuse estimation error with floating-point error.

**Reproduction path for a fix's test:** [fixture-J9-flip-extreme-seed42.csv](evidence-2026-09-11-final/fixture-J9-flip-extreme-seed42.csv) or [fixture-J14-flip-extreme-seed42.csv](evidence-2026-09-11-final/fixture-J14-flip-extreme-seed42.csv) → actual multipart `POST /analyze?seed=42` → CSV upload reader → normalization/validation → `P_Calc()` → returned `resultsCsv`. The independent reference must be the formula above, with the baseline/recoded pair and the fourteen-row displayed-interval check. Do not replace that route with an assertion about key strings alone.

The narrow corrective direction is to recognize categorical laws equivalent under arm/category permutations when constructing the mapping key, while preserving each row's original draw stream. Verify column and arm permutations and the existing unique-law controls. This audit does not claim that sorting margins alone settles every possible equivalence in every branch. **No correction has been implemented here.**

Code: [permutation-checks.R](evidence-2026-09-11-final/permutation-checks.R), [same-draw-permutation.R](evidence-2026-09-11-final/same-draw-permutation.R), [http-routes.R](evidence-2026-09-11-final/http-routes.R).

## Regression checklist

Counts below are passing assertions in the named files, sometimes reused across rows; **do not add these grouped counts**. The nonoverlapping total is 1,820. Full test names and results are in [regression-summary.csv](evidence-2026-09-11-final/regression-summary.csv) and each `regression-*.csv`.

| Brief item | Status | Executed evidence at the requested commit |
|---|---|---|
| 2026-09-06: direct mean grid, replicate SD draw, supplied precision, floor label, trial interval lower end | **VERIFIED STILL FIXED** | `pcalc-direct`, `sd-rounding-draw`, `sd-interval-cells`, `validate-rounding`, `known-answer`: **57** assertions. Independent direct-grid result below also verifies integer sample-sum ties. |
| 2026-09-07: bounded ties, KIND, median draw/clipping, quartile precision, representability and consistency | **VERIFIED STILL FIXED** | `tie-criterion`, `summary-kind`, `median-iqr`, `quartile-draw`, `quartile-precision`, `numeric-resolution`: **95** assertions; three independent median references below. |
| 2026-09-08: coordinate-independent zero, whole-table fill, dispersion guard, two-sided precision disclosure | **VERIFIED STILL FIXED** | `screen-2026-09-08` and `failsafe-table`: **77** passing assertions; skip qualifications below. The prior queued decisions are not reopened. |
| 2026-09-09 F1/F2/F7/F8/F9: enumerate or decline, no inferred partition, no exponential fallback, same score/ties/floor, deterministic reader | **VERIFIED STILL FIXED** | `failsafe-table`, `screen-2026-09-09`, `screen-2026-09-09-1532`: **729** assertions. Includes 188,251 admissible vectors completely enumerated, early refusal above bounds, and retained caller RNG. Supplemental free-cell enumeration gives **81** candidates versus **9** with an explicit partition; see skip qualification. |
| 2026-09-09 F3–F5: supplied/exponent/CSV precision | **VERIFIED STILL FIXED** | `text-precision`: **53** assertions, including header case and supplied precision. |
| 2026-09-09 F6: each replicate translated by its own first arm | **VERIFIED STILL FIXED** | `audit-2026-09-09-f6`: **29** assertions, including the fine-precision cases. |
| 2026-09-10 delta F1: observed values cannot set zero tolerance | **VERIFIED STILL FIXED** | `audit-2026-09-10-f1`: **15** assertions through the recorded cases. |
| Delta F3: blank category coverage and returned artifacts | **VERIFIED STILL FIXED** | `audit-2026-09-10-f3` and `screen-2026-09-10-1143`: **65** assertions, including actual document/handler routes and **3 of 4** coverage. |
| Delta F4: trial-name handling, blank/partial trial IDs, structural issues and original sheet | **VERIFIED STILL FIXED** | Four named files: **69** assertions. Independent HTTP partial-trial and duplicate-name cases returned **422** with the received data; duplicate-name structural issue row is null. |
| Delta F2/F5: ranked selection accepted as a heuristic | **COULD NOT TEST as a numerical fix — this is a decision, not a fix** | **Verified by reading:** current documents say best/worst among readings scored; the obsolete winner's-curse paragraphs are explicitly marked superseded. No new optimization guarantee is inferred. |
| Previous full F1: original identical-margin constructions | **VERIFIED STILL FIXED for the reported fixtures** | `audit-2026-09-10-full-f1`: **14** assertions. Own CSV/API/HTTP executions: J9 **0.01133, no displayed interval, M = 100,000**; J14 **0.00054 (0.000022–0.0012), M = 100,000**. Their exact references agree; the distinct relabeling input is new F1 above. |
| Previous full F1, bounded: sorted pool, near ties, held-draw refusal | **VERIFIED STILL FIXED** | `screen-2026-09-10-1523`: **22** assertions, including 250 shared rows at a 10,000 ceiling and bound refusal. Supplemental prospective-bound check: **100** rows accepted, **101** refused at analysis stage; accepted case actually used M = **1,000**. |
| Previous full F2: entirely excluded trial remains listed | **VERIFIED STILL FIXED** | `audit-2026-09-10-full-f2`: **21** assertions. Independent HTTP response retains **2 trials**; trial B reads **No values**, **0 of 1 rows analysed**, and retains its excluded variable and template lines. No p or interval is produced for B. |
| Previous full F3: structural issue row is JSON null | **VERIFIED STILL FIXED** | The specific real-HTTP test has **8** passing assertions, within **226** in `api-service`. Independent raw HTTP bodies show `"row": null`, not `"NA"`. |
| Security S1: every duplicate column survives refusal | **VERIFIED STILL FIXED** | **9** assertions. Independent CSV with two literal `N` headers returns **422**, keeps both headers and values **20/30** and **20/31**, and has a null structural row. |
| Security S2: reserved AI category labels do not overwrite statistics | **VERIFIED STILL FIXED** | **16** assertions through mocked transport and real AI parser/converter/analysis. Independent replay retains **3 category columns**, blank N/MEAN/SD; categorical p **0.01345 (0–0.03), M = 10,000**, exact reference **0.0120584457852**. |
| Older mid-p, homogeneity direction, staging, combination, floor, seed, pooled variance and rounding | **VERIFIED STILL FIXED in the executed cases** | `adaptive-m`, `known-answer`, `seed-and-ranges`, `pcalc-direct`: **93** assertions, supplemented by the independent calculations below. |

**Three skips, explicitly not passes:** the hybrid fail-safe preservation fixture did not take the hybrid route (**COULD NOT TEST that route**); the older four-level nonpartition fixture now exceeds the enumeration cap (**COULD NOT TEST its resolved outcome**, but refusal is consistent with the bounded-search decision, and the separate free/partition count check executes); the optional nimble/Barnett comparison could not run because nimble is absent (**COULD NOT TEST**). The remaining 62 dispersion assertions passed. These are listed in [regression-exceptions.csv](evidence-2026-09-11-final/regression-exceptions.csv); no whole-branch claim is based on a skip.

## Independent checks of the rest of the engine

### Continuous model and direct draw — executed

For finely printed two-arm means, the squared standardized difference has an F(1, ΣN−2) reference under the documented pooled inverse-chi-square variance model. For three equal-sized arms the corresponding reference is F(2, ΣN−3). Rounding to six decimals makes these fine-grid limits useful independent comparisons. The reference uses degrees-of-freedom-weighted variances, not the engine's statistic helper.

| Synthetic case | Independent F probability | Engine p, displayed interval | Actual M |
|---|---:|---|---:|
| Two arms N = 3, equal SD | 0.1814509302 | 0.181 (0.16–0.21) | 1,000 |
| N = 5 and 17, SD = 1 and 2 | 0.0167983935 | 0.0136 (0.011–0.016), seed 42 | 10,000 |
| Direct branch, N = 100 and 125 | 0.0047523053 | 0.004645 (0.0042–0.0051) | 100,000 |
| Three arms N = 10 | 0.0039914205 | 0.004 (0.0036–0.0044) | 100,000 |

The unequal-N case's seed-42 reference lies outside its printed interval. I retained that result and repeated the **prespecified seeds 42–61**, rather than discarding the inconvenient seed. Two of 20 displayed intervals miss the reference. The mean estimate is **0.0162925**, with a **95% t interval over the 20 run estimates of 0.0157178–0.0168672**; this is an audit interval for the run mean, not an app interval. The reference lies inside. This is not evidence of a systematic numerical defect or a 0.01 decision reversal; nominal Monte Carlo intervals can miss. All individual p/interval/M triples remain in [F-unequal-replications.csv](evidence-2026-09-11-final/F-unequal-replications.csv).

For N = 100 in each arm, SD = 3, integer observations and six-decimal means, an independent simulation explicitly generates and rounds all observations and compares **integer sample sums**. It gives **0.004815**, reference interval **0–0.0102547**, B = 100,000, reference seed 1927. The direct engine gives **0.0047 (0–0.01), M = 100,000**, seed 42. Thus the h/N mean grid and the direct-draw correction survive this independent check.

### Categorical and trial combination — executed

All feasible allocations were enumerated with mass proportional to `prod choose(arm N, cell count)`. The six single-variable references include unequal arms, a three-arm floating-tie example, four arms, and a transposed 2×3 table.

| Case | Exact mid-p | Engine p, displayed interval, M = 1,000 |
|---|---:|---|
| Two equal arms | 0.3333333333 | 0.3375 (0–0.70) |
| Two unequal arms | 0.2625 | 0.2775 (0–0.59) |
| Three-arm tie | 0.35 | 0.346 (0–0.72) |
| Three-arm off-center | 0.4949494949 | 0.4885 (0.38–0.60) |
| Four arms | 0.2157842158 | 0.214 (0.088–0.35) |
| Transposed 2×3 | 0.35 | 0.346 (0–0.72) |

All exact values are inside their displayed intervals. The broad intervals are the engine's conservative strict/inclusive-count intervals at discrete ties; they have not been replaced with narrower audit intervals.

For independent binary tables with N = 2 per arm, the homogeneous state has probability 2/3. An exact binomial law therefore supplies an independent trial reference:

| J / number of extremes | Exact trial mid-p | Engine p | Displayed interval | Actual M |
|---|---:|---:|---|---:|
| 5 / 0 | 0.0658436214 | 0.06425 | Not displayed | 10,000 |
| 5 / 1 | 0.2962962963 | 0.278 | Not displayed | 1,000 |
| 15 / 0 | 0.0011418291 | 0.001225 | Not displayed | 100,000 |
| 15 / 1 | 0.0108473767 | 0.0105 | Not displayed | 10,000 |
| 16 / 0 | 0.0007612194 | 0.00082 | 0–0.0019 | 100,000 |
| 16 / 1 | 0.0076121942 | 0.007695 | Not displayed | 100,000 |

These controls do not show the relabeling defect. For cases with no displayed interval I make no claim about containment in an app interval. Their exact references, fixtures and full results are retained in [independent-comparisons.csv](evidence-2026-09-11-final/independent-comparisons.csv).

### Median/IQR branch — executed

The reference implements the documented three-term metalog in base R: printed-quartile interval draws, N-weighted pooling, type-7 bootstrap quartiles, inverse scale draw, clipping to the 1.66 skew bound, common location, rounded observations and medians. It uses independent uniform/normal draws and no production draw or ranking helpers. This checks implementation of that model; it does not prove that a metalog describes every clinical variable.

| Case | Engine p and displayed interval, M = 10,000 | Independent reference p and interval, B = 100,000 |
|---|---|---|
| Symmetric | 0.02285 (0.018–0.029) | 0.02223 (0.0191608–0.0254159) |
| Asymmetric | 0.06185 (0.056–0.069) | 0.061615 (0.0582492–0.0650494) |
| Skew clipped | 0.0436 (0.021–0.069) | 0.04019 (0.0193859–0.0616212) |

Engine seed 42; reference seed 9173. All reference points lie inside the displayed engine intervals. Translation and power-of-ten unit changes also remain consistent within the reported intervals; finite-seed outputs are not all bit-identical. The six p/interval/M triples are in [invariances.csv](evidence-2026-09-11-final/invariances.csv).

### Pooling, staging, fail-safe limits and across-trial combination

**Unique laws, executed:** two continuous rows, two median rows, and three distinct categorical laws were each compared with the preceding audited implementation at ceilings 1,000 and 100,000. **All six entire output frames are identical**, including the row p, interval and actual M. Shared-law controls change the trial combination as intended. See [old-target-comparison.csv](evidence-2026-09-11-final/old-target-comparison.csv), which also records every compared p and whether an interval was displayed.

**Pooled mapping, derived and independently simulated:** at any fixed observed statistic t, the raw empirical mid-CDF averages `I(X<t) + 0.5 I(X=t)`. Pooling iid draws from the same law preserves its expectation and divides its variance by the number of equally sized rows G. With q = 100/199, M = 1,000 and G = 9, 20,000 independent binomial repetitions give own/pooled means **0.251273225 / 0.251262906**, against exact **0.251256281**; empirical SDs **0.00787610 / 0.00262932**, predicted **0.00790559 / 0.00263520**. These are raw mapping estimates with simulation standard deviations, not displayed engine p/CI pairs. This does **not** prove unbiasedness after a finite-sample floor, nonlinear qnorm transform, or selection/staging. F1 shows why correct identification of the common law remains essential.

**Staging, executed independent arithmetic:** exact binomial summation under the fresh-batch stopping rule gives coverage **93.7365% at true p = 0.009**, **95.4161% at 0.01**, and **95.3709% at 0.5** for the nominal count intervals in an untied single-row null. This confirms the already documented optional-stopping qualification; it is not a new finding. Floor/label and strict versus inclusive interval endpoints also pass their engine regressions.

**Fail-safe bounds, executed regressions and inspected code:** the candidate, working-cell, arm-total, scored-cell and grand-total bounds remain enforced; the selector shares the engine's bounded tie count and refined floor, enumerates admitted spaces completely, and declines oversized ones. Its ordered shortlist across different margins remains the explicitly accepted heuristic. I have not promoted that heuristic to a certified row optimum or a trial optimum.

**Pool boundary, executed:** a prospective 10,000,000 held draws is accepted and 10,100,000 is refused before simulation, in 1.14 s and 0.13 s respectively for these fixtures. The accepted case used only the first batch; this measures the admission boundary, not peak memory at a ten-million-draw stage. The 250-row regression at a 10,000 ceiling also passed its runtime check. No security memory-cap conclusion is drawn.

**Across trials, executed independent quadrature:** `sumz()` agrees with a normal-density integral and inverse-CDF root solve on four input vectors, maximum absolute error **5.83 × 10⁻¹⁵**. This is deterministic arithmetic with no Monte Carlo interval; the complete vectors and answers are in [sumz-quadrature.csv](evidence-2026-09-11-final/sumz-quadrature.csv). The app/API tests separately verify KIND-based selection, censored inputs and omission of noncomputed trials.

## Contract inspection and the nuance question

**Overstated guarantee:** the new method/history language says rows with the same statistical null share one mapping. As demonstrated by F1, the implementation currently recognizes ordered-margin identity rather than even all category-label permutations. This is part of F1, not a second numerical finding.

**F2 — P3 documentation inconsistency:** `docs/statistics.md:281–286`, under “Combining rows into a trial p,” still says every replicate is ranked within its row. The newer account at lines 72–84 correctly describes shared-law pooling, and the implementation does that pooling. Update the combination paragraph to distinguish an unshared row's own mapping from a shared group's pooled mapping. The earlier passage already explains the design; the problem is contradictory descriptions in the document that claims to describe the current method. This has no separate demonstrated numerical impact.

**Behavior worth making explicit:** the ten-million limit is assessed against the requested final ceiling before staging, even when a table would stop at 1,000; the boundary evidence confirms that reading. The API refusal list says “at the final stage” and the code uses `max(stages)`, so this is consistent with the stated policy, not a newly invented refusal. Row p/intervals still use each row's own draws; pooled scores are internal to the combination.

**Resolved read-across, verified by reading:** the old winner's-curse explanation is marked superseded; the fail-safe discussion now includes interior bracket counts and known complements; the API guide allows a partition only when the service constructs the complement; the API limit table includes the pool ceiling. The changed AGENTS security conclusions distinguish untrusted model output and the input routes. The numerical consequences of the two relevant reader changes, S1 and S2, were separately executed above. I do not claim to have re-audited all of those security conclusions.

The documents explain the principal defensible choices: mid-p rather than inclusive tails, banker's rounding, the direct-draw thresholds, uniform interpretation of printed SD/quartile intervals, feasible skew clipping, conservative count intervals, the ranked-selection runtime tradeoff, and the shared-mapping design. The common-location scale and sequential interval coverage are identified as inherited/known limitations rather than hidden guarantees. An unexplained or debatable choice is not being relabeled as a bug.

**None of my four earlier views on the open decisions changes on this evidence.** The previously queued zero-row/precision/workbook/Barnett items, synchronous-compute design, child memory ceiling and tripwire coverage are not re-reported as new findings.

The actionable statistical result of this pass is F1 and its exact CSV/HTTP reproducer. The original fixes and the rest of the executed numerical checks stand, subject to the explicit skips and limitations above.
