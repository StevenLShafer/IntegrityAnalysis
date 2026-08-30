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

## ---- design filter -------------------------------------------------------
# WHY A FILTER IS NEEDED AT ALL, measured rather than assumed. An
# unfiltered run of 1,338 trials produced a p-value distribution that was
# uniform in the lower tail and middle but piled up near 1:
#
#   arms   n     p<0.05   p>0.95        (5% expected in each)
#   2      929    4.6%      8.8%
#   4+     218    4.6%     21.1%   <- median 0.685
#
# The cause, found by reading one of the worst cases (NCT03542149): it is
# a DOSE-ESCALATION study whose "arms" are Cohort 1 Groups A-D, Cohort 2
# Groups A-B, Cohort 3 Groups A-B, with 2 to 6 subjects each. Those
# cohorts were enrolled SEQUENTIALLY and were never randomized against
# one another - randomization happens within a cohort. Carlisle's method
# assumes every compared group came from ONE allocation, so comparing
# across cohorts guarantees more between-group variation than
# randomization predicts, and p goes to 1. Not fraud, and not a coding
# error: the wrong trials in the sample.
#
# NOTE WHAT DOES NOT CATCH IT. That study is labelled
# `interventionModel: PARALLEL` and `allocation: RANDOMIZED`. The
# structural design fields alone are not sufficient, which is why the
# group titles are inspected too.
#
# Set INTEGRITY_CTG_NOFILTER=1 to disable, which is how the before/after
# contrast above was produced.
ctgDesignVeto <- function(st) {
  dm <- tryCatch(st$protocolSection$designModule, error = function(e) NULL)
  di <- dm$designInfo %||% list()
  im <- toupper(di$interventionModel %||% "")
  # CROSSOVER compares periods, not independent arms; FACTORIAL,
  # SEQUENTIAL and SINGLE_GROUP are not one two-way allocation either.
  if (nzchar(im) && im != "PARALLEL")
    return(paste0("design: ", tolower(im)))
  ph <- unlist(dm$phases %||% list())
  if (any(toupper(ph) == "PHASE1"))
    return("phase 1 (dose escalation risk)")
  bm <- tryCatch(st$resultsSection$baselineCharacteristicsModule,
                 error = function(e) NULL)
  gt <- paste(vapply(bm$groups %||% list(), function(g) g$title %||% "", ""),
              collapse = " | ")
  # The direct signature of the failure above: groups named as cohorts,
  # parts or stages are enrolment strata, not co-randomized arms.
  if (grepl("(?i)\\bcohort\\b|dose[- ]escalat|\\bpart [0-9A-C]\\b|\\bstage [0-9]\\b",
            gt, perl = TRUE))
    return("groups are cohorts/parts, not co-randomized arms")
  ttl <- tryCatch(st$protocolSection$identificationModule$briefTitle %||% "",
                  error = function(e) "")
  # Cluster randomization inflates between-arm variation by design: the
  # unit of allocation is a clinic or village, not a patient, so arm
  # means differ more than individual randomization predicts. The
  # registry has no structured field for it, so the title is all there is.
  if (grepl("(?i)cluster[- ]?random", paste(ttl, gt), perl = TRUE))
    return("cluster randomized")
  NA_character_
}

## ---- map a baseline module onto the template ----------------------------
# Decimal places as PRINTED. The whole method rests on rounding simulated
# values exactly as the source rounded its own, and the registry stores
# these as strings, so the printed precision is recoverable rather than
# inferred.
# LENGTH-SAFE. Registry measurements routinely omit `value`, `spread`,
# `lowerLimit` or `upperLimit` for some arms, and JSON absence arrives as
# NULL. as.numeric(NULL) is numeric(0), and assigning that into a vector
# slot fails with "replacement has length zero" - which killed 17 of the
# first 25 studies tried. Return NA instead and let the completeness
# checks below decide whether the measure is usable.
decOf <- function(s) {
  if (is.null(s) || !length(s)) return(NA_integer_)
  s <- as.character(s)[1]
  if (is.na(s) || !grepl("[.]", s)) return(0L)
  nchar(sub("^[^.]*[.]", "", s))
}
numOf <- function(s) {
  if (is.null(s) || !length(s)) return(NA_real_)
  suppressWarnings(as.numeric(as.character(s)[1]))
}

