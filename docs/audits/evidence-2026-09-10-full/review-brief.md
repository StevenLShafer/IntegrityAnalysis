# Independent statistical audit of IntegrityAnalysis — brief for a FULL pass

Written 2026-09-10 (evening) for the audit Steve Shafer will commission
next. The previous pass (your report of 2026-09-10, committed verbatim at
`docs/audits/2026-09-10-independent-statistical-audit-chatgpt.md` with
its 349 evidence files) found five things. All five are adjudicated —
three fixed, two decided — and the security screens that followed each
fix found and fixed four more things in the fixes themselves. This brief
is different from the last four in one respect: **it asks for a full
audit of the engine as it stands, not an audit of the changes.** Five
audit rounds and some sixty pull requests in five days have touched
nearly every statistical path; Steve's question is whether anything
adjudicated in an earlier round has been broken by a later one. If this
pass finds no P1 and no numerical P2, the engine will be declared done
and the effort moves to corpus validation.

Read this whole file before starting. The section "What NOT to
re-report" matters as much as the rest: re-finding a known, decided
matter costs a pass.

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
review; "better is the enemy of done" is the standard this pass is
judged by — a defect that changes what an editor is shown matters, a
refinement does not.

---

## The commit

Audit `main` at commit **`a796e51`**, the tip after the last screen's
fixes merged (#259). Check that commit out. Production runs it (the
app and the API both report it). The whole suite (3,287 assertions) and
the static tripwire pass on it. The security screen of its range
(2026-09-10-1300) found no attacker-facing defect; its one
guard-coverage LOW in the tripwire was accepted in writing, and that
adjudication is the only commit after `a796e51` (#260, two log rows
and a ledger line, no code). If `main` has moved on further by the time
you start, the brief still names `a796e51`.

---

## The deliverables

**1. The regression checklist — every adjudicated finding, re-verified.**
This is the new deliverable and the reason for a full pass. For each
item below, construct or reuse an executable case, run it against
`a796e51`, and report VERIFIED STILL FIXED / REGRESSED / COULD NOT TEST
with the number. The earlier reports and their evidence directories are
in `docs/audits/`; `docs/method-history.md` describes each change and
what was measured; `tests/testthat/test-audit-*.R` and
`test-screen-*.R` carry the tests that were built from each report
through the report's own path, and you may reuse their fixtures.

| round | finding, in one line | `method-history.md` entry | where the test lives |
|---|---|---|---|
| 2026-09-06 (in-session) | the direct draw for large arms keeps the mean's grid; the SD is drawn per replicate within its printed interval; explicit precision is kept; the attainable-floor label; the trial interval's lower end | "2026-09-05 — the direct draw for large arms", "2026-09-06 — the SD is drawn per replicate", "— precision inference", "— the SD's printed rounding is drawn", "— the trial interval's lower end" | `test-pcalc-direct.R`, `test-sd-rounding-draw.R`, `test-sd-interval-cells.R`, `test-validate-rounding.R`, `test-known-answer.R` |
| 2026-09-07 | ties decided by a bounded numerical criterion (a categorical tie group split into 0.10 where the exact mid-p was 0.35); the summary line identified by KIND, not its label; the median/IQR parameter draw and the skew limit clipped; the quartiles' printed precision and intervals entering the fit; a row whose printed precision the arithmetic cannot carry; a stated precision has to describe the number beside it | the seven "2026-09-07 —" entries | `test-tie-criterion.R`, `test-summary-kind.R`, `test-median-iqr.R`, `test-quartile-draw.R`, `test-quartile-precision.R`, `test-numeric-resolution.R` |
| 2026-09-08 | the zero tolerance was a property of the coordinate system (origin / unit conversion moved the p); the fail-safe fill chooses a whole table by p; the dispersion bound sharpened and confined; the precision claim in both directions | "2026-09-08 — the fail-safe fill chooses a whole table, by p", "— the dispersion bound", "— the precision claim, in both directions", and screens 0709/1048 in `test-screen-2026-09-08.R` | `test-screen-2026-09-08.R`, `test-failsafe-table.R` |
| 2026-09-09 F1, F2, F7, F8, F9 | the fail-safe fill enumerates completely or declines; no partition inferred; the 2^arms fallback removed; the selector shares the engine's statistic, tie count and floor; the reader seeds itself | "2026-09-09 — the fail-safe fill declines rather than guesses" | `test-failsafe-table.R`, `test-screen-2026-09-09.R`, `test-screen-2026-09-09-1532.R` |
| 2026-09-09 F3–F5 | supplied precision not overwritten; an exponent is not decimal places; CSV keeps the digits, any header case | (same entry; precision contract) | `test-text-precision.R` |
| 2026-09-09 F6 | a replicate is translated by its own first arm: no ties lost at any printed precision | "2026-09-09 — a replicate is translated by its own first arm" | `test-audit-2026-09-09-f6.R` |
| 2026-09-10 F1 | the zero-snap tolerance is the printed grid's alone; the observed arms cannot enter it (0.00609 → 0.01978 on your fixture) | "2026-09-10 — the zero-snap floor is the printed grid's alone" | `test-audit-2026-09-10-f1.R` |
| 2026-09-10 F3 | a wholly blank category block is counted on the Summary line, listed "Not analysed", kept in the template and the journal table (the journal table restored one line per label, estimated with its width) | "2026-09-10 — rows the validator leaves out are counted" | `test-audit-2026-09-10-f3.R`, `test-screen-2026-09-10-1143.R` |
| 2026-09-10 F4 | a trial column of any case; an all-blank one filled like an absent one; a partly blank one refused cell by cell; structural failures carry an `issues` entry (`structural`, row null); a duplicate-name refusal returns the sheet as received | (API contract; `api-users-guide.md`) | `test-audit-2026-09-10-f4.R`, `test-screen-2026-09-10-1119.R`, `test-api-structural-issues.R`, `test-screen-2026-09-10-1222.R` |
| 2026-09-10 F2, F5 | **decided, not fixed**: the ranked selection is a heuristic and every document says so (see below) | "2026-09-10 — the ranked selection is a heuristic, and is described as one" | — |
| the older engine changes | the mid-p convention; one-sided toward homogeneity; staged replicates; the exact combination of the Stouffer sum; the attainable floor note; the 0.1 escalation and the seed; the pooled SD; banker's rounding kept | the 2026-08-16 to 2026-09-07 entries | `test-adaptive-m.R`, `test-known-answer.R`, `test-seed-and-ranges.R`, `test-pcalc-direct.R` |

