#!/usr/bin/env bash
# tatrProvision.sh - stand up the TATR run-along environment on a compute node.
#
# Written 2026-09-01 by Claude Code (model Claude Opus 5, Anthropic) at
# Steve Shafer's direction. Companion to tools/linuxProvision.sh; like that
# script it names no host and takes no root.
#
# WHY THIS IS NOT "pip install -r requirements.txt".
#
# 1. THE NODES HAVE NO USABLE PYTHON. Ubuntu 26.04 ships Python 3.14, which
#    no PyTorch release supports, and the system python has no pip module.
#    uv installs a managed 3.12 into $HOME without root, which is the only
#    route available here - sudo needs a password these boxes cannot supply
#    to an unattended job.
#
# 2. torch AND torchvision MUST BE INSTALLED TOGETHER FROM THE CPU INDEX.
#    Installing torch from the CPU index and letting torchvision resolve
#    from PyPI yields a pair that imports cleanly and then dies at first
#    inference with "operator torchvision::nms does not exist". That is the
#    first thing that went wrong here, and it fails late rather than at
#    install time, which is exactly the shape of failure worth scripting
#    around.
#
# 3. THE WEIGHTS ARE PINNED BY REVISION AND FETCHED ONCE. Every later run
#    loads with local_files_only=True, so inference touches no network and
#    cannot silently acquire different weights. The revisions live in
#    python/tatr/tatrTables.py and are echoed here only for the fetch.
#
# Usage:  ./tatrProvision.sh            # provision and verify
#         ./tatrProvision.sh --verify   # verify an existing install only
set -euo pipefail

REPO="${INTEGRITY_REPO:-$HOME/IntegrityAnalysis}"
VENV="${TATR_VENV:-$HOME/tatrenv}"
PY="$VENV/bin/python"
REQ="$REPO/python/tatr/requirements.txt"
CPU_INDEX="https://download.pytorch.org/whl/cpu"

DET_MODEL="microsoft/table-transformer-detection"
DET_REV="2357cbe2b5a5d1c03e54f32764f06058933b65ab"
STR_MODEL="microsoft/table-transformer-structure-recognition-v1.1-all"
STR_REV="7587a7ef111d9dcbf8ac695f1376ab7014340a0c"

say() { echo "$(date -Is)  $*"; }

verify() {
  say "verifying"
  "$PY" - <<'EOF'
import torch, torchvision, transformers, timm, pypdfium2, pdfplumber
print("  torch       ", torch.__version__)
print("  torchvision ", torchvision.__version__)
print("  transformers", transformers.__version__)
print("  timm        ", timm.__version__)
print("  threads     ", torch.get_num_threads())
assert transformers.__version__.split(".")[0] == "4", \
    "transformers 5.x rejects the Table Transformer config; pin below 5"
# The nms check is the one that matters: a mismatched torch/torchvision pair
# imports fine and only fails when an operator is actually dispatched.
import torch
_ = torchvision.ops.nms(torch.tensor([[0., 0., 1., 1.]]), torch.tensor([0.9]), 0.5)
print("  torchvision::nms dispatches OK")
EOF
  "$PY" - <<EOF
from transformers import AutoImageProcessor, TableTransformerForObjectDetection
for name, rev in [("$DET_MODEL", "$DET_REV"), ("$STR_MODEL", "$STR_REV")]:
    AutoImageProcessor.from_pretrained(name, revision=rev, local_files_only=True)
    TableTransformerForObjectDetection.from_pretrained(
        name, revision=rev, use_safetensors=True, local_files_only=True)
    print("  cached offline:", name.split("/")[-1], rev[:12])
EOF
  say "verified"
}

if [ "${1:-}" = "--verify" ]; then verify; exit 0; fi

[ -f "$REQ" ] || { echo "no $REQ - is $REPO the repository?" >&2; exit 1; }

# A PINNED, CHECKSUM-VERIFIED ARTEFACT - not curl | sh.
#
# Piping a remote script straight into a shell executes whatever that
# endpoint serves, as the provisioning user, with no record of what ran. For
# a repository whose threat model is "the adversary is the author of a
# manuscript under investigation" and whose dependency files are watched by
# a nightly security screen, that is the wrong default even for a
# convenience tool. (CodeRabbit, PR #137.)
#
# The version is pinned so provisioning is reproducible, and the published
# SHA-256 is checked before anything is unpacked or run. Bump UV_VERSION
# deliberately, the same way renv.lock is bumped.
UV_VERSION="${UV_VERSION:-0.12.8}"
UV_TARGET="x86_64-unknown-linux-gnu"
say "installing uv $UV_VERSION into ~/.local/bin (no root, checksum verified)"
if ! "$HOME/.local/bin/uv" --version >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  base="https://github.com/astral-sh/uv/releases/download/$UV_VERSION"
  tarball="uv-$UV_TARGET.tar.gz"
  curl -fsSL -o "$tmp/$tarball"        "$base/$tarball"
  curl -fsSL -o "$tmp/$tarball.sha256" "$base/$tarball.sha256"
  ( cd "$tmp" && sha256sum -c "$tarball.sha256" ) || {
    echo "uv checksum verification FAILED - refusing to install" >&2
    rm -rf "$tmp"; exit 1; }
  mkdir -p "$HOME/.local/bin"
  tar xzf "$tmp/$tarball" -C "$tmp"
  install -m 0755 "$tmp/uv-$UV_TARGET/uv"  "$HOME/.local/bin/uv"
  install -m 0755 "$tmp/uv-$UV_TARGET/uvx" "$HOME/.local/bin/uvx" 2>/dev/null || true
  rm -rf "$tmp"
  say "uv installed and verified against its published SHA-256"
fi
export PATH="$HOME/.local/bin:$PATH"
say "uv $(uv --version)"

say "installing a managed Python 3.12 (the system 3.14 has no PyTorch build)"
uv python install 3.12
uv venv --python 3.12 "$VENV"

say "installing torch + torchvision TOGETHER from the CPU index"
grep -E '^(torch|torchvision)==' "$REQ" | xargs \
  uv pip install --python "$PY" --index-url "$CPU_INDEX"

say "installing the remaining pinned packages"
grep -vE '^(#|$|torch==|torchvision==)' "$REQ" | xargs \
  uv pip install --python "$PY"

say "fetching the pinned model revisions once"
"$PY" - <<EOF
from transformers import AutoImageProcessor, TableTransformerForObjectDetection
for name, rev in [("$DET_MODEL", "$DET_REV"), ("$STR_MODEL", "$STR_REV")]:
    AutoImageProcessor.from_pretrained(name, revision=rev)
    TableTransformerForObjectDetection.from_pretrained(
        name, revision=rev, use_safetensors=True)
    print("  fetched", name, rev[:12])
EOF

verify
say "provisioned: $VENV"
