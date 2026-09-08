# Independent statistical audit of IntegrityAnalysis

Date: 2026-09-08. Auditor: GPT-6 (Codex). Audited commit: `088a78cb2d3f0c36179783e1e3aa5ddf7a3296be`.

**Disposition:** F1–F7 and documentation corrections below await adjudication. This report changes no application code. Previous audit findings are not reissued.

I ran R 4.5.3 against the project library, using synthetic inputs only. [Evidence and commands](evidence-2026-09-08/README.md) include independent enumeration, simulation, complete frames, outputs and session metadata. Seven selected existing test files passed. No new corpus calibration or deployed-app test was performed.

For engine examples, attach `shiny`, `dqrng`, `foreach`, `Rfast`, `MBESS`, then `pkgload::load_all()`. Unless stated otherwise, use this wrapper; it prints actual `M`, because `m=100000` is a ceiling:

```r
run <- function(d, validated=TRUE) {
  set.seed(42); dqrng::dqset.seed(42)
  v <- shiny::isolate(validateData(d))
  stopifnot(!v$FAIL)
  shiny::isolate(P_Calc("T", if(validated) v$DATA else d,
                       v$CategoryNames, 100000))
}
```

The brief's “inside the interval means agreement” rule is insufficient here. With ties, the reported interval brackets strict and inclusive tails; it can remain wide with unlimited simulations. I distinguish ordinary Monte Carlo differences from exact arithmetic or model-invariance failures.

## Findings

### F1 — P1: the remaining zero snap changes answers with units and origin

**Run and read:** `R/P_Calc.R:1206,1312–1313`; analogous median threshold at `1028`.

```r
d <- data.frame(TRIAL="T", ROW="X", N=c(10,10),
  MEAN=c(0,.1), SD=1, ROUND_MEAN=1,
  ROUND_OBSERVATION=1, ROUND_DISPERSION=1)
run(d)
e <- d; e$MEAN <- e$MEAN*1e-13; e$SD <- e$SD*1e-13
e[c("ROUND_MEAN","ROUND_OBSERVATION","ROUND_DISPERSION")] <- 14
run(e)
```

Both validate. The engine returns **0.163 versus 0.4965**, both at M=1,000; the latter acquires an erroneous `attainable floor` note. Independently simulating the full rounded normal model gives **0.1737645**, SE **0.0003173**, at one million draws, seed 19371. A ten-power unit conversion preserving every grid must retain that answer.

Also, starting with `MEAN=c(0,.00001)`, `SD=.0001`, all precisions 5, adding `1e9` to the means changes p **0.167 → 0.497**, M=1,000. Both pass the numerical-resolution guard.

The statistic is already computed after translation, but values below `1e-26*(1+center^2)` are subsequently erased. This threshold is neither scale nor translation invariant. **Fix:** remove this redundant snap or replace it with a justified error bound that preserves the grids. General arbitrary translations need not preserve rounding; these examples deliberately preserve its phase and units.

### F2 — P1: percentage reconstruction does not deliver its promised conservative p

**Run and read:** `R/armNRecovery.R:88–99,145–200`; `R/parseBaselineTableHeuristics.R:735,980–1015`; guarantee in `docs/statistics.md:355–388`.

There are three separate failures.

**Changing counts changes the reference distribution.** With N=(101,1001), percentages (0,0) admit counts (0,k), k=0…5. Maximising Pearson selects k=5. For k=1 or 5, all events in the larger arm attain the minimum statistic under those margins, so the exact mid-p is

`0.5 * choose(1001,k)/choose(1102,k)`.

```r
counts <- function(k) data.frame(TRIAL="T", ROW="X",
  N=NA_real_, MEAN=NA_real_, SD=NA_real_,
  Event=c(0,k), Other=c(101,1001-k))
run(counts(1)); run(counts(5))
```

| Possible original / selected | Exact mid-p | Engine | M |
|---|---:|---:|---:|
| k=1 / original | 0.4541742 | 0.451 | 1,000 |
| k=5 / selected | 0.3089112 | 0.3185 | 1,000 |

Each simulation agrees with its own reference. The promised ordering fails **exactly**, independently of simulation noise. Maximising a statistic across different margins does not maximise its lower-tail probability.

**Multicategory reconstruction violates arm totals.** A synthetic PDF declares N=200 per arm and category percentages (34,32,34) in both arms. With `pctApprox=TRUE`, the parser returns:

```r
d <- data.frame(TRIAL="T", ROW="Race, %", N=NA_real_,
  MEAN=NA_real_, SD=NA_real_, Asian=c(69,67),
  White=c(65,63), Black=c(69,67))
run(d)
e <- d; e$White <- c(63,65); e$Black <- c(68,68)
run(e)
```

