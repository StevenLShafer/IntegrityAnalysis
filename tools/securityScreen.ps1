# securityScreen.ps1 - the change-gated deep security screen.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-08-27,
# at Steve Shafer's request: "should we implement an automated security
# screen as a scheduled task evening every day when a change is made to
# the API or UI... should the security screen be rerun after any patches
# until it shows up with zero issues?"
#
# WHY THIS IS NOT THE TRIPWIRE. tools/securityCheck.R is a LAB VALUE:
# a small set of hand-verified properties, checked mechanically, with a
# defined normal range (exit 0). It runs on every push, it is free, and
# "repeat until normal" is exactly the right rule for it.
#
# This script is the other thing - a READ of the changed code by a model
# that reasons about it. It finds what a static assertion cannot: the
# journal-table amplification DoS (2026-08-27) was legal input, legal
# code, every input gate passing, and a response that expanded
# super-linearly on the way out. No grep would have caught it.
#
# The two differ in a way that decides how this is scheduled:
#   - The tripwire MEASURES the system. Re-running it after a fix tells
#     you the truth about the system.
#   - The screen SAMPLES AN OPINION about the system. Re-running it
#     yields a fresh sample - which will contain new speculative
#     findings whether or not the system changed. Looping "until zero
#     issues" therefore does not converge; it just keeps drawing
#     opinions until one comes back empty, and invites patching things
#     that were never wrong. Two of this project's worst defects were
#     introduced BY security patches (the CSV sanitizer that renamed
#     variables and broke issue 1's round-trip contract; the tripwire
#     assertion that matched a commented-out line and so passed on a
#     deliberate break). Iatrogenic harm is real here.
#
# The endpoint is therefore EVERY FINDING ADJUDICATED - fixed, or
# accepted with a written reason - and every fix verified, not "the
# screen returns empty."
#
# CHANGE-GATED, NOT CALENDAR-DRIVEN. Run nightly, but do nothing unless
# the watched surface actually moved since the last screened commit.
# A screen of an unchanged tree costs tokens and produces noise; the
# ledger below makes the nightly run a cheap no-op on quiet days and a
# real screen on the days it matters.
#
# THE SCREEN NEVER PATCHES. It writes a report and stops. Deciding what
# to do about a finding stays a human decision, made with the whole
# system in view - see the iatrogenic point above.
#
# Usage:
#   pwsh tools/securityScreen.ps1            # nightly: gate, then screen
#   pwsh tools/securityScreen.ps1 -Force     # screen regardless of diff
#   pwsh tools/securityScreen.ps1 -Since <sha>   # screen a chosen range
#
# Registered as the scheduled task "IntegrityAnalysis security screen"
# (daily 21:00). See ISSUES.md issue 21 for the standing tasks.

[CmdletBinding()]
param(
  [switch] $Force,
  [string] $Since
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$ledgerFile = Join-Path $repo 'tools\securityScreen.ledger'
$reportDir  = Join-Path $repo 'docs\security-screens'
$log        = Join-Path $repo 'tools\securityScreen.log'

function Say([string] $msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format 's'), $msg
  Add-Content $log $line
  Write-Output $line
}

Say "===== security screen run ====="

