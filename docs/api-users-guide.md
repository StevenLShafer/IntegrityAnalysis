<!--
  api-users-guide.md - the IntegrityAnalysis REST service, for the people
  who will call it: an editorial-system integrator, a publisher's
  engineer, or an editor with a script.

  PROVENANCE: written 2026-09-03 by Claude Code (model Claude Fable 5.1)
  at Steve Shafer's request ("perhaps we should create 'API Users
  Guide.md'. The guide would define every field in the API, and include
  R and Python examples (after testing and locally validating)"). Every
  reply shown here was captured from a real service run on 2026-09-03
  (tools/apiClient.R and tools/apiClient.py against a local service),
  abridged only where marked. The field lists are exhaustive for the
  service as built. (docs/api-spec.md is the retired August 2026 design
  note, kept so that links to it resolve.)

  TO REGENERATE THE WORD VERSION for distribution:
    "C:\Program Files\Quarto\bin\tools\pandoc.exe" docs/api-users-guide.md
      --toc --metadata title="IntegrityAnalysis - API User's Guide"
      -o IntegrityAnalysis-api-users-guide.docx
-->

# IntegrityAnalysis — API User's Guide

*The REST service is the same engine as the interactive app at
<https://integrityanalysis.io>: the same deterministic extraction of a
trial's baseline table from a manuscript, the same Carlisle–Shafer Monte
Carlo, the same privacy contract. It exists so that a manuscript system
can screen a submission automatically during peer review, with no
person operating the app and no document retained.*

## 1. In one paragraph

You POST one document to `/analyze` with a bearer token. The service
finds the baseline table, validates it, runs the Monte Carlo, and
replies with a single JSON object: the overall p-value for the trial,
the per-row p-values as a CSV, the extracted table as a CSV in the app's
own input layout, and the reconstructed journal-style table for
comparison against the manuscript page. If the table could not be fully
read, the reply says why, row by row, and carries the partial table in a
form that is itself valid input to the next call. The uploaded document
is deleted when the reply is written, and the reply says so.

## 2. Access

**Base URL.** The service runs on AWS App Runner; the operator gives
you its base URL (of the form `https://….awsapprunner.com`). All
endpoints are under it directly (`/health`, `/parse`, `/analyze`).

**Token.** Every data endpoint requires a bearer token issued to you by
the operator:

    Authorization: Bearer <your token>

The service stores only a hash of each token. A request without a valid
token is refused with 401 before any handler runs; `/health` is open.

**Opt-in AI assist (optional).** If a document's baseline table cannot
be read deterministically (a scanned page with no text layer), the
service can send the unreadable pages to Anthropic's API *under your own
key*, per request, by adding the header

    X-Anthropic-Key: <your Anthropic API key>

Without that header no document content ever leaves the server. With
it, the pages the deterministic reader could not parse are sent to
Anthropic under your account, for that request only; the key is never
stored or logged. Anthropic's commercial terms apply (no training on the
content; deletion within about 30 days). See [the data-handling
statement](data-handling.md).

## 3. Endpoints

### `GET /health`

Liveness and identity. No token.

```json
{"ok": true, "service": "IntegrityAnalysis", "version": "0.2.0",
 "libxml2": "2.12.10", "commit": "da0d61e7…", "engine": "deterministic (Carlisle-Shafer Monte Carlo)"}
```

| field | meaning |
|---|---|
| `ok` | always `true` when the service answers |
| `service` | `"IntegrityAnalysis"` |
| `version` | the package version |
| `libxml2` | the XML parser version the JATS route runs on |
| `commit` | the git commit the service was built from, or `"unknown"`; compare it with the repository to know what is running |
| `engine` | a fixed description of the method |

### `POST /parse`

Extract the baseline table from one document, without analysing it.
Multipart form with exactly one file field, `file`.

### `POST /analyze`

Extract (if needed), validate, and run the Monte Carlo. Same request as
`/parse`, one file field, `file`, plus one optional form field:

