# test-idconv-predicates.R - the ID-converter guards in fetchCorpusIdentity.R
#
############################################################################
# Provenance                                                               #
# Written 2026-09-02 by Claude Code (model Claude Fable 5.1) for PR #143,  #
# which addressed the CodeRabbit findings against the converter block.     #
#                                                                          #
# WHY THIS RUNS WITHOUT THE NETWORK. The script it tests calls NCBI on     #
# source, reads the private identity index, and writes it back. None of    #
# that belongs in a test, so the helper below parses the file and          #
# evaluates ONLY the function definitions, leaving every top-level call    #
# unexecuted. The error handler is exercised by handing it synthetic       #
# conditions carrying the real messages curl and jsonlite produce (the     #
# eleven in C:/dev/Corpus/ocr/idconvcheck.R, plus the yajl forms observed  #
# 2026-09-02); the shape predicates are exercised against reply shapes     #
# copied from the live endpoint the same day.                              #
#                                                                          #
# SCOPE, STATED HONESTLY. corpus/ is .Rbuildignore'd, so this file SKIPS   #
# under R CMD check and runs only in a development tree - the same         #
# limitation test-safe-match.R records, for the same reason.               #
############################################################################

sourceIdconv <- function() {
  env <- parent.frame()
  p <- testthat::test_path("..", "..", "corpus", "fetchCorpusIdentity.R")
  if (!file.exists(p))
    testthat::skip("corpus/ is .Rbuildignore'd - not present in a built package")
  wanted <- c("idconvUrl", "idconvOk", "idconvWhy", "idconvOnce", "idconv")
  for (e in parse(p, keep.source = FALSE))
    if (is.call(e) && identical(e[[1]], as.name("<-")) &&
        as.character(e[[2]]) %in% wanted)
      eval(e, env)
  # idconv() backs off with Sys.sleep(5 * i); the stubs below must not.
  assign("Sys.sleep", function(...) invisible(NULL), envir = env)
}

# The reply shapes the live endpoint returned on 2026-09-02, verbatim.
mixed <- list(records = data.frame(
  doi = c("10.1186/1471-2261-14-172", NA), pmcid = c("PMC4280683", "PMC9999999999"),
  pmid = c(25433674L, NA), `requested-id` = c("PMC4280683", "PMC9999999999"),
  status = c(NA, "error"), errmsg = c(NA, "Identifier not found in PMC"),
  check.names = FALSE, stringsAsFactors = FALSE))
noneMapped <- list(records = data.frame(
  pmcid = c("PMC9999999999", "PMC9999999998"),
  `requested-id` = c("PMC9999999999", "PMC9999999998"),
  status = "error", errmsg = "Identifier not found in PMC",
  check.names = FALSE, stringsAsFactors = FALSE))

test_that("a batch in which nothing maps is a valid answer, not a shape change", {
  sourceIdconv()
  # The first version of the predicate required a pmid column. The live
  # endpoint omits it when no requested id has one, so a batch of 200
  # PMCIDs that all lack a PMID would have stopped the run.
  expect_false("pmid" %in% names(noneMapped$records))
  expect_true(idconvOk(noneMapped, c("PMC9999999999", "PMC9999999998")))
  expect_true(idconvOk(mixed, c("PMC4280683", "PMC9999999999")))
  # The API upper-cases whatever it was asked in.
  expect_true(idconvOk(mixed, c("pmc4280683", "pmc9999999999")))
})

test_that("a truncated, surplus or duplicated reply is refused and named", {
  sourceIdconv()
  # Three asked, two answered: accepting this would resolve part of a batch
  # and leave the third looking like a PMCID with no PMID.
  ids <- c("PMC4280683", "PMC9999999999", "PMC1234567")
  expect_false(idconvOk(mixed, ids))
  expect_match(idconvWhy(mixed, ids), "covered 2 of 3 requested ids")
  expect_match(idconvWhy(mixed, ids), "PMC1234567")

  # Two asked, three answered: an id nobody requested is a shape change
  # too, not a bonus - subset membership would have let it through.
  expect_false(idconvOk(mixed, "PMC4280683"))
  expect_match(idconvWhy(mixed, "PMC4280683"), "not requested")
  expect_match(idconvWhy(mixed, "PMC4280683"), "PMC9999999999")

  dup <- list(records = rbind(mixed$records, mixed$records[1, ]))
  expect_false(idconvOk(dup, c("PMC4280683", "PMC9999999999")))
  expect_match(idconvWhy(dup, c("PMC4280683", "PMC9999999999")), "repeated")
})

