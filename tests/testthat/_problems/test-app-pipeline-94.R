# Extracted from test-app-pipeline.R:94

# prequel ----------------------------------------------------------------------
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(readxl); library(Rfast)
  library(foreach); library(MBESS); library(dqrng)
  # app_ui() builds its page eagerly and calls these unqualified (they
  # are attached by run_app() in production)
  library(shinydashboard); library(shinyjs); library(shinyWidgets)
  library(bslib); library(rhandsontable); library(htmltools)
}))
stageCopy <- function(src) {
  d <- file.path(tempdir(), paste0("up", basename(tempfile(""))))
  dir.create(d)
  f <- file.path(d, basename(src))
  file.copy(src, f)
  f
}

# test -------------------------------------------------------------------------
pdfPath <- stageCopy(syntheticPdfMeanSD())
shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "meanSD.pdf", datapath = pdfPath, stringsAsFactors = FALSE))
    d <- reactiveData()
    expect_false(is.null(d))
    expect_true(any(grepl("Age", d$ROW)))
    expect_false(is.null(reactiveDataValidated()))
    # edit a mean in the grid, revalidate: the edit must be what analysis
    # sees (the applyEdits test seam accepts a bare data.frame)
    i <- which(!is.na(d$MEAN))[1]
    d$MEAN[i] <- d$MEAN[i] + 1
    session$setInputs(dataGrid = d, applyEdits = 1)
    v <- reactiveDataValidated()
    expect_false(is.null(v))
    expect_true(any(abs(v$MEAN - d$MEAN[i]) < 1e-9, na.rm = TRUE))
    session$setInputs(go = 1)
    expect_true(any(session$env$OUTPUT$ROW == "Summary", na.rm = TRUE))
  })
