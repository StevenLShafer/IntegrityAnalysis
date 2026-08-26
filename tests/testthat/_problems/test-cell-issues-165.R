# Extracted from test-cell-issues.R:165

# prequel ----------------------------------------------------------------------
suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
}))
contFrame <- function(...) data.frame(
  TRIAL = "T", ..., ROUND_MEAN = 1, ROUND_OBSERVATION = 1,
  stringsAsFactors = FALSE)
vd <- function(d) shiny::isolate(validateData(d))

# test -------------------------------------------------------------------------
pdfPath <- syntheticPdfMeanSD()
shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "meanSD.pdf", datapath = pdfPath, stringsAsFactors = FALSE))
    d <- reactiveData()
    # the skipped median [range] line is now a grid row: its label in
    # ROW, no data anywhere
    i <- which(grepl("Duration", d$ROW))
    expect_length(i, 1)
    expect_true(all(is.na(d[i, intersect(c("N", "MEAN", "SD"),
                                         names(d))])))
    # registered for painting, with the parser's reason preserved
    sk <- parseSkips()
    expect_false(is.null(sk))
    expect_true(any(grepl("Duration", sk$ROW)))
    expect_match(sk$reason[grepl("Duration", sk$ROW)][1], "median",
                 ignore.case = TRUE)
    # soft warning: required cells yellow, but validation passes and the
    # Analyze button path stays open
    expect_true(any(rIssues()$code == "missing"))
    # the widget carries the red ROW cell for the skipped line
    expect_match(output$dataGrid, "unreadable")
  })
