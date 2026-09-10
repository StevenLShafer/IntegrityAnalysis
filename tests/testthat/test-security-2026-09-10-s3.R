# Adjudication of the private security audit of 2026-09-10, S3 (LOW): the
# default echo of every comment to the console kept the uploaded file's
# name and the trial's p in the host's captured stdout after the session
# that purged everything else had closed.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/outputComments.R (the default echo is
# interactive(), so a deployed app or service - never interactive -
# writes nothing). Reproduced through the path the report names: the
# actual output sink of a non-interactive process. Checked to FAIL on
# d6496e0 (the marker line appeared).
suppressWarnings(suppressPackageStartupMessages({ library(shiny) }))

test_that("a non-interactive process writes no comment to its console by default (security audit 2026-09-10, S3)", {
  skip_if(interactive(), "the default is interactive(); this run is interactive")
  out <- withr::with_options(list(ECHO_OUTPUT_COMMENTS = NULL), {
    capture.output(shiny::isolate(outputComments("Read Synthetic-private-marker.csv: 2 row(s).")))
  })
  expect_false(any(grepl("Synthetic-private-marker", out, fixed = TRUE)))
  expect_identical(formals(outputComments)$echo,
                   quote(getOption("ECHO_OUTPUT_COMMENTS", interactive())))
})

test_that("the option still turns the echo on, for a developer's console", {
  out <- withr::with_options(list(ECHO_OUTPUT_COMMENTS = TRUE), {
    capture.output(shiny::isolate(outputComments("Read Synthetic-echo-marker.csv: 2 row(s).")))
  })
  expect_true(any(grepl("Synthetic-echo-marker", out, fixed = TRUE)))
})
