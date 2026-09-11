# Fourth full statistical audit — execution evidence

Target: **`7c6583f7190ce581ab157b8f931ef5f39eba3789`**. Report: [fourth full audit](../2026-09-11-full2-independent-statistical-audit-chatgpt.md). The [brief](review-brief.md) supplies the scope and exclusions. All inputs are synthetic. No production or live AI request was made; source and dependency library were unchanged.

## Runtime and reproduction

Use R **4.5.3**, locale **C**, and the target's locked dependencies plus the test tools. Set:

- `INTEGRITY_AUDIT_SCRATCH`: a scratch directory with an isolated target checkout in `source`.
- `INTEGRITY_AUDIT_OUTPUT`: a fresh directory containing these scripts.
- `INTEGRITY_AUDIT_LIBRARY_SOURCE`: the existing dependency library.
- `INTEGRITY_AUDIT_REUSE_LIBRARY=true`: inventory the library without copying or updating it.

Run every R entry point with `Rscript --vanilla`, from the source checkout. `common.R` selects the library, attaches shiny/dqrng/foreach/Rfast/MBESS, loads the source, clears AI credentials, disables comment echo and enables real-HTTP tests. All **121** locked package versions match. `runtime.txt` and the package CSVs record the environment. Python 3 with **NumPy** is needed for the new independent simulation; the exact categorical enumerator uses only Python's standard library. No SciPy is required.

Run `setup.R` first. Then:

1. `regressions.R`: 50 files, with a per-file checkpoint. `finalize-evidence.R` aggregates these later.
2. `permutation-checks.R`, `same-draw-permutation.R`, `transpose-checks.R`, `same-draw-transpose.R`: old categorical findings, freshly re-executed.
3. `trial-id-checks.R`, `trial-id-reference.R`: old length-boundary fixtures and full-ID template/quadrature control.
4. `independent.R`, then `additional-checks.R`, then `analytic-checks.R`. Run `median-reference.R` and `direct-grid-reference.R` separately.
5. `enumerate-laws.py`, then `multilevel-permutations.R`; also `arm-key-checks.R`.
6. `http-routes.R` after the permutation/transposition fixtures; `http-trial-id.R` after the identity fixtures and reference. Each starts a local authenticated service and stops it on exit.
7. `unique-law-comparison.R` twice: first with `INTEGRITY_AUDIT_COMPARISON_TAG=target`; then with that tag `old` and `INTEGRITY_AUDIT_SOURCE` pointing to a checkout of **`6db32ee0ea8333870709e52af7ff109299c08da4`**. Unset the source override afterwards. Run `supplemental.R` after both versions finish. No other check uses an old source.
8. `warning-details.R` records the raw-gzip warnings without double-counting its assertions.

For the new findings:

1. **F1:** `symmetric-null-checks.R` runs nine initial cases; `symmetric-refined.R` runs 12 focused cases. `symmetric-event-check.R` checks the focused actual draws by integer trial events and records two additional dispersion-key examples. `symmetric-independent-reference.py` independently generates two million row draws for each of three laws, computes exact event-polynomial trial probabilities from the estimated masses, and supplies simultaneous reference uncertainty bounds. Run `http-symmetric-null.R` after the focused fixtures.
2. **F2:** `trial-id-namespace.R` generates the collision, template and short/repeated-ID controls. Run `http-trial-id-namespace.R` afterwards for six real HTTP requests.
3. Finally run `finalize-evidence.R` and `verify-artifacts.py`. The latter checks report/README links, scans text for machine-local paths and writes `sha256.csv`. The R check inspects all serialized data and rejects functions, environments and local paths.

The scripts create new results; older evidence was not copied as newly executed data. Source filenames inherited from earlier audits are retained to make comparisons easy.

## Launch, checkpoints and monitoring

Longer R runs were launched detached with hidden windows, separate stdout/stderr under scratch, and the target checkout as working directory. The first full-size unit was the smoke test. A portable PowerShell pattern, with `$rscript` supplied as the R 4.5.3 executable:

