# Reproducing the 2026-09-10 independent statistical audit

The [report](../2026-09-10-independent-statistical-audit-chatgpt.md) audits **ae37f0ee06d017d742049b7ab56ba79f2e39c99d**. Everything used as trial data here is synthetic. Application source was read and executed, not patched.

## Principal evidence

| Finding or question | Script | Authoritative output / fixture |
|---|---|---|
| F1: zero snap changes the trial null | `snap-reference.R`, with `followup.R`'s `three-row-snap` unit | `snap-reference.txt`, `snap-reference.rds`, `three-row-1e+07.csv`, `three-row-snap.txt` |
| F2: omitted exact best/worst | `rank-search.R`, `final-routes.R`'s `oracle-through-selector` unit | `rank-search.csv`, `rank-183.rds`, `rank-153.rds`, `oracle-through-selector.txt` |
| F2 through actual documents | `followup.R`'s `parser-cases` unit | `page-183.xml/.docx`, `page-153.xml/.docx`, `parser-cases.txt` |
| F3: unresolved coverage lost | `flags-and-checks.R`, `final-routes.R`'s `document-api-handlers` unit | `flags.xml/.docx`, `flags-routes.txt`, `document-api-handlers.txt`, `document-handler-flags.rds` |
| F4: lowercase trial header | `followup.R`'s `actual-api-handlers` unit | `precision-lowercase.csv`, `actual-api-handlers.txt`, `handler-lowercase.rds` |
| F5: selection loss versus estimation bias | `selection-noise.R` | `selection-noise-183.txt`, `selection-noise-153.txt`, `selection-noise-181.txt`, corresponding RDS checkpoints |
| Repaired zero ties; precision; gates; chunks | `probes.R` | `zero-snap.txt`, `precision.txt`, `gates-and-chunks.txt` |
| Straddle seam checks | `final-routes.R`'s `straddle-routes` unit | `straddle-routes.txt`, `straddle.xml/.docx` |
| Baseline tests and security tripwire | `flags-and-checks.R`'s `baseline-checks` unit | `baseline-checks.txt`, three `*.results.rds` files |
| Runtime versions | `probes.R` metadata; `flags-and-checks.R` version-audit | `metadata.txt`, `versions.csv`, `version-audit.txt`, `library-packages.txt` |

The three test files recorded 29 + 39 + 53 = **121 successful assertions**, with two skips in `test-failsafe-table.R` and no failed expectations. The tripwire checked 30 watched R files across eight groups. The full package suite was not rerun.

`metadata.txt` initially compares version strings literally, which flags R's equivalent hyphen/dot spellings. **Use `versions.csv` for the normalized comparison.** All present locked packages match. Eleven lockfile entries are absent from the copied runtime closure, including plumber; the handler functions were executed directly from their source expressions, without an HTTP server. Unicode/locale warnings are recorded in `version-audit.txt`.

## Recreate the isolated environment

Commands below assume the same repository location and R 4.5.3. If replaying elsewhere, update `root`/`od` in the scripts. Do not switch the shared checkout's branch.

```powershell
Set-Location C:\dev\IntegrityAnalysis
New-Item -ItemType Directory -Force .audit-2026-09-10 | Out-Null
git archive --format=zip --output=.audit-2026-09-10/source.zip ae37f0ee06d017d742049b7ab56ba79f2e39c99d
Expand-Archive .audit-2026-09-10/source.zip .audit-2026-09-10/source -Force
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' --vanilla docs/audits/evidence-2026-09-10/setup.R
```

`setup.R` copies the dependency closure from the existing project renv library, with the user's 4.5 library as a fallback for development tools. It never installs into or alters either shared library. Reading those libraries required sandbox escalation in the original run. If the installed versions have changed, restore the archived `renv.lock` into a private library first; a new run's normalized version comparison must match the supplied `versions.csv` for comparable results. The temporary source/library tree is disposable and can be recreated by these commands.

Scripts load that private library and the exact archived package in `common.R`. They never load the current checkout's package code. The base-R-only `rank-search.R` and `selection-noise.R` do not need the package or copied dependencies.

## Replay units

