# IntegrityAnalysis

Statistical screening of randomized controlled trials for fabricated or
erroneous baseline data, by the Carlisle–Shafer Monte Carlo method: the
baseline arms of an honest RCT are random samples of one population,
and means that agree *too well*, variable after variable, are evidence
against the random-sampling model the table claims — a reason to verify
the table, the allocation and the data, not a verdict on how the table
came to be.

The method as it runs today is described in
[docs/statistics.md](docs/statistics.md); what changed from the original
Carlisle–Shafer method, and when, is in
[docs/method-history.md](docs/method-history.md); the engine's agreement
with Carlisle's 2017 corpus, run by run, is in
[docs/validation-ledger.md](docs/validation-ledger.md).

**Use it now:** <https://steveshafer.shinyapps.io/IntegrityAnalysis/> —
upload (or drop anywhere on the page) an article PDF, a Word
manuscript, a JATS XML article, a spreadsheet, a picture of a table
(jpg, png, tif - or paste a screenshot), or a zip of many; review the
extracted table in an editable grid; analyze. The
[user guide](https://integrityanalysis.io/guide.html) covers
everything, including the privacy contract (IntegrityAnalysis itself
retains nothing you upload; the one exception is the optional
bring-your-own-key AI assist for hard-to-read documents. When it is
on, the page the table sits on goes to Anthropic under your own key —
as text when the page has a text layer, as a rendered image when it is
a scan — and, if no table can be read there, up to 60,000 characters of
the article's text; see [data handling](docs/data-handling.md) for
exactly what is sent, what Anthropic keeps, and for how long).

## What is here

- **The Shiny app** (`R/app_*.R`) — the interactive screen above.
- **The parse engine** (`R/parse*`, `R/tokenize.R`, `R/pageLayout.R`) —
  deterministic extraction of baseline tables from PDFs (85% of a
  1,865-trial journal corpus), Word manuscripts, JATS XML, journal-style
  spreadsheets, and pictures of tables (jpg/png/tif, read by tesseract's
  own reader - no ImageMagick), with the opt-in, bring-your-own-key AI
  assist described above for what the deterministic reader cannot read.
- **The Monte Carlo** (`R/P_Calc.R`) — adaptive replicates, exact
  rounding treatment, median/IQR rows via a metalog null, one-sided p
  toward homogeneity, exact combination across rows; measured against
  Carlisle's 2017 analysis run by run (the current engine: r = 0.993 and
  98.5% alarm concordance over 5,041 usable trials; every run in
  [docs/validation-ledger.md](docs/validation-ledger.md)).
- **The REST API** (`R/apiService.R`, `inst/api/`, `Dockerfile`) — the
  same analysis for editorial systems: bearer-token auth, round-trip
  failure payloads, per-request AI assist, nothing retained.
- **The evidence** (`corpus/`, `tests/`) — the regression corpus
  tooling and a testthat suite of about 1,900 tests (50 files; all
  synthetic data, no corpus files needed); every parser change is
  measured against the corpus before it ships.

## Run it locally

The package is renv-pinned to **R 4.5.3** (`renv.lock`; `DESCRIPTION`
declares R ≥ 4.1). From a clone:

```sh
Rscript -e "renv::restore()"          # the locked library (the .Rprofile activates renv)
R CMD INSTALL --no-multiarch .        # install the package
```

```r
IntegrityAnalysis::run_app()                    # the Shiny app; app.R is a one-line shim
IntegrityAnalysis::runApiService(port = 8080)   # the REST API
```

The API is `R/apiService.R` with its plumber routes in
`inst/api/plumber.R`; the `Dockerfile` builds the container that AWS
App Runner serves. Two size limits are set in code: the app accepts
uploads up to 50 MB (`R/app_run.R`, `shiny.maxRequestSize`) and the API
refuses a request over 25 MiB (`R/apiService.R`, `.apiMaxBytes`, applied
both as plumber's own request cap and as a filter).

## The method

1. Carlisle JB. The analysis of 168 randomised controlled trials to
   test data integrity. *Anaesthesia*. 2012;67:521–537.
2. Carlisle JB, Dexter F, Pandit JJ, Shafer SL, Yentis SM. Calculating
   the probability of random sampling for continuous variables in
   submitted or published randomised controlled trials. *Anaesthesia*.
   2015;70:848–858.
3. Carlisle JB. Data fabrication and other reasons for non-random
   sampling in 5087 randomised, controlled trials in anaesthetic and
   general medical journals. *Anaesthesia*. 2017;72:944–952.

## Authorship

Steve Shafer designed the method with John Carlisle and wrote the
original application (2025) entirely by hand. Since mid-August 2026,
essentially all code in this repository has been written by **Claude**
(Anthropic's Claude Code; models Claude Opus 5 and Claude Fable 5)
working under Steve's direction: Steve sets the goals, reviews the
behavior, and tests every change against real manuscripts; Claude
writes the code, the tests, and the documentation. Every source file
carries a provenance header saying who wrote it, when, and what
verified it — the same auditability the app demands of the trials it
screens. Credit where due, in both directions.

## License and contact

MIT (see `LICENSE`). Questions, comments, suggestions: Steve Shafer,
<steven.shafer@stanford.edu>. A flag from this program is a screening
signal, never an allegation — see the caveat in the app and the guide.
