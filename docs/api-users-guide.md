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
  service as built; docs/api-spec.md is the design document this
  describes the implementation of.

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
content; deletion within about 30 days). See the data-handling
statement.

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
`/parse`: one file field, `file`, and nothing else. There is no knob for
the number of replications: every row runs the same staged scheme as
the app (1,000, then 10,000, then 100,000 replicates, escalating only
while the row still alarms), and the `M` column of the results says
what each row used. The precision of a result is never reduced to fit a
budget; a request too large to run at full precision is refused instead
(section 7).

## 4. What you can send

One file per request, named with its real extension, under 25 MiB:

| kind | extensions | how it is read |
|---|---|---|
| article PDF | `.pdf` | the text layer, deterministically; a scanned page is read by local OCR, or by the AI assist if you sent a key |
| Word manuscript | `.docx` | the document's real tables; captions from the paragraph above |
| **JATS XML article** | `.xml` | the article as PubMed Central, Europe PMC and production systems emit it: real `<tr>/<td>` cells, the cleanest route, and the one intended for editorial systems, which hold the manuscript as XML before any PDF exists |
| spreadsheet | `.csv`, `.xls`, `.xlsx` | either the app's template layout (section 6) or a journal-style baseline table (variables as rows, arms as columns with "(n = 50)" in the headers) |
| picture of a table | `.jpg`, `.jpeg`, `.png`, `.tif`, `.tiff` | local OCR; every value should be verified |

A zip archive is not accepted by the service (the interactive app
expands zips; the service takes the single file). The document's
extension decides the route; a file whose bytes are not what its name
says is refused with a reason (section 5).

## 5. What you get back

Every reply is a JSON object with `ok`, `file` (the name you sent) and
`deleted` (always `true`: the upload and everything derived from it were
removed when the reply was written). Everything else depends on the
outcome.

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
| `engine` | string | which reader produced the table: `heuristic` (PDF text layer), `heuristic-docx`, `heuristic-jats`, `heuristic-ocr` (a scanned page or a picture, read by OCR — verify every value), `heuristic-tatr` / `heuristic-tatr-ocr` (table geometry from the Table Transformer, where the operator runs it), `ai` (the opt-in assist), `template` or `wide` (a spreadsheet) |
| `flags` | array of strings | review notes about the table as a whole: what the reader had to assume (SD versus SE), what it recovered from the Methods text, whether OCR was involved. Read them; they are the same notes the app shows an editor |
| `rows` | integer | rows in `templateCsv` (one per variable per arm) |
| `skipped` | array of `{label, reason}` | table lines the reader could not use, each with the reason in the app's own words ("median with a min–max range - needs quartiles", "n (%) with unknown arm N", …). These rows are absent from the table; an editor would type them in |
| `templateCsv` | string | the extracted table as CSV in the template layout (section 6). This is valid input to `/analyze` as a `.csv` |

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
file over its route's ceiling) arrives here too, with the refusal named.

### `/analyze`, HTTP 200

Captured (the example workbook, two trials):

```json
{"ok": true, "file": "Example.xlsx", "trials": 2, "overallP": 0.9016,
 "resultsCsv": "\"TRIAL\",\"ROW\",\"P\",\"CI95\",\"M\"\n\"Submission 2025-08-01\",\"BUN\",\"0.9215\",\"\",\"1000\"\n… (19 lines)",
 "journalTables": {"Submission 2025-08-01": "\"Variable\",\"Arm 1 (n = 15)\",\"Arm 2 (n = 17)\"\n\"BUN, mean (SD)\",\"31 (5)\",\"35 (7)\"\n…",
                   "Submission 2025-08-02": "…"},
 "journalTablesOmitted": {},
 "templateCsv": "… (29 lines)",
 "deleted": true}
```