ctgToTemplate <- function(st) {
  id <- tryCatch(st$protocolSection$identificationModule$nctId,
                 error = function(e) NA_character_)
  bm <- tryCatch(st$resultsSection$baselineCharacteristicsModule,
                 error = function(e) NULL)
  if (is.null(bm) || !length(bm$groups) || !length(bm$measures))
    return(list(trial = id, data = NULL, why = "no baseline module"))

  gid   <- vapply(bm$groups, function(g) g$id %||% "", "")
  gtitle <- vapply(bm$groups, function(g) g$title %||% "", "")

  # Arm sizes, and the Total detection that must not be skipped.
  n <- stats::setNames(rep(NA_real_, length(gid)), gid)
  if (length(bm$denoms)) {
    for (cnt in bm$denoms[[1]]$counts %||% list()) {
      g <- cnt$groupId
      if (is.null(g) || !(g %in% gid)) next   # never widen n by accident
      v <- numOf(cnt$value); if (!is.na(v)) n[[g]] <- v
    }
  }
  isTotal <- grepl("^\\s*total\\s*$", gtitle, ignore.case = TRUE)
  # Arithmetic check as well as the title: a group whose N equals the sum
  # of all the others is a total however it is labelled.
  for (k in seq_along(gid)) {
    others <- n[-k]
    if (!isTotal[k] && !is.na(n[k]) && all(!is.na(others)) && length(others) > 1 &&
        isTRUE(all.equal(unname(n[k]), sum(others)))) isTotal[k] <- TRUE
  }
  keep <- gid[!isTotal]
  if (length(gid) < 2)
    return(list(trial = id, data = NULL, why = "only one baseline group"))
  if (length(keep) < 2)
    return(list(trial = id, data = NULL, why = "all but one group looked like a Total"))

  rows <- list(); cats <- character(0)
  for (m in bm$measures) {
    title <- m$title %||% ""
    ptype <- toupper(m$paramType %||% "")
    dtype <- toupper(m$dispersionType %||% "")
    classes <- m$classes %||% list()
    if (!length(classes)) next

    if (ptype %in% c("MEAN", "MEDIAN")) {
      # One value per arm; take the first class/category (a continuous
      # measure that is broken into classes is a stratified table, not a
      # single row, and is skipped rather than flattened).
      cat1 <- (classes[[1]]$categories %||% list())
      if (length(cat1) != 1) next
      ms <- cat1[[1]]$measurements %||% list()
      val <- stats::setNames(rep(NA_real_, length(keep)), keep)
      spr <- val; lo <- val; hi <- val; dm <- val; ds <- val
      for (x in ms) {
        g <- x$groupId
        if (is.null(g) || !(g %in% keep)) next
        val[[g]] <- numOf(x$value);      dm[[g]] <- decOf(x$value)
        spr[[g]] <- numOf(x$spread);     ds[[g]] <- decOf(x$spread)
        lo[[g]]  <- numOf(x$lowerLimit); hi[[g]] <- numOf(x$upperLimit)
      }
      if (any(is.na(val)) || any(is.na(n[keep])) || any(is.na(dm))) next
      if (ptype == "MEAN" && dtype %in% c("STANDARD_DEVIATION", "STANDARD_ERROR")) {
        if (any(is.na(spr))) next
        d <- data.frame(TRIAL = id, ROW = title, N = unname(n[keep]),
                        MEAN = unname(val), SD = NA_real_, SE = NA_real_,
                        Q1 = NA_real_, Q3 = NA_real_,
                        ROUND_MEAN = unname(dm), ROUND_DISPERSION = unname(ds),
                        ROUND_OBSERVATION = unname(dm),
                        stringsAsFactors = FALSE)
        if (dtype == "STANDARD_DEVIATION") d$SD <- unname(spr) else d$SE <- unname(spr)
        rows[[length(rows) + 1]] <- d
      } else if (ptype == "MEDIAN" &&
                 dtype %in% c("INTER_QUARTILE_RANGE", "INTERQUARTILE_RANGE")) {
        if (any(is.na(lo)) || any(is.na(hi))) next
        rows[[length(rows) + 1]] <- data.frame(
          TRIAL = id, ROW = title, N = unname(n[keep]), MEAN = unname(val),
          SD = NA_real_, SE = NA_real_, Q1 = unname(lo), Q3 = unname(hi),
          ROUND_MEAN = unname(dm), ROUND_DISPERSION = NA_real_,
          ROUND_OBSERVATION = unname(dm), stringsAsFactors = FALSE)
      }
      next
    }

    if (ptype %in% c("COUNT_OF_PARTICIPANTS", "NUMBER")) {
      cat1 <- (classes[[1]]$categories %||% list())
      if (length(cat1) < 2) next            # nothing to cross-tabulate
      lvl <- vapply(cat1, function(c) c$title %||% "", "")
      if (any(!nzchar(lvl)) || anyDuplicated(lvl)) next
      counts <- matrix(NA_real_, nrow = length(keep), ncol = length(cat1),
                       dimnames = list(keep, lvl))
      for (j in seq_along(cat1))
        for (x in (cat1[[j]]$measurements %||% list()))
          if (!is.null(x$groupId) && x$groupId %in% keep)
            counts[x$groupId, j] <- numOf(x$value)
      if (any(is.na(counts))) next
      colnames(counts) <- paste(title, lvl, sep = ": ")
      d <- data.frame(TRIAL = id, ROW = title, N = NA_real_, MEAN = NA_real_,
                      SD = NA_real_, SE = NA_real_, Q1 = NA_real_, Q3 = NA_real_,
                      ROUND_MEAN = NA_real_, ROUND_DISPERSION = NA_real_,
                      ROUND_OBSERVATION = NA_real_, stringsAsFactors = FALSE)
      d <- cbind(d, as.data.frame(counts, check.names = FALSE))
      cats <- union(cats, colnames(counts))
      rows[[length(rows) + 1]] <- d
    }
  }
  if (!length(rows)) return(list(trial = id, data = NULL, why = "no usable measures"))

  allCols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(d) {
    for (cc in setdiff(allCols, names(d))) d[[cc]] <- NA_real_
    d[, allCols, drop = FALSE]
  })
  list(trial = id, data = do.call(rbind, rows), cats = cats, why = NA_character_)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

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
