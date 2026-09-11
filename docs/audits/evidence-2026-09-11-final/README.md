# Evidence for the final-brief statistical audit, executed 2026-09-11

Target: `7fd654589ddbbaa5bf03e96aad2aecbca9576bb7`, R 4.5.3. All new inputs are synthetic. The source was an isolated, detached worktree; no engine changes were made. `runtime.txt`, `dependency-versions.csv`, and `lockfile-comparison.csv` record the runtime; all 121 lockfile package versions matched.

## Reproduction

The launcher supplies four environment variables; no machine-specific location is embedded here:

- `INTEGRITY_AUDIT_SCRATCH`: a scratch directory containing the audited worktree as `source`.
- `INTEGRITY_AUDIT_OUTPUT`: this evidence directory, or a fresh output directory containing these scripts.
- `INTEGRITY_AUDIT_LIBRARY_SOURCE`: a package library containing the locked runtime dependencies and the test tools.
- Optional `INTEGRITY_AUDIT_SOURCE`: overrides the source directory **only for the old-version comparison**. Leave unset for every audit check.

Run Rscript 4.5.3 with `--vanilla`, from the target worktree. `common.R` attaches the five required packages, loads the source, disables console echo, unsets AI credentials, and enables non-CRAN HTTP tests. No library is installed or updated by the numerical checks. `setup.R` can inventory an existing library with `INTEGRITY_AUDIT_REUSE_LIBRARY=true`.

For the new finding, run `permutation-checks.R`, then `same-draw-permutation.R` and `http-routes.R`. The first script checkpoints completed cases; use a fresh output directory to repeat them. The HTTP script starts and stops an authenticated server on loopback only; its random credential remains in memory. HTTP bodies are retained without reserializing their null values.

For the rest of the audit, run `regressions.R`, `independent.R`, `median-reference.R`, and `direct-grid-reference.R`. After `independent.R`, run `additional-checks.R`, then `analytic-checks.R`. The regression runner checkpoints each of its 44 files. Its summaries contain all assertion counts and skips; it does not claim to run the whole repository suite.

`unique-law-comparison.R` is optional comparative evidence: run once with `INTEGRITY_AUDIT_COMPARISON_TAG=target`, and once with `INTEGRITY_AUDIT_COMPARISON_TAG=old` and a source checkout of `a796e51d6a66b590fc09394488811f8cac2c8060`. Restore the target source before running `supplemental.R`, which reads those comparison results and also checks the AI converter, free versus partitioned enumeration, and the pool boundary. `finalize-evidence.R` aggregates regression results and inspects every RDS object for local paths or executable objects.

## What the files establish

| Files | Evidence |
|---|---|
| `fixture-J9-flip-extreme-seed42.csv`, `fixture-J14-flip-extreme-seed42.csv` | Minimal threshold and displayed-interval counterexamples. Flip only one variable's YES/NO columns back to obtain the controls. |
| `permutation-results.csv` | 24 executed CSV-upload cases, including seeds 42–44 and several relabelings; actual M, printed p, and printed interval. |
| `same-draw-permutation.csv`, `same-draw-*.rds` | Four traces copying the actual draws; integer reference counts versus production tie classification. Traced and untraced results are asserted identical. The `engine_diagnostic_CI_*` columns are count-based audit calculations, **not** intervals displayed for the nine-row trials. |
| `http-*.json`, `http-route-summary.csv` | Eight actual loopback HTTP responses: four statistical comparisons, one excluded-trial case, three structural refusals. `resultsCsv` has the fuller p precision; `overallP` is rounded separately. |
| `independent-comparisons.csv`, `exact-law-*.csv` | Six exact categorical laws, four continuous F limits, six exact binary combinations. An empty CI means **not displayed**, never zero uncertainty. |
| `median-reference-comparisons.csv`, `direct-grid-reference.csv` | Independently generated quantile/observation simulations; both production and reference Monte Carlo intervals are retained. |
| `F-unequal-replications.csv`, `F-unequal-replication-summary.csv` | All 20 prespecified seeds for the fine-grid F case with a seed-42 interval miss. The summary interval is a t interval for the mean over independent runs, not an app interval. |
| `pool-expectation.csv` | Independent binomial experiment and analytical mean/variance of raw own-row and pooled mid-CDF estimates. This does not assert that a nonlinear transformed or selected p is unbiased. |
| `staged-interval-coverage.csv` | Exact binomial summation of interval coverage under the existing fresh-batch stopping rule, for an untied single-row null; confirms the documented optional-stopping qualification. |
| `old-target-comparison.csv` | Entire-output equality for six unique-law comparisons, with fixed and adaptive ceilings; the intended changes to shared-law trial results are separate controls. |
| `AI-exact-reference.csv`, `AI-converted-template.csv`, `fixture-AI-reserved-levels.json` | Mocked transport through the real AI parser/converter and analysis, compared with exact enumeration. No model request was sent. |
| `nonpartition-count.csv`, `pool-boundary.csv` | 81 free readings versus nine explicitly partitioned readings; 100 shared rows accepted and 101 refused at a prospective 100,000 ceiling. The accepted boundary case actually uses 1,000 draws, so this is not a peak-memory benchmark. |
| `regression-summary.csv`, `regression-totals.csv`, `regression-exceptions.csv` | 1,820 passing assertions, zero failures/errors/warnings, three skips, 270 test blocks in 44 files. Grouped checklist counts overlap and must not be added. |

The earlier audit's independent scripts were reused with their source locations changed and were re-executed, not copied as results. Exact references use allocation counting, integer outcomes, F laws, or independent base-R simulation; they do not obtain their expected answer from the production statistic/ranking helper. All displayed p values in the report are accompanied by the displayed interval, or explicitly identify that no interval is displayed. Exact answers and deterministic `sumz()` references have no Monte Carlo interval.
