# buildInfo.R - which commit is this, actually?
#
# PROVENANCE: written 2026-08-27 by Claude Code (model Claude Opus 5),
# for ISSUES.md issue 28, at Steve Shafer's request after he asked "do
# we have checks so that shinyapps.io itself doesn't become malware?"
#
# THE GAP THIS CLOSES. Every existing control protects the PIPELINE:
# deploys can only install the package from GitHub, securityCheck.R
# gates deploy-production.yaml, workflows never use pull_request_target
# so forked PRs get no secrets, and the tripwire bans code-execution
# primitives in R/. None of them says anything about the ARTIFACT that
# ends up running. Nobody - Steve included - could look at the live app
# and tell whether it was built from main or from something a holder of
# the rsconnect token pushed by hand.
#
# WHAT THIS IS NOT. It is not attestation. Anyone able to deploy
# arbitrary code can also report an arbitrary commit, so a determined
# attacker who knows the check exists defeats it by echoing the right
# hex. Saying otherwise would be the sort of overclaim this repository
# spent 2026-08-27 removing from its own comments.
#
# What it DOES catch is the far more likely set: a deploy from the
# wrong branch, a stale deploy nobody noticed, a rollback that never
# rolled forward, a hurried fix applied straight to the host, and any
# tampering by someone who did not think to fake it. That is worth
# having - it converts "we deploy carefully" into "we would notice" -
# provided the claim stays honest about its own ceiling.
#
# WHERE THE VALUE COMES FROM. AGENTS.md's deploy procedure installs the
# package with remotes::install_github(), and remotes records the
# resolved commit in the installed DESCRIPTION as RemoteSha. So the
# deployed app already KNOWS its commit; nothing needed to be injected
# at build time, and there is no new build step to forget.

#' The commit this build came from
#'
#' Reports the git commit of the running package, for comparing what is
#' deployed against what is in the repository (ISSUES.md issue 28).
#'
#' The value is read, in order, from:
#' \enumerate{
#'   \item \code{RemoteSha} in the installed DESCRIPTION - written by
#'     \code{remotes::install_github()}, which is how deploys install
#'     this package (AGENTS.md, "Running, testing, deploying");
#'   \item \code{INTEGRITY_BUILD_SHA} in the environment, for container
#'     builds that install by other means;
#'   \item \code{git rev-parse HEAD} when running from a source tree,
#'     which is the development case.
#' }
#'
#' @param short return the first 8 characters rather than the full hash.
#' @return The commit as a string, or \code{NA_character_} when it
#'   genuinely cannot be determined - never a guess, because a wrong
#'   commit reported confidently is worse than an honest "unknown".
#' @export
buildCommit <- function(short = FALSE) {
  sha <- NA_character_

  # 1. how a deployed build knows: remotes wrote it at install time
  d <- suppressWarnings(utils::packageDescription("IntegrityAnalysis"))
  if (is.list(d) && !is.null(d$RemoteSha) && nzchar(d$RemoteSha))
    sha <- d$RemoteSha

  # 2. an explicit override, for container images built without remotes
  if (is.na(sha)) {
    e <- Sys.getenv("INTEGRITY_BUILD_SHA", "")
    if (nzchar(e)) sha <- e
  }

  # 3. development: running from the source tree. system2() is used
  #    here and NOWHERE else in R/ - the tripwire allows it only in the
  #    reviewed subprocess launcher, so this call is deliberately NOT
  #    added to that allowlist; see .buildCommitFromGit below, which
  #    keeps it out of this file entirely.
  if (is.na(sha)) sha <- .buildCommitFromGit()

  if (is.na(sha) || !nzchar(sha)) return(NA_character_)
  if (short) substr(sha, 1, 8) else sha
}

# The development fallback, isolated so its one risky call is easy to
# see. Reads .git/HEAD directly rather than shelling out to git: no
# subprocess, nothing to quote, and it works when git is not installed.
# (It also keeps R/ free of system2 outside the reviewed launcher,
# which the tripwire enforces - the first draft of this file used
# system2("git", ...) and would have failed the check honestly.)
.buildCommitFromGit <- function(root = ".") {
  headFile <- file.path(root, ".git", "HEAD")
  if (!file.exists(headFile)) return(NA_character_)
  head <- tryCatch(trimws(readLines(headFile, warn = FALSE)[1]),
                   error = function(e) NA_character_)
  if (is.na(head)) return(NA_character_)
  # detached HEAD: the file holds the hash itself
  if (grepl("^[0-9a-f]{40}$", head)) return(head)
  # otherwise "ref: refs/heads/<branch>"
  ref <- sub("^ref:\\s*", "", head)
  refFile <- file.path(root, ".git", ref)
  if (file.exists(refFile))
    return(tryCatch(trimws(readLines(refFile, warn = FALSE)[1]),
                    error = function(e) NA_character_))
  # packed refs, when the loose ref has been packed away
  packed <- file.path(root, ".git", "packed-refs")
  if (file.exists(packed)) {
    lines <- tryCatch(readLines(packed, warn = FALSE),
                      error = function(e) character(0))
    hit <- grep(paste0("\\s", ref, "$"), lines, value = TRUE)
    if (length(hit)) return(sub("\\s.*$", "", hit[1]))
  }
  NA_character_
}

#' A human-readable build identity
#'
#' Version plus short commit, for display. Says "unknown commit" rather
#' than inventing one.
#'
#' @return A one-line string such as \code{"0.2.0 (build 4f1a2b3c)"}.
#' @export
buildLabel <- function() {
  d <- suppressWarnings(utils::packageDescription("IntegrityAnalysis"))
  ver <- if (is.list(d) && !is.null(d$Version)) d$Version else "?"
  sha <- buildCommit(short = TRUE)
  if (is.na(sha)) paste0(ver, " (build unknown)")
  else paste0(ver, " (build ", sha, ")")
}
