# plumber.R - endpoint definitions for the IntegrityAnalysis REST API.
#
# PROVENANCE: written 2026-08-26 with R/apiService.R (issue 1); the
# annotations here stay thin - every decision lives in the .api*
# helpers, which the test suite exercises directly. Loaded by
# runApiService() via plumber::pr().

#* @filter auth
function(req, res) {
  # /health stays open: it serves load balancers and carries no data.
  if (req$PATH_INFO == "/health") return(plumber::forward())
  if (!IntegrityAnalysis:::.apiAuthorized(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(list(ok = FALSE, error = paste(
      "Missing or invalid bearer token. Send 'Authorization: Bearer",
      "<token>' with a token issued by the service operator.")))
  }
  plumber::forward()
}

# Request-size guard (security review H1, and its RE-REVIEW 2026-08-26).
#
# ORDER: this runs AFTER auth, deliberately. The body is fully buffered
# before either filter executes (see below), so putting size first buys
# no memory - while putting AUTH first means an unauthenticated caller
# learns nothing about our policies and simply gets 401.
#
# HONEST SCOPE - read this before trusting it: httpuv buffers the entire
# request into memory, and plumber's own default `body` filter parses it,
# BEFORE any filter in this file runs. So this check does NOT prevent the
# memory spike from a giant upload; by the time it executes the bytes are
# already resident. What it does prevent is everything downstream - the
# writeBin second copy, the parse, the simulation - and it makes the
# refusal cheap and explicit.
#
# THE REAL BODY CAP MUST LIVE IN FRONT OF THE SERVICE (a proxy/WAF ahead
# of App Runner). That is tracked in ISSUES.md issue 1; do not delete
# this comment believing the filter alone closes H1.
#
# A request with NO Content-Length (chunked transfer-encoding) is
# REFUSED rather than forwarded: the re-review found that falling open
# there bypassed the cap entirely, and a legitimate multipart client
# always declares a length.
.apiMaxBytes <- 26214400L   # 25 MiB

#* @filter sizelimit
function(req, res) {
  # thin wrapper: the decision lives in .apiSizeVerdict, a pure function
  # the tests exercise branch by branch
  verdict <- IntegrityAnalysis:::.apiSizeVerdict(req$REQUEST_METHOD,
                                                 req$HTTP_CONTENT_LENGTH)
  if (identical(verdict, "no_length")) {
    res$status <- 411          # Length Required
    return(list(ok = FALSE, error = paste(
      "A Content-Length header is required. Chunked uploads are not",
      "accepted by this service.")))
  }
  if (identical(verdict, "too_large")) {
    res$status <- 413
    return(list(ok = FALSE, error = paste0(
      "Upload exceeds the ",
      round(IntegrityAnalysis:::.apiMaxBytes / 1024^2),
      " MB limit. Send one document per request.")))
  }
  plumber::forward()
}

#* Service health and identity
#* @serializer unboxedJSON
#* @get /health
function() {
  list(ok = TRUE,
       service = "IntegrityAnalysis",
       version = as.character(utils::packageVersion("IntegrityAnalysis")),
       # The commit this service was built from (issue 28), so an
       # operator - or tools/checkDeployedBuild.ps1 - can compare what
       # is RUNNING against what is in the repository. /health is the
       # right home for it: open, unauthenticated, already the endpoint
       # a monitor polls. The repository is public, so the hash reveals
       # nothing. NOT attestation: anyone who can deploy arbitrary code
       # can report an arbitrary commit. It catches the wrong branch,
       # the stale deploy and the careless hand-edit, which is most of
       # what actually goes wrong.
       commit = {
         s <- IntegrityAnalysis::buildCommit()
         if (is.na(s)) "unknown" else s
       },
       engine = "deterministic (Carlisle-Shafer Monte Carlo)")
}

#* Parse one document into the template layout
#* @serializer unboxedJSON
#* @post /parse
#* @param file:file The document: PDF, Word (.docx), or spreadsheet.
function(req, res, file) {
  # Every upload lives in its own tempdir and dies with the request -
  # the retention contract (issue 1). The response confirms it.
  work <- file.path(tempdir(), paste0("api", basename(tempfile(""))))
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE, force = TRUE), add = TRUE)
  name <- names(file)[1]
  path <- file.path(work, basename(name))
  writeBin(file[[1]], path)

  key <- req$HTTP_X_ANTHROPIC_KEY
  r <- IntegrityAnalysis:::.apiReadUpload(path, name, apiKey = key)
  if (!isTRUE(r$ok)) {
    res$status <- 422
    return(list(ok = FALSE, file = name, reasons = r$reasons,
                templateCsv = IntegrityAnalysis:::.apiTemplateCsv(NULL),
                deleted = TRUE))
  }
  list(ok = TRUE, file = name, engine = r$engine,
       flags = as.list(r$flags),
       rows = nrow(r$data),
       skipped = if (!is.null(r$skipped))
         lapply(seq_len(nrow(r$skipped)), function(i)
           list(label = r$skipped$label[i], reason = r$skipped$reason[i]))
       else list(),
       templateCsv = IntegrityAnalysis:::.apiTemplateCsv(r$data),
       deleted = TRUE)
}