The pull requests behind each entry are named in the entry itself and
in `docs/security-screens/log.md`.

The rest of the engine is fair game too: the continuous branch's
direct draw and pooled SD, the median branch's metalog fit, the staged
replicate scheme and its intervals, the attainable floor, the Stouffer
exact combination, `sumz()` across trials, the categorical exact null,
the fail-safe fill's five bounds and its chunked drawing. Anything
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
last pass the documents changed in four places you should read against
the code: the fail-safe section of `statistics.md` (the ranked selection
described as a heuristic; the five bounds; totals equal N only where the
levels partition), the corresponding bullets of `user-guide.md` and
`api-users-guide.md`, the API guide's `issues` codes (seven now, with
`structural`), and the three new `method-history.md` entries.

**4. The nuance question.** Where several choices were defensible, do
the documents explain *why this one*? An unexplained defensible choice
is not a bug; report it as an explanation the reader is owed.

---

## What changed since your last pass (`ae37f0e` → `a796e51`)

- **F1 (the zero snap).** `.iaZeroSnapTol(h)` takes the printed step
  only: `1e-12 × min(step)²`, zero without a stated precision. The
  observed deviations no longer enter it and the signature no longer
  accepts them. Your integer-distance reference is the test. The floor
  itself was kept, as inert by construction (the smallest statistic two
  distinct readings on the grid can produce is at least step²/2).
- **F3 (coverage).** `validateData()` returns what it left out
  (`Excluded`: TRIAL, ROW, REASON; `ExcludedRows`: the rows themselves,
  untouched); `P_Calc(excluded =)` lists each such variable once, "Not
  analysed", with the reason, and counts it on the Summary line; the API
  puts the rows back in `templateCsv` (every row) and the journal table
  (one line per label); the app's downloads do the same behind the same
  size gate, which now counts the table's width. The trial p is
  unchanged by any of this; a test asserts it bit-identical.
- **F4 (the trial column).** One rule, the normaliser's own; an
  all-blank column is filled from the file name; a partly blank one is a
  422 with a `missing` issue per cell; a structural failure (a required
  column absent, two columns normalising to one name) carries a
  `structural` issue, row null, the column named; the note names the
  original headers; the refusal's template is the sheet as received.
- **F2 / F5 (decided).** Steve ruled the certified optimum out on cost
  (scoring every group is what made an ordinary Table 1 fail to parse).
  The ranked runtime stays; every document now says the reading analysed
  is the most favourable **among the readings scored**, and the worst
  case beside it the least favourable among them; your two exact
  counterexamples and the F5 measurement are recorded in the selector's
  commentary and in `method-history.md`. This is a decision, not a
  finding to re-open; what is wanted is whether the documents now say
  exactly what the code does, no more.
- The read-across corrections (five bounds; totals equal N only where
  the levels partition).

---

## What NOT to re-report

| item | state |
|---|---|
| Your F2 and F5 — the ranked selection's guarantee and the winner's-curse explanation | **decided**: heuristic, documented as such; read the wording, do not re-prove the counterexample |
| Your F1, F3, F4 | **fixed** — verify, as regression items 2026-09-10 in the checklist |
| The trial-p claim ("therefore the most favourable reading") | narrowed to the row; open decision 3 below stands |
| The 2026-09-08 audit's F3, F4, F5, F7 (all-zero row, SD bound sharpness, precision contracts, workbook Summary note) | accepted, still queued — not regressions |
| Barnett's test covering the arm-dispersion blind spot | confirmed false on our machine; doc fix queued |
| The parse child has no memory ceiling (ISSUES 32) | open, not statistical; Steve's container item |
| Tripwire (`tools/securityCheck.R`) coverage | not in scope; the security screens own it |

---

## The open decisions, where an opinion is wanted rather than a finding

Your opinions of 2026-09-10 on the four decisions are on record and
were used. Three remain open; say only if your view has changed:

1. **Supplied precision columns** — accept-bound-disclose, or infer
   from printed digits alone.
2. **The median/IQR branch's dispersion-side consistency test** — still
   absent; a corpus measurement first.
3. **The row-p proxy** — maximising each row's p does not maximise the
   trial p, and the documents say so. Is stating it enough?

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
  as the last four were. Keep machine-local paths out of it (the one
  redaction made last time was two library paths in `setup.R`).
