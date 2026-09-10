# Independent statistical audit of IntegrityAnalysis — brief for the next pass

Written 2026-09-10 for the audit Steve Shafer will commission next.
The previous pass (your report of 2026-09-09, committed verbatim at
`docs/audits/2026-09-09-independent-statistical-audit-chatgpt.md` with
its evidence) found nine things. All nine are adjudicated. This brief
says what has changed since, what has deliberately not, and what is
wanted from you now.

Read this whole file before starting. The section "What NOT to re-report"
matters as much as the rest: re-finding a known defect costs a pass.

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
**0.01**, not 0.05: Steve Shafer's position is that 0.05 has no meaning
in this instrument at all.

---

## The three deliverables, unchanged

**1. Adversarial cases you compute yourself.** Construct inputs, work out
the correct answer independently — exact enumeration, a reference
implementation of your own, an invariance argument — and report every
place `P_Calc()` disagrees with you, stating whether the gap exceeds the
Monte Carlo interval the app reports at that stage. Your integer-sum
reference for the zero floor was the model: it never touched a floating
statistic, so the paired loss of ties was visible against an interval
far wider than the effect. Keep the cases; give inputs and expected
values in a form that can be transcribed into a test.

**2. Contract inspection.** Read what the code expects, does and returns,
and compare it with the documentation in three directions: docs that
overstate what the code guarantees; code behaviour no doc mentions;
guarantees stated in one place and contradicted in another. A read-across
of every document against the code was done on 2026-09-10 (PR #235) and
found ten mismatches, three of them Notes quoted verbatim that the engine
no longer emits — so the documents were checked before you were asked
to, and a divergence you find is more likely to be real than stale.

**3. The nuance question.** Where several choices were defensible, do the
documents explain *why this one*? An unexplained defensible choice is
not a bug; report it as an explanation the reader is owed.

---

## What changed since your last pass

Audit `main` at commit `ae37f0e` — check that commit out rather than the
tip of `main`, which has since moved on by two merges (#242 and #243,
now `3ac3568`) that touched parser and tripwire hygiene only and nothing
this brief describes. The whole suite (3,101 assertions) and the static tripwire
pass on `ae37f0e`, and it is the commit running in production. Twelve pull requests merged since
`9d5ef88`; these are the ones with statistical content.

**A. The fail-safe fill enumerates completely or declines, and then
scores only the extremes** (PRs #230, #231, #234, #236 — your F1, F2, F7,
F8, F9, and then a regression your report did not see because it had not
happened yet).

Your F1, F2 and F8 closed the way you recommended: past the enumeration
bound, or past it for one arm, the block is **unresolved** — cells back
to blank, row named with a reason, not analysed, and counted on the
Summary's "k of n rows analysed" line. No partition is inferred from
arithmetic any more; a chosen reading may total more or less than the
arm's N, and the cell's note says so. The superseded per-level rule is
deleted, not left unused.

Then the security screen of that merge found that scoring every distinct
null made an *ordinary* Table 1 unparseable: two arms of 700 with a
three-level category printed as percentages gave 20,449 distinct nulls
and 190 s against a 60 s subprocess timeout. The `partition = FALSE`
case — the common one on a real page — barely groups.

The selection now **ranks the margin groups by the Pearson statistic and
simulates only the top `.ppTableRankMax` (50) for the best case and the
bottom 50 for the worst**, then refines as before. The justification
offered is that the p is the left tail, so within one null it rises with
the statistic, and `pchisq(stat, df)` — the asymptotic form of the same
quantity — orders the groups by the statistic itself when df is shared.
Measured against the exhaustive pass on nine shapes: every
`partition = TRUE` shape chose identical counts; every disagreement was
`partition = FALSE` and chose the **larger** p (0.09517 → 0.1013, 0.1331
→ 0.1363, 0.00135 → 0.001575 on a three-arm row near the threshold). The
explanation given is the winner's curse — ranking thousands of noisy
2,000-replicate estimates and refining the best six selected on upward
noise and biased the reported best case *low*. Over 77 further
`partition = TRUE` shapes the p-maximising group was rank 1 in 46 and
within the top six in 72.

Attack this hardest of anything in the brief:

- **Is the ordering by statistic a guarantee or a heuristic?** The
  documents now say the largest p "can only be among the least alike
  readings". Across *different* nulls the df is shared but the null
  distributions are not identical. Construct a block where the
  p-maximising group's statistic ranks below 50 and say what the shortfall
  costs. The measurements above are ours; an independent one is wanted.
- **The worst case.** Over the same 77 shapes the p-*minimising* group's
  rank by statistic had a median of 3 and a maximum of 652. Our reading is
  that at the floor many groups tie and the *value* is unaffected; the
  group identity is not what the straddle rule needs. Is that right?
- **The winner's-curse claim.** We assert the exhaustive scheme was biased
  toward the accusation. Verify or refute it with a reference of your
  own; if it is right, it belongs in the method history as a measured
  fact rather than our inference.
- **The user-facing sentence** now reads "All N readings this page allows
  were enumerated, and the K at each extreme were scored". It was wrong
  twice in two days (once "scored" of all of them, once with the union of
  both ends as K). Read it against the code once more.
- The bounds that decide whether the reconstruction happens at all: the
  reading count (200,000), the working-set cell budget (5 million), the
  arm-N ceiling (5,000), count-before-build, and — added last, after the
  screen of 2026-09-10 found that every earlier bound counted candidate
  tables while a block with one ambiguous cell has exactly two at *any*
  size — a scoring-cost gate, and then a second screen showing that its
  first form bounded cells while `r2dtable()`'s setup cost grows with the
  grand total. The gate now admits at most 100 cells per table and a grand
  total of at most 125,000 across the arms, from a measured cost model
  (time ≈ 1.0e-7 × tables × cells + 3.5e-7 × calls × grand total), so the
  largest admitted block scores in under ten seconds; the null is drawn
  in chunks sized by the table (1e7 / cells, the engine's own idiom) so
  memory is bounded without multiplying the setup; and — after a third
  screen showed that the grand total the gate measured was the sum of the
  arm sizes while `r2dtable()` pays for the sum of the *table*, which a
  level printed as a count reaches unbounded — the validator's own rule now
  runs at the gate: an arm whose scored counts would total more than 5,000
  is refused before anything is built, using N itself where the levels
  partition the arm and the brackets' tops where they do not. Each was added because
  a screen found the previous one could be driven to a gigabyte or a
  minute. Say whether any of them can decline a table an honest paper
  prints — four arms by twenty-five levels is admitted, five by
  twenty-five is not — and whether chunked drawing changes any p: it
  should not, because `r2dtable()` draws one table at a time from the
  stream.

**B. The zero floor no longer drops genuine ties** (PR #233; your F6).
Each simulated replicate is now translated by **its own first arm**,
which is what the observed row always did, so arms that drew the same
value give a structurally exact zero instead of dust a tolerance had to
forgive. On your construction (two arms of 30, MEAN 2.3, SD 3.007):
1,243 of 6,823 ties lost at fourteen decimals before, 0 after; the row
reads 0.00816 at both six and fourteen decimals against your reference
0.008474. The median branch had the same defect and you did not test it
— invisible on an integer observation grid (halves are dyadic), visible
on tenths with odd N (0.01995 at 1–6 decimals drifting to 0.01755 from
11; now 0.01995 throughout). No pinned Monte Carlo value moved: the
effect is confined to eleven decimals and finer.

**The tolerance floor is deliberately kept.** Its motivating measurement
was taken under the old arithmetic, so removing it would need its own
measurement. Attack that: now that tied arms are structural, is
`1e-12 × step²` still the right size, and is there any remaining source
of dust it must catch — arms that differ, the metalog draw, the
Stouffer combination — at any admissible magnitude?

**C. The precision contract on every input route** (PRs #230, #231, #236;
your F3, F4, F5). A supplied coarse precision is not overwritten; an
exponent is not read as decimal places; the CSV route keeps the digits
the spreadsheet route keeps, whatever case the header is written in, and
a Latin-1 export decodes rather than raising. Attack the round trip
through `/parse` → `templateCsv` → `/analyze` once more, and the
interaction between an inferred and a supplied precision.

**D. What the flags say** (PRs #231, #236). The unresolved and straddle
flags now cross the docx, JATS and TATR seams (they never had). A declined
block retracts its own fail-safe claim, and — after a second screen found
the first retraction cancelled *other* blocks' warnings that shared a
level label — it does so by block, not by name. Read `reviewFlags()`
against what each route actually returns.

---

## What NOT to re-report

| item | state |
|---|---|
| Your F1, F2, F8 — the reconstruction's partition heuristic, the per-arm cap restoring the old rule, the 2^arms fallback | **fixed**, see A — audit the ranked selection, not the old search |
| Your F3, F4, F5 — supplied precision overwritten, exponent as decimals, CSV losing digits | **fixed**, see C |
| Your F6 — the zero floor | **fixed**, see B — audit the kept floor |
| Your F7 — the selector's own tail calculation | **fixed**: it shares the engine's statistic, tie counting and floor, and keys on both margins |
| Your F9 — stochastic extraction | **fixed**: the reader seeds itself and restores the caller's stream |
| The trial-p claim ("therefore the most favourable reading") | **narrowed, not repaired**: the guarantee is stated for the row; open decision 3 below stands |
| The 2026-09-08 audit's F3, F4, F5, F7 (all-zero row, SD bound sharpness, precision contracts, workbook Summary note) | accepted, still queued |
| Barnett's test covering the arm-dispersion blind spot | confirmed false on our machine; doc fix queued |
| The parse child has no memory ceiling (ISSUES 32) | **open, and not statistical** — three screens this week found allocation paths in the fail-safe fill, all fixed in R; the container-level ceiling is Steve's item |

---

## The open decisions, where an opinion is wanted rather than a finding

1. **Supplied precision columns.** Unchanged from the last brief:
   accept-bound-disclose, or infer from printed digits alone? Twelve
   screens have now each found a way to move a p through a precision
   cell, and each was closed with a refusal or a Note.

2. **The median/IQR branch's dispersion-side consistency test.** Still
   absent, for the reason given last time: two consecutive screens caught
   a new refusal throwing out honest rows, and this one wants a corpus
   measurement first.

3. **The row-p proxy.** Maximising each row's p does not maximise the
   trial p, and we now say so rather than promise it. Is stating it
   enough?

4. **New: the ranked selection.** Steve chose to score only the extremes
   because the measurement showed it faster *and* less biased than
   scoring everything. If your independent measurement disagrees on the
   second point, the decision should be revisited; if it agrees, the
   "complete or decline" principle that governs the *enumeration* should
   probably be restated so that it is clear it does not extend to the
   *scoring*. Say which.

---

## Ground rules

- R 4.5.3. Attach `shiny`, `dqrng`, `foreach`, `Rfast`, `MBESS`, then
  `pkgload::load_all()`. `m = 100000` is a ceiling, not a count: print the
  actual `M` the staged scheme used.
- Synthetic inputs only. No corpus manuscripts, no real trials.
- Say plainly what you executed and what you reasoned about; keep the
  "verified by execution" / "verified by reading" distinction.
- Where you quote a p, quote the Monte Carlo interval with it. If a
  finding rests on a number, give the code that produced it.
- A fix's test here must now reproduce the report through the report's
  own path (AGENTS.md, standing rule of 2026-09-10). So when you report a
  finding, name the **path** — the route, the fixture, the seed — as
  precisely as the symptom; that is what the test will be built from.
- Report severity as it applies to a *screen*: a false negative helps a
  fabricator, a false positive accuses an honest author. Both matter, and
  the second is the one that ends careers.
