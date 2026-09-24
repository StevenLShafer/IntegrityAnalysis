# Finding: the baseline block runs on into follow-up timepoints

**Delivered 2026-09-24 by Claude (Opus 5) working in a Cowork session on
`C:\dev\Fujii Boldt Reuben`, not in this repository.** Reported here rather
than filed in ISSUES.md so that a repository session can check for peers and
file it under its own conventions.

**Severity: this blocks the Fujii / Boldt / Reuben corpus analysis, and one
plausible "fix" would silently produce wrong p-values rather than none.**

## Where it came from

The project runs IntegrityAnalysis over the complete published corpora of
three serial fraudsters. The Fujii batch was scope-matched to the 168 trials
of Carlisle, *Anaesthesia* 2012;67:521-537, so that our per-trial p values
could be set beside the Monte Carlo column of Table 2 in Carlisle, Dexter,
Pandit, Shafer and Yentis, *Anaesthesia* 2015;70:848-858 — the paper that
introduced the Monte Carlo method this package implements.

Of 168 papers, **106 analysed and 51 returned `parsed table failed
validation`**. The failures are not spread evenly:

| | failed validation |
|---|---|
| human trials | 26 of ~133 |
| **animal (canine) trials** | **22 of 27** |

Carlisle analysed 24 canine trials in 2012 and found 21 of them inconsistent
with random sampling — 62% below p = 0.00001, against 7% of the human
trials. The canine studies are the most aberrant stratum in the corpus, and
they are the stratum we lose.

## The diagnosis, on a paper with a published answer

The test case is deliberate. **PMID 11375852** — Fujii Y, Hoshi T, Uemura A,
Toyooka H, "Dose-response characteristics of midazolam for reducing
diaphragmatic contractility", *Anesth Analg* 2001;92:1590-3 (retracted) — is
reference 10 of the 2015 paper. Its **Table 1 prints that trial's complete
baseline table**, and the text gives the Monte Carlo result: **p = 1.2e-6**.

Table 1 as published — three groups, n = 8 each, mean (SD), nine variables:

```
RAP  mmHg            5 (2)      5 (2)      5 (2)
RAP(2) mmHg          5 (2)      5 (1)      5 (2)
MPAP mmHg           12 (2)     12 (2)     12 (2)
PAOP mmHg            8 (2)      8 (1)      8 (2)
CO   l/min         2.2 (0.5)  2.2 (0.4)  2.3 (0.4)
Stimulation 20 Hz 15.5 (2)   15.3 (1.8) 15.4 (2.1)
Stimulation 100 Hz 21.1 (2)   20.9 (2.2) 20.9 (2.1)
MAP  mmHg          130 (15)   132 (12)   131 (11)
HR   bpm           141 (15)   143 (10)   140 (12)
```

Nine variables x three groups = **27 rows**. `parseBaselineTableFiles(ai =
"fallback")` returns **58**, engine `hybrid`, and `validateData` fails the
trial. Three distinct defects, in increasing order of importance.

### 1. N is missing — 36 of the 37 issues

```
issue counts by column:   N  ROW
                         36    1
issue counts by code:   missing 37
```

The table prints no N. The eight dogs per group are stated in the Methods.
`validateData` requires N and fails the whole trial without it. In the app a
human types 8 into the grid and moves on; headless, the paper is discarded.
This is the direct cause of all 22 canine failures, and of some human ones.

### 2. Arm detection collapses

```
            arm  N
1          <NA> NA
2 No study drug NA
```

Two arms for a three-group trial, one unnamed, the other a column-header
fragment. Neither carries an N.

### 3. The parse runs past the baseline block — THE ONE THAT MATTERS

Heart rate, as returned:

```
HR   141 (15)      HR   143 (10)      HR   140 (12)    <- Table 1, baseline
HR   142 (17)      HR   133 (10)      HR   123 (10)    <- NOT in Table 1
```

The first value of each pair is the published baseline. The second is a
post-midazolam timepoint. This is a dose-response study whose printed table
carries baseline and follow-up across the page, and the reader took both.
The column structure was never resolved — the returned header reads

```
(Group Variable Group Baseline (Group
```

— and the first row is `"of midazolam"`, a fragment of the article title
parsed as data. 58 rows instead of 27 is very close to 27 baseline + 27
follow-up + noise.

## Why supplying N is NOT the fix

The obvious repair — take N from the Methods, or let the user supply it — makes
the trial validate. It would then compute a Monte Carlo p over a table that
mixes baseline values with post-treatment values.

**Post-treatment values are not random samples of one population; they are a
drug effect.** A dose-response study is expected to separate its arms after
dosing. Feeding those rows to a test for unexpected *homogeneity* is a
category error, and on a table like this one it would very likely return a
small p for a reason that has nothing to do with data integrity.

