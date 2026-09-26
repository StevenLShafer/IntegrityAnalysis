# test-analysis-wall-clock-ceiling.R - one analysis in the app may run for
# .iaAnalysisSeconds(); at the ceiling it stops between trials, or inside a
# trial between rows, and says what finished (ISSUES.md issue 165).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) at Steve's     #
# request after the outside security review of 2026-09-26: a table built  #
# to make every row escalate would hold a worker for a day.               #
############################################################################
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(Rfast)
  library(foreach); library(MBESS); library(dqrng)
}))

twoTrialGrid <- function(d) {
  d$TRIAL[1:4] <- c(1, 1, 2, 2)
  d$ROW[1:4] <- "Age"; d$N[1:4] <- 25
  d$MEAN[1:4] <- c(54.1, 53.8, 50.2, 49.9); d$SD[1:4] <- c(9.2, 8.9, 10.1, 9.7)
  d$ROUND_MEAN[1:4] <- 1; d$ROUND_OBSERVATION[1:4] <- 1
  d
}

test_that(".iaAnalysisSeconds() reads the option, then the environment, and falls back to ten minutes", {
  withr::local_options(IntegrityAnalysis.analysisSeconds = NULL)
  withr::local_envvar(INTEGRITY_ANALYZE_SECONDS = NA)
  expect_identical(.iaAnalysisSeconds(), 600)
  withr::local_envvar(INTEGRITY_ANALYZE_SECONDS = "120")
  expect_identical(.iaAnalysisSeconds(), 120)
  withr::local_options(IntegrityAnalysis.analysisSeconds = 0.5)
  expect_identical(.iaAnalysisSeconds(), 0.5)
  withr::local_options(IntegrityAnalysis.analysisSeconds = "nonsense")
  expect_identical(.iaAnalysisSeconds(), 600)
  withr::local_options(IntegrityAnalysis.analysisSeconds = -3)
  expect_identical(.iaAnalysisSeconds(), 600)
  withr::local_options(IntegrityAnalysis.analysisSeconds = 0)      # zero is a ceiling: stop at once
  expect_identical(.iaAnalysisSeconds(), 0)
})

test_that("P_Calc stops at a deadline with its own condition class, and runs to the end without one", {
  d <- data.frame(TRIAL = 1, ROW = "Age", N = 25, MEAN = c(54.1, 53.8), SD = c(9.2, 8.9),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  v <- validateData(d)
  expect_false(v$FAIL)
  expect_error(P_Calc(1, v$DATA, v$CategoryNames, 1000, deadline = Sys.time() - 1),
               class = "iaAnalysisTimeout")
  r <- P_Calc(1, v$DATA, v$CategoryNames, 1000, deadline = Sys.time() + 600)
  expect_true(any(r$ROW == "Summary"))
  r0 <- P_Calc(1, v$DATA, v$CategoryNames, 1000)                      # the API's call: no deadline
  expect_true(any(r0$ROW == "Summary"))
})

test_that("at the ceiling the app stops, names what finished and what did not, and runs whole under it", {
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d <- twoTrialGrid(reactiveData())
    session$setInputs(dataGrid = d, applyEdits = 1)
    expect_false(is.null(reactiveDataValidated()))
    # a ceiling of zero: passed when the loop reaches its first check,
    # whatever the clock's tick. (options() directly: a withr local_
    # inside testServer's expression has no function frame to defer to.)
    oldOpt <- options(IntegrityAnalysis.analysisSeconds = 0)
    session$setInputs(go = 1)
    options(oldOpt)
    log <- shiny::isolate(commentsLog())
    # (the log is one HTML string, so the checks are substring counts)
    expect_true(grepl("Analysis stopped at the 0-minute ceiling this server sets", log, fixed = TRUE))
    expect_true(grepl("0 of 2 trial(s) completed", log, fixed = TRUE))
    expect_true(grepl("2 trial(s) were not started: 1, 2", log, fixed = TRUE))
    expect_null(session$env$OUTPUT)
    # the default ceiling: both trials complete (a Summary line per trial;
    # the Summary line carries no TRIAL, the block's first row does), and
    # the log gains no second stop message
    session$setInputs(go = 2)
    out <- session$env$OUTPUT
    expect_identical(sum(out$ROW == "Summary", na.rm = TRUE), 2L)
    expect_identical(sort(unique(na.omit(out$TRIAL))), c("1", "2"))
    expect_identical(lengths(regmatches(shiny::isolate(commentsLog()), gregexpr("Analysis stopped", shiny::isolate(commentsLog())))), 1L)
  })
})

test_that("a trial stopped inside P_Calc at the ceiling has no result, the finished trial keeps its own", {
  # the deadline is met inside the second trial: P_Calc raises the
  # ceiling's condition for trial 2 and runs trial 1 as usual
  real <- P_Calc
  local_mocked_bindings(P_Calc = function(TRIAL, ...) {
    if (identical(as.character(TRIAL), "2")) stop(.iaAnalysisTimeout(TRIAL))
    real(TRIAL, ...)
  })
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d <- twoTrialGrid(reactiveData())
    session$setInputs(dataGrid = d, applyEdits = 1)
    session$setInputs(go = 1)
    log <- shiny::isolate(commentsLog())
    expect_true(grepl("1 of 2 trial(s) completed (their results stand", log, fixed = TRUE))
    expect_true(grepl("Trial 2 was stopped before it finished and has no result", log, fixed = TRUE))
    expect_false(grepl("could not be analyzed", log, fixed = TRUE))
    out <- session$env$OUTPUT
    expect_identical(sum(out$ROW == "Summary", na.rm = TRUE), 1L)
    expect_identical(unique(na.omit(out$TRIAL)), "1")
    expect_true(reactiveDone())                                   # trial 1's results can be downloaded
  })
})
