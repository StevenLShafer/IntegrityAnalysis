# Independent statistical audit — fourth full pass, 2026-09-11

**Commit audited: `7c6583f7190ce581ab157b8f931ef5f39eba3789`. Outcome: two numerical P2 findings; no P1 found. The brief's condition for declaring the engine done is not met.**

The previous transposition and long-ID fixtures now pass. Two new cases remain: continuous and median rows can share exactly the same simulated null while receiving different score mappings, and a short literal trial ID can collide with the shortened spelling of a different long ID. Both affect the 0.01 screening decision. The first produces errors in either direction; the second demonstrably produces a false-positive result.

The user confirmed that this is the statistical audit in `REVIEW-BRIEF-chatgpt-statistics-2026-09-11-full2.md`, rather than a security screen. No production code was patched. All inputs are synthetic; no production endpoint, manuscript corpus, or live AI service was used.

## Execution and scope

The exact requested commit was loaded from an isolated checkout, whose tracked files remained unchanged. R **4.5.3**, Windows x86-64, locale `C`; the five packages specified in the brief were attached before `pkgload::load_all()`. All **121 locked dependency versions matched** the existing private library, used without updating it. [Runtime](evidence-2026-09-11-full2/runtime.txt), [versions](evidence-2026-09-11-full2/dependency-versions.csv), and [lock comparison](evidence-2026-09-11-full2/lockfile-comparison.csv) are retained.

The **50 selected regression files** produced **1,979 passing assertions**, **zero failures or errors**, **three skips**, and **three warnings**, across **293 test blocks**. This is a fresh execution of the relevant regression suite, not a claim to have executed the entire approximately 3,760-assertion repository suite. The real-HTTP tests were enabled. The skips and warnings are explicitly qualified below.

Independent work freshly re-executed the continuous F, direct observation-grid, median, exact categorical, staging, across-trial, fail-safe and pooling checks; 24 categorical recodings; 24 transpositions; 28 multilevel/permutation cases; 75 continuous/median key controls and three integer-reference executions; 16 old trial-ID boundary cases; and eight complete output comparisons with `6db32ee`. New work added **21 continuous/direct/median same-law cases**, **six million independent NumPy row simulations**, integer-event checks of the 12 focused cases, and four trial-ID identity controls. There were **24 additional authenticated loopback HTTP requests**, beyond the repository's HTTP regression tests.

All quoted engine probabilities below have their displayed interval or an explicit statement that none is displayed. **M means the actual final simulation batch**, not the 100,000 ceiling. Reference intervals are labeled separately. Scripts, fixtures, results and reproduction order are in the [evidence README](evidence-2026-09-11-full2/README.md).

## F1 — numerical P2: equal continuous and median null laws still receive different mappings

**Location:** `R/P_Calc.R:70` (`.iaNullKey()`), the common locations at lines 1038 and 1224, the key assignments at 1216 and 1424, and the pooled mapping at 1635. The key keeps each arm's individual `MEAN`. In the cases below, the simulation uses those values only through their N-weighted mean, which is identical across all variables. The observed between-arm statistic differs, as it should; that does not change the simulated null.

This is a new continuous/median counterexample, not a regression of the categorical relabeling or transposition fixtures. Sorting entire arm tuples is insufficient when a simulation input enters through an aggregate.

### Inputs and independent answer

The continuous fixture contains five variables V01–V05, two arms per variable, **N = 30, SD = 6, ROUND_MEAN = 0, ROUND_DISPERSION = 1, ROUND_OBSERVATION = 0**. Four variables have means **(0,0)**; V03 has **(-1,1)**. Every variable has common mean zero, the same two SD intervals [5.95,6.05], the same degrees of freedom and rounding, and the same full-observation simulation. The observed statistic is zero in four variables and two in V03.

The median fixture contains seven variables V01–V07, two arms per variable, **N = 9, Q1 = -1, Q3 = 1, SD blank**, with the same three precision columns **0,1,0**. All medians are **(0,0)** except V03, **(-1,1)**. Their pooled median is zero, their quartile-interval and bootstrap laws are identical, and all other simulation parameters agree.

