# Independent statistical audit — third full pass, 2026-09-11

**Commit audited: `6db32ee0ea8333870709e52af7ff109299c08da4`. Outcome: two numerical P2 findings; no P1 found. The brief's condition for declaring the engine done is not met.**

The last audit's category-recoding counterexamples now pass, and its documentation correction is present. Expanded arm/category permutation checks also pass. Two different counterexamples remain: exchanging the row and column margins of one categorical variable defeats the shared-law mapping, and the new clipping of journal-table trial IDs can merge two separate trials into one. Both can create a false-positive screening result below 0.01.

This report follows `REVIEW-BRIEF-chatgpt-statistics-2026-09-11-full.md`, retained in the [evidence directory](evidence-2026-09-11-full/review-brief.md). No engine or reader code was patched. No production endpoint, corpus manuscript, or live AI service was used.

## What was executed

The requested commit was checked out in an isolated detached worktree. Its HEAD was verified before and after the audit, and its tracked diff remained empty. R **4.5.3**, Windows x86-64, locale `C`; the five specified packages were attached before `pkgload::load_all()`. All **121 locked package versions matched** the existing private dependency snapshot, which was used without updating it. Development tools were available alongside those locked dependencies. Runtime details are in [runtime.txt](evidence-2026-09-11-full/runtime.txt).

The 48 selected regression files produced **1,896 passing assertions**, **zero failures or errors**, **three skips**, and **three warnings**, across 283 test blocks. This is a fresh execution of the relevant regression suite, not a claim to have run the entire approximately 3,720-assertion repository suite. The three warnings arise when a regression deliberately reads raw gzip bytes as text: two embedded-NUL warnings and an incomplete-line warning; their sanitized text is retained. The security tripwire is outside this statistical audit.

Independent work included the continuous F and direct-grid references; exact categorical allocation laws; an independent median/IQR simulation; the previous 24 recoding cases; **28 new three-arm/multilevel cases** with exact rational references and integer classification of actual draws; **75 continuous/median key checks** and three end-to-end integer-lattice comparisons; **24 transposition cases** and four same-draw traces; **16 trial-ID boundary cases**; eight old/new output comparisons; and **16 authenticated loopback HTTP requests**, in addition to the repository's real-HTTP tests.

Expected probabilities come from exact allocation counting, integer outcome classes, F distributions, independent base-R simulation, or normal quadrature. No expected answer is taken from the production helper being checked. Old scripts were reused where appropriate but their results were freshly generated at this commit. The six unchanged reference-result files were also compared with the preceding audit and matched exactly.

Throughout, a quoted engine p is accompanied by its displayed Monte Carlo interval, or explicitly says that no interval is displayed. Exact probabilities and deterministic combinations have no Monte Carlo interval. **M is the actual final batch**, not the requested 100,000 ceiling. See the [evidence README](evidence-2026-09-11-full/README.md) for runnable scripts and their order.

## F1 — numerical P2: transposed categorical laws still get different mappings

**Location:** `R/P_Calc.R:1478–1480` builds a key from the separately sorted row and column margins. The pooled mapping begins at `R/P_Calc.R:1611`. Sorting recognizes permutations within each vector; it does not recognize exchanging the two vectors.

**This is a different operation from the recoding fixed in #297.** Transposition exchanges the statistical roles of arms and category totals for one variable. Its margins change, but its Pearson-statistic null distribution does not. Different variables can have different observed arm totals; these fixtures meet the engine's input contract. The issue is not that every transposition describes the same clinical variable, but that these distinct admitted inputs have exactly the same statistic distribution and therefore the same two scores in the documented combination.

For fixed margins r and c, the probability of a table t is

`prod(r_i!) * prod(c_j!) / (N! * prod(t_ij!))`.

Transposition is a bijection of the table space, leaves that probability unchanged, and leaves `sum((observed-expected)^2/expected)` unchanged. Thus it preserves the entire Pearson null law, not merely the observed statistic or its expectation.

### Reproducer and exact answer

