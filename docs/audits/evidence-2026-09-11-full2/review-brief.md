# Independent statistical audit of IntegrityAnalysis — brief for the fourth FULL pass

Written 2026-09-11 (midday) for the audit Steve Shafer will commission
next. Your previous pass (the third full pass of 2026-09-11, committed
verbatim at `docs/audits/2026-09-11-full-independent-statistical-audit-chatgpt.md`
with its 565 evidence files) re-verified every earlier finding - 1,896
assertions, independent references, loopback HTTP - and found two
numerical P2s: F1, TRANSPOSING one categorical table (exchanging its
arm totals and its category totals) preserved the fixed-margin law but
not the shared null-law key, which sorted within each margin but kept
the two in order, splitting genuine trial ties again in the
false-positive direction; F2, the 200-byte clip of a journal-style
trial id made two distinct ids that share their first 200 bytes one
trial, feeding four arms of one trial to the engine where the file
described two two-arm trials (overall 0.071 read 0.0053, no flag).
Both are fixed and merged, your fixtures are the tests, and the
security screens of the fixes are in the log.

This brief asks the same question as the last three: **a full audit of
the engine as it stands.** Steve's rule is unchanged - a round that
returns a numerical P2 is not done, so this is another full pass; if
it returns no P1 and no numerical P2, the engine is declared done and
the effort moves to corpus validation.

Read this whole file before starting. "What NOT to re-report" matters
as much as the rest.

---

## What this instrument is, in one paragraph

IntegrityAnalysis is a Carlisle-style screen. It takes a randomised
trial's baseline table — arm sizes, means and dispersions, medians and
quartiles, category counts — and asks whether the arms are *more alike*
than random allocation would make them. Every p is one-sided **toward
homogeneity**. Rows combine within a trial by an exact combination of the
Stouffer sum against its own simulated null; trials combine by the
closed-form `sumz()`. A small p is a screening signal that a journal
editor investigates, never a verdict. The threshold that matters here is
**0.01**, not 0.05. The instrument's purpose is to flag tables for
review; a defect that changes what an editor is shown matters, a
refinement does not.

---

## The commit

