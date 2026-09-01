# Handoff — morning of 2026-09-01

Written 2026-08-31 by Claude Code (Opus 5) at Steve Shafer's request.
Read this, then [`ISSUES.md`](ISSUES.md) "Where things stand", then
[`AGENTS.md`](AGENTS.md).

---

## 1. What changed yesterday, in one paragraph

Every scattered corpus on this machine and the three Linux nodes was
coalesced into **one accession-numbered library at `C:/dev/Corpus`** —
20,000-odd works, ~40,000 files, ~29 GB — with a master index that
decides what may be shared. Five PRs merged (#127, #128, #130, #131,
#132). One PR is open (#133). Three download workers are running. The
library is backed up to OneDrive as sharded zips, refreshed nightly.

**Read the library's own [`README.md`](file) at `C:/dev/Corpus/README.md`
before touching it** — it explains the accession scheme, the share
classes, and why `identity.csv` is held back.

## 2. The single most important thing to know

**Five defects were found yesterday and every one of them failed by
looking like success.**

| defect | how it presented |
|---|---|
| NCBI ID converter moved | reported a clean run having resolved *zero* |
| `match(NA, …)` on a blank key | gave 3,149 confidential manuscripts a real stranger's name; coverage read a perfect 17,035/17,035 |
| accession reuse | two different works given the same permanent name |
| backup skipped `.docx`/`.xlsx` | every volume it *did* write succeeded, so the log read green |
| a source going missing | would have silently shrunk the index |

None was caught by a test failing. They were caught by **a number being
too good**, and by reading a code review before merging rather than
after. The corresponding guards are now in the scripts (`safeMatch()`,
positive *and* negative controls, an accession-collision assert, abort on
missing source, abort on failed hash). Add the same discipline to
anything new: **if a coverage figure jumps to 100%, treat it as a defect
report.**

## 3. Open work, highest value first

### 3a. The unaudited joins — do this first
`corpus/*.R` joins on PMIDs, PMCIDs and DOIs in many places, and **those
joins have not been audited** for the `match(NA, …)` defect. In R,
`match(NA, table)` returns the position of the first `NA` in the table
rather than missing, so any join whose right-hand key can be blank
silently mis-assigns. Figures already produced by those scripts — some
quoted to editors — may carry it. `safeMatch()` in
`corpus/buildCorpusLibrary.R` is the fix to copy.

### 3b. Finish PR #133
Open, contains the node-list fix, the ctgov-docs source, and the
accession-collision fix. Steve asked for it to be merged when green.
Verify the rebuild is clean, then merge. Check CodeRabbit comments
**before** merging.

### 3c. Never built, still scoped
- `corpus/buildAnalysisFrame.R` — a watcher died mid-run; never rebuilt
- the discipline-stratified test of Steve's allocation-subversion hypothesis
- the over-dispersion adjudicator
- issue 30's frozen regression corpus — now has material to freeze
- matched honest nulls for continuous-only vs categorical-only (promised to Barnett)

## 4. The corpus library

```
C:\dev\Corpus\
  index\     master.csv (shareable) · identity.csv (RESTRICTED) · works.csv
             accessions.csv · accessionsRetired.csv · collections.csv
             sources.csv · licences.csv · hashCache.csv · BUILD.json
  master\    pdf\ xml\ txt\ docx\ xlsx\   — <accession>.<ext>
  registry\  ctgov\ carlisle-tables\      — real filenames, not accessioned
  _source\   as-downloaded trees, original names and manifests
```

Every file in `master/` is a **hard link**, so the tree costs no extra
disk and deleting either name is safe.

**Formats join on the filename.** `master/pdf/IA004512.pdf` and
`master/xml/IA004512.xml` are the same work by construction — that is the
whole point of the exercise, and 6,565 works hold both.

### Sharing is decided by the index, never by a person
`corpus/extractShareable.R` copies a file if and only if `master.csv`
says `FILE_SHAREABLE`. **If a licence is wrong, fix the index** — never
special-case the extraction, because the index is what can be audited
afterwards. `identity.csv` is excluded from every tier unconditionally,
with no flag to override: turning an accession back into a named paper is
a decision Steve makes one paper at a time, so the author can be heard
before anything is said about them.

The A&A peer-review manuscripts are `confidential` — **neither the file
nor a per-item derived row leaves this machine.** Pseudonymising the
index does not change that: the accession hides identity in a *table* and
does nothing about the authors printed inside the PDF.

## 5. Machines

| host | role | state at handoff |
|---|---|---|
| **newryzen** | this Windows box — the corpus lives here | it is *not* a compute node; it was listed as one in error |
| **oldryzen** | compute node | up; **idle, and correctly so** — see below |
| **i5** | compute node | up; finished — result below (`~/expandpmc.log`) |
| **surface** | compute node | up; downloading ctgov documents, 3,000 → 20,000 (`~/ctgdocs2.log`) — the only productive download |

### The PMC route is exhausted, and that is a finding, not a failure

`~/expandPmc.R` on i5 resolved all 14,576 trial-linked PMIDs: **7,709 have
a PMC record, and all but 2 are already in the corpus.** oldryzen
reporting `to fetch: 0` was not a broken worker — there is genuinely
nothing further to fetch down this route. Do not restart it expecting
volume; find a new target list first.

(The script's final step also used the wrong S3 layout — the metadata
JSON path it guessed 404s. The correct object is
`<bucket>/<PMCID>.<version>/<PMCID>.<version>.<ext>`, which
`~/fetchPmc.sh` on oldryzen gets right. Immaterial here, since there were
only 2 new records, but fix it before reusing the script.)

**Genuinely useful overnight work for oldryzen**, if wanted: parse the
3,000+ ClinicalTrials.gov protocol/SAP PDFs and measure what fraction
yield an extractable baseline table. That tests the parser against a
document type it has never seen, and it decides whether the 1,068
protocol-plus-results trials are actually usable. Needs the files copied
over (~5 GB) and no new credentials.

R scripts on the nodes **must run from `~/IntegrityAnalysis`** so the
repo's `.Rprofile` activates renv — the packages are not in the default
library, and a script run from `~` dies on `library(jsonlite)`.

### Scheduled, unattended
- **04:00 `IntegrityAnalysis corpus library`** — `tools/ingestNodes.ps1`:
  pull from the nodes, reindex, resolve identities, refresh the zips.
  **Tonight it rewrites all ~23 GB once** (the backup signature changed);
  after that it is incremental. Check
  `C:\dev\Corpus\index\ingest.log`.
- **03:00 `IntegrityAnalysis corpora backup`** — the older file-by-file
  robocopy of the raw source trees. Still useful: it carries the
  manifests and `idSalt.txt`, which the library does not.
- **21:00 security screen** — unchanged.

## 6. Audit results (2026-08-31)

**Repo, local and GitHub: clean.** The repository is **public**, so
history matters as much as HEAD. Only `Example.xlsx`, `Template.xlsx` and
the user-guide PDF have ever been committed. No Carlisle data, no corpus
PDFs, no A&A manuscripts, no key material, no API-key patterns. Branches
are tidy (PR branches deleted on merge). Actions secrets are the two
deploy credentials. The library is *outside* the repository, so git
cannot commit it even by accident.

**Corpus:** see `corpus/auditCorpus.R` output. The audit found one real
gap — `corpus/TEST`'s 61 parser-development PDFs were missing because the
`regression-fixtures` source was declared non-recursive — now fixed.

**Known and deliberate omission: PubTables-1M.** 93,835 XML/JSON files in
`C:/temp/pubtables1m`, named in `AGENTS.md` as the corpus to run *first*
for geometry regression. It is a third-party Microsoft dataset (CC BY),
not our material, and it is distributed as tarballs. It is referenced but
**not** in the library. Decide deliberately whether to fold it in; do not
assume it is there.

## 7. For the Adrian collaboration

Numbers straight from the index:

- **6,269 trials** with both a redistributable PDF and publisher XML
- **47,813 registry trials** with posted baseline results — a US
  Government work, public domain, shareable in full
- **1,068 trials** with a posted protocol/SAP *and* posted baseline
  results — what the sponsor *planned* beside what they *reported*. New
  as of yesterday; no other collection here supports that comparison
- 6,927 works where the numbers travel but the file does not
- 3,149 works where nothing leaves

**State the caveat rather than let him find it:** the head-to-head set is
PMC open-access, so it skews recent and open-access, and is not a random
sample of the literature. The Carlisle corpus — the only one with
printed-value ground truth — sits almost entirely in the restricted tier.
The natural division is that he works method-versus-method on the
shareable XML/PDF set, while value-accuracy work stays here and travels
as numbers.

Multi-source overlap *between* collections is only 42 works, and almost
all of those are a collection overlapping a subset of itself. Carlisle
against PMC is a **single** work. So issue 30's multi-source disagreement
signal has very little to work with across collections; the real
cross-check is the PDF-vs-XML pairs within PMC.

## 8. Steve's standing preferences

- Small, focused commits; one issue per PR; branch from `main` only;
  never stack PRs; push immediately after committing
- Verbose comments, including where code came from and its review status
- Write "GitHub Actions checks", not "CI"
- Read CodeRabbit comments **before** merging
- Stage copies in `tempdir()` before uploading in tests — the purge
  handler deletes uploaded paths
- Windows CLI quoting breaks on embedded quotes: use `-F`/`--body-file`,
  and never edit a script while `Rscript` is streaming it
