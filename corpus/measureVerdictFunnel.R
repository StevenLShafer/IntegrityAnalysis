# measureVerdictFunnel.R - of the documents where the parser wrongly
# produced a table, how many would have reached the EDITOR as a verdict?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction. LOCAL CORPUS TOOLING ONLY - nothing here ships.      #
#                                                                          #
# WHAT THIS ADDS TO measureFalsePositives.R. That script established that  #
# the parser returns a baseline table for 42.5% of trial protocols -       #
# documents that cannot contain one for their own trial. AI adjudication   #
# then found 91.8% of those are genuine parser defects (the remaining      #
# 5.5% are real baseline tables quoted from PRIOR studies, and none        #
# claimed to describe the protocol's own population).                      #
#                                                                          #
# But "the parser emitted rows" is not the number that matters. Between a  #
# parse and a verdict stands validateData(), which checks the template     #
# contract and refuses malformed input, and then P_Calc, which needs       #
# arms and usable rows. THE OPERATIONAL QUESTION is how many of these      #
# reach an editor as a confident p-value computed from nonsense - and      #
# that is a strictly smaller number than 42.5%.                            #
#                                                                          #
# A refusal here is a SAFE failure: the editor sees red cells and fixes    #
# them, or is told the file cannot be analysed. A verdict is the           #
# dangerous one, because it looks exactly like a real answer.              #
#                                                                          #
# THE FUNNEL, each stage a gate the wrong answer must pass:                #
#   documents tested                                                       #
#     -> parser returned a table          (measured: 42.5%)                #
#       -> validateData accepted it       (measured here)                  #
#         -> P_Calc produced a p-value    (measured here)                  #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/measureVerdictFunnel.R [docDir] [n]                     #
############################################################################

args   <- commandArgs(trailingOnly = TRUE)
docDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_docs")
maxN   <- if (length(args) >= 2) as.integer(args[2]) else 0L

root   <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
fpCsv  <- file.path(root, ".NewCarlisle", "falsepos", "falsePositives.csv")
outCsv <- file.path(root, ".NewCarlisle", "falsepos", "verdictFunnel.csv")

libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis)
  # shiny is not optional: validateData() calls isolate().
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng); library(openxlsx)
}))
cat("engine:", as.character(utils::packageVersion("IntegrityAnalysis")), "\n")
source(file.path(root, "corpus", "parallelHelper.R"))

if (!file.exists(fpCsv))
  stop("no falsePositives.csv - run corpus/measureFalsePositives.R first",
       call. = FALSE)
fp <- utils::read.csv(fpCsv, stringsAsFactors = FALSE)
fp <- fp[fp$ROWS > 0, , drop = FALSE]
if (maxN > 0) fp <- utils::head(fp, maxN)
pdfs <- file.path(docDir, fp$PDF)
pdfs <- pdfs[file.exists(pdfs)]
cat("documents where the parser produced a table:", length(pdfs), "\n\n")

batch  <- 25L
starts <- seq(1, length(pdfs), by = batch)
one <- function(start) {
  idx <- start:min(start + batch - 1L, length(pdfs))
  res <- parseBaselineTableFiles(pdfs[idx], ai = "never", timeout = 120,
                                 quiet = TRUE)
  out <- list()
  for (k in seq_along(idx)) {
    r <- res$result[[k]]
    rows <- if (inherits(r, "ParsePDFTable") && !is.null(r$data))
      nrow(r$data) else 0L
    accepted <- NA; verdict <- NA_character_; why <- ""
    if (rows > 0) {
      # The app's own gate. validateData is INTERNAL (@noRd), like
      # P_Calc, so it needs ::: - calling it unqualified fails with
      # "could not find function", and the first version of this script
      # caught that error and recorded it as a REFUSAL. Every one of 25
      # documents then looked safely rejected, which would have supported
      # the headline "no false positive ever reaches a verdict" from a
      # technical failure wearing a result's clothing.
      #
      # So errors and refusals are now recorded SEPARATELY. A crash in
      # the gate is not evidence that the gate works.
      v <- tryCatch(IntegrityAnalysis:::validateData(r$data),
                    error = function(e)
                      structure(list(msg = conditionMessage(e)),
                                class = "gateError"))
      if (inherits(v, "gateError")) {
        accepted <- NA                       # unknown, NOT a refusal
        why <- paste("GATE ERROR:", v$msg)
      } else {
        accepted <- !isTRUE(v$FAIL)
        if (!accepted) why <- "refused"
      }
      if (accepted && !is.null(v$DATA)) {
        p <- tryCatch({
          set.seed(1); dqrng::dqset.seed(1)
          utils::capture.output(x <- IntegrityAnalysis:::P_Calc(
            v$DATA$TRIAL[1], v$DATA, v$CategoryNames, 100000))
          s <- x[!is.na(x$ROW) & x$ROW == "Summary", , drop = FALSE]
          if (nrow(s)) as.character(s$P[1]) else NA_character_
        }, error = function(e) NA_character_)
        verdict <- p
      }
    }
    out[[length(out) + 1L]] <- data.frame(
      PDF = basename(pdfs[idx][k]), ROWS = rows,
      VALIDATED = accepted, VERDICT = verdict,
      WHY = substr(why, 1, 120), stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

chunks <- iaParallel(starts, one, export = c("pdfs", "batch"), seed = 1L,
                     libDir = if (nzchar(libDir)) libDir else NULL)
res <- do.call(rbind, Filter(Negate(is.null), chunks))
utils::write.csv(res, outCsv, row.names = FALSE)

parsed <- sum(res$ROWS > 0)
ok     <- sum(isTRUE(res$VALIDATED) | res$VALIDATED %in% TRUE, na.rm = TRUE)
verd   <- sum(!is.na(res$VERDICT) & nzchar(res$VERDICT))
cat("\n================ THE VERDICT FUNNEL ================\n")
cat(sprintf("  parser returned a table   : %4d\n", parsed))
cat(sprintf("  validateData ACCEPTED it  : %4d  (%.1f%% of parsed)\n",
            ok, if (parsed) 100 * ok / parsed else 0))
cat(sprintf("  P_Calc produced a VERDICT : %4d  (%.1f%% of parsed)\n",
            verd, if (parsed) 100 * verd / parsed else 0))
cat("\n  A refusal is a SAFE failure - the editor sees red cells.\n")
cat("  A verdict on a document with no baseline table is the dangerous\n")
cat("  outcome, because it is indistinguishable from a real answer.\n")
if (verd) {
  v <- suppressWarnings(as.numeric(res$VERDICT[!is.na(res$VERDICT)]))
  v <- v[!is.na(v)]
  if (length(v))
    cat(sprintf("\n  of those verdicts: %d had p < 0.05 (a FALSE ALARM)\n",
                sum(v < 0.05)))
}
cat("\nper-document results:", outCsv, "\n")