For both fixtures, resetting two actual production generators to the same base-R and dqrng seeds produces **identical arrays of 1,000 null statistics**, despite their different keys. This is supported by inspection of the simulation inputs, not inferred merely from similar empirical distributions.

Let D be the absolute integer difference between the two printed means or medians. The row statistic is D²/2. Write q0, q1 and q2 for the probabilities of D = 0, 1 and 2. With a common mid-p mapping, the Stouffer score cost of D = 2 is between one and two times the cost of D = 1. Therefore, relative to an observed trial with exactly one D = 2:

- All D = 0, or exactly one D = 1 and all others zero, is strictly more homogeneous.
- Exactly one D = 2 and all others zero is a genuine trial tie, whichever variable contains it.
- Every other outcome is less homogeneous.

The population trial mid-p is consequently

`q0^J + J*q1*q0^(J-1) + 0.5*J*q2*q0^(J-1)`.

The independent [NumPy reference](evidence-2026-09-11-full2/symmetric-independent-reference.py) implements each model without any engine draw, ranking or fit helper. It uses PCG64, seed **9173**, and **2,000,000 replicates per row law**: normal full-observation draws, the direct approximation, and the median metalog/rounded type-7 bootstrap respectively. Integer differences determine q0/q1/q2. Simultaneous 95% Hoeffding bounds on these three probabilities are propagated through the positive polynomial above; interval arithmetic verifies the score ordering throughout that box. These are conservative **reference simulation bounds**, not app intervals or exact population probabilities obtained by enumeration.

| Fixture / engine seed | Engine p | Displayed trial interval | Actual M | Independent reference and its simultaneous 95% bounds |
|---|---:|---|---:|---|
| Five continuous variables / 42 | **0.008575** | **Not displayed** | **100,000** | **0.01073752**, **0.01051470–0.01096409** |
| Seven median variables / 43 | **0.01074** | **Not displayed** | **100,000** | **0.00958212**, **0.00938182–0.00978607** |

The reference bounds lie entirely on the opposite side of 0.01 from the corresponding engine results. The continuous case is a false positive relative to the implemented null; the median case is a false negative. Both return **HTTP 200**, `ok: true`, empty flags. The top-level HTTP `overallP` rounds these to 0.0086 and 0.0107; `resultsCsv` retains the values above.

**Interval adjudication:** these two trial intervals are not displayed, so there is no app interval whose containment can be assessed. The finding rests on an independent reference, a threshold reversal, and the exact misclassification of actual draws below. It is not a claim that an absent interval was exceeded. Other focused p/CI/M results, including a seven-variable continuous case whose displayed interval contains its reference, are retained in [symmetric-refined-comparisons.csv](evidence-2026-09-11-full2/symmetric-refined-comparisons.csv).

### Same-draw proof of the defect

The trace copies actual production statistics without changing them. Multiplying by two recovers integer D². A second check classifies complete trials using the integer events above, **without qnorm or a floating-point tie tolerance**. These counts agree exactly with an independent common pooled-rank calculation on the same draws.

| Case | Correct strict count | Correct tie count | Engine strict count | Engine tie count | Correct same-draw mid-p |
|---|---:|---:|---:|---:|---:|
| Continuous, J = 5, seed 42 | 820 | **417** | 820 | **75** | **0.010285** |
| Median, J = 7, seed 43 | 875 | **215** | **1,059** | **31** | **0.009825** |

For the continuous case, **342 genuine ties are lost toward the accusing direction**. For the median case, **184 genuine ties become strictly more homogeneous**, raising the p. This is not variation between independent Monte Carlo runs: it is a different classification of the very same trials.

For completeness, the reference strict/inclusive count intervals on these same draws are **0.00765036–0.01307439** and **0.00818206–0.01156293**, respectively. These broad diagnostic intervals include tie uncertainty and are not displayed by the app. They do not make the proven tie misclassification acceptable or replace the independent population-reference bounds.

The initial nine exploratory cases and the 12 focused cases cover the full continuous, direct and median branches. Every paired generator has identical output after resetting the seed, but two law keys. All 12 focused integer-event checks pass. Equal-N swaps of SD intervals, or quartile pairs, independently of the observed arm means provide further algebraic examples of the same overly literal key; their key inequality and inputs are recorded, without claiming an additional numerical finding.

