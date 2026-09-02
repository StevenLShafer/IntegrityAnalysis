# ingestNodes.ps1 - pull whatever the compute nodes downloaded into the
# master corpus, reindex, and hand off to the zipped backup.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5, Anthropic),
# 2026-08-31, at Steve Shafer's direction: "We will also need scripts so
# that any new runs on any machine moves the corpus into backup."
# Rewritten 2026-09-01 by Claude Code (Opus 5) after the first unattended
# run failed. Review status: the transfer path was exercised end-to-end
# against i5 before this was committed - see the VERIFIED note on
# Copy-NodeTar.
#
# THE PIPELINE, and it is deliberately one direction only:
#
#   oldryzen / i5 / surface  --(this script)-->  C:\dev\Corpus\_staging
#                            --(buildCorpusLibrary.R)-->  master\ + index\
#                            --(backupCorpusZip.ps1)-->   OneDrive
#
# newryzen is NOT in that list: it is the Windows machine the corpus lives
# on, and it was named as a node here in error. See the node table below.
#
# The nodes are PRODUCERS. They fetch; they are never the archive. Nothing
# here writes back to a node and nothing deletes from one, so a node can be
# rebuilt from bare metal - as oldryzen was - without the corpus caring.
#
# INCREMENTAL BY MODIFICATION TIME. Each node gets a stamp file recording
# when it was last ingested; the next run asks that node for files newer
# than the stamp. The stamp is written only AFTER the extract succeeds, so
# an interrupted run re-fetches rather than skipping - the failure mode
# that loses data is the one worth being clumsy about.
#
############################################################################
# WHY THIS WAS REWRITTEN - four defects, and the first run found all four  #
#                                                                          #
# The 04:00 run on 2026-09-01 was the first unattended execution. It wrote #
# ONE line to index\ingest.log - the header - and exited 1. Nothing was    #
# ingested. index\ingest\ held no stamp files and _source\ was empty:      #
# NOTHING had ever been ingested, on any run.                              #
#                                                                          #
# 1. WRONG DESTINATION. This script wrote to C:\dev\Corpus\_source.        #
#    buildCorpusLibrary.R reads C:\dev\Corpus\_staging - every src() row   #
#    for node-produced material points at $staging. The two were never the #
#    same path, so even a perfect transfer would have delivered into a     #
#    directory that nothing indexes. That is the defect which made all the #
#    others invisible: the pipeline could not have worked even if it ran.  #
#                                                                          #
# 2. /tmp IS RAM. The old design built the tarball at /tmp/ingest_*.tgz on #
#    the node. /tmp is tmpfs on all three: 31 GB on oldryzen, 7.5 GB on    #
#    surface and i5. Staging oldryzen's 9.4 GB pmc_corpus there put 6.9 GB #
#    into RAM - it was still sitting there, orphaned, seven hours after    #
#    the task had exited. surface's ctgov_docs is 35 GB against a 7.5 GB   #
#    tmpfs, so THAT transfer could never have succeeded, and would have    #
#    driven the box into swap before failing. Nothing stages on a node now #
#    at all: tar writes to stdout and ssh carries it here.                 #
#                                                                          #
# 3. STDERR WAS FATAL, SILENTLY. $ErrorActionPreference = 'Stop' plus      #
#    "& ssh ... 2>&1" is a trap specific to Windows PowerShell 5.1: native #
#    stderr under 2>&1 arrives as ErrorRecords, and 'Stop' makes the first #
#    one TERMINATE the script - before reaching the Say() that would have  #
#    explained why. Every native call now goes through Invoke-Native,      #
#    which drops to 'Continue' for the duration and returns the exit code  #
#    as data to be checked.                                                #
#                                                                          #
# 4. NOTHING WAS LOGGED UNTIL SUCCESS. The old loop logged on failure or   #
#    after a completed pull and nothing in between, so a transfer that ran #
#    for seven hours produced no output at all. Every step now announces   #
#    itself BEFORE it starts, with the numbers it is about to act on. A    #
#    log that records only success cannot report a hang - the 2026-08-31   #
#    handoff's standing lesson, applied to this file.                      #
#                                                                          #
# Also removed: the oldryzen 'journals' row. That directory is a copy of   #
# C:\temp\Journals pushed TO the node for a run (3,267 files on both       #
# sides), no src() row reads the pulled copy, and re-fetching it spent 586 #
# MB of wire on every first run to produce a directory nothing indexes.    #
############################################################################

