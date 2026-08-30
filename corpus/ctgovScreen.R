# ctgovScreen.R - run the integrity analysis on ClinicalTrials.gov
# posted results, with no PDF and no parser in the loop.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's suggestion: "Trials registered with clinicaltrials.gov often    #
# have results reported. Indeed, reporting within 1 year of trial          #
# completion is compulsory. We could use posted results as ground truth."  #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY THIS IS DIFFERENT FROM EVERY OTHER CORPUS ROUTE. medRxiv, Europe     #
# PMC, PMC-OA and the rest are sources of PDFs: they grow the INPUT of a   #
# pipeline whose ground truth stays fixed at Carlisle's 5,088 hand-entered #
# trials. This grows the GROUND TRUTH, and it arrives already structured.  #
#                                                                          #
#   47,814  randomized interventional studies with posted results          #
#    5,088  trials in Carlisle's One Sheet                                 #
#                                                                          #
# A posted baseline module states exactly what P_Calc needs, and states it #
# rather than implying it:                                                 #
#                                                                          #
#   MEASURE: Age, Continuous  [paramType=MEAN,                             #
#                              dispersionType=STANDARD_DEVIATION]          #
#      group=BG000 value=62.2 spread=6.8                                   #
#      group=BG001 value=62.2 spread=6.8                                   #
#   denoms: BG000=5128  BG001=5123                                         #
#                                                                          #
# Note what is DECLARED here that a PDF only implies. The parser has to    #
# infer SD-versus-SE from a footnote and guess whether a bracketed pair is #
# an IQR or a range; dispersionType says so outright. There is no          #
# misparse risk on this path because there is no parse.                    #
#                                                                          #
# THE THREE USES, in increasing ambition:                                  #
#   1. Corroboration at scale - any paper linked to an NCT with results    #
#      becomes scoreable, across every specialty rather than anesthesia.   #
#   2. A second independent ground truth to cross-check Carlisle.          #
#   3. THIS SCRIPT: screen the registry directly. Under honest reporting   #
#      the per-trial p-values should be near-uniform; a deficit of large   #
#      p-values or an excess of small ones is a finding about the          #
#      literature, not about our parser.                                   #
#                                                                          #
# WHAT IS DELIBERATELY DROPPED, and why it would corrupt the analysis:     #
#                                                                          #
#   * The "Total" pseudo-arm. Registries routinely publish a Total column  #
#     alongside the real arms. It is not an independent group - it is      #
#     their sum - and treating it as one would compare a trial against     #
#     itself and manufacture agreement. Detected by title AND by the       #
#     arithmetic (its N equals the sum of the others).                     #
#   * Measures where the arms disagree on which groups reported. P_Calc    #
#     needs every arm of a row populated.                                  #
#   * Single-arm measures. Nothing to compare.                             #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/ctgovScreen.R [nTrials] [outCsv]                        #
#     nTrials  how many studies to fetch and analyse (default 200)         #
#     outCsv   per-trial results (default .NewCarlisle/ctgov/ctgov.csv)    #
#                                                                          #
#   INTEGRITY_SNAPSHOT_LIB should point at a library built by              #
#   `R CMD INSTALL --library=<dir> .` - same discipline as every other     #
#   number this project defends.                                           #
############################################################################

suppressPackageStartupMessages({ library(jsonlite) })

root   <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
outDir <- file.path(root, ".NewCarlisle", "ctgov")
dir.create(outDir, recursive = TRUE, showWarnings = FALSE)

args    <- commandArgs(trailingOnly = TRUE)
nTrials <- if (length(args) >= 1) as.integer(args[1]) else 200L
outCsv  <- if (length(args) >= 2) args[2] else file.path(outDir, "ctgov.csv")

# Snapshot library, on .libPaths() so anything spawned inherits it - the
# 2026-08-29 lesson (PR #115): lib.loc alone reaches only this process.
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
if (!requireNamespace("IntegrityAnalysis", quietly = TRUE))
  stop("IntegrityAnalysis is not installed in ",
       if (nzchar(libDir)) libDir else "THIS R's library path",
       " - install it first (R CMD INSTALL --library=<dir> .)", call. = FALSE)
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis); library(shiny); library(foreach)
  library(MBESS); library(Rfast); library(dqrng)
}))
cat("engine: version",
    as.character(utils::packageVersion("IntegrityAnalysis")), "\n")

## ---- fetch ---------------------------------------------------------------
API <- "https://clinicaltrials.gov/api/v2/studies"