Make J binary variables. Every ordinary variable has arms `(YES,NO) = (1,99)/(1,99)`. One extreme has `(0,100)/(2,98)`, V03 for J = 9 or V07 for J = 14. Leave template N/MEAN/SD blank, as required for counts.

Now **transpose only the extreme table**. Its arms become **`(0,2)/(100,98)`**. That variable has arm totals **2 and 198**, category totals **100 and 100**; the other variables have arm totals **100 and 100**, category totals **2 and 198**. The engine admits both shapes. The two key strings have their margin groups exchanged and are not equal.

Every variable still has the same two-state Pearson law. The homogeneous state has probability `q = 100/199`, so the exact trial mid-p with one extreme is

`q^J + 0.5 * J * (1-q) * q^(J-1)`.

That is **0.0111459494027611** for nine variables and **0.000519194541114** for fourteen, transposed or not.

| Seed 42 input | Engine p | Displayed 95% Monte Carlo interval | Actual M | Exact reference |
|---|---:|---|---:|---:|
| J = 9, no transpose | 0.01133 | Not displayed | 100,000 | 0.011145949403 |
| J = 9, extreme transposed | **0.003285** | **Not displayed** | 100,000 | 0.011145949403 |
| J = 14, no transpose | 0.00054 | 0.000022–0.0012 | 100,000 | 0.000519194541 |
| J = 14, extreme transposed | **0.00013** | **0.000022–0.00031** | 100,000 | 0.000519194541 |

The nine-variable case crosses the 0.01 screening threshold in the false-positive direction. The fourteen-variable exact value lies outside the displayed interval. Both transposed cases returned **HTTP 200** through actual `/analyze` requests. The result table retains the precision above; the top-level `overallP` is rounded separately.

The fourteen-variable transposed case also returns **0.00010 (0.000016–0.00025), M = 100,000, seed 43**, and **0.00009 (0.000016–0.00022), M = 100,000, seed 44**. All three intervals miss the exact reference. Nine-variable transposition at seeds 43 and 44 returns **0.0192** and **0.017**, respectively, both **M = 10,000, interval not displayed**. Direction varies with the sampled mapping. Transposing all variables together restores a single mapping and the baseline result. All 24 cases are in [transpose-comparisons.csv](evidence-2026-09-11-full/transpose-comparisons.csv).

### Verified on the same draws

The trace copies actual simulated statistics and verifies that the untraced output is unchanged. Integer indicators identify each homogeneous state; their sum independently classifies a whole trial. At seed 42:

| Case | All-homogeneous replicates | Genuine trial ties | Engine-recognized genuine ties | Genuine ties wrongly counted below the observed Stouffer sum |
|---|---:|---:|---:|---:|
| J = 9, baseline | 227 | 1,812 | 1,812 | 0 |
| J = 9, extreme transposed | 227 | 1,812 | **203** | **1,609** |
| J = 14, baseline | 6 | 96 | 96 | 0 |
| J = 14, extreme transposed | 6 | 96 | **14** | **82** |

The fourteen-variable same-draw integer reference is **0.00054**, audit count interval **0.0000220193–0.00123808**; the engine reports **0.00013 (0.000022–0.00031)**. For nine variables, the integer reference is **0.01133**, audit count interval **0.00198456–0.0212850**; no trial interval is displayed by the engine. These audit intervals are explicitly separate from displayed intervals. The discrepancy is tie classification, not independent Monte Carlo noise.

**Fix-test path:** [nine-variable CSV](evidence-2026-09-11-full/fixture-transpose-J9-extreme-s42.csv) and [fourteen-variable CSV](evidence-2026-09-11-full/fixture-transpose-J14-extreme-s42.csv) → multipart `POST /analyze?seed=42` → upload reader → validation → `P_Calc()` → returned `resultsCsv`. Assert the exact reference above, correct integer tie handling, and the fourteen-variable displayed-interval condition. The original recoding fixtures must continue to pass.

The narrow correction is to recognize the **unordered pair of margin multisets** for a categorical law, while retaining each variable's original simulation order. Keep the different-law controls and the held-draw bound. A wider numerical tolerance is not a correction for different empirical mappings. This report does not claim that this change would settle all possible law equivalences in all branches.