param(
  # Limit the run to these node names, for testing a change against one
  # small directory instead of eleven gigabytes.
  [string[]] $Only,
  # Stop after the transfers - skip reindex, identity resolution and the
  # backup hand-off. The reindex rewrites the whole index and the backup
  # rewrites ~23 GB, so a transfer under test has to be able to run
  # without triggering either.
  [switch] $TransferOnly
)

$ErrorActionPreference = 'Stop'

# INTEGRITY_CORPUS, honoured the same way corpus/buildCorpusLibrary.R and
# the rest of the corpus tooling honour it. This is what makes the
# transfer path testable: point it at a scratch directory and the run
# exercises probe, pre-flight, stream, verify, extract and stamp without
# writing anywhere near the real library. An untested transfer is how the
# 04:00 failure got as far as production in the first place.
$corpus  = if ($env:INTEGRITY_CORPUS) { $env:INTEGRITY_CORPUS } else { 'C:\dev\Corpus' }
$staging = Join-Path $corpus '_staging'
$stamps  = Join-Path $corpus 'index\ingest'
$log     = Join-Path $corpus 'index\ingest.log'
$rscript = 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe'

# TAR BY ABSOLUTE PATH, because WHICH tar you get decides whether this
# works at all. Windows ships bsdtar at System32\tar.exe. When Git for
# Windows' usr\bin sits ahead of System32 on PATH - as it does inside a
# Git Bash shell, though not in the persisted PATH the scheduler uses - a
# bare "tar" resolves to GNU tar instead, and GNU tar reads a Windows path
# as a REMOTE host spec: "C:\Users\...\x.tar" is parsed as host "C" and
# path "\Users\...". It fails with "Cannot connect to C: resolve failed",
# which looks nothing like a PATH problem and reads exactly like a corrupt
# archive.
#
# Observed 2026-09-01: byte-identical transfers verified when the script
# was launched from PowerShell and "failed verification" when launched
# from a Git Bash shell. The archives were perfect both times. Naming the
# executable removes the ambiguity permanently.
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path $tarExe)) { $tarExe = 'tar' }

New-Item -ItemType Directory -Force $staging | Out-Null
New-Item -ItemType Directory -Force $stamps  | Out-Null
function Say($m) {
  Add-Content $log ((Get-Date -Format 's') + '  ' + $m)
  Write-Host $m
}

############################################################################
# Invoke-Native - run an external program without letting its stderr kill  #
# the script.                                                              #
#                                                                          #
# In Windows PowerShell 5.1, "& someExe ... 2>&1" wraps each stderr line   #
# in an ErrorRecord. Under $ErrorActionPreference = 'Stop' the first such  #
# record is a TERMINATING error, so a program that merely warns takes the  #
# whole script down before any handler or log line runs. That is exactly   #
# how the 2026-09-01 04:00 run vanished after a single log line.           #
#                                                                          #
# Dropping to 'Continue' for the duration of the call is the documented    #
# way out. Casting each record to [string] flattens stderr and stdout into #
# plain text, and the exit code comes back as data rather than as an       #
# exception that has to be caught.                                         #
############################################################################
function Invoke-Native {
  param([Parameter(Mandatory)][string] $Exe,
        [string[]] $Arguments = @())
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $text = & $Exe @Arguments 2>&1 | ForEach-Object { [string]$_ }
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $prev }
  [pscustomobject]@{ Text = @($text); Code = $code }
}

# Run a command on a node and return its output and exit status. BatchMode
# so a missing key fails immediately instead of waiting on a password
# prompt that no unattended run can answer.
function Invoke-Node {
  param([string] $NodeName, [string] $Command)
  Invoke-Native 'ssh' @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=20',
                        $NodeName, $Command)
}

