# Audits

Independent audits of the statistical engine and the documentation, one
markdown file per audit, kept verbatim as they were delivered (with any
erratum the auditor added afterwards) so that a reader can see what was
asked, what was found, and what was done about it. The engine's response
to each finding is recorded in [method-history.md](../method-history.md)
and, for the documentation findings, in the pull request that fixed them.

| Date | Auditor | File | Scope |
|---|---|---|---|
| 2026-09-11, final-brief pass | Codex, independent | [2026-09-11-final-independent-statistical-audit-chatgpt.md](2026-09-11-final-independent-statistical-audit-chatgpt.md) | Full engine at 7fd6545; 1,820 passing regression assertions, independent numerical references and loopback HTTP; one numerical P2: category relabeling splits equivalent null laws and moves a trial across 0.01; original full-pass fixtures remain fixed; findings await adjudication |
| 2026-09-10, full pass | Codex, independent | [2026-09-10-full-independent-statistical-audit-chatgpt.md](2026-09-10-full-independent-statistical-audit-chatgpt.md) | Full engine at a796e51; 1,631 passing regression assertions, independent categorical/continuous/median references and live loopback HTTP; discrete combination uncertainty crosses 0.01, entirely excluded trial coverage, and structural issue JSON-null contract; findings await adjudication |
| 2026-09-10 | Codex, independent | [2026-09-10-independent-statistical-audit-chatgpt.md](2026-09-10-independent-statistical-audit-chatgpt.md) | Engine and documentation at ae37f0e; integer-distance trial reference, exact ranked-selection counterexamples, selection-bias experiment, unresolved coverage and API round trips; F1 fixed (#246), F3 (#250), F4 (#247; its API-contract half in the structural-issues change), the read-across (#249); F2 and F5 adjudicated as a heuristic and documented as one (method-history, 2026-09-10) |
| 2026-09-09 brief (executed 2026-09-08) | GPT-6 (Codex), independent | [2026-09-09-independent-statistical-audit-chatgpt.md](2026-09-09-independent-statistical-audit-chatgpt.md) | Engine and documentation at 9d5ef88; whole-table reconstruction, precision, zero floor, selection uncertainty and decision rationale; F1-F5 and F7-F9 adjudicated in PR #230, F6 (the zero floor) held back for its own change and its own measurement |
| 2026-09-08 | GPT-6 (Codex), independent | [2026-09-08-independent-statistical-audit-chatgpt.md](2026-09-08-independent-statistical-audit-chatgpt.md) | Engine and documentation at 088a78c; independent arithmetic, percentage reconstruction, precision guards, export disclosures and decision rationale; findings await adjudication |
| 2026-09-07 | GPT-6 (Codex), independent | [2026-09-07-independent-statistical-audit-chatgpt.md](2026-09-07-independent-statistical-audit-chatgpt.md) | Statistical engine at ae81725; exact categorical enumeration, input/output defects, synthetic calibration and sensitivity; findings addressed in the subsequent method-history entries |
| 2026-09-06 | Claude Code (Claude Fable 5.1), in-session | [2026-09-06-statistical-and-documentation-audit-claude.md](2026-09-06-statistical-and-documentation-audit-claude.md) | `R/P_Calc.R` robustness and accuracy; every markdown, HTML and docx document |

Reports from other reviewers (a Gemini statistical review and a ChatGPT
engine audit, both 2026-09-06) are to be added here as their own files
when their text is supplied; the findings they raised and how each was
resolved are already recorded in method-history.md (the 2026-09-06
entries) and in the security-screens log.
