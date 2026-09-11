"""Codex, 2026-09-11: validate evidence links, literal paths and content hashes."""
from pathlib import Path
import csv
import hashlib
import re

evidence = Path(__file__).resolve().parent
report = evidence.parent / "2026-09-11-full-independent-statistical-audit-chatgpt.md"
for document in (report, evidence / "README.md"):
    for target in re.findall(r"\]\(([^)]+)\)", document.read_text(encoding="utf-8")):
        if "://" not in target:
            assert (document.parent / target.split("#")[0]).exists(), target
files = sorted(p for p in evidence.iterdir() if p.is_file() and p.name != "sha256.csv")
for path in files + [report]:
    if path.suffix in {".R", ".md", ".csv", ".txt", ".json", ".py"}:
        content = path.read_text(encoding="utf-8-sig")
        assert not re.search(r"(?<![A-Za-z0-9])[A-Za-z]:[/\\]", content), path.name
with (evidence / "sha256.csv").open("w", newline="", encoding="utf-8") as output:
    writer = csv.writer(output)
    writer.writerow(["file", "bytes", "sha256"])
    for path in files + [report]:
        data = path.read_bytes()
        writer.writerow([path.name if path.parent == evidence else "../" + path.name,
                         len(data), hashlib.sha256(data).hexdigest()])
print(f"Verified links and text in {len(files)} evidence files; SHA-256 manifest written.")
