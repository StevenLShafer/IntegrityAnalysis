# IntegrityAnalysis

Statistical screening of randomized controlled trials for fabricated or
erroneous baseline data, by the Carlisle–Shafer Monte Carlo method: the
baseline arms of an honest RCT are random samples of one population,
and means that agree *too well*, variable after variable, are evidence
that no randomization ever happened.

**Use it now:** <https://steveshafer.shinyapps.io/IntegrityAnalysis/> —
upload (or drop anywhere on the page) an article PDF, a Word
manuscript, a spreadsheet, a picture of a table (jpg, png, tif - or
paste a screenshot), or a zip of many; review the extracted table in
an editable grid; analyze. The
[user guide](https://integrityanalysis.io/guide.html) covers
everything, including the privacy contract (IntegrityAnalysis itself
retains nothing you upload; the one exception is the optional
bring-your-own-key AI assist for hard-to-read documents, which sends
the unreadable pages to Anthropic under your own key — see
[data handling](docs/data-handling.md) for what Anthropic keeps, and
for how long).

## What is here

- **The Shiny app** (`R/app_*.R`) — the interactive screen above.
- **The parse engine** (`R/parse*`, `R/tokenize.R`, `R/pageLayout.R`) —
  deterministic extraction of baseline tables from PDFs (85% of a
  1,865-trial journal corpus), Word manuscripts, JATS XML, journal-style
  spreadsheets, and pictures of tables (jpg/png/tif, read by tesseract's
  own reader - no ImageMagick), with an opt-in AI tier for scans.
- **The Monte Carlo** (`R/P_Calc.R`) — adaptive replicates, exact
  rounding treatment, median/IQR rows via a metalog null, one-sided p
  toward homogeneity, Stouffer combination; validated against
  Carlisle's 2017 analysis of 5,080 trials (r = 0.993, 99.0% alarm
  concordance).
- **The REST API** (`R/apiService.R`, `inst/api/`, `Dockerfile`) — the
  same analysis for editorial systems: bearer-token auth, round-trip
  failure payloads, per-request AI assist, nothing retained.
- **The evidence** (`corpus/`, `tests/`) — the regression corpus
  tooling and a test suite of 1,000+ assertions; every parser change
  is measured against the corpus before it ships.

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
