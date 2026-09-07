<!--
  data-handling.md - the data-handling statement for IntegrityAnalysis,
  written for editors, publishers, and their security/legal reviewers.

  PROVENANCE: drafted 2026-08-26 by Claude (Claude Code; model Claude
  Fable 5) at Steve Shafer's request, from the app and service as built.
  It describes CURRENT behavior; if a data path changes, this file
  changes in the same commit. This Markdown, in the public repository,
  is the published copy. The pages workflow (.github/workflows/pages.yaml)
  serves only site/ and the user guide at integrityanalysis.io; the
  rendered inst/extdata/data-handling.html ships inside the package and
  is not (yet) served at any URL.

  TO REGENERATE THE HTML after editing:
    "C:\Program Files\Quarto\bin\tools\pandoc.exe" docs/data-handling.md
      -s --embed-resources --toc --metadata title="IntegrityAnalysis - Data Handling"
      -c docs/user-guide.css -o inst/extdata/data-handling.html
-->

# IntegrityAnalysis — Data Handling

*For editors and publishers evaluating the service, and for the
security and legal reviewers they may consult. This statement describes
how IntegrityAnalysis handles the documents and data you submit. It
reflects the software as built; the source is open at
<https://github.com/StevenLShafer/IntegrityAnalysis> and every claim
below can be checked against it.*

## In one paragraph

IntegrityAnalysis processes an uploaded manuscript or table **in
memory, for the length of one session or one API request, and retains
nothing afterward**. The extraction is deterministic and the analysis
is a Monte Carlo simulation (reproducible with a seed); both run
entirely on the server that receives the upload — no document content
is sent anywhere else. A single, opt-in exception exists: if a user enters
their own **Anthropic** API key, then for a document the deterministic
reader could not fully read, the page its baseline table sits on — as
text, or as a rendered image when the page is a scan — is sent to the
Anthropic API under the user's account, and if no table can be read
there, the article's text (up to 60,000 characters) follows; this
applies for that session or request only. Anthropic is the only AI
service this software can call. Under Anthropic's commercial terms,
nothing submitted that way is used to train a model, and it is deleted
within about 30 days.

## What is processed, and what is not

**Processed (transiently):** the uploaded file (PDF, Word manuscript,
JATS XML article, spreadsheet, or picture of a table - whether picked,
dropped on the page or pasted from the clipboard - or a zip archive of
those, which
the app expands into its entries, each then handled exactly as a
single upload and discarded with it), the baseline table extracted from
it, any values a
user types into the on-screen grid, and the analysis results.

**Not collected:** account identities, IP addresses tied to content,
cookies for tracking, or any persistent identifier for a submission. A
manuscript is never associated with a stored record, because no record
is stored.

## Retention: none

- **The interactive app** deletes every uploaded file from disk when
  the browser session ends, and the in-memory data (the table, the
  results, the log) dies with the session. Downloads are generated
  straight into your browser; nothing is written to a lasting store.
- **The REST API** writes each upload into a working directory created
  for that one request and deletes the directory when the request
  finishes — on success and on failure alike. Each response includes a
  `"deleted": true` field confirming it.
- There is no database of submissions, no backup of uploaded content,
  and no log that records document content by design. One qualification:
  when an API request fails, the service's internal error log records
  the R error message (the caller receives a fixed, contentless
  response). Such a message can quote a fragment of the failing input —
  a column name, a malformed cell. That log is the hosting platform's
  process log, not a store IntegrityAnalysis keeps, and it never
  contains a document.

## No training on your content

The deterministic engine — the default, and the whole of what runs
unless a user deliberately turns on the AI assist — makes no external
network call at all. Nothing to train on ever leaves the server.

When a user opts into the AI assist by entering their own **Anthropic**
API key, and only for a document the deterministic reader could not
fully read, this is what is sent to the Anthropic API under the
**user's own account**:

