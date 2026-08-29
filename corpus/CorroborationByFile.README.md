# CorroborationByFile.csv

Per-file output of `corpus/measureMisparse.R`: for every corpus PDF that
maps to a Carlisle trial, how many of our extracted (MEAN, SD) pairs his
hand-entered data corroborates.

Committed here — not in `.NewCarlisle/`, which is gitignored because it
holds copyrighted PDFs — so the corroboration figure quoted beside the
parse rate is inspectable. The file carries only PDF basenames, PMIDs
and counts; no article content.

**Generated 2026-08-30** on the Linux compute node `surface`, from a
snapshot library built by `R CMD INSTALL --library=<dir> .` at commit
`c202d55`, version 0.2.0, with 10 parallel workers.

## The numbers

| | |
|---|---|
| files scored | 1,110 |
| parsed | 1,047 |
| extracted no pairs at all | 81 (excluded — nothing to corroborate) |
| **fully corroborated** | **433 of 966 (44.8%)** |
| with at least one uncorroborated pair | 533 (55.2%) |
| our (MEAN, SD) pairs | 13,216 |
| corroborated pairs | 7,500 (56.7%) |
| uncorroborated pairs — upper bound on misparse | 5,716 (43.3%) |
| his pairs we missed | 4,575 (38.0% of his) |

Quote 44.8% beside the parse rate, never alone. A parse rate counts
tables that came out; this counts tables that were right.

## Provenance — and why the earlier 42.8% is superseded

This measurement has been wrong twice, in the same way, for two
different reasons. Both are recorded here because the number is quoted
in public and its chain of custody is part of the claim.

**2026-08-26 — discarded.** Used `pkgload::load_all()` on the live tree
plus a stale 0.1.0 build. Reported 44.4% fully corroborated and 10.5%
zero-corroboration.

**2026-08-29 — also unsound, discovered 2026-08-30.** Reported 42.8%.
It was run with an explicit snapshot library and *looked* clean: the
script printed `engine: version 0.2.0` and that was true — **of the
parent process only.**

`measureMisparse.R` does not parse PDFs itself. It calls
`parseBaselineTableFiles()`, which runs one subprocess per PDF and hands
each child the parent's `.libPaths()`. The parent had loaded the engine
with `library(IntegrityAnalysis, lib.loc = snapshotDir)` — and
`lib.loc` **does not add that directory to `.libPaths()`**. So the
children inherited a library path that did not contain the snapshot
build, and resolved `IntegrityAnalysis` from the renv project library
instead, where the installed version is **0.1.0**.

The 42.8% figure was therefore produced by the same stale 0.1.0 parser
that got the 2026-08-26 run discarded. The 2026-08-29 run replaced one
route to the stale build with another, and reported a version number
that described the process doing the arithmetic rather than the
processes reading the PDFs.

Verified directly, on the Windows desktop, after the fact:

```
libPaths seen by a script run from the repo (renv active):
  .../renv/library/IntegrityAnalysis-fdfa5972/windows/R-4.5/x86_64-w64-mingw32
IntegrityAnalysis resolvable here: 0.1.0
```

**Fixed in PR #115**, which puts the snapshot library on `.libPaths()`
at each level that passes a library path down — the script, the cluster
workers, and hence the parse subprocesses.

**Why this run can be trusted.** It was run on a machine where the
snapshot library is the *only* copy of `IntegrityAnalysis` anywhere on
the system. There is no second build for a child to resolve, so the
failure mode above cannot occur — not merely "was avoided", but is
unavailable. That is a stronger guarantee than any assertion inside the
script, and it is the reason corroboration runs should be done on a
dedicated node rather than the development machine.

A useful corollary: the bug was invisible on Windows precisely *because*
the desktop has a second copy on the default path. The development
machine is the worst place to verify library provenance.

## What changed in the numbers

Fully corroborated went from 42.8% to **44.8%**, and parsed files from
988 to 1,047. Both move in the direction the intervening commits predict
— the 0.2.0 engine includes the shared name normalizer (#108) and
everything merged since — so the practical effect of the defect was
modest. The provenance claim, however, was simply false, which is the
part that mattered.
