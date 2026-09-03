# Deployment shim (stanpumpR pattern): the entire app lives in the installed
# IntegrityAnalysis package; this file is all that rsconnect uploads - plus,
# since 2026-09-03, `build-sha.txt`.
#
# THE BUILD COMMIT (issue 28). buildCommit() reads the installed package's
# DESCRIPTION for the commit the installer recorded, but the shinyapps.io
# builder installs the package itself and records NEITHER field
# (RemoteSha, GithubSHA1): five deploys after issue 28, and one more after
# PR #149 taught buildCommit() the second field, the live app still said
# "unknown". So the deploy job now writes the commit it deployed into
# `build-sha.txt` beside this file, and the shim hands it to the package
# through the explicit route buildCommit() has always honoured. Read only
# if it looks like a commit; the package falls back to "unknown" otherwise,
# never to a guess.
if (file.exists("build-sha.txt")) {
  sha <- trimws(readLines("build-sha.txt", n = 1L, warn = FALSE))
  if (length(sha) == 1L && grepl("^[0-9a-f]{7,40}$", sha))
    Sys.setenv(INTEGRITY_BUILD_SHA = sha)
}
IntegrityAnalysis::run_app()
