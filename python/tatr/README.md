# The TATR run-along

A second, independent way to recover a table's geometry from a PDF, running
beside the deterministic engine rather than replacing it.

Written 2026-09-01 at Steve Shafer's direction: *"create a 'run along' using
TATR ... test it on our entire corpus of PDF files, rendering the output as
XML ... a large run will tell us whether this is adding more computation
without value, or represents a step between the existing parser, which is
free, and the AI parser, which is not."*

---

## What it is, and what it is not

Microsoft's [Table Transformer](https://github.com/microsoft/table-transformer)
(TATR) is a DETR object detector trained on PubTables-1M. It finds tables on
a rendered page and returns their rows, columns, headers and spanning cells.

**It returns geometry and no characters.** It cannot read a digit, and it has
no notion of which table is a baseline demographics table. Cell text here
comes from *our* PDF text layer, assigned to the cell whose box it falls in,
so printed values and their rounding survive exactly. The model is good at
layout and cannot read; poppler is good at reading and cannot do layout.

**Its output is not ground truth.** `master/xml/` holds publisher XML, and
the works holding both a PDF and an XML are usable as parser truth for
precisely that reason. TATR output is registered as a **collection** — its
own `SOURCE_ID`, its own filenames under `registry/` — which the builder
structurally cannot place in `master/`. `corpus/auditCorpus.R` asserts the
rule as well, and that assertion is verified to fail on a deliberate break.

## Why it might be worth the computation

Measured 2026-09-01 on the 147 articles whose text layer the deterministic
engine reads and whose baseline table it still cannot grid:

| | of the 114 that actually contain a per-arm baseline table |
|---|---|
| deterministic engine | 0 — that is how the set was drawn |
| Claude assist (~10–13¢/paper) | 84 (73.7%) |
| TATR (free, local) | 96 (84.2%) as a geometry upper bound |
| either | 109 (95.6%) |

TATR reached **25 articles the paid assist could not parse**. But on the 32
articles containing no per-arm baseline table it still claimed one in 11
(34%), so it must never be trusted to decide *which* table it found.

Two things the paid path can never offer: it costs nothing per use, and,
running entirely locally, it is the only option that can be pointed at the
6,328 confidential peer-review manuscripts.

## The plausibility gate, and why detection score is not enough

The first real run — five medRxiv preprints — returned **14 to 26 "tables"
per article at scores from 0.70 to 0.96, every one of them two columns of
running body text.** TATR was trained on typeset PMC pages where tables
carry rule lines; an author-formatted manuscript is out of domain and the
detector latches onto paragraph blocks.

A wrong detection scores 0.96 as happily as a right one — the same lesson
the NCBI positive controls taught. So **content is the gate, not confidence**:
a results table is mostly short, largely numeric cells.

| threshold | default | meaning |
|---|---:|---|
| `--min-cols` | 3 | two "columns" is what prose degenerates into |
| `--min-numeric` | 0.15 | share of filled cells carrying a number |
| `--max-medlen` | 24 | median characters per filled cell |

Measured effect: on preprints the gate rejected 10–22 prose blocks per
article while keeping the real tables; on typeset journal PDFs it kept 1–4
per article with shapes like 13×6, 19×10 and 33×7. Every statistic is
written into the XML (`frac-numeric`, `median-cell-chars`,
`passed-plausibility`) so thresholds can be re-tuned from recorded evidence
instead of another full run.

## The pegged environment

Everything below changes the output and is therefore part of the pin.

**Model weights**, by revision SHA rather than tag:

| model | revision |
|---|---|
| `microsoft/table-transformer-detection` | `2357cbe2b5a5d1c03e54f32764f06058933b65ab` |
| `microsoft/table-transformer-structure-recognition-v1.1-all` | `7587a7ef111d9dcbf8ac695f1376ab7014340a0c` |

Both are `model.safetensors` with **no `.bin` and no `.py`** in either
repository — no pickle, so no code executes on load, and `trust_remote_code`
is moot. Weights are fetched once by `tools/tatrProvision.sh` and loaded
thereafter with `local_files_only=True`: no network at inference, and no run
can silently acquire different weights.

**Libraries**: `python/tatr/requirements.txt`. The `transformers<5` pin is
load-bearing — 5.x rejects the published config outright (`Field 'dilation'
expected bool, got NoneType`) and the models will not load.

**Inference constants**, in `tatrTables.py`: render DPI 150, detection
threshold 0.7, structure threshold 0.5, structure input 800/1000, crop pad
12, max pages 24.

*Reproducible* rather than *deterministic in the rule-based sense*: same
weights, same library versions, same input, same output. It is a neural
network, and reproducibility is tied to the pins — which is why they are
pins and not preferences. To evaluate a future weight release, run it
against the pegged revision on the same corpus and compare; do not adopt it
because it is newer.

## Running it

```bash
# once per node (no root; installs a managed Python 3.12)
./tools/tatrProvision.sh

# a run: list is CSV of ACCESSION,PATH
~/tatrenv/bin/python python/tatr/tatrTables.py \
    --list work.csv --out tatrXml --manifest tatrRun.csv
```

Resumable: the manifest is appended after every file and re-read on restart,
so an interrupted run loses one PDF rather than the run. Every PDF gets a
manifest row — `ok`, `missing`, or `error: …` — because a silent skip looks
exactly like a file with no tables.

**Threads: one per worker.** `--threads` defaults to 1 because the work is
parallel across *documents*. The first pilot used `cpu_count() - 2` per
worker, so six workers claimed 84 threads on 16 logical cores and
throughput collapsed. Re-running the same twelve works at one thread each
took **1,038 s instead of 8,550 s - 8.2x faster**. Torch cannot know how
many siblings it has; the caller must say.

**Throughput**, CPU only, one thread per worker:

| document kind | seconds each |
|---|---:|
| typeset journal article (6-8 pp) | ~5 |
| medRxiv preprint (20+ pp) | ~21 |
| ClinicalTrials.gov protocol (70-108 pp, detection-dense) | ~87 |

Cost scales with **detections per page**, not page count alone: every
detected region costs a further structure pass, and protocol documents are
detection-dense. Estimating a corpus-wide run from journal articles alone
understates it by more than an order of magnitude - the corpus holds 38,042
PDFs, most of them not journal articles.

## Known limitations

- **Word spacing is lost in some typeset PDFs** — `GroupI`, `No.ofsuccessful`
  — where the text layer carries no space glyphs. Numeric cells such as
  `51.5(12.2)` are unaffected, which is what matters most, but row labels
  need normalising downstream.
- **Out of domain on author manuscripts.** Quality is much lower on
  preprints than on typeset journal PDFs; the gate handles it, but the
  useful yield there is smaller.
- **Scanned pages produce nothing.** TATR returns boxes with no text, so a
  page with no text layer yields an empty grid. Pairing it with tesseract —
  TATR for cell geometry, OCR *within* each cell — is the natural next step
  and is not built here.
