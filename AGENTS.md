# AGENTS.md

Orientation for **all AI coding assistants** working in this repository
(Claude Code, ChatGPT Codex, Gemini/Antigravity, ...). This is the
canonical agent documentation — CLAUDE.md is only a pointer here, kept
because Claude Code auto-loads that filename. Created 2026-08-16 as part
of a session hand-off (the two threads that converged here - app
code-review and PDF parsing - are described in the handoff documents
removed 2026-08-26; `git log --diff-filter=D -- handoff/` recovers
them), and
[`ISSUES.md`](ISSUES.md) for the **canonical open-issues list** — read
its "Where things stand" section before starting substantive work.

## What this is

A Shiny app implementing the Carlisle–Shafer Monte Carlo analysis of
baseline data in randomized controlled trials, used in Steve Shafer's work
as a journal editor detecting research fraud (references in README.md).
This is a **standalone project, unrelated to any other repository on this
machine**. Since the phase-1 restructure (2026-08-16, ISSUES.md issue 10,
plan since completed and removed 2026-08-26 - `git log --diff-filter=D
-- docs/package-restructure-plan.md` recovers it)
it is an **R package**, modeled on stanpumpR: `R/app_globals.R` (constants,
`sumz()`, `outputComments()` — was `global.R`), `R/app_ui.R` (`app_ui()`,
shinydashboard page — was `ui.R`), `R/app_server.R` (`app_server`,
validation pipeline + `P_Calc()` Monte Carlo — was `server.R`),
`R/app_run.R` (exported `run_app()`, attaches libraries, registers
`inst/www` under the `www/` resource prefix). `app.R` is a one-line shim.
Bundled assets live in `inst/www`; `Template.xlsx`, `Example.xlsx`, and
`IntegrityAnalysis.html` in `inst/extdata`, resolved with `system.file()`.
The user documentation's MASTER is `docs/user-guide.md` (issue 14) —
edit the Markdown, then regenerate the served HTML with the pandoc
command in its header comment; never edit `inst/extdata/IntegrityAnalysis.html`
directly, and keep the two in sync in the same commit.
The environment is renv-pinned — see the "renv" section below (the
early no-renv stance was reversed 2026-08-20; this line was stale
until the 2026-08-26 repo audit caught the contradiction). Since the
ParsePDF fold-in
(2026-08-17, issue 9) the package also contains the PDF parser
(`R/parseBaselineTable*.R`, `tokenize.R`, `pageLayout.R`, `aiFallback.R`,
`utils.R`, `writeIntegrityTemplate.R`, all internals `.pp`-prefixed) and
its testthat suite. Since the issue-4 consolidation (2026-08-19) the
suite (`tests/testthat/`, 514 assertions) also covers the app side -
input contract, known-answer Monte Carlo under fixed seeds, the full
headless pipeline, grid mechanics, round trips - all from synthetic data
and synthetic PDFs, no corpus or Carlisle files needed. When testing
uploads with `shiny::testServer`, ALWAYS stage a copy of the file in its
own subdirectory of `tempdir()` and upload the copy - the purge-on-exit
handler deletes uploaded paths.

The upload pipeline (since 2026-08-17 all input modes converge on one
editable grid — Steve's original vision): file (csv/xls/xlsx, **or an
article PDF**, parsed by the deterministic engine in a subprocess and
narrated in the comments log) → the **editable rhandsontable grid** (fix a
missing N or a mistyped SD in place; "Apply Edits & Revalidate") →
column-name normalization by grep (any "MEAN"-containing name that isn't
MEAN → `ROUND_MEAN`, "OBS" → `ROUND_OBSERVATION`, "TRIAL", "ROW"/"GROUP",
"NUMBER" → N) → per-line validation (continuous rows need N/MEAN/SD;
category rows must be numeric, integer-valued, with at least one NA in the
column) → per-trial `P_Calc()`: closed-form weighted means, Monte Carlo of
rounded simulated means (continuous) or simulated chi-square under fixed
margins (categorical), **mid-p** ties, rows combined with Stouffer's
`sumz()` into a **single one-sided p toward excessive homogeneity**
(issue 6: small p = data more similar across arms than random sampling
explains — the fraud signal; heterogeneity is deliberately not reported,
and the categorical branch takes the lower tail, not `chisq.test`'s
upper tail). A
failed PDF extraction is a round trip: the partial table is offered as a
download in the app's own input layout. Local hand-test PDFs, one per
parsing challenge: `corpus/` (see its README).

