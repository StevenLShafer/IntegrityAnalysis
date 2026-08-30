# downloadCtgovDocs.R - fetch trial protocol / SAP PDFs from
# ClinicalTrials.gov as PARSER STRESS-TEST material.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request, after he asked whether ClinicalTrials.gov hosts actual #
# manuscripts. It does not - but it hosts something else useful.           #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHAT IS THERE, AND WHAT IS NOT. Sponsors upload documents under a closed #
# vocabulary: Prot, SAP, Prot_SAP, ICF (and combinations). There is no     #
# manuscript type - FDAAA compels the protocol and the statistical         #
# analysis plan, not the paper, and publications are referenced by PMID    #
# rather than hosted. Measured 2026-08-29:                                 #
#                                                                          #
#   51,429  studies with a protocol                                        #
#   48,000  studies with a statistical analysis plan                       #
#   16,294  studies with a consent form                                    #
#                                                                          #
# SO WHY DOWNLOAD THEM. Not for corroboration: a protocol is written       #
# BEFORE the trial reports, so it has no baseline table to check a parse   #
# against. They are worth having because they are HARD, FREE and LEGALLY   #
# CLEAN input for the parser:                                              #
#                                                                          #
#   * Word-to-PDF exports from hundreds of sponsors, not journal           #
#     typesetting - the layouts are far more varied and far worse than     #
#     the anesthesia journals the corpus is built from.                    #
#   * Dense with tables the parser was never tuned on: schedules of        #
#     assessment, sample-size tables, dose-modification grids.             #
#   * Public US government documents, served from a CDN with no            #
#     credentials and no egress charge - unlike the requester-pays         #
#     medRxiv bucket, this costs nothing at any volume.                    #
#                                                                          #
# The value is finding where the parser BREAKS. A table-heavy document     #
# with no baseline table is exactly the input that should produce a clean  #
# refusal rather than a confident wrong answer, and nothing in the corpus  #
# currently tests that.                                                    #
#                                                                          #
# CONSENT FORMS ARE SKIPPED by default. They carry patient-facing material #
# and no analytic tables, so they are all cost and no signal.              #
#                                                                          #
# POLITE BY CONSTRUCTION: one request at a time with a pause between, and  #
# a manifest so an interrupted run resumes instead of re-fetching. This is #
# a public service paid for by someone else; the courtesy is the point.    #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/downloadCtgovDocs.R [maxDocs] [outDir] [pauseSec]       #
#     maxDocs   how many PDFs to end up with (default 500)                 #
#     outDir    default <INTEGRITY_WORK>/ctgov_docs                        #
#     pauseSec  delay between downloads (default 0.5)                      #
############################################################################

suppressPackageStartupMessages({ library(jsonlite) })

args     <- commandArgs(trailingOnly = TRUE)
maxDocs  <- if (length(args) >= 1) as.integer(args[1]) else 500L
outDir   <- if (length(args) >= 2) args[2] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_docs")
pauseSec <- if (length(args) >= 3) as.numeric(args[3]) else 0.5

dir.create(outDir, recursive = TRUE, showWarnings = FALSE)
manPath <- file.path(outDir, "docManifest.csv")
man <- if (file.exists(manPath))
  utils::read.csv(manPath, colClasses = "character") else
  data.frame(nct = character(), type = character(), file = character(),
             bytes = character(), date = character(), stringsAsFactors = FALSE)
saveMan <- function() utils::write.csv(man, manPath, row.names = FALSE)

cat("target", maxDocs, "PDF(s) in", outDir, "\n")
cat("already have", nrow(man), "\n\n")

## ---- list candidates -----------------------------------------------------
API <- "https://clinicaltrials.gov/api/v2/studies"
# docs:prot is the broadest document filter; the type is read per document
# below, so SAP-only studies arrive too when they carry a protocol.
listDocs <- function(want) {
  out <- list(); token <- NULL
  while (length(out) < want) {
    url <- paste0(API, "?aggFilters=docs:prot",
                  "&fields=protocolSection.identificationModule.nctId,documentSection",
                  "&pageSize=200",
                  if (!is.null(token)) paste0("&pageToken=", token) else "")
    pg <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                   error = function(e) NULL)
    if (is.null(pg) || !length(pg$studies)) break
    for (st in pg$studies) {
      nct <- tryCatch(st$protocolSection$identificationModule$nctId,
                      error = function(e) NULL)
      if (is.null(nct)) next
      docs <- tryCatch(st$documentSection$largeDocumentModule$largeDocs,
                       error = function(e) NULL)
      for (d in docs %||% list()) {
        ty <- d$typeAbbrev %||% ""
        # Consent forms only - no analytic tables, patient-facing text.
        if (identical(ty, "ICF")) next
        fn <- d$filename %||% ""
        if (!nzchar(fn)) next
        out[[length(out) + 1]] <- list(nct = nct, type = ty, file = fn)
      }
    }
    token <- pg$nextPageToken
    if (is.null(token)) break
    cat("\r  listed", length(out), "document(s)")
  }
  cat("\n")
  out
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- fetch ---------------------------------------------------------------
# The CDN path buries each study under the LAST TWO DIGITS of its NCT
# number: .../large-docs/56/NCT03348956/Prot_SAP_000.pdf
docUrl <- function(nct, file)
  sprintf("https://cdn.clinicaltrials.gov/large-docs/%s/%s/%s",
          substr(nct, nchar(nct) - 1, nchar(nct)), nct, file)

need <- maxDocs - nrow(man)
if (need <= 0) {
  cat("already at target\n")
} else {
  cands <- listDocs(need * 2L)     # over-list: some fetches will fail
  have  <- paste(man$nct, man$file)
  got <- 0L; failed <- 0L
  for (d in cands) {
    if (got >= need) break
    key <- paste(d$nct, d$file)
    if (key %in% have) next
    dst <- file.path(outDir, paste0(d$nct, "_", d$file))
    if (!file.exists(dst)) {
      ok <- tryCatch({
        utils::download.file(docUrl(d$nct, d$file), dst, mode = "wb",
                             quiet = TRUE)
        file.exists(dst) && file.size(dst) > 1000
      }, error = function(e) FALSE, warning = function(w) FALSE)
      if (!ok) { unlink(dst); failed <- failed + 1L; next }
    }
    man <- rbind(man, data.frame(nct = d$nct, type = d$type, file = d$file,
                                 bytes = as.character(file.size(dst)),
                                 date = format(Sys.Date()),
                                 stringsAsFactors = FALSE))
    got <- got + 1L
    if (got %% 25L == 0L) { saveMan(); cat("\r  downloaded", got, "of", need) }
    Sys.sleep(pauseSec)
  }
  saveMan(); cat("\n")
  cat("downloaded", got, "new PDF(s);", failed, "fetch failure(s)\n")
}

## ---- report --------------------------------------------------------------
pdfs <- list.files(outDir, pattern = "[.]pdf$", full.names = TRUE)
cat("\n=============== CTGOV DOCUMENT CORPUS ===============\n")
cat("PDFs on disk :", length(pdfs), "\n")
if (length(pdfs)) {
  sz <- file.size(pdfs)
  cat(sprintf("total size   : %.2f GB (median %.1f MB)\n",
              sum(sz) / 1024^3, stats::median(sz) / 1024^2))
}
if (nrow(man)) {
  cat("by type:\n")
  tb <- sort(table(man$type), decreasing = TRUE)
  for (k in seq_along(tb)) cat(sprintf("    %-14s %d\n", names(tb)[k], tb[k]))
  cat("distinct trials:", length(unique(man$nct)), "\n")
}
cat("manifest     :", manPath, "\n")
