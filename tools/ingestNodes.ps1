# ingestNodes.ps1 - pull whatever the compute nodes downloaded into the
# master corpus, reindex, and hand off to the zipped backup.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5, Anthropic),
# 2026-08-31, at Steve Shafer's direction: "We will also need scripts so
# that any new runs on any machine moves the corpus into backup."
#
# THE PIPELINE, and it is deliberately one direction only:
#
#   oldryzen / i5 / newryzen  --(this script)-->  C:\dev\Corpus\_source
#                             --(buildCorpusLibrary.R)-->  master\ + index\
#                             --(backupCorpusZip.ps1)-->   OneDrive
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
# The tarball is built on the node and copied whole rather than streamed:
# PowerShell 5.1 mangles binary data on a pipeline, and a corrupted archive
# that extracts partially is worse than a slow one that does not.

$ErrorActionPreference = 'Stop'

$corpus = 'C:\dev\Corpus'
$srcDir = Join-Path $corpus '_source'
$stamps = Join-Path $corpus 'index\ingest'
$log    = Join-Path $corpus 'index\ingest.log'
$rscript = 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe'

New-Item -ItemType Directory -Force $srcDir | Out-Null
New-Item -ItemType Directory -Force $stamps | Out-Null
function Say($m) {
  Add-Content $log ((Get-Date -Format 's') + '  ' + $m)
  Write-Host $m
}
Say '===== node ingest ====='

# What each node produces, and where it lands locally. Add a row when a
# node starts a new harvest; nothing else needs to change.
# THERE ARE TWO COMPUTE NODES, not three. "newryzen" is THIS Windows
# machine - the one the corpus lives on - and was listed here in error
# when this script was written. It resolves (to a link-local IPv6 address)
# and answers ping, so the mistake looked like a node that was merely
# down; what gave it away is that it runs no sshd and has no entry in
# ~/.ssh/config. Pulling the archive to itself is meaningless.
$nodes = @(
  @{ Node = 'oldryzen'; Remote = 'work/pmc_corpus';   Local = 'pmc_corpus' },
  @{ Node = 'oldryzen'; Remote = 'journals';          Local = 'oldryzen_journals' },
  @{ Node = 'i5';       Remote = 'work/ctgov_corpus'; Local = 'ctgov' }
)

# Guard the class of mistake rather than just the instance. A node entry
# naming this machine would ssh to itself, and if an sshd were ever
# installed here it would "succeed" - tarring the corpus and extracting it
# back over itself. Refuse by name before anything is copied.
$selfNames = @($env:COMPUTERNAME, [System.Net.Dns]::GetHostName()) |
             ForEach-Object { $_.ToLower() } | Select-Object -Unique
$nodes = @($nodes | Where-Object {
  if ($selfNames -contains $_.Node.ToLower()) {
    Say ("SKIP {0}: that is this machine, not a compute node" -f $_.Node)
    $false
  } else { $true }
})

$changed = $false

