# Independent statistical audit of IntegrityAnalysis — brief for the next pass

Written 2026-09-08 for the audit Steve Shafer will commission next.
The previous pass (your report of 2026-09-08, committed verbatim at
`docs/audits/2026-09-08-independent-statistical-audit-chatgpt.md` with
its evidence) found seven things. This brief says what has changed since,
what has deliberately not, and what is wanted from you now.

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
in this instrument at all, and the app's own caveat text (his wording,
from his years as Editor-in-Chief of *Anesthesia & Analgesia*) exists to
say that a p of 0.05 arises in one honest paper in twenty and proves
nothing.

---

## The two deliverables, unchanged from last time

**1. Adversarial cases you compute yourself.** Construct inputs, work out
the correct answer independently — by exact enumeration, by a reference
implementation you write, or by an invariance argument — and report every
place `P_Calc()` disagrees with you. Differences are only interesting
when they are *meaningful*, so please state, for each, whether the gap
exceeds the Monte Carlo interval the app itself reports at that stage.
Three families have paid off before and are worth repeating: exact
enumeration of small discrete cases; invariance under scale, translation
and permutation of arms; and calibration of the honest null at coarse
rounding. Keep the cases: Steve wants the good ones retained as
regression tests, so give inputs and expected values in a form that can
be transcribed.

**2. Contract inspection.** Read what the code actually expects as input,
does as analysis, and returns as output, and compare it with the
documentation. Documentation that misdescribes any of the three is a
defect to be corrected, in whichever direction is wrong — the
documentation may be describing something the code no longer does, or the
code may be doing something no document mentions. Steve's standard is
that they must fit like a hand and glove. Check in three directions:
docs that overstate what the code guarantees; code behaviour that no doc
mentions; and guarantees stated in one place and contradicted in another.

**3. And the nuance question, which is now a standing part of the brief.**
Where there were several defensible choices, do the documents explain
*why this one*, or do they merely assert it? A choice that is defensible
but unexplained is not a bug and should not be reported as one — report
it as an explanation the reader is owed. Your last pass on this question
was the most useful part of the report.

---

## What changed since your last pass

Four pull requests, all merged. Audit `main` at commit `9d5ef88`; that is
the tree these describe, and the whole test suite (2,335 assertions) and
the static tripwire pass on it. They are the primary new surface.

**A. The fail-safe fill now chooses a whole table, by p** (PR #228; the
largest change, and it closes your F2). When a printed percentage fits several counts
— which happens for arms above 100 at whole-percent printing, above 1,000
at one decimal — the app used to maximise, for each category *level on
its own table line*, that level's statistic against its own complement.
That was wrong three ways, and we measured all three: it optimised a
statistic `P_Calc()` does not compute; it let the levels of one variable
disagree about the arm total, which is your 203/197; and, because it drove
every level the same way in the same arm, it left the arms in identical
proportions — the *most* homogeneous reading of the page rather than the
least, which is the opposite of what six user-facing places promised.

It now enumerates every arms-by-levels table the percentages allow, each
cell inside its own bracket and each arm's counts summing to that arm's N
where the levels partition it, scores each with the engine's own
statistic and null, and analyses the one with the **largest p** — the
best case for the authors, which is Steve's decision. The smallest p is
carried alongside, and when the two fall on opposite sides of **p = 0.01**
the row is named in the flags and in its hover note.

Specific things to attack here:

- The exhaustivity test. The code decides that the levels partition the
  arm when N is reachable from the admissible cells *and* the bracket
  midpoints sum to within 2% of N. Construct a block where that test is
  wrong in each direction and say what it costs.
- The bounded search above `.ppTableEnumMax`. A hostile document chooses
  the arm count, the level count and the arm sizes. Is the fallback
  sampling honest about what it can miss, and can you construct a page
  where the bounded search returns something materially worse than the
  best available?
- The claim that the mid-p is monotone in the statistic within one
  level-total group. That is the economy the whole design rests on. If it
  fails anywhere — ties, zero-count columns, degenerate margins — the
  selection is wrong.
- Selection noise. Candidates are ranked at 2,000 replicates and the top
  contenders re-run at 20,000. Is that enough that the reported best case
  is the true best case? What is the distribution of the shortfall?
- The straddle rule itself. Reporting the worst case only when the two
  readings cross 0.01 is a deliberate choice, not an oversight — Steve's
  reasoning is that saying it on every fail-safe row would train the
  reader to skip it. Is that defensible? Is 0.01 the right line, given
  that it is also an escalation threshold in the staged replicate scheme?

