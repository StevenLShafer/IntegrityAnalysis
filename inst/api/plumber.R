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

#* Service health and identity
#* @serializer unboxedJSON
#* @get /health
function() {
  list(ok = TRUE,
       service = "IntegrityAnalysis",
       version = as.character(utils::packageVersion("IntegrityAnalysis")),
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
       resultsCsv = paste0(paste(utils::capture.output(
         utils::write.csv(a$results, row.names = FALSE, na = "")),
         collapse = "\n"), "\n"),
       templateCsv = a$templateCsv,
       deleted = TRUE)
}