Audit `main` at commit **`7c6583f`** (2026-09-11, 11:05 PDT), the tip
after the F1 fix (#301), the F2 fix (#302) and their log rows merged.
Check that commit out. Production runs it (the API reports the last
code commit; the app reports the tip). The whole suite (about 3,760
assertions, the real-HTTP tests on) and the static tripwire pass on
it. If `main` has moved on by the time you start, the brief still
names `7c6583f`.

---

## The deliverables

**1. The regression checklist — every adjudicated finding, re-verified.**
For each item, construct or reuse an executable case, run it against
`7c6583f`, and report VERIFIED STILL FIXED / REGRESSED / COULD NOT TEST
with the number. The reports and their evidence directories are in
`docs/audits/`; `docs/method-history.md` describes each change and what
was measured; `tests/testthat/test-audit-*.R` and `test-screen-*.R`
carry the tests built from each report through the report's own path,
and you may reuse their fixtures. Your own `same-draw-combination.R`
and the nine-binary-row CSVs are now `test-audit-2026-09-10-full-f1.R`.

| round | finding, in one line | `method-history.md` entry | where the test lives |
|---|---|---|---|
| 2026-09-06 (in-session) | the direct draw for large arms keeps the mean's grid; the SD is drawn per replicate within its printed interval; explicit precision is kept; the attainable-floor label; the trial interval's lower end | "2026-09-05 — the direct draw for large arms", "2026-09-06 — the SD is drawn per replicate", "— precision inference", "— the SD's printed rounding is drawn", "— the trial interval's lower end" | `test-pcalc-direct.R`, `test-sd-rounding-draw.R`, `test-sd-interval-cells.R`, `test-validate-rounding.R`, `test-known-answer.R` |
| 2026-09-07 | ties decided by a bounded numerical criterion; the summary line identified by KIND; the median/IQR parameter draw and the skew limit clipped; the quartiles' printed precision and intervals entering the fit; a row whose printed precision the arithmetic cannot carry; a stated precision has to describe the number beside it | the seven "2026-09-07 —" entries | `test-tie-criterion.R`, `test-summary-kind.R`, `test-median-iqr.R`, `test-quartile-draw.R`, `test-quartile-precision.R`, `test-numeric-resolution.R` |
| 2026-09-08 | the zero tolerance was a property of the coordinate system; the fail-safe fill chooses a whole table by p; the dispersion bound sharpened and confined; the precision claim in both directions | "2026-09-08 — the fail-safe fill chooses a whole table, by p", "— the dispersion bound", "— the precision claim, in both directions" | `test-screen-2026-09-08.R`, `test-failsafe-table.R` |
| 2026-09-09 F1, F2, F7, F8, F9 | the fail-safe fill enumerates completely or declines; no partition inferred; the 2^arms fallback removed; the selector shares the engine's statistic, tie count and floor; the reader seeds itself | "2026-09-09 — the fail-safe fill declines rather than guesses" | `test-failsafe-table.R`, `test-screen-2026-09-09.R`, `test-screen-2026-09-09-1532.R` |
| 2026-09-09 F3–F5 | supplied precision not overwritten; an exponent is not decimal places; CSV keeps the digits, any header case | (same entry; precision contract) | `test-text-precision.R` |
| 2026-09-09 F6 | a replicate is translated by its own first arm: no ties lost at any printed precision | "2026-09-09 — a replicate is translated by its own first arm" | `test-audit-2026-09-09-f6.R` |
| 2026-09-10 (delta) F1 | the zero-snap tolerance is the printed grid's alone; the observed arms cannot enter it | "2026-09-10 — the zero-snap floor is the printed grid's alone" | `test-audit-2026-09-10-f1.R` |
| 2026-09-10 (delta) F3 | a wholly blank category block is counted on the Summary line, listed "Not analysed", kept in the template and the journal table | "2026-09-10 — rows the validator leaves out are counted" | `test-audit-2026-09-10-f3.R`, `test-screen-2026-09-10-1143.R` |
| 2026-09-10 (delta) F4 | a trial column of any case; an all-blank one filled like an absent one; a partly blank one refused cell by cell; structural failures carry an `issues` entry (`structural`, row null); a duplicate-name refusal returns the sheet as received | (API contract; `api-users-guide.md`) | `test-audit-2026-09-10-f4.R`, `test-screen-2026-09-10-1119.R`, `test-api-structural-issues.R`, `test-screen-2026-09-10-1222.R` |
| 2026-09-10 (delta) F2, F5 | **decided, not fixed**: the ranked selection is a heuristic and every document says so | "2026-09-10 — the ranked selection is a heuristic, and is described as one" | — |
| **2026-09-10 (full) F1** | rows sharing one null law share ONE mid-p mapping (a pooled empirical distribution over the union of their draws; each row keeps its own draws); the trial-level tie is the bounded criterion (`.iaTieTol`, 1e-10), not bit equality; your nine binary rows read 0.011146 at seed 42 through the API, inside the exact value's interval, whichever row holds the extreme | "2026-09-10 — rows sharing a null law share one mapping" | `test-audit-2026-09-10-full-f1.R` |
| **2026-09-10 (full) F1, bounded (screen 1523)** | only rows whose law is shared have their draws held; the pool is sorted once and each row counted by two binary searches (the same criterion as the tie kernel — equality tested on ties and near-ties either side of the tolerance); a trial whose shared rows would need more than 10,000,000 held draws at the final stage is refused before a draw (`.iaMaxPoolDraws`; the API answers 422 at the analysis stage). The RNG stream is unchanged: every pinned value stands | same entry, "Bounded, the same day" | `test-screen-2026-09-10-1523.R` |
| **2026-09-10 (full) F2** | a trial whose every row is excluded is still listed: TRIALS from every trial offered; the Summary reads "No values", "0 of n rows analysed"; the excluded lines are printed | "2026-09-10 — rows the validator leaves out are counted" (addendum) | `test-audit-2026-09-10-full-f2.R` |
| **2026-09-10 (full) F3** | a structural issue's `row` is JSON null on the wire (tested through real HTTP) | (API contract) | `test-api-service.R` ("row is null") |
| **security audit 2026-09-10, S1** | a refused sheet's `templateCsv` keeps EVERY column, headers and all (two columns both named `N` used to come back as one, and the resubmission analysed the first) | `docs/security-screens/log.md`, row S1 | `test-security-2026-09-10-s1.R` |
| **security audit 2026-09-10, S2** | the AI converter can no longer let a category level named `N`, `MEAN` or `SD` overwrite the reserved fields (a categorical variable used to reach the engine as two continuous lines: p 0.297 for what was, as counts, 0.013); a colliding level takes the long layout's "variable level" spelling | log row S2 | `test-security-2026-09-10-s2.R` |
| **2026-09-11 (final-brief) F1** | the shared null-law key names the law, not the printing: the categorical key is built from each margin vector SORTED (margins as multisets), and the continuous and median keys list their arms in one canonical order, so a variable coded (100, 0)/(98, 2) shares the mapping of one coded (0, 100)/(2, 98); your nine-variable fixture reads 0.01133 recoded or not (exact 0.011146), your fourteen-variable recoded interval contains the exact 0.000519; no row's own draws change | "2026-09-10 - rows sharing a null law share one mapping", the addendum "Recognised under relabelling (2026-09-11)" | `test-audit-2026-09-11-f1.R` (your `permutation-checks.R` generator, through the upload reader and the analysis), the real `/analyze` case in `test-api-service.R` |
| **2026-09-11 (final-brief) F2** | `statistics.md`'s combination paragraph now distinguishes a row's own mapping from a shared group's pooled one | (docs) | - read it against the code |
| **2026-09-11 (third full pass) F1** | the categorical key is the UNORDERED PAIR of the two sorted margin vectors (`.iaCategoryKey()`): each vector sorted, the two strings put in a fixed radix order - every numeric input r2dtable reads, and nothing about the printing; your nine-variable transposed fixture reads within 0.003 of the exact 0.011146 and on its side of 0.01, your fourteen-variable transposed interval contains the exact 0.000519; no row's own draws change | the addendum "Recognised under transposition (2026-09-11, the third full pass)" | `test-audit-2026-09-11-full-f1.R` (your transpose fixtures through the upload reader and the analysis; the key's invariances and controls directly), the real `/analyze` case in `test-api-service.R` |
| **2026-09-11 (third full pass) F2** | a journal-style trial id longer than 200 bytes becomes its first 184 bytes, a space, `#` and twelve hex digits of the SHA-1 of the whole id (`.wideTrialId()`, at both sources - the `Trial:` marker and the sheet name): bounded at 198 bytes, and two ids that differ anywhere are two trials; the same id in two blocks is still one; the reader's work and memory bounds are unchanged; your 201-byte fixture keeps two trials through `/parse` and `/analyze` (overall 0.071, `trials: 2`) | (a reader change, not a method: the API guide's journal-style limits row) | `test-audit-2026-09-11-full-f2.R`, the real `/parse` and `/analyze` cases in `test-api-service.R` |
| the older engine changes | the mid-p convention; one-sided toward homogeneity; staged replicates; the exact combination of the Stouffer sum; the attainable floor note; the 0.1 escalation and the seed; the pooled SD; banker's rounding kept | the 2026-08-16 to 2026-09-07 entries | `test-adaptive-m.R`, `test-known-answer.R`, `test-seed-and-ranges.R`, `test-pcalc-direct.R` |

