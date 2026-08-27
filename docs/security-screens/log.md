# Screen adjudication log

One line per finding, newest first. Raw reports are local and
gitignored (see [README](README.md)); this is the public record of what
was found and what was decided.

| date | finding | severity | outcome |
|---|---|---|---|
| 2026-08-27 | `journalTables` expands super-linearly in the input, so the `/analyze` input gates did not bound the response — a legal table becomes a multi-hundred-MB build on a single-threaded service | high | **fixed** — `.apiMaxJournalCells` bounds the estimated output before anything is built; pinned by tripwire group 5 and a direct test of `.apiJournalCells` |
| 2026-08-27 | `.apiCsvSafe` sanitized cell values but not column names | low (defense in depth — headers are positional literals, *not* a live exploit) | **fixed** — names sanitized; tripwire assertion anchored `^[^#]*` after the first version passed on a commented-out line |
| 2026-08-27 | AGENTS.md still claimed the AI fallback is off in deployment and manuscript text never reaches an LLM — false since the bring-your-own-key assist (issue 8, PR #67) | documentation | **fixed** — corrected, and model output is now stated to be untrusted input |
