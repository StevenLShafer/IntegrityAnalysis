# Independent statistical audit — 2026-09-09 brief

Auditor: GPT-6 (Codex). Requested by Steve Shafer; scope supplied by Claude's brief. Executed **2026-09-08**, America/Los_Angeles. Audited commit **9d5ef888131f9322ec410710cd5cfca3af038cc4**. The brief's claims are the subjects of this review, not assumed conclusions. Application code was not changed.

**The whole-table reconstruction does not yet support its best-case guarantee.** Two synthetic PDFs produce very small homogeneity p-values even though valid counts behind the same percentages give exact p-values above 0.01. The failures arise before the statistical engine sees the reconstructed table. The precision and zero-snap changes also introduce or leave consequential defects. These deserve correction before results from the affected paths inform an editorial investigation.

## Evidence and interpretation

All inputs are synthetic. [Evidence and reproduction instructions](evidence-2026-09-09/README.md) include source scripts, PDFs, spreadsheets, full outputs, exact-reference calculations and per-seed checkpoints. R 4.5.3 loaded the project library with `shiny`, `dqrng`, `foreach`, `Rfast`, `MBESS`, then `pkgload::load_all()`. [Session metadata](evidence-2026-09-09/metadata.txt) records actual versions. Startup reported renv out-of-sync and loading/locale warnings; I did not restore or change dependencies.

Unless stated otherwise, engine runs set **both** `set.seed(42)` and `dqset.seed(42)` and request `m=100000`. Tables below give the **actual M**. “CI” reproduces the app's displayed 95% Monte Carlo interval; its strict/inclusive-tail bracket can be much wider than uncertainty in a mid-p estimate. Exact finite-distribution probabilities have no Monte Carlo interval. Selector scores have **no interval supplied by the implementation**. Neither kind of interval covers uncertainty about which counts or reporting convention the manuscript actually used.

Nine new findings follow. P1 means a consequential false alarm or uncontrolled resource demand that merits prompt correction; P2 means a substantive contract or implementation defect with the narrower demonstrated scope stated below. Previously adjudicated September 8 findings are not counted again.

## F1 — P1: exceeding the per-arm enumeration cap silently restores the old failure

