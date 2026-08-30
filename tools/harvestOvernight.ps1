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
# MONTH SCOPE - the fix for a silent 16-hour underrun on 2026-08-27.
# corpus/harvestMedrxivS3.R lists the current + previous month only,
# which is exactly right for the NIGHTLY job and wrong for a backfill.
# The first overnight run consumed both months in 1h55m, correctly
# reported "0 new", and this wrapper concluded medRxiv was exhausted.
# It was not - the SCOPE was. The bucket has 71 month folders and
# 90,478 packages this corpus has never seen.
#
# So the wrapper now passes -Months explicitly, defaulting to 'all'.
# The harvester keeps its narrow default, because listing 71 folders
# every night to find yesterday's papers would be waste.
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
  [string] $OutDir    = 'C:/temp/medrxiv_rct',
  # 'all' walks every month folder in the bucket, newest first. This
  # wrapper exists for BULK BACKFILL, so that is its default - see the
  # note below for why the harvester's own default is different.
  [string] $Months    = 'all'
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

# ---- RUN FROM A SNAPSHOT, NOT THE LIVE TREE -----------------------------
#
# This loop re-invokes the harvester ONCE PER BATCH - forty-odd times
# across a thirteen-hour window - so the repository is being read for the
# whole run, not once at launch. Editing it mid-run therefore corrupts
# the job, and on 2026-08-29 it did, three ways in one evening:
#
#   * an edit landed while a batch was reading the file: "Execution
#     halted", 250 packages downloaded and left unclassified
#   * `gh pr merge --delete-branch` switched branches underneath the run
#     and DELETED a file the harvester sources; every later batch would
#     have died on "cannot open file", reporting nothing useful
#   * the merge also silently changed the harvester's stdout wording,
#     which this wrapper parses (see the egress accounting below)
#
# The project already knew this lesson for the ENGINE - corpus runs load
# an installed snapshot library precisely so a live edit cannot reach a
# running analysis - and simply had not applied it to the SCRIPTS. This
# does. The scripts are copied once, at launch, and every batch runs the
# copy, so the working tree can be edited, branched or merged freely
# while a harvest is in flight.
$snapRoot = Join-Path $OutDir '.runsnapshot'
$snapDir  = Join-Path $snapRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
$needed = @('corpus/harvestMedrxivS3.R',
            'corpus/rctFilterPatterns.R',
            'corpus/mecaPrefixScreen.R')
foreach ($f in $needed) {
  if (-not (Test-Path $f)) { Say "ERROR: missing $f"; exit 1 }
  Copy-Item $f $snapDir
}
$snapScript = Join-Path $snapDir 'harvestMedrxivS3.R'
$commit = (& git rev-parse --short HEAD 2>$null)
if (-not $commit) { $commit = 'unknown' }
Say ("snapshot: {0} (commit {1})" -f $snapDir, $commit)
# Keep the last few for provenance - which code produced which night's
# corpus - and prune the rest so this never becomes a disk problem.
Get-ChildItem $snapRoot -Directory | Sort-Object Name -Descending |
  Select-Object -Skip 5 | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

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
Say ("months : {0}" -f $Months)

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

  $out = & $rscript $snapScript $BatchFiles $thisGB $OutDir $Months 2>&1 | Out-String
  $line = ($out -split "`r?`n" | Where-Object { $_ -match 'processed \d+ package' }) -join ' '
  if (-not $line) { $line = ($out -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1) }

  # WHAT WAS ACTUALLY SPENT. The harvester reports "egress this run: N MB"
  # since prefix screening landed (#118): the listed size of candidates is
  # no longer what gets paid for, because most packages are now screened
  # on a 64 KB prefix and never fetched. The older "downloading N
  # package(s), M MB" line is still emitted when screening is disabled
  # with INTEGRITY_MECA_SCREEN=0, so both are read - newest first.
  #
  # Reading only the old wording was a live bug for one evening: every
  # batch scored 0 MB, the budget never advanced, and the stall heuristic
  # below fired on every batch. A wrapper that parses another program's
  # prose is coupled to its wording, and this comment is here so the next
  # person changing either one knows it.
  $mb = 0.0
  if ($out -match 'egress this run:\s+([\d.]+)\s*MB') {
    $mb = [double]$Matches[1]
  } elseif ($out -match 'downloading\s+\d+\s+package\(s\),\s+([\d.]+)\s*MB') {
    $mb = [double]$Matches[1]
  }
  # Screening counts, so "did this batch make progress" can be answered
  # without reference to bytes - under screening, near-zero egress is the
  # DESIRED outcome, not a stall.
  $screened = 0; $fetched = 0
  if ($out -match 'screened\s+(\d+),\s+skipped\s+\d+[^,]*,\s+fetched\s+(\d+)') {
    $screened = [int]$Matches[1]; $fetched = [int]$Matches[2]
  }
  $spentGB += $mb / 1024
  $after = CorpusCount
  Say ("batch {0}: {1} | +{2} kept | {3:N0} MB | {4:N2}/{5} GB spent" -f
       $batch, $line.Trim(), ($after - $before), $mb, $spentGB, $BudgetGB)

  # Distinguish "nothing left to fetch" from "this batch could not make
  # progress". Three states, and prefix screening (#118) added the third:
  #
  #   nothing listed        -> genuinely idle; three in a row means done
  #   screened but fetched  -> PROGRESS, even at near-zero egress. Most
  #     few or none            batches now download almost nothing, which
  #                            is the entire point of screening.
  #   nothing screened AND  -> the old stall: with screening disabled the
  #     nothing downloaded     harvester used to filter candidates by
  #                            cumsum(bytes) <= maxGB, returning zero rows
  #                            when the next package exceeded the batch
  #                            cap. That filter is gone, but the guard is
  #                            kept for INTEGRITY_MECA_SCREEN=0 runs.
  #
  # Judging progress by megabytes alone quadrupled BatchGB on every batch
  # of a screened run - the batch was working perfectly and the wrapper
  # read its efficiency as failure.
  $listedNew = 0
  if ($out -match '(\d+)\s+new') { $listedNew = [int]$Matches[1] }
  $madeProgress = ($screened -gt 0) -or ($mb -ge 0.5)
  if ($listedNew -le 0) {
    $idle++
    if ($idle -ge 3) {
      Say "no new packages listed in three batches - medRxiv exhausted, stopping"
      break
    }
  } elseif (-not $madeProgress) {
    Say ("  batch did nothing though {0} package(s) remain - the next one" -f $listedNew)
    Say ("  exceeds the {0} GB batch cap; raising this batch to {1} GB" -f $thisGB, ($BatchGB * 4))
    $BatchGB = $BatchGB * 4
    $idle = 0
  } else { $idle = 0 }

  Start-Sleep -Seconds 5     # be a polite client
}

$end = CorpusCount
Say "===== done ====="
Say ("batches {0}, downloaded {1:N2} GB (about `${2:N2})" -f $batch, $spentGB, ($spentGB * 0.09))
Say ("corpus {0} -> {1} PDF(s), +{2} kept" -f $startCount, $end, ($end - $startCount))
if ((Get-Date) -ge $deadline) { Say "stopped: time window closed" }
elseif ($spentGB -ge $BudgetGB) { Say "stopped: download budget reached" }