**B. Printed precision now survives a spreadsheet** (PR #226). A cell arriving as
*text* has its decimals counted before the coercion that loses them, and
the mean, SD, SE and quartile columns are exported as text at each row's
declared precision. Counts, N and the rounding columns stay numeric, on
the grounds that whole numbers lose nothing and a text column stops being
recognised as a category. Attack the round trip, and attack the
interaction between an inferred precision and a supplied one.

**C. The zero snap is no longer a property of the coordinate system**
(PR #229; this closes your F1). Its tolerance was `1e-26 * (1 +
centre^2)` - quadratic in an arbitrary origin, with an absolute floor at
small magnitudes - while the statistic it thresholds is
translation-invariant and scales as k squared. Reproduced before it was
touched: three arms of 1,000 with SD 0.001 and means differing by 2e-5,
3e-5 and 5e-5 read p = 0.3105, 0.573 and 0.897 at origin 0 and **0.492
for all three** at origin 1e9, the tolerance having swallowed the
observed statistic and nearly every replicate. Nothing refused those
rows. `.iaZeroSnapTol()` now scales to the translated deviations, with
the finest printed grid step as a floor.

Attack that floor. The screen that raised the finding proposed
`1e-12 * max(dd^2)` alone; that is exactly zero when the arms agree,
which removes the dust guard in the one case it exists for and moved a
pinned Monte Carlo value by 0.013. The grid-step floor is the answer
taken, and it is the part of this fix with the least independent
scrutiny. Is `1e-12` times the finest step squared the right size at
every admissible magnitude and arm count? The same commit also stopped
the fine-precision Note firing on ordinary honest rows such as
45.2 / 45.0 / 44.8, and added a static assertion that the note's
tolerance and the engine's stay one binding.

**D. The 2026-09-08 audit is committed** (PR #227), verbatim, with its
evidence, including the synthetic three-category fixture. Steve decided
the record was worth more than the disclosure. You may cite it.

---

## What NOT to re-report

These are known, adjudicated, and either queued or deliberately left. Say
so briefly if you disagree with the disposition, but do not spend the
pass re-deriving them.

| item | state |
|---|---|
| Your F2, the fail-safe guarantee | **fixed**, see A above — audit the fix, not the old rule |
| Your F1, the zero snap is not scale- or translation-invariant | **fixed**, see C above - audit the fix, and especially the grid-step floor |
| Your F3, an honest all-zero row is refused | accepted, queued |
| Your F4, the SD-reachability bound is necessary but not sharp | accepted, queued; the doc claim needs correcting either way |
| Your F5, validator and engine hold different precision contracts | accepted, queued |
| Your F6, the claim that Barnett's test covers the arm-dispersion blind spot | accepted and **confirmed false on our machine**: `barnettTStats` gives bit-identical results for SD pairs (10,10) and (2,14). Doc fix queued |
| Your F7, the workbook Summary sheet drops the "k of n rows analysed" note | accepted, queued |
| The fine-precision note fires on ordinary honest rows | **fixed** in the same commit as C |
| The registry cap drops the oldest rather than by priority | **fixed**: capped by priority, warnings kept while ordinary rows remain |
| The observation-grid disclosure is absent from the coarse note | **accepted and left open on purpose**, because the mechanism it would describe lives in the median branch, which is open decision 2 below |

---

## The open decisions, where an opinion is wanted rather than a finding

1. **Supplied precision columns.** `ROUND_MEAN`, `ROUND_DISPERSION` and
   `ROUND_OBSERVATION` can be typed into the grid, filled into the
   template, or posted to the API, and the engine reads each as the width
   of an interval — a direct multiplier on the null. Eight adversarial
   screens each found a way to move a p by changing one of those cells,
   and each was closed with a refusal where the claim is arithmetically
   impossible or a Note where it is merely unverifiable. The alternative
   is to stop accepting them and infer precision from printed digits
   alone. Is accept-bound-disclose defensible, or must the interval width
   come from somewhere the manuscript does not control?

2. **The median/IQR branch still has no dispersion-side consistency
   test.** The analogue would require the printed quartiles to be
   reachable as type-7 quantiles of N values on the stated observation
   lattice. It is absent because two consecutive screens caught a *new*
   refusal throwing out honest rows, so it wants a corpus measurement
   first. If you think it should be there, say what it would refuse that
   is honest.

3. **The row-p proxy.** Maximising each row's p does not exactly maximise
   the trial p, because the trial null is simulated from the row nulls and
   those shift with the margins being chosen. We state this rather than
   promise exactness. Is stating it enough, or does the guarantee need to
   be made true at the trial level, and at what cost?

---

## Ground rules

- R 4.5.3. Attach `shiny`, `dqrng`, `foreach`, `Rfast`, `MBESS`, then
  `pkgload::load_all()`. `m = 100000` is a ceiling, not a count: print the
  actual `M` the staged scheme used.
- Synthetic inputs only. No corpus manuscripts, no real trials.
- Say plainly what you executed and what you reasoned about. Your last
  report separated "verified by execution" from "verified by reading" and
  that distinction was worth a great deal — keep it.
- Where you quote a p, quote the Monte Carlo interval with it.
- If a finding rests on a number, give the code that produced it.
- Report the severity as it applies to a *screen*: a false negative helps
  a fabricator, a false positive accuses an honest author. Both matter,
  and the second is the one that ends careers, so do not treat it as the
  minor direction.