# --- the watched surface -------------------------------------------------
#
# Steve asked whether the API and the UI are the only entry points. They
# are the only NETWORK-FACING ones, but they are not the only places
# attacker-controlled bytes cross into trusted code. The full list, and
# why each is here:
#
#   apiService.R, inst/api/plumber.R  - the REST surface: unauthenticated
#       bytes, straight off the wire.
#   app_server.R, app_ui.R           - the Shiny surface: uploads, and
#       everything rendered back to the uploader.
#   zipUpload.R                      - archive expansion: path traversal
#       and decompression bombs live here.
#   parse*.R, tokenize.R, pageLayout.R - the parsers. A manuscript is
#       written by the adversary in this threat model; poppler,
#       officer/libxml2 and our own regexes all consume it.
#   aiFallback.R                     - MODEL OUTPUT IS UNTRUSTED INPUT.
#       A hostile PDF can steer what the assistant returns, and what it
#       returns becomes rows, labels and CSV cells. This is an indirect
#       injection path into the editor's screen, and it is the entry
#       point least likely to be thought of as one.
#   outputComments.R                 - the log renders as HTML and
#       carries uploaded file names.
#   utils.R, validateData.R          - shared helpers on every path.
#   .github/workflows/, Dockerfile   - the deploy pipeline holds the
#       shinyapps and AWS credentials; compromise here beats any
#       application bug.
#   renv.lock, DESCRIPTION           - supply chain. A dependency can
#       change underneath code that did not.
#
# corpus/ and the rest of tools/ are deliberately ABSENT: they run only
# on Steve's machine, against files he chose, and nothing there ships.
$watched = @(
  'R/apiService.R', 'inst/api/plumber.R',
  'R/app_server.R', 'R/app_ui.R', 'R/app_run.R', 'R/app_globals.R',
  'R/zipUpload.R', 'R/outputComments.R', 'R/usageCount.R',
  'R/parseBaselineTable.R', 'R/parseBaselineTableFiles.R',
  'R/parseBaselineTableHeuristics.R', 'R/parseDocx.R',
  'R/parseWideTable.R', 'R/parsePDF-module.R', 'R/aiFallback.R',
  'R/tokenize.R', 'R/pageLayout.R', 'R/armNRecovery.R',
  'R/utils.R', 'R/validateData.R', 'R/baselineTable.R',
  'inst/scripts/', '.github/workflows/', 'Dockerfile',
  'renv.lock', 'DESCRIPTION'
)

# --- the gate ------------------------------------------------------------
$head = (git rev-parse HEAD).Trim()
$last = if ($Since) { $Since }
        elseif (Test-Path $ledgerFile) {
          (Get-Content $ledgerFile | Where-Object { $_ -match '^[0-9a-f]{7,40}\s' } |
             Select-Object -Last 1) -split '\s+' | Select-Object -First 1
        } else { '' }

if (-not $last) {
  Say "no ledger entry - screening the whole watched surface"
  $changed = $watched
} else {
  $diff = git diff --name-only "$last..$head" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Say "WARN: $last is not reachable (rebase or fresh clone) - screening all"
    $changed = $watched
  } else {
    $changed = $diff | Where-Object {
      $f = $_
      $watched | Where-Object { $f -eq $_ -or $f.StartsWith($_) }
    }
  }
}

if (-not $changed -and -not $Force) {
  Say "no watched file changed since $last - nothing to screen"
  Say "(the tripwire still ran on every push in the meantime)"
  exit 0
}

Say ("changed on the watched surface: " + (($changed | Sort-Object -Unique) -join ', '))

# --- the objective gate runs first --------------------------------------
# If the mechanical properties are already broken there is no point
# spending a screen: fix the lab value, then look at the film.
$rscript = 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe'
if (Test-Path $rscript) {
  $tw = & $rscript 'tools/securityCheck.R' 2>&1
  if ($LASTEXITCODE -ne 0) {
    Say "TRIPWIRE FAILED - screening stopped, fix this first:"
    $tw | ForEach-Object { Say "  $_" }
    exit 1
  }
  Say ("tripwire: " + ($tw | Select-Object -Last 1))
} else {
  Say "WARN: Rscript not found - tripwire not run"
}

# --- the screen ----------------------------------------------------------
New-Item -ItemType Directory -Force $reportDir | Out-Null
$stamp  = Get-Date -Format 'yyyy-MM-dd-HHmm'
$report = Join-Path $reportDir "screen-$stamp.md"

# The diff is fed to the screen as CONTEXT, not as the whole story: a
# finding usually lives in the interaction between changed code and code
# that did not change (the amplification bug was in an OUTPUT path whose
# INPUT gates all still passed). The prompt therefore names the diff and
# tells the reviewer to read outward from it.
$prompt = @"
You are performing a security screen of the IntegrityAnalysis repository
at $repo. Read AGENTS.md first, especially its "Security" section, which
records the threat model and the conclusions of previous screens.

SCOPE. Screen the changes between $last and $head. These watched files
moved: $(($changed | Sort-Object -Unique) -join ', ').