The reconstructed totals are **203 and 197**. The possible original `e` totals **200 and 200**, and every percentage rounds to the same page. Exact conditional enumeration gives **0.004117601 versus 0.04020610**; the engine gives **0.00417**, M=100,000, versus **0.043**, M=10,000. Categories are maximised separately as binary variables, then combined into a different multilevel statistic. The original reference is outside the reconstruction's reported interval, 0–0.0089.

**Bracket endpoints can contradict rounding.** `.ppCountBracket(49,0,200)` includes 97 and 99, which print as 48% and 50% under the retained half-even convention. Only 98 prints as 49%. Including both endpoints also disagrees with ordinary half-up rounding.

**Fix:** reconstruct jointly under arm-total and rounding constraints; use the largest conditional p over admissible tables, or report a sensitivity range/unresolved counts. Do not claim conservatism from maximising Pearson. Account explicitly for unknown rounding conventions. These examples disprove the bound; they do not estimate a population false-alarm rate.

### F3 — P2: an honest all-zero row is refused

**Run and read:** `R/P_Calc.R:267–279,755–757`; false impossibility claim in `docs/statistics.md:440–448`.

```r
d <- data.frame(TRIAL="T", ROW="X", N=c(10,10),
  MEAN=0, SD=0, ROUND_MEAN=2,
  ROUND_OBSERVATION=2, ROUND_DISPERSION=0)
run(d); d$MEAN <- 1; run(d)
```

Ten identical zeros legitimately print mean **0.00**, SD **0**. Nevertheless, validation passes and the engine refuses the row for mismatched precision; M is blank. Adding one to every observation yields **0.5**, M=1,000. Under the existing exact-zero-SD model, **both answers must be 0.5**.

The guard imposes an unjustified relation between location and dispersion precision whenever all numbers are zero. **Fix:** exempt exact-zero-SD continuous rows and remove the assertion that different precisions are impossible. Coarsely printed zero quartiles pose an identifiability question, not this arithmetic contradiction.

### F4 — P2: the SD bound is necessary, but not sharp as claimed

**Run and read:** `R/P_Calc.R:313–368`; `docs/method-history.md:691–699`.

```r
d <- data.frame(TRIAL="T", ROW="X", N=c(1000,1000),
  MEAN=c(200,201), SD=250, ROUND_MEAN=0,
  ROUND_OBSERVATION=-3, ROUND_DISPERSION=0)
run(d)
```

It passes and gives **0.0512**, M=10,000, although the stated sample cannot exist. For observations on hℤ with exact mean μ, let t be the fractional part of μ/h. Minimising squared deviations puts observations on the two adjacent lattice points, giving

`s_min = h * sqrt(N*t*(1-t)/(N-1))`.

Here the first arm's printed mean interval admits only mean 200; hence its minimum SD is **400.2002**, above the entire printed SD interval [249.5,250.5]. There is no legitimate reference p for these claimed inputs. Independent enumeration of every sample on {0,1,2,3}, N=2…7, verifies and attains the formula.

The implemented inequalities are valid necessary bounds; the error is calling them sharp and treating them as a completed consistency check. **Fix:** minimise the sharp bound over reachable means in the printed interval, retain the exact-zero exception, and document precisely what remains unchecked.

### F5 — P2: precision normalization and simulation have different contracts

**Run and read:** `R/validateData.R:394–405,582–586,632,647–649`; `R/P_Calc.R:700–711`.

```r
d <- data.frame(TRIAL="T", ROW="X", N=c(10,10),
  MEAN=c(1.1,1.2), SD=1, ROUND_MEAN=0,
  ROUND_OBSERVATION=1, ROUND_DISPERSION=1)
run(d, FALSE); run(d, TRUE)
```

The direct call refuses inconsistent precision; validation silently changes `ROUND_MEAN` to 1 and produces **0.163**, M=1,000. Thus the documented promise that supplied precision is preserved/refused is route dependent.

Furthermore, nonfinite/out-of-range precision is silently replaced by inference; fractional precision is accepted. The frame below returns **0.815**, M=1,000:

```r
d <- data.frame(TRIAL="T", ROW="X", N=c(100,100),
  MEAN=c(50,52), SD=10, ROUND_MEAN=0,
  ROUND_OBSERVATION=-.5, ROUND_DISPERSION=0)
run(d)
```

`10^(-d)` treats this observation grid as √10, while `round(x,-.5)` rounds to integers. There is no single stated rounding model to assign a correct p to. Missing mean precisions also differ: validation can propagate another arm's *supplied* precision, whereas direct inference uses numeric digits only (additional reproduction in evidence).

**Fix:** one normalization contract, whole-number precision or NA, explicit disposition of invalid supplied values, and preserved supplied/inferred provenance. Document repairs if repairs are intended.

### F6 — P2 documentation: Barnett does not fill the arm-SD blind spot

**Run and read:** `docs/statistics.md:465–482`; `R/dispersionTest.R:147–155`.