foreach ($n in $nodes) {
  $tag   = $n.Node + '-' + ($n.Local)
  $stamp = Join-Path $stamps "$tag.stamp"
  $dest  = Join-Path $srcDir $n.Local

  # Is the node up? A box that is down is normal here - newryzen was
  # refusing connections this morning - and must not fail the whole run.
  $probe = & ssh -o ConnectTimeout=10 -o BatchMode=yes $n.Node 'echo up' 2>&1
  if ($LASTEXITCODE -ne 0) {
    Say ("SKIP {0}: unreachable ({1})" -f $tag, ($probe | Select-Object -First 1))
    continue
  }

  $since = '1970-01-01'
  if (Test-Path $stamp) { $since = (Get-Content $stamp -Raw).Trim() }
  $started = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

  # --newer-mtime on the node, so only new work crosses the wire. The
  # remote directory may not exist yet (a node that has not run its
  # harvest), which is a skip, not an error.
  $remoteCmd = "test -d ~/$($n.Remote) && cd ~/$($n.Remote) && " +
               "tar czf /tmp/ingest_$tag.tgz --newer-mtime='$since' . 2>/dev/null; " +
               "echo EXIT:`$?; ls -l /tmp/ingest_$tag.tgz 2>/dev/null | awk '{print `$5}'"
  $out = & ssh -o BatchMode=yes $n.Node $remoteCmd 2>&1
  # CHECK THE REMOTE EXIT STATUS BEFORE TRUSTING THE ARCHIVE. tar can fail
  # part-way - disk full, a file yanked mid-read - and still leave a
  # readable /tmp/ingest_*.tgz with a plausible size. Reading only the
  # size would extract that truncated archive, then advance the stamp past
  # files it never contained, and those files would never be fetched
  # again: a permanent silent hole in the corpus. The remote command emits
  # EXIT:<status> for exactly this reason.
  $exit = ($out | Select-String -Pattern '^EXIT:(\d+)' |
           Select-Object -Last 1).Matches.Groups[1].Value
  if ($exit -and [int]$exit -ne 0) {
    Say ("FAILED {0}: remote tar exited {1} - stamp NOT advanced, will retry" -f $tag, $exit)
    & ssh -o BatchMode=yes $n.Node "rm -f /tmp/ingest_$tag.tgz" 2>&1 | Out-Null
    continue
  }
  $size = ($out | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1)

  if (-not $size) {
    Say ("SKIP {0}: nothing to fetch or remote path missing" -f $tag)
    continue
  }
  # A tar.gz of an empty selection is about 45 bytes of header. Treat
  # anything that small as "no new files" rather than shipping it.
  if ([int]$size -lt 200) {
    Say ("ok   {0}: no new files since {1}" -f $tag, $since)
    & ssh -o BatchMode=yes $n.Node "rm -f /tmp/ingest_$tag.tgz" 2>&1 | Out-Null
    Set-Content $stamp $started -Encoding ascii
    continue
  }

  $tgz = Join-Path $env:TEMP "ingest_$tag.tgz"
  if (Test-Path $tgz) { Remove-Item $tgz -Force }
  & scp -q ("{0}:/tmp/ingest_{1}.tgz" -f $n.Node, $tag) $tgz 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tgz)) {
    Say ("FAILED {0}: scp did not deliver the archive" -f $tag)
    continue
  }

  New-Item -ItemType Directory -Force $dest | Out-Null
  & tar -xzf $tgz -C $dest 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Say ("FAILED {0}: extract failed - stamp NOT advanced, will retry" -f $tag)
    Remove-Item $tgz -Force
    continue
  }

  $mb = [math]::Round((Get-Item $tgz).Length / 1MB, 1)
  Remove-Item $tgz -Force
  & ssh -o BatchMode=yes $n.Node "rm -f /tmp/ingest_$tag.tgz" 2>&1 | Out-Null
  # Only now, after a clean extract.
  Set-Content $stamp $started -Encoding ascii
  Say ("PULLED {0}: {1} MB into _source\{2}" -f $tag, $mb, $n.Local)
  $changed = $true
}

# --- reindex ------------------------------------------------------------
# Cheap when nothing arrived: the hash cache in index/hashCache.csv means
# unchanged files are not re-read, so a quiet night costs a directory walk
# rather than 24 GB of I/O. Run it regardless, because a local edit (a
# manual download into .NewCarlisle) is also a reason to reindex.
Say 'reindexing'
& $rscript 'C:\dev\IntegrityAnalysis\corpus\buildCorpusLibrary.R' 2>&1 |
  Select-Object -Last 12 | ForEach-Object { Say ('  ' + $_) }

# --- identity, only for what is new -------------------------------------
# fetchCorpusIdentity.R fills only blank rows, so this is self-limiting;
# on a night with no new accessions it makes two positive-control calls
# and stops.
# Run it after EVERY reindex, not only after a node transfer. The reindex
# above also picks up local additions - a PDF hand-downloaded into
# .NewCarlisle, which is Steve's daily handful - and those create blank
# identity rows too. Gating on $changed would leave them unresolved until
# some unrelated node happened to deliver something. The script fills only
# blank rows, so on a genuinely quiet night this costs two positive-control
# calls and stops.
if ($true) {
  Say 'resolving identities for any unresolved accessions'
  & $rscript 'C:\dev\IntegrityAnalysis\corpus\fetchCorpusIdentity.R' 2>&1 |
    Select-Object -Last 12 | ForEach-Object { Say ('  ' + $_) }
}

# --- backup -------------------------------------------------------------
Say 'handing off to the zipped backup'
& powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File 'C:\dev\IntegrityAnalysis\tools\backupCorpusZip.ps1' 2>&1 |
  Select-Object -Last 20 | ForEach-Object { Say ('  ' + $_) }

Say '===== done ====='