Evidence: [generator](evidence-2026-09-11-full/transpose-checks.R), [same-draw trace](evidence-2026-09-11-full/same-draw-transpose.R), [HTTP script](evidence-2026-09-11-full/http-routes.R), [nine-variable response](evidence-2026-09-11-full/http-transpose-J9-extreme-s42.json), [fourteen-variable response](evidence-2026-09-11-full/http-transpose-J14-extreme-s42.json).

## F2 — numerical P2: clipping trial IDs silently merges distinct trials

**Location:** `R/parseWideTable.R:363` sets the 200-byte marker-ID limit; `R/parseWideTable.R:1010–1012` clips each `Trial:` marker before constructing the block. Two distinct IDs with the same first 200 bytes become the same TRIAL value. No collision is detected, and no warning flag is returned.

This is a numerical consequence of the new bounded reader, distinct from the accepted bounds themselves. Keeping the memory bound is appropriate. Losing the distinction between two trials is not an acceptable way to enforce it.

### Reproducer and controls

The synthetic journal-style CSV has two blocks. Each starts with `Trial: <ID>`, then `Variable,Arm A (n=30),Arm B (n=30)`, and the single row:

`"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"`.

The IDs are two different 201-byte ASCII strings: one common 200-byte prefix, followed by A or B. This is a small file, with ordinary table cells and no compressed input. It passes the normal input gates.

| Route/control, seed 42 | Trials retained | Reported result | Displayed intervals and actual M |
|---|---:|---|---|
| Wide CSV, distinct 200-byte IDs | **2** | Trial p values **0.1405** and **0.16**; overall **0.07139** | Trial intervals **0.11–0.18** and **0.12–0.20**, M = **1,000** each. No overall interval is displayed. |
| Wide CSV, distinct 201-byte IDs | **1** | **0.005275** | **0.0048–0.0058**, M = **100,000** |
| Template CSV, the full distinct 201-byte IDs | **2** | Trial p values **0.1405** and **0.16**; overall **0.07139** | Same two trial intervals and M as the 200-byte control; no overall interval is displayed. |
| Same 201-byte wide CSV on preceding commit `7fd6545` | **2** | Trial p values **0.1405** and **0.16**; overall **0.07139** | Same two trial intervals and M; no overall interval is displayed. |

The data are unchanged across the identity controls. The defect changes the statistical experiment: the current wide reader feeds **four arms of one Age variable in one trial** to the engine, where the file specified two independent two-arm trials. It changes a nonflagged overall result into a result below 0.01. The interval on the merged result quantifies simulation of the wrong experiment; it does not account for the lost trial identity.

The correct two-trial combination was also calculated independently by integrating the normal density and numerically inverting that integral: using the two control trial p estimates gives **0.0713919338635497**, matching the displayed overall **0.07139**. This is deterministic combination of Monte Carlo estimates, not an exact population p or a new confidence interval. It is far outside the merged result's reported **0.0048–0.0058** interval.

The **actual HTTP `/parse` response already contains only one unique TRIAL**, and `/analyze` reports `trials: 1`. Both return **HTTP 200**, `ok: true`, and empty flags. The 200-byte wide and 201-byte template controls retain two trials through both endpoints. Six raw HTTP responses are preserved. A sixteen-case boundary sweep covers lengths 199, 200, 201 and 240 with four mean differences; all cases at 201/240 lose the trial distinction, while 199/200 preserve it.

**Fix-test path:** [201-byte marker CSV](evidence-2026-09-11-full/fixture-trial-id-201-delta-0.5.csv) → real multipart `/parse` and `/analyze?seed=42` → wide CSV marker parsing → block assembly → validation → analysis. The fix must preserve two trial identities and two two-arm analyses, or explicitly refuse the collision before analysis. A direct `.ppClip()` length test is insufficient. Compare the [template control](evidence-2026-09-11-full/fixture-trial-id-template-201.csv) and the two-trial reference, not whatever p a patched reader happens to produce.

Retain bounded IDs while preserving their identity, for example by separating a bounded display label from a bounded collision-resistant internal identity, or detecting collisions and returning an explicit refusal. Do not remove the reader's work/memory bound to fix the collision.

