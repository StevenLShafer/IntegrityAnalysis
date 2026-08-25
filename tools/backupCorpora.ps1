# backupCorpora.ps1 - copy every local test corpus into OneDrive.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-25,
# at Steve Shafer's request ("I have a little anxiety related to not
# backing up the files"). The code lives on GitHub; the corpora do not -
# they are copyrighted PDFs and harvested preprints that exist only on
# this machine, and the corpus folder has ALREADY been lost once (the
# 2026-08-19 testServer purge incident; it was rebuilt from sources).
#
# Design: ADDITIVE robocopy, not a mirror - /E copies new and changed
# files only, and a deletion on this machine never propagates to the
# backup. OneDrive then syncs the deltas. No zipping: archives would
# re-upload gigabytes on every change; per-file copies upload each PDF
# exactly once, which suits corpora that only grow.
#
# Run by hand, or via the weekly scheduled task
# "IntegrityAnalysis corpora backup" (Sundays 03:00; see ISSUES.md
# issue 21 for how both standing tasks were registered).

$dest = Join-Path $env:OneDrive 'IntegrityAnalysisCorpora'
$log  = Join-Path $dest 'backup.log'
New-Item -ItemType Directory -Force $dest | Out-Null
Add-Content $log ("`n===== backup run " + (Get-Date -Format 's') + " =====")

$corpora = [ordered]@{
  'journals'       = 'C:\temp\journals'
  'AA'             = 'C:\Temp\AA'
  'medrxiv_rct'    = 'C:\temp\medrxiv_rct'
  'NewCarlisle'    = 'C:\dev\IntegrityAnalysis\.NewCarlisle'
  'Boldt'          = 'C:\dev\IntegrityAnalysis\.Boldt'
  'Fujii'          = 'C:\dev\IntegrityAnalysis\.Fujii'
  'Shafer studies' = 'C:\Temp\Shafer studies'
}

foreach ($name in $corpora.Keys) {
  $src = $corpora[$name]
  if (-not (Test-Path $src)) {
    Add-Content $log "SKIP (missing): $src"
    continue
  }
  # /E new+changed incl. empty dirs; /XO don't re-copy older-on-source;
  # /R:2 /W:10 shrug off OneDrive file locks; /NP no percent spam
  robocopy $src (Join-Path $dest $name) /E /XO /R:2 /W:10 /NP /NFL /NDL /LOG+:$log | Out-Null
  # robocopy exit codes 0-7 are success shades; 8+ are failures
  if ($LASTEXITCODE -ge 8) {
    Add-Content $log "FAILED ($LASTEXITCODE): $name"
  } else {
    Add-Content $log "ok ($LASTEXITCODE): $name"
  }
}
Add-Content $log ("===== done " + (Get-Date -Format 's') + " =====")