## Running, testing, deploying

- Use **R 4.5.3**: `"C:\Program Files\R\R-4.5.3\bin\Rscript.exe"` (its 4.5
  user library has all packages; the 4.6 library does not).
- Do not start R while the shell is in another project's directory — an
  renv-managed project there will hijack the library path.
- Run locally: install the package (`R CMD INSTALL --no-multiarch .`) then
  `IntegrityAnalysis::run_app()` — or `shiny::runApp()` on `app.R`.
- Deploy (since the phase-1 package restructure): install the package
  **from GitHub** so rsconnect records the GitHub source, then ship only
  the shim — the old hand-maintained `appFiles` list (and its risk of
  uploading the Carlisle spreadsheets) is gone:

  ```r
  remotes::install_github("StevenLShafer/IntegrityAnalysis")  # or @<branch> for a PR app
  rsconnect::deployApp(appDir = "C:/dev/IntegrityAnalysis",
    appName = "IntegrityAnalysis",       # or IntegrityAnalysis_PR_<n>
    appFiles = "app.R",
    account = "steveshafer", server = "shinyapps.io",
    forceUpdate = TRUE, launch.browser = FALSE)
  ```

  A locally-installed (`R CMD INSTALL`) copy will NOT deploy — shinyapps.io
  can only fetch the package from GitHub, so push first, deploy second.
  PR test apps are `IntegrityAnalysis_PR_<n>`; purge them after merging.
  **A PR test app must identify itself in the UI** (Steve's rule,
  2026-08-16): deploy it with an `app.R` of the form
  `IntegrityAnalysis::run_app(testNote = "PR #<n>: <what to test>")` —
  write that shim to a scratch directory and point `deployApp(appDir=)` at
  it, so the repository's production `app.R` is never edited. The note
  renders as an orange banner under the header, telling the tester which
  PR this is and what to look at without opening GitHub.
  (The pre-package procedure is in git history; the handoff documents
  were removed 2026-08-26 as completed.)
- Production: https://steveshafer.shinyapps.io/IntegrityAnalysis/
  (rsconnect account `steveshafer`).
- Headless functional testing pattern (until a real suite exists): drive
  the server with `shiny::testServer`; simulate `input$upload` with a
  one-row data.frame carrying `datapath`, and read `<<-`-mutated state via
  `session$env$...` (the test block only sees a clone).

## renv - the pinned environment