Evidence: [boundary generator](evidence-2026-09-11-full/trial-id-checks.R), [independent control/quadrature](evidence-2026-09-11-full/trial-id-reference.R), [before-fix control](evidence-2026-09-11-full/trial-id-pre-fix.R), [HTTP script](evidence-2026-09-11-full/http-trial-id.R), [HTTP summary](evidence-2026-09-11-full/http-trial-id-summary.csv), [faulty analyze response](evidence-2026-09-11-full/http-analyze-trial-id-201-delta-0.5.json).

## Regression checklist

Counts below are passing assertions in the named files, sometimes reused across rows; **do not add these grouped counts**. The nonoverlapping total is 1,896. Full test names and results are in [regression-summary.csv](evidence-2026-09-11-full/regression-summary.csv) and each `regression-*.csv`.

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
| Previous full F1: original identical-margin constructions | **VERIFIED STILL FIXED for the reported fixtures** | `audit-2026-09-10-full-f1`: **14** assertions. Own CSV/API/HTTP executions: J9 **0.01133, no displayed interval, M = 100,000**; J14 **0.00054 (0.000022–0.0012), M = 100,000**. Their exact references agree; the different transposed-law input is new F1 above. |
| Previous full F1, bounded: sorted pool, near ties, held-draw refusal | **VERIFIED STILL FIXED** | `screen-2026-09-10-1523`: **22** assertions, including 250 shared rows at a 10,000 ceiling and bound refusal. Supplemental prospective-bound check: **100** rows accepted, **101** refused at analysis stage; accepted case actually used M = **1,000**. |
| Previous full F2: entirely excluded trial remains listed | **VERIFIED STILL FIXED** | `audit-2026-09-10-full-f2`: **21** assertions. Independent HTTP response retains **2 trials**; trial B reads **No values**, **0 of 1 rows analysed**, and retains its excluded variable and template lines. No p or interval is produced for B. |
| Previous full F3: structural issue row is JSON null | **VERIFIED STILL FIXED** | The specific real-HTTP test has **8** passing assertions, within **229** in `api-service`. Independent raw HTTP bodies show `"row": null`, not `"NA"`. |
| Security S1: every duplicate column survives refusal | **VERIFIED STILL FIXED** | **9** assertions. Independent CSV with two literal `N` headers returns **422**, keeps both headers and values **20/30** and **20/31**, and has a null structural row. |
| Security S2: reserved AI category labels do not overwrite statistics | **VERIFIED STILL FIXED** | **16** assertions through mocked transport and real AI parser/converter/analysis. Independent replay retains **3 category columns**, blank N/MEAN/SD; categorical p **0.01345 (0–0.03), M = 10,000**, exact reference **0.0120584457852**. |
| 2026-09-11 final-brief F1: arm/category recoding recognizes the common law | **VERIFIED STILL FIXED** | `audit-2026-09-11-f1`: **33** assertions; the added actual HTTP regression: **3**. Independent replay of all **24** recoding cases passes, and four traces count every genuine tie correctly. Recoded J9 at seed 42: **0.01133, no displayed interval, M = 100,000**; recoded J14: **0.00054 (0.000022–0.0012), M = 100,000**. |
| 2026-09-11 final-brief F2: the combination paragraph describes pooled versus own mapping | **COULD NOT TEST numerically — documentation correction** | **Verified by reading:** both the general method and the combination paragraph now distinguish a unique row's mapping from a shared group's pooled mapping, matching the implementation. |
| Older mid-p, homogeneity direction, staging, combination, floor, seed, pooled variance and rounding | **VERIFIED STILL FIXED in the executed cases** | `adaptive-m`, `known-answer`, `seed-and-ranges`, `pcalc-direct`: **93** assertions, supplemented by the independent calculations below. |

