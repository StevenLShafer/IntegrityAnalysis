# Security screens

Reports from `tools/securityScreen.ps1` — the change-gated deep screen
that runs nightly when the watched surface has moved. The reasoning
behind the schedule and the stopping rule is in AGENTS.md,
"Two instruments, two stopping rules".

## The reports are not committed, on purpose

This repository is **public**. A screen report describes findings
*before* they are fixed, so committing one would publish an unfixed
vulnerability together with a map to it. `screen-*.md` files are
gitignored and stay on the machine that ran the screen.

What gets committed is the **adjudication**, after the fix lands: the
code change, the tripwire assertion that pins it, and one line in
[`log.md`](log.md).

## Adjudicating a report

Every finding ends in one of two states before the next merge that
touches the watched surface:

- **Fixed** — with a `tools/securityCheck.R` assertion or a test that
  pins it, and that assertion **verified to fail on a deliberate
  break**. An assertion nobody watched fail is not evidence; one was
  written here that matched a commented-out line and passed on a break.
- **Accepted** — with a written reason in `log.md`. "Not reachable",
  "cost exceeds the risk", and "already covered by X" are all fine
  reasons. Silence is not.

The endpoint is *every finding adjudicated*, **not** "the next screen
comes back empty". The screen samples an opinion rather than measuring
a state, so it never converges to empty, and chasing an empty report
means patching things that were never wrong — which is how two of this
project's worst defects were introduced.

## Verifying a fix

Re-screen the **patch**, not the whole tree, and ask specifically
whether the fix broke a contract elsewhere. Both patch-induced defects
here were of exactly that shape: a sanitizer that made returned CSVs
safe also renamed variables and broke the round-trip contract.

```bash
pwsh tools/securityScreen.ps1 -Since <commit-before-the-fix>
```
