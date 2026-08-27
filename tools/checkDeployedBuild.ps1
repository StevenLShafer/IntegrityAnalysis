# checkDeployedBuild.ps1 - is the live app running the code we think?
#
# PROVENANCE: written 2026-08-27 by Claude Code (model Claude Opus 5),
# ISSUES.md issue 28, from Steve's question "do we have checks so that
# shinyapps.io itself doesn't become malware?"
#
# The answer was: the pipeline is guarded, the artifact is not. Deploys
# can only install from GitHub, the tripwire gates deploy-production,
# forks get no secrets - and none of that would tell anyone if a person
# holding the rsconnect token deployed something else. This closes that
# by comparing the commit the LIVE app reports (R/buildInfo.R) against
# origin/main.
#
# HONEST LIMITS, because the whole point of the exercise was that a
# guarantee should survive checking:
#  - This is NOT attestation. Whoever can deploy arbitrary code can
#    also make it report an arbitrary commit. A determined attacker who
#    knows this check exists echoes the expected hex and passes.
#  - What it reliably catches: a deploy from the wrong branch, a stale
#    deploy nobody noticed, a rollback that never rolled forward, a fix
#    applied by hand to the host, and tampering by anyone who did not
#    think about this file.
#  - A DIVERGENCE IS NOT AUTOMATICALLY AN ATTACK. The ordinary cause is
#    that main moved and no deploy has run yet. The report says which
#    direction the difference goes, because "behind main" and "not a
#    commit in this repository at all" mean very different things - the
#    second is the one to be alarmed by.
#
# Usage:  pwsh tools/checkDeployedBuild.ps1
#         pwsh tools/checkDeployedBuild.ps1 -ApiUrl https://host/health

[CmdletBinding()]
param(
  [string] $AppUrl = 'https://steveshafer.shinyapps.io/IntegrityAnalysis/',
  [string] $ApiUrl = '',
  [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$log = Join-Path $repo 'tools\checkDeployedBuild.log'

# Write-HOST, not Write-Output, and the distinction is load-bearing.
# With Write-Output every narration line joins the RETURN VALUE of
# whatever function is running, so `$problems += Compare-Build ...` was
# adding an array of strings to an integer. PowerShell reported that as
# "op_Addition" failing inside the try block, which the catch then
# rendered as "UNREACHABLE" - a security check announcing the wrong
# failure, which is worse than one that simply breaks. (2026-08-27)
function Say([string] $msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format 's'), $msg
  Add-Content $log $line
  if (-not $Quiet) { Write-Host $line }
}

Say "===== deployed-build check ====="

# What SHOULD be running: origin/main, fetched rather than assumed, so
# a stale local clone cannot make a mismatch look like a match.
git fetch -q origin main 2>$null
$expected = (git rev-parse origin/main 2>$null)
if (-not $expected) {
  Say "ERROR: could not resolve origin/main - check skipped, NOT passed"
  exit 1
}
$expected = $expected.Trim()
Say "origin/main is $($expected.Substring(0,8))"

$problems = 0

function Compare-Build([string] $what, [string] $found) {
  if (-not $found -or $found -eq 'unknown') {
    Say "$what : reports NO build commit"
    Say "  -> a build older than issue 28, or something that is not our app."
    Say "     Deploy current main and re-run before treating this as benign."
    return 1
  }
  if ($found -eq $script:expected) {
    Say "$what : $($found.Substring(0,8)) - matches origin/main"
    return 0
  }
  # Is it at least a commit in this repository? That distinction is the
  # useful part of the report.
  $known = $false
  try {
    git cat-file -e "$found^{commit}" 2>$null
    $known = ($LASTEXITCODE -eq 0)
  } catch { $known = $false }

  if ($known) {
    $behind = (git rev-list --count "$found..origin/main" 2>$null)
    Say "$what : $($found.Substring(0,8)) - DIFFERS from origin/main"
    Say "  -> it IS a commit in this repository, $behind commit(s) behind main."
    Say "     Ordinary cause: main moved and no deploy has run. Check whether"
    Say "     a deploy is expected; this is not by itself evidence of tampering."
  } else {
    Say "$what : $found - NOT A COMMIT IN THIS REPOSITORY"
    Say "  -> This is the alarming case. Nothing in the deploy path can put"
    Say "     an unknown commit here. Treat the deployment as untrusted:"
    Say "     rotate the rsconnect token, redeploy from main, and check the"
    Say "     shinyapps account's activity log."
  }
  return 1
}

# --- the app: read the meta tag out of the initial HTML ----------------
try {
  $html = (Invoke-WebRequest -Uri $AppUrl -TimeoutSec 60 -UseBasicParsing).Content
  $m = [regex]::Match($html,
       '<meta[^>]*name="integrity-build"[^>]*content="([^"]*)"')
  if (-not $m.Success) {
    # attribute order is not guaranteed by the HTML generator
    $m = [regex]::Match($html,
         '<meta[^>]*content="([^"]*)"[^>]*name="integrity-build"')
  }
  $verdict = Compare-Build "app  $AppUrl" $(if ($m.Success) { $m.Groups[1].Value } else { '' })
  $problems += @($verdict)[-1]
} catch {
  Say "app  $AppUrl : UNREACHABLE - $($_.Exception.Message)"
  Say "  -> unreachable is not the same as compromised, but it is also not a pass."
  $problems++
}

# --- the API: /health carries it as a field ----------------------------
if ($ApiUrl) {
  try {
    $h = Invoke-RestMethod -Uri $ApiUrl -TimeoutSec 60
    $verdict = Compare-Build "api  $ApiUrl" $h.commit
    $problems += @($verdict)[-1]
  } catch {
    Say "api  $ApiUrl : UNREACHABLE - $($_.Exception.Message)"
    $problems++
  }
}

if ($problems -eq 0) {
  Say "OK - everything reachable is running origin/main"
  exit 0
}
Say "$problems problem(s) above - read the direction of the difference before acting"
exit 1