############################################################################
# Copy-NodeTar - stream a tar of the node's new files straight into a      #
# local file. Nothing is staged on the node.                               #
#                                                                          #
# WHY A GENERATED .cmd FILE. The bytes must not pass through a PowerShell  #
# pipeline - PowerShell 5.1 decodes native output as text and corrupts     #
# binary, which is why the original design staged a file and used scp.     #
# cmd.exe's ">" is byte-exact, so the redirection happens there. The       #
# command line is WRITTEN to a .cmd file rather than passed as arguments,  #
# because argument passing to cmd.exe re-parses quotes and this project    #
# has been bitten by embedded-quote mangling before. Writing the file      #
# ourselves means the exact text we intend is the exact text that runs.    #
#                                                                          #
# ssh exits with the REMOTE command's status, so the exit code from cmd is #
# tar's own - a stronger check than the old EXIT:<n> marker printed into   #
# the output stream, and one that cannot be confused with data.            #
#                                                                          #
# NOT COMPRESSED, deliberately. The LAN is 1 Gb (~125 MB/s) and gzip -1 on #
# one core of these boxes runs at about the same rate, so compression buys #
# nothing on the wire while adding a way to fail. The old "tar czf" also   #
# spent its time compressing PDFs, which are already deflate-compressed.   #
#                                                                          #
# VERIFIED 2026-09-01 end-to-end against i5:~/work/ctgov_corpus - streamed,#
# listed and extracted, with file counts compared on both sides.           #
############################################################################
function Copy-NodeTar {
  param([string] $NodeName, [string] $RemoteDir, [string] $Since,
        [string] $Select, [string] $OutFile, [string] $Tag)

  # ONE SELECTOR, USED TWICE. The pre-flight counts with this same find
  # expression, so the number in the log is the number of files that
  # actually ship. Two independently written selections - tar --exclude
  # here, find -not -path there - would be free to disagree, and the way
  # they would report it is a count that quietly stops matching reality.
  $remote = "set -o pipefail; cd `$HOME/$RemoteDir && " +
            "find . $Select -newermt '$Since UTC' -print0 | tar cf - --null -T -"

  $cmdFile = Join-Path $env:TEMP "ingest_pull_$Tag.cmd"
  $line = 'ssh -o BatchMode=yes -o ConnectTimeout=20 {0} "{1}" > "{2}"' -f $NodeName, $remote, $OutFile
  # ASCII, so no UTF-8 BOM: cmd.exe reads a BOM as part of the first
  # command and fails with an unhelpful parse error.
  Set-Content -Path $cmdFile -Value @('@echo off', $line) -Encoding ascii

  $r = Invoke-Native 'cmd.exe' @('/c', $cmdFile)
  Remove-Item $cmdFile -Force -ErrorAction SilentlyContinue
  $r
}

Say '===== node ingest ====='
if ($Only)         { Say ('  limited to: ' + ($Only -join ', ')) }
if ($TransferOnly) { Say '  -TransferOnly: no reindex, no identity pass, no backup' }

