# Issue 22, tier 2: scanned pages through the deterministic engine on
# tesseract word boxes, with "ocr" provenance driving whole-table cyan
# shading in the app.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-26,
# with the tier-2 wiring in parseBaselineTable.R / heuristics / app_server.
# The OCR-vs-AI validation run (Steve's design: the AI assist validates
# tesseract) lives outside the suite - it needs a key and a real scan;
# its results are recorded in ISSUES.md issue 22.

test_that("the engine parses its own rendered page through OCR", {
  skip_if_not_installed("tesseract")
  skip_on_cran()
  # Certified on the desktop and the Linux nodes, whose tesseract builds
  # are known; the GitHub runner's distribution tesseract reads this page
  # differently (arm N as NA), and exact OCR equality is the engine's
  # property, not this package's - see test-image-uploads.R (2026-09-03).
  skip_on_ci("exact OCR equality is certified on the desktop and the nodes, not the runner's tesseract")
  src <- syntheticPdfMeanSD()
  direct <- parseBaselineTableHeuristics(src, quiet = TRUE)
  viaOcr <- parseBaselineTableHeuristics(src, ocr = TRUE, quiet = TRUE)

  expect_identical(viaOcr$engine, "heuristic-ocr")
  expect_true(all(viaOcr$provenance$ENGINE == "ocr"))
  expect_identical(direct$engine, "heuristic")

  # same table, read from pixels instead of the text layer: on a clean
  # 300-dpi render of a plain synthetic page, tesseract should hand the
  # engine the same words - a mismatch here is worth investigating, not
  # tolerating
  expect_setequal(unique(viaOcr$data$ROW), unique(direct$data$ROW))
  # each ROW appears once per arm, so sort both frames into the same
  # order and compare column-wise (a merge on ROW would go cartesian)
  srt <- function(d) {
    d <- d[, c("ROW", "N", "MEAN", "SD")]
    d[order(d$ROW, d$N, d$MEAN, d$SD), , drop = FALSE]
  }
  expect_equal(srt(viaOcr$data), srt(direct$data), ignore_attr = TRUE)
})

test_that("parseBaselineTable rescues a failed parse via OCR when pages are image-only", {
  skip_if_not_installed("tesseract")
  src <- syntheticPdfMeanSD()
  real <- parseBaselineTableHeuristics(src, ocr = FALSE, quiet = TRUE)
  real$engine <- "heuristic-ocr"

  calls <- new.env(); calls$ocr <- 0L
  testthat::local_mocked_bindings(
    .ppImageOnlyPages = function(...) 1L,
    parseBaselineTableHeuristics = function(..., ocr = FALSE, pages = NULL) {
      if (!isTRUE(ocr)) stop("no usable table in the text layer")
      calls$ocr <- calls$ocr + 1L
      calls$pages <- pages
      real
    })

  out <- parseBaselineTable(src, ai = "never", quiet = TRUE)
  expect_identical(calls$ocr, 1L)
  expect_identical(calls$pages, 1L)      # OCR aimed at the image page only
  expect_identical(out$engine, "heuristic-ocr")
  expect_match(out$flags, "OCR")
  expect_match(out$flags, "verify")
})

test_that("an OCR result with no arm identity is rejected, not surfaced", {
  skip_if_not_installed("tesseract")
  src <- syntheticPdfMeanSD()
  junk <- parseBaselineTableHeuristics(src, ocr = FALSE, quiet = TRUE)
  junk$arms$arm <- NA_character_        # what a degraded scan produces:
  junk$arms$N   <- NA_integer_          # a table with no arm identity
  testthat::local_mocked_bindings(
    .ppImageOnlyPages = function(...) 1L,
    parseBaselineTableHeuristics = function(..., ocr = FALSE, pages = NULL) {
      if (!isTRUE(ocr)) stop("no usable table in the text layer")
      junk
    })
  expect_error(parseBaselineTable(src, ai = "never", quiet = TRUE),
               "no usable table in the text layer")
})

test_that("no image-only pages means no OCR attempt - the error stands", {
  skip_if_not_installed("tesseract")
  src <- syntheticPdfMeanSD()
  testthat::local_mocked_bindings(
    .ppImageOnlyPages = function(...) integer(0),
    parseBaselineTableHeuristics = function(..., ocr = FALSE, pages = NULL)
      stop("no usable table anywhere"))
  expect_error(parseBaselineTable(src, ai = "never", quiet = TRUE),
               "no usable table anywhere")
})

test_that("a real degraded scan fails gracefully in the app, no key present", {
  # Full pipeline against a REAL scanned table page - runs only on
  # machines that hold the medRxiv stress corpus (never committed).
  # This particular scan is too degraded for tesseract (the quality
  # gate rejects an armless read), so the assertion is the graceful
  # path: the upload completes, the failure is reported, nothing
  # crashes. The cyan whole-table path is pinned by the registry logic
  # above plus the renderer's COL "*" expansion; a usable real scan for
  # an end-to-end cyan assertion is an open corpus-harvest want.
  scan <- "C:/Temp/medrxiv_rct/10.1101_19007195.pdf"
  skip_if(!file.exists(scan), "medRxiv corpus not on this machine")
  skip_if_not_installed("tesseract")
  skip_on_cran()
  d <- file.path(tempdir(), paste0("ocr", basename(tempfile(""))))
  dir.create(d)
  f <- file.path(d, "scan.pdf")
  file.copy(scan, f)
  shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "scan.pdf", datapath = f, stringsAsFactors = FALSE))
    log <- commentsLog()
    expect_match(log, "scan.pdf")
    expect_match(log, "No usable baseline table|No file produced")
  })
})
