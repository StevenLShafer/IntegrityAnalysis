# test-security.R - pins the security properties from the 2026-08-20
# review (AGENTS.md "Security"). tools/securityCheck.R guards these
# statically in the workflows; these tests guard the BEHAVIOR.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-08-20.

test_that(".escapeHtml neutralizes markup in log messages", {
  # The comments log renders through HTML(); a file named like an XSS
  # payload must come out inert.
  hostile <- '<img src=x onerror=alert(1)>.pdf'
  out <- .escapeHtml(hostile)
  expect_false(grepl("<", out, fixed = TRUE))
  expect_false(grepl(">", out, fixed = TRUE))
  expect_identical(.escapeHtml("a & b"), "a &amp; b")
  expect_identical(.escapeHtml('say "hi"'), "say &quot;hi&quot;")
  # ampersand escapes FIRST, or the other entities double-escape
  expect_identical(.escapeHtml("<"), "&lt;")
})

test_that("outputComments escapes what it logs", {
  # Drive the real path: a mock session whose registered logger is a
  # genuine reactiveVal (is.reactive() gates the branch).
  session <- shiny::MockShinySession$new()
  rv <- shiny::reactiveVal("")
  session$userData$commentsLog <- rv
  shiny::withReactiveDomain(session, {
    outputComments("<script>alert(1)</script>", echo = FALSE)
  })
  got <- shiny::isolate(rv())
  expect_true(grepl("&lt;script&gt;", got, fixed = TRUE))
  expect_false(grepl("<script>", got, fixed = TRUE))
})

test_that("the static tripwire passes on the committed tree", {
  skip_on_cran()
  root <- normalizePath(test_path("..", ".."), winslash = "/")
  skip_if_not(file.exists(file.path(root, "tools", "securityCheck.R")))
  # RUN IT FROM THE PACKAGE ROOT. This used to invoke
  # "tools/securityCheck.R" as a relative path while testthat had the
  # working directory set to tests/testthat, where no such file exists,
  # so Rscript exited non-zero and the test failed locally. In CI it did
  # not fail - R CMD check's layout has no tools/ either, but there the
  # skip_if_not above fires first. The net effect was a test that failed
  # on every developer machine and asserted NOTHING on the one machine
  # that gates merges. Found 2026-08-27 while adding the compute-product
  # assertion; the same vacuous-assertion pattern as the journal-bound
  # test that passed because validateData rejected its fixture first.
  res <- suppressWarnings(withr::with_dir(root, system2(
    file.path(R.home("bin"), "Rscript"),
    c("tools/securityCheck.R"),
    stdout = TRUE, stderr = TRUE)))
  status <- attr(res, "status")
  expect_true(is.null(status) || status == 0,
              info = paste(res, collapse = "\n"))
  # and it must actually have RUN, not silently produced nothing
  expect_match(paste(res, collapse = "\n"), "Security check passed")
})