**Fix-test path:** the [continuous CSV](evidence-2026-09-11-full2/fixture-symmetric-refined-continuous-J5-s42.csv) and [median CSV](evidence-2026-09-11-full2/fixture-symmetric-refined-median-J7-s43.csv) → real multipart `POST /analyze?seed=42` or `seed=43` → upload reader → validation → `P_Calc()` → `resultsCsv`. Assert the correct common-law integer counts, the independent references above, and the screening side of 0.01. Retain the categorical, arm-order and different-law controls. The [HTTP script](evidence-2026-09-11-full2/http-symmetric-null.R) confirms that untraced HTTP probabilities equal the traced handler results.

**Correction direction:** derive mapping identity from the effective simulation parameters, including their aggregates and symmetries, while retaining each row's own draws. Do not merely delete `MEAN` from the current key: the common location matters, and the direct-draw representability decision reads the magnitude of the individual means. Preserve the actual branch decision, precision grids, relevant dispersion-interval law and all other inputs that can alter the null. Reassess the pool admission count under any broader grouping. Increasing the tie tolerance does not repair two different estimated mappings.

Evidence: [initial trace](evidence-2026-09-11-full2/symmetric-null-checks.R), [focused trace](evidence-2026-09-11-full2/symmetric-refined.R), [integer events](evidence-2026-09-11-full2/symmetric-event-check.R), [independent reference values](evidence-2026-09-11-full2/symmetric-independent-reference.csv), [HTTP results](evidence-2026-09-11-full2/http-symmetric-null-summary.csv).

## F2 — numerical P2: generated and literal trial-ID spellings can collide

**Location:** `R/parseWideTable.R:379` (`.wideTrialId()`), called for markers at line 1034 and sheet names at 1048. IDs of at most 200 bytes are returned unchanged; longer IDs become a 184-byte prefix followed by ` #` and 12 digest characters. The resulting string is also used as the trial's identity.

Choose any long ID L and supply a different short ID S equal to the generated spelling `.wideTrialId(L)`. Then `.wideTrialId(L) == .wideTrialId(S)` by construction. **No two digest values need to collide.** The finding is about overlap between generated names and accepted literal names, not the accepted 48-bit fingerprint width.

The fixture's L is `"Synthetic identity "` repeated 12 times, followed by `A`: **229 bytes**. S is the corresponding **198-byte** generated spelling, ending in **` #a020339ac28c`**. The [identity table](evidence-2026-09-11-full2/trial-id-namespace-identities.csv) contains both full input strings and their identical outputs.

Each of two journal-style blocks has `Variable,Arm A (n=30),Arm B (n=30)` and one row, `"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"`. The reader silently makes these two differently named trials one four-arm Age analysis.

| Input/control, seed 42 | Trials retained | Result | Displayed intervals and actual M |
|---|---:|---|---|
| Wide CSV with distinct L and S | **1** | **0.005275** | **0.0048–0.0058**, **100,000** replicates |
| Template CSV with the same full distinct IDs | **2** | Trial p **0.1405** and **0.16**; overall **0.07139** | Trial intervals **0.11–0.18**, **0.12–0.20**; **1,000** replicates each. No overall interval displayed. |
| Wide CSV with two ordinary distinct short IDs | **2** | Same two trial results; overall **0.07139** | Same trial intervals and counts; no overall interval displayed. |
| Wide CSV repeating L twice intentionally | **1** | **0.005275** | **0.0048–0.0058**, **100,000** replicates; correct one-ID control |

Independent normal quadrature on the two control trial estimates gives **0.0713919338635497**. This is a deterministic combination of Monte Carlo estimates, not an exact population probability. It lies far outside the merged result's displayed interval. More fundamentally, that interval describes the wrong statistical experiment and cannot account for the reader's loss of identity.

Six actual loopback HTTP requests reproduce the collision and controls through **both `/parse` and `/analyze`**. All return **200**, `ok: true`, empty flags. The problematic `/parse` already returns one unique TRIAL; `/analyze` reports `trials: 1`. Its top-level rounded `overallP` is 0.0053. The template and ordinary-short-ID controls retain two trials through both endpoints.

