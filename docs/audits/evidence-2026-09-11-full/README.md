# Third full statistical audit — execution evidence

Target: `6db32ee0ea8333870709e52af7ff109299c08da4`. R 4.5.3, locale C; 121/121 locked dependency versions matched. All newly generated inputs are synthetic. No production request or live AI request was made. The source worktree and existing private dependency library were not modified.

The report is [2026-09-11-full-independent-statistical-audit-chatgpt.md](../2026-09-11-full-independent-statistical-audit-chatgpt.md). `review-brief.md` records the full scope and exclusions. `sha256.csv` inventories the final artifacts.

## Runtime and reproduction

Supply these environment variables externally; no machine-specific directory is embedded in the scripts:

- `INTEGRITY_AUDIT_SCRATCH`: a scratch directory containing the target worktree as `source`.
- `INTEGRITY_AUDIT_OUTPUT`: a fresh evidence directory containing these scripts.
- `INTEGRITY_AUDIT_LIBRARY_SOURCE`: the verified package library, including the test tools.
- `INTEGRITY_AUDIT_REUSE_LIBRARY=true` for `setup.R` to inventory that library without copying it.

Leave `INTEGRITY_AUDIT_SOURCE` unset for target checks. It is used **only** to select the previous `7fd654589ddbbaa5bf03e96aad2aecbca9576bb7` checkout for the two expressly historical comparisons below. Every R entry point is run with **Rscript 4.5.3 `--vanilla`**, from the target source directory. `common.R` selects the library, attaches the five required packages, loads the package, disables console echo and clears AI credentials. It enables the real-HTTP tests with `NOT_CRAN=true`.

Run `setup.R` first. The source is loaded from a real checkout, so prior regression fixtures and helper files resolve. The check deliberately does not restore or update packages.

For the principal findings:

1. `transpose-checks.R`, then `same-draw-transpose.R`. These generate the F1 fixtures and compare the actual draw outcomes against integer reference counts.
2. `trial-id-checks.R`, then `trial-id-reference.R`. These generate the F2 boundary cases and the full-ID template control and independently combine its trial probabilities by normal quadrature.
3. `permutation-checks.R`, then `same-draw-permutation.R`. These re-execute the preceding audit's 24 recoding cases and its four traces on the corrected commit.
4. `http-routes.R` after the transpose and permutation generators; `http-trial-id.R` after the trial-ID generator and reference. They start authenticated servers on loopback and stop them on exit. Random credentials remain in memory. They preserve the actual JSON reply representation, including nulls.

For the remaining coverage:

1. `regressions.R` runs the 48 selected regression files with per-file checkpoints. Use a fresh output directory to rerun completed files. `warning-details.R` is the separate focused replay that records the three raw-gzip fixture warnings; its assertions are not added again to the total.
2. Run `independent.R`, `median-reference.R` and `direct-grid-reference.R`. After `independent.R`, run `additional-checks.R`; then `analytic-checks.R`. The latter uses the 20 prespecified unequal-N F runs and independently measures mapping expectation and staged-interval coverage.
3. Run `enumerate-laws.py` with Python 3 (standard library only), then `multilevel-permutations.R`. The Python reference enumerates fixed-margin tables using exact rational arithmetic. The R script runs 28 parser/engine cases and compares every production trial count with an integer classification of the actual draws.
4. `arm-key-checks.R` runs 75 key-property checks and three CSV/analysis executions using integer-lattice reference ranks.
5. `unique-law-comparison.R` runs once with `INTEGRITY_AUDIT_COMPARISON_TAG=target`; then once with that tag `old` and `INTEGRITY_AUDIT_SOURCE` selecting **7fd6545**. `trial-id-pre-fix.R` also runs with that old source, after the current trial-ID fixture exists. Restore the target source by unsetting the override before continuing.
6. `supplemental.R` checks the mocked-transport AI conversion, exact categorical reference, free versus partitioned enumeration, prospective pool boundary, and reads the two versions' comparison results.
7. `finalize-evidence.R` aggregates the 48 nonoverlapping regression results and inspects RDS contents. `verify-artifacts.py` checks links and text for local paths and writes the hash manifest.