| field | type | meaning |
|---|---|---|
| `trials` | integer | trials analysed (a document is one trial; a spreadsheet may hold several, distinguished by its TRIAL column) |
| `overallP` | number or string | **the result**: the one-sided p-value toward excessive homogeneity, combined across every row of every trial. Small means the baseline data are more alike across arms than random sampling explains. For one trial it is that trial's exact-combination p; for several it is the closed-form Stouffer combination of the trial p's. It arrives as the string `"<0.0001"` when the Monte Carlo licenses that claim |
| `resultsCsv` | string | CSV with columns `TRIAL`, `ROW`, `P`, `CI95`, `M`: one line per variable with its row p-value, then a `Summary` line per trial with the trial's combined p. `P` is the Monte Carlo mid-p, printed as `<0.0001` only when the bound in the next column licenses it. `CI95` is the exact Clopper–Pearson 95 % interval of that p from the Monte Carlo's own sampling uncertainty, on every row, as `lower to upper` (about the simulation, not the data). `M` is the replicates the row actually used (1,000, 10,000 or 100,000; section 3). `TRIAL` is printed on a trial's first line only, and the `Summary` line carries the trial's combined p (the exact combination: the rows' Stouffer sum judged against its own simulated null, floored at one over the replicate count) and, below 0.001, its exact 95 % Monte Carlo interval |
| `journalTables` | object of strings | one CSV per trial, keyed by trial name: the baseline table reconstructed from the extracted numbers in journal layout (variables as rows, arms as columns with "(n = …)" in the headers, "mean (SD)" cells). This is what an editor compares against the manuscript page |
| `journalTablesOmitted` | string or empty | when the reconstructed tables would exceed the service's cell budget they are omitted and this says so; otherwise empty |
| `templateCsv` | string | the analysed table in the template layout, as `/parse` returns it |

Values in the CSVs are sanitised against spreadsheet formula injection:
a cell that would begin with `=`, `+`, `-` or `@` is prefixed with an
apostrophe, in `resultsCsv` and the journal tables. `templateCsv` is
verbatim, because it must round-trip.

### `/analyze`, HTTP 422 — read, but not analysable

The round-trip contract: the failure payload is the next call's input.

```json
{"ok": false, "stage": "validation", "file": "…",
 "issues": [{"row": 3, "col": "N", "code": "…", "note": "no arm N printed for 'Weight'"}, …],
 "templateCsv": "… the table as read, with the flagged cells to fix …",
 "deleted": true}
```

| field | meaning |
|---|---|
| `stage` | `"parse"` (the document yielded nothing usable; `reasons` is set as for `/parse`), `"validation"` (the table was read but a row cannot be analysed as it stands), or `"too_large"` (the table exceeds the service's size or compute limits, section 7) |
| `issues` | array; each has `row` (1-based line of `templateCsv`, or null for a whole-table issue), `col` (the column concerned, or null), `code` (a short machine code) and `note` (or `detail`, for the size limits) explaining it in the app's words. The commonest is a continuous row with no arm N: the service refuses to guess |
| `templateCsv` | the table as read. Fix the flagged cells and POST the CSV back to `/analyze` |

### Other status codes

| status | body | meaning |
|---|---|---|
| 401 | `{"ok": [false], "error": ["…"]}` | missing or invalid bearer token |
| 411 | `{"ok": [false], "error": ["…"]}` | no `Content-Length` header; chunked uploads are not accepted |
| 413 | `{"ok": [false], "error": ["…"]}` | the request exceeds 25 MiB |
| 500 | `{"ok": false, "error": "internal", "id": "…"}` | an unexpected failure; the body carries a request id for support and nothing of the document |

The three refusals above are produced by the request filters, whose JSON is boxed: each value arrives as a one-element array, as shown, where the endpoint replies use bare values. A client that reads `ok` should accept both forms.

## 6. The template layout

`templateCsv` is the app's own input format, one line per variable per
arm:

| column | meaning |
|---|---|
| `TRIAL` | the trial the line belongs to (the file name, unless the document carries trial identifiers) |
| `ROW` | the variable, as printed |
| `N` | that arm's size for the variable |
| `MEAN`, `SD`, `SE` | the printed mean and its dispersion (SD, or SE when the table says so) |
| `Q1`, `Q3` | the quartiles of a median row (present when the table labels its interval an IQR) |
| `ROUND_MEAN`, `ROUND_DISPERSION`, `ROUND_OBSERVATION` | the decimals the mean and dispersion were printed to, and the precision of the underlying measurement: the Monte Carlo rounds its simulated data exactly this way, which is the method's answer to the rounding problem |
| further columns | one per category level for categorical rows (`MALE`, `NOT MALE`, …), holding counts; a binary "n (%)" row is expanded into the count and its complement |

A file in this layout, saved as `.csv`, is valid input to either
endpoint; so is the app's own "Editor's View" download.

## 7. Limits

| what | limit | on breach |
|---|---|---|
| request size | 25 MiB, `Content-Length` required | 413 / 411 |
| JATS XML | 8 MiB on disk; UTF-8 text beginning with `<` (no NUL bytes, so no UTF-16); not a gzip stream; no `<!ENTITY` declaration (no real JATS article needs one); a table over 20,000 cells is skipped, and at most 100,000 cells and 20,000 body paragraphs are read per document | 422 with the reason |
| picture of a table | 20 megapixels; up to 10 TIFF pages; JPEG, PNG or TIFF by its bytes, not its name | 422 with the reason |
| spreadsheet archives (`.xlsx`) | 100 MiB uncompressed, 512 entries, compression ratio 200 | 422 |
| parse time | 60 s per document (300 s with the AI assist) | 422, `stage: "parse"` |
| table | 5,000 rows, 200 columns, 200 trials, arm N up to 5,000 | 422, `stage: "too_large"` |
| compute | 12 billion simulated values per request (the worst case of every row escalating to 100,000 replicates, times the subjects each row draws); precision is never reduced to fit | 422, `stage: "too_large"`, code `too_much_compute`, with the arithmetic and the advice (one trial per request; or the web app, which has no request timeout) in `detail` |
| journal tables | 200,000 cells across the reply | omitted, with `journalTablesOmitted` set |

The service handles one request at a time per worker; a pathological
document costs at most its timeout.

## 8. Retention

The document is written to a directory created for the request and
removed when the reply is written, on success and on failure alike;
nothing is logged of its content; there is no store of submissions.
Every reply carries `"deleted": true` to say so. The full statement is
the data-handling document published beside the user guide.

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

# analyze one document
r <- request(paste0(base, "/analyze")) |>
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

    Rscript tools/apiClient.R analyze https://<service> article.pdf

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

    python tools/apiClient.py analyze https://<service> article.pdf

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
should do with every reply: read `flags` and `skipped`, because they
say what the reader assumed and what it could not use; and keep
`journalTables`, because comparing the reconstructed table against the
manuscript page is the check that catches an extraction error before
it becomes a number in an email.
