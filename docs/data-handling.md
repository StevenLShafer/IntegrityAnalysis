<!--
  data-handling.md - the data-handling statement for IntegrityAnalysis,
  written for editors, publishers, and their security/legal reviewers.

  PROVENANCE: drafted 2026-08-26 by Claude (Claude Code; model Claude
  Fable 5) at Steve Shafer's request, from the app and service as built.
  It describes CURRENT behavior; if a data path changes, this file
  changes in the same commit. Published to
  https://integrityanalysis.io/data-handling.html by the pages workflow.

  TO REGENERATE THE SERVED HTML after editing:
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
nothing afterward**. The default analysis is deterministic and runs
entirely on the server that receives it — no document content is sent
anywhere else. A single, opt-in exception exists: if a user enters
their own **Anthropic** API key, the pages a document's own text cannot
be read from are sent to the Anthropic API under the user's account,
for that session only. Anthropic is the only AI service this software
can call. Under Anthropic's commercial terms, nothing submitted that
way is used to train a model, and it is deleted within about 30 days.

## What is processed, and what is not

**Processed (transiently):** the uploaded file (PDF, Word manuscript,
spreadsheet, or picture of a table), the baseline table extracted from
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
  and no log that records document content.

## No training on your content

The deterministic engine — the default, and the whole of what runs
unless a user deliberately turns on the AI assist — makes no external
network call at all. Nothing to train on ever leaves the server.

When a user opts into the AI assist by entering their own **Anthropic**
API key, the text (or, for a scanned page, the image) of the pages the
deterministic reader could not parse is sent to the Anthropic API under
the **user's own account**. Anthropic is the only AI service this
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
  and **only** the specific pages the deterministic reader could not
  handle. Absent a key, no third party receives any content.

All traffic to the app and the API is over HTTPS.

## Transport and access

Uploads travel over HTTPS. Within the service, an uploaded document is
read only by the analysis process, in its own isolated working
directory; document-parsing of untrusted files runs in short-lived
subprocesses with enforced time and size limits, so a malformed or
hostile file cannot persist or reach other requests. The API requires a
bearer token issued by the operator; the operator's registry stores
only irreversible hashes of those tokens, never the tokens themselves.

## Usage measurement

The interactive app counts two numbers only: how many times it is
opened and how many analyses are run. These are simple counts. No IP
address, no document content, and no per-submission identifier reaches
the counter — the count is sent by the server, not by the browser.

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
