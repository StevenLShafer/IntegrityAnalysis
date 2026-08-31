# backupCorpusZip.ps1 - zipped nightly backup of the corpus library to OneDrive.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5, Anthropic),
# 2026-08-31, at Steve Shafer's direction: "yes, I want a true zip backup
# to my OneDrive. It should be a scheduled nightly task, but no reason to
# run if nothing has changed."
#
# This is the companion to backupCorpora.ps1, which copies the raw source
# trees file-by-file. This one archives the LIBRARY - the accession-named
# tree plus the index that explains it - so that a restore reproduces
# C:\dev\Corpus exactly, accession numbers included, without needing this
# machine or any of the original download scripts.
#
# ---------------------------------------------------------------------
# WHY IT IS SHARDED, which is the whole reason a nightly zip is viable.
#
# The library is 24 GB and mostly PDFs, which are already compressed - a
# single archive would be ~22 GB re-uploaded every time one paper was
# added. So it is split into VOLUMES, each with its own signature, and a
# volume is rebuilt only when its own contents change.
#
# The PDF volumes are sharded by ACCESSION RANGE, and that detail is doing
# real work. Accessions are assigned sequentially, so new arrivals always
# take the HIGHEST numbers - which means a night that adds 40 papers
# dirties exactly one shard of ~2 GB, and the other nine are already in
# OneDrive and stay there. Sharding by journal or by source would smear
# new arrivals across every volume and defeat the whole arrangement.
#
# PDF and XML/TXT are compressed differently on purpose: PDFs are stored
# without compression (they are already deflate-compressed internally, so
# a second pass costs minutes of CPU to save under a percent), while XML
# and text compress by roughly 5:1 and are worth the time.
# ---------------------------------------------------------------------

# -Dest and -Only exist so this can be exercised without committing 22 GB
# to OneDrive. A backup script that has only ever been tested by running
# it for real is a backup script nobody has tested.
param(
  [string]$Dest = (Join-Path $env:OneDrive 'IntegrityAnalysisCorpus'),
  [string]$Only = ''
)

$ErrorActionPreference = 'Stop'
# BOTH assemblies. ZipFileExtensions lives in .FileSystem, but the
# ZipArchive/ZipArchiveMode/CompressionLevel types live in the base
# System.IO.Compression - loading only the first gives "Unable to find
# type [System.IO.Compression.ZipArchiveMode]" at the first write.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$corpus = 'C:\dev\Corpus'
$dest   = $Dest
$stamps = Join-Path $dest 'stamps'
$log    = Join-Path $dest 'backup.log'
$shard  = 2000            # accessions per PDF volume

New-Item -ItemType Directory -Force $dest   | Out-Null
New-Item -ItemType Directory -Force $stamps | Out-Null
function Say($m) {
  Add-Content $log ((Get-Date -Format 's') + '  ' + $m)
  Write-Host $m
}
Say "===== corpus zip backup ====="

if (-not (Test-Path (Join-Path $corpus 'index\master.csv'))) {
  Say "ABORT: no index at $corpus - run corpus/buildCorpusLibrary.R first."
  exit 1
}

# A volume's signature is computed from NAME + SIZE + MTIME of its files,
# not from their contents: re-hashing 24 GB nightly to decide whether to
# back up 24 GB would cost as much as the backup. The library's own
# content hashes live in index/master.csv and are archived with it, so a
# restore can still be verified byte-for-byte.
# The signature covers the FULL path, not just the leaf name, so that a
# change in how entries are laid out inside the archive also invalidates
# the volume. Signing the leaf alone would leave a stale zip in place
# after a layout fix, because the file list looks identical.
function Get-Signature($files) {
  if ($files.Count -eq 0) { return 'empty' }
  $sb = New-Object System.Text.StringBuilder
  foreach ($f in ($files | Sort-Object FullName)) {
    [void]$sb.AppendLine($f.FullName + '|' + $f.Length + '|' + $f.LastWriteTimeUtc.Ticks)
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $h = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))
  ($h | ForEach-Object { $_.ToString('x2') }) -join ''
}