```powershell
$job = 'regressions'
$script = Join-Path $env:INTEGRITY_AUDIT_OUTPUT ($job + '.R')
Start-Process -FilePath $rscript -ArgumentList @('--vanilla', ('"' + $script + '"')) `
  -WorkingDirectory (Join-Path $env:INTEGRITY_AUDIT_SCRATCH 'source') `
  -WindowStyle Hidden `
  -RedirectStandardOutput (Join-Path $env:INTEGRITY_AUDIT_SCRATCH ($job + '.stdout')) `
  -RedirectStandardError (Join-Path $env:INTEGRITY_AUDIT_SCRATCH ($job + '.stderr')) -PassThru
```

Expected first output: under 15 seconds for the regression/categorical units, under a minute for a median reference. The fail-safe regression file can take about 90 seconds. Check the process and output, then progress at two and ten minutes, rather than treating a returned PID as success. The recorded reference sequence completed in under eight minutes. No audit job remained running at final verification; all audit HTTP services were stopped.

`regressions.R` and the older permutation generator skip completed checkpoints on relaunch. The new independent Python simulation writes a checkpoint every 100,000 row replicates and completes one whole row law at a time; rerunning it regenerates its three laws from seed 9173. Other short scripts rerun from the beginning. For a fully fresh repetition, use a new output directory. Do not mix results from different source commits in one directory except for the explicitly named old/target comparison files.

## Reading the principal evidence

| Files | What they establish |
|---|---|
| `regression-totals.csv`, `regression-summary.csv`, `regression-exceptions.csv` | **1,979** passing assertions, zero failures/errors, three skips, three warnings; **50** files, **293** blocks. |
| `same-draw-transpose.csv`, `permutation-results.csv`, `trial-id-comparisons.csv` | The previous reported fixtures are still fixed. |
| `symmetric-null-comparisons.csv`, `symmetric-refined-comparisons.csv` | Every new exploratory/focused p, displayed CI and actual M; key counts and finite-draw reference counts. |
| `draws-symmetric-*.rds` | Actual simulated integer statistics and production summary counters; data only, no executable closures. |
| `symmetric-integer-events.csv` | Independent integer classification of each focused trial; agrees with the common pooled-rank reference. |
| `symmetric-independent-reference.csv` | Independent PCG64 row-law estimates, event-polynomial trial probabilities, simultaneous Hoeffding bounds and bounded score-order ratios. These are reference uncertainty bounds, not app intervals. |
| `http-symmetric-null-summary.csv`, corresponding JSON replies | Both F1 threshold-crossing cases on the real API; the untraced returned probabilities equal the traced handler results. |
| `trial-id-namespace-identities.csv` | Full distinct input IDs and their identical generated/literal output spelling. |
| `trial-id-namespace-comparisons.csv` | Collision plus three controls, including explicit trial count, displayed trial intervals and actual M. |
| `http-trial-id-namespace-summary.csv`, corresponding JSON replies | Six parse/analyze calls proving the collision already occurs in parsing and has no flag. |
| `independent-comparisons.csv`, `median-reference-comparisons.csv`, `direct-grid-reference.csv` | Fresh independent checks of the other row models. |
| `multilevel-comparisons.csv`, `arm-key-comparisons.csv` | Expanded categorical and arm-order checks with integer references. |
| `old-target-comparison.csv`, `pool-expectation.csv`, `staged-interval-coverage.csv` | Preserved outputs and independent mapping/stopping calculations. |
| `serialized-evidence-check.txt`, `source-verification.txt`, `sha256.csv` | Serialized-content checks, exact source identity and content manifest. |

A blank engine CI means **not displayed**, never zero uncertainty. Same-draw integer references and their count intervals are distinct from independent population-reference estimates. Statistical equivalence here concerns the implemented row model; it is not evidence that the row model describes every real clinical variable.