The pull requests behind each entry are named in the entry itself and
in `docs/security-screens/log.md`.

The rest of the engine is fair game too: the continuous branch's
direct draw and pooled SD, the median branch's metalog fit, the staged
replicate scheme and its intervals, the attainable floor, the Stouffer
exact combination, `sumz()` across trials, the categorical exact null,
the fail-safe fill's five bounds and its chunked drawing, and now the
shared mapping - in particular whether the key now recognises EVERY
relabelling that leaves a law unchanged (arms permuted, categories
permuted, both at once, transposed, three or more arms, three or more
categories, a category column absent in one row and present in
another, and - for the continuous and median keys - any input that
enters the simulation only through a symmetric function), whether
it ever merges two rows whose laws differ (it must not: every input a
simulation reads is in its key - say so if you find one that is not),
and whether a pooled mapping over G rows' draws and a single row's own
mapping agree in expectation. Your same-draw integer trace is the judge
for any such case. Anything
where an independent calculation disagrees with `P_Calc()` beyond the
interval the app reports is a finding.

**2. Adversarial cases you compute yourself.** As before: construct
inputs, work out the correct answer independently — exact enumeration,
a reference implementation of your own, an invariance argument — and
report every place `P_Calc()` disagrees, stating whether the gap
exceeds the reported Monte Carlo interval. Give inputs and expected
values in a form that can be transcribed into a test.

**3. Contract inspection.** Read what the code expects, does and
returns, and compare it with the documentation in three directions:
docs that overstate what the code guarantees; behaviour no doc mentions;
guarantees stated in one place and contradicted in another. Since your
last pass the documents changed in these places: the shared-mapping
entry and its "Bounded" addendum in `method-history.md` (and the
superseded "biased low" paragraph you pointed at, now marked); the
"one end of each ambiguous arm's bracket" sentence in `statistics.md`
and the "No partition is assumed" sentence in `api-users-guide.md`
(your read-across items); the API guide's refusal list (the pool
ceiling is new); AGENTS.md's security conclusions.

