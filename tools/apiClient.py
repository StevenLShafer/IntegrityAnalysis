#!/usr/bin/env python3
"""apiClient.py - drive the IntegrityAnalysis REST service from Python.

Standard library only (no requests, no third-party packages), so it runs
anywhere Python 3.8+ does. The R twin is tools/apiClient.R; both were run
against a local service and the deployed one before the API User's Guide
(docs/api-users-guide.md) was written from their replies.

Usage:
    python tools/apiClient.py health  <base-url>
    python tools/apiClient.py parse   <base-url> <file>
    python tools/apiClient.py analyze <base-url> <file> [m]

<file> is an article PDF, a Word manuscript (.docx), a JATS XML article
(.xml), a spreadsheet (csv/xls/xlsx), or a picture of a table
(jpg/png/tif); one file per call. [m] is the Monte Carlo replication count
for /analyze (default 15000). The bearer token comes from the
INTEGRITY_API_TOKEN environment variable; /health needs none. Written
2026-09-03 by Claude Code (model Claude Fable 5.1) at Steve Shafer's
request, beside the R client.
"""
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid


def usage():
    print(__doc__.split("Usage:")[1].split("<file>")[0].strip())
    sys.exit(2)


def health(base):
    try:
        with urllib.request.urlopen(base + "/health", timeout=30) as r:
            body = json.loads(r.read().decode("utf-8"))
            build = body.get("commit")
            print("health: %d  ok=%s%s%s" % (
                r.status, body.get("ok"),
                "  build %s" % build[:8] if build else "",
                "  %s" % body["engine"] if body.get("engine") else ""))
            return True
    except Exception as e:  # noqa: BLE001 - report and stop
        print("health: could not reach %s - %s" % (base, e))
        return False


def multipart(fields, file_field, path):
    """Build a multipart/form-data body by hand: fields + one file."""
    boundary = "----IntegrityAnalysis" + uuid.uuid4().hex
    ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
    parts = []
    for k, v in fields.items():
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
                      % (boundary, k, v)).encode("utf-8"))
    with open(path, "rb") as fh:
        data = fh.read()
    parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n"
                  "Content-Type: %s\r\n\r\n" % (boundary, file_field, os.path.basename(path), ctype)).encode("utf-8"))
    parts.append(data)
    parts.append(("\r\n--%s--\r\n" % boundary).encode("utf-8"))
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def save_csv(stem, suffix, text):
    if not text:
        return
    out = "%s-%s.csv" % (stem, suffix)
    with open(out, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    print("  wrote %s (%d rows)" % (out, text.count("\n") - 1))


def main(argv):
    if len(argv) < 2 or argv[0] not in ("health", "parse", "analyze"):
        usage()
    verb, base = argv[0], argv[1].rstrip("/")
    if not health(base) or verb == "health":
        sys.exit(0 if verb == "health" else 1)
    if len(argv) < 3:
        usage()
    token = os.environ.get("INTEGRITY_API_TOKEN", "")
    if not token:
        print("set INTEGRITY_API_TOKEN to the token the operator issued you")
        sys.exit(2)
    path = argv[2]
    if not os.path.exists(path):
        print("no such file: %s" % path)
        sys.exit(2)
    fields = {}
    if verb == "analyze" and len(argv) >= 4:
        fields["m"] = str(int(argv[3]))
    body, ctype = multipart(fields, "file", path)
    req = urllib.request.Request(base + "/" + verb, data=body, method="POST",
                                 headers={"Authorization": "Bearer " + token,
                                          "Content-Type": ctype,
                                          "Content-Length": str(len(body))})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=900 if verb == "analyze" else 300) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:      # 4xx/5xx still carry a JSON body
        status, raw = e.code, e.read()
    except Exception as e:  # noqa: BLE001
        print("%s: request failed - %s" % (verb, e))
        sys.exit(1)
    secs = round(time.time() - t0, 1)
    print("%s %s: HTTP %d in %s s" % (verb, os.path.basename(path), status, secs))
    if os.environ.get("INTEGRITY_API_SAVE_RAW"):      # the reply exactly as received
        rawpath = "%s-%s-reply.json" % (os.path.splitext(path)[0], verb)
        with open(rawpath, "wb") as fh:
            fh.write(raw)
        print("  raw reply: %s" % rawpath)
    try:
        b = json.loads(raw.decode("utf-8"))
    except ValueError:
        print("  (no JSON body) %s" % raw[:300])
        sys.exit(1)
    print("  ok=%s  deleted=%s%s" % (b.get("ok"), b.get("deleted"),
                                    "  engine=%s" % b["engine"] if b.get("engine") else ""))
    for key in ("reasons", "flags"):
        if b.get(key):
            print("  %s: %s" % (key, "; ".join(str(x) for x in b[key])))
    if b.get("rows") is not None:
        print("  rows: %s" % b["rows"])
    for s in b.get("skipped") or []:
        print("    - %s: %s" % (s.get("label"), s.get("reason")))
    if b.get("trials") is not None:
        print("  trials: %s" % b["trials"])
    if b.get("overallP") is not None:
        print("  overall p: %s" % b["overallP"])
    stem = os.path.splitext(path)[0]
    save_csv(stem, "template", b.get("templateCsv"))
    save_csv(stem, "results", b.get("resultsCsv"))
    for name, csv in (b.get("journalTables") or {}).items():
        save_csv(stem, "journal-" + "".join(c if c.isalnum() or c in "._-" else "_" for c in name), csv)
    if b.get("journalTablesOmitted"):
        print("  journal tables omitted: %s" % b["journalTablesOmitted"])
    sys.exit(0 if b.get("ok") else 1)


if __name__ == "__main__":
    main(sys.argv[1:])