| field | type | meaning |
|---|---|---|
| `seed` | integer, 1 to 2147483647, **on the URL**: `POST /analyze?seed=12345` | a Monte Carlo seed. The same document, seed and service build (`commit` in `/health`) give the same numbers, and the reply echoes it as `seed`. Without it the numbers differ from run to run within the reported Monte Carlo interval, as an unseeded simulation should |

Send the seed as a query parameter, not as a form part. A multipart
text part without a `Content-Type` header (what most HTTP libraries
send) is dropped by the service's multipart parser, and the request is
refused with 422, stage `request`, saying so; a part sent with
`Content-Type: text/plain` does arrive and is accepted. A seed that is
not a whole number in range is refused with 422, stage `request`,
before the document is read.

There is no knob for the number of replications: every trial runs the
same staged scheme as the app (1,000 replicates per row, then 10,000
while the trial's or any row's mid-p is below 0.1, then 100,000 while
the trial's or any row's mid-p is below 0.01), and the `M` column of
the results says what the rows used. The precision of a result is never
reduced to fit a budget; a request too large to run at full precision
is refused instead (section 7).

## 4. What you can send

One file per request, named with its real extension, under the 25 MB
request cap (26,214,400 bytes; section 7):

| kind | extensions | how it is read |
|---|---|---|
| article PDF | `.pdf` | the text layer, deterministically; a scanned page is read by local OCR, or by the AI assist if you sent a key |
| Word manuscript | `.docx` | the document's real tables; captions from the paragraph above |
| **JATS XML article** | `.xml` | the article as PubMed Central, Europe PMC and production systems emit it: real `<tr>/<td>` cells, the cleanest route, and the one intended for editorial systems, which hold the manuscript as XML before any PDF exists |
| spreadsheet | `.csv`, `.xlsx` (`.xls` is refused with 422, stage `parse`: save the workbook as `.xlsx`) | either the app's template layout (section 6) or a journal-style baseline table (variables as rows, arms as columns with "(n = 50)" in the headers) |
| picture of a table | `.jpg`, `.jpeg`, `.png`, `.tif`, `.tiff` | local OCR; every value should be verified |

A zip archive is not accepted by the service (the interactive app
expands zips; the service takes the single file). The document's
extension decides the route; a file whose bytes are not what its name
says is refused with a reason (section 5).

## 5. What you get back

A 200 or 422 reply from `/parse` or `/analyze` is a JSON object with
`ok`, `file` (the name you sent; empty when no file part could be read)
and `deleted` (always `true`: the upload and everything derived from it
were removed when the reply was written). Everything else depends on the
outcome. The refusals under "Other status codes" below (400, 401, 411,
413, 500) carry `ok` and `error` only. Where a reply quotes a reader's
own error message, the server's temporary path has been removed from
it.

### `/parse`, HTTP 200

Captured from a real run (the ticagrelor article PDF, a 36-row table):

```json
{"ok": true, "file": "ticagrelor.pdf", "engine": "heuristic",
 "flags": ["a continuous row is missing its mean or its SD/SE",
           "the table does not say whether its dispersion is an SD or an SE; recorded as SD"],
 "rows": 36, "skipped": [],
 "templateCsv": "\"TRIAL\",\"ROW\",\"N\",\"MEAN\",\"SD\",\"SE\",\"ROUND_MEAN\",… (37 lines)",
 "deleted": true}
```

| field | type | meaning |
|---|---|---|
| `engine` | string | which reader produced the table: `heuristic` (PDF text layer), `heuristic-docx`, `heuristic-jats`, `heuristic-ocr` (a scanned page or a picture, read by OCR — verify every value), `ai` (the opt-in assist), `template` or `wide` (a spreadsheet). Two further values, `heuristic-tatr` and `heuristic-tatr-ocr` (page geometry from the Table Transformer), appear only where the operator has configured that model; the deployed container carries no Python, so the deployed service does not produce them |
| `flags` | array of strings | review notes about the table as a whole: what the reader had to assume (SD versus SE), what it recovered from the Methods text, whether OCR was involved, and which category rows carry **fail-safe counts** (below). Read them; they are the same notes the app shows an editor |
| `rows` | integer | rows in `templateCsv` (one per variable per arm) |
| `skipped` | array of `{label, reason}` | table lines the reader could not use, each with the reason in the app's own words ("median with a min–max range - needs quartiles", "n (%) with unknown arm N", …). These rows are absent from the table; an editor would type them in |
| `templateCsv` | string | the extracted table as CSV in the template layout (section 6). This is valid input to `/analyze` as a `.csv`. The `MEAN`, `SD`, `SE`, `Q1` and `Q3` fields are quoted and carry their printed precision — a mean of 50.0 is `"50.0"`, not `50` — so a caller that POSTs the payload back gets the same analysis. Parse them as decimal strings, not integers |

