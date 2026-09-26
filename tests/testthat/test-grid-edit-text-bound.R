# test-grid-edit-text-bound.R - the edited grid meets the text bound an
# uploaded sheet meets (.iaTableTextRefusal: a cell over .ppMaxCellChars,
# or more than .iaMaxTableTextBytes of text, is refused before validation).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) after an       #
# outside security review of the same date: Apply Edits handed the grid   #
# to validation without the preflight the upload route runs.             #
############################################################################
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(Rfast)
  library(foreach); library(MBESS); library(dqrng)
}))

test_that("a grid cell over the cell limit is refused by Apply Edits, and one at the limit is not", {
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d <- reactiveData()
    d$ROW[1:2] <- "Age"; d$N[1:2] <- 25
    d$MEAN[1:2] <- c(54.1, 53.8); d$SD[1:2] <- c(9.2, 8.9)
    d$ROUND_MEAN[1:2] <- 1; d$ROUND_OBSERVATION[1:2] <- 1
    # one character over the limit: refused before validation, the table
    # of record untouched
    over <- d
    over$ROW[1:2] <- strrep("a", .ppMaxCellChars + 1L)
    session$setInputs(dataGrid = over, applyEdits = 1)
    expect_null(reactiveDataValidated())
    log <- shiny::isolate(commentsLog())
    expect_true(any(grepl("was not accepted", log, fixed = TRUE)))
    expect_true(any(grepl(paste0("limit is ", .ppMaxCellChars), log, fixed = TRUE)))
    # at the limit: the preflight passes and the table validates
    at <- d
    at$ROW[1:2] <- strrep("a", .ppMaxCellChars)
    session$setInputs(dataGrid = at, applyEdits = 2)
    expect_false(is.null(reactiveDataValidated()))
    expect_false(any(grepl("was not accepted", shiny::isolate(commentsLog()), fixed = TRUE)))
  })
})

test_that("a grid whose text exceeds the table bound is refused by Apply Edits", {
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d <- reactiveData()
    # cells each within the cell limit, together past the table's text bound
    nRows <- ceiling(.iaMaxTableTextBytes / .ppMaxCellChars) + 1L
    big <- d[rep(1L, nRows), , drop = FALSE]
    big$ROW <- strrep("b", .ppMaxCellChars)
    big$N <- 25
    session$setInputs(dataGrid = big, applyEdits = 1)
    expect_null(reactiveDataValidated())
    expect_true(any(grepl("MB of text", shiny::isolate(commentsLog()), fixed = TRUE)))
  })
})
