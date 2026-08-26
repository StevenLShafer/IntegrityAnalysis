# apiService.R - the REST API around the analysis (ISSUES.md issue 1).
#
############################################################################
# Provenance                                                               #
# Written 2026-08-26 by Claude Code (model Claude Fable 5) at Steve        #
# Shafer's request ("Is it time to implement the API? I know that will    #
# be of interest to publishers"), to the contract issue 1 has carried     #
# since the start: input is one PDF or spreadsheet; on pass return the    #
# Monte Carlo results plus confirmation the upload was deleted; on fail   #
# return THE PARTIAL TABLE - valid input for the next call - plus what    #
# is wrong with it; retention none.                                       #
#                                                                          #
# Design decisions (Steve, 2026-08-26):                                    #
# - Hosting target is an AWS container (phase 2); THIS file is           #
#   hosting-agnostic - runApiService() starts plumber on a port and      #
#   works identically on a laptop and in a container.                     #
# - Callers authenticate with bearer tokens Steve issues: the            #
#   INTEGRITY_API_TOKENS environment variable holds a comma-separated    #
#   list; a request whose Authorization header does not carry one of     #
#   them is refused 401 before any handler runs. /health alone is open   #
#   (it serves load balancers and carries no data).                       #
# - BYOK per request (issue 8's service side): an X-Anthropic-Key        #
#   header switches parsing from ai="never" to the fallback path for     #
#   THAT request only. The key is the caller's consent and their bill;   #
#   it is never stored, never logged, and is scrubbed from any error     #
#   text that could echo it - same guarantees as the app.                #
#                                                                          #
# The security posture the app promises is preserved here:                #
# - every upload lands in its own fresh tempdir that is deleted when     #
#   the request ends, success or failure - the response says so          #
#   ("deleted": true), because the contract requires confirming it;      #
# - PDFs and docx go through parseBaselineTableFiles(), the subprocess-  #
#   per-file batcher with an OS timeout: ~2% of real PDFs hang poppler,  #
#   R cannot interrupt it, and a service must survive a crafted or       #
#   broken upload (the manuscript AUTHOR is the adversary - AGENTS.md);  #
# - no code path writes an upload anywhere but its request tempdir.      #
#                                                                          #
# Status: run and verified by tests/testthat/test-api-service.R, which   #
# boots the service in a callr subprocess and exercises health, auth,    #
# parse (success and the failure round-trip), and analyze end to end.    #
############################################################################

# ---- request helpers (plain functions, unit-testable without a server) ---

.apiTokens <- function()
  trimws(strsplit(Sys.getenv("INTEGRITY_API_TOKENS", ""), ",")[[1]])

.apiAuthorized <- function(authHeader) {
  toks <- .apiTokens()
  if (length(toks) == 0 || all(!nzchar(toks))) return(FALSE)
  if (is.null(authHeader) || !nzchar(authHeader)) return(FALSE)
  supplied <- sub("(?i)^\\s*Bearer\\s+", "", authHeader, perl = TRUE)
  supplied %in% toks[nzchar(toks)]
}

# The template CSV: the exact column layout validateData() accepts, so
# the failure payload is - by construction - valid input to the next
# call (the round-trip contract). Category columns ride after the base
# columns, as everywhere else.
.apiTemplateCsv <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    data <- as.data.frame(setNames(
      rep(list(character(0)), length(.ppBaseColumns())), .ppBaseColumns()))
  }
  base <- intersect(.ppBaseColumns(), names(data))
  data <- data[, c(base, setdiff(names(data), base)), drop = FALSE]
  con <- textConnection("out", "w", local = TRUE)
  utils::write.csv(data, con, row.names = FALSE, na = "")
  close(con)
  paste0(paste(out, collapse = "\n"), "\n")
}

