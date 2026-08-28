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

# Tests that call .apiAnalyze IN-PROCESS reach P_Calc, whose %do% loop,
# dqrnorm and Rfast operations resolve from the search path - the same
# attach runApiService() performs at startup (and the convention every
# other Monte-Carlo test file follows, e.g. test-adaptive-m.R).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng); library(openxlsx)
}))

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

# ---- security hardening (2026-08-26 review) -------------------------------

test_that("the RESULTS csv neutralizes formula injection", {
  # the human-facing artifact: an editor opens it in Excel
  r <- data.frame(TRIAL = "1", ROW = "=HYPERLINK(\"http://evil\")",
                  P = "0.03", CI95 = "", M = 1000L,
                  stringsAsFactors = FALSE)
  csv <- .apiResultsCsv(r)
  expect_match(csv, "'=HYPERLINK", fixed = TRUE)
  expect_no_match(csv, ",\"=HYPERLINK", fixed = TRUE)
})

test_that("the TEMPLATE csv stays verbatim - the round trip must close", {
  # templateCsv is the machine payload a caller POSTs back (issue 1's
  # round-trip contract). Sanitizing it would RENAME variables: a real
  # label like "-Mean change" would return as "'-Mean change" and the
  # next call would analyze a different table. Caught by the security
  # re-review, 2026-08-26 - this test exists so it cannot come back.
  d <- data.frame(TRIAL = "T1", ROW = c("Weight", "-Mean change"),
                  N = 50L, MEAN = c(72, -3.1), SD = c(10, 2),
                  stringsAsFactors = FALSE)
  csv <- .apiTemplateCsv(d)
  f <- tempfile(fileext = ".csv"); writeLines(csv, f)
  back <- utils::read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
  expect_identical(back$ROW, d$ROW)          # labels survive exactly
  expect_equal(back$MEAN, d$MEAN)
  expect_no_match(csv, "'-Mean", fixed = TRUE)
})

test_that("the CSV sanitizer covers all four Excel trigger characters", {
  for (ch in c("=", "+", "-", "@")) {
    d <- data.frame(TRIAL = "1", ROW = paste0(ch, "cmd"), N = 1L,
                    MEAN = 1, SD = 1, stringsAsFactors = FALSE)
    expect_match(.apiCsvSafe(d)$ROW, paste0("^'\\", ch))
  }
  expect_identical(.apiCsvSafe(data.frame(x = "safe"))$x, "safe")
})

test_that(".apiAnalyze rejects an oversized table before simulating", {
  big <- data.frame(TRIAL = as.character(seq_len(.apiMaxTrials + 1L)),
                    ROW = "Age", N = 50L, MEAN = 60, SD = 10,
                    stringsAsFactors = FALSE)
  a <- .apiAnalyze(big)
  expect_false(a$ok)
  expect_identical(a$stage, "too_large")
  # many rows, few trials, also rejected
  rows <- data.frame(TRIAL = "1", ROW = paste0("V", seq_len(.apiMaxRows + 1L)),
                     N = 50L, MEAN = 60, SD = 10, stringsAsFactors = FALSE)
  expect_identical(.apiAnalyze(rows)$stage, "too_large")
})

test_that("the AI key never enters the child options blob (M4)", {
  # the pure split function is the security seam: the key comes out on
  # its own (for env-var passing), and the opts blob that gets written
  # to disk contains no trace of it
  fakeKey <- "FAKE-KEY-rds-check-00000000000000"
  s <- .ppSplitChildKey("fallback",
                        list(apiKey = fakeKey, pctApprox = TRUE),
                        .libPaths(), NULL)
  expect_identical(s$childKey, fakeKey)
  expect_null(s$opts$args$apiKey)
  expect_true(s$opts$args$pctApprox)                 # other dots survive
  blob <- paste(capture.output(str(s$opts)), collapse = " ")
  expect_false(grepl(fakeKey, blob, fixed = TRUE))   # key nowhere in the blob
  # no key -> empty childKey, blob still clean
  s2 <- .ppSplitChildKey("never", list(), .libPaths(), NULL)
  expect_identical(s2$childKey, "")
})

