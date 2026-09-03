"""tatrTables.py - the Table Transformer run-along.

Written 2026-09-01 by Claude Code (model Claude Opus 5, Anthropic) at
Steve Shafer's direction: "create a 'run along' using TATR ... test it on
our entire corpus of PDF files, rendering the output as XML."

WHAT THIS IS FOR. The deterministic engine reads a PDF's text layer and
infers the table's geometry from it. That inference is where it fails: of
the 281 failures in the 1,865-article Carlisle corpus, 147 are articles
whose text layer we read perfectly and whose baseline table we still
cannot grid. This runs Microsoft's Table Transformer over the same PDFs to
recover the geometry a different way, and writes what it finds as XML.

MEASURED, 2026-09-01, on exactly those 147 files: TATR located a
confident, griddable table on a baseline-reading page in 96 of the 114
that actually contain a per-arm baseline table (84.2%), including 25 the
Claude assist could not parse. On the 32 articles that contain no per-arm
baseline table at all it still claimed one in 11 (34%) - so TATR supplies
GEOMETRY and must never be trusted to decide WHICH table it has found.

THE OUTPUT IS NOT GROUND TRUTH, and the corpus must never let it look
like it. master/xml/ holds publisher XML, and the 6,565 works holding both
a PDF and an XML are usable as parser truth for exactly that reason.
TATR output is therefore registered as a COLLECTION (registry/, its own
SOURCE_ID, its own filenames), which the builder structurally cannot place
in master/, and corpus/auditCorpus.R asserts the rule besides.

VALUES COME FROM THE TEXT LAYER, NEVER FROM THE MODEL. TATR returns boxes
and no characters. Cell text here is our own extracted words, assigned to
the cell whose box they fall in, so printed digits and their rounding are
preserved exactly. That is the whole point of pairing the two: the model
is good at layout and cannot read; poppler is good at reading and cannot
do layout.

PEGGING. Every constant below changes the output and is therefore part of
the pinned environment - see python/tatr/README.md, which records the
model revision SHAs and the library versions this was validated against.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass

import pdfplumber
import pypdfium2 as pdfium
import torch
from PIL import Image
from transformers import (AutoImageProcessor, TableTransformerConfig,
                          TableTransformerForObjectDetection)

# ---------------------------------------------------------------------------
# PEGGED CONSTANTS. Changing any of these changes the output, so each is
# recorded in the run manifest alongside the results.
# ---------------------------------------------------------------------------
DET_MODEL = "microsoft/table-transformer-detection"
DET_REV = "2357cbe2b5a5d1c03e54f32764f06058933b65ab"
STR_MODEL = "microsoft/table-transformer-structure-recognition-v1.1-all"
STR_REV = "7587a7ef111d9dcbf8ac695f1376ab7014340a0c"

RENDER_DPI = 150          # TATR was trained on rendered pages at this order
DET_THRESHOLD = 0.7       # the research repo's own reporting operating point
STR_THRESHOLD = 0.5
STRUCT_SIZE = {"shortest_edge": 800, "longest_edge": 1000}
MAX_PAGES = 24            # an article longer than this is not a trial report
CROP_PAD = 12             # the structure model expects the outer rule lines

# PLAUSIBILITY GATE. Detection score cannot decide this - a prose block
# scores 0.96 as readily as a real table (measured 2026-09-01, five medRxiv
# preprints, 14-26 spurious "tables" each). Content decides it: a results
# table is mostly short, largely numeric cells. Defaults come from the
# observed separation and are overridable on the command line, with every
# statistic written into the XML so they can be re-tuned from recorded
# evidence instead of another full run.
MIN_COLS = 3              # two "columns" is what prose degenerates into
MIN_NUMERIC = 0.15        # share of filled cells that carry a number
MAX_MEDLEN = 24           # median characters per filled cell
MAX_LEADERS = 0.20        # share of cells carrying "......" dot leaders

SCALE = RENDER_DPI / 72.0  # PDF points -> rendered pixels

SCHEMA_VERSION = "1"


@dataclass
class Box:
    x0: float
    y0: float
    x1: float
    y1: float

    def inter(self, o: "Box") -> float:
        w = min(self.x1, o.x1) - max(self.x0, o.x0)
        h = min(self.y1, o.y1) - max(self.y0, o.y0)
        return w * h if w > 0 and h > 0 else 0.0

    def area(self) -> float:
        return max(0.0, self.x1 - self.x0) * max(0.0, self.y1 - self.y0)


def _config(name, rev, kw):
    """Load a config that transformers 5.x will accept, without downgrading it.

    THE PROBLEM. The published Table Transformer configs carry JSON nulls for
    fields typed as bool - "dilation": null, "use_pretrained_backbone": null -
    and transformers 5.x validates strictly, so construction fails with
    "Field 'dilation' expected bool, got NoneType". An earlier version of this
    file answered that by pinning transformers<5. That pin traded a KNOWN
    VULNERABILITY (GHSA-29pf-2h5f-8g72, fixed in 5.3.0) for a loading
    convenience, which is the wrong way round. (CodeRabbit, PR #137.)

    WHY THE OBVIOUS FIX DOES NOT WORK. Passing dilation=False to
    from_pretrained is applied AFTER the config object is constructed from the
    file, so validation has already failed. The dict has to be corrected
    before construction, which is what this does.

    It changes nothing about the model. null and False mean the same thing to
    a ResNet backbone that does not use dilated convolutions, and "backbone":
    null is simply absent rather than empty. Verified by loading both
    checkpoints and confirming the label sets - 2 classes for detection, 6 for
    structure - then re-running the eight-article regression set and getting
    byte-identical table counts and shapes.
    """
    d, _ = TableTransformerConfig.get_config_dict(name, revision=rev, **kw)
    if d.get("dilation") is None:
        d["dilation"] = False
    if d.get("use_pretrained_backbone") is None:
        d["use_pretrained_backbone"] = False
    if d.get("backbone") is None:
        d.pop("backbone", None)
    return TableTransformerConfig.from_dict(d)


def load_models(offline: bool):
    """Load both models at their pinned revisions.

    local_files_only is the deployed posture: no network at inference, so a
    run cannot silently pick up new weights, and the corpus cannot depend on
    huggingface.co being reachable. The first provisioning run populates the
    cache with these exact revisions.
    """
    kw = dict(local_files_only=offline)
    dcfg = _config(DET_MODEL, DET_REV, kw)
    scfg = _config(STR_MODEL, STR_REV, kw)
    dproc = AutoImageProcessor.from_pretrained(DET_MODEL, revision=DET_REV, **kw)
    dmodel = TableTransformerForObjectDetection.from_pretrained(
        DET_MODEL, revision=DET_REV, config=dcfg, use_safetensors=True, **kw)
    sproc = AutoImageProcessor.from_pretrained(STR_MODEL, revision=STR_REV, **kw)
    # The published preprocessor_config carries only "longest_edge", which the
    # shared DETR processor rejects outright. Supplying both matches the crop
    # resolution the research repo uses.
    sproc.size = STRUCT_SIZE
    smodel = TableTransformerForObjectDetection.from_pretrained(
        STR_MODEL, revision=STR_REV, config=scfg, use_safetensors=True, **kw)
    dmodel.eval()
    smodel.eval()
    return dproc, dmodel, sproc, smodel


def render(pdf_path: str, n_pages: int):
    """Rasterise pages with pypdfium2 (Apache-2.0/BSD).

    PyMuPDF is faster and AGPL; this project ships a public repo and a
    hosted app, so a permissive licence is worth the difference.
    """
    doc = pdfium.PdfDocument(pdf_path)
    try:
        for i in range(min(len(doc), n_pages)):
            yield i, doc[i].render(scale=SCALE).to_pil().convert("RGB")
    finally:
        doc.close()


def cells_from_structure(names, boxes):
    """Rows x columns -> grid cells, plus the header and spanning boxes.

    TATR emits rows and columns as separate objects; a cell is their
    intersection. That is the model's own formulation, not an invention
    here: the paper calls the intersection "a seventh implicit class,
    table grid cell".
    """
    rows = sorted([b for n, b in zip(names, boxes) if n == "table row"],
                  key=lambda b: b.y0)
    cols = sorted([b for n, b in zip(names, boxes) if n == "table column"],
                  key=lambda b: b.x0)
    heads = [b for n, b in zip(names, boxes) if n == "table column header"]
    spans = [b for n, b in zip(names, boxes) if n == "table spanning cell"]
    return rows, cols, heads, spans


NUMERIC = None   # compiled lazily; see is_numeric_cell
OUTLINE = None   # section labels: 8., 8.1., 10.3.4, 2.0
DOTLEADER = None # "Title Page........ 14"


def is_numeric_cell(s: str) -> bool:
    """A cell that carries a number, in the shapes a results table uses.

    Deliberately generous: 45, 45.2, 45.2%, (12.3), 45.2 (11.8), 12/34,
    45+/-3. Deliberately NOT generous about prose that happens to contain a
    year - a cell is numeric only if digits dominate what it holds.
    """
    global NUMERIC, OUTLINE
    if NUMERIC is None:
        import re
        NUMERIC = re.compile(r"[-+(]?\d[\d,.]*\s*[)%]?")
        # Outline labels only: a TRAILING dot ("8.", "8.1.") or three or
        # more levels ("10.3.4"). Deliberately NOT "2.0" or "45" - a
        # bare integer is a count and "2.0" is a plausible mean, and
        # losing real data to catch a contents page is the wrong trade.
        # The dot-leader test below catches what this deliberately misses.
        OUTLINE = re.compile(r"\d+(?:\.\d+)*\.|\d+(?:\.\d+){2,}")
    t = s.strip()
    if not t or len(t) > 24:
        return False
    # An OUTLINE NUMBER is not data. "8.1.", "10.3.4", "2.0" are section
    # labels, and counting them as numeric is how a table of contents passes
    # a numeric-density gate. Found 2026-09-02: the numeric-dense tables in
    # ClinicalTrials.gov protocol documents were overwhelmingly contents
    # pages - "8. PRESTUDY AND CONCOMITANT...", "1.0 Title Page........".
    if OUTLINE.fullmatch(t):
        return False
    hits = NUMERIC.findall(t)
    if not hits:
        return False
    return sum(len(h) for h in hits) / len(t) >= 0.5


def table_stats(grid):
    """Cheap descriptors that separate a data table from a block of prose.

    THE REASON THIS EXISTS. On the first real run - five medRxiv preprints
    - the detector returned 14 to 26 "tables" per article at scores from
    0.70 to 0.96, and every one was two columns of running body text. TATR
    was trained on typeset PMC pages, where tables carry rule lines and
    aligned columns; an author-formatted manuscript is out of domain, and
    the model latches onto paragraph blocks. On typeset journal PDFs it
    behaved well (measured separately: a griddable table on 84% of the 147
    articles our engine cannot parse).

    So detection score cannot be the gate - a wrong detection scores 0.96
    as happily as a right one, which is the same lesson the NCBI positive
    controls taught. Content is the gate: a results table is mostly short,
    largely numeric cells; prose is long text in few columns.

    Every statistic is written into the XML so the threshold can be
    re-tuned later against recorded evidence rather than re-run.
    """
    global DOTLEADER
    if DOTLEADER is None:
        import re
        DOTLEADER = re.compile(r"\.{3,}")
    cells = [c for row in grid for c in row]
    n = len(cells)
    if n == 0:
        return dict(cells=0, filled=0.0, numeric=0.0, medlen=0.0)
    filled = [c for c in cells if c.strip()]
    lens = sorted(len(c.strip()) for c in filled) or [0]
    # Dot leaders are the other half of the contents-page signature: a cell
    # like "Title Page........ 14" is typography, not tabulation.
    leaders = sum(bool(DOTLEADER.search(c)) for c in filled)
    return dict(
        cells=n,
        filled=len(filled) / n,
        numeric=(sum(is_numeric_cell(c) for c in filled) / len(filled)) if filled else 0.0,
        medlen=float(lens[len(lens) // 2]),
        leaders=(leaders / len(filled)) if filled else 0.0,
    )


def assign_words(words, cell: Box):
    """Words whose box overlaps this cell more than any other, in order.

    Overlap fraction of the WORD, not of the cell: a long word straddling a
    rule line belongs to the cell holding most of it.
    """
    got = []
    for w in words:
        wb = w["box"]
        a = wb.area()
        if a > 0 and wb.inter(cell) / a >= 0.5:
            got.append(w)
    got.sort(key=lambda w: (round(w["box"].y0, 1), w["box"].x0))
    return " ".join(w["text"] for w in got).strip()


def page_words(page):
    """Text-layer words in RENDERED-PIXEL coordinates.

    pdfplumber reports points with a top-left origin, the same convention
    the renderer uses, so this is a pure scale with no flip.
    """
    out = []
    for w in page.extract_words(use_text_flow=False, keep_blank_chars=False):
        out.append({"text": w["text"],
                    "box": Box(w["x0"] * SCALE, w["top"] * SCALE,
                               w["x1"] * SCALE, w["bottom"] * SCALE)})
    return out


def build_xml(accession, pdf_path, tables, elapsed, sha, gate):
    """A JATS-shaped document: <table-wrap> is what corpus/parseJats.R reads.

    The geometry is kept beside the markup rather than thrown away, so a
    later scoring pass can compare boxes against PubTables-1M ground truth
    without re-running the models.

    The root element is deliberately NOT <article>. This file must never be
    mistaken for publisher JATS, so it announces itself: a tatr-tables root,
    a derived="true" attribute, and the model revisions that produced it.
    """
    root = ET.Element("tatr-tables", {
        "schema-version": SCHEMA_VERSION,
        "derived": "true",
        "ground-truth": "false",
        "accession": accession,
        "source-pdf-sha256": sha,
        "detection-model": f"{DET_MODEL}@{DET_REV}",
        "structure-model": f"{STR_MODEL}@{STR_REV}",
        "render-dpi": str(RENDER_DPI),
        "det-threshold": str(DET_THRESHOLD),
        "str-threshold": str(STR_THRESHOLD),
        # THE GATE THAT PRODUCED THIS FILE, recorded with it. The per-table
        # statistics are only re-tunable against the thresholds they were
        # judged by; without these a later pass cannot tell whether a table
        # is absent because the model missed it or because the gate of the
        # day rejected it. (CodeRabbit, PR #137.)
        "gate-min-cols": str(gate["min_cols"]),
        "gate-min-numeric": str(gate["min_numeric"]),
        "gate-max-medlen": str(gate["max_medlen"]),
        "gate-max-leaders": str(MAX_LEADERS),
        "seconds": f"{elapsed:.2f}",
    })
    note = ET.SubElement(root, "provenance-note")
    note.text = ("Machine-derived table geometry from Microsoft Table "
                 "Transformer, with cell text taken from the PDF text layer. "
                 "NOT publisher markup and NOT ground truth. The model "
                 "supplies layout only and cannot identify which table is a "
                 "baseline table.")

    for t in tables:
        tw = ET.SubElement(root, "table-wrap", {
            "id": f"p{t['page']:02d}t{t['index']}",
            "page": str(t["page"]),
            "detection-score": f"{t['score']:.4f}",
            "rows": str(len(t["rows"])),
            "cols": str(len(t["cols"])),
            "column-headers": str(t["n_head"]),
            "spanning-cells": str(t["n_span"]),
            "cells": str(t["stats"]["cells"]),
            "frac-filled": f"{t['stats']['filled']:.3f}",
            "frac-numeric": f"{t['stats']['numeric']:.3f}",
            "median-cell-chars": f"{t['stats']['medlen']:.0f}",
            "frac-dot-leaders": f"{t['stats']['leaders']:.3f}",
            "passed-plausibility": "true" if t["keep"] else "false",
        })
        tbl = ET.SubElement(tw, "table")
        tbody = ET.SubElement(tbl, "tbody")
        for r, cellrow in enumerate(t["cells"]):
            tr = ET.SubElement(tbody, "tr", {"row": str(r),
                                             "header": "true" if r in t["head_rows"] else "false"})
            for c, txt in enumerate(cellrow):
                td = ET.SubElement(tr, "td", {"col": str(c)})
                td.text = txt
        geo = ET.SubElement(tw, "geometry", {"units": "rendered-px",
                                             "dpi": str(RENDER_DPI)})
        ET.SubElement(geo, "table-box", box_attrs(t["box"]))
        for i, b in enumerate(t["rows"]):
            ET.SubElement(geo, "row-box", dict(index=str(i), **box_attrs(b)))
        for i, b in enumerate(t["cols"]):
            ET.SubElement(geo, "col-box", dict(index=str(i), **box_attrs(b)))
        # Spanning cells were counted but their boxes were thrown away. They
        # are the part of a table's structure that a row/column grid cannot
        # express, and the reason PubTables-1M exists at all - so scoring
        # this output against that ground truth needs them. (CodeRabbit.)
        for i, b in enumerate(t["spans"]):
            ET.SubElement(geo, "spanning-box", dict(index=str(i), **box_attrs(b)))
        for i, b in enumerate(t["heads"]):
            ET.SubElement(geo, "column-header-box", dict(index=str(i), **box_attrs(b)))
    return root


def box_attrs(b: Box):
    return {"x0": f"{b.x0:.1f}", "y0": f"{b.y0:.1f}",
            "x1": f"{b.x1:.1f}", "y1": f"{b.y1:.1f}"}


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def process(pdf_path, accession, models, max_pages=MAX_PAGES,
            min_cols=MIN_COLS, min_numeric=MIN_NUMERIC, max_medlen=MAX_MEDLEN):
    dproc, dmodel, sproc, smodel = models
    slabels = smodel.config.id2label
    t0 = time.time()
    tables = []

    with pdfplumber.open(pdf_path) as plumb:
        n = min(len(plumb.pages), max_pages)
        for pno, img in render(pdf_path, n):
            enc = dproc(images=img, return_tensors="pt")
            det = dproc.post_process_object_detection(
                dmodel(**enc), threshold=DET_THRESHOLD,
                target_sizes=[img.size[::-1]])[0]
            if len(det["scores"]) == 0:
                continue
            words = page_words(plumb.pages[pno])

            for ti, (score, box) in enumerate(zip(det["scores"], det["boxes"])):
                x0, y0, x1, y1 = (float(v) for v in box)
                crop = img.crop((max(0, x0 - CROP_PAD), max(0, y0 - CROP_PAD),
                                 min(img.width, x1 + CROP_PAD),
                                 min(img.height, y1 + CROP_PAD)))
                ox, oy = max(0, x0 - CROP_PAD), max(0, y0 - CROP_PAD)
                senc = sproc(images=crop, return_tensors="pt")
                sres = sproc.post_process_object_detection(
                    smodel(**senc), threshold=STR_THRESHOLD,
                    target_sizes=[crop.size[::-1]])[0]
                names = [slabels[int(l)] for l in sres["labels"]]
                # back to page coordinates so the words line up
                boxes = [Box(float(b[0]) + ox, float(b[1]) + oy,
                             float(b[2]) + ox, float(b[3]) + oy)
                         for b in sres["boxes"]]
                rows, cols, heads, spans = cells_from_structure(names, boxes)
                if len(rows) < 2 or len(cols) < 2:
                    continue

                head_rows = {i for i, r in enumerate(rows)
                             if any(r.inter(h) / max(r.area(), 1) > 0.5 for h in heads)}
                grid = []
                for r in rows:
                    grid.append([assign_words(words, Box(c.x0, r.y0, c.x1, r.y1))
                                 for c in cols])
                st = table_stats(grid)
                keep = (len(cols) >= min_cols
                        and st["numeric"] >= min_numeric
                        and st["medlen"] <= max_medlen
                        and st["leaders"] < MAX_LEADERS)
                tables.append(dict(page=pno + 1, index=ti, score=float(score),
                                   box=Box(x0, y0, x1, y1), rows=rows, cols=cols,
                                   n_head=len(heads), n_span=len(spans),
                                   heads=heads, spans=spans,
                                   head_rows=head_rows, cells=grid,
                                   stats=st, keep=keep))
    return tables, time.time() - t0


def main():
    ap = argparse.ArgumentParser(description="TATR run-along over a list of PDFs")
    ap.add_argument("--list", required=True,
                    help="CSV with columns ACCESSION,PATH (no header assumptions: "
                         "first two columns are used)")
    ap.add_argument("--out", required=True, help="output directory for XML")
    ap.add_argument("--manifest", required=True, help="CSV run manifest")
    ap.add_argument("--limit", type=int, default=10 ** 9)
    ap.add_argument("--threads", type=int, default=1,
                    help="torch threads for THIS worker. One per worker is "
                         "correct when several run side by side; raise it only "
                         "for a single-worker run.")
    ap.add_argument("--min-cols", type=int, default=MIN_COLS,
                    help="reject a detection with fewer columns than this")
    ap.add_argument("--min-numeric", type=float, default=MIN_NUMERIC,
                    help="reject unless this share of filled cells is numeric")
    ap.add_argument("--max-medlen", type=float, default=MAX_MEDLEN,
                    help="reject if the median filled cell is longer than this")
    ap.add_argument("--allow-download", action="store_true",
                    help="permit fetching weights; default is offline")
    ap.add_argument("--write-empty", action="store_true",
                    help="also write tables the gate rejected whose cells are "
                         "ALL empty - a page with no text layer, where the "
                         "geometry is exactly what an OCR pass can fill "
                         "(the tesseract pairing, 2026-09-02); they carry "
                         "passed-plausibility=false")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    torch.set_grad_enabled(False)
    ############################################################################
    # THREADS: ONE PER WORKER BY DEFAULT, AND THAT DEFAULT IS THE WHOLE POINT.
    #
    # This was cpu_count() - 2, which is correct for a single worker on an
    # idle box and catastrophic for a fleet. The 2026-09-01 pilot ran six
    # workers on a 16-logical-core node; each claimed 14 threads, so 84
    # threads contended for 16 cores and throughput collapsed from the 4.7 s
    # per journal article measured single-worker to 354 s per work.
    #
    # Torch does not know how many siblings it has, so the caller must say.
    # One thread per worker is the right default for the run-along, because
    # the work is embarrassingly parallel across DOCUMENTS - six documents
    # at one thread each beats one document at six threads, and it cannot
    # oversubscribe. Pass --threads deliberately for a single-worker run.
    ############################################################################
    torch.set_num_threads(max(1, args.threads))

    # A RESUMED RUN RETRIES WHAT FAILED. Treating every manifest row as
    # "done" made a transient failure permanent: one unreadable moment, one
    # network blip, and that accession was skipped for good on every later
    # pass, silently, because a row existed. Only rows that actually
    # succeeded are skipped now. (CodeRabbit, PR #137.)
    done = set()
    if os.path.exists(args.manifest):
        with open(args.manifest, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                if (row.get("STATUS") or "").strip() == "ok":
                    done.add(row["ACCESSION"])

    todo = []
    with open(args.list, encoding="utf-8") as fh:
        for line in fh:
            parts = [p.strip().strip('"') for p in line.rstrip("\n").split(",")]
            if len(parts) < 2 or parts[0] == "ACCESSION":
                continue
            if parts[0] in done:
                continue
            todo.append((parts[0], parts[1]))
    todo = todo[:args.limit]
    print(f"{len(todo)} PDFs to process ({len(done)} already done)", flush=True)
    if not todo:
        return

    models = load_models(offline=not args.allow_download)
    print("models ready", flush=True)

    # csv.writer, not string formatting: a path containing a comma would
    # shift every later column, and the resume logic above reads this file
    # back BY COLUMN NAME. (CodeRabbit, PR #137.)
    new = not os.path.exists(args.manifest)
    mf = open(args.manifest, "a", newline="", encoding="utf-8")
    mw = csv.writer(mf)
    if new:
        mw.writerow(["ACCESSION", "PDF", "TABLES_KEPT", "TABLES_REJECTED",
                     "PAGES_WITH_TABLE", "MAXROWS", "MAXCOLS", "SECONDS",
                     "STATUS"])

    t_start = time.time()
    for i, (acc, path) in enumerate(todo, 1):
        try:
            if not os.path.exists(path):
                mw.writerow([acc, path, 0, 0, 0, 0, 0, 0, "missing"]); mf.flush(); continue
            found, el = process(path, acc, models, min_cols=args.min_cols,
                                min_numeric=args.min_numeric,
                                max_medlen=args.max_medlen)
            # Only plausible tables reach the corpus. Rejects are COUNTED, not
            # written: 14-26 prose blocks per article would bury the real
            # tables and inflate the library for nothing. The count is what
            # tells us later whether the gate is set right.
            # --write-empty adds the text-less rejects: cell text is empty
            # because the page has no text layer, not because the region is
            # prose, and their boxes are what the R side fills with OCR.
            tables = [t for t in found
                      if t["keep"] or (args.write_empty and t["stats"]["filled"] == 0)]
            if tables:
                root = build_xml(acc, path, tables, el, sha256_of(path),
                                 dict(min_cols=args.min_cols,
                                      min_numeric=args.min_numeric,
                                      max_medlen=args.max_medlen))
                ET.ElementTree(root).write(os.path.join(args.out, f"{acc}.tatr.xml"),
                                           encoding="utf-8", xml_declaration=True)
            pages = len({t["page"] for t in tables})
            mr = max((len(t["rows"]) for t in tables), default=0)
            mc = max((len(t["cols"]) for t in tables), default=0)
            mw.writerow([acc, path, len(tables), len(found) - len(tables),
                         pages, mr, mc, f"{el:.2f}", "ok"])
        except Exception as e:                                    # noqa: BLE001
            # One unreadable PDF must not end a 38,000-file run. The status
            # column is what a later pass greps for; a silent skip would look
            # exactly like a file with no tables.
            mw.writerow([acc, path, 0, 0, 0, 0, 0, 0,
                         "error: " + str(e)[:120]])
        mf.flush()
        if i % 50 == 0 or i == len(todo):
            el = time.time() - t_start
            print(f"  {i}/{len(todo)}  {el:.0f}s  {el/i:.2f}s/pdf", flush=True)
    mf.close()
    print("=== tatr run-along done ===", flush=True)


if __name__ == "__main__":
    sys.exit(main())
