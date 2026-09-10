# Full statistical audit evidence — 2026-09-10

Source commit: **a796e51d6a66b590fc09394488811f8cac2c8060**. R 4.5.3.
All data are synthetic. The source archive and private dependency copies
were scratch material; the committed evidence contains no machine-specific
paths or library copies. See the [report](../2026-09-10-full-independent-statistical-audit-chatgpt.md).

## Start with these files

- `review-brief.md`: the complete commissioning brief.
- `verification-summary.txt`, `regression-summary.csv`, `skips-and-failures.csv`:
  39 test files, 1,631 passing assertions, no failures/errors, 11 skips.
  Each `regression-<name>.csv` records every test block, its counts and skip reason.
- `runtime.txt`, `dependency-versions.csv`, `lockfile-comparison.csv`:
  runtime and copied dependency provenance; 121 comparisons, no mismatch.
- `audited-source-SHA256.txt`: hashes of the audited R source, test files,
  lockfile, DESCRIPTION and four principal method/contract documents.
- `same-draw-combination.csv`: the decisive numerical comparison. Its RDS
  companions contain only numeric simulations/counts, not R environments.
- `fixture-ordinary-N100-J9-bad3.csv`: exact trial p 0.0111459494027611;
  engine trial p 0.003285, M=100000, seed 42.
- `fixture-ordinary-N100-J14-bad7.csv`: exact trial p 0.000519194541114;
  engine p 0.00013, displayed CI 0.000022–0.00031, M=100000, seed 42.
- `fixture-all-excluded-trial.csv`: trial B missing from results/coverage.
- `fixture-http-duplicate.csv`: structural issue serializes `row` as `"NA"`.
- `http-*.json`: actual HTTP reply text, pretty-printed without converting
  through an R object. `http-route-summary.csv` records status and summary.

## Recreate

Run from a checkout of this repository using **R 4.5.3**. The project must
already have access to the recorded runtime dependencies, plus `pkgload`,
`testthat` and `plumber`. `setup.R` copies the dependency closure from the
active project library; it installs and updates nothing. The version comparison
is the check that those copies correspond to the audited lockfile.

Create an isolated source snapshot (PowerShell):

```powershell
New-Item -ItemType Directory -Force .audit-2026-09-10-full | Out-Null
git archive --format=zip --output=.audit-2026-09-10-full/source.zip a796e51d6a66b590fc09394488811f8cac2c8060
Expand-Archive .audit-2026-09-10-full/source.zip .audit-2026-09-10-full/source
```

Call `setup.R` with project startup enabled, so renv selects the project
library. All subsequent scripts use `--vanilla` and explicitly select the
private copied library before attaching the requested packages. `Rscript`
below means the **4.5.3 executable**, not whichever version happens to come first
on a new machine's PATH.

```text
Rscript docs/audits/evidence-2026-09-10-full/setup.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/regressions.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/independent.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/combination-followup.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/verify-combination.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/ordinary-arm-combination.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/median-reference.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/additional-checks.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/direct-grid-reference.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/http-routes.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/same-draw-combination.R
Rscript --vanilla docs/audits/evidence-2026-09-10-full/summarize.R
```

`regressions.R` resumes from completed per-file CSVs. For a genuinely fresh
rerun, use a fresh evidence output directory or archive those CSVs first;
otherwise it intentionally skips them. The other scripts overwrite their
own results and checkpoint each completed case. Preserve the delivered
evidence before rerunning if a comparison with it is wanted.

For sustained runs, the actual audit used detached, hidden Windows processes.
A reusable launch pattern, with no machine-specific executable path:

```powershell
$auditR = (Get-Command Rscript.exe).Source  # verify this is R 4.5.3 first
$auditScript = 'docs/audits/evidence-2026-09-10-full/regressions.R'
$auditRun = Start-Process -FilePath $auditR -ArgumentList '--vanilla',$auditScript -WorkingDirectory (Get-Location).Path -WindowStyle Hidden -RedirectStandardOutput '.audit-2026-09-10-full/regressions.stdout.txt' -RedirectStandardError '.audit-2026-09-10-full/regressions.stderr.txt' -PassThru
Get-Process -Id $auditRun.Id
```

The first full-size regression unit completed in seconds. For reruns, allow roughly
20 seconds for startup and first output on a comparable machine; investigate
no first checkpoint by 40 seconds. The fail-safe and boundary files take
longer (the first fail-safe file took about 58 seconds; additional boundary
files about 17–19 seconds). The median reference checkpoints each of three
100,000-replicate cases. During this audit, process/output checks occurred
throughout the runs, with first checkpoints and later progress read back.
No run was left for a later unattended session. Completion
markers and per-file results, rather than a successful launcher return,
were used as evidence of completion.

## What each reference establishes

`independent.R` enumerates fixed-margin allocation probabilities without
calling the production statistic/tie helpers. The continuous comparison
uses the fine-grid F limit. The initial unequal-N interval miss is preserved;
`additional-checks.R` repeats it over 20 seeds and finds an aggregate interval
containing the reference. That script also tests origin/units and checks
`sumz()` by integrating the normal density and solving its CDF independently.

`median-reference.R` uses base R order statistics and a separate RNG to
implement the documented median null. Agreement validates implementation,
not calibration for all populations. `direct-grid-reference.R` draws every
observation and counts ties by exact integer sample sums.

`ordinary-arm-combination.R` and `verify-combination.R` use the untouched API
analysis path. `same-draw-combination.R` adds observational traces solely to
copy the generated statistics and sums. Its reference counts the integer
number of minimum-state rows; it changes no production computation.
`combination-followup.R` is an earlier diagnostic on very small arm sizes.
Its position comparisons are conditional re-evaluations at a captured M;
`verify-combination.R` separately reruns real adaptive stopping for the actual
positions. Do not mistake a conditional position diagnostic for a new engine run.

`http-routes.R` starts the real service on loopback with a synthetic local
test token. It uploads five synthetic CSVs and stops the child in `finally`.
The seed is sent on the URL, as the API requires. Early harness trials used
a form field without a Content-Type; the API correctly rejected those before
analysis. The retained final HTTP artifacts are the corrected URL-seed runs.

No corpus, OCR service, AI provider, remote deployment or production endpoint
was used. The repository's optional nimble/MCMC comparison was not executed.
Console output is retained with any machine-local paths removed; all fixtures,
scripts and numerical outputs are preserved without such paths.
