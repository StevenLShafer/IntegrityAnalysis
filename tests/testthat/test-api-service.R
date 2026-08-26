# Issue 1: the REST API. Boots the real plumber service in a callr
# subprocess and exercises the contract end to end: health open, auth
# refused without a token, parse success, the failure round-trip (the
# 422 payload is valid input to the next call), and analyze through the
# Monte Carlo. No test touches the network beyond 127.0.0.1, and no
# test needs an Anthropic key (BYOK pass-through is pinned at the
# helper level with a fake key never sent anywhere).
#
# PROVENANCE: written 2026-08-26 by Claude Code (model Claude Fable 5)
# with R/apiService.R and inst/api/plumber.R.

skip_if_not_installed("plumber")
skip_if_not_installed("callr")

apiToken <- "TEST-TOKEN-api-service"

startApi <- function() {
  port <- httpuv::randomPort()
  px <- callr::r_bg(function(port, token, pkgDir) {
    Sys.setenv(INTEGRITY_API_TOKENS = token)
    pkgload::load_all(pkgDir, quiet = TRUE)
    # the exported entry point, patched to the dev tree's plumber.R
    # (system.file resolves inst/ under load_all, so this exercises
    # runApiService exactly as a deployment would run it)
    runApiService(port = port, host = "127.0.0.1")
  }, args = list(port = port, token = apiToken,
                 pkgDir = normalizePath(test_path("..", ".."))))
  base <- paste0("http://127.0.0.1:", port)
  for (i in 1:60) {
    ok <- tryCatch({
      httr2::request(paste0(base, "/health")) |>
        httr2::req_timeout(2) |> httr2::req_perform()
      TRUE
    }, error = function(e) FALSE)
    if (ok) break
    if (!px$is_alive())
      stop("API subprocess died: ", paste(px$read_all_error_lines(),
                                          collapse = "\n"))
    Sys.sleep(0.5)
  }
  if (!ok) { px$kill(); stop("API did not come up") }
  list(px = px, base = base)
}

apiReq <- function(base, path, token = apiToken)
  httr2::request(paste0(base, path)) |>
  httr2::req_headers(Authorization = paste("Bearer", token)) |>
  httr2::req_error(is_error = function(resp) FALSE)