############################################################################
# What each node produces, and where it lands locally.                     #
#                                                                          #
# Dest is an ABSOLUTE path and it must match a src() row in                #
# corpus/buildCorpusLibrary.R, or the material will be ingested and then   #
# never indexed - defect 1 above. The matching row is named on each entry  #
# so that the two lists can be checked against each other by eye.          #
#                                                                          #
# THE THREE COMPUTE NODES ARE oldryzen, i5 AND surface.                    #
#                                                                          #
# This list was wrong in both directions when first written. It named      #
# "newryzen", which is THIS Windows machine - the one the corpus lives on  #
# - and it omitted "surface" entirely. The first error was well disguised: #
# newryzen resolves to a link-local IPv6 address and answers ping, so it   #
# read as a node that was merely down rather than a category error; what   #
# gives it away is that it runs no sshd and has no ~/.ssh/config entry.    #
#                                                                          #
# The second error was the expensive one. surface holds ctgov_docs - now   #
# 20,001 ClinicalTrials.gov posted protocols, statistical analysis plans   #
# and consent forms, 35 GB - and none of it reached the library, because   #
# the original inventory checked oldryzen and i5 and never looked. Two of  #
# three nodes is not an inventory.                                         #
#                                                                          #
# The medRxiv rows were missing until 2026-09-01 and were the specific gap #
# the handoff called out. All three nodes harvest medRxiv into the same    #
# DOI-named namespace and are working disjoint month folders, so they      #
# share one destination: a preprint lands under its own DOI whichever node #
# fetched it, and buildCorpusLibrary.R dedups on content hash regardless.  #
#                                                                          #
# Select is a find(1) expression, and it is the ONLY place a row says what #
# it wants. medRxiv takes PDFs and nothing else, for two reasons. The      #
# harvest directory also holds the node's own working state - harvest.lock #
# and heartbeat.log - and copying those here overwrites the LOCAL          #
# harvester's state with another machine's; a stale lock is exactly the    #
# kind of thing that stops a job while looking like nothing happened.      #
# ("incoming" holds partially-downloaded .meca packages, which -name       #
# '*.pdf' already excludes; the -not -path clause is kept so that a        #
# half-written PDF appearing there could never be indexed as a real one.)  #
# The other three sources take every file, which is what their src() rows  #
# expect.                                                                  #
############################################################################
############################################################################
# THE medRxiv DESTINATION IS NOT DERIVED FROM INTEGRITY_CORPUS BY DEFAULT,
# and the reason is the whole subject of this file.
#
# buildCorpusLibrary.R indexes medRxiv at a FIXED path - src("medrxiv",
# "C:/temp/medrxiv_rct") - because that collection lives outside the corpus
# tree. An earlier draft here redirected medRxiv whenever INTEGRITY_CORPUS
# was set, which is exactly right for an isolated test and exactly wrong
# for anyone who sets that variable to relocate a real corpus: the transfer
# would report success, the stamp would advance, and the files would sit in
# a directory the indexer never reads. That is defect 1 of this rewrite,
# reintroduced one directory over. (CodeRabbit flagged it on PR #135.)
#
# So the override is its own variable, and choosing it is deliberate.
# INTEGRITY_CORPUS alone no longer moves medRxiv silently - it says so.
############################################################################
$medrxivDefault = 'C:\temp\medrxiv_rct'   # must match src("medrxiv")
# INTEGRITY_CORPUS does NOT move medRxiv. Only INTEGRITY_MEDRXIV does, and
# only when someone sets it on purpose. An intermediate version kept the
# INTEGRITY_CORPUS fallback and merely WARNED about it - but a warning in a
# log nobody reads is not a guard, and this repository has a long record of
# exactly that. A variable that relocates the corpus should not quietly
# relocate a collection stored outside it.
$medrxiv = if ($env:INTEGRITY_MEDRXIV) { $env:INTEGRITY_MEDRXIV } else { $medrxivDefault }
if ($medrxiv -ne $medrxivDefault) {
  Say ("NOTE: INTEGRITY_MEDRXIV sends medRxiv to {0}, NOT the indexed path {1}." -f $medrxiv, $medrxivDefault)
  Say  '      buildCorpusLibrary.R reads the indexed path, so nothing landing'
  Say  '      here will appear in the corpus. Correct for an isolated test;'
  Say  '      wrong for a real run.'
}
$allFiles = '-type f'
$pdfsOnly = "-type f -name '*.pdf' -not -path './incoming/*'"
$workerPdfs = "-type f -name '*.pdf' -path './medrxiv_w*' -not -path '*/incoming/*'"

