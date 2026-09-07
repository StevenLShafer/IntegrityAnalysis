# Evidence for the 2026-09-07 independent statistical audit

GPT-6 (Codex); synthetic data only; audited commit
`ae81725148bc64e55b842123b66e5f6ff71bcdf5`. No engine edits.

- `probes.R` / `probes.txt`: continuous convergence checks, exhaustive
  categorical enumeration, and the known-answer tests. `categorical-worst.rds`
  preserves the enumerated 3x2 counterexample. The 2x2 search covers all
  positive category margins at arm totals 2 through 20; the 3x2 search
  covers arm totals 2 through 8. Integer comparison keys establish ties
  independently of the floating-point Pearson calculation.
- `followup.R` / `followup.txt`: categorical trial combination, API label
  collision, direct-call SD precision, quartile precision, sensitivity,
  exact percentage-rounding enumeration, and seven further test files.
- `edgechecks.R` / `edgechecks.txt`: explicit sample proving the quartile
  refusal, default percentage-bracket check, normalized lockfile comparison,
  and 27 numerical edge configurations.
- `calibration.R` / `calibration.csv` / `calibration-summary.csv`: 400
  independent synthetic trials in each of three prespecified scenarios.
  These runs use a fixed 1,000-replicate ceiling. Rates in the summary
  exclude refused rows, whose counts are shown explicitly.
- `*-console.txt`, `calibration-errors.txt`, and `calibration-smoke.txt`
  preserve launch output. Startup reported locale warnings and a general
  renv out-of-sync message; normalized installed package versions all
  match the lockfile (`edgechecks.txt`). The first raw version comparison
  in `followup.txt` lists hyphen/dot spelling differences, not upgrades.

From `C:/dev/IntegrityAnalysis`, with access to the existing renv library:

```powershell
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-07/probes.R
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-07/followup.R
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-07/edgechecks.R
```

Calibration smoke command: the following ran one full-size trial in each
scenario and wrote the actual resume file. Measured per-unit times were
0.05, 0.23 and 0.25 seconds, including first-use overhead; R/package startup
was about six seconds. First resumed output was expected within ten seconds.

```powershell
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-07/calibration.R 1
```

The full run was launched detached with `Start-Process -WindowStyle Hidden`,
working directory `C:/dev/IntegrityAnalysis`, executable as above,
arguments `docs/audits/evidence-2026-09-07/calibration.R 400`, and redirected
stdout/stderr to `calibration-console.txt` / `calibration-errors.txt` in this
folder. PID 16256 was read back after launch. Completion was verified by
process exit, all 1,200 saved trial rows, and the three summary rows.

Resume command (already-completed case/index pairs are skipped):

```powershell
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-07/calibration.R 400
```

Do not run against a changed source checkout and append to these results.
Use a new output directory for a new build or independent replication.
