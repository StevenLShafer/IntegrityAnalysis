#!/usr/bin/env bash
############################################################################
# linuxProvision.sh - turn a fresh Ubuntu 24.04 server into an            #
# IntegrityAnalysis compute node.                                          #
#                                                                          #
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request, while his Ubuntu box was still installing. LOCAL       #
# INFRASTRUCTURE ONLY - nothing here ships in the app or the package.      #
#                                                                          #
# NOT GUESSED. Every step below is transcribed from                        #
# .github/workflows/R-CMD-check.yaml, which is the only environment        #
# recipe in this project that is continuously PROVEN to work: it runs on   #
# ubuntu-latest (24.04) on every PR. Two of its steps exist because        #
# someone already lost time to the failure they prevent, and both would    #
# bite again here:                                                         #
#                                                                          #
#   1. SYSTEM LIBRARIES. setup-renv does NOT install SystemRequirements.   #
#      RSPM binaries then install cleanly and fail to LOAD - the reported  #
#      symptom was pdftools "required" errors, whose actual cause was a    #
#      missing libpoppler-cpp. Installed explicitly below.                 #
#                                                                          #
#   2. Rfast MUST BE REBUILT FROM SOURCE. The prebuilt Linux binary        #
#      fails to load with an undefined TBB symbol against the restored     #
#      RcppParallel. This is the single most confusing failure a new       #
#      Linux node will hit, because everything installs "successfully"     #
#      and then the engine will not start.                                 #
#                                                                          #
# WHY R COMES FROM POSIT'S .deb AND NOT apt: `apt install r-base` gives    #
# whatever R the distribution currently ships, which drifts. renv.lock     #
# pins R 4.5.3, and a version mismatch would make every number this box    #
# produces incomparable to the ones from Steve's desktop. The .deb below   #
# is the same artifact r-lib/actions/setup-r uses in CI, installed side-   #
# by-side under /opt/R/4.5.3.                                              #
#                                                                          #
# WHY NO GITHUB CREDENTIALS ARE NEEDED: StevenLShafer/IntegrityAnalysis    #
# is a PUBLIC repository, so the clone below is anonymous HTTPS. That is   #
# deliberate - it means this machine holds no credential that could write  #
# to the repo. The corpus PDFs are a different matter: they are            #
# copyrighted, gitignored (see .gitignore), and live outside the repo on   #
# Steve's desktop. They are pushed over SSH separately, never cloned.      #
#                                                                          #
# Usage (from the Windows desktop, once the box is reachable):             #
#   scp tools/linuxProvision.sh steve@ubantu:/tmp/                         #
#   ssh steve@ubantu 'bash /tmp/linuxProvision.sh'                         #
#                                                                          #
# Safe to re-run: every step is idempotent.                                #
############################################################################

set -euo pipefail

# REFUSE TO RUN AS ROOT.
#
# This script runs as the ORDINARY user and calls sudo only for the
# steps that genuinely need it (apt, the R .deb, the site profile).
# Three things must land in the INVOKING user's home: the repository
# clone, the renv library, and the package cache. Running the whole
# script under `sudo bash` puts all three under /root, where the user's
# own account cannot reach them.
#
# The failure is SILENT, which is what makes it worth a guard: every
# step still reports success, R still installs correctly system-wide,
# and nothing looks wrong until you try to use the machine and find no
# repository in your home directory. That happened while provisioning
# the second compute node on 2026-08-30 and cost a full re-run.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run this with sudo." >&2
  echo >&2
  echo "  Run it as your normal user:   bash $0" >&2
  echo >&2
  echo "It calls sudo itself where root is needed. Running the whole" >&2
  echo "script as root clones the repository and builds the renv" >&2
  echo "library under /root, where your account cannot use them." >&2
  exit 1
fi

R_VERSION="4.5.3"
REPO_URL="https://github.com/StevenLShafer/IntegrityAnalysis.git"
REPO_DIR="${HOME}/IntegrityAnalysis"

# RELEASE DETECTION, not a hardcoded codename. The first draft of this
# script assumed 24.04 "noble" because that is what CI runs; the actual
# machine turned out to be 26.04 "resolute", which would have produced
# two silent 404s. Both Posit endpoints are keyed by release, so derive
# them rather than guess. Verified 2026-08-29: r-4.5.3 debs and RSPM
# binaries both exist for resolute.
. /etc/os-release
CODENAME="${VERSION_CODENAME}"              # e.g. resolute
DEBSLUG="ubuntu-${VERSION_ID/./}"           # e.g. ubuntu-2604
# Posit's binary package mirror. Without this, renv::restore() compiles
# ~125 packages from source and takes an hour instead of a few minutes.
RSPM="https://packagemanager.posit.co/cran/__linux__/${CODENAME}/latest"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

