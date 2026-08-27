# Build identity (ISSUES.md issue 28).
#
# PROVENANCE: written 2026-08-27 by Claude Code (model Claude Opus 5)
# with R/buildInfo.R, after Steve asked whether anything checks that
# shinyapps is running our code.
#
# The property that makes this worth having is NOT that it usually finds
# a commit - it is that it NEVER INVENTS ONE. A build identity that
# guesses is worse than none: the whole use is comparing it against
# origin/main, and a confident wrong answer turns a detector into a
# rubber stamp.

test_that("buildCommit reports NA rather than guessing", {
  # An empty directory has no .git and no DESCRIPTION to read from.
  empty <- file.path(tempdir(), "no-git-here")
  dir.create(empty, showWarnings = FALSE)
  expect_true(is.na(.buildCommitFromGit(empty)))

  # a .git with an unreadable HEAD is still not an excuse to invent one
  fake <- file.path(tempdir(), "broken-git")
  dir.create(file.path(fake, ".git"), recursive = TRUE, showWarnings = FALSE)
  expect_true(is.na(.buildCommitFromGit(fake)))
})

test_that(".buildCommitFromGit reads each way a HEAD can be stored", {
  # detached HEAD: the hash sits in HEAD itself
  det <- file.path(tempdir(), "git-detached")
  dir.create(file.path(det, ".git"), recursive = TRUE, showWarnings = FALSE)
  sha <- paste(rep("a1b2c3d4", 5), collapse = "")   # 40 hex chars
  writeLines(sha, file.path(det, ".git", "HEAD"))
  expect_identical(.buildCommitFromGit(det), sha)

  # attached HEAD: a ref pointing at a loose ref file
  att <- file.path(tempdir(), "git-attached")
  dir.create(file.path(att, ".git", "refs", "heads"), recursive = TRUE,
             showWarnings = FALSE)
  writeLines("ref: refs/heads/main", file.path(att, ".git", "HEAD"))
  sha2 <- paste(rep("0f1e2d3c", 5), collapse = "")
  writeLines(sha2, file.path(att, ".git", "refs", "heads", "main"))
  expect_identical(.buildCommitFromGit(att), sha2)

  # packed refs: the loose file is gone, the hash lives in packed-refs
  pk <- file.path(tempdir(), "git-packed")
  dir.create(file.path(pk, ".git"), recursive = TRUE, showWarnings = FALSE)
  writeLines("ref: refs/heads/main", file.path(pk, ".git", "HEAD"))
  sha3 <- paste(rep("9988aabb", 5), collapse = "")
  writeLines(c("# pack-refs with: peeled fully-peeled sorted",
               paste(sha3, "refs/heads/main")),
             file.path(pk, ".git", "packed-refs"))
  expect_identical(.buildCommitFromGit(pk), sha3)
})

test_that("buildCommit honours an explicit build SHA", {
  # the container path: no remotes, no .git, an environment variable
  old <- Sys.getenv("INTEGRITY_BUILD_SHA", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("INTEGRITY_BUILD_SHA")
          else Sys.setenv(INTEGRITY_BUILD_SHA = old), add = TRUE)
  d <- suppressWarnings(utils::packageDescription("IntegrityAnalysis"))
  skip_if(is.list(d) && !is.null(d$RemoteSha) && nzchar(d$RemoteSha),
          "installed from GitHub: RemoteSha wins, by design")
  sha <- paste(rep("beefcafe", 5), collapse = "")
  Sys.setenv(INTEGRITY_BUILD_SHA = sha)
  expect_identical(buildCommit(), sha)
  expect_identical(buildCommit(short = TRUE), "beefcafe")
})

test_that("buildLabel says 'unknown' instead of fabricating", {
  lab <- buildLabel()
  expect_type(lab, "character")
  expect_length(lab, 1)
  expect_match(lab, "build")
  # it is either a real short hash or the honest word - never blank,
  # never a stray "NA" leaking into the user interface
  expect_match(lab, "build (unknown|[0-9a-f]{8})\\)$")
  expect_false(grepl("build NA", lab, fixed = TRUE))
})

test_that("R/ still contains no system2 outside the reviewed launcher", {
  # buildInfo.R's first draft shelled out to `git rev-parse`, which the
  # tripwire bans in R/ - it reads .git/HEAD instead. This pins that the
  # replacement stayed replaced, because the shell version is the
  # obvious thing for the next person to reach for.
  f <- test_path("..", "..", "R", "buildInfo.R")
  skip_if_not(file.exists(f))
  code <- sub("#.*$", "", readLines(f, warn = FALSE))
  expect_false(any(grepl("system2\\s*\\(", code)))
  expect_false(any(grepl("\\bsystem\\s*\\(", code)))
})

test_that("the build commit reaches the SERVED html, not just the object", {
  # THE LOAD-BEARING TEST. tools/checkDeployedBuild.ps1 fetches the page
  # over plain HTTP and reads the meta tag; if the tag only exists in
  # the UI object, the whole check is decorative.
  #
  # It must be tested by SERVING, not by as.character(app_ui()): Shiny
  # hoists tags$head content during renderDocument, so the object form
  # does NOT contain the tag and the first version of this check
  # reported a false negative. An as.character() assertion here would
  # have "failed safe" into deleting a mechanism that works.
  skip_on_cran()
  skip_if_not_installed("callr")
  skip_if_not_installed("httpuv")

  port <- httpuv::randomPort()
  px <- callr::r_bg(function(port, dir) {
    pkgload::load_all(dir, quiet = TRUE)
    suppressWarnings(suppressPackageStartupMessages({
      library(shiny); library(shinydashboard); library(shinyjs)
      library(shinyWidgets); library(bslib); library(rhandsontable)
      library(openxlsx); library(readxl); library(Rfast); library(foreach)
      library(MBESS); library(dqrng)
    }))
    shiny::addResourcePath("www",
      system.file("www", package = "IntegrityAnalysis"))
    shiny::runApp(shiny::shinyApp(IntegrityAnalysis:::app_ui(),
                                  IntegrityAnalysis:::app_server),
                  port = port, host = "127.0.0.1", launch.browser = FALSE)
  }, args = list(port = port,
                 dir = normalizePath(test_path("..", ".."))))
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  url <- paste0("http://127.0.0.1:", port, "/")
  html <- NULL
  for (i in 1:60) {
    html <- tryCatch(paste(readLines(url, warn = FALSE), collapse = "\n"),
                     error = function(e) NULL)
    if (!is.null(html) || !px$is_alive()) break
    Sys.sleep(1)
  }
  skip_if(is.null(html), "app did not come up")

  # exactly the regex the checker uses, so the two cannot drift apart
  rx <- '<meta[^>]*name="integrity-build"[^>]*content="([^"]*)"'
  m <- regmatches(html, regexec(rx, html))[[1]]
  expect_length(m, 2)
  # a definite value, never a dropped attribute: htmltools omits an
  # attribute whose value is NA, which is exactly what the first version
  # of app_ui did and what this test caught
  expect_true(nzchar(m[2]))
  expected <- buildCommit()
  expect_identical(m[2], if (is.na(expected)) "unknown" else expected)
  # and the human-readable label is on the page too
  expect_match(html, "build (unknown|[0-9a-f]{8})")
})
