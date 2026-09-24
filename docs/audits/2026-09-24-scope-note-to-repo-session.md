# Scope note to the "IntegrityAnalysis Repo" session

*Written 2026-09-24 by the Cowork session that produced the two audit
findings of this date. That session is ending; its work continues in a
Claude Code session named **IntegrityAnalysis Corpus**. Steve asked for
this note so the two sessions do not collide.*

## The boundary, from now on

| Tree | Owner | Other session may |
|---|---|---|
| `C:\dev\IntegrityAnalysis` | **you** | read only |
| `C:\dev\Fujii Boldt Reuben` | IntegrityAnalysis Corpus | read only |
| `C:\dev\Corpus` | IntegrityAnalysis Corpus | read only |
| `C:\Temp` | shared scratch, no ownership | — |

**You own the repository. Please do not edit anything under
`C:\dev\Fujii Boldt Reuben` again** — that includes `author_batch.R`,
`carlisle168_batch.R`, `ai_pass.R` and `diagnose_one.R`. They call the
package but they are corpus tooling, and the corpus session needs to be
able to change them without wondering whether you have.

This is not hypothetical. On 2026-09-24 we both patched
`author_batch.R` and `carlisle168_batch.R` within the same hour,
neither knowing the other was in the file. Your library-provenance and
0.2.0 version gate, and this session's seeding, checkpoint retention
and sub-path support, are all present in the current files — so nothing
was lost. That was luck, not coordination.

If you need a change in corpus tooling, say so in a document under
`docs/audits/` and the corpus session will make it. That channel has
worked well in both directions today.

## What the corpus session will send you

Findings as markdown under `docs/audits/`, indexed in
`docs/audits/README.md`, in the form of the two written today:
reproduction case, evidence, acceptance criteria, and the regression
tests that should be committed. It will diagnose, build failing cases,
and may push a branch. **It will not merge to main.** Adjudication and
merge remain yours.

The reason is written into today's history: this session asserted "27
rows" for PMID 11375852 with real confidence, having read Carlisle's
composite Table 1 rather than Fujii's actual page. Your session went to
the page and found 18 (6 variables x 3 arms). A corpus session sees the
failure; it does not see the 4,100 tests or why they are shaped as they
are. Keep the second pair of eyes.

## What needs doing now

1. **Nothing is blocked on this session.** Issue 35 / PR #336 stands on
   its own.

2. **The stale user library is Steve's to refresh** — the gate you added
   means both batch scripts now refuse to run below 0.2.0, which is the
   right behaviour. Nothing for you to do unless he asks.

3. **One item is explicitly yours and is not yet done:** the non-fatal
   `suspect` issue code for SD > MEAN, which you correctly declined to
   bolt onto the existing fatal codes. It needs an API-contract and
   grid-legend decision. The corpus session will keep meeting tables
   where a percentage has been read as a dispersion, and an advisory
   flag is what makes that visible without failing an honest skewed
   variable.

4. **Ground truth now exists and is not yet wired in.**
   `C:\dev\Corpus\registry\carlisle-tables\One Sheet Carlisle Data.xlsx`
   is Carlisle's hand-entered baseline data: 5,075 PMIDs, 72,141
   variable-arm rows (columns by letter, no header: B variable, C arm,
   D N, E mean, F SD, I PMID; continuous only, no labels). The overlap
   with the fraud corpora is extracted to
   `C:\dev\Fujii Boldt Reuben\Carlisle_handentry_ground_truth_2026-09-24.csv`
   - 39 Boldt papers, 20 Fujii, 12 Reuben, 1,365 rows.

   It is the only ground truth in this project not produced by the thing
   being tested. **The 39 Boldt papers have never been parsed**, so they
   are a genuine held-out set. Consider a standing regression that
   compares a parse against hand entry per (variable, arm) rather than a
   file someone remembers to consult.

5. **Two measurements are void and should not be cited** until re-run on
   a current library: `Carlisle168_results_2026-09-24.xlsx`, and the
   2017 validation run of 2026-09-24 (5,080 trials, r = 0.9903, 90.2%
   within 0.05, 99.0% concordance). This session reported that second
   one as evidence the issue-34 fix had landed well. It was produced by
   the 0.1.0 engine and says nothing about the fix. If it reached
   `docs/validation-ledger.md`, it needs removing or marking.

## One thing worth knowing about the corpus

It is no longer three fraud corpora. John Loadsman (editor,
*Anaesthesia and Intensive Care*) has sent three more author sets, and
more are likely. Papers now arrive in zip archives of mixed quality:
whole bound journal issues, macOS `._` stubs, duplicate copies of one
article, image-only scans, Japanese-language text, and in one case an
unpublished peer-review manuscript. Parser failures from that corpus
are worth taking seriously precisely because it is messier than
`corpus/TEST`.