- **The page the baseline table sits on**, located by its caption the
  same way the deterministic reader locates it. The page's text is sent
  when it has a text layer — even though that text was readable, it is
  the table on it that could not be extracted. When the document has
  scanned or image-only pages, up to four of those pages are sent as
  rendered images instead; a fully scanned document is first searched
  locally to find the table page, and that page is sent as an image. A
  picture of a table uploaded as a file is sent as that picture (jpg or
  png; a tif is read locally only).
- **The article's text, up to 60,000 characters**, if no table could be
  read from that page — some trials state their baseline data in a
  sentence of the Methods rather than a table, and this second request
  asks for those. (A Word manuscript or a JATS XML article never takes
  either route; those formats are read deterministically only.)

Where the deterministic reader has read part of the table, the model is
also told which arms and variables were already read, so that it fills
gaps rather than re-reading the page; its lines are marked as AI-read
in the grid, and a value found deterministically is never overwritten.
In the interactive app the assist stops after 25 documents in one
session (the default of `INTEGRITY_AI_SESSION_CAP`) and the rest of the
upload is read deterministically. Anthropic is the only AI service this
software is built to call: the key field validates against Anthropic's
API and the client speaks only that API, so a key from another provider
would simply be rejected.

Anthropic's Commercial Terms of Service state that Anthropic may not
train its models on customer content submitted through the API, and
API inputs and outputs are
[deleted from Anthropic's systems within about 30 days](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
(longer only where a legal requirement or a trust-and-safety flag
applies). A submission sent this way therefore never enters any future
model and is not retained beyond that window. The user's key itself is
never stored, never logged, never placed in a URL, and does not persist
beyond the session or request.

*These guarantees were verified against Anthropic's published terms and
apply to Anthropic only. If a future version of this software were to
support another AI service, that service's terms would have to be
verified separately and this statement updated — do not read the
paragraph above as covering any provider other than Anthropic.*

## Where the service runs, and who else touches data

- **The interactive app** runs on shinyapps.io (operated by Posit),
  which hosts the R process and terminates HTTPS. Posit is a hosting
  sub-processor; it does not receive document content as a separate
  data feed — the content lives only inside the running app process and
  is purged as described above.
- **The REST API** runs on AWS App Runner in the US East (N. Virginia)
  region, in a container built from the open source. AWS is a hosting
  sub-processor on the same terms.
- **Anthropic** — the only AI service this software can call — receives
  content **only** when a user has entered their own Anthropic API key,
  and **only** for a document the deterministic reader could not fully
  read: the table's page, and if that fails, up to 60,000 characters of
  the article's text, as described above. Absent a key, no third party
  receives any content.

All traffic to the app and the API is over HTTPS.

## Transport and access

Uploads travel over HTTPS. Within the service, an uploaded document is
read only by the analysis process, in its own isolated working
directory; document-parsing of untrusted files runs in short-lived
subprocesses with enforced time and size limits, so a malformed or
hostile file cannot persist or reach other requests. The API requires a
bearer token issued by the operator. In the deployed configuration the
operator's registry and the service's environment carry only
irreversible SHA-256 hashes of those tokens, never the tokens themselves
(the software also accepts a plain-text token in its environment, a
convenience for local testing that the deployment does not use).

## Usage measurement

The interactive app counts two numbers only: how many times it is
opened and how many analyses are run. These are simple counts, sent to
a GoatCounter site operated by Steve Shafer (`R/usageCount.R`; the
payload is one event name, "session" or "analyze"). No IP address, no
document content, and no per-submission identifier reaches the counter
— the count is sent by the server process, not by the browser, so the
counter sees only the hosting service's address. Counting is on only
in the production deployment; the API does not count.

## What IntegrityAnalysis is not

It is not a repository, a manuscript-tracking system, or a data
controller that keeps records about submissions. It is an ephemeral
analysis tool: content in, result out, nothing kept. A flag it produces
is a **screening signal, never an allegation** — how a flag should be
acted on is described in the user guide.

## Questions

Data-handling questions may be directed to Steve Shafer
(<steven.shafer@stanford.edu>). Because the service keeps no record of
submissions, requests to access or delete a past submission cannot be
fulfilled for the simple reason that nothing was retained to access or
delete.