# Build the archive under a temp name and move it into place only on
# success. A half-written zip that replaced a good one would be a backup
# that looks present and restores nothing - the worst failure mode a
# backup has.
function Write-Volume($name, $files, $level, $root) {
  if ($Only -ne '' -and $name -notlike $Only) { return $false }
  $sig = Get-Signature $files
  $stampFile = Join-Path $stamps "$name.stamp"
  if (Test-Path $stampFile) {
    if ((Get-Content $stampFile -Raw).Trim() -eq $sig) {
      Say ("skip  {0,-14} unchanged ({1} files)" -f $name, $files.Count)
      return $false
    }
  }
  $zip = Join-Path $dest "$name.zip"
  $tmp = "$zip.partial"
  if (Test-Path $tmp) { Remove-Item $tmp -Force }
  $mode = [System.IO.Compression.CompressionLevel]::Optimal
  if ($level -eq 'store') {
    $mode = [System.IO.Compression.CompressionLevel]::NoCompression
  }
  $fs = [System.IO.File]::Open($tmp, [System.IO.FileMode]::CreateNew)
  try {
    $za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
      # Entry names must keep the path RELATIVE TO THE VOLUME ROOT, not
      # collapse to the bare filename. The registry volumes are gathered
      # recursively, so flattening would drop their directory structure -
      # a restore could not rebuild registry/ctgov, and two files sharing
      # a name in different subdirectories would collide inside the zip,
      # with the second silently overwriting the first on extraction.
      foreach ($f in $files) {
        $rel = $f.FullName
        if ($root -and $f.FullName.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
          $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/')
        } else {
          $rel = $f.Name
        }
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $za, $f.FullName, $rel, $mode)
      }
    } finally { $za.Dispose() }
  } finally { $fs.Dispose() }
  Move-Item $tmp $zip -Force
  Set-Content $stampFile $sig -Encoding ascii
  $mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
  Say ("WROTE {0,-14} {1} files, {2} MB" -f $name, $files.Count, $mb)
  return $true
}

$wrote = 0

# --- index and README: small, and the only part that is useless to lose.
# Always re-zipped, because it is a few hundred KB and it is the map.
$idx = @(Get-ChildItem (Join-Path $corpus 'index') -File)
$idx += @(Get-ChildItem $corpus -File -Filter '*.md')
if (Write-Volume 'index' $idx 'optimal' $corpus) { $wrote++ }

# --- registry: ClinicalTrials.gov baseline data and Carlisle's tables.
$regDir = Join-Path $corpus 'registry'
if (Test-Path $regDir) {
  foreach ($d in (Get-ChildItem $regDir -Directory)) {
    $f = @(Get-ChildItem $d.FullName -File -Recurse)
    if (Write-Volume ("registry-" + $d.Name) $f 'optimal' $d.FullName) { $wrote++ }
  }
}

# --- every non-PDF format, one volume each, discovered rather than listed.
# The first version hardcoded @('xml','txt') and silently omitted the 12
# .docx and 1 .xlsx when they joined the library - a backup that skips a
# format without saying so is exactly the failure this script exists to
# prevent. Enumerate what is actually there instead.
foreach ($d in (Get-ChildItem (Join-Path $corpus 'master') -Directory)) {
  if ($d.Name -eq 'pdf') { continue }      # sharded separately, below
  $f = @(Get-ChildItem $d.FullName -File)
  if ($f.Count -eq 0) { continue }
  if (Write-Volume $d.Name $f 'optimal' $d.FullName) { $wrote++ }
}

# --- pdf: sharded by accession range, stored uncompressed.
$pdfDir = Join-Path $corpus 'master\pdf'
if (Test-Path $pdfDir) {
  $groups = Get-ChildItem $pdfDir -File | Group-Object {
    # IA004512.pdf and IA004512.c2.pdf belong to the same shard.
    $m = [regex]::Match($_.Name, '^IA(\d{6})')
    if ($m.Success) {
      # [math]::Floor returns a Double, and the "d3" format specifier only
      # accepts an integer - without the cast this throws "Format specifier
      # was invalid" on the first file.
      '{0:d3}' -f [int][math]::Floor([int]$m.Groups[1].Value / $shard)
    } else { 'other' }
  }
  foreach ($g in ($groups | Sort-Object Name)) {
    if (Write-Volume ("pdf-" + $g.Name) @($g.Group) 'store' $pdfDir) { $wrote++ }
  }
}

# --- retire volumes whose source no longer exists, but NEVER silently.
# A shard that vanishes because the corpus shrank is a fact Steve should
# see in the log, not something the script quietly tidies away.
$expected = (Get-ChildItem $stamps -Filter '*.stamp' | ForEach-Object { $_.BaseName })
foreach ($z in (Get-ChildItem $dest -Filter '*.zip')) {
  if ($expected -notcontains $z.BaseName) {
    Say ("ORPHAN volume in backup, not written this run: " + $z.Name +
         " - left in place deliberately; delete by hand if intended.")
  }
}

$total = [math]::Round((Get-ChildItem $dest -Filter '*.zip' |
          Measure-Object -Property Length -Sum).Sum / 1GB, 2)
if ($wrote -eq 0) {
  Say "nothing changed - no volume rewritten. Backup holds $total GB."
} else {
  Say "$wrote volume(s) rewritten. Backup holds $total GB."
}
Say "===== done ====="
