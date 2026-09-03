# IntegrityAnalysis — open issues

Open work only, newest first. Each entry says what the work is, why it
matters, and what "done" looks like. **Closed and fully-implemented
issues are removed rather than kept below** (restructure approved by
Steve 2026-08-25): every prior version of this file, including the full
text of every closed issue and the reasoning that closed it, survives
in git history — `git log --follow ISSUES.md`. Issue numbers are stable
and therefore gappy.

---

## Where things stand — 2026-09-02 (evening, session handoff)

**Merged and in production today** (#140–#144, all from Steve's live
testing of a real journal table, `Ticgrelor.xlsx`): per-arm median
handling, with Q1/Q3 columns that are always there to type into (#140
and #142); the log autoscroll no longer throws (#141); the identity-index
fetcher refuses a partial index and names the converter failure that
actually happened (#143); `(number, %)` recognised as the count tag,
and a name-collision refusal that names the offending column (#144).
Production was verified end to end with the sheet after the merges.

**Open, green, screened — awaiting Steve's merge:**

- **#145 — a picture of a table (jpg/png/tif) as input.** Read by
  tesseract's own reader (no ImageMagick), header-checked by our own
  parser before any decoder runs, decoded only in the parse
  subprocess, shaded cyan. `securityScreen.ps1` ran on the branch: one
  High (GIF) fixed by dropping GIF, three Lows fixed, the child memory
  ceiling filed as issue 32; CodeRabbit's five threads fixed; tripwire
  group 6 rebuilt on the parser's token table and verified to trip on
  seven deliberate breaks.
- **#146 — Springer side captions.** Typographic spaces glued the
  caption numeral to its text, and the caption shares its line with the
  table's header row. The ticagrelor PDF now parses to the same 84
  numbers as the spreadsheet. Before/after on the 209 corpus files
  whose caption lines show the gap: 200 identical, 1 gained, 1
  improved, 0 regressions — after a tightening the measurement itself
  forced (the gap-only version regressed 13).

**OCR measurement (issue 22 follow-on, `C:/dev/Corpus/ocr`)**: arm 2
(99 real scans) complete; arm 1 (born-digital renders scored against
JATS truth) still running, past 200 works. Interim finding: the
dominant OCR failure is wrong-table selection, not digit misreads
(~92% digit precision) — the case for pairing TATR geometry with
tesseract, proposed to Steve but not yet filed as an issue.

**Citable numbers are unchanged** from 2026-08-26: parse rate 84.9%
over the 1,865-trial Carlisle corpus; r = 0.9930 against Carlisle 2017
across 5,080 trials, 99.0% alarm concordance; AI-assist rescue 91%/81%.

**Two traps recorded today** (details in the off-repo handoff and the
memory notes): a corpus before/after silently measured the stale 0.1.0
package in the user library after a failed reinstall — assert
`find.package()` lies inside the snapshot library before measuring;
and `system2(timeout=)` on Windows kills the 32-bit Rscript launcher,
not its 64-bit child — drive per-file subprocesses with
`bin/x64/Rscript` and `processx::run(cleanup_tree = TRUE)`.

**Still standing from 2026-08-26**: the AWS Identity Center session
duration (8 h by default — raise it, then `aws sso login --profile
steve`, or unattended harvests fail; confirm this was done);
PubTables-1M full-split report and v2 scoring (issue 20); the issue-23
layout repairs; nightly parsing of freshly harvested PDFs with a
snapshot library (approved 2026-08-25, pending); the 121 Carlisle-2017
outliers (issue 3); the TATR ctgov-docs scoping decision
(`tatr/HANDOFF-TATR.md`). Overnight jobs unchanged: 2 AM S3 harvest,
3 AM OneDrive backup.

**Working alongside other sessions**: see AGENTS.md. Worktrees in use
today: `C:/Temp/ia-main` (main snapshot) and `C:/Temp/ia-springer`
(#146); snapshot libraries `C:/Temp/ia-lib-main` and
`C:/Temp/ia-lib-springer`.

---

## 32. A memory ceiling for the parse child, and a render cap for scanned pages

**Status: open, filed 2026-09-02** from the security screen of the image
upload feature (`docs/security-screens/log.md`, F1 and its note).

Every hostile document is decoded in a child process under a wall-clock
timeout (`parseBaselineTableFiles()`), and the image route now refuses
oversized headers before any decoder runs. What the child does NOT have
is a memory ceiling: a decoder that allocates faster than the timeout
fires is the container's out-of-memory, and on a single-threaded host
that is the worker. The image preflight narrows the window (20 MP cap,
10 TIFF pages, no GIF); it does not close it, and it does nothing for the
older routes.

Two things, both belonging to the container rather than to R code, and
neither verifiable from the Windows development machine:

- **A memory limit on the parse child.** On Linux, `ulimit -v` around the
  `Rscript --vanilla` launch in `parseBaselineTableFiles()`, or a
  container-level limit in the App Runner service and the Docker image.
  Whichever is chosen, verify on a Linux node that a deliberately huge
  allocation in the child is killed and reported as a failed parse, not
  as a dead worker.
- **A page-size cap on the scanned-PDF OCR render.** `.ppOcrPages()`
  renders image-only pages at 300 dpi with no bound on the page's
  MediaBox; a PDF declaring 200 x 200 inches would render at
  60000 x 60000. Read the page size from `pdftools::pdf_pagesize()`
  first and refuse, or render at a dpi that keeps the raster under the
  same 20 MP the image route allows.

Done looks like: both limits in place, each with the deliberate-break
test that shows it working, and the screen's F1 note closed.

---

## 33. The Table Transformer + tesseract seam: built; where it runs is the open question

**Status: built 2026-09-02 (PR #147, `R/parseTatr.R`)** at Steve's
direction, "Add tatr-tesseract to pdf parser workflow", after the
run-along (issue 20's neighbour, PR #137) showed the model locating a
griddable table in 84% of the text-layer articles the engine cannot grid
and on 97% of scanned pages with no text layer at all.

What is built: the model's XML (with `--write-empty`, so a scanned page
keeps its geometry) goes through the Word path's adapter into the same
block parser; on a page with no text layer, tesseract supplies the
characters and each word is assigned to the cell holding at least half
of its box. A rescue tier behind the text engine, ahead of the AI route
and of plain OCR; the model never chooses the table.

**Measured 2026-09-02** on an installed snapshot, through the subprocess
batcher. Run B (574 Carlisle articles with model geometry, text layer):
the engine alone parses 523; of the **51 it cannot, the seam recovers
25** (49%) - 8 of them with an N on every arm, 17 with continuous rows,
and a tail of thin one-to-two-variable readings that the value scoring
below would sort. The 26 still failing split between poppler timeouts
(the same files time out with or without the seam) and tables the model
found but the engine could not read as baseline data. Run C (the 300
accessions of the scanned-set run, 192 with model geometry, 84 of them
text-less tables kept by `--write-empty`): the engine alone parses
106; of the 86 it cannot, the seam recovers **19 through the text
layer** - the same mechanism as run B - but the **OCR pairing on real
scans yielded only fragments**: 18 results, none with an N on two arms,
one with a continuous row, mostly a single variable, and no better than
plain OCR on the five files both read. The seam now gates a pairing
result on arm identity exactly as the OCR rescue does, so those
fragments do not surface. **Standing conclusion, unchanged from issue
22: on a real scan the AI image route is the quality path; geometry
from the model helps the text-layer failures, not (yet) the scans.**

What is NOT decided, and is Steve's call:

- **Where the model runs in deployment.** It needs the pegged Python
  (`tools/tatrProvision.sh`), ~17 s per article on CPU, ~1 GB resident,
  and ~500 MB of weights on disk. Two hosts could carry it. The API's
  Docker image is the simpler one: we build it, so the Python, the
  weights and `INTEGRITY_TATR_PYTHON` go in directly. The shinyapps.io
  app (Steve's Professional plan, instances up to 8 GB) is the second:
  it runs Python through `reticulate` from a shipped `requirements.txt`,
  but the torch wheels and the pegged weights would have to travel in
  the app bundle or be fetched at every instance start, and each cold
  start would pay the model load. A third route joins the two (Steve,
  2026-09-02): the shinyapps.io app could call OUR OWN API for the
  geometry - a `POST /v1/geometry` endpoint on the Docker image, invoked
  only when the app's text engine fails, returning the model's XML for
  the app's own `parseBaselineTableTatr()`. One place runs the model,
  the app stays R-only; it costs a service token held as a shinyapps
  secret and one round trip per failure, and it changes the guide's
  "nothing leaves this server" sentence, which would then read "to a
  container we run, with the API's zero-retention guarantee". Neither
  deployment is a code change; the endpoint is a small one. All Steve's
  call, weighed against the memory ceiling of issue 32 and the measured
  payoff (text-layer failures, not scans).
- **Per-cell OCR, and a higher render for scans.** The pairing OCRs the
  whole page at 300 dpi and assigns words; on real scans that produced
  fragments (above). OCRing each cell's crop separately, with a
  digits-friendly configuration, and rendering scanned pages for the
  model at more than 150 dpi are the next steps - and need an image
  cropper that is not ImageMagick (screen F1, 2026-09-02; tesseract's own
  reader can take a rectangle, which is the route to try). Arm 2's 99
  real scans are the test set.
- **Value scoring - now run on the 25** (2026-09-02, late). Eleven of
  the 25 recovered articles map to a Carlisle trial with hand-entered
  values. Of the seam's 185 (mean, SD) pairs, **105 corroborate his
  (57%)** by the corroboration script's own rounding rule, and **91% of
  his pairs are recovered** (10 of 113 missed). Six articles are fully
  corroborated; five carry uncorroborated pairs, two of them badly
  (IA012208: 44 of 54; IA013851: 22 of 32 - extra rows he did not
  record, or a table read wrong). That is the same order as the engine's
  corpus-wide 44.8% fully-corroborated figure, so the recovered readings
  are ordinary parser output, not a new class of error - and the two bad
  ones are what the grid's flags exist for. The remaining 14 have no
  Carlisle mapping; the 147-article scoring on the node queue is the
  fuller answer.

**Measured 2026-09-03 on the WHOLE Carlisle corpus** (1,865 articles;
the model's geometry for all of them from a 3.7 h run on `i5`, the
comparison on `oldryzen` from the installed branch snapshot through the
batcher: `tatr = "never"` against `tatr = "always"`; files under
`C:/dev/Corpus/tatr/xml/runFull/always/`, scripts
`C:/dev/Corpus/tools/tatrAlwaysReport.R` and `valueCheckAlways.R`):

- The text engine parses 1,654 (88.7%); with the seam 1,768 (94.8%):
  **114 recovered, none lost** (78 through the text layer, 36 by the
  OCR pairing). The 51 articles the model found no table in parse the
  same either way.
- When both succeed (1,654), the model's reading wins by parse score in
  441 (26.7%): 63 with identical numbers, 378 with different ones - the
  model reads more (median 28 values against 19).
- **Judged by Carlisle's hand-entered numbers** (1,485 of the 1,865
  join to his One Sheet by PMID; each reading's values scored for
  recall of his numbers and precision against them): on the 321 joined
  articles where the model won with different numbers, recall rises
  from 0.41 to 0.59 and precision from 0.38 to 0.44; paired, the model
  reads more of his numbers in 150 articles and fewer in 59. Of the
  1,905 values the model added net, 58% are his - a better hit rate than
  the text engine's own 38% on those articles, so the additions are
  content, not noise, on balance. The 84 recovered articles with a
  Carlisle trial score recall 0.51 / precision 0.46, the same order as
  the text engine's 0.61 / 0.48 on articles it parses: ordinary parser
  output. Corpus-wide, recall 0.61 -> 0.65 and precision 0.48 -> 0.50.
  So `tatr = "always"` is a net gain by his numbers, not just by score.
- **The failure the score cannot see, 38 articles**: the model's reading
  won by parse score while its precision against Carlisle fell by more
  than 0.2 - in the worst (PMID 14725516) the text engine's 16 values
  were all his and the model's 16 were a different table with one.
  Parse score rewards content; it does not know which table is the
  baseline table, and a larger non-baseline table can outscore a
  correct smaller one. This does not touch the default `tatr = "auto"`
  (the seam runs only when the text engine fails: 114 recovered, none
  lost); it is a rule to add before `"always"` is used in earnest - the
  model's candidate should have to match the text engine's caption, or
  the caption score should weigh in the comparison. Listed in
  `always_valuecheck.csv`.

Done looks like: a deployment decision recorded here, and the "always"
comparison given a caption rule so the 38 cannot happen.

---

## 31. One corpus library, with an index that decides what may be shared

**Status: built 2026-08-31** (`corpus/buildCorpusLibrary.R`,
`corpus/fetchCorpusIdentity.R`, `corpus/extractShareable.R`,
`tools/ingestNodes.ps1`, `tools/backupCorpusZip.ps1`; the library itself
is `C:/dev/Corpus`, outside the repository). Recorded here because the
*rules* are the deliverable, and because issue 30 depends on it.

Steve, prompted by the prospect of collaborating with Adrian Barnett:
"The test and development corpora are currently scattered all over this
computer... we can't have this scattered set of files. Please coalesce
into a single corpora with a master index and a logical tree. Papers
should be assigned our own access numbers to preserve confidentiality."

**What was scattered.** Eleven collections across `C:/temp`, the repo's
hidden `.NewCarlisle`/`.Boldt`/`.Fujii`, and two Linux nodes — 36,842
files, 24.2 GB, in four incompatible naming schemes. The same paper
could be `Journals/Anaesthesia/2003/1.2.pdf`, `Journals/PMID_12492668.pdf`
and a PMC XML named by PMCID, with nothing linking them. **17,032 works**
after dedup on PMID > PMCID > DOI > SHA-256; **6,565 hold both a PDF and
an XML**, which is the set that makes XML usable as parser ground truth.

**The architecture is one sentence of Steve's**, given after the A&A
peer-review holdings were flagged: *"Put them in the master index, but
marked 'not sharable.' The master corpus itself is never shared. We
extract and share only what the master index permits."* So the library is
not a shareable artefact with sensitive parts carved out — it is a
complete private archive plus an index that **decides**. A file is
extracted if and only if `master.csv` says `FILE_SHAREABLE`. If a licence
is wrong, fix the index; never special-case the extraction, because the
index is what can be audited afterwards.

**Two booleans, because two different questions get asked.**
`FILE_SHAREABLE` (may the article go?) is true for 20,049 of 36,842
files. `DERIVED_SHAREABLE` (may a parsed table go?) is true for 30,514.
The gap is the point: a subscription PDF cannot be redistributed, but the
mean and SD printed in its Table 1 are *facts*, and facts are not
copyrightable — so restricted material can still carry a published
analysis. Confidential peer review is the one class where both are false,
because there the content *is* the confidence.

**The confidential tier.** `C:/temp/AA` held 6,328 PDFs of Anesthesia &
Analgesia submissions from Steve's editorship. Pseudonymising the index
does not make them shareable — the accession hides identity in a *table*
and does nothing about the authors and title printed inside the PDF. They
are in the archive (they are the only corpus showing what actually
arrives at a journal) and marked `confidential`: 6,328 files collapsing
to 3,149 works, since the same manuscript was held in several folders.

**Accessions are randomised, not sequential-by-scan.** `IA######`
assigned in shuffled order under a recorded seed. Scan order would leak
exactly what the pseudonym hides — `IA000001`–`IA001865` would obviously
be the Carlisle set. Same reasoning as `corpus/pseudonymize.R`.
`identity.csv` (accession → PMID, journal, volume, issue, pages, title,
authors) is excluded from every extraction tier unconditionally, with no
flag to override: turning an accession back into a named paper is a
decision Steve makes one paper at a time, so the author can be heard
first.

**`FIRST_SEEN` enables a temporal holdout.** Train on
`FIRST_SEEN <= X`, evaluate on what arrived after. That is clean in a way
`corpus/Holdout.csv` cannot claim — those articles had already been read
and their failures studied when it was drawn. Deliberately *not* inferred
from file mtimes: a 2025 download copied in 2026 has a timestamp that
says nothing about when the corpus gained it.

**Watch for**

- **`match()` on a missing key is a silent identity swap, and a positive
  control will not catch it.** `pmidToPmcid.csv` holds 11,428 rows with an
  empty PMCID; `match(NA, table)` in R returns the position of the first
  `NA` rather than missing, so on the first run *every* work without a
  PMCID — all 3,149 confidential A&A manuscripts among them — inherited
  one unrelated paper's PMID, and then that paper's title and authors.
  Coverage read `17,035 / 17,035`. The script already had positive
  controls on both NCBI endpoints and **they passed**: a healthy API
  answers a wrong question as cheerfully as a right one, so they proved
  the service worked and could not prove the keys were right. Fixed with
  `safeMatch()` (both scripts, ten joins) plus a **negative control that
  aborts before writing** — a work with no identifier at build time may
  not acquire one. Treat a coverage figure that jumps to 100% as a
  defect report, not a result.

  **Audited 2026-09-01: every join in `corpus/`** — 39 raw `match()`
  call sites (37 lookups plus the two hand-copied definitions of
  `safeMatch()` itself), the 12 joins already converted on 2026-08-31,
  and the 13 `merge()` calls, which have the same defect and were not
  covered by the original fix. Nothing
  was corrupt: every right-hand table in use today happens to be free of
  blank keys, so the seven unguarded joins found were latent, not live
  (checked, not assumed — `.NewCarlisle/manifest.csv`,
  `unpaywall.csv`, `licensed_manifest.csv` and `corpus/pmid_map.csv`
  all hold zero blank PMIDs, and the 20,025 accessions hold no
  degenerate work key). The audit's three findings worth keeping:
  **(1)** the failure needs a blank on the LEFT *and* a blank in the
  table, which is why filename- and literal-keyed joins are fine and
  did not need touching — 26 of the 37 lookups were cleared unchanged
  on that ground, and only 7 were genuinely exposed; **(2)** the worst
  site was
  `corpus/buildFraudDownloadList.R`, which *deliberately* stores an
  unresolved citation as `PMID = NA` and then joins on it, so a
  stranger's DOI, licence and download URL could have entered Steve's
  hand-worked queue; and **(3)** a second bug of the same family that
  `safeMatch()` does not address — the work key was built with
  `!is.na()`, so an empty-string identifier would have produced the
  key `"pmid:"` and an unhashable file the key `"sha:NA"`, collapsing
  every affected file into ONE work with ONE accession. That is the
  mirror image of the collision check already in the builder (one
  accession, two works) and invisible to it; both are now refused
  before anything is written. `safeMatch()` itself moved to
  `corpus/safeMatch.R` — one definition, sourced by seven scripts,
  because a third hand-transcription would have been the next defect.
  Pinned by `tests/testthat/test-safe-match.R`, which SKIPS under
  `R CMD check` (`corpus/` is `.Rbuildignore`d) and therefore runs
  only in a development tree.
- **The NCBI ID converter moved again.** `www.ncbi.nlm.nih.gov/pmc/utils/
  idconv/v1.0/` now 301s to `pmc.ncbi.nlm.nih.gov/tools/idconv/api/v1/
  articles/`, and `jsonlite::fromJSON` does not follow redirects — it
  parses the redirect HTML, finds no records, and reports success having
  resolved nothing. That is the **third** silent NCBI zero in this project
  (retired `oa.fcgi`, an unfollowed 301, a `pmcid:` prefix left in parsed
  values). Both fetchers now run a **positive control before the run** and
  `stop()` on failure. Add one to any new NCBI caller.
- Hard links, not copies: `master/` costs no extra disk, but robocopy and
  zip both expand them, so never back up `master/` *and* the source trees.
- The originals under `C:/temp` still exist and older `corpus/*.R` scripts
  still read them. They are hard links to the same bytes, so this is not
  duplication — but the paths must be repointed before anything is deleted.

---

## 30. A frozen regression corpus, and multi-source disagreement as a signal

Two requirements from Steve, 2026-08-30, which belong together because
the first produces the material the second freezes.

### 30a. More than one source per table is information, not a scorecard

"We are trying to learn how to parse input files to generate baseline
tables. When we have > 1 source, then that provides information from
which we can further refine input table parsing, regardless of the
source."

Today's PMC pass gives, for the same trial, up to three independent
renderings of one baseline table:

| source | reachable | what it is |
|---|---|---|
| PDF | ~7,000 | the typeset article |
| JATS XML | ~10,200 | the publisher's own table markup |
| the registry | 47,813 trials | values the sponsor typed into ClinicalTrials.gov |

(XML availability was measured, not assumed: 39 of 40 sampled OA
articles and 39 of 40 sampled author manuscripts carry an `xml_url`,
against 35 and 3 respectively for `pdf_url`. XML is not a fallback for
the awkward cases - it is the format that is actually there.)

**5,672 trials have all three.** A further 2,322 author manuscripts have
XML and the registry but no PDF.

The comparison isolates cleanly because BOTH input paths funnel into the
SAME `.ppParseBlock()`. The PDF path reconstructs a table from
coordinates; the XML path hands over real cells; after that the
interpretation code is byte-identical. So a PDF-vs-XML disagreement is
attributable to EXTRACTION alone, with interpretation held constant by
construction. That is a far sharper instrument than issue 24's
measurement, which could say "9.6% agree with the ground truth not at
all" but never why.

Three sources also break ties: a 2-versus-1 split usually names the odd
one out. And the PDF-and-XML-agree-but-registry-differs case is not a
parser finding at all - it is baseline reporting inconsistency between a
published paper and its registry entry, which is publishable on its own.

**The point is the feedback loop, not the score.** Each disagreement
localises a defect (a lost column, a misread decimal, the wrong table
chosen), that defect gets fixed, and the corpus re-run. What must NOT
happen is the loop of AGENTS.md's optimisation pass - fix against the
same files, re-measure on the same files - which is why 30b exists and
why `corpus/freezeHoldout.R` already splits development from holdout.

**Caveat to state before quoting any number**: XML is ground truth for
what the TABLE CONTAINS, not for what the PDF says. PMC XML is sometimes
re-keyed or converted from the publisher's deposit, and author-manuscript
XML is generated from the submitted Word file, so the two can legitimately
differ. A disagreement is a flag, not a verdict; the honest design
measures the rate and adjudicates a sample by eye.

### 30b. A frozen, multi-format regression corpus

"We should set aside a corpus of 'successfully parsed and validated'
files of all types (pdf, xlsx, docx, XML, etc) that we can use in the
future to be certain that new parsing programs don't significantly
degrade the parser."

**The gap this closes.** Every fixture in the suite today is
SYNTHESISED at test time - `helper-syntheticPdf.R`,
`helper-syntheticDocx.R`, `helper-syntheticJats.R` - and the only
committed real files are `Example.xlsx` and `Template.xlsx`. That was
forced: the Carlisle and A&A corpora are copyrighted PDFs, gitignored,
local-only. So the suite catches logic regressions but CANNOT catch a
regression on real-world layout variety, which is exactly where the
parser fails.

**What makes this newly possible.** Of the registry-linked PMC articles
measured 2026-08-30: 3,673 are CC BY and 47 are CC0. Those are
redistributable with attribution, so a `<table-wrap>` fragment plus its
expected output can be COMMITTED and run in GitHub Actions on every PR.
CC BY-NC (1,625) and CC BY-NC-ND (1,567) are usable locally but awkward
to redistribute in a repository others may use commercially; TDM (3,087)
permits mining, not redistribution. **Only CC BY and CC0 go in the
repo**, and each case records its licence and citation.

**Two tiers, mirroring the existing local/public split:**

- **Tier 1, committed, runs in CI.** CC BY / CC0 JATS table fragments,
  plus the synthesised PDF/.docx/.xlsx fixtures already in use. Public,
  legally clean, fast.
- **Tier 2, local only.** Real PDFs from the Carlisle, A&A and medRxiv
  corpora. Run on the compute nodes, never committed.

**What "successfully parsed and validated" must mean**, or the corpus
freezes our mistakes: the file parses, `validateData()` passes, AND the
values were checked against a second source (XML, the registry, or by
hand) rather than merely looking plausible. A case admitted on "it
parsed without error" would pin whatever the parser did that day,
including a wrong-table selection - the precise failure of issue 24.

**Done looks like:** a `corpus/regression/` manifest of cases (input,
expected validated frame, source, licence, citation, how it was
verified); a test that parses every tier-1 case and diffs against the
frozen frame; a corpus script that runs tier 2 locally and reports
drift; and a documented rule that a case is added only WITH its
verification evidence.

**Deliberately not automated:** admitting a case requires a human
judgement that the values are right. The manifest records who verified
it and how.

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

## 29. JATS/XML input — the format publishers already have

Accept JATS XML as a fourth input type, alongside PDF, .docx and the
spreadsheet formats.

**Why, and the first reason is a measurement rather than an argument.**
Of the 13,113 registry-linked papers that exist in PubMed Central
(measured 2026-08-30 against the PMC Cloud Service metadata objects):

| | n | with a PDF |
|---|---|---|
| Open Access subset | 7,277 | 6,863 (94%) |
| **author manuscripts** | **3,208** | **160 (5%)** |
| absent from the bucket | 2,788 | — |

**Author manuscripts are XML-only.** Without XML support those 3,208
papers are unreachable, and they are the ones worth reaching: an author
manuscript carries the baseline table as submitted, and the registry
holds the sponsor's own structured values for the same trial. That is
ground truth by construction for the parser itself — parse the table,
compare against what was typed into ClinicalTrials.gov. The protocol
PDFs measured in the false-positive work had no ground truth at all.

**Second, the API.** Steve's point, 2026-08-30: a publisher integrating
with the API already has JATS, because that is what their production
system emits. Asking them to render a PDF so that we can reconstruct
the table geometry we just destroyed is backwards. Manuscript systems
hold structured text; the API should accept it.

**Third, XML is simply better input.** No column clustering, no caption
scoring, no OCR, no decimal recovered from a glyph. The entire class of
defect that issues 24, 23 and 22 exist to chase does not arise: a JATS
table is real `<tr>`/`<td>`, and the only interpretation left is the one
we actually want to test — what the numbers mean.

### What it costs, which is less than it looks

The .docx work already built the seam. `R/parseDocx.R` has

```r
.ppDocxLines(mat, caption = NULL, footnotes = character(0))
```

which turns a cell matrix into the synthetic coordinates `.ppParseBlock()`
expects, so every existing behaviour — mean±SD, n (%), footnote-driven
SD-vs-SE disambiguation, arm-N recovery, skip reasons — works unchanged.
A JATS `<table-wrap>` is the same shape. `xml2` is already in
`DESCRIPTION`. The work is extraction and plumbing, not a new engine.

### Scope

- `R/parseJats.R`: `.ppJatsData()` (locate `<table-wrap>`, read with SAFE
  parser options), a cell matrix builder that expands `colspan`/`rowspan`,
  caption from `<label>`/`<caption>`, footnotes from `<table-wrap-foot>`;
  then hand all of it to `.ppDocxLines()`.
- Candidate loop over every table in the document, scored by
  `.ppParseScore()` + caption score, exactly as the .docx path does.
- Dispatch on `[.]xml$` inside `parseBaselineTableHeuristics()`; keep the
  `pdfFile` parameter name for API stability.
- **Route through `parseBaselineTableFiles()`** — the per-file subprocess
  with an OS timeout. This matters more for XML than it did for .docx;
  see security below.
- Extension plumbing: `app_server.R` allowlist and the non-PDF branch,
  `app_ui.R` accept list and blurb, `zipUpload.R`; `DESCRIPTION` Collate.

### Security — not optional, and the reason for the subprocess

XML carries two attacks a PDF does not:

- **Billion laughs**: nested entity definitions that expand a sub-kilobyte
  file into gigabytes. Resource exhaustion, not theft.
- **XXE**: `<!ENTITY x SYSTEM "file:///etc/passwd">` makes the parser read
  local files, or `SYSTEM "http://…"` turns the server into a request
  forwarder.

libxml2 defends against both **by default**. The danger is entirely in
options that switch the defence off — `NOENT`, `DTDLOAD` and above all
`HUGE`, which is the one someone adds at 2am to get past a "document too
large" complaint. So: read with defaults, never `HUGE`, and pin it in
`tools/securityCheck.R` as a tripwire rather than a convention. The
per-file subprocess contains what is left: a memory bomb kills the child,
not the app.

### Done looks like

- Synthetic JATS fixtures (mirroring `helper-syntheticDocx.R`): mean±SD,
  n (%) with complement columns, median [Q1, Q3], merged header cells,
  a decoy results table out-scored by the real Table 1, no caption.
- A **real PMC author manuscript** parses end to end.
- A billion-laughs fixture and an XXE fixture are both refused without
  reading a file or exhausting memory, asserted in tests.
- `tools/securityCheck.R` fails if `HUGE`/`NOENT`/`DTDLOAD` appear.
- **The ground-truth test**: for a sample of author manuscripts, the
  parsed table matches the registry's own baseline values. This is the
  point of the issue, not a bonus.

### Punts, recorded so they are not rediscovered

Multi-part tables split across sibling `<table-wrap>` elements are not
stitched. Tables supplied only as `<graphic>` fall to the existing OCR
path (issue 22), not here. Publisher DTDs that are not JATS are out of
scope; JATS covers PMC, Europe PMC and MECA, which is the whole corpus.

---

## 28. Report the build commit, so an unauthorized deploy is visible

**Status: implemented 2026-08-27** (PR #97 — `R/buildInfo.R`,
`tools/checkDeployedBuild.ps1`, scheduled task "IntegrityAnalysis
deployed-build check", daily 21:30).

From Steve's question: "do we have checks so that shinyapps.io itself
doesn't become malware?" Every control protected the *pipeline* — deploys
install only from GitHub, `securityCheck.R` gates
`deploy-production.yaml`, forks get no secrets, the tripwire bans
code-execution primitives — and **nothing attested the artifact**.

**How.** The deploy installs with `remotes::install_github()`, which
records the resolved commit as `RemoteSha` in the installed DESCRIPTION,
so the app already knew its commit and nothing had to be injected at
build time. Exposed as a `<meta name="integrity-build">` tag in the
initial HTML and a `commit` field on `GET /health`;
`checkDeployedBuild.ps1` compares both to `origin/main`.

**Not attestation.** Anyone able to deploy arbitrary code can report an
arbitrary commit. It catches the wrong branch, the stale deploy, the
rollback that never rolled forward, the hand-applied fix, and tampering
by anyone who did not think about it. The report distinguishes "behind
main" (ordinary) from "not a commit in this repository" (alarming),
because a check that cried wolf every time main moved would be ignored
within a week — and then the alarming case would be ignored too.

**Remaining:** production still reports no build commit until the next
production deploy carries this code. The nightly check flags that, which
is the honest behaviour rather than a false pass.

---

## 27. renv.lock pins versions but not contents

**Status: open.** Found 2026-08-27 while answering Steve's question
about malware in returned files.

All 125 package entries in `renv.lock` carry `Package`, `Version` and
`Source` — and **no `Hash` field**. So a restore is reproducible only as
far as the registry is honest: a hijacked re-release at the same version
number, or a compromised mirror, installs silently and every guarantee
built on package behaviour goes with it. The workbook-safety test
(`test-workbook-safety.R`) states this limit explicitly, because
"openxlsx writes strings, not formulas" is only as good as openxlsx
being openxlsx.

This matters more than it would in an ordinary app. The renv section of
AGENTS.md justifies pinning on the grounds that "an integrity finding
may be challenged, and the exact computational environment is on record
is part of the defense." A version number without a hash is a weaker
record than that sentence promises.

**Done looks like:** `renv.lock` carries a `Hash` per package and
`renv::restore()` verifies it, or the reason it cannot is written down
where the reproducibility claim is made.

---

## 26. An asynchronous API, for trials the synchronous one must refuse

**Status: open.** Surfaced 2026-08-27 when Steve asked whether capping
N at 10,000 would solve the compute-product problem.

The `/analyze` compute budget bounds the WORST case — every row
escalating to 100,000 replicates. The typical case is about 100x
cheaper, because rows stop at the first stage:

| 25 variables, N = 10,000/arm | |
|---|---|
| typical (rows stop at 1,000) | ~5 seconds |
| worst case (all rows escalate) | ~495 seconds |

The bind: **the rows that escalate are the suspicious ones.** So the
worst case is a fraudulent-looking mega-trial — precisely the
submission most worth analyzing. No synchronous budget both admits that
and bounds request time, which means the current design refuses its
most interesting inputs.

Steve's decision that a coarser p-value is worse than a refusal (issue
25's log, 2026-08-27) closes off the easy escape of quietly reducing
replicates. The remaining answer is to stop requiring an answer within
one request: `POST /analyze` returns a job id, the caller polls, and
the Monte Carlo runs to full precision however long it takes.

**Done looks like:** a publisher can submit any trial the app can
handle and get the same p-value the app would give, with no limit
imposed by HTTP. Until then the refusal message routes large single
trials to the web app, which has no request timeout.

---

## 25. Standing security screen: change-gated, adjudicated, not looped

**Status: implemented 2026-08-27** (`tools/securityScreen.ps1`, nightly
scheduled task "IntegrityAnalysis security screen", 21:00). Recorded
here because the *discipline* is the deliverable, not the script.

Steve asked whether to schedule a security screen when the API or UI
changes, and whether to re-run it after each patch "until it shows up
with zero issues" — the treat-to-target loop a physician runs on a
blood pressure. Both halves needed a qualified answer; AGENTS.md
"Two instruments, two stopping rules" carries the full reasoning.

**Scheduled, but change-gated.** Nightly at 21:00, doing nothing unless
the watched surface moved since the last screened commit (a ledger in
`tools/securityScreen.ledger`). A screen of an unchanged tree costs
tokens and produces noise. The ledger advances only after a report is
written, so a screen that dies leaves its range for the next run.

**Re-run after patches — but "zero issues" is the wrong endpoint.** The
tripwire (`securityCheck.R`) is a lab value: objective, defined normal,
free to repeat, and "repeat until normal" is exactly right. The screen
is a radiologist's read: it samples an *opinion*, so re-running always
yields new speculative findings and never converges to empty. Chasing
empty means patching what was never wrong — and **two of this project's
worst defects were introduced by security patches** (the CSV sanitizer
that broke issue 1's round-trip contract; the tripwire assertion that
matched a commented-out line and so passed on a deliberate break). The
endpoint is **every finding adjudicated** — fixed, or accepted with a
written reason — with each fix carrying an assertion verified to fail
on a deliberate break.

**"Are the API and UI the only entry points?" No.** They are the only
network-facing ones. The watched list also covers the parsers (a
manuscript is written by the adversary), `zipUpload.R`,
`outputComments.R`, and two that are easy to miss: `aiFallback.R`,
because a hostile document steers model output that becomes row labels
and CSV cells, and `.github/workflows/` + `renv.lock`, because
compromising the pipeline or a dependency beats any application bug.

**Found while writing this:** the standing conclusion in AGENTS.md that
"the AI fallback is off in deployment, so manuscript text never reaches
an LLM" had been false since the bring-your-own-key assist landed
(issue 8, PR #67). The code was reviewed when it merged; the *documented
conclusions it invalidated* were not. That drift is precisely what the
standing screen exists to catch, and it is the best argument for having
one.

**Done looks like:** each report in `docs/security-screens/` ending with
every finding marked fixed or accepted-with-reason before the next
merge touching the watched surface.

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
  (https://f1000research.com/articles/11-783): **IMPLEMENTED
  2026-08-30** — `barnettTStats()` and `barnettDispersion()` in
  `R/dispersionTest.R`.

  The characterisation recorded here on 2026-08-17 was wrong, and the
  correction is the reason the method is worth having. It is not "a
  Bayesian re-formulation of the Carlisle approach — same evidence,
  different inferential wrapper". It uses **different evidence** (a
  two-sample t-statistic per row per *pair* of arms, categorical rows
  included, where ours uses continuous rows only) and it tests a
  **different quantity**: ours tests the shape of a whole distribution,
  his tests one moment of it — the variance of the t-statistics.

  That distinction is the whole value. Barnett's own simulation study
  found that a distribution-shape test — his "uniform test", the family
  ours belongs to — fires on skew, on categorical data and on rounding,
  none of which is fraud, while a variance test does not. So the two
  disagreeing on the same table is diagnostic rather than embarrassing:
  it localises the anomaly to the shape of the distribution rather than
  to the spread of the data.

  Implemented by exact quadrature rather than MCMC. For a single trial
  his model has one binary switch and one continuous parameter, so the
  posterior is a one-dimensional integral; evaluating it directly is
  deterministic, dependency-free, and more accurate than the reference
  app's 1,000 kept draws (whose Monte Carlo error near his 0.95 flag
  threshold is about 0.007). `tests/testthat/test-dispersion.R` pins
  the agreement against nimble running his own model file.

Evaluation plan when picked up: run Carlisle–Shafer, Barnett, and
SPRITE/GRIM flags over corpus/TEST; compare per-trial calls; adopt
what adds discrimination, report what merely agrees as corroboration.
`corpus/barnettCorpus.R` does the first two over the 47,813-trial
ClinicalTrials.gov registry corpus, where the numbers are typed by
sponsors rather than parsed from PDFs and our parser is therefore out
of the loop entirely.

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

### First optimisation attempt found nothing worth taking (2026-08-28)

Profiled and measured at Steve's suggestion, using his method: a fixed
seed makes candidate rewrites verifiable, since identical draws must
give identical results. **No meaningful speed improvement was found.**
The loop is already close to what base R can do.

Where the time goes, for one chunk of 20,000 replicates x 2 arms x
N = 500:

| component | time | share |
|---|---|---|
| `rnorm` with the `rep()` mean | 0.894 s | 65% |
| `round(M, ROUND_OBSERVATION)` on the full matrix | 0.387 s | 28% |
| everything else | ~0.02 s | 2% |

`Nmat` / `rowsums` — the parts that look expensive — are about 1%.
Replacing them with a matrix-vector product measured *slower*.

Four rewrites were tried. All are **bit-identical**, which validates the
method; none is faster:

| rewrite | identical | speed |
|---|---|---|
| `rnorm(n)*sd + mu` instead of a vectorised mean | yes, max diff 0 | 1.00x |
| column recycling instead of `rep(meansim, N)` | yes | 0.91x |
| `round(M*10^d)/10^d` instead of `round(M, d)` | yes | 0.57x |
| `MCMean %*% N` instead of `Nmat` + `rowsums` | yes | slower |

**What would be faster, and what it costs.** `dqrnorm` draws ~3x faster
than base `rnorm`, but requires a SCALAR mean - which is exactly why the
code uses `rnorm` here. Rewriting as
`matrix(dqrnorm(N*ch), ch) * sd + meansim` (scale-and-add, column
recycling) measures **1.82x** on the full loop body. It is not
bit-identical: a different RNG stream moves every pinned Monte Carlo
value, so it would require re-baselining the known-answer fixtures and
re-running issue 3's validation.

**C was prototyped and is NOT faster.** A fused C kernel using R's own
`norm_rand()` - draw, round and accumulate in one pass, never
materialising the ch x N matrix - measured **0.94x**, slightly slower.
There is no interpreter overhead to remove: the loop is already three C
calls over ten-million-element vectors, and R's internals are better
optimised than a naive hand-written loop.

C also cannot be bit-identical here, for a reason worth recording.
`Rfast::rowmeans` does not sum in sequential order (pairwise or SIMD):

```
Rfast::rowmeans == base rowSums/n : FALSE, max|diff| 4.3e-14
after round(, 1): 8 of 1000 rows differ
```

A difference in the fourteenth decimal is arithmetically nothing, but
the code ROUNDS immediately afterwards, so it flips a value across a
`.05` boundary in about 1% of rows. Any fused implementation would have
to replicate Rfast's exact summation order to preserve pinned values.

**The one thing C buys unambiguously is memory**: 0.16 MB instead of
80 MB for that chunk, because nothing materialises the matrix. At the
current `1e8` chunk target the per-arm matrix is ~400 MB. That matters
for the OOM work in the 2026-08-28 screen, but it is a different goal
from speed and costs the package its first compiled dependency - and
`P_Calc.R` is the artifact the user guide now points investigators to,
so readable R has value beyond convenience.

Chunk size is also NOT a free parameter: with more than one arm the
per-arm `rnorm` calls interleave differently across chunks, so changing
`1e8` changes results. Verified on the real computation.

**Conclusion: leave it alone** (Steve, 2026-08-28). If the Monte Carlo
ever becomes the practical bottleneck, issue 26's async API buys more
than 1.82x by removing the request timeout altogether. Trial-level
parallelism remains the largest untried win and does not touch the
draws at all.

**Provenance worth recording**: this loop was written and optimised by
Steve in 2025. Four independent attempts to improve it produced nothing
faster, which is the useful measure of how well it was done.

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