test_that("a reply that is not a JSON object is diagnosed, not an error", {
  sourceIdconv()
  # jsonlite::fromJSON('"text"') is a character vector; `$` on it throws
  # "$ operator is invalid for atomic vectors", which would have replaced
  # the diagnostic with a stack trace.
  scalar <- jsonlite::fromJSON('"text"')
  expect_false(is.list(scalar))
  expect_false(idconvOk(scalar, "PMC1"))
  expect_match(idconvWhy(scalar, "PMC1"), "not a JSON object")

  expect_false(idconvOk(list(status = "error"), "PMC1"))
  expect_match(idconvWhy(list(status = "error"), "PMC1"), "no 'records'")
  notTable <- list(records = list(pmcid = "PMC1"))
  expect_false(idconvOk(notTable, "PMC1"))
  expect_match(idconvWhy(notTable, "PMC1"), "not a table")
  noKey <- list(records = data.frame(pmcid = "PMC1", pmid = "1"))
  expect_false(idconvOk(noKey, "PMC1"))
  expect_match(idconvWhy(noKey, "PMC1"), "requested-id")
})

test_that("the error handler tells transport from malformed, and retries the right ones", {
  sourceIdconv()
  # The handler is the `error =` argument of idconvOnce's tryCatch; pull it
  # out and hand it conditions carrying real messages.
  handler <- eval(body(idconvOnce)$error)
  classify <- function(msg) {
    r <- handler(simpleError(msg))
    list(kind = attr(r, "kind"), transient = attr(r, "transient"),
         why = idconvWhy(r, "PMC1"))
  }
  # curl: transient, retried
  for (m in c("HTTP error 429.", "HTTP error 503.", "HTTP error 599.",
              "Timeout was reached: [eutils] Operation timed out",
              "cannot open URL 'https://...'")) {
    c1 <- classify(m)
    expect_identical(c1$kind, "transport failure", info = m)
    expect_true(c1$transient, info = m)
    expect_match(c1$why, "^transport failure - ")
  }
  # curl: permanent
  for (m in c("HTTP error 404.", "HTTP error 400.")) {
    expect_identical(classify(m)$kind, "transport failure", info = m)
    expect_false(classify(m)$transient, info = m)
  }
  # \b must be a word boundary: digits that merely CONTAIN a code are not
  # that code (and without perl = TRUE the pattern matches nothing at all).
  expect_false(classify("record 15030 rejected")$transient)

  # jsonlite (yajl): the forms observed 2026-09-02, multi-line and all
  html <- "lexical error: invalid char in json text.\n                                       <html>oops\n                     (right here) ------^\n"
  h <- classify(html)
  expect_identical(h$kind, "malformed reply")
  expect_false(h$transient)
  expect_match(h$why, "^malformed reply - lexical error")
  expect_false(grepl("\n", h$why))            # collapsed for the log
  cut <- "parse error: premature EOF\n                                       {\"records\": [\n                     (right here) ------^\n"
  expect_identical(classify(cut)$kind, "malformed reply")
  expect_true(classify(cut)$transient)         # a body cut off mid-stream
})

test_that("idconv retries only transient failures and reports which it was", {
  sourceIdconv()
  calls <- 0L
  handler <- eval(body(idconvOnce)$error)
  idconvOnce <- function(ids) { calls <<- calls + 1L; handler(simpleError("HTTP error 429.")) }
  r <- idconv("PMC1", tries = 3L)
  expect_identical(calls, 3L)
  expect_true(isTRUE(attr(r, "exhausted")))
  expect_match(idconvWhy(r, "PMC1"), "transport failure - HTTP error 429")

  # A truncated reply is well-formed and wrong; retrying will not change it.
  calls <- 0L
  idconvOnce <- function(ids) { calls <<- calls + 1L; mixed }
  r <- idconv(c("PMC4280683", "PMC9999999999", "PMC1234567"), tries = 3L)
  expect_identical(calls, 1L)
  expect_false(isTRUE(attr(r, "exhausted")))
  expect_false(idconvOk(r, c("PMC4280683", "PMC9999999999", "PMC1234567")))

  # And a good reply comes straight back.
  calls <- 0L
  r <- idconv(c("PMC4280683", "PMC9999999999"), tries = 3L)
  expect_identical(calls, 1L)
  expect_true(idconvOk(r, c("PMC4280683", "PMC9999999999")))
})
