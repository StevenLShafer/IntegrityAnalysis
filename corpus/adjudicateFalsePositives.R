# adjudicateFalsePositives.R - when the parser finds a "baseline table"
# in a protocol, WHAT did it actually find?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction. LOCAL CORPUS TOOLING ONLY - nothing here ships.      #
#                                                                          #
# THE CORRECTION THIS EXISTS TO MAKE. measureFalsePositives.R reported     #
# that the parser returned a baseline table for 255 of 600 protocol PDFs   #
# (42.5%), and asserted that every one is a false positive because "a      #
# protocol cannot contain a baseline table". Steve pointed out that this   #
# is wrong: a protocol or statistical analysis plan may legitimately quote #
# the baseline table of a PRIOR study when justifying the design, the      #
# expected population or the sample size. It cannot contain a baseline     #
# table for ITS OWN trial - that trial has not run - but a real baseline   #
# table from someone else's trial is fair game.                            #
#                                                                          #
# The first case inspected by hand was exactly that: weight, length and    #
# head circumference with means and SDs, taken from a previously published #
# study cited in the background section.                                   #
#                                                                          #
# SO 42.5% CONFLATES TWO DIFFERENT FAILURES:                               #
#                                                                          #
#   PARSER DEFECT  - prose, a schedule of assessments or a sample-size     #
#                    grid assembled into something shaped like a table.    #
#                    The parser is wrong about what it is reading.         #
#   CONTEXT ERROR  - a genuine baseline table, correctly extracted, that   #
#                    belongs to a DIFFERENT study. The parser did its job; #
#                    nothing told it which trial the document is about.    #
#                                                                          #
# Both hand an editor a verdict computed from the wrong numbers, so both    #
# matter operationally - but they have different fixes, and quoting one    #
# number for both overstates the parser's defect rate.                     #
#                                                                          #
# WHY AI RATHER THAN A HEURISTIC. Telling those apart requires reading the #
# page and understanding whether the table describes this protocol's own   #
# (not yet enrolled) population or someone else's completed one. That is a #
# judgment about document context, not a pattern. The prose-in-row-labels  #
# heuristic caught only 15% of cases and cannot make this distinction at   #
# all.                                                                     #
#                                                                          #
# COST CONTROL, because these are Steve's tokens: the script prints an     #
# estimate and REFUSES to send anything until run with --go. Only the      #
# single page the parser used is sent, never the whole protocol - a        #
# median protocol is 0.8 MB and would be ~100x the tokens for no gain.     #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/adjudicateFalsePositives.R <docDir> [n] [--go]          #
#     docDir  directory of protocol PDFs                                   #
#     n       how many to adjudicate (default 50; 0 = all)                 #
#     --go    actually send. Without it, estimates and exits.              #
#                                                                          #
#   Needs ANTHROPIC_API_KEY in ~/.Renviron. The key is never printed,      #
#   logged, or written to the results file.                                #
############################################################################

suppressPackageStartupMessages({ library(jsonlite); library(httr2) })

args   <- commandArgs(trailingOnly = TRUE)
go     <- any(args == "--go")
args   <- args[args != "--go"]
docDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_docs")
maxN   <- if (length(args) >= 2) as.integer(args[2]) else 50L

root   <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
fpCsv  <- file.path(root, ".NewCarlisle", "falsepos", "falsePositives.csv")
outCsv <- file.path(root, ".NewCarlisle", "falsepos", "adjudicated.csv")
MODEL  <- Sys.getenv("INTEGRITY_ADJUDICATE_MODEL", "claude-sonnet-5")

if (!file.exists(fpCsv))
  stop("no falsePositives.csv - run corpus/measureFalsePositives.R first",
       call. = FALSE)
fp <- utils::read.csv(fpCsv, stringsAsFactors = FALSE)
fp <- fp[fp$ROWS > 0, , drop = FALSE]
cat("parser produced a table for", nrow(fp), "document(s)\n")
if (maxN > 0) fp <- utils::head(fp, maxN)

# Only the page the parser used. pdftools reads it directly; the PAGE
# column comes from the ParsePDFTable the measurement recorded.
pageText <- function(pdf, page) {
  txt <- tryCatch(pdftools::pdf_text(pdf), error = function(e) character(0))
  if (!length(txt)) return("")
  p <- suppressWarnings(as.integer(page))
  if (is.na(p) || p < 1 || p > length(txt)) p <- 1L
  substr(txt[p], 1, 12000)
}

cat("gathering page text...\n")
fp$TEXT <- vapply(seq_len(nrow(fp)), function(i)
  pageText(file.path(docDir, fp$PDF[i]), fp$PAGE[i]), character(1))
fp <- fp[nzchar(fp$TEXT), , drop = FALSE]