**Incomplete data: fail-safe counts.** A table that prints only a
percentage for a categorical level gives the count exactly when the arm
has 100 or fewer patients (1,000 at one printed decimal); above that,
several counts fit the printed percentage. The service fills such cells
with the **best case for the authors among the readings scored**: it
enumerates every whole arms-by-levels table the printed percentages
allow — each cell inside its own bracket — ranks them by how unlike they
leave the arms, scores the fifty at each end with the statistic and null
the analysis itself uses, and keeps the one with the largest p. The
ranking is a heuristic: within one null a less-alike reading has the
larger p, but across nulls an independent audit found pages where a
better reading sat further down the list. That is the most favourable
reading of **that row among those scored**; it is not a claim about the trial p,
which combines rows and does not move monotonically with any one of
them. The effect is still large: a two-arm row of 5,000 per arm
printed as counts 2,500 and 2,500 reads p = 0.008, and the same row
printed as "50%" and "50%" reads a far larger one. Every such row is
named in `flags` ("… category row(s) use FAIL-SAFE counts …") on
**both** routes, `/parse` and `/analyze`, and the same rule and colour
apply in the app.

No partition is assumed — except where the service builds the
complement itself, a binary "n (%)" row whose other column *is* the arm
N minus the count. Whether a variable's categories divide the arm
between them is otherwise a statement about what the categories mean,
so a chosen reading may total slightly more or less than the arm's N.

