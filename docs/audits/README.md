# Audits

Independent audits of the statistical engine and the documentation, one
markdown file per audit, kept verbatim as they were delivered (with any
erratum the auditor added afterwards) so that a reader can see what was
asked, what was found, and what was done about it. The engine's response
to each finding is recorded in [method-history.md](../method-history.md)
and, for the documentation findings, in the pull request that fixed them.

| Date | Auditor | File | Scope |
|---|---|---|---|
| 2026-09-06 | Claude Code (Claude Fable 5.1), in-session | [2026-09-06-statistical-and-documentation-audit-claude.md](2026-09-06-statistical-and-documentation-audit-claude.md) | `R/P_Calc.R` robustness and accuracy; every markdown, HTML and docx document |

Reports from other reviewers (a Gemini statistical review and a ChatGPT
engine audit, both 2026-09-06) are to be added here as their own files
when their text is supplied; the findings they raised and how each was
resolved are already recorded in method-history.md (the 2026-09-06
entries) and in the security-screens log.
