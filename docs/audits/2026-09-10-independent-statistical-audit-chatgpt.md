# Independent statistical audit of IntegrityAnalysis — 2026-09-10

Audited commit: **`ae37f0ee06d017d742049b7ab56ba79f2e39c99d`**, the exact commit requested in [the commissioning brief](evidence-2026-09-10/review-brief.md). Investigator: Codex. The shared checkout was at `8c54644`; execution used a separate archive of the requested commit. No application code was changed.

**Five new findings:** one numerical defect that crosses the screening threshold of 0.01; a failure of the ranked reconstruction's claimed optimum; loss of unresolved rows from coverage reporting; a lowercase-header API failure; and an unsupported direction-of-bias claim. The largest numerical defect is in the retained zero-snap tolerance: a three-row trial reports **0.00609**, while an independent integer-distance calculation on its very same simulated data gives **0.01979**.

The previously adjudicated findings listed in the brief are not counted again. In particular, F1 below concerns destruction of **unequal simulated values and their ranks**, not the repaired loss of ties between equal arms. F3 concerns loss **before the engine receives a row**, not the September 8 finding about the workbook's separate Summary sheet.

## Execution and interpretation

All inputs were synthetic. R 4.5.3 attached `shiny`, `dqrng`, `foreach`, `Rfast`, and `MBESS`, then called `pkgload::load_all()` on the archived source. The project dependencies were copied into a private library. Every copied package appearing in `renv.lock` matched its locked version after normalizing R's equivalent version punctuation. Some lockfile packages outside the copied dependency closure were absent; notably, no live plumber server was started. See [session metadata](evidence-2026-09-10/metadata.txt), [normalized version comparison](evidence-2026-09-10/versions.csv), and [warnings](evidence-2026-09-10/version-audit.txt). The locale was `C`; loading emitted Unicode translation warnings, retained in the evidence.

Unless stated otherwise, engine runs set both `set.seed(42)` and `dqset.seed(42)` and request `m=100000`. **M below is the actual final stage**, not that ceiling. The reconstruction uses its own built-in seed, 20260909. Exact finite-distribution probabilities have no Monte Carlo interval. The selector itself supplies no interval. App intervals are reproduced as printed; they bracket strict and inclusive tails and can be much wider than the uncertainty of a mid-p estimate.

The request-handler tests evaluate the actual `/parse` and `/analyze` function expressions from `inst/api/plumber.R` and pass synthetic raw file parts to them. For XML, they include the actual parse subprocess. They exercise the statistical and file routes, **not HTTP transport, authentication, or multipart decoding**.

[All scripts, fixtures, outputs and reproduction instructions](evidence-2026-09-10/README.md) are retained, along with [hashes of the audited source files](evidence-2026-09-10/audited-source-SHA256.txt). Tests in three relevant existing files completed with 121 successful assertions, no failures and two skips; the static security check passed all eight property groups. This was not a rerun of the full package suite.

## F1 — P1: the zero snap can collapse a row's entire simulated null and create an alarm

**Verified by execution through CSV upload → `.apiAnalyze()` → validation → `P_Calc()`, and by an independent calculation on the same draws.**