The old pair of long IDs differing beyond byte 200 now stays distinct, as intended by #302. This counterexample instead uses one long and one short ID. An author could intentionally give two blocks the same original name, but that does not justify the parser silently equating two **different** supplied names; a previously shortened name can also be supplied literally in a subsequent input.

**Fix-test path:** [wide collision CSV](evidence-2026-09-11-full2/fixture-trial-id-namespace-wide.csv) → real multipart `/parse` and `/analyze?seed=42` → wide marker parsing → block assembly → validation → analysis. Preserve two identities and the two-trial result, or explicitly refuse the collision before analysis. Test alongside the [template control](evidence-2026-09-11-full2/fixture-trial-id-namespace-template.csv), two-short-ID control and intentional repeated-ID control. A helper-only length/digest test is insufficient.

Use a collision-safe mapping from original identity to bounded representation, or detect distinct originals resolving to one representation. A longer hash alone does not fix the overlap with literal IDs. Retain the existing reader bounds.

Evidence: [generator](evidence-2026-09-11-full2/trial-id-namespace.R), [handler results](evidence-2026-09-11-full2/trial-id-namespace-comparisons.csv), [HTTP execution](evidence-2026-09-11-full2/http-trial-id-namespace.R), [HTTP summary](evidence-2026-09-11-full2/http-trial-id-namespace-summary.csv), [faulty analysis reply](evidence-2026-09-11-full2/http-analyze-trial-id-namespace-wide.json).

## Regression checklist

Grouped assertion counts overlap and must not be added. The nonoverlapping total is **1,979**. Every status of **VERIFIED STILL FIXED** below refers to an executed case at the requested commit, rather than a reading of a test file. [Per-file totals](evidence-2026-09-11-full2/regression-summary.csv) and individual `regression-*.csv` files retain the test names and outcomes.