**Executed through PDF extraction, validation and row analysis.** [failsafeTable.R:218–220](../../R/failsafeTable.R#L218) returns the `none` result when one arm has too many admissible vectors. It says `complete=TRUE`, with missing p-values. [parseBaselineTableHeuristics.R:1139](../../R/parseBaselineTableHeuristics.R#L1139) then skips the whole-table replacement, retaining counts already chosen by the old per-level rule. Neither the bounded-search flag nor the straddle flag is set.

The [five-category PDF](evidence-2026-09-09/five-category-cap.pdf) has N=4000 in each arm and five categories, each printing 20% in each arm. Extraction returns `(820,820,820,820,820)` versus `(780,780,780,780,780)`: totals **4100 and 3900**, despite the stated equal Ns. Validation accepts them.

Valid original counts are `(820,820,780,780,800)` versus `(780,780,820,820,800)`. Every percentage prints 20 under the model's rounding convention; both totals are 4000.

| Categorical row analysed | App p | App CI | M | Independent exact mid-p |
|---|---:|---|---:|---:|
| Reconstructed counts | `<0.0001` | 0 to 0.000037 | 100000 | 0.0000001770893 |
| Valid original counts | 0.5835 | 0.55 to 0.61 | 1000 | 0.5938788818 |

The valid reference is far outside the reconstructed row's CI. It suffices to disprove the claimed maximum; I need not find the global maximum. These are **category-row results**, not the combined PDF trial including its fixture Age row.

**Repair:** every failed search must return an explicit unresolved result. Do not retain the old reconstruction as a best case. Bound or sample before per-arm enumeration overflows, and enforce the arm-total postcondition for confirmed partitions. Preserve the failure reason in every output route.

Code and output: [probes.R, `per-arm-cap`](evidence-2026-09-09/probes.R), [execution](evidence-2026-09-09/per-arm-cap.txt), [independent enumeration](evidence-2026-09-09/references.R).

## F2 — P1: the 2% heuristic invents complete category partitions

**Executed through PDF extraction, validation and row analysis.** [The partition test](../../R/parseBaselineTableHeuristics.R#L1126) treats numerical proximity to 100% as evidence that categories exhaust the arm. That is a statement about what categories mean, which arithmetic cannot establish.

The [incomplete-category PDF](evidence-2026-09-09/incomplete-category.pdf) gives N=1000 in both arms, percentages `(24,24,24,26)` and the footnote **“Other categories omitted.”** The midpoint sum is 980, exactly at the 2% boundary; N is reachable only by taking every upper endpoint. The parser therefore returns `(245,245,245,265)` in **both** arms and declares that the page permits only one reading. No straddle warning appears.

One valid original, including the omitted category, is `(235,245,235,265,20)` versus `(245,235,245,255,20)`.

| Categorical row analysed | App p | App CI | M | Independent exact mid-p |
|---|---:|---|---:|---:|
| Invented complete partition | 0.00003 | 0 to 0.00013 | 100000 | 0.00004540021 |
| Valid original with Other | 0.0619 | 0.057 to 0.067 | 10000 | 0.0637509089 |

Again, the valid reference is outside the erroneous CI. The reconstruction excludes the non-alarming reading rather than merely estimating its probability inaccurately.

**The reverse error also occurs.** Honest counts `(29,29,29,29,29,29,26)` sum to N=200, but print percentages `(14,14,14,14,14,14,13)`, totaling 97. The heuristic calls this non-exhaustive and admits 2186 vectors instead of the 7 satisfying its own bracket-and-total constraints. I verified the extra candidate space, not a consequent threshold crossing for this reverse case.

**Repair:** establish mutual exclusivity and completeness from the table or an explicit user declaration. For an incomplete list of mutually exclusive categories, preserve an Other/complement count when justified. Overlapping categories require a different representation; even a sum of exactly 100% does not establish a multinomial partition. Document these assumptions at input, not only in statistical background.

Code and output: [partition-and-precision.R](evidence-2026-09-09/partition-and-precision.R), [execution](evidence-2026-09-09/partition-and-precision.txt), [exact references](evidence-2026-09-09/references.txt).

## F3 — P1: valid supplied negative mean precision is overwritten

**Executed.** The new unconditional decimal bump at [validateData.R:702–707](../../R/validateData.R#L702), also present in the median branch, changes `ROUND_MEAN=-1` to zero for integer means. A mean of 50 legitimately printed to the nearest ten lies on its declared grid. This is a new regression in the changed block, beyond the earlier accepted general precision-contract finding.

Reproduce with three identical arms: N=100, MEAN=50, SD=30, `ROUND_MEAN=-1`, `ROUND_OBSERVATION=0`, `ROUND_DISPERSION=0`.

| Route | Effective ROUND_MEAN | App p | App CI | M |
|---|---:|---:|---|---:|
| Direct engine, supplied frame | -1 | 0.2595 | 0 to 0.55 | 1000 |
| Current validated frame | 0 | 0.005305 | 0 to 0.011 | 100000 |

The supplied-grid result is outside the altered-grid CI. The invariant being violated is preservation of valid explicit metadata; the direct engine is the comparison, not an independent probability oracle.

**Repair:** infer blank precision separately from checking supplied precision. Do not overwrite a legitimate negative precision simply because the numeric value contains no fractional digits. [Reproducer and both frames](evidence-2026-09-09/partition-and-precision.R).

## F4 — P1: scientific notation becomes fictitious decimal precision

**Executed.** [validateData.R:319–321](../../R/validateData.R#L319) now uses `.ppDecimals()` on value text before coercion. [utils.R:689–694](../../R/utils.R#L689) counts characters after the decimal point, including the exponent.

For two arms, N=40 and `ROUND_OBSERVATION=0`, compare MEAN=`"50"`, SD=`"10"` with MEAN=`"5.0e1"`, SD=`"1.0e1"`. Both spellings carry unit precision: one mantissa decimal minus exponent one is zero.

| Spelling | Inferred mean/SD decimals | App p | App CI | M |
|---|---:|---:|---|---:|
| Ordinary decimal | 0 / 0 | 0.0831 | 0 to 0.17 | 10000 |
| Scientific notation | 3 / 3 | 0.00235 | 0 to 0.0051 | 100000 |

The ordinary-spelling result lies outside the scientific-spelling CI. The new text-preservation route feeds a defective helper and changes the screen's interpretation.

**Repair:** parse sign, mantissa and exponent; precision is the mantissa's decimal count minus the exponent, retaining meaningful trailing zeros and negative precisions. [Executable comparison](evidence-2026-09-09/partition-and-precision.R).

## F5 — P2: CSV ingestion still destroys the precision that XLSX now preserves

**Executed through the actual API upload reader.** [apiService.R:718](../../R/apiService.R#L718) and [app_server.R:927](../../R/app_server.R#L927) use default `read.csv()`. It coerces even quoted numeric text before the validator can count its trailing zeros.

Input: two arms, N=100, MEAN=`"50.000"`, SD=`"3.00"`, `ROUND_OBSERVATION=0`, with no mean/dispersion precision columns.

| Route | Inferred mean/SD decimals | App p | App CI | M |
|---|---:|---:|---|---:|
| Character frame or text-cell XLSX | 3 / 2 | 0.00469 | 0 to 0.01 | 100000 |
| Quoted-text CSV | 0 / 0 | 0.351 | 0 to 0.73 | 1000 |

The wide CSV CI contains the other result; this is **not** a claim of non-overlapping Monte Carlo intervals. The directly verified defect is format-dependent input semantics and a changed screening point estimate.

**Repair:** retain original value text while keeping N and count columns numeric for classification. Tests must use the production reader, not a test-only `colClasses="character"`. This example does not show that an API template retaining explicit precision columns loses them; qualify the preservation promise by route and metadata retained. The fixture's trial label `T` also becomes logical TRUE in default CSV conversion; the harness resets only that label to isolate precision.

Code and output: [probes.R, `text-roundtrip`](evidence-2026-09-09/probes.R), [execution](evidence-2026-09-09/text-roundtrip.txt).

## F6 — P1: the new zero floor still drops genuine ties at fine printed precision

**Executed against an independent million-draw reference.** The tolerance [P_Calc.R:558–564](../../R/P_Calc.R#L558) is proportional to the finest printed step squared. Yet simulated means are centered relative to the **observed** first arm ([line 1292](../../R/P_Calc.R#L1292)); floating-point residuals in a replicate depend on that replicate's common value. A progressively finer printed step can make the tolerance smaller than those residuals without changing the underlying equality event.

Two arms have N=30, MEAN=2.3, SD=3.007, `ROUND_OBSERVATION=0`, `ROUND_DISPERSION=3`. An actual integer sample producing those summaries is nine 3s, eight 6s, eight −2s and five 2s: mean 2.3, SD 3.007462. Thus this is arithmetically feasible.

| ROUND_MEAN | App p | App CI | M |
|---|---:|---|---:|
| 6 | 0.00816 | 0 to 0.017 | 100000 |
| 14 | 0.0066 | 0 to 0.014 | 100000 |

Both precisions distinguish adjacent possible sample means, whose spacing is 1/30. Equality should be the same event. The independent reference generates the specified rounded-data model and compares **integer sample sums**, avoiding the floating statistic. At B=1,000,000, base-R seed 19371, it finds 16,948 ties: mid-p **0.008474**, reference SE 0.00006454, normal 95% simulation interval **0.0083475–0.0086005**.

Applying the engine's centering and threshold to those **same draws** loses 3016 genuine ties, approximately **17.8%**. This changes the paired estimate by 0.001508. Both app CIs contain the correct reference; the paired loss of known equal sums establishes the numerical bias independently of those broad intervals.

**Repair to investigate:** center each simulated replicate on its own first-arm mean before computing its weighted center. Equal simulated means then produce exact zeros structurally. Test fine printed precision over coarse observation grids, unequal Ns and multiple arms; another empirical tolerance alone needs a numerical justification.

Code, feasible raw sample and output: [zero-reference.R](evidence-2026-09-09/zero-reference.R), [zero-reference.txt](evidence-2026-09-09/zero-reference.txt).

## F7 — P2: the selector is not using the engine's own tail calculation

**Executed helper comparison; candidate-pruning defects also verified by reading.** [.ppTableP](../../R/failsafeTable.R#L175) uses literal floating equality and a different floor formula. For `rbind(c(1,1),c(1,1),c(1,5))`, independent conditional enumeration gives exact lower mid-p **0.35**. The selector gives **0.099834** with 100000 replicates, seed 42, **no supplied interval**. `P_Calc()` gives **0.346**, CI **0 to 0.72**, M=1000. The selector's discrepancy is much larger than its Monte Carlo noise, although it falls within the engine's broad interval.

This small table establishes inconsistent scoring; it does **not** establish a wrong percentage-page winner from this particular tie defect, because these small Ns do not create ambiguous whole percentages.

Two further differences matter. `.ppTableStat()` rejects an all-zero level, while the engine removes such levels and continues. And the grouping key at [line 253](../../R/failsafeTable.R#L253) contains only level totals even when `exhaustive=FALSE` permits varying arm totals.

The monotonicity argument is mathematically sound **when both margins are fixed**: `P(T<t)+0.5P(T=t)` cannot decrease with t. It does not justify pruning across different arm margins. An exact search over 768 small configurations found a maximum pruning shortfall of 0.0002118541: at N=500 per arm, percentage cells `(0,4;2,10)`, the valid candidate `(0,21;12,50)` has exact mid-p 0.9797850; the best retained group extreme has 0.9795731. This is a correctness counterexample, not a demonstrated consequential screen crossing.

**Repair:** share the engine's statistic, zero-column handling, tie logic and probability convention; include both margins in the grouping key. [Helper execution](evidence-2026-09-09/selector-ties.txt), [independent grouping search](evidence-2026-09-09/references.R).

## F8 — P1: the bounded search can still allocate billions of candidates

**Executed to a pre-allocation intercept; dangerous allocation not attempted.** [failsafeTable.R:231](../../R/failsafeTable.R#L231) retains at least two vectors per arm and then calls `expand.grid()` across arms. With 32 arms, N=200 each, two categories both printing 50%, each arm has three possible complete vectors. The fallback retains two each and proposes **2^32 = 4,294,967,296 tables**, despite `.ppTableSampleMax=20000`. Eighteen arms already propose 262144.

The evidence uses an ephemeral function copy overriding only `expand.grid()` to print its proposed size and stop. All preceding selection logic is unchanged. This is a proved budget failure, not a measured out-of-memory incident.

**Repair:** impose a global table and simulation budget before allocation. Sample complete feasible tables directly or return unresolved; do not multiply independently capped arm sets without checking their product. [Reproducer](evidence-2026-09-09/probes.R), [intercept output](evidence-2026-09-09/bounded-dimensions.txt).

## F9 — P2: extraction is now stochastic, outside the analysis seed contract

**Executed with the same PDF; API seed placement verified by reading.** The [selection-noise PDF](evidence-2026-09-09/selection-noise.pdf) has two arms of 5000 and two categories printing 50% each. Pre-parse seeds 1 and 3 produce:

| Pre-parse seed | Reconstructed counts by arm | App row p after resetting both analysis generators to 42 | App CI | M |
|---|---|---:|---|---:|
| 1 | `(2525,2475); (2475,2525)` | 0.6915 | 0.65 to 0.73 | 1000 |
| 3 | `(2524,2476); (2475,2525)` | 0.6825 | 0.65 to 0.72 | 1000 |

The intervals overlap; the finding is **reproducibility**, not a statistically significant p difference. [User guide lines 39 and 193](../user-guide.md#L39) promise deterministic extraction. [API guide line 103](../api-users-guide.md#L103) promises identical numbers for the same document, seed and build. Yet [apiService.R:823](../../R/apiService.R#L823) sets the analysis seed after parsing, and the parse subprocess receives no corresponding seed. New `sample.int()` and `r2dtable()` calls have already selected the data.

**Repair:** make reconstruction deterministic or explicitly seed and record its randomness before it runs, including in subprocesses. Decide whether changing the analysis seed should ever change the analysed counts. Retain the selected table and selection provenance so a reported result can be reconstructed. [Executable PDF comparison](evidence-2026-09-09/parse-reproducibility.R), [output](evidence-2026-09-09/parse-reproducibility.txt).

## Bounded sampling: a material miss even when the warning is returned

**Executed through an eight-arm PDF.** Each arm has N=5000 and two categories printing 50%. The fallback searches 6561 of the 51^8 feasible tables. At extraction seed 42, it selects first-category counts `(2523,2475,2523,2475,2475,2475,2515,2475)`, with their complements. A valid alternative is four arms at `(2475,2525)` and four at `(2525,2475)`.

| Counts analysed | App row p | App CI | M | Independent reference mid-p | Reference 95% simulation interval |
|---|---:|---|---:|---:|---|
| Bounded selection | 0.122 | 0.10 to 0.14 | 1000 | 0.126155 | 0.1247001–0.1276099 |
| Valid alternative | 0.215 | 0.19 to 0.24 | 1000 | 0.2202225 | 0.2184066–0.2220384 |

The reference independently samples fixed margins by sequential hypergeometric draws and compares integer-scaled statistics, B=200000 each, seeds 8821/8822. The alternative is outside the selected row's app CI. This establishes a shortfall of approximately 0.094 against **an available alternative**, not a computed global optimum. Both are above 0.01; no false alarm is asserted for this case.

`approxBounded` correctly names the row. Its hover nevertheless says the page allows only 6561 readings and promises the one with the largest p. Those are sampled readings and the largest estimated p **within that search**. The flag and detailed explanation must express the same limitation. A bounded result is not a certified best case; if a decision depends on that guarantee, require stronger optimization or leave reconstruction unresolved.

Code, actual PDF and outputs: [bounded-sampling.R](evidence-2026-09-09/bounded-sampling.R), [eight-arm-bounded.pdf](evidence-2026-09-09/eight-arm-bounded.pdf), [bounded-sampling.txt](evidence-2026-09-09/bounded-sampling.txt).

## Selection noise: measured shortfall, without a universal guarantee

I compared the unchanged 2000/20000-replicate selector against independent exact candidate probabilities. Each seed is checkpointed. A scoring wrapper records the actual budget without consuming random draws or changing the selector.

| Arms and printed categories | Candidates | Seeds | Runs missing exact optimum | Maximum true-p shortfall |
|---|---:|---:|---:|---:|
| N=400/400; 40%, 60% | 25 | 1–60 | 0/60 | 0 |
| N=200/200; 34%, 32%, 34% | 49 | 1–60 | 0/60 | 0 |
| N=200/300; 34%, 32%, 34% | 49 | 1–60 | 0/60 | 0 |
| N=5000/5000; 50%, 50% | 2601 | 1–30 | 3/30 | 0.0097757215 |

For the last case, the exact best p is **0.6825927**; seeds 3, 26 and 29 select a table whose exact p is **0.6728170**. Shortfall is zero in 27 runs and 0.0097757215 in three. These are exact oracle probabilities, requiring no Monte Carlo intervals. The selector itself provides none. All 210 selected winners received 20000-replicate scoring, and every straddle flag agreed with the exact range in these four configurations. No missed 0.01 warning was demonstrated by this noise study.

This is evidence that the budget often works and sometimes misses, not a general distribution of errors over manuscripts. By reading, an unrefined contender can still win after the refined scores fall, because the final maximum mixes both budgets. None did here. “Largest p” should be “largest estimated p among candidates searched” unless an exact optimum is established. Independent evaluation after selection, or uncertainty-aware refinement, would make the claim more assessable.

Sources: [binary oracle and seed study](evidence-2026-09-09/zero-and-noise.R), [three-category oracle](evidence-2026-09-09/noise-three.R), [larger-case output](evidence-2026-09-09/large-noise.txt).

## Decisions and explanations the user is owed

**Keep supplied precision, with provenance and sensitivity.** Accept-bound-disclose remains defensible. Printed digits do not independently reveal measurement resolution, and an author also controls those digits. Removing explicit columns cannot remove manuscript control. Preserve the distinction between printed precision, measurement resolution and an analyst's assumption; show the effective values after validation, and explain that a changed interval defines a changed null model. Where reasonable settings change an editorially relevant result, the honest conclusion is that precision needs clarification. Silent rewriting, as in F3, defeats this policy.

**Do not impose unconditional type-7 quartile reachability.** This is a model assumption, not a universal property of honest summaries. For example, `round(quantile(0:6,c(.25,.75),type=8),2)` gives 1.17 and 4.83. Type-7 quartiles for seven integer observations lie on a half-integer grid; those printed intervals cannot contain them. A type-7-only refusal would reject an honest alternative convention. R documents [nine quantile algorithms](https://stat.ethz.ch/R-manual/R-patched/library/stats/html/quantile.html). Check a declared convention when available; otherwise label a consistency concern or evaluate supported conventions. A corpus measurement can inform frequency, but cannot make a universal refusal valid.

**The row-p proxy needs a narrower promise; its gap is not necessarily small.** [Method history lines 586–591](../method-history.md#L586) acknowledges the proxy but calls it small. [API guide lines 175–180](../api-users-guide.md#L175) still says the trial p is therefore the most favourable reading. Those statements do not agree.

Here is an exact counterexample, including executable [finite-null convolution](evidence-2026-09-09/trial-proxy.R). Row A has arm totals 200 and 2000, event counts 0 and k, and their complements. The second arm prints 0.2%, compatible with k=3,4,5. Row B has counts `(1,4)` versus `(6,3)`. Enumerate each conditional hypergeometric null, transform its exact mid-p ranks to Stouffer z-scores, then enumerate the combined null.

| k | Exact Row A p | Exact trial p |
|---|---:|---:|
| 3 | 0.3756061 | 0.6435210 |
| 4 | 0.3414135 | 0.7857911 |
| 5 | 0.3103194 | 0.7599796 |

Choosing the greatest row p loses **0.1422701** in trial p. These exact values have no Monte Carlo intervals. The example does not cross 0.01 and does not measure how often an editorial classification changes. A diagnostic copy of `P_Calc()` forcing one 100000-replicate batch supports the calculation; the default staged run stops at M=1000 and has additional rank noise. Both outputs, including the engine's blank trial-CI field, are retained in [trial-proxy.txt](evidence-2026-09-09/trial-proxy.txt). The diagnostic clone is explicitly not the production stopping scheme.

Disclosure can justify a practical row-based exploratory method, but it cannot support “most favourable trial p.” For a potentially consequential result, jointly examine admissible row combinations when tractable; otherwise retain a sensitivity range or report reconstruction as unresolved. A larger, unsolved optimization problem is preferable to a false guarantee about an author's best case.

**The 0.01 straddle rule is a defensible attention policy.** Its rationale—avoid warning fatigue—is recorded in method history. Its coincidence with simulation escalation does not provide statistical validation; computational precision and editorial attention are separate decisions. Near the boundary, use uncertainty in the extrema to distinguish “definitely” from “possibly” straddling. A bounded search cannot certify the absence of a straddle. Row-wise straddles also do not answer the trial-proxy problem.

Actual hover notes always show best **and worst**, at [parseBaselineTableHeuristics.R:1165–1173](../../R/parseBaselineTableHeuristics.R#L1165); only the additional straddle wording and flags are conditional. Clarify whether the intended restriction applies to prominent warnings or also to hover detail. The current documents describe both policies.

**Separate three kinds of uncertainty for the reader:** simulation error conditional on a selected table; ambiguity about the counts and precision behind the page; and adequacy of the statistical model. More replicates address the first. They cannot repair a wrong partition, identify missing counts, or establish a quantile convention. This distinction should travel with the result, especially when it is copied into a workbook or API client.

## Coverage, passing checks and carry-forward items

I executed six relevant regression files: **140 assertions passed, zero failures/errors/skips** ([verification](evidence-2026-09-09/verification.txt)). These include the new whole-table and precision tests, the September 8 screen tests, SD draws, tie handling and known answers. Passing them does not cover the new counterexamples.

The previous small-unit/origin example no longer shows its former gross discrepancy: original, scaled and translated runs give respectively **0.163 [0.069,0.27]**, **0.1645 [0.073,0.27]**, and **0.164 [0.068,0.27]**, all M=1000, seed 42. That supports the earlier fix on this fixture; it is not proof of invariance at every magnitude. F6 concerns the newly chosen floor.

The September 8 queued zero-row, SD-bound, general precision-contract, Barnett-remedy and missing Summary-disclosure findings remain carry-forward items. The previously described percentage-endpoint convention also remains a separate concern; I have not counted its reappearance as a new finding. The method history now records the alternatives considered for whole-table reconstruction and the reason for selective warnings well. Its empirical and universal claims need the qualifications above.

I did **not** run a new population-wide honest-null false-alarm calibration, the entire package suite, a live deployment, or a corpus evaluation. The million-draw study is a conditional reference calculation, not an estimate of false accusations across honest papers. No application files, shared dependencies, branches or deployments were changed. Findings and proposed repairs await adjudication.
