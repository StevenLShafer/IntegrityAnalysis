# IntegrityAnalysis API — specification (retired)

This file was the August 2026 design document for the REST service
(drafted 2026-08-17, before any of it was built). It is kept only so
that links to it resolve. The reference for the service as it runs is
[the API User's Guide](api-users-guide.md); everything below is where the
built service departs from the design.

- The endpoints are bare paths — `/health`, `/parse` and `/analyze` — with no `/v1` prefix and no `/spec` endpoint.
- There is no caller-chosen replicate count: every trial runs the app's fixed staged scheme of 1,000, 10,000 and 100,000 replicates.
- There is no `format` field; every reply is JSON.
- The request cap is 25 MB (26,214,400 bytes), not 50 MB.
- A reply carries `ok`, `overallP`, `resultsCsv`, `templateCsv`, `journalTables` and `deleted`, not `status` and `retention` objects.
- `.xls` is refused; a spreadsheet is `.csv` or `.xlsx`.
