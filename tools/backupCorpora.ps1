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

# ---- heartbeat check (Steve's request, 2026-08-26) ----------------------
# Everything scheduled runs on one PC in Steve's house, and a job that
# stops running is INVISIBLE - the 2 AM harvest could fail silently for
# weeks. The harvest appends a line to heartbeat.log on every run; this
# task (03:00, an hour later) checks that the line is fresh and shouts
# into the backup log if it is not. The backup log is in OneDrive, so
# the complaint is visible from any device.
#
# Deliberately dumb: no email, no service, nothing else to fail. The
# question it answers is "did the harvest run last night?", which is
# the question that actually goes unnoticed.
$hb = 'C:\temp\medrxiv_rct\heartbeat.log'
$hbAgeHours = if (Test-Path $hb) {
  [math]::Round(((Get-Date) - (Get-Item $hb).LastWriteTime).TotalHours, 1)
} else { $null }

if ($null -eq $hbAgeHours) {
  Add-Content $log "HEARTBEAT MISSING: $hb does not exist - the medRxiv harvest has never reported."
} elseif ($hbAgeHours -gt 26) {
  Add-Content $log "HEARTBEAT STALE: the medRxiv harvest last reported $hbAgeHours hours ago (expected nightly). Check Task Scheduler and 'aws sso login --profile steve'."
} else {
  Add-Content $log "heartbeat ok: harvest reported $hbAgeHours hours ago"
}

# shinyapps.io active-hours check (Steve's capacity question, 2026-08-26).
# The allowance is shared across every app on the account, and when it is
# exhausted Posit takes the apps offline - the app cannot warn about that
# itself, so the warning has to arrive here.
$capacity = & 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
    'C:\dev\IntegrityAnalysis\tools\checkCapacity.R' 2>&1
Add-Content $log ($capacity | Out-String).TrimEnd()

# The harvest uses a dedicated IAM user with a LONG-LIVED access key
# (profile "harvest", 2026-08-27), so there is no session to expire and
# nothing to log into - the Identity Center route was abandoned after
# its token proved to last 8 hours, which no 2 AM task can satisfy.
# What CAN still break is the key being rotated, deleted, or the policy
# changed, so prove the credential works rather than assuming it.
$awsExe = Join-Path $env:LOCALAPPDATA 'Programs\Amazon\AWSCLIV2\aws.exe'
if (-not (Test-Path $awsExe)) { $awsExe = 'C:\Program Files\Amazon\AWSCLIV2\aws.exe' }
if (Test-Path $awsExe) {
  $probe = & $awsExe sts get-caller-identity --profile harvest `
             --region us-east-1 --query 'Arn' --output text 2>&1
  if ($LASTEXITCODE -eq 0) {
    Add-Content $log "aws harvest credential ok: $(($probe | Select-Object -First 1))"
  } else {
    Add-Content $log "AWS HARVEST CREDENTIAL FAILING - the nightly harvest cannot run: $(($probe | Select-Object -First 1))"
  }
}