say "1/8  Base tools"
sudo apt-get update -qq
# avahi-daemon is what makes this machine answer to "ubantu.local" from
# Windows without a static IP or a DHCP reservation - see the DHCP note
# in tools/README-linux.md.
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl git rsync build-essential gfortran \
  pandoc avahi-daemon libnss-mdns

say "2/8  System libraries (verbatim from R-CMD-check.yaml)"
# libtiff5-dev is transitional on 24.04; fall back to the real package
# rather than letting `set -e` kill the run over a package rename.
sudo apt-get install -y --no-install-recommends \
  libpoppler-cpp-dev libcurl4-openssl-dev libssl-dev \
  libxml2-dev libfontconfig1-dev libfreetype6-dev \
  libharfbuzz-dev libfribidi-dev libpng-dev libjpeg-dev \
  libcairo2-dev \
  || { echo "retrying with libtiff-dev"; }
sudo apt-get install -y --no-install-recommends libtiff5-dev \
  || sudo apt-get install -y --no-install-recommends libtiff-dev

say "3/8  R ${R_VERSION} (Posit build - matches renv.lock exactly)"
if [ ! -x "/opt/R/${R_VERSION}/bin/R" ]; then
  deb="/tmp/r-${R_VERSION}_1_amd64.deb"
  curl -fsSL -o "$deb" \
    "https://cdn.posit.co/r/${DEBSLUG}/pkgs/r-${R_VERSION}_1_amd64.deb"
  sudo apt-get install -y "$deb"
  rm -f "$deb"
fi
sudo ln -sf "/opt/R/${R_VERSION}/bin/R"       /usr/local/bin/R
sudo ln -sf "/opt/R/${R_VERSION}/bin/Rscript" /usr/local/bin/Rscript

say "4/8  Point R at the binary mirror"
# Written to the site profile so every R session - including the ones
# parallel workers start - inherits it.
sudo tee "/opt/R/${R_VERSION}/lib/R/etc/Rprofile.site" >/dev/null <<RPROFILE
# Binary packages for ${CODENAME}. Written by linuxProvision.sh.
options(repos = c(CRAN = "${RSPM}"))
options(HTTPUserAgent = sprintf(
  "R/%s R (%s)", getRversion(),
  paste(getRversion(), R.version\$platform, R.version\$arch, R.version\$os)))
RPROFILE

say "5/8  Clone (public repo - no credentials on this machine)"
if [ -d "${REPO_DIR}/.git" ]; then
  git -C "${REPO_DIR}" fetch --quiet origin
  git -C "${REPO_DIR}" checkout --quiet main
  git -C "${REPO_DIR}" pull --quiet --ff-only origin main
else
  git clone --quiet "${REPO_URL}" "${REPO_DIR}"
fi
cd "${REPO_DIR}"

say "6/8  renv::restore() - the pinned runtime graph"
Rscript -e 'if (!requireNamespace("renv", quietly = TRUE))
              install.packages("renv")' \
        -e 'renv::restore(prompt = FALSE)'

say "7/8  Rebuild Rfast from source (TBB ABI - see the header)"
# renv caches the result, so this compiles once per lockfile, not once
# per provisioning run. It is slow (several minutes) and unavoidable.
Rscript -e 'options(pkgType = "source");
            renv::install("Rfast@2.1.5.2", rebuild = TRUE, prompt = FALSE)'

say "8/8  Verify - the engine must LOAD, not merely install"
# Installing and loading are different questions here; see the Rfast note.
Rscript -e '
  pkgs <- c("Rfast", "pdftools", "shiny", "MBESS", "dqrng", "openxlsx")
  bad  <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(bad)) stop("failed to LOAD: ", paste(bad, collapse = ", "))
  cat("R           :", format(getRversion()), "\n")
  cat("physical cores:", parallel::detectCores(logical = FALSE), "\n")
  cat("logical cores :", parallel::detectCores(logical = TRUE), "\n")
  cat("workers (n-2) :", max(1L, parallel::detectCores(logical=FALSE) - 2L), "\n")
  cat("all engine packages load OK\n")'

Rscript tools/securityCheck.R

say "Provisioning complete"
echo "Repository : ${REPO_DIR}"
echo "Hostname   : $(hostname) / $(hostname).local"
echo
echo "Next: install the package into a snapshot library, then benchmark:"
echo "  cd ${REPO_DIR}"
echo "  R CMD INSTALL --library=\$HOME/ialib ."
echo "  Rscript tools/machineBench.R"