Read the diff with:  git diff $last..$head

Do not stop at the diff. Most real findings live in the interaction
between changed code and code that did not change - the worst finding to
date was an output path that expanded super-linearly while every input
gate on it still passed. Read outward from each change into the paths
that reach it and the paths it reaches.

THREAT MODEL. The manuscript author is the adversary. Uploaded PDFs,
docx files, spreadsheets and zips are hostile. The REST API takes
unauthenticated bytes off the wire. AI-assist responses are UNTRUSTED
INPUT, because a hostile document can steer what the model returns.
The app runs single-threaded on shared hosting, so resource exhaustion
is a real availability finding, not a theoretical one.

REPORT DISCIPLINE. For each finding give: the file and line, the
concrete path from attacker-controlled input to the effect, the actual
consequence, and a severity. Distinguish clearly between what you
VERIFIED by reading the code and what you SUSPECT. State it plainly when
you could not verify a claim - a previous screen reported arm names
reaching CSV headers as a live exploit when the headers were positional
literals, and that overstatement cost real time. An empty report is a
perfectly good result; do not manufacture findings to fill the page.

Recommend a fix for each finding, but DO NOT EDIT ANY FILES.

OUTPUT FORMAT - THIS MATTERS. Only your FINAL message is captured;
everything you say while working is discarded. Put the COMPLETE report
in that final message: every finding in full, with its file, line,
path, consequence, severity, and recommended fix. Do not end with a
summary that refers back to findings you described earlier - those
earlier words do not survive. If there are no findings, say so and say
what you checked. (The first run of this screen ended with an ordered
list of fixes for findings F1-F5 whose descriptions had all been lost.)
"@

# Resolve the CLI explicitly. A scheduled task does NOT inherit the
# interactive PATH, and claude lives in ~/.local/bin - exactly the bug
# that stopped the medRxiv harvester when `aws` could not be found from
# its task. Fail loudly rather than writing an empty report.
$claudeExe = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudeExe) {
  foreach ($c in @("$env:USERPROFILE\.local\bin\claude.exe",
                   "$env:USERPROFILE\.local\bin\claude",
                   "$env:LOCALAPPDATA\Programs\claude\claude.exe")) {
    if (Test-Path $c) { $claudeExe = $c; break }
  }
}
if (-not $claudeExe) {
  Say "ERROR: the claude CLI was not found - screen NOT run."
  Say "The range stays unclaimed; screen it interactively, or fix the path."
  Remove-Item $report -ErrorAction SilentlyContinue
  exit 1
}
Say "using $claudeExe"

Say "running the screen (this takes a few minutes)..."
$header = @"
# Security screen $stamp

- range: ``$last..$head``
- watched files changed: $(($changed | Sort-Object -Unique) -join ', ')
- tripwire: passed before this screen ran
- screen is READ-ONLY: findings below are recommendations, not applied changes

Adjudication rule: every finding is either fixed, or accepted here with a
written reason. The endpoint is "adjudicated", not "the next screen comes
back empty" - see the header of tools/securityScreen.ps1 for why.

---

"@
Set-Content -Path $report -Value $header -Encoding utf8

try {
  # --permission-mode plan: the screen READS. It cannot edit a file
  # even if a finding tempts it to, which is the point (see the
  # iatrogenic note in this file's header).
  $out = $prompt | & $claudeExe -p --permission-mode plan 2>&1
  Add-Content -Path $report -Value $out -Encoding utf8
  Say "report written: $report"
} catch {
  Say "SCREEN FAILED: $_"
  Add-Content -Path $report -Value "**The screen did not complete.** $_" -Encoding utf8
  exit 1
}

# --- advance the ledger --------------------------------------------------
# Only after a report exists. If the screen died, the next run rescreens
# the same range rather than silently skipping it.
Add-Content $ledgerFile ("{0}  {1}  {2}" -f $head, (Get-Date -Format 's'),
                         (Split-Path -Leaf $report))
Say "ledger advanced to $head"
Say "ADJUDICATE the findings in $report before the next merge."