ctgFetch <- function(want) {
  got <- list(); token <- NULL
  fields <- paste("protocolSection.identificationModule.nctId",
                  "protocolSection.identificationModule.briefTitle",
                  "protocolSection.designModule",
                  "resultsSection.baselineCharacteristicsModule", sep = ",")
  while (length(got) < want) {
    url <- paste0(API, "?aggFilters=results:with,studyType:int",
                  "&query.term=", utils::URLencode("AREA[DesignAllocation]RANDOMIZED",
                                                   reserved = TRUE),
                  "&fields=", fields,
                  "&pageSize=100",
                  if (!is.null(token)) paste0("&pageToken=", token) else "")
    pg <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                   error = function(e) NULL)
    if (is.null(pg) || !length(pg$studies)) break
    got <- c(got, pg$studies)
    token <- pg$nextPageToken
    if (is.null(token)) break
    cat("\r  fetched", length(got), "study record(s)")
  }
  cat("\n")
  utils::head(got, want)
}

source(file.path(dirname(sub("--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[1])), "ctgovMap.R"))


## ---- run -----------------------------------------------------------------
cat("fetching", nTrials, "randomized interventional trial(s) with results\n")
studies <- ctgFetch(nTrials)
cat("got", length(studies), "study record(s)\n\n")

useFilter <- !identical(Sys.getenv("INTEGRITY_CTG_NOFILTER"), "1")
cat("design filter:",
    if (useFilter) "ON" else "OFF (INTEGRITY_CTG_NOFILTER=1)", "\n\n")

res <- list(); skipped <- character(0); vetoed <- character(0)
for (i in seq_along(studies)) {
  if (useFilter) {
    v <- tryCatch(ctgDesignVeto(studies[[i]]), error = function(e) NA_character_)
    if (!is.na(v)) { vetoed <- c(vetoed, v); next }
  }
  m <- tryCatch(ctgToTemplate(studies[[i]]),
                error = function(e) list(trial = NA, data = NULL,
                                         why = conditionMessage(e)))
  if (is.null(m$data)) { skipped <- c(skipped, m$why %||% "unknown"); next }
  p <- tryCatch({
    set.seed(1); dqrng::dqset.seed(1)
    # P_Calc narrates to stdout; keep this run's log readable.
    utils::capture.output(
      pp <- IntegrityAnalysis:::P_Calc(m$trial, m$data, m$cats, 100000))
    pp
  }, error = function(e) NULL)
  if (is.null(p)) { skipped <- c(skipped, "P_Calc error"); next }
  summ <- p[!is.na(p$ROW) & p$ROW == "Summary", , drop = FALSE]
  res[[length(res) + 1]] <- data.frame(
    NCT = m$trial, ROWS = length(unique(m$data$ROW)),
    ARMS = sum(m$data$ROW == m$data$ROW[1]),
    P = if (nrow(summ)) suppressWarnings(as.numeric(summ$P[1])) else NA_real_,
    stringsAsFactors = FALSE)
  cat("\r  analysed", length(res), "trial(s)")
}
cat("\n\n")

out <- if (length(res)) do.call(rbind, res) else
  data.frame(NCT = character(), ROWS = integer(), ARMS = integer(), P = numeric())
utils::write.csv(out, outCsv, row.names = FALSE)

cat("=============== CLINICALTRIALS.GOV BASELINE SCREEN ===============\n")
cat("studies fetched :", length(studies), "\n")
cat("design-vetoed   :", length(vetoed), "\n")
if (length(vetoed)) {
  tv <- sort(table(vetoed), decreasing = TRUE)
  for (k in seq_along(tv)) cat(sprintf("    %-46s %d\n", names(tv)[k], tv[k]))
}
cat("analysed        :", nrow(out), "\n")
cat("skipped         :", length(skipped), "\n")
if (length(skipped)) {
  tb <- sort(table(skipped), decreasing = TRUE)
  for (k in seq_along(tb)) cat(sprintf("    %-28s %d\n", names(tb)[k], tb[k]))
}
pv <- out$P[!is.na(out$P)]
if (length(pv)) {
  cat("\np-values:", length(pv), "\n")
  cat("  deciles :", paste(sprintf("%.3f", stats::quantile(pv, seq(0, 1, 0.1))),
                           collapse = " "), "\n")
  # Under honest reporting these should be near-uniform. Report the
  # tails rather than a single test: an excess of SMALL p is excessive
  # homogeneity (the Carlisle signal), a deficit is over-dispersion.
  cat(sprintf("  p < 0.01 : %d (%.1f%%)   expected ~1%%\n",
              sum(pv < 0.01), 100 * mean(pv < 0.01)))
  cat(sprintf("  p < 0.05 : %d (%.1f%%)   expected ~5%%\n",
              sum(pv < 0.05), 100 * mean(pv < 0.05)))
  cat(sprintf("  p > 0.95 : %d (%.1f%%)   expected ~5%%\n",
              sum(pv > 0.95), 100 * mean(pv > 0.95)))
  ks <- suppressWarnings(stats::ks.test(pv, "punif"))
  cat(sprintf("  KS vs uniform: D = %.4f, p = %.4g\n",
              unname(ks$statistic), ks$p.value))
}
cat("\nper-trial results written to", outCsv, "\n")