```r
d <- data.frame(TRIAL="T", ROW=rep(c("A","B","C"),each=2),
  N=100, MEAN=c(50,52,100,104,20,21), SD=10,
  ROUND_MEAN=2, ROUND_OBSERVATION=2, ROUND_DISPERSION=14)
a <- barnettTStats(d)
d$SD <- rep(c(2,14),3)
b <- barnettTStats(d)
identical(a,b)
barnettDispersion(a); barnettDispersion(b)
```

Result: **TRUE**, with identical `pDispersed=0.5889293` (deterministic; no seed/M). Both SD pairs pool to variance 100. Barnett measures dispersion of standardized contrasts, not disagreement between arm SDs. **Correct the new remedy claim**, distinguishing these two meanings of dispersion. This is not a repeat finding that the primary screen ignores arm-SD disagreement.

### F7 — P2: the workbook overview loses the refusal disclosure

**Run and read:** `R/baselineTable.R:271–278,315–318`.

```r
d <- data.frame(TRIAL="T", ROW=c("Zero","Zero","Other","Other"),
  N=10, MEAN=c(0,0,1,1.1), SD=c(0,0,1,1),
  ROUND_MEAN=2, ROUND_OBSERVATION=2, ROUND_DISPERSION=0)
v <- shiny::isolate(validateData(d))
set.seed(42); dqrng::dqset.seed(42)
x <- shiny::isolate(P_Calc("T",v$DATA,v$CategoryNames,1000))
writeResultsWorkbook(x,v$DATA,v$CategoryNames,"partial.xlsx")
```

The engine's Summary correctly says **1 of 2 rows analysed**, p=0.168. The workbook's separate **Summary sheet** drops NOTE and presents that p without coverage. Test Results retains it. **Fix:** carry coverage onto every trial overview and aggregate export; the qualification must travel with the number.

## Actual contract and remaining documentation gaps

The following is **by reading**, except reproductions already identified.

**Input:** `P_Calc(TRIAL,DATA,CategoryNames,m,graphs=NULL)` is an internal function. There is no generated `?P_Calc` topic/export; the detailed contract is roxygen under `@noRd` (`R/P_Calc.R:575–680`). It expects normalized numeric columns, one record per arm/variable, grouped by TRIAL/ROW; no arm identifier is used. Required columns are TRIAL, ROW, N, MEAN, SD. Counts require named `CategoryNames`, with N/MEAN/SD blank. Complete Q1/Q3 plus N identify medians, stored in MEAN. SE alone is not converted. Direct calls require well-formed input and bypass validator/service caps.

Blank mean precision takes variable-wide digits, blank observation precision follows it, and blank dispersion precision takes variable-wide SD or quartile digits. F5 qualifies the apparent agreement with validation. The validator normalizes aliases, converts long categories, checks finite numeric values, nonnegative whole counts, integer N≥2, arm N≤5,000 and magnitudes **strictly below** 10¹². These are not all engine checks. API table caps (5,000 records, 200 columns/trials) and the 12-billion compute budget are service gates; §7 agrees with their constants.

**Analysis:** normal rows draw SDs uniformly over printing intervals (zero is exact), pool by df, draw inverse-chi-square variance and a common location, then simulate rounded observations/means. Eligible large arms use the normal approximation on h/N. Median rows draw/order quartiles, pool/refit, bootstrap rounded type-7 quartiles, invert the scale ratio, and simulate rounded medians. Locations use the unweighted sum of squared deviations about the N-weighted centre. Categories remove wholly empty levels and use fixed-margin Pearson lower tails. Fresh batches are 1,000→10,000→m, with all usable rows advancing together. Trial combination ranks simulated row statistics, sums z-scores, and compares with its simulated null. Across trials, consumers use closed-form `sumz()`.

**Output:** character/display columns TRIAL, ROW, P, CI95, M, NOTE, KIND; variables, one summary, one NA spacer. TRIAL appears only on the first variable. P may be refusal text or `<0.0001`; KIND identifies summaries. Refusals have blank CI/M. Zero usable rows give `No values`; one usable row copies its p **and CI at any p**; multiple rows show summary CI only below .001. Notes combine floor, skew clipping, flat quartiles, precision disclosures; summary NOTE counts refusals.

The refusal predicates, in evaluation order, are:

| P text | Actual trigger |
|---|---|
| `Only 1 Row` | Fewer than two records for that variable |
| `An arm with fewer than 2 patients cannot be simulated` | All arm Ns present and at least one below two |
| `The stated precision does not match the printed values (...)` | Any stated-grid, observation-location, zero-row or SD-grid check fails |
| `Printed precision beyond this magnitude's numerical resolution (...)` | Finest relevant grid below eight epsilon-times-magnitude units |
| `Mixed SD and quartile lines` | Median branch has any missing Q1 or Q3; the predicate is missing quartiles, not simply the presence of an SD |
| `Quartiles do not increase (Q3 must exceed Q1)` | Q3 is below Q1 beyond numerical tolerance; equality is allowed |
| `Incomplete category counts across arms` | A selected category remains missing in some arms |
| `Degenerate category table (an arm or every remaining category is empty)` | Empty arm or fewer than two nonempty category levels after dropping empty columns |