**Three skips, explicitly not passes:** the hybrid fail-safe preservation fixture did not take the hybrid route (**COULD NOT TEST that route**); the older four-level nonpartition fixture now exceeds the enumeration cap (**COULD NOT TEST its resolved outcome**, but refusal is consistent with the bounded-search decision, and the separate free/partition count check executes); the optional nimble/Barnett comparison could not run because nimble is absent (**COULD NOT TEST**). The remaining 62 dispersion assertions passed. These are listed in [regression-exceptions.csv](evidence-2026-09-11-full/regression-exceptions.csv); no whole-branch claim is based on a skip.

The three new reader files (`screen-2026-09-10-2100-f3`, `screen-2026-09-10-2100-raw`, `screen-2026-09-10-2149`) add **40 passing assertions** for byte clipping, raw reads and bounded IDs/text. Three warnings come from reading raw gzip bytes as text; see `warning-details.csv`. Their bounded-input properties pass. They do not test the distinct-ID collision in new F2.
## Independent checks of the rest of the engine

### Continuous model and direct draw — executed

For finely printed two-arm means, the squared standardized difference has an F(1, ΣN−2) reference under the documented pooled inverse-chi-square variance model. For three equal-sized arms the corresponding reference is F(2, ΣN−3). Rounding to six decimals makes these fine-grid limits useful independent comparisons. The reference uses degrees-of-freedom-weighted variances, not the engine's statistic helper.

| Synthetic case | Independent F probability | Engine p, displayed interval | Actual M |
|---|---:|---|---:|
| Two arms N = 3, equal SD | 0.1814509302 | 0.181 (0.16–0.21) | 1,000 |
| N = 5 and 17, SD = 1 and 2 | 0.0167983935 | 0.0136 (0.011–0.016), seed 42 | 10,000 |
| Direct branch, N = 100 and 125 | 0.0047523053 | 0.004645 (0.0042–0.0051) | 100,000 |
| Three arms N = 10 | 0.0039914205 | 0.004 (0.0036–0.0044) | 100,000 |

The unequal-N case's seed-42 reference lies outside its printed interval. I retained that result and repeated the **prespecified seeds 42–61**, rather than discarding the inconvenient seed. Two of 20 displayed intervals miss the reference. The mean estimate is **0.0162925**, with a **95% t interval over the 20 run estimates of 0.0157178–0.0168672**; this is an audit interval for the run mean, not an app interval. The reference lies inside. This is not evidence of a systematic numerical defect or a 0.01 decision reversal; nominal Monte Carlo intervals can miss. All individual p/interval/M triples remain in [F-unequal-replications.csv](evidence-2026-09-11-full/F-unequal-replications.csv).

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

These controls do not show the new transposition defect. For cases with no displayed interval I make no claim about containment in an app interval. Their exact references, fixtures and full results are retained in [independent-comparisons.csv](evidence-2026-09-11-full/independent-comparisons.csv).

### Median/IQR branch — executed

The reference implements the documented three-term metalog in base R: printed-quartile interval draws, N-weighted pooling, type-7 bootstrap quartiles, inverse scale draw, clipping to the 1.66 skew bound, common location, rounded observations and medians. It uses independent uniform/normal draws and no production draw or ranking helpers. This checks implementation of that model; it does not prove that a metalog describes every clinical variable.

| Case | Engine p and displayed interval, M = 10,000 | Independent reference p and interval, B = 100,000 |
|---|---|---|
| Symmetric | 0.02285 (0.018–0.029) | 0.02223 (0.0191608–0.0254159) |
| Asymmetric | 0.06185 (0.056–0.069) | 0.061615 (0.0582492–0.0650494) |
| Skew clipped | 0.0436 (0.021–0.069) | 0.04019 (0.0193859–0.0616212) |

Engine seed 42; reference seed 9173. All reference points lie inside the displayed engine intervals. Translation and power-of-ten unit changes also remain consistent within the reported intervals; finite-seed outputs are not all bit-identical. The six p/interval/M triples are in [invariances.csv](evidence-2026-09-11-full/invariances.csv).

### Expanded law-key tests — executed, with independent integer references

