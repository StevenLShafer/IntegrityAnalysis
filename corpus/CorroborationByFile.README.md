# CorroborationByFile.csv

Per-file output of `corpus/measureMisparse.R`: for every corpus PDF that
maps to a Carlisle trial, how many of our extracted (MEAN, SD) pairs his
hand-entered data corroborates.

Committed here — not in `.NewCarlisle/`, which is gitignored because it
holds copyrighted PDFs — so the corroboration figure quoted beside the
parse rate is inspectable. The file carries only PDF basenames, PMIDs
and counts; no article content.

**Generated 2026-08-29** from a snapshot library built by
`R CMD INSTALL --library=<dir> .` at commit `9e85d0a`, version 0.2.0.

The previous version of this measurement is kept at
`.NewCarlisle/misparse/contaminated-2026-08-26/` (local only). It used
`pkgload::load_all()` on the live tree and a stale 0.1.0 build, and its
numbers flattered: 44.4% fully corroborated against 42.8% clean, and
10.5% zero-corroboration against 13.5%.

## The numbers

| | |
|---|---|
| files scored | 1,110 |
| parsed | 988 |
| extracted no pairs at all | 101 (excluded — nothing to corroborate) |
| **fully corroborated** | **380 of 887 (42.8%)** |
| with at least one uncorroborated pair | 507 (57.2%) |

Quote 42.8% beside the 84.9% parse rate, never alone. A parse rate
counts tables that came out; this counts tables that were right.
