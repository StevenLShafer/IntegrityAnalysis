# IntegrityAnalysis — open issues

Open work only, newest first. Each entry says what the work is, why it
matters, and what "done" looks like. **Closed and fully-implemented
issues are removed rather than kept below** (restructure approved by
Steve 2026-08-25): every prior version of this file, including the full
text of every closed issue and the reasoning that closed it, survives
in git history — `git log --follow ISSUES.md`. Issue numbers are stable
and therefore gappy.

---

## Where things stand — 2026-08-26 (end of day, session handoff)

**Nine PRs merged and deployed today (#72–#80), all same-day from
Steve's live testing:**
no-training/confidentiality documentation for the AI assist (#72 — the
Commercial Terms bar training on API content; sourced in the guide);
scanned pages travel to the AI assist as page images (#73, tier 1 of
issue 22); the medRxiv harvester's RCT filter repaired against
referential abstracts (#74); tesseract OCR into the deterministic
engine with whole-table cyan shading (#75, tier 2); the three-column
UI — sidebar | workflow | data with a message box under the grid, the
Table.png explainer retired to the guide (#76); automatic re-read of
failed uploads when a key validates, plus the verdict-overlap fix
(#77); Template/Example downloads retired from the sidebar (#78); the
key verdict paints before the retry parse starts (#79); and the
medRxiv harvest moved to the S3 TDM channel (#80). Zip-upload limits
documented in the guide for Steve's outreach to statistical editors
(direct docs commits).

**Citable numbers for outreach** (Steve is writing EICs, publishers,
WAME, and statistical editors this week): parse rate **71.9% → 84.9%**
over the 1,865-trial Carlisle corpus (single-engine recertification,
PR #71, purely additive vs prior main); **r = 0.9930** against
Carlisle 2017 across all 5,080 trials, median |diff| 0.0127, **99.0%
alarm concordance**; AI-assist rescue rates 91%/81%; the live demo
flow (paste key → green check → upload → green rescue, now with
automatic re-read). A&A submission archive gross rate: 54.5% of 6,328
raw submissions (a floor, not comparable to the curated corpus;
results in C:/temp/AAW_20260825/ParseOutcomes_AA.csv).

**AWS (new 2026-08-26)**: account 196253397540, Identity Center
profile `steve` (root retired to break-glass), S3 bucket
shafer-corpora-196253397540 (private, corpus backup candidate), $10
monthly budget alarm.

> **ACTION NEEDED, first thing (found 2026-08-26 ~22:00 PT).** The
> Identity Center access token expires **8 hours** after login - the
> default session duration, NOT the ~90 days this note previously
> claimed. Measured: login 15:35, expiry 23:35 UTC. Consequences: the
> 02:00 medRxiv harvest **failed overnight**, and the hardened API
> image cannot be rebuilt or deployed until you log in.
> **One-time fix:** Identity Center console -> Settings ->
> Authentication -> raise the session duration (up to 90 days), then
> `aws sso login --profile steve`. Unattended jobs work from then on.
> (Alternative, if that proves insufficient: a long-lived IAM access
> key scoped to S3 read - trades a static credential for reliability.)

**PubTables-1M (issue 20)**: 8.0 GB of annotations/word boxes
downloaded and verified; test split (93,834 tables) extracted; mining
worktree C:/Temp/ia-pubtables + snapshot library ia-pubtables-lib
(engine commit recorded per row). 500-table pilot: 19.6%
baseline-shaped (→ ~18k with ground truth in the split), shaped parse
62.2% vs generic 22.9% (correct stratification), 0.05 s/table (full
split ≈ 80 min). The full-split run is chunked/resumable in
C:/temp/pubtables1m/mining. v1 agreement metrics are crude proxies —
see the issue before citing them.

**Overnight, unattended**: 2 AM — S3 harvest (100 packages / 2 GB per
night, corpus/harvestMedrxivS3.R); 3 AM — corpora backup to OneDrive
(now nightly). The medRxiv corpus holds 7 RCT PDFs after the first
S3 batch (2% RCT base rate × nightly cadence compounds).

**Queued next**: PubTables full-split report + v2 scoring (issue 20);
the issue-23 layout repairs; fold parsing of freshly harvested PDFs
into the nightly job with a snapshot library (Steve approved
2026-08-25 — still pending); adjudicate the 121 Carlisle-2017
outliers (issue 3); a usable real scan to pin the cyan OCR path
end-to-end (issue 22). Steve's call: nine stale stanpumpr_PR_* preview
apps on shinyapps (other project) await a sweep.

**Working alongside other sessions**: see AGENTS.md. The ParsePDF
glyph session's PR #53 remains open (worktree C:/Temp/ia-glyphs and
library C:/Temp/ia-lib are theirs).

---

## 24. Silent misparse: the parser sometimes returns the WRONG TABLE

**The measurement Steve asked for** (2026-08-26, from the "unknown
unknowns" review): we measure the parse RATE, and the Monte Carlo is
validated - but nobody had measured how often a parse SUCCEEDS WITH
WRONG VALUES. A failed parse is safe: the editor sees red cells. A
plausible misparse is the dangerous case, because an editor acts on it.

`corpus/measureMisparse.R` scores every corpus PDF that maps to one of
Carlisle's hand-entered trials. Each (MEAN, SD) pair we extract either
matches one of his pairs for that trial within printed rounding
("corroborated") or does not. Values, not labels: his row naming is his
own, and a label join would manufacture disagreement.

**RESULT - full run, 1,110 files mapped, 1,016 parsed (2026-08-26):**

| | files | share |
|---|---|---|
| fully corroborated (every pair matches) | 496 | 48.8% |
| partial (some match, some not) | 422 | 41.5% |
| **ZERO corroboration** | **98** | **9.6%** |

Also: 47.1% of parsed files have >= 80% of their pairs corroborated;
67.8% have >= 50%; the median file has 75% of its pairs corroborated;
and on the 767 files with >= 3 matches we recover 75.0% of Carlisle's
pairs.

**DO NOT quote the raw 43.7% uncorroborated as a misparse rate.**
Carlisle recorded only the variables he chose to analyze; the parser
extracts everything it finds, so most uncorroborated pairs are simply
variables he never entered. The honest headline is the two ends:
**about half of parsed files agree with the ground truth completely,
and about one in ten agrees with it not at all.**

**What the zero bucket actually is - the finding that matters.**
Inspected by hand, those files are not misread digits. **The parser
selected the wrong table.** Examples:

- `PMID_11927472.pdf`: rows labelled "Staph epidermidis",
  "Spore-bearing bacilli" - a microbiology RESULTS table. Carlisle's
  baseline values (633.3 +/- 25.8, ...) appear nowhere in our output.
- `PMID_11823394.pdf`: every row labelled "Group C", values 0/15/9/25 -
  an adverse-event or outcomes table, not baseline characteristics.

A wrong-table parse yields a confident p-value computed on data that
are not baseline characteristics, with nothing flagged. That is
precisely the failure this measurement existed to find.

**Why it is tractable**: this is a SELECTION failure, not a reading
failure, and selection can be gated on evidence. In order of expected
value:

1. **Refuse a winning candidate whose ROW LABELS do not look like
   baseline characteristics.** A demographic table says age / sex /
   weight / height / ASA / BMI; a microbiology table says Staph
   epidermidis. A vocabulary test over the winner's row labels - not
   the caption, which these files often lack - would refuse both
   examples above.
2. **Require positive baseline evidence to return anything at all.**
   Today an unlabelled table can win on parse score alone. Returning
   NOTHING is strictly better than returning the wrong table: the app
   handles "no table found" gracefully, and the API's round-trip
   payload covers it.
3. **Flag low-confidence selections** (no caption, no baseline
   vocabulary) so a human sees a warning rather than a silent verdict.
   Cheap, and useful even after 1 and 2.

**REMAINING**: classify the 98 zero-corroboration files properly
(wrong table vs. trial-mapping error vs. genuine digit misreads - the
three inspected were all wrong-table, but three is not a sample), then
implement the gate. Data: `.NewCarlisle/misparse/` (misparse_rows.csv,
misparse_files.csv sorted worst-first, run.log).

**Expect the headline parse rate to FALL when this is fixed** - from
84.9% toward something lower and truer, because some of today's
"successes" are wrong-table parses. For a fraud screen that is the
right trade, and it should be stated plainly when the number moves.

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

---

## 22. Scanned tables (both tiers IMPLEMENTED 2026-08-26; one pin open)

Born from the medRxiv harvest's first night: 10.1101/19007195 is a
text manuscript whose Table 1 page alone is a scanned picture — the
kind of document curated submission corpora can never surface (A&A's
submission rules precluded scanned tables; a curated corpus measures
the gate, not the wild).

As shipped (PRs #73, #75; design details in git history and the PR
bodies): **tier 1** — pages with no text layer travel to the AI assist
as rendered 150-dpi page images (the only route that can reach a
scanned table; consent language covers content, text or image).
**tier 2** — with no key, the deterministic engine retries image-only
pages on tesseract word boxes; an OCR-read table shades whole-table
pale cyan with a verify-every-cell warning, and a quality gate rejects
arm-less OCR noise. Validation verdict (the AI validating tesseract,
Steve's design): on a clean render OCR reproduces the text-layer parse
EXACTLY; on the real degraded scan the AI read correctly and OCR was
rightly gated. Standing conclusion: OCR is the no-key fallback for
clean scans; the AI image route is the quality path for real ones.

**REMAINING**: a harvested scan clean enough for OCR, to pin the
end-to-end cyan path in the app against a real file (the registry and
renderer logic are unit-pinned; the full-pipeline assertion awaits a
usable specimen from the nightly harvest).

---

## 21. A medRxiv preprint stress-test corpus (no ground truth, by design)

Steve's idea (2026-08-25): harvest randomized-controlled-trial
preprints as a stress corpus. No ground truth for values — what it
buys is the opposite of validation: a firehose of AUTHOR-typeset PDFs
(Word exports, LaTeX, every table habit in the wild, no copyeditor),
which is exactly where parser crashes, hangs, and blind spots hide.
It earned its keep on night one (issues 22 and 23 both came from the
first five files).

**The route is S3 (2026-08-26, PR #80)**: the first night's HTTPS
fetches hit 403 on 67 of 72 (medRxiv bot protection, which we do not
evade); the replacement is the channel medRxiv built FOR bulk mining —
the requester-pays bucket s3://medrxiv-src-monthly, billed to Steve's
AWS account (verified: 100 packages, 842 MB, ~7 cents).
`corpus/harvestMedrxivS3.R` runs nightly (100 packages / 2 GB): lists
current+previous month, unpacks each .meca, reads DOI/title/abstract
from the JATS XML, applies the SHARED RCT filter
(corpus/rctFilterPatterns.R — the PR #74 rules, on real abstracts),
keeps RCT PDFs by DOI with license recorded in s3Manifest.csv, deletes
the rest. medRxiv's conditions honored by construction: TDM use, link
back, no re-hosting — corpus under C:/temp, never committed.
`downloadPreprintRCTs.R` remains for API metadata scans.

**OPEN**: fold parsing of freshly harvested PDFs into the nightly job
(snapshot-installed library, never load_all of the live tree — the
2026-08-25 contamination lesson), so each night's catch is
stress-tested by morning. Known residual filter leak: a paper whose
TITLE cites RCTs referentially (10.1101/19007195) passes; harmless.

---

## 20. Docling cross-check harness and PubTables-1M fixture mining

Filed 2026-08-25 (Steve's request, after surveying the document-parsing
landscape). Two additions to the parser optimization loop (AGENTS.md),
both LOCAL CORPUS TOOLING ONLY — nothing here ships in the deployed
app, which stays deterministic, offline, and R-only.

**Why the survey did not change the architecture.** The 2026 academic
benchmark of nine table extractors (arxiv 2511.16134, ~44k scientific
tables) puts the field's best — IBM Docling's detection + TableFormer
models — at ~0.99 table detection but only ~0.86 end-to-end
cell-structure accuracy on clean biomedical tables, with VLM-mode
hallucination reports; our engine's failure mode (refuse and say why)
is the right one for a fraud screen, and its structural accuracy on
what it accepts is the thing to measure and improve — hence the mining.

**PubTables-1M status (2026-08-26)**: annotation/word archives
downloaded (8.0 GB; the ~100 GB of page images deliberately skipped —
the engine consumes word boxes, which the dataset ships separately);
test split extracted (93,834 tables with structure XML + word-box
JSON). Mining runs in worktree C:/Temp/ia-pubtables against snapshot
library C:/Temp/ia-pubtables-lib via `corpus/minePubTables.R`
(chunked/resumable; engine commit recorded per row; word boxes feed
.ppParseBlock through the same seam as the docx adapter — no PDF, no
rendering, 0.05 s/table).

**Pilot (500 tables)**: 19.6% baseline-shaped (caption/±/n(%) signals)
→ ~18,400 ground-truthed baseline-style tables in the test split;
parse rate 62.2% within the shaped stratum vs 22.9% generic (the
semantic layer rightly refuses generic tables — never cite an
unstratified "parse rate" from this corpus); 37 shaped-but-unparsed
tables per 500 are the improvement queue (~7k extrapolated); shaped
tables carry more spanning cells (2.8 vs 1.9) — multi-level headers
are the likely wall.

**OPEN**: (a) full test-split run + report (in flight); (b) v2 scoring
— the v1 row/column agreement numbers are metric artifacts (template
variables ≠ printed rows; deliberately-dropped statistic columns count
against us) and need proper alignment before they mean anything;
(c) mine the shaped-but-unparsed bucket into ranked failure classes
and fixtures; (d) the Docling cross-check harness itself (run Docling
over the same word-box tables; disagreement = review queue).

---

## 12. Median/IQR rows (IMPLEMENTED 2026-08-17; validation approach open)

As shipped: Q1/Q3 columns; MEAN read as the median when both present;
metalog (3-term) null reconstructing the pooled population, exact
m/Q1/Q3 match including skew, |a3/a2| > 1.667 refused rather than
mis-simulated; simulated medians rounded as printed. Full design in
git history and R/ comments; parse-side extraction (engine + docx +
wide) landed 2026-08-21 with the text-evidence gate (IQR must be
STATED; ranges and unlabeled intervals are refused).

**REMAINING — the validation approach**: no Carlisle-style ground
truth exists for median rows. In place: a calibration property test
(honest lognormal trials → p roughly uniform) and direction tests.
Worth doing: a larger calibration study across N, skew, and rounding
regimes, and sensitivity of the metalog null against other plausible
shapes.

---

## 11. Live UI feedback while the Monte Carlo runs

Steve's request (2026-08-16). The p-value calculation can take a very
long time, and Shiny's single-threaded server locks the UI while
`P_Calc()` computes — no reactive flush, no log refresh, no button
response. What exists: `shiny::Progress` ticks once per TRIAL (its
`$set()` bypasses the flush) and `bslib::input_task_button` shows a
busy state — but within one long trial nothing moves and nothing can
be cancelled.

The real fix is to take the computation off the main thread:
`shiny::ExtendedTask` (+ promises/future) with the existing
input_task_button as its intended companion — UI stays live, per-trial
results stream into the log, Cancel becomes possible; a callr/future
worker polled via invalidateLater is the portable fallback; P_Calc's
row loop can then report per-ROW progress via callback.

**Do together with issue 5**: trial-level parallelism and off-thread
computation are the same plumbing. Test cancellation and
two-users-at-once on shinyapps.io, where workers are billed compute.

---

## 8. AI parsing in deployment — BYOK (app side IMPLEMENTED; service side open)

The app side shipped 2026-08-25/26 (PRs #67, #70, #73, #77, #79 — the
masked key field with live validation, deterministic-first merge, green
provenance rows, per-session cap, page-image route for scans,
automatic re-read of failed uploads on key entry). Third-party
deployments enable it permanently with INTEGRITY_AI_ALWAYS=true and
their own ANTHROPIC_API_KEY — the gate is a policy, not a fork. The
guide carries consent language, the no-training/confidentiality
guarantees (Anthropic's Commercial Terms; ~30-day deletion), and the
measured rescue rates (91%/81%).

**REMAINING**: the API-service side — per-request BYOK when issue 1 is
built — and landing-page copy at integrityanalysis.io describing the
assist. The governing rationale (kept): the point is publication, not
concealment — the prompts and JSON schema ARE the algorithm, written
to be read; the gate is on the spending, never the method.

---

## 7. Survey other open-source research-integrity screens

Look for additional published, open screens that could be applied to
the same submissions and reported alongside the baseline analysis.

**Already tried and rejected — do not repeat without a reason:**
Benford's law and repeating-digit tests, both worthless here: a
baseline table supplies far too few numbers for digit-distribution
methods to have power. Judge any candidate first on whether it works
on tens of numbers.

Worth considering instead — screens that use *structure*: internal
consistency of means against totals, SDs impossible for the stated N
and range, granularity tests (GRIM/GRIMMER), terminal-digit balance
across arms.

**Candidates raised by Steve, 2026-08-17:**

- **SPRITE** (Heathers et al., https://shiny.ieis.tue.nl/sprite/):
  reconstructs possible samples behind a reported mean/SD of a bounded
  integer scale. Works on a single pair, so it passes the
  too-few-numbers test. Complementary: it catches impossible mean/SD
  pairs within one row where Carlisle–Shafer catches improbable
  agreement across arms. Natural fit as a per-row plausibility flag
  (with GRIM/GRIMMER) in validation — cheap, deterministic.
- **Barnett's Bayesian baseline method**
  (https://f1000research.com/articles/11-783): a Bayesian
  re-formulation of the Carlisle approach — same evidence, different
  inferential wrapper, so a cross-check rather than an independent
  signal.

Evaluation plan when picked up: run Carlisle–Shafer, Barnett, and
SPRITE/GRIM flags over corpus/TEST; compare per-trial calls; adopt
what adds discrimination, report what merely agrees as corroboration.

---

## 5. Optimise the Monte Carlo

The adaptive staged scheme (1,000 → 10,000 → 100,000 replicates,
escalating only while a row alarms) shipped 2026-08-17 and is the big
practical win; chunked simulation bounds memory; dqrng supplies fast
draws. **Remaining**: profiling, vectorisation of what is left, and
trial-level parallelism — which is the same plumbing as issue 11 and
should be designed with it. Profile before changing anything, and keep
issue 3's validation green throughout. Trials are independent, so
trial-level parallelism is the easiest large win for whole-corpus runs.

---

## 3. Validate against Carlisle 2017 (COMPLETE; outlier adjudication open)

**The shipped engine reproduces Carlisle 2017** (full run 2026-08-21,
57.8 min, all 5,080 trials joined, zero refused): r = 0.9930, median
|diff| 0.0127, 90.3% within 0.05, alarm concordance 99.0%; 39 his-p=1
z=+∞ artifact trials reported separately. The validation is a
committed, reproducible artifact: `corpus/validateCarlisle2017.R`
(pilot and full modes, resumable via
.NewCarlisle/validation2017/results.csv). Method notes that still
matter: Carlisle's stored p.values are folded (< 0.5) and effectively
mid-p — the app's convention since PR #8; the One Sheet's A&A
numbering drifts by one above trial ~1234 (apply the offset before
using it as ground truth again).

**REMAINING**: adjudicate the 121 outliers (|diff| > 0.10; 50 disagree
on the p < 0.05 alarm) — per-trial values in results.csv; the worst
five are recorded there (e.g. NEJM 670: ours 0.129 vs his 0.634).

---

## 1. Build the API (BUILT and DEPLOYED 2026-08-26; hardening follow-ups open)

**Shipped**: `POST /parse` and `POST /analyze` behind bearer-token auth,
running on AWS App Runner from a container CodeBuild builds out of this
repository. The contract below is honored, including the round-trip
failure payload and confirmed deletion, and the per-request BYOK header.
Live-verified end to end, including an AI rescue of a scanned table
through the deployed service. Issuance is `tools/issueApiToken.R` (a
256-bit token shown once; only its SHA-256 is recorded, in a private
registry repository). Decisions and their reasoning:
`docs/api-spec.md`.

**OPEN follow-ups, in priority order** (from the 2026-08-26 security
review and its independent re-review):

1. **A real body cap in front of the service.** The in-app `sizelimit`
   filter cannot prevent the memory spike it targets: httpuv buffers
   the whole request and plumber parses it before any filter runs. The
   filter still refuses the parse/compute (and now refuses a POST with
   no Content-Length, which previously bypassed it entirely), but the
   actual cap needs a proxy/WAF ahead of App Runner. Until that exists,
   H1 is mitigated, not closed.
2. **Per-token quotas.** Request size and compute are bounded per
   request; nothing yet bounds how MANY requests one token may make.
   Worth having before the token list grows beyond people Steve knows
   by name.
3. **Self-service issuance** (Cognito + WAF) if demand justifies it -
   deliberately deferred; the design is in `docs/api-spec.md`.
4. **Version in `/health`**: the deployed image predates the 0.2.0
   bump, so `/health` still reports 0.1.0 until the next image build.

## 1a. The API contract (as built)

Expose the analysis so other programs can call it — the target is
editorial systems such as Editorial Manager linking to it automatically
and silently for fraud screening during peer review.

**Contract**

| | |
|---|---|
| Input | a single PDF **or** a spreadsheet (xls/xlsx/csv) |
| On pass | run the Monte Carlo; return a CSV of the analysis, plus confirmation the PDF was deleted |
| On fail | return **the partial table**, carrying as much extracted data as possible, plus what is wrong with it |
| Retention | none — the PDF is deleted and the caller is told so |

**Decisions already made**

- **A failure is not a bare error.** It returns the failed table so an
  editor or reviewer can fill the gaps and call the API again, this
  time with a spreadsheet instead of the PDF. A failed scan is a round
  trip, not a dead end — which means *the failure payload must itself
  be valid input to the next call*. `writeIntegrityTemplate()` already
  emits exactly that layout.
- **No arm N, no analysis.** Without a hard-coded N the service
  returns a fail rather than running the Monte Carlo. About 58% of
  rows extracted from real articles carry no arm N.
- **No AI in the deployed path by default** — but see issue 8: the
  service side of BYOK (per-request key = per-request consent and
  billing) is the sanctioned way in.

**Watch for**

- Annotation must stay out of the data columns (a numeric flag would
  be swallowed as a category); use a text column or a separate sheet.
- Return `$skipped` (each unusable row and why), not a count.
- A folder of PDFs must go through `parseBaselineTableFiles()`, never
  a loop — ~2% of real PDFs hang poppler and R cannot interrupt it.
- Realistic expectation: fed a single PDF, the deterministic path
  yields a fully analysable trial 84.9% of the time on curated journal
  PDFs (recertified 2026-08-25), far less on raw submissions; the
  spreadsheet path is the reliable one.