Adopted 2026-08-20 (Steve's decision). `renv.lock` is the single source
of truth for R (4.5.3) and every package version, because this tool's
verdicts must be reproducible: an integrity finding may be challenged,
and "the exact computational environment is on record" is part of the
defense. The known-answer tests pin the Monte Carlo values themselves;
the lockfile pins everything those values depend on.

- **Local**: the project `.Rprofile` auto-activates renv. After pulling
  a lockfile change, run `renv::restore()`. After adding a dependency
  (DESCRIPTION first - Imports or Suggests - then `renv::install()`),
  run `renv::snapshot()` and commit `renv.lock` in the same PR. The
  snapshot type is **explicit**: DESCRIPTION's runtime declarations
  (Imports, recursively) are recorded and nothing else. Dev tooling
  (testthat, rcmdcheck, rsconnect, remotes) deliberately FLOATS - its
  versions cannot affect the statistical results, and pinning it would
  drag hundreds of transitive suggests into the lockfile.
- **CI and deploys** restore from the lockfile
  (`r-lib/actions/setup-renv@v2` in `R-CMD-check.yaml`,
  `deploy-production.yaml`, `deploy-pr-app.yaml`), so the runner's
  library - and therefore the versions rsconnect writes into the
  manifest and shinyapps.io installs - are the locked ones.
- **Floating breakage is discovered on a schedule, not in an
  emergency**: `cran-canary.yaml` runs the full check every Monday
  against R "release" and latest CRAN. A red canary blocks nothing; it
  means "plan a lockfile refresh".
- **Refresh policy**: deliberately, roughly monthly or when the canary
  goes red - `renv::update()`, run the full suite (the known-answer
  tests are the arbiter; if an upgrade moves the pinned Monte Carlo
  values, re-pin them and say so in the commit), snapshot, PR.

## Working alongside other sessions

Multiple Claude sessions work this repository (proven 2026-08-21). The
standing rules, each learned from a real incident:

- **Unpushed work does not exist** (2026-08-16: a local branch was
  destroyed by a concurrent merge). Push immediately after committing.
- **The shared user library is nobody's**: this repo's sessions run on
  the renv project library, and batch jobs should use a private library
  from a git worktree (the 2026-08-21 install race invalidated a
  peer's measurements mid-run when the user library changed under it).
- **Do not switch branches in C:/dev/IntegrityAnalysis while a
  detached run launched from it is still loading** - long jobs load
  code once at start and are immune afterwards.
- **Check for peers before assuming a PR, branch, or push is yours** -
  `gh pr list` surprises happen (PRs 51/53 arrived from a parallel
  session mid-day). Cross-session messages can be exchanged with the
  SendMessage tool when coordination is needed.
- Long-running work in flight is recorded in ISSUES.md "Where things
  stand" with its log path - read that section FIRST in a new session.

## Security

Security must be assured before anything deploys (Steve's requirement,
2026-08-20). The threat model is specific and unusual: **the adversary is
the author of a manuscript under investigation.** An editor can be
induced to upload a file that author crafted, so every uploaded artifact
- spreadsheet, PDF, file *name* - is hostile input.

### The API surface (added 2026-08-26)

The REST service (issue 1) widened the model: the adversary is now the
manuscript author **plus anyone on the internet, with or without a
token**. Three app-side guarantees did NOT extend to it automatically,
and the review that found them is the reason the following are pinned
by `tools/securityCheck.R` property group 5 - do not remove one without
replacing the property:

- **Request size**: the app's `shiny.maxRequestSize` does not apply to
  plumber, which buffers a whole multipart body in memory before any
  handler runs. `inst/api/plumber.R`'s `sizelimit` filter rejects
  oversized bodies 413 by header, *before* auth, because the body
  arrives before the handler does.
- **Compute**: `/analyze` refuses a table above `.apiMaxRows` /
  `.apiMaxTrials` before simulating. plumber is single-threaded and the
  Monte Carlo escalates precisely on homogeneous-looking rows, so a
  crafted table could otherwise pin the service past App Runner's
  request timeout and starve `/health`.
- **Spreadsheets**: `.xlsx` is a zip, and the API's read runs
  in-process (unlike PDFs, which get the subprocess batcher).
  `.apiZipInflationOK` reads the zip directory's declared uncompressed
  sizes and refuses a bomb before a byte is inflated.
- **Returned CSVs are formula-sanitized** (`.apiCsvSafe`): the "our
  workbooks cannot smuggle formulas" property was proven for xlsx
  string cells and does NOT hold for `write.csv`. A row label like
  `=HYPERLINK(...)` parsed from a manuscript would execute when the
  editor opens the file.
- **The caller's AI key never touches disk**: `.ppSplitChildKey` keeps
  it out of the child options RDS and it travels by environment
  variable on the `system2` call (not argv, so invisible to `ps`).
- **Errors say nothing**: `pr_set_error` returns a fixed 500 body;
  plumber's default handler would return R condition text carrying
  tempdir paths or upload fragments.

Confirmed good and worth preserving: auth fails closed (no tokens
configured = nothing authorized), zip *upload* handling is unreachable
from the API (`expandZipUploads` is Shiny-only), filenames are
`basename()`d into a per-request tempdir, and issued tokens are
256-bit with only their hashes stored.

The standing conclusions of the 2026-08-20 full-repository review:

- **A malicious document cannot execute code here.** PDFs are parsed by
  poppler (via pdftools), which reads them as data and never runs their
  embedded JavaScript; in the app every parse runs in a subprocess with
  a 60-second OS timeout, so a crafted PDF can at worst crash or stall
  its own subprocess. Spreadsheet readers (read.csv, openxlsx, readxl)
  parse data, not code. Nothing in `R/` evaluates constructed code
  (`eval`, `parse(text=)`, `system`, shell) - the one subprocess
  launcher (`parseBaselineTableFiles.R`) shQuote()s every argument and
  runs `Rscript --vanilla`.
- **User text is escaped before it reaches HTML.** The comments log is
  rendered with `HTML()`; every message is escaped at the single entry
  point (`outputComments.R::.escapeHtml`) because uploaded file names
  flow into it.
- **Workbooks we write cannot smuggle formulas.** openxlsx writes
  character cells as strings; a grid cell starting with `=` stays text.
  `writeFormula()` is used only in local corpus tooling on our own
  strings, never on uploaded content.
- **The AI fallback is off in deployment BY DEFAULT** (`ai = "never"`),
  so manuscript text never reaches an LLM unless the uploader has
  entered their own key. *Corrected 2026-08-27:* this bullet used to
  read "is off in deployment... never reaches an LLM", which stopped
  being true when the bring-your-own-key assist landed (issue 8, PR
  #67) and nobody revisited it. With a key entered, page text and page
  images DO go to Anthropic for that session, and two consequences
  follow that the old wording hid:
  - **A prompt-injection payload in a manuscript reaches a model.** It
    cannot execute anything, but it can steer what comes back.
  - **Model output is therefore untrusted input.** It becomes row
    labels, grid cells and CSV values. Those paths are defended
    (escaped into the log, formula-sanitized into CSVs) - but they are
    defended *as untrusted input*, and must stay that way.
  This is the drift the standing screen exists to catch: the code was
  reviewed when it landed; the conclusions that the code invalidated
  were not.
- **Deploy secrets stay out of reach.** Workflows trigger on
  `pull_request`, never `pull_request_target`; forked PRs get no
  secrets. The API key lives only in the environment, never in code.
- **Archives are extracted defensively.** Any zip/tgz handling must
  refuse absolute paths and `..` components, extract by basename into a
  fresh directory, cap entry count and total uncompressed size, and
  never recurse into nested archives.
- **There are two subprocess launchers, and both are pinned** (the
  second added 2026-09-02 with the Table Transformer seam, PR #147).
  `parseBaselineTableFiles.R` runs `Rscript --vanilla` per file;
  `parseTatr.R`'s `.ppTatrRun()` runs the pegged Python over one PDF -
  pdfium and pdfminer are two more decoders on hostile bytes, so it is a
  subprocess under an OS timeout, never the worker. Its properties are
  reviewed in `tools/securityCheck.R` group 1 and verified to trip on a
  break: interpreter and script from configuration, never from a
  request; every argument `shQuote()`d and every path ours; offline
  (no `--allow-download`); output read as XML data. It is absent on
  shinyapps.io (no Python there), so the deployed app's surface did not
  change; a Docker/API image that sets `INTEGRITY_TATR_PYTHON` takes it
  on knowingly. The XML the model returns is data: nothing in it is
  evaluated, and the model never decides which table is the baseline
  table.

### Two instruments, two stopping rules (added 2026-08-27)

Steve asked whether the screen should be scheduled, and whether it
should re-run after every patch "until it shows up with zero issues" -
the treat-to-target loop a physician runs on a blood pressure. The
answer is yes to re-measuring, but the two instruments here are not the
same kind of measurement and do not share a stopping rule.

- **`tools/securityCheck.R` is the lab value.** Hand-verified
  properties, checked mechanically, defined normal range (exit 0), free
  to repeat. Runs on every push and before every deploy. *Repeat until
  normal is exactly right here* - if it is red, something a human
  verified is now false.
- **`tools/securityScreen.ps1` is the radiologist's read.** A model
  reasoning over changed code, finding what no assertion encodes - the
  journal-table amplification DoS (2026-08-27) was legal input, legal
  code, every input gate passing, and a response that expanded
  super-linearly on the way out.

The screen samples an *opinion*, not a state. Re-running it draws a
fresh sample containing new speculative findings whether or not the
system changed, so "loop until it comes back empty" does not converge -
and chasing an empty report means patching things that were never
wrong. That is not hypothetical: **two of this project's worst defects
were introduced by security patches.** The CSV sanitizer renamed
variables and broke issue 1's round-trip contract. The tripwire
assertion written to pin a fix matched a commented-out line, so it
passed on a deliberate break - a test that tested nothing. Every
intervention carries its own risk, and an asymptomatic finding can be
worse treated than left alone.

**So: re-screen after every patch, but the endpoint is EVERY FINDING
ADJUDICATED - fixed, or accepted with a written reason in the report -
not "the next screen returns empty."** A fix should also arrive with
the assertion or test that would catch its regression, and that
assertion must be verified to FAIL on a deliberate break before it is
believed.

**Scheduling:** nightly at 21:00, but change-gated. `securityScreen.ps1`
compares HEAD against the last screened commit in
`tools/securityScreen.ledger` and does nothing unless the watched
surface moved; a screen of an unchanged tree costs tokens and produces
noise. The ledger advances only after a report is actually written, so
a screen that dies leaves its range unclaimed for the next run. Reports
land in `docs/security-screens/`. **The screen never patches** - it
reads and reports, and what to do about a finding stays a decision made
with the whole system in view.

**Entry points are not just the API and the UI.** Those are the only
network-facing ones, but the watched list in `securityScreen.ps1`
covers every place attacker-controlled bytes cross into trusted code,
including two that are easy to forget: `aiFallback.R`, because model
output steered by a hostile document is untrusted input, and
`.github/workflows/` plus `renv.lock`, because compromising the
pipeline or a dependency beats any application bug.

**The gate:** `tools/securityCheck.R` mechanises the properties above
that a one-line diff could silently break, and runs in both
`R-CMD-check.yaml` (every PR) and `deploy-production.yaml` (before every
deploy - a failure stops the deploy). Run it locally with
`Rscript tools/securityCheck.R`. When adding code, keep it green
honestly: if a new feature genuinely needs a banned primitive, the
review happens FIRST and the script's allowlist is extended in the same
PR, with the reasoning in comments.

## Conventions

- Case sensitivity: shinyapps.io runs Linux — filenames in code must match
  exactly (the old `Global.R`-vs-`global.R` failure generalizes).
- Generous comments; every non-obvious or AI-drafted change carries a
  provenance header (origin, date, run/verified status) and in-place
  `FIX:`/rationale comments. See the tops of `R/app_globals.R`,
  `R/app_server.R`, and `parseCovariateTable.R` for the house style.
- Small, focused commits — one issue each. **Push immediately after
  committing**: two agents have shared this repository, and
  committed-but-unpushed work was already lost once when a merged branch
  was deleted (recovered in `81b03cf`). Unpushed work does not exist.
- Pull requests (Steve's rules, 2026-08-16): every PR **branches directly
  from `main`** — never stack a PR on another PR's branch; each PR is
  devoted to **one specific issue**, so its testing scope is obvious; and
  the PR description **opens with a plain statement of the change made**.
- `main` is **protected** (2026-08-17): force-pushes and branch deletion
  are blocked for everyone. Admin (Steve's account) can still push
  ordinary commits directly — used for documentation-only changes; code
  goes through PRs. If a push is rejected, do not try to work around the
  protection; rebase onto the current `main` and push normally.
- **`R-CMD-check` is a required status check on `main`** (2026-08-19,
  phase 5): every PR must pass the GitHub Actions R CMD check — which
  runs the full testthat suite on a bare Ubuntu runner — before it can
  merge. The workflow is `.github/workflows/R-CMD-check.yaml`; it fails
  on ERRORs and tolerates the one documented `library()` WARNING (see
  the comment there). A PR whose check is red is not mergeable — fix
  the tests, never bypass.
- **The deploy trio is live** (2026-08-19, phase 5 complete):
  `deploy-production.yaml` redeploys production after `R-CMD-check`
  SUCCEEDS on a `main` commit (2026-08-20: it triggers on that
  workflow's completion and deploys that exact tested SHA, so the
  553-assertion suite passing before every deploy is a mechanism, not
  a convention; `workflow_dispatch` remains for manual redeploys);
  `deploy-pr-app.yaml` deploys `IntegrityAnalysis_PR_<n>` for
  every PR — banner auto-generated as "PR #n: <PR title>", link posted
  as a PR comment, redeployed on each push; `cleanup-pr-app.yaml`
  purges the app when the PR closes. So: DO NOT manually deploy
  production or PR test apps, and do not manually purge PR apps — the
  workflows do all three (the manual recipe below is for emergencies
  only). Secrets: `SHINY_TOKEN`/`SHINY_SECRET` (verified 2026-08-19),
  vars `SHINY_ACCOUNT`/`SHINY_APP_NAME`.
- No Bioconductor-dependent packages (the shinyapps.io image build breaks
  on them — that is why `metap` was replaced by a local `sumz()`).
- Keep secrets and per-user data out of `outputComments()` logs and out of
  bookmark state.

## The parser optimization loop

### Development and holdout (added 2026-08-27) — READ FIRST

Steve asked whether refinements built on one corpus should be tested on
another before being deployed and measured against Carlisle and A&A. Yes
— and the question exposed a larger gap: **until 2026-08-27 there was no
held-out set anywhere in this repository.** The loop below reads the
failures in `ParseOutcomes.csv`, fixes the code, and re-measures on the
same 1,865 articles. Every parse-rate number it ever produced, including
the **84.9% being quoted to editors**, was measured on the corpus the
fixes were developed against.

`corpus/Holdout.csv` now freezes a 25% stratified holdout (465 articles;
1,400 development). Stratified by source AND outcome, so both halves
start at exactly 84.9% by construction and any later divergence is
signal. `corpus/freezeHoldout.R` **refuses to redraw it** — a split that
can be regenerated is not a holdout, and the accident to guard against is
someone re-running a script, not anyone deciding to cheat.

**Develop against `SET == "development"`. Report against
`SET == "holdout"`, and only after the change is finished** — a holdout
consulted during development is just a test set.

**What freezing cannot do.** It protects the future, not the past. These
articles have been read and their failures studied for weeks, so the
holdout drawn today has already influenced the code. No number measured
on it is clean until it has survived a development cycle it did not
participate in.

So the best *uncontaminated* estimate available today does not come from
this corpus at all — it comes from corpora that have never driven a fix:
medRxiv preprints and PubTables-1M. That is what makes the cross-corpus
proposal more than hygiene.

### Where the corpora live

All of them, as of 2026-08-31, are one archive: **`C:/dev/Corpus`**, built
by [`corpus/buildCorpusLibrary.R`](corpus/buildCorpusLibrary.R) and
described by its own `README.md` at that path. 17,032 works,
36,842 files, one `IA######` accession per work, `master/<format>/<accession>.<ext>`.

Two things follow that did not hold before. **Formats join on the
filename** — `master/pdf/IA004512.pdf` and `master/xml/IA004512.xml` are
the same work by construction, and 6,565 works hold both. And **sharing is
decided by the index, not by a person**: `index/master.csv` carries
`FILE_SHAREABLE` and `DERIVED_SHAREABLE` per file, and
[`corpus/extractShareable.R`](corpus/extractShareable.R) copies only what
they permit. The A&A submissions are marked `confidential` — in the
archive, never out of it. `index/identity.csv` (accession → PMID, journal,
title, authors) is excluded from every extraction tier.

### Which corpus answers which question

They differ in KIND, not just in sample, so "develop on A, test on B"
changes domain as well as split — a drop can mean overfitting *or* a
different kind of table, and symmetric A→B/B→A testing cannot tell them
apart. Use each for what only it can answer:

| corpus | ground truth | what it alone can answer |
|---|---|---|
| **PubTables-1M** (93,834) | structure only | geometry regression — does a fix break column clustering across 75k diverse tables? Cheap, broad, run FIRST |
| **medRxiv** (growing) | none | real-PDF robustness, and wrong-table selection (issue 24), because it has whole articles |
| **Carlisle** (1,865) | printed VALUES | the only corpus that can confirm *correctness* rather than yield. Guard its holdout hardest |
| **A&A** (6,328) | none | population realism — what actually arrives at a journal |

**The metric is the trap.** Parse RATE is not correctness. The misparse
measurement found 9.6% of files returning a table with zero corroboration
— a wrong table, confidently parsed. A refinement can raise parse rate
*while* increasing wrong-table selection, and a cross-corpus gate scored
on yield would reward exactly that. Score on correctness where truth
exists (Carlisle values, PubTables structure) and on corroboration where
it does not.


The PDF parser (the `R/` files prefixed with parse*/tokenize/pageLayout/
aiFallback, folded in from the ParsePDF package 2026-08-17, issue 9) is
the hardest problem in this repository, and it is **deliberately set up to
be re-attacked by large language models every few months**. If you are an
LLM reading this because Steve asked you to look for parser improvements,
this section is your map.

- **The problem**: extract the baseline demographics table ("Table 1") of
  a randomized controlled trial from an article PDF — one row per
  variable per arm, means/SDs/Ns with their printed rounding — using only
  the PDF text layer, deterministically. Journals differ in layout,
  column conventions, and font encodings (several journals print `=` or
  `±` as private-use glyphs; see the repairs pinned in the test suite).
- **The evidence**: [`corpus/ParseOutcomes.csv`](corpus/ParseOutcomes.csv)
  — the master sheet, one row per PDF in the 1,865-article corpus, with a
  binary outcome (**successfully parsed / not successfully parsed**) and a
  `COMMENTS` column: the steps taken when parsing succeeded, and where the
  process failed when it did not. Read the failures, then read the code.
  [`corpus/README.md`](corpus/README.md) documents the columns, the
  current baseline (71.9% parsed; 58% exact value recovery against
  Carlisle), and the regeneration command.
- **The corpus PDFs** are copyrighted and live locally in the corpus
  library at `C:/dev/Corpus/master/pdf/<accession>.pdf` — never commit
  them. The test suite needs none of them (synthetic PDFs via `pdf()`).
  The as-downloaded tree is still at `C:/temp/journals`
  (`<journal>/<year>/<n.m>.pdf`), hard-linked to the same bytes, and the
  older `corpus/*.R` scripts still read it; new work should use the
  library and its index.
- **The third engine** (2026-09-02, PR #147): `R/parseTatr.R` takes the
  Table Transformer's geometry (`python/tatr/`, run on the Linux nodes or
  wherever `tools/tatrProvision.sh` has been applied) and the PDF's own
  characters - text layer, or tesseract on a scanned page - through the
  same block parser. It is a rescue tier behind the text engine; the
  model never chooses the table. Architecture guide 05d.
- **The architecture**: [`docs/parsepdf-architecture.md`](docs/parsepdf-architecture.md)
  (with an HTML twin). Entry points: `parseBaselineTable()` (one PDF,
  deterministic-then-optional-AI), `parseBaselineTableFiles()` (batches;
  one subprocess per file with an OS timeout — never loop over PDFs
  in-process, ~2% hang poppler), `writeIntegrityTemplate()` (emits the
  app's input format). The AI fallback's prompt and JSON schema — part of
  the published method — are `.ppSystemPrompt()` and
  `.ppTableSchemaJson()` in `R/aiFallback.R`, written to be read.
- **The rules**: the deployed path stays deterministic and offline (the
  app screens *unpublished* manuscripts; same input must always give the
  same verdict). Keep the ~295-assertion test suite green and add a
  fixture for every new corpus defect found. Score any change both ways:
  parse rate (`corpus/buildParseOutcomes.R`) **and** value accuracy
  against Carlisle — parsing more tables while misreading more numbers is
  a regression.

## Adjacent work

- **`C:/dev/ParsePDF`**: the parser's former home (now folded in here —
  its git history holds the development record; the repo is retired).
- **`G:/projects/Fraud/2025`**: Steve's original dev folder (assets,
  Carlisle corpus files, old code in `Old Files/`).