# Rough token estimate: ~4 characters per token, plus a fixed prompt.
chars <- sum(nchar(fp$TEXT)) + nrow(fp) * 1200
cat(sprintf("\n  documents to adjudicate : %d\n", nrow(fp)))
cat(sprintf("  approx input tokens     : %s\n", format(round(chars / 4), big.mark = ",")))
cat(sprintf("  model                   : %s\n", MODEL))
if (!go) {
  cat("\n  DRY RUN - nothing sent. Re-run with --go to spend tokens.\n")
  quit(status = 0)
}
if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY")))
  stop("ANTHROPIC_API_KEY is not set - put it in ~/.Renviron", call. = FALSE)

SYS <- paste(
  "You are auditing a clinical trial PROTOCOL or STATISTICAL ANALYSIS PLAN.",
  "An automated parser extracted something it believed was a baseline",
  "characteristics table from the page shown. A protocol is written BEFORE",
  "its trial runs, so it cannot contain baseline characteristics for its",
  "OWN participants - but it may legitimately quote a baseline table from a",
  "PREVIOUSLY PUBLISHED study when justifying the design or sample size.",
  "Decide which of these the page contains. Answer only with the JSON.")

# additionalProperties = FALSE is REQUIRED, not optional: the API rejects
# an object schema without it -
#   "output_config.format.schema: For 'object' type,
#    'additionalProperties' must be explicitly set to false"
# The first run of this script omitted it and every one of 255 requests
# came back 400. Rejected requests are not billed, so the cost was zero -
# but the error handling below reported them all as a bland "request
# failed", which is what actually made it expensive in time.
SCHEMA <- list(type = "object", additionalProperties = FALSE,
  properties = list(
    class = list(type = "string",
                 enum = c("prior_study", "own_trial", "not_a_baseline_table")),
    confidence = list(type = "string", enum = c("high", "medium", "low")),
    reason = list(type = "string")),
  required = list("class", "confidence", "reason"))

ask <- function(txt, labels) {
  body <- list(
    model = MODEL, max_tokens = 1000L, system = SYS,
    output_config = list(format = list(type = "json_schema", schema = SCHEMA)),
    messages = list(list(role = "user", content = paste0(
      "Row labels the parser extracted:\n", labels,
      "\n\n--- PAGE TEXT ---\n", txt))))
  # SURFACE THE REAL ERROR. The first version collapsed every failure to
  # "request failed", so 255 identical 400s looked like a mystery instead
  # of a one-line schema fix. Errors are not suppressed here: the HTTP
  # status and the API's own message are carried into the results file.
  resp <- tryCatch(
    httr2::request("https://api.anthropic.com/v1/messages") |>
      httr2::req_headers(`x-api-key` = Sys.getenv("ANTHROPIC_API_KEY"),
                         `anthropic-version` = "2023-06-01") |>
      httr2::req_body_json(body) |>
      httr2::req_timeout(120) |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform(),
    error = function(e)
      structure(list(msg = conditionMessage(e)), class = "transportError"))
  if (inherits(resp, "transportError"))
    return(list(class = "ERROR", confidence = "",
                reason = paste("transport:", resp$msg)))
  st <- httr2::resp_status(resp)
  if (st != 200)
    return(list(class = "ERROR", confidence = "",
                reason = paste0("HTTP ", st, ": ",
                                substr(httr2::resp_body_string(resp), 1, 300))))
  r <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  txtOut <- tryCatch(r$content[[1]]$text, error = function(e) "")
  out <- tryCatch(jsonlite::fromJSON(txtOut), error = function(e) NULL)
  if (is.null(out$class))
    list(class = "ERROR", confidence = "",
         reason = paste("unparseable reply:", substr(txtOut, 1, 200)))
  else out
}

res <- vector("list", nrow(fp))
for (i in seq_len(nrow(fp))) {
  a <- ask(fp$TEXT[i], as.character(fp$PROSEY_LABELS[i]))
  res[[i]] <- data.frame(PDF = fp$PDF[i], ROWS = fp$ROWS[i], PAGE = fp$PAGE[i],
                         CLASS = a$class, CONFIDENCE = a$confidence %||% "",
                         REASON = substr(a$reason %||% "", 1, 200),
                         stringsAsFactors = FALSE)
  cat("\r  adjudicated", i, "of", nrow(fp))
}
cat("\n")
`%||%` <- function(a, b) if (is.null(a)) b else a
out <- do.call(rbind, res)
utils::write.csv(out, outCsv, row.names = FALSE)

cat("\n============ WHAT THE PARSER ACTUALLY FOUND ============\n")
tb <- sort(table(out$CLASS), decreasing = TRUE)
for (k in seq_along(tb))
  cat(sprintf("  %-24s %4d  (%.1f%%)\n", names(tb)[k], tb[k],
              100 * tb[k] / nrow(out)))
cat("\n  prior_study          = a REAL baseline table from another trial:\n")
cat("                         the parser was right, the context was wrong\n")
cat("  not_a_baseline_table = a parser defect\n")
cat("  own_trial            = should be impossible; inspect these by hand\n")
cat("\nwritten:", outCsv, "\n")