test_that("the service honors the whole issue-1 contract", {
  skip_on_cran()
  api <- startApi()
  on.exit(api$px$kill(), add = TRUE)

  # health is open - no token
  h <- httr2::request(paste0(api$base, "/health")) |> httr2::req_perform()
  expect_equal(httr2::resp_status(h), 200)
  expect_true(httr2::resp_body_json(h)$ok)

  # everything else is refused without a bearer token
  r <- httr2::request(paste0(api$base, "/parse")) |>
    httr2::req_method("POST") |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
  expect_equal(httr2::resp_status(r), 401)
  # ...and with a wrong one
  r <- apiReq(api$base, "/parse", token = "WRONG") |>
    httr2::req_method("POST") |> httr2::req_perform()
  expect_equal(httr2::resp_status(r), 401)

  # parse a synthetic PDF: table extracted, template CSV returned,
  # deletion confirmed
  pdf <- syntheticPdfMeanSD()
  r <- apiReq(api$base, "/parse") |>
    httr2::req_body_multipart(file = curl::form_file(pdf)) |>
    httr2::req_perform()
  expect_equal(httr2::resp_status(r), 200)
  b <- httr2::resp_body_json(r)
  expect_true(b$ok)
  expect_true(b$deleted)
  expect_gt(b$rows, 0)
  expect_match(b$templateCsv, "TRIAL")
  expect_match(b$templateCsv, "Age")

  # the failure round-trip: garbage in -> 422 with a template payload
  # that IS valid input for the next call
  bad <- file.path(tempdir(), "not-a-table.pdf")
  grDevices::pdf(bad); graphics::plot.new()
  graphics::text(0.5, 0.5, "There is no table in this document at all.")
  grDevices::dev.off()
  r <- apiReq(api$base, "/parse") |>
    httr2::req_body_multipart(file = curl::form_file(bad)) |>
    httr2::req_perform()
  expect_equal(httr2::resp_status(r), 422)
  b <- httr2::resp_body_json(r)
  expect_false(b$ok)
  expect_true(b$deleted)
  expect_match(b$templateCsv, "TRIAL")   # header row: next call's input

  # analyze a valid template spreadsheet end to end - real Monte Carlo
  ex <- system.file("extdata", "Example.xlsx",
                    package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  r <- apiReq(api$base, "/analyze") |>
    httr2::req_body_multipart(file = curl::form_file(ex)) |>
    httr2::req_timeout(600) |>
    httr2::req_perform()
  expect_equal(httr2::resp_status(r), 200)
  b <- httr2::resp_body_json(r)
  expect_true(b$ok)
  expect_true(b$deleted)
  expect_gt(b$trials, 0)
  expect_match(b$resultsCsv, "Summary")
  expect_true(is.numeric(b$overallP) || is.character(b$overallP))
})

test_that("the auth helper is strict about tokens", {
  old <- Sys.getenv("INTEGRITY_API_TOKENS", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("INTEGRITY_API_TOKENS")
          else Sys.setenv(INTEGRITY_API_TOKENS = old), add = TRUE)
  Sys.setenv(INTEGRITY_API_TOKENS = "alpha, beta")
  expect_true(.apiAuthorized("Bearer alpha"))
  expect_true(.apiAuthorized("Bearer beta"))
  expect_true(.apiAuthorized("bearer alpha"))    # scheme case-insensitive
  expect_false(.apiAuthorized("Bearer gamma"))
  # a bare token (no Bearer scheme) strips to itself and matches -
  # accepted deliberately, one less integration footgun
  expect_true(.apiAuthorized("alpha"))
  expect_false(.apiAuthorized(NULL))
  expect_false(.apiAuthorized(""))
  # no tokens configured -> NOTHING authorizes (fail closed)
  Sys.setenv(INTEGRITY_API_TOKENS = "")
  expect_false(.apiAuthorized("Bearer alpha"))
})

test_that("hashed registry entries authorize without storing plaintext", {
  # the issuance design (2026-08-26): the private registry and the
  # service env carry sha256:<hex> entries; a token exists in plaintext
  # only on the operator's screen at issuance
  old <- Sys.getenv("INTEGRITY_API_TOKENS", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("INTEGRITY_API_TOKENS")
          else Sys.setenv(INTEGRITY_API_TOKENS = old), add = TRUE)
  token <- "ia_test_token_never_stored_anywhere"
  h <- digest::digest(token, algo = "sha256", serialize = FALSE)
  Sys.setenv(INTEGRITY_API_TOKENS = paste0("sha256:", h))
  expect_true(.apiAuthorized(paste("Bearer", token)))
  expect_false(.apiAuthorized("Bearer ia_some_other_token"))
  # the hash itself is NOT a usable credential
  expect_false(.apiAuthorized(paste("Bearer", h)))
  expect_false(.apiAuthorized(paste0("Bearer sha256:", h)))
  # mixed plaintext + hashed lists work (local testing convenience)
  Sys.setenv(INTEGRITY_API_TOKENS = paste0("devtoken,sha256:", h))
  expect_true(.apiAuthorized("Bearer devtoken"))
  expect_true(.apiAuthorized(paste("Bearer", token)))
})

test_that("the BYOK key is scrubbed from parse failure text", {
  fakeKey <- "FAKE-KEY-api-scrub-000000000000000000"
  pdf <- file.path(tempdir(), "scrub-test.pdf")
  grDevices::pdf(pdf); graphics::plot.new()
  graphics::text(0.5, 0.5, "No table here either.")
  grDevices::dev.off()
  r <- .apiReadUpload(pdf, "scrub-test.pdf", apiKey = fakeKey)
  expect_false(isTRUE(r$ok))
  expect_false(grepl(fakeKey, paste(r$reasons, collapse = " "),
                     fixed = TRUE))
})
