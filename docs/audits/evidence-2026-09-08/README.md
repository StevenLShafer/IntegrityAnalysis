# Reproduction evidence for the 2026-09-08 audit

Origin: GPT-6 (Codex), 2026-09-08. Executed against commit
`088a78cb2d3f0c36179783e1e3aa5ddf7a3296be`, R 4.5.3, project renv library.
All data and the PDF/workbook fixtures are synthetic. No application code was
changed. The main report is [here](../2026-09-08-independent-statistical-audit-chatgpt.md).

Run in PowerShell from `C:/dev/IntegrityAnalysis`, using this project's library:

```powershell
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-08/probes.R
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-08/countsearch.R
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-08/followup.R
& 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' docs/audits/evidence-2026-09-08/final-checks.R
```

These are short, foreground audit checks, not detached corpus runs. Each writes
its own text output. The console logs additionally record startup warnings and
test output. All final script versions completed with exit 0. Startup reports
renv out-of-sync and locale/loading warnings; no library restoration or package
installation was performed. `final-checks.txt` records actual session versions.

- `probes.R` / `probes.txt`: zero-row refusal, translation/unit invariance,
  SD-lattice counterexample, percentage bracket endpoints, Barnett counterexample.
- `countsearch.R` / `countsearch.txt` / `countsearch.rds`: exact two-arm
  hypergeometric enumeration over 17,955 percentage configurations. No Monte
  Carlo is needed for the counterexample to the promised p ordering.
- `followup.R` / `followup.txt`: selected exact count examples through P_Calc;
  independent rounded-normal simulation (one million replicates, seed 19371,
  integer-grid statistic comparison); unrounded t-mixture quadrature as a
  separate approximation; quartile conventions; tie-helper probe; synthetic PDF
  reconstruction; workbook summary disclosure; seven existing statistical test
  files. All seven reported DONE with no failed expectations.
- `final-checks.R` / `final-checks.txt`: full conditional 2×3 enumeration using
  exact integer scores below 2^53; exhaustive SD-minimum verification;
  independent-reference MC standard error; normalized versus direct precision;
  fractional precision; export/help-file availability; session metadata.
- `synthetic-three-category.pdf` and `.rds`: exact parser fixture and returned
  parse object. `synthetic-partial-results.xlsx`: actual workbook showing the
  lost overview NOTE. These are test evidence, not manuscript data.

Engine seeds are 42 in both generators unless an existing test explicitly sets
its own seed. The engine stages adaptively: `m=100000` does **not** force 100,000
replicates. Read each returned M. A refused row has no M. Barnett's calculation
and the enumerations have no simulation seed or M.

The mixed supplied/inferred-precision run in `final-checks.txt` prints the
validator's normalized frame in both calls for comparison; the `validate=FALSE`
call deliberately passes the original frame to P_Calc. Its p difference alone is
within simulation uncertainty; the demonstrated mismatch is the input grid used.

The first development run of `followup.R` stopped on an empty test-fixture
selection (`Race` versus `Race, %`); the final run corrected the selector. The
first `final-checks.R` run completed its statistical checks but stopped in
pkgload's help lookup on an embedded-NUL documentation error; the final version
checks the export and source man file directly. Neither development failure
changed application code or the findings.
