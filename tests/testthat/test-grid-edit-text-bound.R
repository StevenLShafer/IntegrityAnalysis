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

test_that("an upload whose combination with the grid exceeds the table bound is refused, and the grid stays", {
  # the table on the grid and the uploaded sheet each hold half the bound
  # and a little more; each passes alone, together they do not
  nRows <- ceiling(.iaMaxTableTextBytes / 2 / .ppMaxCellChars) + 50L
  label <- strrep("c", .ppMaxCellChars)
  half <- data.frame(TRIAL = 1, ROW = rep(label, nRows), N = 25, MEAN = 54.1, SD = 9.2,
                     ROUND_MEAN = 1, ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  csv <- file.path(tempdir(), "half-the-bound.csv")   # under tempdir(): the purge on exit is tempdir-guarded
  utils::write.csv(half, csv, row.names = FALSE)
  shiny::testServer(app_server, {
    session$setInputs(dataGrid = half)
    session$setInputs(upload = data.frame(name = "half-the-bound.csv", datapath = csv,
                                          stringsAsFactors = FALSE))
    log <- shiny::isolate(commentsLog())
    expect_true(any(grepl("combined table was not accepted", log, fixed = TRUE)))
    expect_true(any(grepl("MB of text", log, fixed = TRUE)))
    # the session's table is not the refused combination, and the grid is
    # what it was
    expect_true(is.null(session$env$DATA) || nrow(session$env$DATA) <= nRows)
    expect_equal(nrow(currentGrid()), nRows)   # ceiling() made nRows a double
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
