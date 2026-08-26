# IntegrityAnalysis — open issues

Working list of outstanding work, newest thinking first. Each entry says what
the work is, why it matters, and what "done" looks like. Closed items move to
the bottom rather than being deleted, so the reasoning survives.

---

## Where things stand — 2026-08-21 (session handoff)

**UPDATE 2026-08-25 end of day.** Landed today, all on main and
deployed: journal-style wide-spreadsheet input (PR #60), median
[Q1, Q3] in the shared engine (#61), Word .docx manuscript input
(#62), seven engine repairs from the vocacapsaicin four-format
verification (#63, #65), folder-crash resilience with per-file
subprocess batching and progress (#64), the medRxiv gentle harvester +
OneDrive corpus backup (#66, nightly scheduled tasks), the BYOK AI
assist (#67 - production demo succeeded: paste key, upload, green
AI-read rows), workflow install hardening (#68), docs (#69), and
immediate API-key validation with green/red verdicts (#70). QUEUED FOR
TOMORROW: (a) the recertification below; (b) restructure this file to
open-issues-first (Steve approved; worktree C:/Temp/ia-issues-rewrite,
branch issues-restructure); (c) fold PDF parsing of freshly harvested
medRxiv files into the nightly job using a snapshot-installed library
(R CMD INSTALL to a private lib - never load_all from the live tree
in corpus children); (d) pull PubTables-1M (issue 20); (e) rerun the
A&A assembly (command below) and report the gross rate.

**RECERTIFIED 2026-08-25 late (branch caption-rescue): parse rate
84.9%** (1,584 of 1,865), from a full single-engine rerun of all 1,865
PDFs against an R CMD INSTALL snapshot of that branch; the committed
corpus/ParseOutcomes.csv IS that run. Three same-day deltas: (a) vs a
clean snapshot of TODAY'S MAIN (82.6%, 1,541): +43 newly parsed,
0 newly failed - the branch's three caption fixes are purely
additive - plus 83 winner changes that move toward demographics
tables (mean variables 4.7 -> 7.2, continuous rows 2.9 -> 5.1,
arms-with-N 1.0 -> 1.6, skips down); (b) vs the contaminated
certified CSV: +47/-13, net +34; (c) the contamination measured:
the certified CSV vs today's main disagree on 19 outcomes and 306
diagnostics rows - the certification's 5 "newly failing" files all
fail under today's main too (git bisect dates every flip to PR #51,
and all five OLD successes were misparses - see the caption-rescue PR
for the adjudication). Of the 214 files the certification called
newly parsed, 212 survive recertification; the other 2 fail under
today's main as well (stale cache, not engine). Safe to cite:
84.9%, +43 vs main, and the r = 0.9930 Carlisle-2017 validation.

**SUPERSEDED (contaminated - see above) 2026-08-25 evening - Carlisle
regression: parse rate 71.9% -> 83.1%** (1,550 of
1,865; +214 newly parsed, 5 newly failing, all five at candidate
selection - adjudication chip filed; among files parsed both ways,
variables/file up +0.25 mean). The regenerated
corpus/ParseOutcomes.csv IS the new committed baseline. The
regeneration crashed once at final assembly - a pre-existing TRE
regex-escaping bug in buildParseOutcomes.R, fixed in the same commit
(paths are stripped as fixed strings now); all 19 chunks were already
cached, so the rerun was instant. The A&A run (C:/temp/AAW_20260825,
6,328 PDFs, the whole submission archive) is still grinding and its
IN-MEMORY parent still has the buggy assembly, so expect it to crash
at the very end tonight - rerun `Rscript corpus/buildParseOutcomes.R
C:/Temp/AA C:/temp/AAW_20260825` and it assembles from cache in
seconds.

**A full Carlisle-2017 validation run is IN FLIGHT**, launched detached
2026-08-21 morning (survives every session): the shipped engine over
all 5,080 One Sheet trials at mMax = 100,000, via the committed runner
`corpus/validateCarlisle2017.R`. Its 100-trial pilot gate PASSED first:
r = 0.9930 vs Carlisle's stored p-values, median |diff| 0.0164, alarm
concordance 99.0%, nothing refused. Progress:
`.NewCarlisle/validation2017/run.log` (a stats block prints at the
end); results accumulate in `results.csv` every 25 trials; if the
machine restarts, rerun `Rscript corpus/validateCarlisle2017.R` - done
trials are skipped. NEXT SESSION: read the stats block, record it in
issue 3, and adjudicate the outliers (|diff| > 0.10; ~112 expected
from the 2026-08-17 run, plus ~12 known his-p=1 artifacts).

**A parallel session is active in this repository** (ParsePDF glyph
work): PR #53 is OPEN and theirs; branch symbol-pua-and-dash-evidence;
worktree C:/Temp/ia-glyphs and private library C:/Temp/ia-lib are
THEIRS - do not touch. Their branch predates renv and the cleanup fix;
both reconcile when they merge main. See AGENTS.md "Working alongside
other sessions".

**The pipeline is fully mechanized and verified end to end** (all on
main): every PR runs the 586-passing-assertion suite + security
tripwire inside R CMD check on the renv-pinned environment (R 4.5.3,
121 runtime packages, lockfile refresh policy in AGENTS.md "renv");
production deploys only after R-CMD-check passes, at the tested SHA,
from a staged directory; preview apps purge on PR close with 15-minute
retries that fail red; the CRAN canary checks latest-everything every
Monday.

**The app** (production, deployed): five ways in including zipped
multi-file upload; editable validated grid with issue colors; adaptive
one-sided Monte Carlo; three-tab results workbook with an overall
Stouffer P; optional PowerPoint of actual-vs-expected distribution
graphs (Graph results checkbox). Security threat model and standing
conclusions in AGENTS.md "Security".

**Corpus efforts** (see corpus/README.md and the project memories):
Carlisle manual queue ~3,500 trials with a daily filing loop
(.NewCarlisle/inbox -> fileDownloads.R); Boldt (104 queued) and Fujii
(185) worklists built, both 100% manual - every legal automated route
is exhausted and the reasoning recorded.

**Open issues:** 1 (API), 3 (validation - in flight above), 5 (MC
parallelism; pairs with 11), 7 (survey), 8 (AI in deployment - BYOK
direction), 11 (live analysis feedback), 12 (median/IQR validation),
22 (scanned tables - vision tier IMPLEMENTED, tesseract tier open),
23 (verbose-column layout fixes from medRxiv).

## 22. Scanned tables: page images to the AI, then local tesseract OCR

The first night of the medRxiv harvest (issue 21) earned its keep
immediately: 10.1101/19007195 is an ordinary text manuscript whose
Table 1 page alone is a scanned picture - zero text-layer characters
on page 19, 53,970 on the other 20 pages. No text route can reach that
table. Steve's observation (2026-08-26): the A&A corpus could never
have taught us this, because A&A's submission requirements precluded
scanned tables - a corpus of curated submissions measures the gate,
not the wild.

Two tiers, agreed 2026-08-26:

**Tier 1 (IMPLEMENTED 2026-08-26) - page images to the AI assist.**
`parseBaselineTableAI()` now detects pages with no text layer
(`.ppImageOnlyPages`) and sends them as rendered 150-dpi PNG content
blocks instead of text. In a mixed document the image-only pages are
tried first (when a table was pasted in as a picture, that is where it
is); a fully scanned document uses a local tesseract OCR pass to
locate the table page by caption score, then still sends the image
(the model reads a page picture far better than OCR-mangled text).
BYOK consent language already covers it - the uploaded documents'
content, text or image, goes only under the user's own key.

**Tier 2 (IMPLEMENTED 2026-08-26) - tesseract OCR into the
deterministic engine.** All three planned pieces landed: (a) automatic
engagement - `parseBaselineTable` retries image-only pages with
`ocr = TRUE` when the AI route is unavailable (no key, `ai = "never"`)
or itself failed; (b) whole-table pale-cyan shading (`#d2ecef`,
deliberately distinct from incongruent blue and derived green) driven
by engine `"heuristic-ocr"` / provenance `"ocr"`, with the legend and
hover note: OCR misreads digits (3/8, 1/7) - verify every cell, or
enter a key for the higher-accuracy AI read; (c) the validation run
(Steve's design: the AI assist validates tesseract). Three repairs
were needed to make it real: tesseract reads the plus-minus sign as a
plain "+" (three shapes; repaired in the OCR adapter only, never the
global normalizer), `.ppOcrPages` had the pdf_convert filenames-
template bug, and the engine's no-caption fallback collapsed
explicitly-requested pages to one vocabulary-best page (a CONSORT
diagram outscored the actual table).

**Validation verdict (2026-08-26).** On a clean render (the synthetic
suite page OCR'd at 300 dpi), tesseract-into-engine reproduces the
text-layer parse EXACTLY - every variable, value, and rounding digit
(pinned in test-ocr-tier2.R). On the real degraded scan
(10.1101/19007195, the table the AI assist read correctly and
completely), OCR produced noise: 34 of 286 cells, garbled labels,
junk values, no arm identity. A quality gate now rejects any OCR
result with no arm name and no arm N (the analysis could never run on
one), so degraded scans fail cleanly toward the enter-a-key
suggestion instead of surfacing garbage. Standing conclusion: OCR is
the no-key fallback for CLEAN scans; the AI image route remains the
quality path for real-world ones. OPEN want: a harvested scan clean
enough for OCR, to pin the end-to-end cyan path in the app against a
real file.

## 23. Layout repairs from the wild: statistic columns and superscript orphans

10.1101/19007542 (medRxiv, first harvest night): the deterministic
engine finds the right page and the right caption - "Table 1. Sample
characteristics.", sitting BELOW the table - then rejects every row
("no usable rows"). Four stacked hostilities, two of them worth
engine work because they are common in real journals:

- **Trailing test-statistic columns** (here t and p; elsewhere chi2,
  F). The arm columns carry "(N = 22)" headers; the statistic columns
  carry none. Detectable and droppable: a rightmost column block whose
  header matches `(?i)^(t|z|F|p|chi.?2?|x2)$` (or is empty) and whose
  cells are bare decimals with no N anywhere. The AI schema already
  excludes these by instruction; the deterministic engine should too.
- **Superscript orphans.** Footnote markers set as separate words ("A",
  "B", "&") land between cells and split them across visual lines
  ("0.02 &" on one line, its neighbor "0.89" alone on the next). Kin
  to the rotated-rail filter (.ppStripRotatedText): single-glyph words
  vertically offset from their line's baseline can be dropped before
  clustering.

The other two hostilities - row labels wrapped across lines with huge
vertical whitespace, and the stat tag buried mid-label ("Age (s.d.) in
years") - are the hard general case; diminishing returns, and exactly
what the AI assist is for (the model reads this page trivially).

## 1. Build the API

Expose the analysis so other programs can call it — the target is editorial
systems such as Editorial Manager linking to it automatically and silently for
fraud screening during peer review.

**Contract**

| | |
|---|---|
| Input | a single PDF **or** a spreadsheet (xls/xlsx/csv) |
| On pass | run the Monte Carlo; return a CSV of the analysis, plus confirmation the PDF was deleted |
| On fail | return **the partial table**, carrying as much extracted data as possible, plus what is wrong with it |
| Retention | none — the PDF is deleted and the caller is told so |

**Decisions already made**

- **A failure is not a bare error.** It returns the failed table so an editor or
  reviewer can fill the gaps and call the API again, this time with a
  spreadsheet instead of the PDF. A failed scan is a round trip, not a dead
  end — which means *the failure payload must itself be valid input to the next
  call*. ParsePDF's `writeIntegrityTemplate()` already emits exactly that
  layout.
- **No arm N, no analysis.** Without a hard-coded N the service returns a fail
  rather than running the Monte Carlo. This matters more than it sounds: about
  58% of rows ParsePDF extracts from real articles carry no arm N, because many
  tables never print it.
- **No AI in the deployed path.** Two independent reasons: every call would be
  billed to the maintainer's account at unbounded volume, and manuscripts under
  peer review are *unpublished*, so sending one to a third-party API is a
  confidentiality problem. A deterministic engine also guarantees that the same
  submission always yields the same verdict — which matters when the output may
  influence an editorial decision.

**Watch for**

- Annotation must stay out of the data columns. `server.R` decides a column is
  categorical if it is integer-valued with at least one `NA`, so a numeric
  "needs attention" flag would be silently swallowed as a category. Use a text
  column or a separate sheet.
- Return `$skipped` from ParsePDF, not a count: it names each unusable row *and
  why* ("median [range] — integrity analysis needs mean and SD"), which is what
  tells an editor where to look.
- A folder of PDFs must go through `parseBaselineTableFiles()`, never a loop:
  roughly 2% of real PDFs hang poppler indefinitely, R cannot interrupt it, and
  in a multi-user app an in-process hang takes the worker down for everyone.
- Realistic expectation: fed a single PDF, the deterministic path yields a
  fully analysable trial roughly a third of the time. The spreadsheet path is
  the reliable one; the PDF path is a convenience that will often decline.

---

## 2. Point https://integrityanalysis.io at the app

**Closed 2026-08-19** - see the Closed section at the bottom.

---

## 3. Validate the analysis against Carlisle's 2017 manuscript

**FULL RUN COMPLETE (2026-08-21, 57.8 min): the current shipped engine
reproduces Carlisle 2017.** All 5,080 trials joined, zero refused:
r = 0.9930, median |diff| = 0.0127, 90.3% within 0.05, alarm
concordance (p < 0.05 both ways) 99.0%; 39 his-p=1 z=+inf artifact
trials reported separately. Against the 2026-08-17 lost-scratchpad
benchmark (r = 0.991, concordance 97.4%): equal or better where it
matters. REMAINING: adjudicate the 121 outliers (|diff| > 0.10; 50 of
them disagree on the p < 0.05 alarm) - results and per-trial values in
`.NewCarlisle/validation2017/results.csv`; the worst five are recorded
in the results file (e.g. NEJM 670: ours 0.129 vs his 0.634).

Prior status for context (now historical): Corrected archaeology: the full
validation ALREADY RAN once, 2026-08-17, in a session scratchpad -
5,080 trials, r = 0.991, median |diff| 0.0095, 92% within 0.05,
alarm-zone concordance 97.4% - but its scripts were never committed
and the engine has since gained the adaptive staged scheme. Steve
ratified mid-p for ties (2026-08-20; already the app's convention).

The validation is now a COMMITTED, reproducible artifact:
`corpus/validateCarlisle2017.R` (pilot mode: 100 seeded trials at
m = 15,000; full mode: every trial at m = 100,000; resumable via
`.NewCarlisle/validation2017/results.csv` - rerunning skips done
trials). It reads the One Sheet raw rows through validateData()'s
native Carlisle aliases and joins to the repaired wide file by
journal + trial with the A&A >= 1235 numbering offset. The full run
was launched detached overnight 2026-08-21; check
`.NewCarlisle/validation2017/run.log` for progress and the final
stats block. REMAINING AFTER THE RUN: record the stats here, and
adjudicate the ~112 unexplained outliers (|diff| > 0.10) the
2026-08-17 run left open (plus ~12 known his-p=1 z=+inf artifacts,
reported separately by the script).

Reproduce the published results for the 5,087 trials in Carlisle's 2017
*Anaesthesia* paper from the same inputs, as an end-to-end check on the Monte
Carlo.

**Do this before issue 4**, since it settles whether the current implementation
is right, and before issue 5, so optimisation has a correctness baseline to
protect.

**Note the p-value convention.** Carlisle's published values are *folded*: he
and Steve treated P > 0.95 (too heterogeneous) as equally concerning as
P < 0.05 (too homogeneous), so every stored value is < 0.5, with 1 − P recorded
wherever Stouffer's sumz exceeded 0.5. Reproducing his numbers therefore
requires reproducing that convention. Issue 6 then changes it deliberately —
these are two separate steps and conflating them will make validation look like
a bug. (Pilot correction: the stored `p.value` column itself is the raw
one-sided value — it exceeds 0.5 freely; `p.value 2-sided` is the folded one.)

**Pilot results — 2026-08-16, 100 random trials, m = 15,000.** Run through the
app's own `validateData()` → `P_Calc()` from `One Sheet Carlisle Data.xlsx`,
compared against the repaired `Carlisle Data with PMIDs.xlsx`:

- **Direction confirmed**: our PLE correlates with his `p.value` as-is
  (r = +0.88), so both count small = too homogeneous.
- **Tie handling is the method difference.** As shipped, `P_Calc` counts all
  simulated ties into PLE (P(<) + P(=)), and agreement is mediocre (median
  |diff| 0.076, 36% within 0.05, always in the ours-higher direction — the
  signature of tie inflation on a rounding-discretized statistic). Recomputing
  as **mid-p** (P(<) + P(=)/2, recoverable from P_Calc's own PLE/PGE since
  PEQ = PLE+PGE−1): per-variable r = 0.996 with median |diff| 0.006; per-trial
  r = 0.995, median |diff| 0.013, **93% within 0.05**. Carlisle's published
  values are, in effect, mid-p. The residual is consistent with two
  independent Monte Carlos of finite size.
- **Decision needed from Steve before the full 5,087-trial run**: adopt mid-p
  (matches Carlisle; arguably the standard choice for discrete statistics),
  keep the current full-tie convention (more conservative — higher p, fewer
  alarms), or fold the choice into issue 6's redesign, which is deciding the
  p-value's meaning anyway. Validation should then be run with whichever
  convention is chosen for the comparison, and the app's convention documented
  either way.
- **Bookkeeping**: the two files' journal names differ (one-sheet uses BJA /
  CJA / EJA / NEJM / JAMA / "Anesthesia and Analgesia"; the wide file uses
  full journal names, `&amp;` included) — an 8-entry lookup joins them, to be
  used for the full run. Per-journal trial counts agree to within a few
  trials. The wide file's formula columns (`p.value 2-sided`, `Variables`)
  have no cached values and read as NA from R — recompute, don't read.

**FULL VALIDATION — 2026-08-17, VALIDATED.** All 5,080 joinable trials
(100% join with the lookup; zero rows dropped), m = 15,000, mid-p build
(PR #8): **r = 0.991 against Carlisle's stored p.value, median |diff|
0.0095, 92% within 0.05, alarm-zone (folded p < 0.05) concordance 97.4%**
(734 flagged by both, 75 ours-only, 55 his-only). The residual is
consistent with two independent Monte Carlos. Two artifact families
explain most of the worst tail, neither a method problem:

- **A&A numbering drift in the One Sheet**: its Anesthesia & Analgesia
  sequence skips the wide file's trial ~1234 and renumbers, so one-sheet
  trials ≥ 1235 correspond to wide trial t+1 (five more trials missing at
  the end account for the 1,282 vs 1,288 count). Correcting the offset
  realigned 49 trials from median |diff| ≈ 0.24 to ≈ 0.011. The One Sheet
  file itself has not been repaired — do that (or always apply the offset)
  before using it as a Carlisle ground-truth again.
- **The known his-p = 1 artifact** (12 of the 124 trials still off by
  > 0.10): a variable p of exactly 1 maps to z = +∞ (see the with-PMIDs
  repair notes); Steve's adjudication of those 33 rows is still pending.
  The other ~112 outliers are unadjudicated — most look like Monte Carlo
  extremes and per-variable count mismatches; the sorted list is
  `carlisle_final_validation.csv` (session scratchpad, also sent to Steve).

Remaining before closing: merge PR #8 (the mid-p convention the validation
ran under), and decide how far to adjudicate the 112 unexplained outliers.

---

## 4. Build a comprehensive test suite

**Closed 2026-08-19** - see the Closed section at the bottom.

---

## 5. Optimise the Monte Carlo

**Status 2026-08-20:** the adaptive staged scheme (1,000 -> 10,000 ->
100,000 replicates, escalating only while a row alarms) shipped
2026-08-17 and is the big practical win - typical rows now cost 1,000
replicates. Chunked simulation bounds memory; dqrng supplies fast
draws. Remaining: profiling, vectorisation of what is left, and
trial-level parallelism - which is the same plumbing as issue 11 and
should be designed with it.

Profile before changing anything, and keep issue 3's validation green
throughout.

Likely wins, in the order worth trying: vectorise across replications rather
than looping; pre-allocate the replication matrices; avoid recomputing per-trial
constants inside the replication loop; consider whether the simulation count can
be adaptive (stop early when the p-value is far from any threshold of interest).

Since trials are independent — no cross-talk — trial-level parallelism is
available and is the easiest large win for a whole-corpus run.

---

## 6. Change the p-value to one-sided toward homogeneity

**Closed 2026-08-20** (implemented 2026-08-17) - see the Closed section.
---

## 7. Survey other open-source research-integrity screens

Look for additional published, open screens that could be applied to the same
submissions and reported alongside the baseline analysis.

**Already tried and rejected — do not repeat without a reason:**

| Screen | Outcome |
|---|---|
| **Benford's law** | worthless here |
| **Repeating-digit tests** | worthless here |

Both almost certainly fail for the same reason: a baseline table supplies far
too few numbers for either test to have any power. Any candidate screen should
therefore be judged first on whether it can work on the order of tens of
numbers — which rules out most digit-distribution methods before any
implementation effort.

Worth considering instead are screens that use *structure* rather than digit
frequency: internal consistency of means against reported totals, SDs that are
impossible for the stated N and range, granularity tests (GRIM/GRIMMER — does a
reported mean exist for an integer-valued measure at that N?), and terminal
digit balance across arms rather than within a single table.

**Candidates raised by Steve, 2026-08-17:**

- **SPRITE** (https://shiny.ieis.tue.nl/sprite/, Heathers et al.):
  reconstructs the possible samples behind a reported mean/SD of a bounded
  integer scale. Passes the too-few-numbers test because it works on a
  *single* reported pair, not a distribution of digits. Complementary, not
  overlapping: it catches impossible or wildly implausible mean/SD pairs
  within one row, where Carlisle–Shafer catches improbable *agreement
  across arms*. Natural fit as a per-row plausibility flag (with GRIM/
  GRIMMER) in the validation pass — cheap, deterministic, no simulation.
- **Barnett's Bayesian baseline method**
  (https://f1000research.com/articles/11-783,
  https://aushsi.shinyapps.io/baseline/): a Bayesian re-formulation of the
  Carlisle approach modeling under/over-dispersion of baseline t-statistics
  with posterior probabilities instead of a frequentist p. Same evidence,
  different inferential wrapper — so it is a *cross-check*, not an
  independent signal. Worth reporting alongside if the posterior framing
  helps editors; the corpus/TEST mass-test set (61 verified PDFs +
  Carlisle expectations) is exactly the benchmark to run both methods on
  and compare verdicts, as Steve proposed.

Evaluation plan when picked up: run Carlisle–Shafer, Barnett, and
SPRITE/GRIM flags over corpus/TEST; compare per-trial calls; adopt what
adds discrimination, report what merely agrees as corroboration.

---

## 8. AI parsing in deployment - BYOK (APP SIDE IMPLEMENTED 2026-08-25)

**IMPLEMENTED in the app, 2026-08-25** (timed for Steve's outreach to
journal EICs, publishers, and WAME): a masked key field above the
upload box. With a key entered, document parsing switches from
ai = "never" to the fallback path - the deterministic engine still runs
first and its numbers still win; the AI fills gaps and, when no table
parses at all, asks for baseline data stated in the running text. As
designed here in 2026-08-20's direction update: the key is the
consent, the charges land on the key's owner, and the key is never
stored, never logged (upstream error text is scrubbed of it too),
never in a URL, and dies with the session. Guardrails as built:
AI-read lines paint GREEN in the grid ("verify against the
manuscript") and are tagged in provenance; a per-session document cap
(default 25, INTEGRITY_AI_SESSION_CAP) bounds spending even on the
owner's own key; a docx with the assist on quietly takes the
deterministic path (the fallback renders PDF pages). Third-party
deployments enable it permanently with INTEGRITY_AI_ALWAYS=true plus
their own ANTHROPIC_API_KEY - the gate is a policy, not a fork.
The user guide carries the consent language and the measured rescue
rates (91%/81%). Tests: test-ai-byok.R (fake-key graceful failure with
the deterministic result intact, key never in the log, cap, the
deployment pathway - no test makes a real API call).

STILL OPEN in this issue: the API-service side (per-request BYOK when
issue 1 is built), and any landing-page copy at integrityanalysis.io
describing the assist.

The rationale that shaped the build (kept because it still governs):

**The point is publication, not concealment.** The AI algorithm is part
of the academic contribution: visible, tested, and citable, with the
gate on the *spending*, never the *method*. Hence: the deployment can
use somebody else's key (a publisher runs their own instance with
`INTEGRITY_AI_ALWAYS=true` and their own `ANTHROPIC_API_KEY` - the gate
is a policy, not a fork); the prompts and JSON schema ARE the algorithm
(`.ppSystemPrompt()` / `.ppTableSchemaJson()` in R/aiFallback.R,
written to be read); and the evidence travels with it (the measured
rescue rates: 91% of known values on articles with no parseable table,
81% where the deterministic engine misread, both scored against
Carlisle where the deterministic engine scores zero).

*(Superseded and removed 2026-08-25 at Steve's direction: the original
design of a secret URL keyword known only to him - SHA-256/KDF gating,
token-leak analysis, and the injection notes - is no longer relevant
now that BYOK ships: there is no secret, only each uploader's own key.
The full design discussion survives in git history.)*

---

## 9. Fold ParsePDF into this repository

**Closed 2026-08-20** (merged 2026-08-17, PR #9; the old repository is
retired) - see the Closed section.
---

## 10. Restructure the repository as an R package (stanpumpR model)

**Closed 2026-08-20** (phase 5, the deploy trio, completed 2026-08-19;
the deploy gained its test gate 2026-08-20) - see the Closed section.
---

## 11. Live UI feedback while the Monte Carlo runs

Steve's request (2026-08-16). The p-value calculation can take a very long
time, and the user needs feedback while it runs. This is genuinely hard in
Shiny: the server is single-threaded, so while `P_Calc()` computes, the UI
is locked — no reactive flush, no log refresh, no button response.

What exists today, and its limits: `shiny::Progress` ticks once per
**trial** (its `$set()` pushes straight to the websocket, bypassing the
flush, which is why it works at all), and `bslib::input_task_button` shows
a busy state — but within one long trial nothing moves, the comments log
(`invalidateLater(1000)`) freezes, and nothing can be cancelled. Dean's
PR #2 (full-page spinner, closed 2026-08-20 as superseded) was another
symptom of the same itch; a spinner still cannot update *during* the
computation. (2026-08-20: download-side feedback exists - the graphs
build counts its slides and greys its button - but the ANALYSIS itself
still only ticks per trial.)

The real fix is to take the computation **off the main thread**:

- **`shiny::ExtendedTask`** (Shiny ≥ 1.8.1) + {promises}/{future} is the
  designed-for answer, and `input_task_button` — already in the app — is
  its intended companion: the button binds to the task, the UI stays live,
  per-trial results can stream into the log as they complete, and a Cancel
  button becomes possible.
- A worker process (callr/future multisession) reporting progress through a
  file or socket the main session polls with `invalidateLater` is the
  portable fallback.
- Within-trial granularity: P_Calc's row loop can report progress per ROW
  (pass a callback) once progress can actually reach the client.

Do together with issue 5 (optimise the Monte Carlo): parallelising trials
with {future} and moving the loop off the main thread are the same
plumbing, and should be designed once. Test cancellation and the
two-users-at-once case on shinyapps.io, where worker processes are billed
compute.

---

## 12. Median/IQR rows (IMPLEMENTED 2026-08-17; validation approach open)

Steve's design (2026-08-17), confirmed after discussion: **Q1 and Q3
columns** (two quartiles, not a single IQR width — the quartiles carry the
asymmetry, and papers print `median [Q1–Q3]` anyway); when both are filled
in, **MEAN is read as the MEDIAN** and SD/SE must be empty. Validation
enforces completeness (both quartiles, N, median), unambiguity (no SD/SE
alongside), and Q1 ≤ median ≤ Q3.

**The Monte Carlo null** reconstructs the common population from the pooled
(N-weighted) median and quartiles with a **3-term metalog** (Keelin 2016):
matches m/Q1/Q3 exactly including skew, closed-form quantile function
(`X = a1 + a2·logit(u) + a3(u−½)·logit(u)`), reduces to a symmetric
logistic when the quartiles are symmetric. Steve's shared Gemini analysis
(https://share.gemini.google/p0YqsFwQKEIw) surveyed the options; note its
printed a3 coefficient is off by a factor of 2 against its own derivation —
the correct value is `a3 = 2(Q1+Q3−2m)/ln 3`, pinned by an
exact-quantile-recovery unit test. Rows with |a3/a2| > 1.667 (metalog
validity bound) are refused with a message rather than mis-simulated.
Simulated arm MEDIANS are rounded as printed (observations to
ROUND_OBSERVATION, medians to ROUND_MEAN) and compared by the same
between-arm sum of squares, lower mid-p tail, Stouffer combination.

**Validation status**: no Carlisle-style ground truth exists for median
rows. In place: a calibration property test (honest lognormal trials →
p roughly uniform; in the testthat suite) and direction tests. Worth
considering later: a larger calibration study across N, skew, and rounding
regimes, and checking the metalog null against other plausible shapes for
sensitivity.

---

## 13. Color-coded grid cells replace the parse-error list

**Closed 2026-08-20** (implemented 2026-08-18) - see the Closed section.
---

## 14. Documentation moves to HTML

**Closed 2026-08-19** - see the Closed section at the bottom.

---

## 15. Journal-style baseline table view for editors

**Closed 2026-08-20** (implemented 2026-08-19) - see the Closed section.
---

## 16. Graphs of actual vs expected squared-error distributions

**Closed 2026-08-20** - see the Closed section at the bottom.

---

## 21. A medRxiv preprint stress-test corpus (no ground truth, by design)

Steve's idea (2026-08-25): preprint servers permit programmatic access,
so harvest randomized-controlled-trial preprints into a test corpus.
There is no ground truth for the values - what a preprint corpus buys
is the opposite of validation: a firehose of AUTHOR-typeset PDFs (Word
exports, LaTeX, every table habit in the wild, no copyeditor), which is
exactly where parser crashes, hangs, and layout blind spots hide.
Journal corpora can never supply that diversity, because a copyeditor
has already ironed it out.

As built: `corpus/downloadPreprintRCTs.R` walks the api.biorxiv.org
metadata API for an interval (medRxiv by default - RCTs live there, not
on bioRxiv), keeps records whose title/abstract says randomized trial
(minus protocols, reviews, meta-analyses, post-hoc analyses), and
fetches each newest-version PDF. **Gentle by requirement** (Steve,
2026-08-25): one metadata page per second, one PDF per ~6 s with
jitter, an identifying user agent with a contact address, and the
instruction that any future rate trouble is answered by slowing down,
not retrying harder. Resumable manifest records DOI, version, date,
category, and LICENSE per file. The corpus lives under C:/temp and is
never committed (corpus/README.md rules). Feed it to
`corpus/buildParseOutcomes.R`; score CRASHES, HANGS, and skip-reason
distribution - never values.

Smoke-tested on one July-2026 medRxiv week (415 records -> 18 RCT
candidates -> 8/8 fetchable PDFs fetched and verified; one 403
recorded in the manifest and skipped).

**Continuous operation** (Steve: "it could run continuously on this
machine over a period of several weeks. Or more"): the metadata scan
caches per (server, interval) in candidates.csv/scanState.csv, so only
the first run walks the API; every later run downloads the next batch.
Two STANDING WINDOWS SCHEDULED TASKS registered 2026-08-25 on this
machine (view/edit in Task Scheduler):

- **"IntegrityAnalysis medRxiv harvest"** - daily 02:00: 150 PDFs per
  night at ~2 min each over the interval 2019-06-01..2026-08-25 into
  C:/temp/medrxiv_rct; the first night also performs the one-time
  metadata walk. Exhausts the candidate list in a few weeks, then
  nightly runs no-op; extend the interval to pick up new postings.
- **"IntegrityAnalysis corpora backup"** - Sundays 03:00:
  tools/backupCorpora.ps1, an ADDITIVE robocopy of every local corpus
  (journals, AA, medrxiv_rct, .NewCarlisle, .Boldt, .Fujii, the Shafer
  studies folder - ~13 GB at filing) into
  OneDrive/IntegrityAnalysisCorpora. Additive on purpose: a local
  deletion never propagates to the backup (the 2026-08-19 corpus wipe
  is why this exists). Check that the OneDrive plan has headroom.

---

## 20. Docling cross-check harness and PubTables-1M fixture mining

Filed 2026-08-25 (Steve's request, after surveying the document-parsing
landscape while the vocacapsaicin corpus work landed). Two additions to
the parser optimization loop (AGENTS.md), both LOCAL CORPUS TOOLING
ONLY - nothing here ever ships in the deployed app, which stays
deterministic, offline, and R-only.

**UPDATE 2026-08-26: the PubTables-1M data is DOWNLOADED** - the six
annotation/word archives (8.0 GB: structure annotations
train/val/test, table word boxes, filelists, per-PDF annotations; the
~100 GB of rendered page images deliberately skipped - our engine
consumes word boxes, which PubTables ships separately) are at
C:/temp/pubtables1m, byte counts verified against the Hugging Face
listing. Next: unpack, and mine test-split tables whose word boxes
feed .ppParseBlock via the synthetic-coordinate seam.

**Why the survey did not change the architecture.** The 2026 academic
benchmark of nine table extractors (arxiv 2511.16134, ~44k scientific
tables) puts the field's best - IBM Docling's detection + TableFormer
models - at ~0.99 table detection but only ~0.86 end-to-end
cell-STRUCTURE accuracy on clean published biomedical tables, and
practitioner reports show its VLM mode hallucinating column names and
repeating values on dense numeric data. A hallucinated number is worse
than a refusal in a fraud screen. And structure is the easy half:
none of these tools attempt the semantic layer - mean (SD) vs n (%),
printed rounding, arm Ns, Total columns, IQR gates - where nearly all
of the vocacapsaicin corpus defects lived. The deployed engine's
division of labor stands. What the field CAN contribute:

- **A Docling cross-check harness** - the same play as the 2026-08-21
  AI comparison that exposed the 583 arm-N-blocked skips: run Docling
  (Python, local, pinned version) over the corpus failure set and diff
  its cell grids against the engine's. Where Docling finds a grid we
  miss, that is a targeted repair with the failure in hand; where the
  two disagree on cells, one of them is wrong and the PDF says which.
  Docling's grids feed the engine the way the docx path already does
  (a cell matrix through the synthetic-coordinate adapter into
  .ppParseBlock), so a rescued grid can even be re-scored semantically.
- **PubTables-1M fixture mining** - Microsoft's ground-truthed corpus
  of 947,642 tables from PMC articles
  (huggingface.co/datasets/bsmock/pubtables-1m, 117 GB total). We do
  NOT need the page images that dominate that size: the structure
  annotations carry bounding boxes in PDF coordinates, and the "words"
  files hold extracted words with positions - the same shape
  pdftools::pdf_data() feeds the engine - so the annotation + words
  archives (a few GB) allow scoring the engine's grid against ground
  truth directly, and layout patterns our 1,865-article corpus lacks
  become synthetic fixtures. Every sample maps to a PMCID, and the PMC
  open-access subset is bulk-retrievable, so full source PDFs for
  end-to-end fixtures stay inside the licensed-download-only policy
  (corpus/README.md). Store under C:/temp (never committed).
- **Adopt TEDS** (tree-edit-distance similarity over table structure)
  as a third corpus score alongside parse rate and Carlisle value
  accuracy - it grades the grid; the value-accuracy score grades the
  numbers; parse rate grades coverage.

Done looks like: the annotation/words subset of PubTables-1M on local
disk with a scoring script in corpus/; a Docling runner + diff report
over the current ParseOutcomes failures; at least one round of repairs
with fixtures pinned, scored the mandatory both ways (parse rate AND
value accuracy - a grid win that misreads numbers is a regression).

---

## 17. Journal-style wide spreadsheets as input (IMPLEMENTED 2026-08-21)

Steve's request (2026-08-21): the app must read an Excel spreadsheet in
"the usual form" - variables as rows, arms as columns - i.e. exactly the
journal-style table the app itself generates as the Editor's View
download (issue 15). The specified acceptance test: generate that table
from a validated frame, feed it back through the input parser, and
verify the validated result matches the frame it came from.

As built (R/parseWideTable.R, integrated in the upload observer ahead of
the plain-spreadsheet reader): detection is conservative (a "(n = 15)"
arm header, or a Variable/Characteristic label column over rows of
recognizable cells; a header carrying the template's own TRIAL/ROW/N/
MEAN/SD names is vetoed so template files keep flowing to
validateData()); both generator shapes parse (one sheet per trial, and
the results workbook's stacked "Trial: <id>" blocks - re-uploading the
whole three-tab results workbook reads just the Baseline Tables sheet);
and per Steve's scope decision the parser is TOLERANT: arbitrary arm
headers ("Control (n=50)", "Treatment"), "mean ± SD", untagged
"a (b)" (label-driven SD-vs-percent, defaulting SD), "n (%)" rows
(count + complement, mirroring the PDF engine), "; n = 14" per-line N
overrides, and un-indented count rows under a category header.

Decisions worth remembering:

- **Median intervals are emitted only when the label says IQR** ("median
  [Q1, Q3]", "(IQR)", "quartiles"). A label saying "range", or saying
  nothing, sends the row to the red-cell skip path: an IQR and a range
  both straddle the median, so the numbers cannot distinguish them, and
  a wrong guess would feed the metalog null in a fraud-screening
  verdict. (The PDF engine's parallel change is issue 18.)
- **ROUND_OBSERVATION = ROUND_MEAN** (not the PDF engine's +1): the wide
  format never prints observation granularity, and matching
  validateData()'s own default is what lets the round trip close
  exactly.
- Skipped rows use the PDF branch's contract - they arrive as grid rows
  with red ROW cells and the reason on hover.
- Not in v1, skipped with reasons: fraction cells ("15/10"),
  percent-only cells. Known limitation: a cell Excel typed as a NUMBER
  loses trailing zeros ("12.10" reads as "12.1"), so printed-precision
  recovery is exact for text cells (everything the app generates is
  text).

Validation: tests/testthat/test-wide-table.R (round trips over both
shapes plus the app-level upload, and the adversarial cases), with the
shared fixture in helper-baselineTable.R. Template.xlsx/Example.xlsx
non-detection is a pinned regression test.

---

## 19. Word .docx manuscripts as input (IMPLEMENTED 2026-08-21)

Steve's request (2026-08-21): parse a manuscript in Word format by the
same rules as the PDF engine, allowing for the submission convention -
tables at the end of the file, captions probably (not necessarily)
before each table.

As built (R/parseDocx.R): a Word table is already a grid of cells, so
the docx path fabricates the word-coordinate `lines` structure and
feeds the PDF engine's `.ppParseBlock()` VERBATIM - zero changes to the
most heavily test-pinned code in the package - which buys every cell
rule for free (mean ± SD, footnote-driven "a (b)" disambiguation,
n (%) complements, percent conversion, SD-vs-SE, arm-N recovery from
the Methods text). Column c's words sit at x = (c-1) x pitch, pitch
computed from the widest cell so .ppClusterColumns() always sees each
Word column as one cluster (pinned by test). Every table in the
document is a candidate scored by the same caption-preference rules as
the PDF path, so end-of-manuscript placement does not matter - and
caption-above-table is the engine's NATIVE orientation, so the
submission convention costs nothing. `pages` in the result is the
table's ordinal (docx has no pages); `engine` is "heuristic-docx".

Decisions worth remembering:

- **Dispatch is by extension inside parseBaselineTableHeuristics()**,
  keeping the exported API (and the historical `pdfFile` name) stable -
  so inst/scripts/parseOne.R needed NO change, eliminating the
  inst/-desync failure mode PR #10 hit.
- **docx goes through the subprocess batcher** like a PDF: a .docx (zip
  of XML via officer/libxml2) parses as data and cannot execute, but
  the threat model says the manuscript author is the adversary, and
  crafted XML can stall or exhaust the parser; the per-file OS timeout
  contains that for free.
- **The AI fallback is refused for docx** (it renders PDF pages); the
  deployed app always runs ai = "never" anyway.
- **officer quirks, measured on fixtures**: docx_summary()'s doc_index
  is unique per CELL, and row_id runs on across tables - tables are
  reassembled by doc_index continuity and rebased. Do not "simplify"
  the grouping back to doc_index equality.
- Punted (documented in the architecture map): "Table 1 continued"
  split into a second Word table is not stitched; vertically merged
  cells keep their text in the first row only; a pasted IMAGE of a
  table has no text to read and fails with a message.

Validation: tests/testthat/test-parse-docx.R over synthetic officer
fixtures (helper-syntheticDocx.R) - submission format end to end,
footnote disambiguation, p-column drop, no-caption table, decoy results
table out-scored, arm-N recovery with CONSORT review flag, ragged
cells, adapter cluster pinning, the subprocess path, the app-level
upload, and the zip allowlist. The median-through-docx test activates
automatically once issue 18's engine change merges.

---

## 18. Parse engine emits median [Q1, Q3] (IMPLEMENTED 2026-08-21)

Steve's decision (2026-08-21, while scoping the docx work): the engine's
unconditional skip of `medianRng` cells ("integrity analysis needs mean
and SD") predated issue 12 - the app has accepted median/Q1/Q3 rows
since then (metalog null) - so the skip was stale, and median support
belongs in the shared parse engine now rather than as a future issue.

As built (R/tokenize.R + R/parseBaselineTableHeuristics.R):

- The `medianRng` token gained the comma/semicolon separator ("127
  [98, 160]" - the printed IQR form, which the dash-only pattern never
  matched) and now carries its THIRD number (`num3`/`dec3`; extraction
  is structured via `.ppMedianParts`, because a bare number grep read
  the separator dash of "127 [98-160]" as a minus sign).
- **Emission is gated on text, never numbers**: an IQR and a min-max
  range both straddle the median, so they are numerically
  indistinguishable, and feeding a range into the quartile-matched
  metalog would be a correctness bug in a fraud-screening verdict. The
  row's own label outranks the caption/footnote (one table can print
  IQR and range rows side by side); "interquartile range" is recognized
  as an IQR statement, not a range statement. Verdicts: IQR stated ->
  emit MEAN(=median)/Q1/Q3 (SD/SE empty, ROUND_MEAN from the printed
  median); range stated -> skip "the analysis needs quartiles (Q1/Q3),
  not the range"; nothing stated -> skip "median with an unlabeled
  interval - if it is an IQR, enter median/Q1/Q3 by hand". A median
  outside its own interval also refuses.
- Q1/Q3 columns appear in the output only when a median row was
  actually emitted - `.ppBaseColumns()` is unchanged, because the AI
  path and the hybrid merge index by it and adding two always-empty
  columns would clutter every parse.

The wide-spreadsheet parser (issue 17) applies the same gate on its own
cells; the docx parser (issue 19) inherits this engine change for free.
Validation: tests/testthat/test-parse-median.R (all three gate
verdicts, both separators, label-beats-footnote, end-to-end
validateData acceptance); the existing median [range] fixtures in
test-parse-synthetic.R and test-app-pipeline.R still skip, now with the
quartile-focused reason.

---

## Closed

### 2. Point https://integrityanalysis.io at the app (closed 2026-08-19)

Went with the landing-page design the issue recommended, served by
GitHub Pages from `site/` in this repository (published by
`.github/workflows/pages.yaml` on every push to main):

- https://integrityanalysis.io - landing page: the method (screening
  signal, never a verdict), usage, the data-retention promise stated
  before anyone uploads, Carlisle 2012/2015/2017 by DOI, Launch buttons.
- https://integrityanalysis.io/app - stanpumpr.io-pattern full-screen
  iframe of the shinyapps deployment, keeping the domain in the address
  bar (shinyapps serves its own HTTPS inside the frame - no plan
  upgrade needed).
- https://integrityanalysis.io/guide.html - the user guide, republished
  from the same file the app serves.

DNS stayed at pairNic (four A records to GitHub Pages IPs + www CNAME
to stevenlshafer.github.io, replacing the old HTTP-only forwarder).
Let's Encrypt certificate provisioned by GitHub; HTTPS enforced. When
certificate provisioning stalls after a DNS change, removing and
re-adding the Pages custom domain restarts it (it issued within a
minute of the toggle). Built for inviting journal editors-in-chief
after John Carlisle's review.


### 4. Build a comprehensive test suite (closed 2026-08-19)

Done across the 2026-08 feature PRs and the consolidation PR. The suite
(tests/testthat/, 514 assertions) now covers every priority the issue
listed: the input contract (`test-input-contract.R` - name
normalisation, Carlisle aliases, `is_category`, graceful failure on
missing required columns, which was found CRASHING the session and
fixed in the same PR); known-answer Monte Carlo under fixed seeds
(`test-known-answer.R`, including the documentation's worked example at
p = 0.0495 and the categorical direction check); degenerate inputs
(zero-SD arms, N = 1, single arm, degenerate categoricals, single-line
categoricals, empty rounding columns); and the round-trip
(`test-app-grid.R` - Download Table re-imports and revalidates
identically). The app pipeline runs headlessly end to end
(`test-app-pipeline.R`: upload -> validate -> analyze, re-run
non-append, purge-on-exit, synthetic-PDF-to-grid-to-analysis), plus the
feature suites added with their PRs (cell colors, appending uploads,
baseline view, median/IQR, adaptive m). Everything runs from synthetic
data and synthetic PDFs - no corpus or Carlisle files needed - so the
suite is CI-ready (the GitHub Actions issue remains open in the
restructure plan, phase 5).

TESTING RULE learned the hard way: never hand a real file's path to
`input$upload` in `testServer` - stage a copy in its own subdirectory
of `tempdir()` first (the purge-on-exit handler deletes uploaded
paths).


### 14. Documentation moves to HTML (closed 2026-08-19)

Done exactly as the issue recommended. The Word original became
`docs/user-guide.md`, maintained in the repository and rendered by
pandoc to the self-contained `inst/extdata/IntegrityAnalysis.html`
(regeneration command in the Markdown's header comment and AGENTS.md).
The sidebar's "Download Documentation" button is now a **View
Documentation** link to https://integrityanalysis.io/guide.html, opened
in a new tab - the very same file, republished by
`.github/workflows/pages.yaml`, so the guide a reader sees is always the
guide the deployed app was built from and no one reads a stale copy out
of their Downloads folder. No PDF is generated; nobody asked for the
file back.

Closing it also completed the guide's "Results and downloads" section,
which now describes all three worksheets of the results workbook - the
`Test Results` audit trail column by column, the `Baseline Tables`
reconstruction and its formatting rules, and the one-line-per-study
`Summary` - rather than listing the tabs.


### 16. Graphs of actual vs expected squared-error distributions (closed 2026-08-20)

Built the day it was filed. A **Graph results** checkbox sits beside
Download Results; ticked, the download becomes a zip of the workbook
plus `Integrity Analysis Graphs.pptx`. The deck follows the granularity
settled that morning: an all-trials slide (observed cumulative
distribution of trial p-values against the uniform diagonal - the
Carlisle 2012 Fujii figure), one slide per trial over its variables,
and one slide per variable with p <= 0.01 showing the expected
distribution of the squared-error statistic with the observed value
marked in red - the Monte Carlo draws the engine had always generated
and discarded, now kept by a collector that leaves the returned results
bit-identical (pinned by test).

Steve's Excel-tabs alternative was considered and declined: native
Excel charts cannot express these figures (an ECDF against a diagonal,
a density with an observed marker), metafile paste is a Windows-only
idiom and the server is Linux, and images in worksheet tabs neither
scale nor print. The metafile INSTINCT - editable vector graphics - is
delivered better in the deck itself: rvg inserts every graph as native
PowerPoint drawing objects, so axes, bars, and labels can be restyled
by hand. Slides are also simply the right habitat for what these are:
exhibits, shown to editors and integrity committees.

Implementation: officer + rvg (both CRAN); the collector hooks
.stagedTail's first stage (1,000 draws, 8 KB per row, zero RNG
disturbance); the PowerPoint is built at download time only when the
box is ticked. R/distributionGraphs.R, tests in
test-distribution-graphs.R.


### 6. One-sided p toward homogeneity (closed 2026-08-20; implemented 2026-08-17)

The issue's one "still to do outside the code" - the PDF documentation
still describing the old two-column output - was resolved by issue 14:
the PDF is retired, and docs/user-guide.md documents the single-column
one-sided p (Steve confirmed complete, 2026-08-20).

The app reports a single one-sided p toward excessive homogeneity - the
demonstrated fraud signal (Fujii); heterogeneity is deliberately not
reported. As built: mid-p with the Davison-Hinkley floor per row;
"<0.0001" shown only when the 97.5% Clopper-Pearson bound licenses it;
Stouffer across rows, unfloored (accumulation IS the signal), with a
parametric-bootstrap interval when the trial p < 0.001. Downstream, the
same convention runs through the Summary sheet's overall P (2026-08-20)
and the distribution graphs (issue 16). The tie-convention question for
the Carlisle comparison lives in issue 3.

### 9. ParsePDF folded in (closed 2026-08-20; merged 2026-08-17, PR #9)

The parser lives in R/ as package code (8 parser files + the module
doc), its 295-assertion suite came with it, and the old private
repository is retired. Validated at r = 0.991 against Carlisle before
the move (issue 3 pilot). The corpus tooling (corpus/) and the
optimization loop (AGENTS.md) operate on it in place; the 2026-08-20
security review covered it (parses run in a time-limited subprocess;
poppler never executes document content).

### 10. Package restructure (closed 2026-08-20; phase 5 done 2026-08-19)

All five phases of docs/package-restructure-plan.md are live:
DESCRIPTION/R-package scaffolding, code moved to R/ with roxygen, the
testthat suite, R CMD check green in CI, and the deploy trio
(production deploy, per-PR preview apps, close-time cleanup). Since
then the pipeline gained the security tripwire (2026-08-20) and the
deploy now waits mechanically on R-CMD-check success, deploying the
exact tested SHA.

### 13. Color-coded grid cells (closed 2026-08-20; implemented 2026-08-18)

The grid carries the diagnosis: yellow = missing, red = unreadable
(parser skip rows keep their reason on hover), blue = incongruent, with
a legend that appears only when something is flagged. validateData()
returns the per-cell issue map; a custom handsontable renderer paints
it (writing via textContent - see the security review). The issue
taxonomy doubles as the API's machine-readable issues[] codes when
issue 1 is built. Incomplete parses under-detect (measured 2026-08-18:
a real alarm diluted from p = 0.014 to 0.099), which is why gaps are
conspicuous rather than silent.

### 15. Journal-style baseline table view (closed 2026-08-20; implemented 2026-08-19)

buildBaselineTables() reconstructs each trial's Table 1 from the
VALIDATED data - variables as rows, arms as columns with their Ns,
"mean (SD)" / "median [Q1, Q3]" / category counts, every value at the
printed precision the analysis assumed. Available as its own download
and as the results workbook's middle sheet: if the reconstruction
disagrees with the manuscript page, so did the analysis. Still a
candidate for the API response (issue 1).