| Brief item | Status | Evidence / result |
|---|---|---|
| 2026-09-06: direct grid, replicate SD draw, precision, floor and trial interval lower end | **VERIFIED STILL FIXED** | Five named files: **57** assertions; independent full-observation grid reference below. |
| 2026-09-07: bounded ties, KIND, median draw/clipping, quartile intervals/precision, numeric resolution and stated grids | **VERIFIED STILL FIXED** | Six named files: **95** assertions; three independent median cases below. |
| 2026-09-08: coordinate-independent zero, whole-table fill, dispersion guard and precision disclosure | **VERIFIED STILL FIXED** | `screen-2026-09-08`, `failsafe-table`: **77** assertions; skipped subcases qualified below. Accepted queued decisions are not reopened. |
| 2026-09-09 F1/F2/F7/F8/F9: enumerate or decline, no inferred partition, no exponential fallback, same score/ties/floor, reader seed | **VERIFIED STILL FIXED** | Three files: **729** assertions; **188,251** candidates enumerated, oversized spaces declined. Independent free/partition case: **81 / 9** candidates. |
| 2026-09-09 F3–F5: supplied precision, exponent and CSV digits/case | **VERIFIED STILL FIXED** | `text-precision`: **53** assertions. |
| 2026-09-09 F6: replicate translated by its own first arm | **VERIFIED STILL FIXED** | **29** assertions, including fine precision and median cases. |
| 2026-09-10 delta F1: observed values cannot set zero tolerance | **VERIFIED STILL FIXED** | **15** assertions. |
| Delta F3: excluded blank categorical coverage and artifacts | **VERIFIED STILL FIXED** | Two files: **65** assertions, including **3 of 4 rows** coverage. |
| Delta F4: trial header/blank handling, structural issues, original sheet retained | **VERIFIED STILL FIXED** | Four named files: **69** assertions; independent partial-ID and duplicate-name HTTP cases return **422** with original data and null structural row. |
| Delta F2/F5: ranked selection is an accepted heuristic | **COULD NOT TEST as a numerical fix — a decision** | Verified by reading: best/worst among scored readings, superseded winner's-curse explanation marked. |
| 2026-09-10 full F1: original shared categorical law and bounded trial tie | **VERIFIED STILL FIXED for the reported cases** | **14** assertions; J9 seed 42 **0.01133**, no displayed interval, M **100,000**; J14 **0.00054 (0.000022–0.0012)**, M **100,000**. New continuous/median case is F1 above. |
| Same finding, bounded pool implementation | **VERIFIED STILL FIXED** | **22** assertions; independent planned **10,000,000** accepted / **10,100,000** refused. Accepted fixture actually uses M **1,000**. |
| Full F2: a wholly excluded trial stays listed | **VERIFIED STILL FIXED** | **21** assertions; independent HTTP preserves two trials, B says **No values**, **0 of 1 rows analysed**, with its excluded row. No p or interval for B. |
| Full F3: structural `row` is JSON null | **VERIFIED STILL FIXED** | Specific real-HTTP case **8** assertions, within **241** API assertions; independent raw bodies contain `"row": null`. |
| Security S1: duplicate columns preserved on refusal | **VERIFIED STILL FIXED** | **9** assertions; independent HTTP 422 retains both literal N headers and both value columns. |
| Security S2: AI levels do not overwrite N/MEAN/SD | **VERIFIED STILL FIXED** | **16** assertions; independent mocked transport preserves three count columns and blank reserved fields; **0.01345 (0–0.03)**, M **10,000**, exact reference **0.0120584457852**. |
| 2026-09-11 final-brief F1: categorical recoding and arm order | **VERIFIED STILL FIXED** | **33** dedicated assertions; all **24** independent recoding cases and four integer traces pass. J9/J14 values and M as above. |
| Final-brief F2: own versus pooled mapping documentation | **COULD NOT TEST numerically — documentation correction** | Verified by reading: distinction is present. The broader same-law guarantee remains incomplete for new F1. |
| Third full F1: transposition | **VERIFIED STILL FIXED** | **41** dedicated assertions; **24** independent cases and four traces. Transposed J9 seed 42: **0.01133**, no interval, M **100,000**; transposed J14: **0.00054 (0.000022–0.0012)**, M **100,000**. All **1,812 / 96** true ties retained, respectively. |
| Third full F2: two long IDs differing beyond the prefix | **VERIFIED STILL FIXED for the reported cases** | **30** dedicated assertions; **16** old boundary cases now retain two trials; six HTTP parse/analyze controls. Seed 42, delta 0.5: overall **0.07139**, no overall interval; trial **0.1405 (0.11–0.18)** and **0.16 (0.12–0.20)**, M **1,000** each. New literal/generated collision is F2 above. |
| Older direction, mid-p, staging, floor, seed, pooling and rounding | **VERIFIED STILL FIXED in executed cases** | Four files: **93** assertions; independent references below. |

**Three skips are not passes:** the hybrid fail-safe fixture did not take the hybrid route; the older nonpartition fixture exceeds the current enumeration cap; nimble is absent for the optional Barnett comparison. Those particular routes/outcomes are **COULD NOT TEST**. The explicit independent free/partition enumeration executes, and the remaining **62** dispersion assertions pass. [Exceptions](evidence-2026-09-11-full2/regression-exceptions.csv).

The three warnings are the expected embedded-NUL/incomplete-line warnings from intentionally reading raw gzip bytes as text. Sanitized warning text is retained separately. Three reader screen files contribute **40** passing assertions for raw reads and bounded strings; they do not cover F2's new overlap.

## Independent checks of the rest of the engine

### Continuous and median models

Fine-grid continuous references use the appropriate F law for the documented pooled inverse-chi-square model, independently of the production statistic helper. Engine seed is 42.

| Case | Reference | Engine p and displayed interval | Actual M |
|---|---:|---|---:|
| Two arms N = 3, equal SD | 0.1814509302 | 0.181 (0.16–0.21) | 1,000 |
| N = 5/17, SD = 1/2 | 0.0167983935 | 0.0136 (0.011–0.016) | 10,000 |
| Direct N = 100/125 | 0.0047523053 | 0.004645 (0.0042–0.0051) | 100,000 |
| Three arms N = 10 | 0.0039914205 | 0.004 (0.0036–0.0044) | 100,000 |