$nodes = @(
  @{ Node = 'oldryzen'; Remote = 'work/pmc_corpus';   Local = 'pmc_corpus'
     Dest = (Join-Path $staging 'pmc_corpus')  # src("pmc-oa")
     Select = $allFiles },
  @{ Node = 'i5';       Remote = 'work/ctgov_corpus'; Local = 'ctgov'
     Dest = (Join-Path $staging 'ctgov')       # src("ctgov")
     Select = $allFiles },
  @{ Node = 'surface';  Remote = 'work/ctgov_docs';   Local = 'ctgov_docs'
     Dest = (Join-Path $staging 'ctgov_docs')  # src("ctgov-docs")
     Select = $allFiles },
  @{ Node = 'oldryzen'; Remote = 'work/medrxiv_rct';  Local = 'medrxiv_rct'
     Dest = $medrxiv                           # src("medrxiv")
     Select = $pdfsOnly },
  @{ Node = 'i5';       Remote = 'work/medrxiv_rct';  Local = 'medrxiv_rct'
     Dest = $medrxiv                           # src("medrxiv")
     Select = $pdfsOnly },
  @{ Node = 'surface';  Remote = 'work/medrxiv_rct';  Local = 'medrxiv_rct'
     Dest = $medrxiv                           # src("medrxiv")
     Select = $pdfsOnly },

  # THE PARALLEL HARVEST WORKERS, added 2026-09-01. harvestMedrxivS3.R
  # takes a single-instance lock per outDir, so the 24 workers launched to
  # finish the bucket backlog each write to their own ~/work/medrxiv_wNN.
  # Without these rows their output would sit on the nodes forever - the
  # same gap the handoff flagged for medrxiv_rct itself, one directory
  # further out.
  #
  # Remote is ~/work and the selector picks the medrxiv_w* trees, so a
  # worker added or removed later needs no change here. Files arrive as
  # medrxiv_w07\<doi>.pdf under the medRxiv destination; src("medrxiv") is
  # recursive, so nesting is indexed exactly like a flat drop, and a
  # preprint fetched twice collapses on content hash.
  @{ Node = 'oldryzen'; Remote = 'work';              Local = 'medrxiv_workers'
     Dest = $medrxiv                           # src("medrxiv")
     Select = $workerPdfs },
  @{ Node = 'i5';       Remote = 'work';              Local = 'medrxiv_workers'
     Dest = $medrxiv                           # src("medrxiv")
     Select = $workerPdfs },
  @{ Node = 'surface';  Remote = 'work';              Local = 'medrxiv_workers'
     Dest = $medrxiv                           # src("medrxiv")
     Select = $workerPdfs }
)

# Guard the class of mistake rather than just the instance. A node entry
# naming this machine would ssh to itself, and if an sshd were ever
# installed here it would "succeed" - tarring the corpus and extracting it
# back over itself. Refuse by name before anything is copied.
$selfNames = @($env:COMPUTERNAME, [System.Net.Dns]::GetHostName()) |
             ForEach-Object { $_.ToLower() } | Select-Object -Unique
$nodes = @($nodes | Where-Object {
  if ($selfNames -contains $_.Node.ToLower()) {
    Say ('SKIP {0}: that is this machine, not a compute node' -f $_.Node)
    $false
  } else { $true }
})
if ($Only) { $nodes = @($nodes | Where-Object { $Only -contains $_.Node }) }

# The remote command is built without quoting, which is safe only while no
# remote path contains a space. Assert it rather than assume it: the
# failure would be a tar of the WRONG DIRECTORY, not an error.
foreach ($n in $nodes) {
  if ($n.Remote -match '\s') {
    throw ("node path '{0}' contains a space; the unquoted remote command cannot " +
           'carry it. NOTHING WAS TRANSFERRED.' -f $n.Remote)
  }
}

# Legacy cleanup: the pre-2026-09-01 design left tarballs in /tmp, which is
# RAM on these boxes - one was still holding 6.9 GB of oldryzen's memory.
# Nothing writes them any more, so anything found is stale by definition.
foreach ($node in ($nodes | ForEach-Object { $_.Node } | Select-Object -Unique)) {
  $r = Invoke-Node $node 'ls -1 /tmp/ingest_*.tgz 2>/dev/null | wc -l'
  if ($r.Code -eq 0 -and ($r.Text -join '') -match '([1-9]\d*)') {
    Say ('{0}: removing {1} stale /tmp tarball(s) left by the old design (tmpfs = RAM)' -f $node, $Matches[1])
    Invoke-Node $node 'rm -f /tmp/ingest_*.tgz' | Out-Null
  }
}

$changed = $false