The new categorical tests use Python `Fraction` arithmetic to enumerate every fixed-margin table, its exact probability, and its rational Pearson statistic. For each of four laws, a trial contains J−1 minimum-statistic variables and one variable at the next statistic. With minimum/next-state masses q0/q1, its exact probability is `q0^J + 0.5*J*q1*q0^(J-1)`. Every other outcome is strictly less homogeneous than that trial, so this reference needs no floating-point Stouffer calculation.

| Margins (arms; categories) / J | Exact trial mid-p | Baseline engine p | Displayed interval | Actual M |
|---|---:|---:|---|---:|
| (2,2,6); (3,7) / 9 | 0.0835896145 | 0.0854 | Not displayed | 10,000 |
| (2,3,4); (2,3,4) / 3 | 0.002612244898 | 0.00246 | Not displayed | 100,000 |
| (3,3,3); (2,3,4) / 3 | 0.042507288630 | 0.03965 | Not displayed | 10,000 |
| (3,4,5); (2,4,6) / 3 | 0.000946262373 | 0.00093 | 0.00038–0.0016 | 100,000 |

Each law was run seven ways: unchanged; the extreme variable's arms permuted; its categories permuted; both; a nonzero category moved into a column absent in other variables; an extra zero column; and entirely different category-column names for each variable. **All 28 cases use one key, and every case's production strict/tie counts exactly match the integer reference on its actual draws.** For the seven last-law cases, where a trial interval is displayed, every interval contains the exact probability. The absent/zero-column cases exercise the real upload reader's handling of the global category columns before key construction. See [multilevel-comparisons.csv](evidence-2026-09-11-full/multilevel-comparisons.csv), [rational enumerator](evidence-2026-09-11-full/enumerate-laws.py), and [execution/trace script](evidence-2026-09-11-full/multilevel-permutations.R).

The continuous, direct and median branches were tested with three unequal-sized arms. All six arm permutations give the same key. Individually changing each active numeric input in each arm changes the key: **75 checks passed** across the three shapes. These negative controls show no erroneous merger of the changed inputs; they do not claim that every differing input necessarily implies a different mathematical law.

Three CSV→analysis executions pair each variable with an arm-permuted copy. Their statistic is independently recovered as an integer lattice numerator, `sum((Ntotal*integer_mean - weighted_integer_sum)^2)`, so floating representations of the same statistic cannot split the reference ranks. Production strict/tie counts exactly match a pooled rank calculation on these integer values:

| Branch | Engine p | Displayed interval | Actual M | Integer strict / tied counts |
|---|---:|---|---:|---:|
| Full-observation continuous | 0.01255 | Not displayed | 10,000 | 125 / 1 |
| Direct-draw continuous | 0.1405 | Not displayed | 1,000 | 140 / 1 |
| Median/IQR | 0.000345 | 0.00024–0.00049 | 100,000 | 34 / 1 |

This reference checks the finite pooled mapping on the actual draws; unlike the rational categorical enumeration, it is not an exact analytical population p. See [arm-key-checks.R](evidence-2026-09-11-full/arm-key-checks.R).

**False mergers, verified by reading and tested controls:** the continuous simulation reads N, means (for common location and representability), SDs and the three precision columns; the median simulation additionally reads Q1/Q3. These row-specific inputs are represented in the key, with arm tuples kept together. The other simulation settings are process-wide constants. For categorical rows, equal sorted row and column margin vectors establish a probability-preserving row/column permutation; zero-margin and absent columns are removed before that key is made. I found no missing row-specific simulation input or counterexample where the new canonical ordering pools genuinely different laws. F1 is a missed equivalence, not such a merger.

### Unique laws, mapping expectation, staging and bounds

**Old/new output comparison:** against `7fd6545`, the six entire output frames for distinct continuous, median and categorical laws are identical at the fixed 1,000 ceiling and the adaptive 100,000 ceiling. Two shared-law controls are also identical. This verifies the intended preservation of row draws and outputs in these cases. [old-target-comparison.csv](evidence-2026-09-11-full/old-target-comparison.csv) includes p, displayed CI and actual M for each comparison.

