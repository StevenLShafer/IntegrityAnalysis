# test-analysis-draw-budget.R - the app refuses, before the first draw, a
# table whose worst-case simulation exceeds .iaAppDrawBudget(), and says
# why (ISSUES.md issue 166).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) at Steve's     #
# request after the outside security review of 2026-09-26: the second of  #
# two interim guards beside the wall-clock ceiling (issue 165).            #
############################################################################
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(Rfast)
  library(foreach); library(MBESS); library(dqrng)
}))

oneTrialGrid <- function(d) {
  d$TRIAL[1:2] <- 1
  d$ROW[1:2] <- "Age"; d$N[1:2] <- 25
  d$MEAN[1:2] <- c(54.1, 53.8); d$SD[1:2] <- c(9.2, 8.9)
  d$ROUND_MEAN[1:2] <- 1; d$ROUND_OBSERVATION[1:2] <- 1
  d
}

test_that("the app's budget is ten times the API's, and the estimate is the API's own", {
  withr::local_options(IntegrityAnalysis.appDrawBudget = NULL)
  expect_identical(.iaAppDrawBudget(), 10 * .apiMaxDrawBudget)
  withr::local_options(IntegrityAnalysis.appDrawBudget = 1e6)
  expect_identical(.iaAppDrawBudget(), 1e6)
  withr::local_options(IntegrityAnalysis.appDrawBudget = -1)
  expect_identical(.iaAppDrawBudget(), 10 * .apiMaxDrawBudget)
  d <- data.frame(TRIAL = 1, ROW = "Age", N = c(25, 25), MEAN = c(54.1, 53.8), SD = c(9.2, 8.9),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  expect_identical(.apiDrawWork(d), 50 * .apiReplicateCeiling)
})

test_that("a table over the budget is refused before the first draw, with the numbers; under it the analysis runs", {
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d <- oneTrialGrid(reactiveData())
    session$setInputs(dataGrid = d, applyEdits = 1)
    expect_false(is.null(reactiveDataValidated()))
    # a budget below this table's worst case (50 subjects x 100,000 = 5e6);
    # options() directly: a withr local_ or a mocked binding inside
    # testServer's expression has no function frame to release it
    oldOpt <- options(IntegrityAnalysis.appDrawBudget = 1e6)
    session$setInputs(go = 1)
    options(oldOpt)
    log <- shiny::isolate(commentsLog())
    expect_true(grepl("more simulation than this server allows in one analysis", log, fixed = TRUE))
    expect_true(grepl("2 row(s) totalling 50 subjects would need about 5,000,000 simulated values", log, fixed = TRUE))
    expect_true(grepl("above the 1,000,000 this app allows", log, fixed = TRUE))
    expect_false(grepl("Execution time", log, fixed = TRUE))            # nothing was simulated
    expect_null(session$env$OUTPUT)
    expect_false(reactiveDone())
  })
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d <- oneTrialGrid(reactiveData())
    session$setInputs(dataGrid = d, applyEdits = 1)
    session$setInputs(go = 1)                                            # the real budget: runs
    log <- shiny::isolate(commentsLog())
    expect_false(grepl("more simulation than this server allows", log, fixed = TRUE))
    expect_true(any(session$env$OUTPUT$ROW == "Summary", na.rm = TRUE))
    expect_true(reactiveDone())
  })
})