[The tolerance](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/P_Calc.R#L567) is

`1e-12 * max(max(observed translated arm differences^2), finest printed step^2)`.

[It is applied to every simulated statistic before ranking](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/P_Calc.R#L1459). An unusually large **observed** arm difference therefore determines what counts as zero in an otherwise ordinary **simulated** null. This can erase meaningful simulated variation even though the observed statistic itself is nowhere near zero.

The [six-line CSV fixture](evidence-2026-09-10/three-row-1e+07.csv) contains:

| ROW | N in each arm | Arm means | SD in each arm | ROUND_MEAN | ROUND_OBSERVATION | ROUND_DISPERSION |
|---|---:|---|---:|---:|---:|---:|
| X | 100 | 0, 10000000 | 1 | 4 | 4 | 3 |
| Y | 100 | 0, 0 | 1 | 4 | 4 | 3 |
| Z | 100 | 0, 0 | 1 | 4 | 4 | 3 |

All rows pass validation. At the final M=100000, X has **4292 distinct integer arm-distance values** and only **31 genuine zero statistics**. Its unsnapped statistic ranges from 0 to 0.1879458. The tolerance is **100**, so all 100000 statistics become zero. Every replicate's X rank then contributes z=0 to the combination, instead of its actual varying z-score. X's observed row p remains at the ceiling, so its observed contribution remains negative. The observed combination and its null no longer describe the same calculation.

| Quantity | Value | App's displayed 95% MC interval | M |
|---|---:|---|---:|
| X row p | 0.9999 | 1 to 1 | 100000 |
| Y row p | 0.00015 | 0 to 0.00043 | 100000 |
| Z row p | 0.00012 | 0 to 0.00036 | 100000 |
| Production trial p | **0.00609** | Not displayed at this p | 100000 |
| Independent same-draw trial reference | **0.01979** | Reference conditional interval below | 100000 |

The reference intercepts the simulated statistics **before** snapping without changing the draws. With two equal-sized arms, the statistic is `(mean1-mean2)^2/2`. Each printed mean is on the 0.0001 grid, so `round(sqrt(2*stat)/0.0001)` recovers an integer distance. Ordinary integer ordering and average ranks then give the row empirical mid-p values and their Stouffer combination, independently of `.iaZeroSnapTol()` and `.iaTieRank()`.

That calculation counts **1979** strictly-beyond trial replicates, with no ties. Collapsing only X reproduces the production count of **609**, also with no ties. Conditional Clopper–Pearson tail-count intervals are **0.01893571–0.02067230** and **0.005617167–0.006591814**, respectively. They do not overlap. These are additional diagnostic intervals, **not intervals displayed by the app**, and they do not include the uncertainty of estimating the component row p-values from the same batch. The paired destruction of known distinct values establishes the defect without relying on those intervals' nominal coverage.

A diagnostic function copy changing only the snap tolerance to zero reports **0.01978**; the one-replicate difference from the integer reference is within simulation resolution. Reducing X's difference to 1000 gives production trial p **0.0196**, M=100000, again with no displayed trial interval. The alarm introduced by making X still more heterogeneous is caused by the simulated ranks being collapsed.

**Scope and severity.** This is an extreme but accepted stress input, not a measurement of the frequency of false alarms in honest trials. It demonstrates a deterministic error in the trial null with an accusing-direction crossing of 0.01. A very heterogeneous row should not silently change how its null replicates are ranked.

**Repair target:** stop using the observed range to erase simulated variation. Equal arms already yield structural zero. Any residual numerical guard must be bounded using the arithmetic of the particular statistic and must preserve distinct attainable values. The replacement's test should upload this CSV with seed 42, run the full validation/analysis route, and compare with the saved integer-distance reference, rather than merely assert a different tolerance constant.

Code and full counts: [snap-reference.R](evidence-2026-09-10/snap-reference.R), [output](evidence-2026-09-10/snap-reference.txt), [saved draws and reference](evidence-2026-09-10/snap-reference.rds).

## F2 — P2: ranking margin groups by Pearson statistic does not certify either p extreme

**Verified by independent exact enumeration, by the actual selector, and through JATS and Word extraction.**

Within one fixed-margin null, lower mid-p is nondecreasing in the statistic. Across different margins, it need not be. A common asymptotic chi-square distribution does not make the finite conditional distributions identical. [The top/bottom-50 pruning](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/failsafeTable.R#L725) therefore is a heuristic.

For the 2×2 reference, enumerate the upper-left count x under fixed margins. Its probability is hypergeometric. Rank its statistic by the **integer** quantity `abs(grandTotal*x - rowTotal*columnTotal)`, avoiding floating comparisons altogether. Sum probabilities strictly closer to the null plus half the equal-distance probability. This is independent of the package's statistic, tie helpers and simulations. The distribution agrees with R's documented [hypergeometric law](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/Hypergeometric.html); [`r2dtable`](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/r2dtable.html) draws tables conditional on both margins.

### Best case outside the first 50

The [JATS fixture](evidence-2026-09-10/page-183.xml) and [Word fixture](evidence-2026-09-10/page-183.docx) state N=1000/200. Two race levels print percentages **(2,25)** and **(1,27)**; a footnote says other categories are omitted. The reconstruction therefore uses `partition=FALSE`, as intended. Its brackets are `(15..25,245..255)` and `(1..3,53..55)`.

There are **1089 candidate tables and 689 distinct margin groups**. The exact p-maximizing group's maximum statistic ranks **85th**, below the scoring cutoff.

| Reading, one pair of counts per arm | Pearson statistic | Exact lower mid-p |
|---|---:|---:|
| Global best: (23,246); (1,53) | 2.933592137713 | **0.9320444339788** |
| Best among retained 50: (24,245); (1,53) | 3.148046197191 | **0.9293437977457** |

The exact loss is **0.0027006362331**. Both real document routes select the second table. The production selector's estimate is 0.929275, with no supplied interval. `P_Calc()` with seed 42 reports **0.944, CI 0.91–0.97, M=1000** for those chosen counts. The available better reading's exact p is inside that broad app interval. This is a proved optimization failure, **not** a demonstrated threshold crossing or a significant discrepancy between the chosen table's engine p and its own null.

An exact-score diagnostic replaces only `.ppTableP()` with the independent oracle. With the actual rank limit it chooses the second table; allowing every margin group chooses the first. This removes selection noise as an explanation for the failure.

### The worst-case value can change away from the floor

Another [JATS](evidence-2026-09-10/page-153.xml)/[Word](evidence-2026-09-10/page-153.docx) pair has N=2000/200 and percentages **(1,10)** versus **(0,11)**. It admits 2646 tables and 1846 margin groups.

| Worst-case reading | Statistic | Exact lower mid-p |
|---|---:|---:|
| Global worst: (15,208); (1,22) | 0.1939877253808 | **0.1745037194288** |
| Worst among retained bottom 50: (11,205); (1,21) | 0.0124841085387 | **0.1952735325531** |

The true minimizing group ranks **313th** when ordered from smallest statistic. The omission raises the computed minimum by **0.0207698131243**, far above the selector's floor of 1/20001. The production document note reports worst p approximately 0.194, with no supplied interval. Thus the explanation that distant worst-case ranks merely identify interchangeable floor ties is not generally true.

The true worst table run through `P_Calc()` gives **0.183, CI 0–0.40, M=1000**. That broad interval contains both exact values; it does not invalidate the deterministic comparison of the two optimization objectives. Both exact minima are above 0.01, so this case does **not** demonstrate a missed straddle warning.

The reference sweep evaluated 171 configurations from 230 planned configurations after its explicit size/support filters: 100 partitioned and 71 nonpartitioned. Five omitted a better best value; 33 omitted a lower worst value. No worst-case omission in this sweep crossed 0.01, and no partitioned case omitted an extreme value. These are adversarial search results, not prevalence estimates or a calibration study. The two examples above were separately verified as admitted by the production selector.

**Repair target:** either certify bounds across omitted margin groups, or describe the result as the best/worst **estimated among retained candidates**. Keep complete enumeration distinct from complete scoring and from proven optimization. The current unconditional guarantee of the most favorable reading is false even with noiseless scores.

Evidence: [exact search](evidence-2026-09-10/rank-search.R), [results](evidence-2026-09-10/rank-search.csv), [actual parser outputs](evidence-2026-09-10/parser-cases.txt), [exact oracle through selector](evidence-2026-09-10/oracle-through-selector.txt).

## F3 — P2: fully unresolved category rows disappear before Summary coverage is counted

**Verified through JATS and Word, and through the actual API handlers including the XML parse subprocess.**

The [fixture](evidence-2026-09-10/flags.xml) has four variables: Age, ASA status, Weight, and NYHA class, with N=1200 per arm. ASA percentages 33/33/34 permit too many reconstructions and are correctly declined. NYHA percentages 33.3/33.3/33.4 can be reconstructed. Both blocks use level names I/II/III, testing the block-specific warning retraction at the same time.

The parser correctly retains two blank ASA lines, emits `approxUnresolved`, retracts ASA's fail-safe claim, and preserves NYHA's fail-safe warning. **That seam is repaired.** But [validation identifies fully blank lines as label-only](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/validateData.R#L576) and [removes them](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/validateData.R#L827). `P_Calc()` receives only three variables and has no way to count the fourth.

The returned Summary has a **blank NOTE**, rather than “3 of 4 rows analysed.” ASA is absent from the results, reconstructed journal table, and analysis response's `templateCsv`. The direct XML response still has its outer warning flags; posting the `/parse` response's CSV to `/analyze` loses those document flags as well and returns the same unqualified Summary.

The trial p is **0.001355**, actual M=100000 for all three analyzed rows; no trial interval is displayed because the p exceeds 0.001. The row outputs, with their intervals, are retained in the evidence. This finding does not assert that including unknown ASA counts should yield a particular p. It concerns the denominator of the coverage claim and loss of the repairable input row.

The method document and brief explicitly promise that **every reconstruction refusal is counted** on the Summary's “k of n” line. That promise is not met when all cells of the refused block become blank. It can encourage an editor to read a partial-table screen as covering the full baseline table.

**Repair target:** carry offered/refused variable identities through validation separately from usable numeric rows; preserve unresolved rows in correction payloads. A regression test must start from this XML or Word fixture, reach the API result, assert a 3-of-4 coverage note, and retain the ASA row in the returned editable template. Testing `reviewFlags()` alone would miss the defect.

Evidence: [route checks](evidence-2026-09-10/flags-and-checks.R), [parser/analysis output](evidence-2026-09-10/flags-routes.txt), [request-handler output](evidence-2026-09-10/document-api-handlers.txt), [saved response objects](evidence-2026-09-10/document-handler-flags.rds).

## F4 — P2: lowercase `trial` breaks the API's accepted-header and round-trip contract

**Verified through the actual `/parse` and `/analyze` handler functions.**

The user guide says column names are case-insensitive. The CSV value reader now preserves lowercase `mean`/`sd` text, but [`.apiReadUpload()` tests for the exact uppercase spelling `TRIAL`](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/apiService.R#L742) before normalization. With a lowercase `trial` column already present, it appends another `TRIAL` using the filename.

The [lowercase fixture](evidence-2026-09-10/precision-lowercase.csv) contains two ordinary continuous lines. `/parse` says `ok=TRUE` and returns a template with **both `TRIAL` and `trial`**. Direct `/analyze`, and `/parse` → `templateCsv` → `/analyze`, both fail validation because the names collide after case folding. The response's `issues` array is empty; the duplicate-name explanation appears only in the process log. Its recovery template can also replace the original trial identity with the filename, depending on the route.

For comparison, the uppercase counterpart analyzes at **p=0.004805, CI 0–0.01, M=100000**. No p is produced by the failing lowercase routes. This is an input-route failure, not evidence of a numerical p bias.

The mixed supplied/inferred precision and scientific-notation counterparts retain their values through the tested uppercase round trip. A supplied negative mean precision on an integer value also survives. A supplied precision finer/coarser than text still follows the validator's existing hybrid rules; the previously accepted broader precision-contract issue is not counted again here.

**Repair target:** recognize/normalize the trial column before adding a fallback; preserve the original identity and return a useful structural validation reason. The regression should invoke the actual handlers on the lowercase CSV, not stop after testing the text-preserving reader.

Evidence: [handler script](evidence-2026-09-10/followup.R), [complete output](evidence-2026-09-10/actual-api-handlers.txt), [response objects](evidence-2026-09-10/handler-lowercase.rds).

## F5 — P2 documentation: the winner's-curse claim confuses selection loss with estimation bias

**Verified by an independent experiment using the exact score sampling distribution.**

The [selector commentary](https://github.com/StevenLShafer/IntegrityAnalysis/blob/ae37f0ee06d017d742049b7ab56ba79f2e39c99d/R/failsafeTable.R#L142) and method document claim that exhaustive noisy ranking biased the “reported best case” low, toward accusation, and that noiseless statistic ranking cannot have that bias. Three quantities must be distinguished:

1. The largest **true** p among all allowed readings.
2. The true p of the selected reading, which can fall short of that optimum.
3. The selected reading's displayed **estimated** score, which is selected for being large and can be upward-biased.

For each candidate the exact 2×2 null gives probabilities of a strict hit, tie, or miss. Two binomial draws generate exactly the sampling law of a 2000- or 20000-replicate mid-p score. This avoids both the package simulator and a floating statistic. The experiment compares all-group selection with top-50 selection, each taking six coarse-pass winners and selecting the largest refined estimate. Both receive the same coarse draws and shared refinement draws for common candidates.

There are **2000 independent selection repetitions per configuration**, seed **998173**. The intervals below are 95% simulation intervals for the **mean effect across selection repetitions**, not app intervals or confidence limits for a single selected candidate.

| Configuration | Ranked minus exhaustive: mean true p of selected reading | 95% interval |
|---|---:|---|
| Case 183, N=1000/200, percentages (2,25)/(1,27) | **−0.00298942** | −0.00303893 to −0.00293990 |
| Case 153, N=2000/200, percentages (1,10)/(0,11) | **−0.00242201** | −0.00247045 to −0.00237357 |
| Case 181, N=5000/200, percentages (5,50)/(5,50) | **+0.00034750** | +0.00032394 to +0.00037106 |

Ranking improves selection in the third case and worsens it in the first two. Thus its performance advantage is conditional on the input, not guaranteed by the winner's curse.

Meanwhile, the exhaustive selector's **reported estimate minus the selected candidate's true p** is positive in all three cases: **+0.00162585** (95% interval 0.00157279–0.00167890), **+0.00150620** (0.00145962–0.00155278), and **+0.00414221** (0.00404494–0.00423948). The ranked selector also retains positive estimation bias because its final selection still maximizes noisy refined scores. Its initial statistic ranking is noiseless; its whole selection process is not.

This does not refute the particular before/after values supplied in the brief or the runtime reason for pruning. It refutes their interpretation as a universal direction of bias. Neither reconstructed score is the final independently simulated `P_Calc()` score. Selection can change the true p of the counts that reach that later analysis; an upward-biased selector estimate is a different quantity.

**Documentation repair:** record the reported measurements as measurements, label their explanation appropriately, and discuss optimization loss separately from score-estimation bias. Evaluate any future selection rule against an independent oracle and report its missed-optimum distribution, especially around 0.01.

Evidence: [independent experiment](evidence-2026-09-10/selection-noise.R), [case 183](evidence-2026-09-10/selection-noise-183.txt), [case 153](evidence-2026-09-10/selection-noise-153.txt), [case 181](evidence-2026-09-10/selection-noise-181.txt).

## Remaining brief questions and contract read-across

| Question | Result and scope |
|---|---|
| Does the new centering preserve genuine zero ties? | Yes in executed continuous and odd-N median cases. Removing the snap entirely left the repaired continuous p **0.00816, CI 0–0.017, M=100000**, and median p **0.01995, CI 0–0.044, M=10000**, bit-identical. A tested unequal-N row was also bit-identical. This is bounded evidence, not proof over every input. |
| Does the literal `1e-12 × step²` floor itself need to remain? | No remaining necessity was demonstrated. Equal values are structurally zero; for unequal lattice values a nonzero sum of squared deviations is not zero-valued dust. F1 is specifically caused by the **observed-range term** in the maximum, not by the printed-step term. Removing or retaining only the latter should be justified separately. The Stouffer sum has its own arithmetic and is not repaired by zero-snapping row statistics. |
| Is “All N readings … enumerated, and the K at each extreme … scored” numerically correct? | The tested document's **N=1089 and K=50** agree with the code: 50 group-maximum and 50 group-minimum candidate tables receive the initial score. It correctly avoids substituting the union count of 100 for K. But the ranking is of group extrema, six candidates at each end are refined, and the following unconditional largest-p guarantee remains false. |
| Can the gates decline an honest table? | Yes. A block of four arms × 25 levels with one two-way ambiguity was admitted; the same five-arm block was declined even with a grand total only 2376. At N=5000, three nonpartitioned percentage brackets for 25.0/42.0/33.0 can have feasible readings summing to N but upper endpoints totaling 5006; the upper-envelope gate declines the whole block. These are conservative resource decisions, not numerical findings. |
| Do the documented bounds match the code? | Not completely. The method text still lists only three bounds; the code also enforces the 100-cell scoring gate and the table-total/row-total limits. It also first describes all candidates as summing to N and later correctly says that only constructed complements are constrained. The first sentence should be removed or qualified. |
| Does chunking change the categorical stream? | No in the executed checks. A draw of 1234 tables was bit-identical, including final RNG state, to draws of 17+503+714 on two distinct 3-arm tables. The chunk-size calculation was also inspected. This supports the stated stream property; it does not certify a hardware-independent ten-second runtime ceiling. |
| Are all refusal paths now cheap before construction? | The count-before-build, per-arm 5000 ceiling, five-million-cell budgets, table dimensions and upper-envelope total checks precede candidate construction/scoring in the inspected source. This audit did not attempt resource exhaustion or certify a process memory ceiling. |
| Do flags cross the document seams? | JATS and Word preserve unresolved and straddle flags in executed fixtures; shared level labels no longer cancel the other block's warning. The corresponding TATR return-field forwarding was verified by reading, without invoking Python or the model. F3 lies after those repaired seams. |
| Does the API preserve inferred/supplied precision on round trip? | The uppercase mixed, scientific, and supplied-coarse cases passed the executed handler comparisons. The lowercase trial-header exception is F4. No new failure of the repaired exponent or CSV value-text handling was found in these cases. |

A further explanatory qualification is appropriate wherever the documents call the combination “exact” or “calibrated by construction”: it is a simulated combination under the stated independent-row models, with discrete mid-p conventions, estimated distributions and staged sampling. The documents already disclose important parts of this. The term should not imply exact finite-sample calibration for every real trial or dependence structure. This is clarification of scope, not a sixth finding.

## Opinions on the four open decisions

**1. Supplied precision: retain accept, bound, and disclose.** Printed numeric values alone cannot recover trailing zeros, underlying observation resolution, or a deliberate tens/hundreds rounding convention. Inferring exclusively from the stored numbers would replace supplied information with another assumption. Keep source text and distinguish supplied from inferred metadata throughout exports. Require consistency where the data can establish it, and make a precision-dependent alarm conditional on checking that metadata. The current mean and dispersion inference rules are not identical; explain that explicitly rather than calling both simply “preserved.”

**2. Median/IQR consistency: measure before imposing a new refusal.** A corpus can estimate how often a proposed rule affects manuscripts, but cannot by itself establish a false-positive rate under honest randomization. Use synthetic distributions with known observation grids, both odd and even Ns, tied quartiles, and the actual quantile convention to test any new rule. The inverse-bootstrap scale, ordering of drawn quartiles, uniform interval draws and skew clipping are modeling choices; their empirical justification should not be described as a universally conservative finite-sample guarantee. No new median refusal is recommended from this audit alone.

**3. The row-p proxy: disclosure is necessary but does not certify a trial-level benefit of the doubt.** Even exact row maxima need not maximize the simulated combined trial p, because changing a row changes its null as well as its observed score. The existing narrowed language is an improvement. For a consequential decision near 0.01, require the original counts or a trial-level sensitivity calculation; an unqualified “best case for this trial” remains unavailable. Do not reintroduce an expensive unbounded search to manufacture that claim.

**4. Ranked scoring: retain the runtime decision only as an explicit heuristic, or add certification.** The independent measurement supports improved selection on one shape and worse selection on two others. It does not justify the general claim of less accusing bias. Restate the rule as “enumerate completely or decline; score a bounded candidate set; report what that set supports.” If the product requires a guaranteed most-favorable reading, a non-certified ranked result must remain unresolved. The choice is between product contracts, not between two algebraically equivalent optimizations.

The immediate numerical priority is F1. F2 and F5 require a deliberate decision about the reconstruction guarantee. F3 and F4 have concrete regression fixtures and straightforward contracts to preserve. No production changes or deployments were made during this audit.