**Expectation of a pooled mapping:** at a fixed statistic t, the raw empirical mid-CDF averages `I(X<t)+0.5*I(X=t)`. Pooling iid draws from the same law preserves its expectation and divides its variance by G for G equally sized rows. An independent 20,000-repetition binomial experiment at q = 100/199, M = 1,000, G = 9 gives own/pooled means **0.251273225 / 0.251262906** against exact **0.251256281**; empirical SDs **0.00787610 / 0.00262932**, predicted **0.00790559 / 0.00263520**. These are mapping estimates and simulation SDs, not displayed p/CI pairs. This does not assert unbiasedness after flooring, qnorm transformation, maximization, or staging.

**Staging:** independent exact binomial summation under the fresh-batch stopping rule gives interval coverage **93.7365% at true p = 0.009**, **95.4161% at 0.01**, and **95.3709% at 0.5** in an untied single-row null. This reproduces the already documented optional-stopping qualification; it is not re-reported as a new defect. The engine's attainable-floor labels, finite floor and strict/inclusive interval endpoints pass the existing executable cases.

**Fail-safe fill:** the candidate, working-cell, arm-total, scored-cell and grand-total limits remain enforced in the executed regressions and inspected code. An admitted 188,251-vector space is fully enumerated; oversized spaces are declined; the selector keeps its own deterministic seed without consuming the caller's stream. The explicit free-versus-partitioned supplemental case yields **81 versus 9** candidates. The cross-margin shortlist remains the accepted heuristic, not a certified optimum, and it is not silently promoted to a trial-p optimum.

**Pool boundary:** the prospective 10,000,000-held-draw case is admitted; 10,100,000 is refused at the analysis stage. These fixtures took 1.64 s and 0.20 s. The admitted case actually used 1,000 replicates; this checks admission against the planned ceiling, not peak memory at a ten-million-draw stage. The 250-row, 10,000-ceiling runtime regression also passes. No new memory-cap or security claim is made.

**Across-trial arithmetic:** normal-density quadrature and an inverse-CDF root solve agree with `sumz()` on four vectors to maximum absolute error **5.83 × 10⁻¹⁵**. This is deterministic arithmetic, without a Monte Carlo interval. The complete vectors are in [sumz-quadrature.csv](evidence-2026-09-11-full/sumz-quadrature.csv). The separate trial-ID finding shows that correct combination arithmetic does not protect against combining the wrong units.

## Documentation, contracts and defensible choices

**Overstated guarantees:** the shared-mapping account is correct for the permutations tested, but the broader description of rows with the same null law having one mapping is still incomplete for F1's transpose-equivalent laws. The proof and numerical impact are included in F1; this is not counted again as a documentation finding.

**Undocumented behavior:** the wide CSV reader's bounded ID representation can collapse distinct input trials without a flag. That is F2's loss of statistical identity, not an objection to a 200-byte resource bound. The template route preserves those same IDs, establishing a material inconsistency between two accepted input routes.

**Resolved contradictions, verified by reading:** the combination paragraph now distinguishes own and shared mappings and agrees with the earlier method paragraph. The old winner's-curse explanation is explicitly marked superseded. The percentage reconstruction discussion includes interior bracket counts and limits partition assumptions to a constructed complement. The API guide lists the pooled-draw ceiling. The updated security conclusions distinguish untrusted model output and its conversion; the two relevant S1/S2 conversion contracts were also executed. The full security conclusions and accepted screen informational notes are not re-audited here.

The documents explain why the principal choices were made: lower mid-p rather than inclusive tails, banker's rounding, the direct-draw thresholds, uniform draws inside printed dispersion intervals, feasible metalog clipping, conservative strict/inclusive count intervals, ranked-selection cost limits, and shared mappings. The common-location scale and optional-stopping limitation remain acknowledged. I found no additional unexplained choice that should be elevated to a numerical bug.

**None of my four earlier views on the open decisions changes.** The accepted precision/zero-row/workbook/Barnett items, the child-memory and synchronous-compute decisions, and tripwire or collation informational notes are not re-reported as new findings.

The stopping decision rests on the two demonstrated P2 cases above. Their original fixtures, reference calculations, actual draw traces where relevant, before/after control, and HTTP replies are retained so a later fix can be judged through the same routes.