# Read one uploaded file into template-layout rows. PDFs and Word
# manuscripts go through the subprocess batcher; spreadsheets try the
# journal-style wide layout first (parseWideTable) and fall back to the
# template layout read.
.apiReadUpload <- function(path, name, apiKey = NULL) {
  ext <- tolower(tools::file_ext(name))
  stem <- tools::file_path_sans_ext(basename(name))
  if (ext %in% c("pdf", "docx")) {
    aiOn <- !is.null(apiKey) && nzchar(apiKey)
    res <- parseBaselineTableFiles(
      path, ai = if (aiOn) "fallback" else "never",
      timeout = if (aiOn) 300 else 60,
      quiet = TRUE, apiKey = if (aiOn) apiKey else NULL)
    r <- res$result[[1]]
    if (is.null(r) || nrow(r$data) == 0) {
      msg <- res$error[1]
      if (!is.null(apiKey) && nzchar(apiKey))
        msg <- gsub(apiKey, "<key>", msg, fixed = TRUE)
      msg <- gsub(path, name, msg, fixed = TRUE)
      return(list(ok = FALSE, reasons = msg, data = NULL,
                  skipped = NULL, flags = character(0),
                  engine = NA_character_))
    }
    d <- r$data
    d$TRIAL <- stem
    list(ok = TRUE, data = d,
         skipped = if (nrow(r$skipped)) r$skipped else NULL,
         flags = r$flags %||% character(0),
         engine = r$engine)
  } else if (ext %in% c("csv", "xls", "xlsx")) {
    wide <- tryCatch(parseWideTable(path, ext), error = function(e) NULL)
    if (!is.null(wide)) {
      d <- do.call(.ppRbindFill, lapply(wide, function(b) {
        bd <- b$data
        if (!"TRIAL" %in% names(bd) || all(is.na(bd$TRIAL)))
          bd$TRIAL <- if (is.null(b$trial) || is.na(b$trial)) stem else b$trial
        bd
      }))
      return(list(ok = TRUE, data = d, skipped = NULL,
                  flags = character(0), engine = "wide"))
    }
    d <- tryCatch({
      if (ext == "csv") utils::read.csv(path, check.names = FALSE)
      else openxlsx::read.xlsx(path)
    }, error = function(e) NULL)
    if (is.null(d) || nrow(d) == 0)
      return(list(ok = FALSE,
                  reasons = paste0("could not read ", name,
                                   " as a template or journal-style table"),
                  data = NULL, skipped = NULL, flags = character(0),
                  engine = NA_character_))
    if (!"TRIAL" %in% names(d)) d$TRIAL <- stem
    list(ok = TRUE, data = d, skipped = NULL, flags = character(0),
         engine = "template")
  } else {
    list(ok = FALSE, reasons = paste0("unsupported file type: .", ext),
         data = NULL, skipped = NULL, flags = character(0),
         engine = NA_character_)
  }
}

# The /analyze pipeline after reading: validate, then Monte Carlo.
.apiAnalyze <- function(DATA) {
  v <- validateData(DATA)
  if (isTRUE(v$FAIL)) {
    return(list(ok = FALSE, stage = "validation",
                issues = if (!is.null(v$issues)) v$issues else NULL,
                templateCsv = .apiTemplateCsv(
                  if (!is.null(v$DATA)) v$DATA else DATA)))
  }
  OUTPUT <- NULL
  for (TRIAL in v$TRIALS)
    OUTPUT <- rbind(OUTPUT,
                    P_Calc(TRIAL, v$DATA, v$CategoryNames, m))
  # per-trial summary p's, plus the overall Stouffer combination across
  # trials (the same closure the results workbook reports)
  sm <- OUTPUT[!is.na(OUTPUT$ROW) & OUTPUT$ROW == "Summary", , drop = FALSE]
  trialP <- suppressWarnings(as.numeric(sm$P))
  ok <- !is.na(trialP)
  overall <- if (sum(ok) > 1) signif(sumz(trialP[ok])$p, 4)
             else if (sum(ok) == 1) trialP[ok]
             else NA_real_
  list(ok = TRUE, stage = "analysis",
       results = OUTPUT, overallP = overall,
       trials = length(v$TRIALS),
       templateCsv = .apiTemplateCsv(v$DATA))
}

#' Run the IntegrityAnalysis REST service
#'
#' Starts the plumber API defined in `inst/api/plumber.R`. Endpoints:
#' `GET /health` (open); `POST /parse` and `POST /analyze` (bearer
#' token). Uploads are multipart (`file`); an `X-Anthropic-Key` header
#' turns on the per-request AI assist under the caller's own key
#' (issue 8's service side). Every upload is deleted when its request
#' ends, and the response says so - the retention contract of issue 1.
#'
#' @param port TCP port (default 8080, the AWS App Runner convention).
#' @param host bind address; `"0.0.0.0"` for containers.
#' @return Called for the side effect of running the server; blocks.
#' @export
runApiService <- function(port = 8080, host = "0.0.0.0") {
  if (!requireNamespace("plumber", quietly = TRUE))
    stop("The API service needs the 'plumber' package.")
  # The analysis stack expects these ATTACHED, exactly as run_app()
  # attaches them (P_Calc's %do%, dqrnorm, s.u, and Rfast matrix ops
  # resolve from the search path - the app_run.R list minus the Shiny
  # UI packages, which a REST service has no use for).
  suppressWarnings(suppressPackageStartupMessages({
    library(shiny)      # outputComments isolates; no UI is started
    library(openxlsx)
    library(readxl)
    library(Rfast)
    library(foreach)
    library(MBESS)
    library(dqrng)
  }))
  if (length(.apiTokens()) == 0)
    message("WARNING: INTEGRITY_API_TOKENS is empty - every /parse and ",
            "/analyze request will be refused 401. Set it to a ",
            "comma-separated token list before exposing the service.")
  pr <- plumber::pr(system.file("api", "plumber.R",
                                package = "IntegrityAnalysis"))
  plumber::pr_run(pr, host = host, port = port)
}