#* Parse (if needed), validate, and run the Monte Carlo
#* @serializer unboxedJSON
#* @post /analyze
#* @param file:file The document: PDF, Word (.docx), or spreadsheet.
function(req, res, file) {
  work <- file.path(tempdir(), paste0("api", basename(tempfile(""))))
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE, force = TRUE), add = TRUE)
  name <- names(file)[1]
  path <- file.path(work, basename(name))
  writeBin(file[[1]], path)

  key <- req$HTTP_X_ANTHROPIC_KEY
  r <- IntegrityAnalysis:::.apiReadUpload(path, name, apiKey = key)
  if (!isTRUE(r$ok)) {
    res$status <- 422
    return(list(ok = FALSE, stage = "parse", file = name,
                reasons = r$reasons,
                templateCsv = IntegrityAnalysis:::.apiTemplateCsv(NULL),
                deleted = TRUE))
  }
  a <- IntegrityAnalysis:::.apiAnalyze(r$data)
  if (!isTRUE(a$ok)) {
    # the round-trip contract: the failure payload IS the next call's
    # input - fix the flagged cells in templateCsv and POST it back
    res$status <- 422
    return(list(ok = FALSE, stage = a$stage, file = name,
                issues = if (!is.null(a$issues))
                  lapply(seq_len(nrow(a$issues)), function(i)
                    as.list(a$issues[i, ])) else list(),
                templateCsv = a$templateCsv,
                deleted = TRUE))
  }
  list(ok = TRUE, file = name, trials = a$trials,
       overallP = a$overallP,
       # sanitized against spreadsheet formula injection (review M5)
       resultsCsv = IntegrityAnalysis:::.apiResultsCsv(a$results),
       # the reconstructed journal-style table per trial (issue 15) -
       # what an editor compares against the manuscript page
       journalTables = a$journalTables,
       # ...and WHY it is absent when it is. .apiAnalyze omits the
       # tables above .apiMaxJournalCells and builds an explanation;
       # this handler used to drop that explanation on the floor, so a
       # caller saw journalTables: null with nothing to distinguish
       # "too large" from "nothing to build" or an internal failure.
       # PR #91's commit message claimed callers "read a reason instead
       # of guessing at a null" - they did not, until here. (F2 of the
       # 2026-08-27 screen: the gap was between the stated guarantee
       # and the code, which is a kind of defect no test was asking
       # about.) Omitted from the JSON entirely when there is nothing
       # to say, so the ordinary response is unchanged.
       journalTablesOmitted = a$journalTablesOmitted,
       templateCsv = a$templateCsv,
       deleted = TRUE)
}