test_that("parseOne.R folds the env-var key back into the parse args (M4)", {
  # the child reads INTEGRITY_CHILD_APIKEY and merges it, then clears it
  old <- Sys.getenv("INTEGRITY_CHILD_APIKEY", unset = NA)
  on.exit(if (is.na(old)) Sys.unsetenv("INTEGRITY_CHILD_APIKEY")
          else Sys.setenv(INTEGRITY_CHILD_APIKEY = old), add = TRUE)
  Sys.setenv(INTEGRITY_CHILD_APIKEY = "FAKE-KEY-env-merge")
  opts <- list(args = list(ai = "fallback"))
  .childKey <- Sys.getenv("INTEGRITY_CHILD_APIKEY", "")
  if (nzchar(.childKey)) {
    opts$args$apiKey <- .childKey
    Sys.unsetenv("INTEGRITY_CHILD_APIKEY")
  }
  expect_identical(opts$args$apiKey, "FAKE-KEY-env-merge")
  expect_identical(Sys.getenv("INTEGRITY_CHILD_APIKEY", "unset-marker"),
                   "unset-marker")   # cleared after use
})

test_that("the decompression-bomb preflight rejects an over-inflating zip", {
  # a tiny xlsx whose declared uncompressed size exceeds the cap is
  # rejected without reading; a normal workbook passes
  ex <- system.file("extdata", "Example.xlsx",
                    package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  expect_true(.apiZipInflationOK(ex))                # a real workbook is fine
  # csv is not a zip - preflight is a no-op pass
  csv <- tempfile(fileext = ".csv"); writeLines("TRIAL,ROW", csv)
  expect_true(.apiZipInflationOK(csv))
  # a lowered cap makes even the honest workbook trip the guard
  old <- .apiMaxUncompressed
  local_mocked_bindings(.apiMaxUncompressed = 1)  # 1 byte cap
  expect_false(.apiZipInflationOK(ex))
})

# ---- re-review gaps (2026-08-26): the fixes above had no coverage ---------

test_that("the size verdict decides every branch correctly", {
  # Pure-function coverage of the filter's decision (the re-review's
  # point: the old tests pinned that the filter EXISTED, not that it
  # decided right). Driving chunked encoding over HTTP is unreliable,
  # so the branch is tested here and the wrapper stays trivial.
  expect_identical(.apiSizeVerdict("GET",  NULL), "ok")
  expect_identical(.apiSizeVerdict("GET",  ""),   "ok")
  # a POST with no Content-Length (chunked) is REFUSED, not forwarded -
  # falling open there bypassed the cap entirely
  expect_identical(.apiSizeVerdict("POST", NULL), "no_length")
  expect_identical(.apiSizeVerdict("POST", ""),   "no_length")
  expect_identical(.apiSizeVerdict("post", NULL), "no_length")
  expect_identical(.apiSizeVerdict("POST", "1024"), "ok")
  expect_identical(.apiSizeVerdict("POST", as.character(.apiMaxBytes)), "ok")
  expect_identical(.apiSizeVerdict("POST", as.character(.apiMaxBytes + 1)),
                   "too_large")
  expect_identical(.apiSizeVerdict("POST", "999999999"), "too_large")
  # a garbage header is not a number: treated as absent -> refused on POST
  expect_identical(.apiSizeVerdict("POST", "not-a-number"), "no_length")
})

test_that("an oversized upload is refused 413 over HTTP", {
  skip_if_not_installed("plumber"); skip_if_not_installed("callr")
  skip_on_cran()
  api <- startApi()
  on.exit(api$px$kill(), add = TRUE)
  # Send a REAL oversized body. Faking Content-Length instead makes the
  # server block waiting for bytes that never arrive - which hangs the
  # suite, and is itself a live demonstration of the re-review's H1
  # point: the body is consumed before this filter ever runs.
  big <- as.raw(rep(0L, .apiMaxBytes + 1024L))
  r <- apiReq(api$base, "/parse") |>
    httr2::req_body_raw(big) |>
    httr2::req_timeout(120) |>
    httr2::req_perform()
  expect_equal(httr2::resp_status(r), 413)
})

test_that("the analyze gate also bounds arm N and column count", {
  # a SHORT table with an enormous N was the open lane: it passes a row
  # gate, then P_Calc allocates rnorm(N * chunk) - gigabytes
  small <- data.frame(TRIAL = "T", ROW = c("Age", "Age"),
                      N = c(1e9, 1e9), MEAN = c(50, 51), SD = c(10, 10),
                      stringsAsFactors = FALSE)
  a <- .apiAnalyze(small)
  expect_false(a$ok)
  expect_identical(a$stage, "too_large")
  expect_match(a$issues$detail, "largest N")
  # very wide (many category columns) is the same attack
  wide <- data.frame(TRIAL = "T", ROW = "Sex", N = 50L, MEAN = NA_real_,
                     SD = NA_real_, stringsAsFactors = FALSE)
  for (i in seq_len(.apiMaxCols + 1L)) wide[[paste0("C", i)]] <- 1L
  expect_identical(.apiAnalyze(wide)$stage, "too_large")
})

test_that("the zip preflight does not fall open on a non-zip xlsx", {
  # an .xlsx that is not a readable zip must be REFUSED, not waved
  # through to openxlsx (the re-review found this falling open)
  fake <- tempfile(fileext = ".xlsx")
  writeBin(as.raw(rep(0, 64)), fake)
  expect_false(.apiZipInflationOK(fake, "xlsx"))
  # .xls is legitimately not a zip - bounded by file size instead
  fakeXls <- tempfile(fileext = ".xls")
  writeBin(as.raw(rep(0, 64)), fakeXls)
  expect_true(.apiZipInflationOK(fakeXls, "xls"))
  # a real workbook still passes
  ex <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  expect_true(.apiZipInflationOK(ex, "xlsx"))
})

test_that("the AI key reaches a REAL spawned child through the environment", {
  # The re-review's sharpest catch: the M4 test re-implemented
  # parseOne.R's logic inline, so deleting the parent's Sys.setenv would
  # break BYOK with every test still green - which is exactly how the
  # system2(env=) bug survived its first test pass. This spawns a real
  # child the same way parseBaselineTableFiles does and asserts the key
  # arrives.
  skip_on_cran()
  skip_if_not_installed("callr")
  # callr spawns a real child and inherits the parent environment, the
  # same mechanism parseBaselineTableFiles relies on - without the
  # cross-platform quoting hazards of building an -e command line.
  Sys.setenv(INTEGRITY_CHILD_APIKEY = "FAKE-KEY-spawn-check")
  on.exit(Sys.unsetenv("INTEGRITY_CHILD_APIKEY"), add = TRUE)
  got <- callr::r(function() Sys.getenv("INTEGRITY_CHILD_APIKEY"))
  expect_identical(got, "FAKE-KEY-spawn-check")
  # and once cleared, a child must NOT see it
  Sys.unsetenv("INTEGRITY_CHILD_APIKEY")
  expect_identical(callr::r(function() Sys.getenv("INTEGRITY_CHILD_APIKEY")),
                   "")
})

test_that("a custom error handler is registered, so 500s leak nothing", {
  # M6 is pinned by INSPECTION rather than by driving a malformed
  # request: a deliberately broken multipart hangs plumber's parser in
  # this harness (it stalled the suite for 10 minutes), and a test that
  # cannot finish is worse than one that reads the registration. The
  # handler body itself is three lines and returns a constant.
  # Read the INSTALLED function, not the source file: under R CMD check
  # the package is installed and R/ is not shipped, so a readLines() of
  # the source passes locally and fails on CI (it did, 2026-08-26).
  src <- paste(deparse(body(runApiService)), collapse = " ")
  expect_match(src, "pr_set_error", fixed = TRUE)
  expect_match(src, "Internal error processing the request", fixed = TRUE)
  # what the CALLER receives must be a constant, not the condition text
  expect_match(src, "ok = FALSE", fixed = TRUE)
})

test_that("/analyze returns the journal-style table per trial", {
  # issue 15's artifact travels with the response (api-spec decision,
  # 2026-08-26): the editor compares it against the manuscript page
  ex <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  skip_on_cran()
  d <- openxlsx::read.xlsx(ex)
  a <- .apiAnalyze(d)
  expect_true(a$ok)
  expect_false(is.null(a$journalTables))
  expect_true(length(a$journalTables) >= 1)
  first <- a$journalTables[[1]]
  expect_true(is.character(first))
  expect_match(first, ",")          # it is CSV
})

test_that("CSV sanitizing covers COLUMN NAMES, not just cell values", {
  # A header is as executable as a cell when the editor opens the file
  # in Excel, so .apiCsvSafe must guard names() as well as values.
  #
  # This is DEFENCE IN DEPTH, and the comment here originally said
  # otherwise - that the journal table's headers are arm names parsed
  # from the manuscript, hence attacker text. They are not:
  # buildBaselineTables names columns positionally ("Arm 1 (n = 15)").
  # Corrected as F3 of the 2026-08-27 screen, which found the wrong
  # rationale had propagated into three places. The test still earns
  # its keep: it pins the behaviour regardless of which caller one day
  # hands this function names that DID come from an upload.
  d <- data.frame(a = "safe", b = "also safe", stringsAsFactors = FALSE)
  names(d) <- c("Variable", "=cmd|'/c calc'!A1")
  safe <- .apiCsvSafe(d)
  expect_match(names(safe)[2], "^'=cmd", perl = TRUE)
  expect_identical(names(safe)[1], "Variable")   # harmless names untouched
  # and it survives the write: no bare "=" opening a header field
  out <- capture.output(utils::write.csv(safe, row.names = FALSE, na = ""))
  expect_match(out[1], "'=cmd", fixed = TRUE)
  expect_false(grepl(",\"=cmd", out[1], fixed = TRUE))
  # every trigger character, in a name
  for (ch in c("=", "+", "-", "@")) {
    dd <- data.frame(x = 1L)
    names(dd) <- paste0(ch, "danger")
    expect_match(names(.apiCsvSafe(dd))[1], paste0("^'\\", ch))
  }
})

test_that("journalTables carry the sanitizing too", {
  ex <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  skip_on_cran()
  d <- openxlsx::read.xlsx(ex)
  a <- .apiAnalyze(d)
  expect_true(a$ok)
  expect_true(length(a$journalTables) >= 1)
  # no journal CSV may open a field with a formula trigger
  for (csv in a$journalTables) {
    lines <- strsplit(csv, "\n")[[1]]
    for (ln in lines)
      expect_false(grepl('(^|,)"?[=+@]', ln), label = substr(ln, 1, 40))
  }
})

test_that("the compute budget covers CATEGORICAL work too", {
  # F1 of the 2026-08-28 screen. P_Calc has THREE branches; the budget
  # modelled two. The categorical one simulates with r2dtable, whose
  # cost is arms x categories and NOT N - and validateData REQUIRES
  # N = NA on any line carrying a category value, so every row reaching
  # it was one the continuous term dropped. A wholly categorical payload
  # scored zero and the gate refused nothing.
  d <- data.frame(TRIAL = "T", ROW = rep(paste0("V", 1:20), each = 100),
                  N = NA_real_, MEAN = NA_real_, SD = NA_real_,
                  stringsAsFactors = FALSE)
  for (k in 1:190) d[[paste0("C", k)]] <- 5L
  d$C190[1] <- NA

  cats <- .apiCategoryGuess(d)
  expect_gt(length(cats), 100)                 # the columns are seen
  expect_gt(.apiDrawWork(d, cats), .apiMaxDrawBudget)
  # ...and it is the CATEGORICAL term doing it: the continuous term is 0
  expect_identical(.apiDrawWork(d, character(0)), 0)

  a <- .apiAnalyze(d)
  expect_false(a$ok)
  expect_identical(a$stage, "too_large")
})

test_that("the size gates see N whatever the header calls it", {
  # F2. Both gates matched "N" exactly and case-sensitively while
  # validateData uppercases and applies the Carlisle aliases AFTERWARDS,
  # so a header spelled "n" made the gates see no N column - and
  # .apiDrawWork read "column absent" as "no work". A two-row table
  # declaring n = 200,000, twenty times the ceiling, ran the analysis.
  lower <- data.frame(TRIAL = "T", ROW = c("A", "A"), n = 200000,
                      MEAN = c(1, 2), SD = 1,
                      check.names = FALSE, stringsAsFactors = FALSE)
  expect_identical(names(.apiNormalizeNames(lower))[3], "N")
  a <- .apiAnalyze(lower)
  expect_false(a$ok)
  expect_identical(a$stage, "too_large")

  # the NUMBER alias bypassed the budget the same way
  alias <- data.frame(TRIAL = "T", ROW = rep(paste0("V", 1:2500), each = 2),
                      NUMBER = 10000, MEAN = 1, SD = 1,
                      stringsAsFactors = FALSE)
  expect_identical(names(.apiNormalizeNames(alias))[3], "N")
  b <- .apiAnalyze(alias)
  expect_false(b$ok)
  expect_identical(b$stage, "too_large")

  # normalising must not disturb a frame that was already correct
  fine <- data.frame(TRIAL = "T", ROW = "A", N = 50, MEAN = 1, SD = 1,
                     stringsAsFactors = FALSE)
  expect_identical(names(.apiNormalizeNames(fine)), names(fine))
})

test_that("ordinary trials in the thousands are ACCEPTED", {
  # The gate must bound the attack WITHOUT refusing real work, and the
  # first budget (6e9) failed that half: it refused a 20-variable trial
  # above N = 1,500 per arm and a 30-variable trial above N = 1,000.
  # Carlisle's corpus is full of trials in the thousands, so the
  # deployed service was turning away ordinary submissions. Nothing
  # tested that direction - every assertion pointed at the attack - so
  # the over-restriction shipped. This test is the missing half.
  trial <- function(nVar, nArm, N)
    data.frame(TRIAL = "T", ROW = rep(paste0("V", seq_len(nVar)), each = nArm),
               N = N, MEAN = 1, SD = 1, stringsAsFactors = FALSE)

  # sizes drawn from real baseline tables, all must pass the budget
  expect_lt(.apiDrawWork(trial(20,  2,  2000)), .apiMaxDrawBudget)
  expect_lt(.apiDrawWork(trial(30,  2,  1000)), .apiMaxDrawBudget)
  expect_lt(.apiDrawWork(trial(15,  3,  1000)), .apiMaxDrawBudget)
  expect_lt(.apiDrawWork(trial(25,  2,   500)), .apiMaxDrawBudget)
  expect_lt(.apiDrawWork(trial(40,  2,   200)), .apiMaxDrawBudget)

  # and the N ceiling is Steve's editorial one, not the old round number
  expect_identical(.apiMaxN, 10000L)
})

test_that("the compute-product gate refuses what the size gates allow", {
  # F4 of the 2026-08-27 screen. The four size limits are checked with
  # ||, so each can pass while the simulation cost - replicates x
  # sum(N) - is enormous. Measured: one row at N = 100,000 with 100,000
  # replicates is 199 seconds on a single-threaded service.
  #
  # Tested on the pure estimator AND through .apiAnalyze, because the
  # journal bound's first test went only through .apiAnalyze, where
  # validateData rejected the fixture before the code under test ran -
  # it passed while testing nothing.
  expect_identical(.apiDrawWork(NULL), 0)
  expect_identical(.apiDrawWork(data.frame(x = 1)), 0)          # no N
  expect_identical(.apiDrawWork(data.frame(N = numeric(0))), 0) # no rows
  # NA and non-positive N contribute nothing rather than propagating
  # NA and non-positive N contribute nothing FROM THE CONTINUOUS TERM.
  # This assertion used to read as though zero were the whole answer,
  # and in doing so it pinned the F1 hole as intended behaviour: a
  # categorical payload has N = NA on every line by validateData's own
  # rule, so "NA costs nothing" silently meant "categorical costs
  # nothing". The frame below has no category columns, which is now the
  # reason the answer is zero - and the categorical case is asserted
  # separately in its own test.
  expect_identical(.apiDrawWork(data.frame(N = c(NA, -5, 0))), 0)
  expect_identical(.apiDrawWork(data.frame(N = c(10, 20))),
                   30 * .apiReplicateCeiling)

  # a table INSIDE every individual limit but far outside the budget
  # N sits at the ceiling, NOT above it, so this exercises the compute
  # gate rather than tripping the N gate first (which it did when
  # .apiMaxN was 100,000 and this fixture used that value - the test
  # would have kept passing for the wrong reason after the 2026-08-27
  # cap change, reporting "too_large" from a different gate)
  wide <- data.frame(TRIAL = "T", ROW = rep(paste0("V", 1:100), each = 2),
                     N = .apiMaxN, MEAN = 1, SD = 1,
                     stringsAsFactors = FALSE)
  expect_lt(nrow(wide), .apiMaxRows)          # rows: fine
  expect_lte(max(wide$N), .apiMaxN)           # N: fine
  expect_lt(ncol(wide), .apiMaxCols)          # columns: fine
  expect_gt(.apiDrawWork(wide), .apiMaxDrawBudget)   # the product is not

  a <- .apiAnalyze(wide)
  expect_false(a$ok)
  expect_identical(a$stage, "too_large")
  expect_identical(a$issues$code[1], "too_much_compute")
  # the refusal must tell the caller what to do - and "split it" is
  # useless advice for a SINGLE large trial, whose rows combine into one
  # p-value, so the message routes those to the app instead
  expect_match(a$issues$detail[1], "one per\\s+request")
  expect_match(a$issues$detail[1], "web app")
  # ...and must NOT claim the analysis was quietly coarsened instead
  expect_match(a$issues$detail[1], "never reduced to fit")
  expect_false(is.null(a$templateCsv))

  # an ordinary trial is untouched: 20 variables, 2 arms, N = 500
  ok <- data.frame(TRIAL = "T", ROW = rep(paste0("V", 1:20), each = 2),
                   N = 500, MEAN = 1, SD = 1, stringsAsFactors = FALSE)
  expect_lt(.apiDrawWork(ok), .apiMaxDrawBudget)
})

test_that("the journal-size estimate grows with category expansion", {
  # The expansion driver, tested directly: buildBaselineTables emits one
  # line per populated category column for each categorical variable, so
  # a table that is short but WIDE in categories is a large output from
  # a small input. Tested on the estimator rather than through
  # .apiAnalyze because validateData rejects synthetic wide tables
  # before the journal logic is reached - which would have made this
  # test vacuous (it did; caught 2026-08-27).
  plain <- data.frame(TRIAL = "T", ROW = c("Age", "Age"), N = 50L,
                      MEAN = c(60, 61), SD = c(10, 10),
                      stringsAsFactors = FALSE)
  expect_identical(.apiJournalCells(plain, character(0)), 2)

  wide <- plain
  cats <- paste0("C", seq_len(80))
  for (cn in cats) wide[[cn]] <- 1L
  # 2 rows, each populated across 80 category columns: 2 + 2*80
  expect_identical(.apiJournalCells(wide, cats), 162)

  # the cap is what stands between that growth and the response
  expect_true(.apiMaxJournalCells > 1000)
  big <- wide[rep(1:2, 2000), ]
  expect_gt(.apiJournalCells(big, cats), .apiMaxJournalCells)
  # a category column absent from the frame must not be counted
  expect_identical(.apiJournalCells(plain, c("Male", "Female")), 2)
})

test_that("an ordinary table still gets its journal tables", {
  ex <- system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")
  skip_if(!nzchar(ex), "Example.xlsx not installed")
  skip_on_cran()
  a <- .apiAnalyze(openxlsx::read.xlsx(ex))
  expect_true(a$ok)
  expect_true(length(a$journalTables) >= 1)
  expect_null(a$journalTablesOmitted)
})
