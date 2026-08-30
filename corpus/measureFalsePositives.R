# measureFalsePositives.R - how often does the parser return a baseline
# table from a document that cannot contain one?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request. LOCAL CORPUS TOOLING ONLY - nothing here ships.        #
#                                                                          #
# THE GAP THIS FILLS. Every existing measurement asks how OFTEN the parser #
# succeeds (parse rate, 84.9%) or how RIGHT it is when it does             #
# (corroboration, 44.8%). None asks what it does when handed a document    #
# with no baseline table at all. That is not a hypothetical: an editor     #
# uploads the protocol instead of the paper, or the supplement, or the     #
# wrong article. A confident answer computed from the wrong table is the   #
# failure mode this project exists to prevent, and it has never been       #
# measured.                                                                #
#                                                                          #
# WHY PROTOCOLS ARE THE RIGHT PROBE. A trial protocol is written BEFORE    #
# the trial runs, so it cannot contain baseline characteristics of the     #
# enrolled population. GROUND TRUTH IS KNOWN BY CONSTRUCTION: the correct  #
# output is nothing, for every file, with no adjudication needed. That is  #
# rare and worth exploiting. ClinicalTrials.gov hosts 51,429 of them free  #
# (corpus/downloadCtgovDocs.R).                                            #
#                                                                          #
# WHAT A FALSE POSITIVE LOOKS LIKE, from the first 15 tried: one protocol  #
# yielded weight, length and head circumference with means and SDs - real  #
# numbers, but from a PREVIOUSLY PUBLISHED study quoted in the background  #
# section to justify the new trial. The row labels carried the give-away,  #
# prose spliced from the surrounding paragraph:                            #
#                                                                          #
#   "incidence of microcephaly between groups. Over twice as weight"       #
#                                                                          #
# A variable name does not contain a sentence boundary. That is a cheap    #
# heuristic the parser does not currently apply, and this script exists to #
# say whether it would be worth applying.                                  #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/measureFalsePositives.R [docDir] [nSample]              #
#     docDir   directory of PDFs (default <INTEGRITY_WORK>/ctgov_docs)     #
#     nSample  how many to test, 0 = all (default 600)                     #
############################################################################

args    <- commandArgs(trailingOnly = TRUE)
docDir  <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_docs")
nSample <- if (length(args) >= 2) as.integer(args[2]) else 600L

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
outDir <- file.path(root, ".NewCarlisle", "falsepos")
dir.create(outDir, recursive = TRUE, showWarnings = FALSE)
outCsv <- file.path(outDir, "falsePositives.csv")

libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
if (!requireNamespace("IntegrityAnalysis", quietly = TRUE))
  stop("IntegrityAnalysis is not installed in ",
       if (nzchar(libDir)) libDir else "THIS R's library path", call. = FALSE)
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis); library(shiny); library(foreach)
  library(MBESS); library(Rfast); library(dqrng); library(openxlsx)
}))
cat("engine: version",
    as.character(utils::packageVersion("IntegrityAnalysis")), "\n")
source(file.path(root, "corpus", "parallelHelper.R"))

pdfs <- list.files(docDir, pattern = "[.]pdf$", full.names = TRUE)
cat("documents available:", length(pdfs), "\n")
if (!length(pdfs)) stop("no PDFs in ", docDir, call. = FALSE)
set.seed(1)
if (nSample > 0 && nSample < length(pdfs))
  pdfs <- sort(sample(pdfs, nSample))
cat("testing:", length(pdfs), "\n\n")

# Batched exactly like measureMisparse: each worker parses its own slice
# through the subprocess batcher and returns rows; the parent writes.
batch  <- 25L
starts <- seq(1, length(pdfs), by = batch)
scoreBatch <- function(start) {
  idx <- start:min(start + batch - 1L, length(pdfs))
  res <- parseBaselineTableFiles(pdfs[idx], ai = "never", timeout = 120,
                                 quiet = TRUE)
  out <- list()
  for (k in seq_along(idx)) {
    r <- res$result[[k]]
    rows <- if (inherits(r, "ParsePDFTable") && !is.null(r$data))
      nrow(r$data) else 0L
    # A row label containing a sentence boundary is prose, not a variable
    # name - the signature of a table lifted out of flowing text.
    prosey <- 0L
    if (rows > 0 && !is.null(r$data$ROW))
      prosey <- sum(grepl("[.] [A-Za-z]|[a-z]{4,} [a-z]{4,} [a-z]{4,}",
                          as.character(r$data$ROW)))
    out[[length(out) + 1L]] <- data.frame(
      PDF = basename(pdfs[idx][k]), ROWS = rows,
      PROSEY_LABELS = prosey,
      PAGE = if (rows > 0 && !is.null(r$pages)) as.character(r$pages[1]) else NA,
      stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

chunks <- iaParallel(starts, scoreBatch, export = c("pdfs", "batch"),
                     seed = 1L, libDir = if (nzchar(libDir)) libDir else NULL)
res <- do.call(rbind, Filter(Negate(is.null), chunks))
utils::write.csv(res, outCsv, row.names = FALSE)

fp <- sum(res$ROWS > 0)
cat("\n============ PARSER FALSE-POSITIVE RATE ============\n")
cat("documents tested        :", nrow(res), "\n")
cat("correctly returned NOTHING:", sum(res$ROWS == 0), "\n")
cat(sprintf("FALSE POSITIVES         : %d (%.1f%%)\n", fp, 100 * fp / nrow(res)))
cat("  (a protocol cannot contain a baseline table; every extraction\n")
cat("   is the parser confidently answering a question with no answer)\n")
if (fp) {
  cat(sprintf("\n  rows extracted: median %d, max %d\n",
              as.integer(stats::median(res$ROWS[res$ROWS > 0])),
              max(res$ROWS)))
  withProse <- sum(res$PROSEY_LABELS > 0 & res$ROWS > 0)
  cat(sprintf("  of those, with PROSE in a row label: %d (%.0f%%)\n",
              withProse, 100 * withProse / fp))
  cat("  -> that fraction is what a sentence-boundary guard could catch\n")
}
cat("\nper-document results:", outCsv, "\n")