For short focused units:

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' --vanilla docs/audits/evidence-2026-09-10/followup.R three-row-snap
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' --vanilla docs/audits/evidence-2026-09-10/snap-reference.R snap-reference
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' --vanilla docs/audits/evidence-2026-09-10/final-routes.R oracle-through-selector
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' --vanilla docs/audits/evidence-2026-09-10/followup.R parser-cases
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' --vanilla docs/audits/evidence-2026-09-10/followup.R actual-api-handlers
```

Unit scripts accept unit names after the script path; omitting them runs all units in that script. Run `probes.R` first to recreate its precision fixtures if starting with scripts only. Run `flags-and-checks.R flags-routes` and `final-routes.R straddle-routes` before `final-routes.R document-api-handlers` if recreating those fixtures from scratch.

Longer batches were launched detached using this pattern (substitute the script name):

```powershell
$auditDir = 'C:\dev\IntegrityAnalysis\docs\audits\evidence-2026-09-10'
$auditRun = Start-Process -FilePath 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
  -ArgumentList '--vanilla', "$auditDir\rank-search.R" `
  -WorkingDirectory 'C:\dev\IntegrityAnalysis\.audit-2026-09-10\source' `
  -WindowStyle Hidden `
  -RedirectStandardOutput "$auditDir\rank-search-console.txt" `
  -RedirectStandardError "$auditDir\rank-search-stderr.txt" -PassThru
Get-Process -Id $auditRun.Id
Get-Content "$auditDir\rank-search-console.txt" -Tail 10
```

The first real rank-search case completed in under a second; each candidate configuration writes its own `rank-NNN.rds`, including NULL for filtered-out configurations. **230 configurations were visited; 171 were evaluated.** The selection-noise experiment checkpoints every 200 independent selection repetitions and writes a final text summary for each shape. The integrated parser probe completed a case within seconds; document request-handler runs completed in about 17 seconds. The three test files and tripwire took about 84 seconds. These are observed times on this machine, not portable performance guarantees.

The original launches were checked for a live PID and then for actual output. None remains running. If a replay produces no first output after twice the measured expectation, inspect its stderr/process before proceeding. For a long replay, check at two and ten minutes, then every fifteen; unchanged output for two checks or a vanished process requires investigation. The original runs completed before those longer monitoring intervals were needed.

`rank-search.R` resumes by skipping existing `rank-NNN.rds`; rerunning it with the saved checkpoints performs no new search. Use a fresh output directory for an entirely new search. `selection-noise.R` reruns its three configurations from the stated seed; it overwrites each configuration's checkpoint and summary. Other scripts can resume at a named unit. Preserve this evidence directory before rerunning if you want to retain the original outputs and hashes.

## Reference and fixture notes

The 2×2 oracle uses hypergeometric probabilities and **integer absolute determinants** for within-null tail order and ties. Its cross-null Pearson ranking is explicit in the saved frames. Case IDs refer to the deterministic search plan, not corpus accessions. Case 183's earliest maximizing group ranks 85; case 153's earliest minimizing group ranks 313. The exact-oracle substitution runs the production grouping and pruning code with noiseless scores, then lifts only its group-ranking cutoff; this isolates pruning from Monte Carlo selection noise.

The F1 reference keeps the actual final simulated statistics before snapping. Equal arm sizes and the printed grid allow their ranks to be reconstructed from integer distances. The saved RDS contains all three arrays, integer distances, observed row p-values and trial tail counts. No reference calculation uses the production zero tolerance.

The initial exploratory `rank-case-*.xml` fixtures put N inside a combined header; those parses did not have N available when the category conversion ran. They are retained with their outputs, **not used as successful parser evidence**. The authoritative `page-*.xml/.docx` fixtures have an explicit N line and are generated by the final `parser-cases` unit. Case 147 remains an exploratory direct-selector example: its all-zero percentage level is not preserved by the tested document parser, so its larger worst-case discrepancy is not used as the report's document-route finding. These limitations are why cases 183 and 153 were carried through separately.

Some console logs contain early harness syntax/dimension errors subsequently corrected in the saved scripts and rerun. The per-unit outputs listed in the principal-evidence table are the completed runs cited by the report. They are the authoritative results; the final selector-oracle output, in particular, is `oracle-through-selector.txt`.

The report, brief, scripts, fixtures, and outputs are hashed in `SHA256SUMS.txt`. Temporary copies of the R library and source are not evidence artifacts and are excluded.