**4. The nuance question.** Where several choices were defensible, do
the documents explain *why this one*? An unexplained defensible choice
is not a bug; report it as an explanation the reader is owed.

---

## What changed since your last pass (`6db32ee` -> `7c6583f`)

- **Your F1.** `R/P_Calc.R`: the categorical key is built by
  `.iaCategoryKey()` - each margin vector sorted, the two strings put
  in a fixed (radix) order and joined. The key names the mapping,
  never the simulation: draws are still made from each row's own table
  in its own order and every pinned value stands. `docs/statistics.md`
  says the two margins enter as an unordered pair of sets.
- **Your F2.** `R/parseWideTable.R`: `.wideTrialId()` replaces the bare
  clip at both sources. An id within the bound is used as it is; a
  longer one keeps its own first 184 bytes and gains a 48-bit
  fingerprint of the whole (" #" and twelve hex digits of its SHA-1).
  Not a new refusal; no id text is lost that the clip had not already
  lost. The tripwire pins the helper.
- **Nothing else in the engine.** The report itself (#300) and the log
  rows are documentation.

---

## What NOT to re-report

| item | state |
|---|---|
| Your F1 and F2 of the third full pass; F1 and F2 of the final-brief pass; F1, F2, F3 of the full pass | **fixed** - verify, as regression items in the checklist |
| The 48-bit fingerprint of a long trial id (a collision needs two ids agreeing on 184 bytes of text and 48 bits of digest) | **a design choice**: an opinion on the width is welcome, not a finding |
| The two informational notes of screen 2026-09-11-0848 (the pool refusal reachable by more tables; the canonical order's collation) and the two of screen 2230 (a reader-pin regex; the file stem's bound) | **accepted in writing** in the log; `order(method = "radix")` is queued should the key ever be compared across platforms |
| The pool ceiling of 10,000,000 held draws | **a new refusal, Steve's decision** — an opinion on the number is welcome, not a finding |
| The delta pass's F2 and F5 — the ranked selection's guarantee and the winner's-curse explanation | **decided**: heuristic, documented as such |
| The trial-p claim ("therefore the most favourable reading") | narrowed to the row; open decision 3 stands |
| The 2026-09-08 audit's F3, F4, F5, F7 (all-zero row, SD bound sharpness, precision contracts, workbook Summary note) | accepted, still queued — not regressions |
| Barnett's test covering the arm-dispersion blind spot | confirmed false on our machine; doc fix queued |
| The parse child and the container have no memory ceiling (ISSUES 32) | open, not statistical; Steve's item |
| Synchronous compute (a valid 5,000-arm table holds the API for 150 s) | measured by the security audit; submit-and-poll is Steve's design question |
| Tripwire (`tools/securityCheck.R`) coverage | not in scope; the security screens own it |

---

## The open decisions, where an opinion is wanted rather than a finding

Your opinions on the four decisions are on record and were used. These
remain open; say only if your view has changed:

1. **Supplied precision columns** — accept-bound-disclose, or infer
   from printed digits alone.
2. **The median/IQR branch's dispersion-side consistency test** — still
   absent; a corpus measurement first.
3. **The row-p proxy** — maximising each row's p does not maximise the
   trial p, and the documents say so. Is stating it enough?
4. **The pool ceiling** — 10,000,000 held draws (a hundred identical
   rows at the ceiling; a thousand at 10,000 replicates). Is that the
   right order of magnitude for a real baseline table?

---

## Ground rules

- R 4.5.3. Attach `shiny`, `dqrng`, `foreach`, `Rfast`, `MBESS`, then
  `pkgload::load_all()`. `m = 100000` is a ceiling, not a count: print
  the actual `M` the staged scheme used.
- Synthetic inputs only. No corpus manuscripts, no real trials.
- Say plainly what you executed and what you reasoned about; keep the
  "verified by execution" / "verified by reading" distinction. For the
  regression checklist, "VERIFIED STILL FIXED" means executed.
- Where you quote a p, quote the Monte Carlo interval with it. If a
  finding rests on a number, give the code that produced it.
- A fix's test here must reproduce the report through the report's own
  path (AGENTS.md, standing rule of 2026-09-10). Name the **path** — the
  route, the fixture, the seed — as precisely as the symptom.
- Report severity as it applies to a *screen*: a false negative helps a
  fabricator, a false positive accuses an honest author. Both matter,
  and the second is the one that ends careers.
- Your evidence directory will be committed verbatim with the report,
  as the last seven were. Keep machine-local paths out of it.