The unequal-N seed-42 interval misses. All prespecified seeds **42–61** were rerun: two of 20 displayed intervals miss, mean **0.0162925**, 95% t interval on that run mean **0.0157178–0.0168672**. This audit interval contains the reference. The isolated miss is retained, but does not establish a systematic implementation defect or a threshold reversal. [All runs](evidence-2026-09-11-full2/F-unequal-replications.csv).

For N = 100, SD = 3, integer observations and six-decimal printed means, a separate full-observation reference compares integer sample sums: **0.004815**, reference interval **0–0.0102547**, B **100,000**, seed **1927**. The direct engine gives **0.0047 (0–0.01)**, M **100,000**, seed **42**. The mean's h/N grid is preserved.

The independent base-R median reference uses scalar type-7 quantiles, interval draws, inverse bootstrap scaling, skew clipping and rounded observations, without production fit/draw helpers. At engine seed 42 and reference seed 9173:

| Median case | Engine p / displayed interval, M = 10,000 | Reference p / interval, B = 100,000 |
|---|---|---|
| Symmetric | 0.02285 / 0.018–0.029 | 0.02223 / 0.0191608–0.0254159 |
| Asymmetric | 0.06185 / 0.056–0.069 | 0.061615 / 0.0582492–0.0650494 |
| Skew clipped | 0.0436 / 0.021–0.069 | 0.04019 / 0.0193859–0.0616212 |

All three reference points lie inside the displayed intervals. Translation and power-of-ten unit cases remain compatible within their reported intervals; they are not claimed bit-identical. These checks establish implementation agreement for the selected model, not that a metalog fits every clinical population.

### Categorical laws and combination

Six single-variable laws were independently enumerated, including unequal arms, three-arm ties, four arms and a transposed 2×3 table. All exact references lie in the displayed intervals, at M **1,000**: exact/engine **1/3 / 0.3375 (0–0.70)**; **0.2625 / 0.2775 (0–0.59)**; **0.35 / 0.346 (0–0.72)**; **0.4949494949 / 0.4885 (0.38–0.60)**; **0.2157842158 / 0.214 (0.088–0.35)**; and **0.35 / 0.346 (0–0.72)**. The wide intervals are the app's strict/inclusive-count intervals, not narrowed by the audit.

For the independent binary law q = 2/3, six trial cases with J = 5, 15 or 16 and zero/one extremes agree with their exact binomial references. Full p/interval/M values are in [independent-comparisons.csv](evidence-2026-09-11-full2/independent-comparisons.csv); no interval-containment claim is made where the app prints none.

Exact rational enumeration supplies four further multilevel trial references. Each was executed seven ways: original, arms permuted, categories permuted, both permuted, a nonzero category moved into an otherwise absent column, an extra zero column, and disjoint category names.

| Arm/category margins; J | Exact reference | Engine p | Displayed interval | Actual M |
|---|---:|---:|---|---:|
| (2,2,6) / (3,7); 9 | 0.0835896145 | 0.0854 | Not displayed | 10,000 |
| (2,3,4) / (2,3,4); 3 | 0.002612244898 | 0.00246 | Not displayed | 100,000 |
| (3,3,3) / (2,3,4); 3 | 0.042507288630 | 0.03965 | Not displayed | 10,000 |
| (3,4,5) / (2,4,6); 3 | 0.000946262373 | 0.00093 | 0.00038–0.0016 | 100,000 |

**All 28 cases share the expected key, and all production strict/tie counts match integer classification of the actual draws.** All seven displayed last-law intervals contain the exact reference. [Results](evidence-2026-09-11-full2/multilevel-comparisons.csv).

The corrected transposition cases now match their untransposed controls exactly at seed 42. Their integer counts are **227 strict / 1,812 ties** for J9 and **6 / 96** for J14. All earlier categorical fixtures remain fixed; they do not exercise new F1's continuous/median aggregate equivalence.

### Keys, expectation, bounds and across-trial arithmetic

