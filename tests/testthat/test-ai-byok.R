# Issue 8: the AI assist, bring-your-own-key.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-25,
# with the BYOK wiring in R/app_server.R and R/app_ui.R. No test here
# makes a REAL Anthropic call: the fake-key path exercises everything up
# to and including the graceful failure of the API attempt, which is the
# property that matters - a bad, revoked, or unreachable key must leave
# the user with the full deterministic result, and the key string must
# never surface anywhere.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
}))

stageAi <- function(src) {
  d <- file.path(tempdir(), paste0("byok", basename(tempfile(""))))
  dir.create(d)
  f <- file.path(d, basename(src))
  file.copy(src, f)
  f
}

test_that("a key turns the assist on; failure falls back; the key is never logged", {
  # this synthetic PDF parses with flags (a skipped median line), which
  # is exactly what triggers the AI consult - the fake key then fails
  # authentication (or the network is absent), and the deterministic
  # result must stand
  fakeKey <- "FAKE-KEY-byok-test-000000"
  up <- stageAi(syntheticPdfMeanSD())
  shiny::testServer(app_server, {
    session$setInputs(aiKey = fakeKey)
    session$setInputs(upload = data.frame(
      name = "meanSD.pdf", datapath = up, stringsAsFactors = FALSE))
    d <- reactiveData()
    expect_false(is.null(d))
    expect_true("Age" %in% d$ROW)          # deterministic result intact
    log <- commentsLog()
    expect_match(log, "AI assist is ON")
    expect_match(log, "your key")
    expect_false(grepl(fakeKey, log, fixed = TRUE))   # never logged
  })
})

test_that("without a key the assist stays off - no message, no AI engine", {
  up <- stageAi(syntheticPdfMeanSD())
  shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "meanSD.pdf", datapath = up, stringsAsFactors = FALSE))
    expect_false(grepl("AI assist", commentsLog() %||% ""))
    expect_true("Age" %in% reactiveData()$ROW)
  })
})

test_that("the per-session cap turns the assist off with a message", {
  old <- Sys.getenv("INTEGRITY_AI_SESSION_CAP", unset = NA)
  Sys.setenv(INTEGRITY_AI_SESSION_CAP = "0")
  on.exit(if (is.na(old)) Sys.unsetenv("INTEGRITY_AI_SESSION_CAP")
          else Sys.setenv(INTEGRITY_AI_SESSION_CAP = old), add = TRUE)
  up <- stageAi(syntheticPdfMeanSD())
  shiny::testServer(app_server, {
    session$setInputs(aiKey = "FAKE-KEY-cap-test")
    session$setInputs(upload = data.frame(
      name = "meanSD.pdf", datapath = up, stringsAsFactors = FALSE))
    log <- commentsLog()
    expect_match(log, "cap of 0")
    expect_false(grepl("AI assist is ON", log))
    expect_true("Age" %in% reactiveData()$ROW)   # deterministic still runs
  })
})

test_that("INTEGRITY_AI_ALWAYS with a deployment key enables the assist", {
  # the third-party-deployment pathway (issue 8): policy, not a fork.
  # A fake deployment key on a NO-FLAGS parse never reaches the API at
  # all (nothing to consult), so this runs fast and offline.
  olds <- Sys.getenv(c("INTEGRITY_AI_ALWAYS", "ANTHROPIC_API_KEY"),
                     unset = NA)
  Sys.setenv(INTEGRITY_AI_ALWAYS = "true",
             ANTHROPIC_API_KEY = "FAKE-KEY-deployment")
  on.exit({
    for (v in names(olds))
      if (is.na(olds[[v]])) Sys.unsetenv(v) else
        do.call(Sys.setenv, as.list(stats::setNames(olds[v], v)))
  }, add = TRUE)
  up <- stageAi(syntheticPdfMeanParen())
  shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "meanParen.pdf", datapath = up, stringsAsFactors = FALSE))
    # (the log is HTML-escaped, so the apostrophe arrives as &#39;)
    expect_match(commentsLog(), "this deployment.{1,6}s key")
    expect_false(is.null(reactiveData()))
  })
})

test_that(".ppKeyCheck gives the three honest verdicts", {
  # a fake key is "invalid" when the API is reachable, "unreachable"
  # when it is not - both are acceptable on a runner; what is NEVER
  # acceptable is "valid"
  v <- .ppKeyCheck("FAKE-KEY-keycheck-test")
  expect_true(v %in% c("invalid", "unreachable"))
  expect_false(identical(v, "valid"))
  # with a real key in the local environment, the check must pass
  # (skipped where no key exists, e.g. the GitHub runner)
  skip_if(!nzchar(Sys.getenv("ANTHROPIC_API_KEY")), "no local API key")
  expect_identical(.ppKeyCheck(Sys.getenv("ANTHROPIC_API_KEY")), "valid")
})

test_that("the key field validates on entry, with honest verdicts", {
  shiny::testServer(app_server, {
    # a mid-typing fragment never touches the network
    session$setInputs(aiKey = "sk-ant-abc")
    expect_identical(aiKeyMsg(), "short")
    expect_match(as.character(output$aiKeyStatus$html), "too short")
    # a full-length fake key: invalid when the API answers, unreachable
    # when it does not - never "valid"; the key string never renders
    session$setInputs(aiKey = "FAKE-KEY-validate-me-000000000000000")
    m <- aiKeyMsg()
    expect_true(m %in% c("invalid", "unreachable"))
    html <- as.character(output$aiKeyStatus$html)
    expect_match(html, "Invalid key|Could not reach")
    expect_false(grepl("FAKE-KEY-validate-me", html, fixed = TRUE))
    # erasing the key clears any stale verdict (the programmatic clear
    # after "invalid" consumes one empty event by design)
    session$setInputs(aiKey = "")
    session$setInputs(aiKey = " ")
    session$setInputs(aiKey = "")
    expect_null(aiKeyMsg())
  })
})
