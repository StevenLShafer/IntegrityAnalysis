# Reproducible evidence for the 2026-09-09 audit brief

Origin: GPT-6 (Codex), at Steve Shafer's request. Executed 2026-09-08 in `C:/dev/IntegrityAnalysis`, commit `9d5ef888131f9322ec410710cd5cfca3af038cc4`, Windows 11, R 4.5.3. This directory contains synthetic data only. [The report](../2026-09-09-independent-statistical-audit-chatgpt.md) distinguishes execution, code inspection and recommendations. [The supplied brief](review-brief.md) is archived as received.

No application edits, package installs, library restores, branch changes or deployment were made. The scripts load the working package, so reproducing the historical results requires the audited commit. The current shell must be in this repository, not another renv project. `metadata.txt` records the actual session; startup's renv out-of-sync and locale/package-loading warnings are preserved in console/stderr logs. The successful targeted tests do not certify that every lockfile entry matched the installed library.

## Scripts and authoritative outputs

| Script | Evidence | What was executed |
|---|---|---|
| `probes.R` | `per-arm-cap.txt`, `selector-ties.txt`, `text-roundtrip.txt`, `bounded-dimensions.txt`, `metadata.txt` | Actual parser and upload reader; engine comparisons; independent small-table enumeration; intercepted allocation dimensions |
| `references.R` | `references.txt`, `nonexhaustive.rds` | Exact lower-tail probabilities for F1/F2, integer comparisons for ties; 768-case non-exhaustive grouping search |
| `partition-and-precision.R` | `partition-and-precision.txt` | Incomplete/complete partition examples; negative precision and scientific notation |
| `zero-reference.R` | `zero-reference.txt` | Feasible integer raw sample; million-draw rounded-data reference using integer sample sums; engine comparison; earlier origin/unit fixture |
| `zero-and-noise.R` | `selection-noise.txt`, `large-noise.txt` | Exact binary oracle, 60 small and 30 larger selector runs; optional exploratory zero sweep |
| `noise-three.R` | `noise-three.txt`, `noise-three-unequal.txt` | Exact three-category oracle, 60 seeds for each pair of arm sizes |
| `parse-reproducibility.R` | `parse-reproducibility.txt` | Same synthetic PDF, two extraction seeds, same subsequent analysis seed |
| `bounded-sampling.R` | `bounded-sampling.txt` | Eight-arm synthetic PDF; successful bounded sampling; independent sequential hypergeometric reference for selected and valid alternative counts |
| `trial-proxy.R` | `trial-proxy.txt` | Exact finite row nulls and Stouffer convolution; default engine; explicitly instrumented single-batch engine copy |
| `verification.R` | `verification.txt`, `verification.rds` | Six regression files, 140 assertions, zero failures/errors/skips |

The `.R` files are the complete executable inputs; data frames and parameters are constructed there. Their same-name `.txt` outputs (or named unit outputs for `probes.R`) are the primary evidence. PDFs and spreadsheets are retained next to the scripts that construct them; parser-result RDS files retain the returned metadata.

The default engine comparisons set both generators to 42 and pass `m=100000`; actual `M` and every interval the engine emits are printed. Selection uses base R, with seeds specified per run. The independent zero reference uses base seed 19371 and B=1000000. Bounded reference seeds are 8821/8822 and B=200000. Exact probabilities require no random seed or Monte Carlo interval. `trial-proxy.R` explicitly labels its diagnostic function copy: changing its stage assignment to one batch is not a claim that production `m=100000` forces that batch.

## Running and resuming

For the short probes, from PowerShell in the audited repository:

```powershell
$auditRscript = 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe'
& $auditRscript docs/audits/evidence-2026-09-09/probes.R selector-ties text-roundtrip bounded-dimensions metadata
& $auditRscript docs/audits/evidence-2026-09-09/partition-and-precision.R
& $auditRscript docs/audits/evidence-2026-09-09/parse-reproducibility.R
& $auditRscript docs/audits/evidence-2026-09-09/verification.R
```

Run longer calculations detached. This example is also the larger seed study's resume command:

```powershell
$auditProc = Start-Process -FilePath $auditRscript `
  -ArgumentList 'docs/audits/evidence-2026-09-09/zero-and-noise.R','noise','large' `
  -WorkingDirectory 'C:/dev/IntegrityAnalysis' -WindowStyle Hidden `
  -RedirectStandardOutput 'docs/audits/evidence-2026-09-09/large-noise-console.txt' `
  -RedirectStandardError 'docs/audits/evidence-2026-09-09/large-noise-stderr.txt' -PassThru
Get-Process -Id $auditProc.Id
```

Each real larger-case seed took approximately 1.5–2.7 seconds after library loading and oracle preparation. Confirm the first `large-seed-001.rds` and console output, not merely the launcher's return. Check at two minutes, and investigate immediately if the process has gone or output remains unchanged. The other seed studies likewise checkpoint each seed and resume by skipping existing files:

| Script argument list | Checkpoints |
|---|---|
| `zero-and-noise.R noise` | `selection-seed-001.rds` through `060` |
| `zero-and-noise.R noise large` | `large-seed-001.rds` through `030` |
| `noise-three.R` | `three-seed-001.rds` through `060` |
| `noise-three.R unequal` | `three-unequal-seed-001.rds` through `060` |

Use the same launcher pattern for `probes.R per-arm-cap`, `references.R`, `zero-reference.R`, `bounded-sampling.R` and `trial-proxy.R`, with distinct log paths. Those are individual completed units rather than per-seed resumable studies. All launched audit processes were checked for completion.

**Preserve this record when testing a fix.** Scripts overwrite their own output files. Seed studies resume from existing RDS files, so running them unchanged in this populated directory does not recompute completed seeds. For a fresh computation, copy the relevant script, change its `od` assignment to a new empty directory, create that directory, and run the copy against the intended checkout. Do not mix historical checkpoints with a changed selector and call it a new validation.

## Development logs and limits

`probes-console.txt` includes initial harness-development failures: default CSV conversion changed the label `T` to TRUE, and the first category-only PDF did not trigger the intended table recognizer. The retained script resets only that trial identifier for the CSV comparison and adds a synthetic Age row to the PDF. `retry-console.txt` and the individual unit files record successful reruns. The independent selector enumeration was added and rerun subsequently; its final unit output is authoritative.

`zero-floor.txt` and `zero-extended.txt` are exploratory sweeps, not all certified feasible raw summaries. F6 relies on `zero-reference.R` and its explicit feasible raw sample, not on a possibly impossible exploratory summary. `bounded-dimensions.txt` deliberately ends each instrumented call with an allocation-intercept message; this demonstrates the attempted size without allocating billions of rows. In `partition-and-precision.txt`, both printed validation frames have ROUND_MEAN=0; the first engine call deliberately uses the original frame with -1, as `run(d,FALSE)` specifies.

No real trial or corpus manuscript was read. No population-wide false-alarm calibration or full package check was performed. Exact conditional enumeration and reference simulation establish the specific numerical claims; they do not establish how frequent these inputs are in submitted papers.