Longer jobs were launched detached with hidden windows and separate stdout/stderr files under scratch. A portable PowerShell launch pattern (supply `$rscript` as the R 4.5.3 executable) is:

```powershell
$job = 'regressions'
$script = Join-Path $env:INTEGRITY_AUDIT_OUTPUT ($job + '.R')
Start-Process -FilePath $rscript -ArgumentList @('--vanilla', ('"' + $script + '"')) `
  -WorkingDirectory (Join-Path $env:INTEGRITY_AUDIT_SCRATCH 'source') `
  -WindowStyle Hidden `
  -RedirectStandardOutput (Join-Path $env:INTEGRITY_AUDIT_SCRATCH ($job + '.stdout')) `
  -RedirectStandardError (Join-Path $env:INTEGRITY_AUDIT_SCRATCH ($job + '.stderr')) -PassThru
```

First-output expectations on this run: under 15 seconds for the first regression file or categorical fixture; under a minute for the first median reference. Individual fail-safe regression units can take about 90 seconds. The first completed full-size unit is the smoke test. Check its file and process, then the per-unit output, rather than treating a PID as success. `regressions.R` and `permutation-checks.R` skip completed checkpoints when relaunched; the other short experiments can be rerun from their beginning in a fresh output directory. All R processes from this audit had exited at final verification.

## Reading the evidence

| Files | Interpretation |
|---|---|
| `transpose-comparisons.csv` | All 24 new F1 cases, including seeds 42–44, actual M and displayed intervals. `none` is the control; `extreme` transposes only the exceptional variable. |
| `same-draw-transpose.csv`, `same-draw-transpose-*.rds` | Actual production draws classified by integer homogeneous-state counts. The files named `same-draw-transpose-J...rds` hold only data. Diagnostic count intervals are **not** app intervals where CI95 is blank. |
| `trial-id-comparisons.csv`, `parsed-trial-id-*.csv` | Sixteen F2 boundary cases. The parsed data show precisely where two trial identities become one. |
| `trial-id-reference.csv`, `trial-id-before-fix-summary.csv` | Full-ID template control on the target and identical wide input on 7fd6545. The independent quadrature value combines the control trial estimates; it is not an exact population p. No overall Monte Carlo interval is displayed. |
| `http-*.json` | Sixteen actual loopback HTTP replies: ten general/transposition replies, six trial-ID parse/analyze replies. The embedded `resultsCsv` preserves more digits than `overallP`. |
| `permutation-results.csv`, `same-draw-permutation.csv` | The previous recoding defect now passes; all genuine ties in the traced original cases are recognized. |
| `multilevel-laws.json`, `exact-multilevel-*.csv`, `multilevel-comparisons.csv` | Exact rational laws, chosen tables, exact trial references, and all 28 permutation/missing-column controls. Every production trial strict/tie count agrees with the same-draw integer reference. |
| `arm-key-property-checks.csv`, `arm-key-comparisons.csv` | 75 key checks and three end-to-end continuous/direct/median comparisons. The latter check a finite pooled mapping on actual integer-lattice statistics, not an exact analytical population p. |
| `independent-comparisons.csv`, `median-reference-comparisons.csv`, `direct-grid-reference.csv` | Exact categorical and fine-grid F references, independent median simulation, and the independent full-observation mean-grid reference. |
| `F-unequal-replications.csv`, `F-unequal-replication-summary.csv` | All 20 prespecified seeds for the F case with an interval miss. The summary interval is a t interval on the run mean, not an app interval. |
| `old-target-comparison.csv` | Eight entire-output comparisons against 7fd6545, six with distinct laws and two shared-law controls. All are identical. |
| `pool-expectation.csv`, `staged-interval-coverage.csv` | Independent raw mid-CDF expectation/variance and exact finite-binomial coverage under the stopping rule. No claim of unbiasedness after nonlinear transformation or selection. |
| `regression-totals.csv`, `regression-summary.csv`, `regression-exceptions.csv`, `warning-details.csv` | 1,896 passing assertions, zero failures/errors, three skips and three warnings. Grouped counts in the report overlap and must not be added. |

An empty displayed CI means **not displayed**, never zero uncertainty. The new report's findings are distinct from the original recoding fixtures and from the accepted security/resource-limit decisions. No fix or test that assumes a proposed fix was added to the production package.