That is the worst failure available to this program: a confident p-value on
rows that are not baseline characteristics, with nothing flagged. It is
issue 24's failure mode — "a wrong-table parse yields a confident p-value
computed on data that are not baseline characteristics" — arriving by a
different route. Issue 24 is about selecting the wrong *table*; this is
selecting the wrong *columns* of the right table.

Any change here should fix defect 3 before, or together with, defects 1
and 2. Fixing 1 alone converts a visible failure into an invisible one.

## A ready-made regression test

PMID 11375852 gives what a fixture usually lacks: a **published input table**
and a **published answer from the method's own authors**.

- The correct parse is the 27 rows of Table 1 above, three arms, N = 8 each.
- The correct trial p is **1.2e-6** (Monte Carlo, 2015 paper).

A fixture built from the printed table tests `P_Calc` independently of the
parser; the PDF itself then tests the parser end to end against the same
number. The PDF is at
`C:\dev\Fujii Boldt Reuben\Fujii\PMID_11375852.pdf`.

## How to replicate it

R 4.5.3, from `C:\dev\Fujii Boldt Reuben` (the package is in that R's user
library; the machine's default `Rscript` is R 4.6 and will not find it):

```
"C:\Program Files\R\R-4.5.3\bin\Rscript.exe" diagnose_one.R
```

`diagnose_one.R` parses one PDF with `ai = "fallback"`, prints the table and
the arms, runs `validateData`, prints the issue frame, and — only if
validation passes — computes the trial p and prints it beside 1.2e-6. It tees
everything to `diagnose_one.log` beside itself. It takes an optional path
argument relative to that folder, so any other corpus paper can be examined
the same way:

```
"C:\Program Files\R\R-4.5.3\bin\Rscript.exe" diagnose_one.R Fujii/PMID_10589648.pdf
```

**What it prints today, on `Fujii/PMID_11375852.pdf` (2026-09-23 19:05).** If a
session sees something materially different, the input or the environment has
changed and that is worth understanding before anything is edited:

```
engine: hybrid | rows: 58
arms:
            arm  N
1          <NA> NA
2 No study drug NA

validateData FAIL: TRUE

issue counts by column:   N  ROW
                         36    1
issue counts by code:   missing 37
```

and, in the row dump, heart rate appearing six times rather than three:
141 (15), 142 (17), 143 (10), 133 (10), 140 (12), 123 (10) — three baseline
values from Table 1 interleaved with three post-midazolam values that are not
in Table 1.

The script needs no API key if run with `ai = "never"`, but the 58-row result
above is from `ai = "fallback"`, which is what the corpus batches use. The key
is read from `ANTHROPIC_API_KEY` in `~/Documents/.Renviron`.

## How to know it is fixed

Steve's constraint, in his words: the parsing algorithm is now beyond his
ability to follow the code, so he is relying on the assistant to work through
the problem, build the test cases, and fix it without breaking anything. That
puts the burden of proof on the tests rather than on a reading of the diff.
Three things should be true, in this order.

**1. A unit fixture, independent of the parser.** Build the 27 rows of Table 1
above as a fixture — three arms, N = 8 each, nine variables, the printed
precisions — and assert that `P_Calc` returns approximately 1.2e-6. This tests
the engine against a number computed by the method's own authors and does not
depend on any parser change. If it does not reproduce, the problem is not
where this document says it is, and that is worth knowing first.

**2. An end-to-end assertion on the PDF.** Parsing
`Fujii/PMID_11375852.pdf` should return **27 continuous rows, three arms**,
no post-treatment values, and — once N is available — a trial p near 1.2e-6.
The specific things to assert, because each is a separate defect:

- row count is 27, not 58
- three arms, each named from the table rather than `<NA>` or a header fragment
- no row carries a value absent from Table 1 above (142, 133, 123 for HR, and
  the corresponding second values for the other eight variables)
- `validateData` does not fail

**3. Nothing else moves.** This is the part that matters most given the
constraint above. Before and after, on the same commit-to-commit basis:

- the `testthat` suite (128 files, ~3,000 assertions) passes
- `corpus/runMassTest.R` — the parse rate over `corpus/TEST` does not fall
  except where a paper's parse was previously wrong
- `corpus/measureMisparse.R` — the corroboration table of issue 24 moves in
  the right direction. If this defect is as widespread as suspected, **the
  "partial" bucket (422 files, 41.5%) should shrink and "fully corroborated"
  (496, 48.8%) should grow**, because a table that shed its follow-up columns
  now matches Carlisle's hand-entered values on every pair it returns. That
  is the quantitative test of the hypothesis, not just of the fix.
- `corpus/validateCarlisle2017.R` — the citable row of
  `docs/validation-ledger.md` is 2026-09-06: 5,041 usable trials, r = 0.9929
  against Carlisle, 89.1% within 0.05, **98.5% alarm concordance**. A parser
  change should not move these; if it does, the ledger needs a new row and the
  reason stated.

**Expect the headline parse rate to fall, and say so.** Issue 24 already makes
this argument: some of today's successes are wrong parses, and a fix that
refuses them trades a rate for correctness. The same applies here. A table
that today returns 58 rows and fails validation might, after a fix, return 27
rows and pass — or might correctly return nothing, if the baseline block
cannot be isolated. Both are improvements on a confident wrong answer.

**One thing not to do.** Do not make `validateData` tolerant of a missing N as
the primary fix. It would clear 36 of the 37 issues on this paper and make the
trial analysable, and the number it then produced would be computed over
baseline and post-treatment rows together. The visible failure would become an
invisible one.

## Pin the fix — tests that must be committed, not just run

**Steve's instruction, 2026-09-24: provide test cases so that this fix does
not regress with future PDF parser changes.** The suite is the only durable
record of what this defect was. It currently stands at **127 files and 3,194
`expect_` assertions**, and it is what will still be here when everyone has
forgotten this document. A fix that passes the checks above but leaves nothing
behind in `tests/testthat/` has not been finished.

Three tests, in the repository's own idiom.

**1. The engine fixture — no PDF, no corpus.** The 27 rows of Table 1 above,
three arms, N = 8 each, with the printed precisions, asserted against
`P_Calc` at approximately 1.2e-6. Pure numbers, so it runs anywhere and
pins the published answer permanently. This one also belongs in
`docs/validation-ledger.md` as a named single-trial check: the ledger
currently records agreement with Carlisle 2017 in aggregate, and has no entry
anywhere that ties the engine to a single published Monte Carlo p computed by
the method's own authors.

**2. The layout regression — synthetic, following `test-real-layouts.R`.**
That file already establishes the convention and states the reason: "We cannot
ship the articles themselves, so the typography is rebuilt with the `pdf()`
device." Do the same here. The synthetic page needs the three features that
broke this parse, and it should assert against each independently:

- a baseline block of arm columns **followed on the same rows by a second
  block of post-treatment columns**, under a header that spans them (this is
  the defect; assert the parse stops at the baseline block)
- **no N anywhere in the table**, the group size given only in synthetic
  Methods prose above it (assert whatever the chosen remedy is — N recovered
  from the prose, or an explicit refusal — but assert it)
- arm names in a header row that the current reader collapses to `<NA>` and a
  fragment (assert three named arms)

Build it so each assertion fails for its own reason. A single "does it parse"
test would pass again the moment any one of the three regressed.

There is a neighbouring file, `test-armn-recovery.R`, which suggests arm-N
recovery already has a home and conventions; the N half of this may belong
there rather than in a new file.

**3. The end-to-end check on the real PDF — corpus tooling, not the suite.**
The suite is deliberately corpus-free (AGENTS.md: "all from synthetic data and
synthetic PDFs, no corpus or Carlisle files needed"), and
`Fujii/PMID_11375852.pdf` is a retracted copyrighted article that should not
be committed. Put this where the corpus checks live, and have it skip cleanly
when the file is absent, so it runs on Steve's machine and is silent in CI.
It asserts the four things listed under "How to know it is fixed" — 27 rows,
three named arms, no post-treatment values, validation passes — and the trial
p near 1.2e-6.

**Why all three rather than the last one.** Test 3 is the most convincing and
the least durable: it depends on one file on one machine. Test 2 is what
actually protects the fix from the next parser change, because it will run in
CI forever and fails loudly when the baseline block starts running on again.
Test 1 protects the engine independently of both.

## Scale of the question

How wide is this? Unknown, and worth measuring before it is fixed:

- 22 of 27 canine Fujii trials failed. All are repeated-measures diaphragm
  studies with baseline-and-timepoint tables.
- 26 human Fujii trials also failed; their issue frames were not captured
  (the batch script discarded failed parses; that has since been fixed, but
  those 26 have not been re-run).
- **Boldt is the open risk.** That corpus is 175 cardiac-surgery trials, many
  of them repeated-measures with the same table shape, and unlike Fujii there
  is no published ground truth to catch a wrong answer. That run is being held
  until this is understood.

`corpus/measureMisparse.R` already scores extracted (MEAN, SD) pairs against
Carlisle's hand-entered values. A table that includes follow-up columns would
show as **partial** corroboration — every baseline pair matching, every
follow-up pair not — which suggests the 41.5% "partial" bucket in issue 24's
table may contain this defect in quantity, mixed in with the variables
Carlisle simply never entered.

## What was not done here

`ISSUES.md` was deliberately not edited. AGENTS.md asks sessions to check for
peers before assuming a branch, PR or file is theirs, and this session cannot
see the repository's other work. Filing this as a numbered issue — and
deciding whether it belongs under 24 or beside it — is left to a repository
session.
