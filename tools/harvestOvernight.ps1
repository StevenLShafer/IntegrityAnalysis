# harvestOvernight.ps1 - run the medRxiv S3 harvest for a long window.
#
# PROVENANCE: written 2026-08-27 by Claude Code (model Claude Opus 5),
# at Steve Shafer's request: "Can we start additional retrieval from
# medRxiv at that time? The computer will be otherwise unoccupied for
# about 18 hours."
#
# WHY A WRAPPER. corpus/harvestMedrxivS3.R stops at its per-run caps
# (maxFiles / maxGB) by design - the cost guard is per invocation. To
# use a long unattended window it has to be called repeatedly. This
# loops it until whichever comes first: the time window closes, the
# download budget is spent, or medRxiv runs out of new packages.
#
# COST, stated plainly because this spends real money. The medRxiv TDM
# bucket is REQUESTER-PAYS: Steve pays egress at roughly $0.09/GB.
# Measured 2026-08-27: packages average ~6.4 MB, and about 1.8% of them
# are RCTs worth keeping (2 of the first 114 processed).
#
#     budget    packages    est. RCTs kept    est. cost
#      20 GB       ~3,200          ~57           ~$1.80
#      50 GB       ~8,000         ~145           ~$4.50
#     100 GB      ~16,000         ~290           ~$9.00
#
# TIME BINDS, NOT MONEY. Measured throughput 2026-08-27 is ~1.4 MB/s,
# so an 18-hour window moves about 89 GB - roughly $8. Steve has $200
# allocated, so the budget is set ABOVE what the window can reach
# (150 GB) and the clock is what stops the run. A budget below the
# window's reach would silently cut the night short.
#
# The account has a $10 budget ALARM (C:\dev\AWS), which an overnight
# run will approach or cross. It NOTIFIES; it does not stop anything.
# Expect the email; it is not a fault.
#
# NOTHING IS DELETED. The harvester only adds; non-RCT packages are
# discarded from the incoming staging area, never from the corpus.
#
# Usage:
#   pwsh tools/harvestOvernight.ps1                     # 18h, 150 GB cap
#   pwsh tools/harvestOvernight.ps1 -Hours 8 -BudgetGB 20

[CmdletBinding()]
param(
  [double] $Hours     = 18,
  [double] $BudgetGB  = 150,
  [int]    $BatchFiles = 250,
  [double] $BatchGB    = 4,
  [string] $OutDir    = 'C:/temp/medrxiv_rct'
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$log = Join-Path $OutDir 'overnight.log'
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Say([string] $m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 's'), $m
  Add-Content $log $line
  Write-Host $line
}

$rscript = 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe'
if (-not (Test-Path $rscript)) { Say "ERROR: Rscript not found"; exit 1 }

# The harvester resolves the aws CLI itself, but say up front whether the
# credential is alive: an 18-hour run that fails on batch 1 for a stale
# key is 18 hours of nothing. The harvest profile is a permanent IAM key
# precisely so this cannot expire mid-run (Identity Center tokens died
# after 8 hours - the 2026-08-27 lesson).
$env:INTEGRITY_AWS_PROFILE = 'harvest'
$aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $aws) {
  $c = "$env:LOCALAPPDATA\Programs\Amazon\AWSCLIV2\aws.exe"
  if (Test-Path $c) { $aws = $c }
}
if ($aws) {
  $who = & $aws sts get-caller-identity --profile harvest 2>&1 | Out-String
  if ($who -match 'integrityanalysis-harvest') {
    Say "credential OK (integrityanalysis-harvest)"
  } else {
    Say "WARNING: harvest credential did not verify:"
    Say ("  " + ($who -replace "`r?`n", ' '))
  }
} else {
  Say "WARNING: aws CLI not found on PATH - the harvester resolves it itself, continuing"
}

$deadline = (Get-Date).AddHours($Hours)
Say "===== overnight harvest ====="
Say ("window : {0:s} -> {1:s} ({2} h)" -f (Get-Date), $deadline, $Hours)
Say ("budget : {0} GB (about `${1:N2} at 0.09/GB)" -f $BudgetGB, ($BudgetGB * 0.09))

function CorpusCount { (Get-ChildItem $OutDir -Filter *.pdf -ErrorAction SilentlyContinue | Measure-Object).Count }
$startCount = CorpusCount
Say "corpus at start: $startCount PDF(s)"

$spentGB = 0.0
$batch = 0
$idle = 0
while ((Get-Date) -lt $deadline -and $spentGB -lt $BudgetGB) {
  $batch++
  $thisGB = [Math]::Min($BatchGB, $BudgetGB - $spentGB)
  if ($thisGB -le 0.01) { break }
  $before = CorpusCount

  $out = & $rscript 'corpus/harvestMedrxivS3.R' $BatchFiles $thisGB $OutDir 2>&1 | Out-String
  $line = ($out -split "`r?`n" | Where-Object { $_ -match 'processed \d+ package' }) -join ' '
  if (-not $line) { $line = ($out -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1) }

  # "downloading N package(s),  M MB" tells us what was actually spent
  $mb = 0.0
  if ($out -match 'downloading\s+\d+\s+package\(s\),\s+([\d.]+)\s*MB') {
    $mb = [double]$Matches[1]
  }
  $spentGB += $mb / 1024
  $after = CorpusCount
  Say ("batch {0}: {1} | +{2} kept | {3:N0} MB | {4:N2}/{5} GB spent" -f
       $batch, $line.Trim(), ($after - $before), $mb, $spentGB, $BudgetGB)

  # Distinguish "nothing left to fetch" from "the batch cap was too
  # small for the next package". The harvester filters with
  # cumsum(bytes) <= maxGB, which returns ZERO rows when the very next
  # package is larger than the remaining batch budget - so a small
  # -BatchGB stalls at 0 downloaded while thousands remain. Found in the
  # 2026-08-27 smoke test at BatchGB 0.05; it does not arise at the 4 GB
  # default, but a stall must never be misreported as "done".
  $listedNew = 0
  if ($out -match '(\d+)\s+new') { $listedNew = [int]$Matches[1] }
  if ($mb -lt 0.5) {
    if ($listedNew -gt 0) {
      Say ("  batch downloaded nothing though {0} package(s) remain - the next one" -f $listedNew)
      Say ("  exceeds the {0} GB batch cap; raising this batch to {1} GB" -f $thisGB, ($BatchGB * 4))
      $BatchGB = $BatchGB * 4
      $idle = 0
    } else {
      $idle++
      if ($idle -ge 3) {
        Say "no new packages listed in three batches - medRxiv exhausted, stopping"
        break
      }
    }
  } else { $idle = 0 }

  Start-Sleep -Seconds 5     # be a polite client
}

$end = CorpusCount
Say "===== done ====="
Say ("batches {0}, downloaded {1:N2} GB (about `${2:N2})" -f $batch, $spentGB, ($spentGB * 0.09))
Say ("corpus {0} -> {1} PDF(s), +{2} kept" -f $startCount, $end, ($end - $startCount))
if ((Get-Date) -ge $deadline) { Say "stopped: time window closed" }
elseif ($spentGB -ge $BudgetGB) { Say "stopped: download budget reached" }