These are engine refusals, distinct from validation failure before simulation. Rename the quartile refusal to describe decreasing quartiles; its parenthetical incorrectly implies equality is prohibited.

Additional corrections, **P3 unless indicated**:

- `statistics.md:329`, `user-guide.md:976`, `api-users-guide.md:246` omit the one-usable-row CI exception. API/user-guide NOTE inventories omit the coarse-precision note; `statistics.md:330` quotes its superseded wording. The fine note can trigger when locations agree after rounding to their least displayed precision, not only when exactly equal (`P_Calc.R:411–425`). Synchronize wording and predicates.
- `P_Calc.R:975,994` floors fitted IQR at 0.01 of the finest printed unit and bootstrap IQR at one unit. The latter changes **positive sub-unit** pooled widths too, not only zero resamples. Document both constants, effects and rationale; disclose that replicate-level clipping need not produce the observed-fit skew note.
- “Right average” over an SD interval (`statistics.md:148`) assumes uniform weighting. Rounded summaries alone do not imply that distribution. State it as a modelling choice, including independent quartile draws; the draw is not conditional on their jointly enclosing the printed median.
- `method-history.md:547–553` still says twelve-arm exhaustive search; current limit is eight. Its later “Ideas” list leaves coarse quartiles unmeasured despite the newer experiment. Update chronology/configurations. Label calibration results by engine commit and population; they do not establish arbitrary-table guarantees.
- Tie helpers do not literally use one equivalence rule (`P_Calc.R:90–109`): for `c(1,1+9e-11,1+18e-11)`, ranks merge all three transitively, while observed counts tie only two with the first. **P2 investigation:** adopt one grouping convention. This is a run helper counterexample; an accepted-table p consequence has **not** been demonstrated.
- The source's “calibrated by construction at every rounding and every N” (`P_Calc.R:44`) overstates what null simulation proves. It preserves the specified model, not its applicability or empirical calibration.

The rationale for mid-p, staged precision, simulated within-trial combination, inverse-bootstrap scale, retained half-even rounding and the inherited location draw is already recorded in method history. Preserve those decisions and their measured tradeoffs; document the additional constants above with the same discipline. A numerical convenience should not silently become a statistical assumption.

## Decisions and further explanation

**Keep supplied precision**, with provenance and sensitivity analysis. Inference alone does not close manipulation: the manuscript also controls printed digits, and spreadsheets lose zeros. Separate measured observation resolution, printed precision, and inferred defaults. An editor should be able to see which assumption changes an alarm. Arithmetic checks cannot certify the assumption's truth; F1–F5 show why a sequence of local guards is not that certification.

**Do not impose an unconditional type-7 quartile refusal.** For the honest integer sample `0:6`, type-8 quartiles are 7/6 and 29/6, printing 1.17 and 4.83. Type-7 quartiles of seven integer observations must be half-integers. The proposed rule would reject honest data. R explicitly supports [nine quantile definitions](https://stat.ethz.ch/R-manual/R-patched/library/stats/html/quantile.html). Require a known convention for a hard check; otherwise disclose uncertainty. Corpus testing measures frequency, not logical legitimacy.

**Coarse quartiles need an identifiability explanation.** Uniform intervals, ordered pairs, clipping and scale floors are substantive choices. Lowering mean honest p toward .5 is not sufficient justification for a replacement. A defensible research alternative is a rounded-order-statistic likelihood with stated support/quantile convention and a sensitivity envelope over plausible spreads. There is no uniquely less-conservative answer in an uninformative printed interval. Bounded scores and zero inflation particularly need study before general reassurance.

Explain that a large p may mean little information, and a small p warrants checking allocation, extraction and precision. Neither is a probability of fraud. Before expanding heuristic refusals, prioritize joint percentage reconstruction, dependence/duplicate-variable experiments, bounded median populations and many-arm calibration.

## Checked and sound within scope

- Independent fixed-margin enumeration agrees with the categorical engine in the new cases; reconstruction is the failure.
- The old categorical tie fixture now gives 0.346 versus exact 0.35; five rows give 0.0831 versus exact 0.084. Their existing regression tests pass.
- The ordinary rounded-normal example agrees with the independent million-draw calculation.
- The positive-SD inequalities are necessary; the stronger formula was independently enumerated.
- Direct defaults, numeric-resolution, quartile precision/draw and percentage-search tests pass their selected fixtures. This is not a blanket calibration claim.