foreach ($n in $nodes) {
  $tag   = $n.Node + '-' + $n.Local
  $stamp = Join-Path $stamps "$tag.stamp"
  $dest  = $n.Dest

  ########################################################################
  # STAMPS ARE UTC, AND SAY SO WHEN THEY ARE USED.
  #
  # The stamp used to be written with Get-Date, i.e. Windows LOCAL time,
  # and handed to find -newermt on a node whose clock is UTC. newryzen
  # runs PDT, so a stamp of "05:47:03" was read on the node as 05:47 UTC -
  # 22:47 the previous evening in Steve's time - and every incremental run
  # silently re-fetched the last SEVEN HOURS of files. Measured: a rerun
  # one minute after a clean pull reported 309 new files, all of which had
  # just been transferred.
  #
  # Over-fetching wastes bandwidth and is otherwise harmless, which is why
  # it could have run for months unnoticed. The direction is what makes it
  # worth fixing anyway: the same defect with the offset reversed - a node
  # ahead of this machine rather than behind it - would skip files instead
  # of repeating them, advance the stamp past them, and leave a permanent
  # hole in the corpus. A bug that is benign only because of which way a
  # timezone happens to point is not benign.
  #
  # Both halves are explicit now: written with ToUniversalTime(), read
  # back with a literal " UTC" appended, which GNU find parses (verified
  # on i5, 2026-09-01).
  ########################################################################
  $since = '1970-01-01 00:00:00'
  if (Test-Path $stamp) { $since = (Get-Content $stamp -Raw).Trim() }
  $started = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
  Say ('--- {0}: {1}  (new since {2})' -f $tag, $n.Remote, $since)

  # Is the node up? A box that is down is normal here and must not fail
  # the whole run.
  $probe = Invoke-Node $n.Node 'echo up'
  if ($probe.Code -ne 0) {
    Say ('  SKIP: unreachable ({0})' -f ($probe.Text | Select-Object -First 1))
    continue
  }

  # PRE-FLIGHT, so the log says what is about to happen while it is still
  # about to happen. The old script announced a transfer only once it had
  # finished, which is why a seven-hour tar looked exactly like a script
  # that had never started. It also replaces the old "a tar.gz under 200
  # bytes means nothing new" heuristic with a direct count.
  # THE EXCLUDE PATTERN MUST BE QUOTED, and set -o pipefail is what makes
  # the mistake visible if it ever stops being.
  #
  # Written unquoted, "-not -path ./incoming/*" is expanded by the REMOTE
  # SHELL before find ever sees it. On i5 it became thirty-nine .meca
  # filenames, find died with "paths must precede expression", and because
  # a pipeline's status is awk's rather than find's, the pre-flight
  # returned a clean "0 0". The script reported "no new files" for a
  # directory holding 579 of them and advanced the stamp past every one:
  # an error that presents as success, caught only by cross-checking the
  # count against a number already known. That is the 2026-08-31 lesson
  # arriving in new clothes on the day it was written down. pipefail makes
  # find's failure the command's failure, so the next version of this
  # mistake stops the transfer instead of silently emptying it.
  # awk prints two bare numbers - count, then bytes - and no literal text.
  # Labels would need double quotes inside a PowerShell double-quoted
  # string inside a remote shell command, and every quote that survives
  # that journey is a quote that can be mangled on it.
  $q  = "set -o pipefail; " +
        "test -d `$HOME/$($n.Remote) || { echo MISSING; exit 0; }; " +
        "cd `$HOME/$($n.Remote) && " +
        "find . $($n.Select) -newermt '$since UTC' -printf '%s\n' | " +
        "awk '{n++; b+=`$1} END {print n+0, b+0}'"
  $pf = Invoke-Node $n.Node $q
  $pfText = ($pf.Text -join ' ')
  if ($pf.Code -ne 0) {
    Say ('  SKIP: pre-flight failed ({0})' -f ($pf.Text | Select-Object -First 1))
    continue
  }
  if ($pfText -match 'MISSING') {
    Say '  SKIP: remote directory does not exist (node has not run this harvest)'
    continue
  }
  # Match the LAST line on its own rather than the joined text: ssh may
  # print a warning before the answer, and a pattern anchored to joined
  # output would then silently fail to find a perfectly good count.
  $last = ($pf.Text | Where-Object { $_.Trim() } | Select-Object -Last 1)
  if ($last -notmatch '^\s*(\d+)\s+(\d+)\s*$') {
    Say ('  SKIP: pre-flight gave no usable answer ({0})' -f $pfText)
    continue
  }
  $count = [int64]$Matches[1]
  $bytes = [int64]$Matches[2]
  if ($count -eq 0) {
    Say '  ok: no new files'
    Set-Content $stamp $started -Encoding ascii
    continue
  }
  Say ('  {0} new file(s), {1} MB - streaming, no node-side staging' -f $count, [math]::Round($bytes / 1MB, 1))

  ########################################################################
  # Room to receive it - on BOTH volumes, because they need not be one.
  #
  # The archive streams into %TEMP% and the extracted copy lands in $dest.
  # The first version measured only $dest and applied the combined 2.2x
  # headroom there, so a %TEMP% on a different volume could fill mid-stream
  # while the check reported plenty of room. The stamp is not advanced on
  # that path, so the cost is a transfer that repeats rather than data that
  # is lost - but a guard that measures the wrong disk is not a guard.
  #
  # And Split-Path -Qualifier returns NOTHING for a UNC or relative path.
  # Get-PSDrive '' then throws, and under $ErrorActionPreference = 'Stop'
  # that aborts the whole loop and silently skips every remaining node -
  # one unusual path taking out the entire run. Skip the row instead.
  # (Both found by CodeRabbit on PR #135.)
  ########################################################################
  # ACCUMULATE BY VOLUME. Checking each path separately was wrong whenever
  # %TEMP% and $dest share a drive - the common case - because 1.1x was
  # tested twice against the same unchanged free-space figure, so a disk
  # with 1.5x free passed both checks and then could not hold the archive
  # and the extracted copy together. Summing per resolved volume gives
  # 2.2x when they are co-located and 1.1x each when they are not.
  $roomOk = $true
  $need = @{}
  foreach ($vol in @($env:TEMP, $dest)) {
    $q = (Split-Path $vol -Qualifier)
    if (-not $q) {
      Say ('  SKIP: cannot determine the volume for {0} (UNC or relative path?) - stamp NOT advanced' -f $vol)
      $roomOk = $false; break
    }
    $key = $q.TrimEnd(':')
    $need[$key] = [int64]$need[$key] + [int64]($bytes * 1.1)
  }
  if ($roomOk) {
    foreach ($key in $need.Keys) {
      $drive = Get-PSDrive $key -ErrorAction SilentlyContinue
      if (-not $drive) {
        Say ('  SKIP: no such drive {0}: - stamp NOT advanced' -f $key)
        $roomOk = $false; break
      }
      if ($drive.Free -lt $need[$key]) {
        Say ('  FAILED: {0}: needs about {1} MB free and has {2} MB - stamp NOT advanced' -f
             $key, [math]::Round($need[$key] / 1MB), [math]::Round($drive.Free / 1MB))
        $roomOk = $false; break
      }
    }
  }
  if (-not $roomOk) { continue }

  $tar = Join-Path $env:TEMP "ingest_$tag.tar"
  if (Test-Path $tar) { Remove-Item $tar -Force }
  $t0 = Get-Date
  $r = Copy-NodeTar -NodeName $n.Node -RemoteDir $n.Remote -Since $since `
                    -Select $n.Select -OutFile $tar -Tag $tag
  $secs = [math]::Round(((Get-Date) - $t0).TotalSeconds)

  # ssh returns the remote tar's exit status, so a partial archive shows
  # up here rather than being discovered as a hole in the corpus months
  # later. The stamp is not advanced on any of these paths, so the files
  # are simply fetched again next time.
  if ($r.Code -ne 0 -or -not (Test-Path $tar)) {
    Say ('  FAILED: remote tar exited {0} after {1}s - stamp NOT advanced, will retry' -f $r.Code, $secs)
    if ($r.Text) { Say ('    ' + (($r.Text | Select-Object -First 2) -join ' / ')) }
    if (Test-Path $tar) { Remove-Item $tar -Force }
    continue
  }
  Say ('  received {0} MB in {1}s' -f [math]::Round((Get-Item $tar).Length / 1MB, 1), $secs)

  # LIST BEFORE EXTRACTING. A truncated stream is still a readable file;
  # tar -t walks every header and fails on the one that was cut off.
  $chk = Invoke-Native $tarExe @('-tf', $tar)
  if ($chk.Code -ne 0) {
    # SAY WHAT TAR SAID. The first version of this handler reported only
    # "truncated stream", which is a guess about the cause rather than the
    # evidence - and when it fired on 2026-09-01 the archive turned out to
    # verify perfectly by hand, so the guess was wrong and the message sent
    # the diagnosis in the wrong direction for twenty minutes. An error
    # handler that does not print what it observed is the same defect this
    # repository keeps rediscovering.
    Say ('  FAILED: archive did not verify (tar exit {0}) - stamp NOT advanced, will retry' -f $chk.Code)
    if ($chk.Text) { Say ('    tar said: ' + ((($chk.Text | Where-Object { $_ -match '\S' }) | Select-Object -First 2) -join ' / ')) }
    Say ('    kept for inspection: ' + $tar)
    continue
  }

  New-Item -ItemType Directory -Force $dest | Out-Null
  $x = Invoke-Native $tarExe @('-xf', $tar, '-C', $dest)
  if ($x.Code -ne 0) {
    Say ('  FAILED: extract failed ({0}) - stamp NOT advanced, will retry' -f ($x.Text | Select-Object -First 1))
    Remove-Item $tar -Force
    continue
  }
  Remove-Item $tar -Force
  # Only now, after a clean extract.
  Set-Content $stamp $started -Encoding ascii
  Say ('  PULLED into {0}' -f $dest)
  $changed = $true
}

if ($TransferOnly) { Say '===== done (transfers only) ====='; return }

# --- reindex ------------------------------------------------------------
# Cheap when nothing arrived: the hash cache in index/hashCache.csv means
# unchanged files are not re-read, so a quiet night costs a directory walk
# rather than 24 GB of I/O. Run it regardless, because a local edit (a
# manual download into .NewCarlisle) is also a reason to reindex.
Say 'reindexing'
$b = Invoke-Native $rscript @('C:\dev\IntegrityAnalysis\corpus\buildCorpusLibrary.R')
$b.Text | Select-Object -Last 12 | ForEach-Object { Say ('  ' + $_) }
if ($b.Code -ne 0) {
  # The builder refuses to write a bad index rather than writing one, so a
  # non-zero exit means the index still describes the last good state.
  # Stopping here is right: resolving identities against a stale index, or
  # backing it up as though it were new, would spread the failure.
  Say ('REINDEX FAILED (exit {0}) - index unchanged, skipping identity and backup' -f $b.Code)
  Say '===== done (with errors) ====='
  exit 1
}

# --- identity, only for what is new -------------------------------------
# Run it after EVERY reindex, not only after a node transfer. The reindex
# above also picks up local additions - a PDF hand-downloaded into
# .NewCarlisle, which is Steve's daily handful - and those create blank
# identity rows too. Gating on $changed would leave them unresolved until
# some unrelated node happened to deliver something. The script fills only
# blank rows, so on a genuinely quiet night this costs two positive-control
# calls and stops.
Say 'resolving identities for any unresolved accessions'
$i = Invoke-Native $rscript @('C:\dev\IntegrityAnalysis\corpus\fetchCorpusIdentity.R')
$i.Text | Select-Object -Last 12 | ForEach-Object { Say ('  ' + $_) }
if ($i.Code -ne 0) {
  # Not fatal to the backup: identity is additive, and a failed NCBI pass
  # leaves rows blank rather than wrong. It IS worth saying loudly, because
  # the positive controls in that script exist precisely to stop a moved
  # endpoint from reporting a clean run.
  Say ('  identity pass exited {0} - rows left blank, backup continues' -f $i.Code)
}

# --- backup -------------------------------------------------------------
Say 'handing off to the zipped backup'
$k = Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass',
       '-File', 'C:\dev\IntegrityAnalysis\tools\backupCorpusZip.ps1')
$k.Text | Select-Object -Last 20 | ForEach-Object { Say ('  ' + $_) }
if ($k.Code -ne 0) { Say ('  backup exited {0}' -f $k.Code) }

Say '===== done ====='
