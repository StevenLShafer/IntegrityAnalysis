# apiClient.R - drive the IntegrityAnalysis REST service from R, by hand.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-03 by Claude Code (model Claude Fable 5.1) at Steve      #
# Shafer's request: "I haven't tested the API interface ... Have you       #
# written an R script that you've used to test the API interface?" The    #
# test suite (tests/testthat/test-api-service.R) boots the service in a   #
# subprocess and posts files over HTTP, but it is a test, not something   #
# a person runs. This is the by-hand client: health, then one file to     #
# /parse or /analyze, the reply printed and its CSVs saved beside the     #
# input. It uses only packages the package already imports (httr2, curl).#
############################################################################
#
# Usage (from anywhere; Rscript from the R 4.5.3 installation):
#
#   Rscript tools/apiClient.R health  <base-url>
#   Rscript tools/apiClient.R parse   <base-url> <file>
#   Rscript tools/apiClient.R analyze <base-url> <file>
#
#   <file>     an article PDF, Word manuscript (.docx), JATS XML (.xml),
#              spreadsheet (csv/xls/xlsx), or picture of a table
#              (jpg/png/tif). One file per call - the service takes no zip.
#   The service takes no replication count: every row runs the app's
#   staged Monte Carlo (1,000 / 10,000 / 100,000 replicates, escalating
#   only while the row alarms), and the M column of the results says
#   what each row used.
#
# The bearer token comes from the INTEGRITY_API_TOKEN environment variable
# (the plaintext token the operator issued with tools/issueApiToken.R;
# the service holds only its hash). /health needs no token.
#
# AGAINST A LOCAL SERVICE, in a second R session (or terminal):
#   Sys.setenv(INTEGRITY_API_TOKENS = "local-test-token")
#   IntegrityAnalysis::runApiService(port = 8080, host = "127.0.0.1")
# then here:
#   Sys.setenv(INTEGRITY_API_TOKEN = "local-test-token") / set INTEGRITY_API_TOKEN=...
#   Rscript tools/apiClient.R analyze http://127.0.0.1:8080 path/to/article.pdf
#
# AGAINST THE DEPLOYED SERVICE (AWS App Runner, service
# "integrityanalysis-api"): the base URL is the service's ServiceUrl -
#   aws apprunner list-services --profile steve --region us-east-1 \
#     --query "ServiceSummaryList[?ServiceName=='integrityanalysis-api'].ServiceUrl" --output text
# (prefix https://), and the token is one issued to you. Everything you
# send is processed in a per-request directory and deleted when the
# reply is written; the reply says so ("deleted": true).

args <- commandArgs(trailingOnly = TRUE)
usage <- function() {
  cat("usage: Rscript tools/apiClient.R health  <base-url>\n",
      "       Rscript tools/apiClient.R parse   <base-url> <file>\n",
      "       Rscript tools/apiClient.R analyze <base-url> <file>\n", sep = "")
  quit(status = 2)
}
if (length(args) < 2) usage()
verb <- args[1]; base <- sub("/+$", "", args[2])
if (!verb %in% c("health", "parse", "analyze")) usage()
if (verb != "health" && length(args) < 3) usage()
suppressPackageStartupMessages({ library(httr2); library(curl) })
token <- Sys.getenv("INTEGRITY_API_TOKEN", "")

say <- function(...) cat(paste0(..., collapse = ""), "\n")
show <- function(label, x) if (!is.null(x) && length(x)) say("  ", label, ": ", paste(unlist(x), collapse = "; "))

# ---- health: open, no token ------------------------------------------------
h <- tryCatch(request(paste0(base, "/health")) |> req_timeout(30) |> req_perform(),
              error = function(e) e)
if (inherits(h, "error")) {
  say("health: could not reach ", base, " - ", conditionMessage(h)); quit(status = 1)
}
hb <- resp_body_json(h)
say("health: ", resp_status(h), "  ok=", isTRUE(hb$ok),
    if (!is.null(hb$commit)) paste0("  build ", substr(hb$commit, 1, 8)) else "",
    if (!is.null(hb$engine)) paste0("  ", hb$engine) else "")
if (verb == "health") quit(status = 0)

# ---- parse / analyze: one file, bearer token ------------------------------
if (!nzchar(token)) { say("set INTEGRITY_API_TOKEN to the token the operator issued you"); quit(status = 2) }
file <- args[3]
if (!file.exists(file)) { say("no such file: ", file); quit(status = 2) }

req <- request(paste0(base, "/", verb)) |>
  req_headers(Authorization = paste("Bearer", token)) |>
  req_timeout(if (verb == "analyze") 900 else 300) |>
  req_error(is_error = function(resp) FALSE)
body <- list(file = form_file(file))
req <- req_body_multipart(req, !!!body)

t0 <- Sys.time()
r <- tryCatch(req_perform(req), error = function(e) e)
secs <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
if (inherits(r, "error")) { say(verb, ": request failed - ", conditionMessage(r)); quit(status = 1) }
status <- resp_status(r)
# INTEGRITY_API_SAVE_RAW=1 keeps the reply exactly as received, beside the
# input - for a support question, or for reading the fields the guide names
if (nzchar(Sys.getenv("INTEGRITY_API_SAVE_RAW", ""))) {
  raw <- paste0(tools::file_path_sans_ext(file), "-", verb, "-reply.json")
  writeLines(resp_body_string(r), raw); say("  raw reply: ", raw)
}
b <- tryCatch(resp_body_json(r), error = function(e) NULL)
say(verb, " ", basename(file), ": HTTP ", status, " in ", secs, " s")
if (is.null(b)) { say("  (no JSON body) ", resp_body_string(r)); quit(status = 1) }

say("  ok=", isTRUE(b$ok), "  deleted=", isTRUE(b$deleted),
    if (!is.null(b$engine)) paste0("  engine=", b$engine) else "")
show("reasons", b$reasons)
show("flags", b$flags)
if (!is.null(b$rows)) say("  rows: ", b$rows)
if (length(b$skipped)) {
  say("  skipped ", length(b$skipped), " line(s):")
  for (s in b$skipped) say("    - ", s$label, ": ", s$reason)
}
if (!is.null(b$trials)) say("  trials: ", b$trials)
if (!is.null(b$overallP)) say("  overall p: ", b$overallP)

# the CSVs the reply carries, saved beside the input
stem <- tools::file_path_sans_ext(file)
saveCsv <- function(txt, suffix) {
  if (is.null(txt) || !nzchar(txt)) return(invisible())
  out <- paste0(stem, "-", suffix, ".csv")
  writeLines(txt, out)
  say("  wrote ", out, " (", length(strsplit(txt, "\n")[[1]]) - 1L, " rows)")
}
saveCsv(b$templateCsv, "template")
saveCsv(b$resultsCsv, "results")
# journalTables: one CSV per trial, keyed by trial name (the reconstructed
# journal-style table, for comparison against the manuscript page)
if (length(b$journalTables)) {
  nms <- names(b$journalTables); if (is.null(nms)) nms <- paste0("trial", seq_along(b$journalTables))
  for (i in seq_along(b$journalTables))
    saveCsv(b$journalTables[[i]], paste0("journal-", gsub("[^A-Za-z0-9._-]", "_", nms[i])))
}
if (length(b$journalTablesOmitted) && nzchar(b$journalTablesOmitted[[1]]))
  say("  journal tables omitted: ", b$journalTablesOmitted[[1]])
quit(status = if (isTRUE(b$ok)) 0 else 1)