Two further flags may follow. When the best and the worst admissible
readings fall on opposite sides of p = 0.01, the rows are named ("… row(s)
cross p = 0.01 between the best and the worst reading …"): for those the
printed counts decide the answer and the percentages do not, so get the
counts before acting.

When a row allows more readings than can be enumerated — or more than
the service can score within its limits on cells and on the table's
total, or when an arm is larger than the 5,000 the analysis accepts — it
is **not reconstructed at all**. Its cells come back empty, the row is named in
`flags` ("… category row(s) could NOT be read as counts and are left
blank …") with the reason, and the row is not analysed — the trial's
summary reports how many of its rows were. Submit the printed counts to
analyse such a row. The guarantee can only be kept over readings the
service has actually enumerated, so where they cannot all be enumerated
it declines rather than estimating. This is a design decision for incomplete data, not a
reading of the page: if the author supplies the printed counts, resubmit
with them. Cells whose percentage fits exactly one count are converted
exactly and flagged as such.

### `/parse`, HTTP 422 — nothing usable

Captured (a PDF with no table in it):

```json
{"ok": false, "file": "notable.pdf",
 "reasons": "No table caption and no parseable page were found in notable.pdf (3 words of text). Try the `pages` argument.",
 "templateCsv": "\"TRIAL\",\"ROW\",\"N\",\"MEAN\",\"SD\",\"SE\",\"ROUND_MEAN\",\"ROUND_DISPERSION\",\"ROUND_OBSERVATION\"\n",
 "deleted": true}
```

`reasons` is the reader's own message (a string, or an array of them);
`templateCsv` is the empty template — the header row — so the next call
has a valid shape to fill. A refused file (wrong bytes for its name, an
oversized image, a gzip stream named `.xml`, a declared XML entity, a
file over its route's ceiling) arrives here too, with the refusal
named. A sheet over 10,000 rows or 500 columns is not read at all, and
arrives as "could not read … as a template or journal-style table".

A `/parse` refusal carries no `stage` field, with one exception: an
empty file part (a zero-byte file, or a part the multipart parser
dropped) is refused by both endpoints as `{"ok": false, "stage":
"request", "file": "", "reasons": "the uploaded file is empty or its
file part could not be read", …}`, with the empty template.

### `/analyze`, HTTP 200

Captured (the example workbook, two trials):

```json
{"ok": true, "file": "Example.xlsx", "trials": 2, "overallP": 0.9016,
 "resultsCsv": "\"TRIAL\",\"ROW\",\"P\",\"CI95\",\"M\",\"NOTE\",\"KIND\"\n\"Submission 2025-08-01\",\"BUN\",\"0.9215\",\"\",\"1000\",\"\",\"variable\"\n… (19 lines)",
 "journalTables": {"Submission 2025-08-01": "\"Variable\",\"Arm 1 (n = 15)\",\"Arm 2 (n = 17)\"\n\"BUN, mean (SD)\",\"31 (5)\",\"35 (7)\"\n…",
                   "Submission 2025-08-02": "…"},
 "journalTablesOmitted": {},
 "templateCsv": "… (29 lines)",
 "deleted": true}
```

| field | type | meaning |
|---|---|---|
| `trials` | integer | trials in the results (a document is one trial; a spreadsheet may hold several, distinguished by its TRIAL column) — including a trial whose every row was left out, which appears with its rows "Not analysed" and a Summary of "No values" |
| `overallP` | number or string | **the result**: the one-sided p-value toward excessive homogeneity, combined across every row of every trial. Small means the baseline data are more alike across arms than random sampling explains. For one trial it is that trial's exact-combination p, and it arrives as the string `"<0.0001"` when the Monte Carlo licenses that bound. For several trials it is always a number: the closed-form Stouffer combination of the trial p's, a trial's `<0.0001` entering as 0.0001 |
| `resultsCsv` | string | CSV, one line per variable with its row p-value. The `Summary` line's `NOTE` carries `k of n rows analysed; the rest were refused - see their P cells` whenever the engine refused any row of that trial — or the validator left one out: a row with a label and no values (a percentage block the parser could not reconstruct arrives that way) is listed as `Not analysed` with the reason in its `NOTE`, and stays in `templateCsv` and `journalTables` so it can be corrected — so a combined p is never read as covering a table it did not cover — which may be a **refusal in words** rather than a number when the engine could not analyse that row ("Only 1 Row", "Quartiles do not increase (Q3 must exceed Q1)", "The stated precision does not match the printed values", "Printed precision beyond this magnitude's numerical resolution"): the request still succeeds, and a client that parses `P` as a number must expect text — then a summary line per trial with the trial's combined p. Its seven columns are listed in the next table; a script tells the summary line by its `KIND` column, never by the text in `ROW` |
| `journalTables` | object of strings | one CSV per trial, keyed by trial name: the baseline table reconstructed from the extracted numbers in journal layout (variables as rows, arms as columns with "(n = …)" in the headers, "mean (SD)" cells). This is what an editor compares against the manuscript page |
| `journalTablesOmitted` | string or empty | when the reconstructed tables would exceed the service's cell budget they are omitted and this says so; otherwise empty |
| `templateCsv` | string | the table in the template layout, as `/parse` returns it — the analysed rows and any row the validator left out (a label with no values), so a caller can fill the missing cells and POST it back |
| `flags` | array of strings | present only when the reader had to decide something for itself: the same warnings `/parse` returns, including the FAIL-SAFE counts note above and recovered arm sizes. Read them before quoting `overallP`; a p computed from fail-safe counts is conservative for those rows |
| `seed` | integer | present only when the request sent one: the seed the run used |

The columns of `resultsCsv`, with the names the app's results workbook
gives them:

| column | in the workbook | meaning |
|---|---|---|
| `TRIAL` | TRIAL | the trial; printed on a trial's first line only |
| `ROW` | ROW | the variable, as printed in the manuscript; the label `Summary` on the trial's last line. A manuscript may itself have a variable called "Summary", so do not identify the trial's line by this text: use `KIND` |
| `P` | P (one-sided toward homogeneity) | the row's Monte Carlo mid-p, printed as `<0.0001` only when the bound in the next column licenses it. On the `Summary` line, the trial's combined p: the exact combination (the rows' Stouffer sum judged against its own simulated null), floored at 1/(replicates + 1) |
| `CI95` | 95% Monte Carlo interval (blank on a refused row, as `M` is) | the exact Clopper–Pearson 95 % interval of that p from the Monte Carlo's own sampling uncertainty, as `lower to upper` (about the simulation, not the data); on every variable line, and on the `Summary` line when the trial p is below 0.001 |
| `M` | Replicates | the replicates the row actually used (1,000, 10,000 or 100,000; section 3); blank on the `Summary` line |
| `NOTE` | Note | `attainable floor` when the row sits at the smallest p its printed precision allows (the arms printed exactly the same value and no honest replicate agreed better); for a median row, `quartiles beyond the metalog's skew limit; fitted at the limit` when the printed quartiles were more skewed than the model can carry, and `printed quartiles do not separate in k arm(s); the fit uses their printed intervals` when an arm printed Q1 and Q3 as the same number, so its width is known only to be under one printed unit; and `the stated mean precision (k decimals) exceeds the digits these values carry, and the arms are equal at the digits they print, so the p rests on that precision - check it against the page` when a row whose arms print the same mean states more decimals than those means carry — read that one before quoting a small p; and its mirror, `the stated mean precision (k decimals) is coarser than the digits these values carry, which widens the rounding the arms are judged against; this row's p rests on that claim - check it against the page`, when the stated precision is coarser than the digits, which widens the rounding the arms are judged against and moves the p the other way (notes are joined with `; `); else blank. A script should not read such a row as reassurance; whether it is informative depends on how rare exact agreement is at that N and precision, which is what its `P` says (0.27 for integer age at 1,000 per arm is nothing; 0.001 for a two-decimal row is a finding) |
| `KIND` | (not printed) | what the line is: `variable` for a variable's line, `summary` for the trial's combined p, empty on the blank spacer between trials. Added 2026-09-07 after an audit showed a variable named "Summary" being read as a second trial summary |

Values in the CSVs are sanitised against spreadsheet formula injection:
a cell that would begin with `=`, `+`, `-`, `@`, a tab or a carriage
return is prefixed with an apostrophe, in `resultsCsv` and the journal
tables. `templateCsv` is
verbatim, because it must round-trip.

### `/analyze`, HTTP 422 — read, but not analysable

The round-trip contract: the failure payload is the next call's input.

```json
{"ok": false, "stage": "validation", "file": "…",
 "issues": [{"row": 3, "col": "N", "code": "missing", "note": null}, …],
 "templateCsv": "… the table as read, with the flagged cells to fix …",
 "deleted": true}
```

| field | meaning |
|---|---|
| `stage` | where the request stopped: `"parse"`, `"validation"`, `"too_large"` or `"analysis"` (`"request"` when the request itself was wrong); the full list is in "Stages and codes" below |
| `issues` | array; each has `row` (the row's index in the table, so line `row + 1` of `templateCsv`, whose line 1 is the header; null for a whole-table issue), `col` (the column concerned, or null), `code` (one of the codes listed below) and `note` (or `detail`, for the size limits) explaining it in the app's words, or null when the code and the cell say it all. The commonest is a continuous row with no arm N — `code` `missing` on the `N` cell, as in the example: the service refuses to guess |
| `templateCsv` | the table as read. Fix the flagged cells and POST the CSV back to `/analyze` |

### Stages and codes

`stage` takes one of five values:

| stage | when | body |
|---|---|---|
| `request` | the request itself was wrong: a bad or dropped `seed`, or an empty file part | `reasons`; both endpoints |
| `parse` | the document yielded nothing usable, or was refused (wrong bytes for its name, `.xls`, a sheet over 10,000 rows or 500 columns, an oversized image, …) | `reasons`, as `/parse` gives it — `/analyze` only; a `/parse` refusal carries no `stage` |
| `validation` | the table was read but cannot be analysed as it stands | `issues` |
| `too_large` | the table exceeds a size or compute limit (section 7) | `issues`, one entry with `detail` |
| `analysis` | the Monte Carlo itself failed on a trial | `issues`, one entry, code `error` |

`code` in an `issues` entry takes one of seven values:

| code | meaning |
|---|---|
| `missing` | a required cell is blank: an arm N, a mean or an SD; a quartile of a median row; the `ROW` cell of a categorical line with no matching line in another arm |
| `unreadable` | the cell holds something that is not a number |
| `incongruent` | the cell is a number that cannot be right where it sits: a negative count, SD or SE; an N that is not a whole number of at least 2; a median outside its quartiles; a count with a fraction; a continuous value on a categorical line, or a dispersion where the table gives none; a magnitude no measurement reaches. A row whose magnitude and printed precision together ask for more than the 15 significant digits a double carries passes validation but is refused by the engine, and its `P` cell says so |
| `too_large` | an N or a count over the arm ceiling (section 7); as the only entry, with `detail`, when the whole table exceeds a limit |
| `too_much_compute` | the table is within every size limit but the simulation it asks for is not; `detail` carries the arithmetic and the advice |
| `error` | the validator (stage `validation`) or the analysis (stage `analysis`) failed in a way the service did not foresee; `note` names the trial and the failure, never the document's content |
| `structural` | the table as a whole cannot be analysed: a required column (`ROW`, `N`, `MEAN`, `SD`) is absent, or two columns normalise to the same name (`Number` and `N`, say; the service refuses to guess which is meant). `row` is null — there is no cell — `col` names the column concerned, and `note` says what to change |

A structural failure arrives as stage `validation` with one `structural`
entry per problem and the table as read in `templateCsv`. The per-cell
checks do not run on a table whose columns are wrong, so the only cell
codes that can accompany it are the two found before them: an arm over
the ceiling (`too_large`) and a blank `TRIAL` cell (`missing`).

### Other status codes

| status | body | meaning |
|---|---|---|
| 400 | `{"ok": false, "error": "…"}` | a malformed request: a NUL byte (`%00`) in the query string, or a file part the multipart body could not carry (a quote or line break in the file name) |
| 401 | `{"ok": [false], "error": ["…"]}` | missing or invalid bearer token |
| 411 | `{"ok": [false], "error": ["…"]}` | no `Content-Length` header (a chunked upload). Chunked uploads are not accepted: the request is refused as 411 or as 413 (the service's native request cap may answer first), either way before any of the body is read |
| 413 | `{"ok": [false], "error": ["…"]}` | the request exceeds the 25 MB limit. Refused from the `Content-Length` header before any of the body is read, and before authentication — so an oversized request gets 413 rather than 401 even without a token |
| 500 | `{"ok": false, "error": "Internal error processing the request."}` | an unexpected failure. The body is this fixed text and carries nothing of the document; the service logs the error on its own side |

The 401, 411 and 413 refusals are produced by the request filters, whose JSON is not unboxed: each value is a one-element array, as shown, where the endpoint replies use bare values. A client that reads `ok` or `error` should accept both forms.

## 6. The template layout

`templateCsv` is the app's own input format, one line per variable per
arm:

| column | meaning |
|---|---|
| `TRIAL` | the trial the line belongs to: the file name without its extension, unless a spreadsheet carries its own `TRIAL` column (any case, like every column name) or trial identifiers |
| `ROW` | the variable, as printed |
| `N` | that arm's size for the variable |
| `MEAN`, `SD`, `SE` | the printed mean and its dispersion (SD, or SE when the table says so) |
| `Q1`, `Q3` | the quartiles of a median row (present when the table labels its interval an IQR) |
| `ROUND_MEAN`, `ROUND_DISPERSION`, `ROUND_OBSERVATION` | the decimals the mean and dispersion were printed to, and the precision of the underlying measurement: the Monte Carlo rounds its simulated data exactly this way, which is the method's answer to the rounding problem |
| further columns | one per category level for categorical rows (`MALE`, `NOT MALE`, …), holding counts; a binary "n (%)" row is expanded into the count and its complement |

A file in this layout, saved as `.csv`, is valid input to either
endpoint; so is the app's own "Editor's View" download.

**The long layout is accepted as input too.** A
categorical variable may be sent one line per category level per arm: a
`LEVEL` column (alias `CATEGORY`) names the level, `N` holds its count,
`MEAN` and `SD` are blank, and the lines sharing `ROW` and `LEVEL` are
the arms, in order. Both layouts may appear in one file. The service
converts on receipt and its replies (`templateCsv`, `journalTables`)
carry the wide layout, so a script that reads replies sees one layout
whichever it sent.

## 7. Limits

| what | limit | on breach |
|---|---|---|
| request size | 25 MB (26,214,400 bytes), `Content-Length` required | 413; a request with no `Content-Length` gets 411 or 413 |
| JATS XML | 8 MiB on disk; UTF-8 text beginning with `<` (no NUL bytes, so no UTF-16); not a gzip stream; no `<!ENTITY` declaration (no real JATS article needs one); a table over 20,000 cells is skipped, and at most 100,000 cells and 20,000 body paragraphs are read per document | 422 with the reason |
| picture of a table | 20 megapixels; up to 10 TIFF pages; JPEG, PNG or TIFF by its bytes, not its name | 422 with the reason |
| spreadsheet archives (`.xlsx`) | 100 MiB uncompressed, 512 entries, compression ratio 200 | 422 |
| spreadsheet sheet | 10,000 rows, 500 columns, judged before the table limits below | 422 (`stage: "parse"` from `/analyze`) |
| parse time | 60 s per document (300 s with the AI assist) | 422 (`stage: "parse"` from `/analyze`) |
| table | 5,000 rows, 200 columns, 200 trials, arm N up to 5,000 | 422, `stage: "too_large"` from `/analyze`; `/parse` refuses the rows and columns limits too, with the reason, so `templateCsv` never carries a table the service would not analyse |
| journal-style table | what the wide reader would BUILD from it: at most 200 category columns (one per count level and its complement, counted across every trial block of the file) and 5,000 template lines (one per variable per arm) - the same 200 columns and 5,000 rows as above, judged before a line is built (a sheet with more rows past its header than the file has lines left is refused before it is read) | 422 with the reason (`stage: "parse"` from `/analyze`); the file is not read again as a template |
| compute | 12 billion simulated values per request (the worst case of every row escalating to 100,000 replicates, times the subjects each row draws); precision is never reduced to fit | 422, `stage: "too_large"`, code `too_much_compute`, with the arithmetic and the advice (one trial per request; or the web app, which has no request timeout) in `detail` |
| rows sharing one null law | 10,000,000 held draws at the final stage for the rows of a trial whose simulated null is the same distribution as another row's (identical inputs, or the same category margins) — a hundred such rows at 100,000 replicates; a table of that shape is not a baseline table | 422, `stage: "analysis"`, code `error`, the reason in `note` — refused before a draw is made |
| journal tables | 200,000 cells across the reply | omitted, with `journalTablesOmitted` set |
| `flags` | 50 entries, each 2 KiB | truncated, with `...N further flag(s) truncated` as the last entry and ` ...truncated` ending a cut string |
| `skipped` (`/parse`) | 200 entries, each field 2 KiB | truncated, with a final entry whose `label` reads `...N further line(s) omitted` |

The service handles one request at a time per worker; a pathological
document costs at most its timeout.

## 8. Retention

The document is written to a directory created for the request and
removed when the reply is written, on success and on failure alike;
nothing is logged of its content; there is no store of submissions.
Every reply carries `"deleted": true` to say so. The full statement is
[the data-handling document](data-handling.md), published beside the
user guide.

## 9. Examples

Both scripts live in the repository under `tools/` and were run against
a real service before this guide was written; each prints the reply's
fields and saves its CSVs beside the input file.

### R (httr2)

```r
library(httr2)
base  <- "https://<service>"                 # from the operator
token <- Sys.getenv("INTEGRITY_API_TOKEN")

# health, open
request(paste0(base, "/health")) |> req_perform() |> resp_body_json()

# analyze one document, seeded so a rerun reproduces the numbers
r <- request(paste0(base, "/analyze?seed=12345")) |>
  req_headers(Authorization = paste("Bearer", token)) |>
  req_body_multipart(file = curl::form_file("article.pdf")) |>
  req_timeout(900) |>
  req_error(is_error = function(resp) FALSE) |>     # read 422 bodies too
  req_perform()
resp_status(r)                                     # 200, or 422 with reasons
b <- resp_body_json(r)
b$overallP                                         # the trial's p
writeLines(b$resultsCsv,  "article-results.csv")   # per-row p-values
writeLines(b$templateCsv, "article-template.csv")  # the table as read
for (nm in names(b$journalTables))                 # the journal-style table
  writeLines(b$journalTables[[nm]], paste0("article-journal-", nm, ".csv"))
```

The full client, with health, parse and analyze as commands:

    Rscript tools/apiClient.R analyze https://<service> article.pdf --seed 12345

### Python (standard library only)

```python
import json, os, urllib.request, uuid

base, token = "https://<service>", os.environ["INTEGRITY_API_TOKEN"]

def post_file(endpoint, path):
    boundary = "----IA" + uuid.uuid4().hex
    body = ("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n"
             "Content-Type: application/octet-stream\r\n\r\n" % (boundary, os.path.basename(path))).encode()
    body += open(path, "rb").read() + ("\r\n--%s--\r\n" % boundary).encode()
    req = urllib.request.Request(base + endpoint, data=body, method="POST",
        headers={"Authorization": "Bearer " + token,
                 "Content-Type": "multipart/form-data; boundary=" + boundary,
                 "Content-Length": str(len(body))})
    try:
        with urllib.request.urlopen(req, timeout=900) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:            # 422 carries a JSON body too
        return e.code, json.loads(e.read())

status, b = post_file("/analyze", "article.pdf")
print(status, b.get("overallP"), b.get("reasons"))
# utf-8 explicitly: row labels are printed as the manuscript printed
# them, and on Windows the default encoding cannot write some of them
open("article-results.csv", "w", newline="", encoding="utf-8").write(b.get("resultsCsv", ""))
```

The full client:

    python tools/apiClient.py analyze https://<service> article.pdf --seed 12345

### What a run looks like

The R client against a local service, 2026-09-03 (the ticagrelor
article PDF and the example workbook):

    parse ticagrelor.pdf: HTTP 200 in 3.2 s
      ok=TRUE  deleted=TRUE  engine=heuristic
      flags: a continuous row is missing its mean or its SD/SE; the table does not say
             whether its dispersion is an SD or an SE; recorded as SD
      rows: 36
      wrote ticagrelor-template.csv (36 rows)

    analyze Example.xlsx: HTTP 200 in 0.5 s
      ok=TRUE  deleted=TRUE
      trials: 2
      overall p: 0.9016
      wrote Example-template.csv (28 rows)
      wrote Example-results.csv (18 rows)
      wrote Example-journal-Submission_2025-08-01.csv (13 rows)
      wrote Example-journal-Submission_2025-08-02.csv (6 rows)

    parse notable.pdf: HTTP 422 in 2.3 s
      ok=FALSE  deleted=TRUE
      reasons: No table caption and no parseable page were found in notable.pdf (3 words of text).

## 10. Reading a result

`overallP` is a screening signal, not an allegation: it says how
surprising the agreement between the arms' baseline data is under
honest randomization. The user guide's section "What to do with a
flag" is written for the editor who receives one. Two things a script
should do with every reply: read `flags`, which both routes return, and
on `/parse` also `skipped`, because they say what the reader assumed and
what it could not use (`/analyze` returns the flags but not the list of
unusable lines; use `/parse` when you want that list); and keep
`journalTables`, because comparing the reconstructed table against the
manuscript page is the check that catches an extraction error before
it becomes a number in an email.
