#!/usr/bin/env python3
"""apiClient.py - drive the IntegrityAnalysis REST service from Python.

Standard library only (no requests, no third-party packages), so it runs
anywhere Python 3.8+ does. The R twin is tools/apiClient.R; both were run
against a local service and the deployed one before the API User's Guide
(docs/api-users-guide.md) was written from their replies.

Usage:
    python tools/apiClient.py health  <base-url>
    python tools/apiClient.py parse   <base-url> <file>
    python tools/apiClient.py analyze <base-url> <file> [--seed N]

<file> is an article PDF, a Word manuscript (.docx), a JATS XML article
(.xml), a spreadsheet (csv/xls/xlsx), or a picture of a table
(jpg/png/tif); one file per call. The service takes no replication count:
every row runs the app's staged Monte Carlo (1,000 / 10,000 / 100,000
replicates, escalating only while the row alarms). The bearer token comes
from the
INTEGRITY_API_TOKEN environment variable; /health needs none. Written
2026-09-03 by Claude Code (model Claude Fable 5.1) at Steve Shafer's
request, beside the R client.
"""
import csv
import io
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


def usage():
    print(__doc__.split("Usage:")[1].split("<file>")[0].strip())
    sys.exit(2)


# THE CLIENT DOES NOT FOLLOW REDIRECTS, AND A REMOTE SERVICE MUST BE HTTPS
# (outside security review, 2026-09-26). Python's default opener follows a
# 3xx wherever it points and re-sends the request's headers there, so a
# redirecting endpoint - or anything between the client and it - would
# receive the bearer token, and a plain http:// base URL would carry the
# token and the manuscript in clear. A redirect is reported as a wrong
# base URL and nothing is re-sent; http:// is accepted only for a service
# on this machine (the guide's local-run examples).
class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None                         # urlopen raises HTTPError(3xx)


_opener = urllib.request.build_opener(_NoRedirect)
_LOCAL_HOSTS = ("127.0.0.1", "localhost", "::1", "[::1]")


def check_base(base):
    u = urllib.parse.urlsplit(base)
    host = (u.hostname or "").lower()
    if u.scheme == "https" or (u.scheme == "http" and host in _LOCAL_HOSTS):
        return
    print("the service URL must be https:// (http:// only for a service on this machine): %s" % base)
    sys.exit(2)


def redirected(e):
    """A 3xx from the service: say where it pointed, send nothing there."""
    if 300 <= e.code < 400:
        print("the service answered %d with a redirect to %s; this client does not follow "
              "redirects with your token - check the base URL with the operator"
              % (e.code, e.headers.get("Location", "(no Location header)")))
        return True
    return False


def health(base):
    try:
        with _opener.open(base + "/health", timeout=30) as r:
            body = json.loads(r.read().decode("utf-8"))
            build = body.get("commit")
            print("health: %d  ok=%s%s%s" % (
                r.status, body.get("ok"),
                "  build %s" % build[:8] if build else "",
                "  %s" % body["engine"] if body.get("engine") else ""))
            return True
    except urllib.error.HTTPError as e:
        if redirected(e):
            return False
        print("health: %s answered HTTP %d" % (base, e.code))
        return False
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


def formula_cells(text):
    """Count the cells a spreadsheet would read as a formula: a cell that
    begins with =, @, a tab or a carriage return, or with + or - and then
    something other than a number ("-0.5" is a number; "-cmd" is not)."""
    n = 0
    for row in csv.reader(io.StringIO(text)):
        for cell in row:
            if not cell:
                continue
            c = cell[0]
            if c in "=@\t\r":
                n += 1
            elif c in "+-" and not cell[1:2].isdigit() and cell[1:2] != ".":
                n += 1
    return n


def save_csv(stem, suffix, text):
    if not text:
        return
    out = "%s-%s.csv" % (stem, suffix)
    with open(out, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    print("  wrote %s (%d rows)" % (out, text.count("\n") - 1))
    # THE TEMPLATE IS SAVED VERBATIM, AND SAID SO WHEN THAT MATTERS (outside
    # security review, 2026-09-26). templateCsv is the round-trip payload -
    # the service must accept it back unchanged, so the client cannot
    # sanitise its labels as the results CSV's are - but it is written as
    # an ordinary .csv beside the input, and a label a spreadsheet would
    # read as a formula ("=...", "@...", "+text") is a manuscript's own
    # text. When such a cell is present the user is told, and told to edit
    # the file in a text editor rather than open it in spreadsheet software.
    if suffix == "template":
        k = formula_cells(text)
        if k:
            print("  note: %d cell(s) in %s begin with a character spreadsheet software reads as a "
                  "formula (=, +, -, @); the file is kept exactly as the service returned it so it "
                  "can be sent back - edit it in a text editor, not in a spreadsheet" % (k, out))


def main(argv):
    seed = None
    if "--seed" in argv:                      # a Monte Carlo seed: same file, seed and build -> same numbers
        k = argv.index("--seed")
        if k + 1 >= len(argv):
            usage()
        seed = argv[k + 1]
        argv = argv[:k] + argv[k + 2:]
    if len(argv) < 2 or argv[0] not in ("health", "parse", "analyze"):
        usage()
    verb, base = argv[0], argv[1].rstrip("/")
    check_base(base)
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
    url = base + "/" + verb
    if seed is not None and verb == "analyze":
        # on the URL, not as a form part: a text part without a
        # Content-Type is dropped by the service's multipart parser
        # (found 2026-09-05), and the query string always arrives
        url += "?seed=" + urllib.parse.quote(str(seed), safe="")
    body, ctype = multipart(fields, "file", path)
    req = urllib.request.Request(url, data=body, method="POST",
                                 headers={"Authorization": "Bearer " + token,
                                          "Content-Type": ctype,
                                          "Content-Length": str(len(body))})
    t0 = time.time()
    try:
        with _opener.open(req, timeout=900 if verb == "analyze" else 300) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:      # 4xx/5xx still carry a JSON body
        if redirected(e):
            sys.exit(1)
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
            v = b[key] if isinstance(b[key], list) else [b[key]]   # unboxed JSON: one reason is a string
            print("  %s: %s" % (key, "; ".join(str(x) for x in v)))
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