The **75** arm-key controls pass. Three-arm full/direct/median CSV analyses paired with arm-permuted copies agree with integer-lattice pooled ranks: **0.01255**, no displayed interval, M **10,000**, counts **125/1**; **0.1405**, no interval, M **1,000**, counts **140/1**; **0.000345 (0.00024–0.00049)**, M **100,000**, counts **34/1**. These are finite-draw reference checks, not analytical population probabilities.

**No false merger or missing row-specific simulation input was found** in the inspected keys and executed controls. The continuous key includes N, means, SDs and precision; the median key additionally includes quartiles; remaining settings are common process constants. The categorical key's unordered margin pair supports a probability-preserving permutation/transposition. F1 is the opposite problem: redundant individual inputs prevent recognizing equal laws. The negative controls do not prove that every different input vector implies a different law.

Eight complete outputs, including distinct-law continuous/median/category cases at 1,000 and adaptive 100,000 ceilings and two shared-law controls, are **identical to `6db32ee`**. [Comparisons with all p/CI/M values](evidence-2026-09-11-full2/old-target-comparison.csv).

At a fixed statistic, the raw empirical mid-CDF averages `I(X<t) + 0.5*I(X=t)`. Pooling independent draws from the same law preserves its expectation and divides its variance by G for equally sized groups. An independent 20,000-repetition experiment, q = 100/199, M = 1,000, G = 9, gives own/pooled means **0.251273225 / 0.251262906**, exact **0.251256281**, SDs **0.00787610 / 0.00262932**, predicted **0.00790559 / 0.00263520**. These are mapping estimates and sampling SDs, not displayed trial probabilities. No unbiasedness claim is extended to flooring, qnorm, optimization or adaptive stopping.

Independent exact binomial summation of fresh-batch stopping gives interval coverage **93.7365% at p = 0.009**, **95.4161% at 0.01**, and **95.3709% at 0.5** for an untied single-row null. This reproduces an acknowledged qualification, not a new finding.

The five fail-safe bounds and complete-enumeration-or-refusal behavior pass their cases. Free cell brackets yield **81** candidates versus **9** under an explicit partition. The ranked margin shortlist remains the accepted heuristic. The planned pool boundary accepts **100** shared rows and refuses **101** at the 100,000 ceiling, before drawing the latter; the accepted fixture actually uses **1,000** replicates. This is an admission-bound check, not a peak-memory benchmark.

Normal-density quadrature and an inverse-CDF root solve agree with `sumz()` on four vectors to maximum absolute difference **5.83 × 10⁻¹⁵**. This arithmetic is deterministic and has no Monte Carlo interval. Correct combination arithmetic does not protect against F2's loss of trial identity.

## Documentation, contracts and choices

**Overstatement demonstrated by execution:** the statements that equal simulated null laws receive one mapping remain incomplete for the common-location and dispersion symmetries in F1. The current account correctly describes the explicit grouping rule; that rule does not yet establish its broader guarantee. This is included in F1, not counted twice.

**Undocumented behavior and route inconsistency:** the new bounded-ID algorithm is documented, but its overlap with accepted literal IDs is not. The same distinct trial identities are preserved by the template route and merged by the wide route, without a flag. That is F2, rather than a criticism of the byte limit or fingerprint width.

**Verified by reading:** the own-versus-pooled mapping distinction is present; the obsolete winner's-curse account is marked superseded; the reconstruction paragraph includes interior bracket values; the partition exception is limited to a constructed complement; the API refusal list includes the pool ceiling. The changed transposition description matches the corrected categorical implementation and executed cases. AGENTS.md's relevant conversion, untrusted-model-output and console-privacy statements were inspected; the S1/S2 statistical conversion contracts were executed. This was not a fresh security attestation, and the tripwire was not rerun as part of this statistical audit.

The documents explain the principal defensible choices: lower mid-p, rounding, dispersion-interval draws, direct approximation, median clipping, strict/inclusive count intervals, ranked-search costs and shared mappings. The broader limitations of simulation-based combination and the queued zero/precision/Barnett/workbook items are not reopened as new findings. In particular, finite shared rankings do not by themselves prove universal binomial calibration.

**My views on the four recorded open decisions have not changed.** The two numerical P2 cases above are the reason this pass does not meet the brief's stopping condition.
