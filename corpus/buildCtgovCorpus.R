# buildCtgovCorpus.R - archive every ClinicalTrials.gov baseline table.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request: "can we build a corpus of all 50K baseline data tables #
# in clinicaltrials.gov ... it might even be a publishable paper."         #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHAT THIS IS. 47,814 randomized interventional trials have posted        #
# results, each with a structured baseline module. Fetched with only the   #
# fields needed, that is about 0.21 GB of JSON and roughly twelve minutes  #
# of API calls - the cheapest large corpus this project has ever had, and  #
# the only one that needs no parsing at all.                               #
#                                                                          #
# For comparison: Carlisle's One Sheet covers 5,088 trials in eight        #
# anaesthesia journals, hand-entered. This is ten times that, across every #
# specialty, with design metadata attached, at no cost.                    #
#                                                                          #
# TWO PHASES, DELIBERATELY SEPARATE:                                       #
#                                                                          #
#   Phase 1 (network)  -> raw.ndjson, one study per line, exactly as the   #
#     registry returned it. This is the ARCHIVE. It is never rewritten by  #
#     a mapping change, so a result can always be traced back to the bytes #
#     that produced it.                                                    #
#   Phase 2 (local)    -> the mapped CSVs. These are DERIVED and entirely  #
#     regenerable: `--map-only` rebuilds them from the archive without     #
#     touching the network. When the mapping improves - and it will, the   #
#     upper-tail anomaly is unexplained - the corpus does not need         #
#     re-fetching, and the old and new mappings can be diffed against the  #
#     same input.                                                          #
#                                                                          #
# That separation is the whole reason to store both. A corpus intended to  #
# support a publication has to answer "where did this number come from",   #
# and a single derived table cannot.                                       #
#                                                                          #
# THE MAPPING IS NOT DEFINED HERE. It lives in corpus/ctgovMap.R and is    #
# shared with ctgovScreen.R, so the archive and the screen cannot drift.   #
#                                                                          #
# OUTPUT                                                                   #
#   raw.ndjson               the archive, one study per line               #
#   trials.csv               one row per trial: design, arms, veto, status #
#   baselineContinuous.csv   TRIAL, ROW, ARM, N, MEAN, SD, SE, Q1, Q3, and #
#                            the printed-precision columns                 #
#   baselineCategorical.csv  TRIAL, ROW, ARM, CATEGORY, COUNT              #
#                                                                          #
# Long format, not the wide template: category columns differ from trial   #
# to trial, so a single wide table would be enormous and mostly empty.     #
# Reshaping back is trivial; the reverse is not.                           #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/buildCtgovCorpus.R [maxStudies] [outDir] [--map-only]   #
#     maxStudies  0 = everything (default 0)                               #
#     outDir      default <INTEGRITY_WORK>/ctgov_corpus                    #
############################################################################

suppressPackageStartupMessages({ library(jsonlite) })

args    <- commandArgs(trailingOnly = TRUE)
mapOnly <- any(args == "--map-only")
args    <- args[args != "--map-only"]
maxN    <- if (length(args) >= 1) as.integer(args[1]) else 0L
outDir  <- if (length(args) >= 2) args[2] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
dir.create(outDir, recursive = TRUE, showWarnings = FALSE)

scriptDir <- dirname(sub("--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
source(file.path(scriptDir, "ctgovMap.R"))

rawPath   <- file.path(outDir, "raw.ndjson")
tokenPath <- file.path(outDir, "nextPageToken.txt")
API <- "https://clinicaltrials.gov/api/v2/studies"

## ---- phase 1: archive ----------------------------------------------------
if (!mapOnly) {
  fields <- paste("protocolSection.identificationModule.nctId",
                  "protocolSection.identificationModule.briefTitle",
                  "protocolSection.designModule",
                  "protocolSection.sponsorCollaboratorsModule.leadSponsor",
                  "protocolSection.statusModule.startDateStruct",
                  "resultsSection.baselineCharacteristicsModule", sep = ",")
  # Resume from a saved token: 479 pages over a public API will hit a
  # hiccup eventually, and re-fetching from zero is rude as well as slow.
  token <- if (file.exists(tokenPath)) readLines(tokenPath, warn = FALSE)[1] else NA
  if (is.na(token) || !nzchar(token)) token <- NULL
  if (is.null(token) && file.exists(rawPath)) unlink(rawPath)
  have <- if (file.exists(rawPath))
    length(readLines(rawPath, warn = FALSE)) else 0L
  cat("archiving to", rawPath, "\n")
  cat("already have", have, "study record(s)\n\n")
  con <- file(rawPath, open = "a", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  repeat {
    if (maxN > 0 && have >= maxN) break
    url <- paste0(API, "?aggFilters=results:with,studyType:int",
                  "&query.term=",
                  utils::URLencode("AREA[DesignAllocation]RANDOMIZED",
                                   reserved = TRUE),
                  "&fields=", fields, "&pageSize=100",
                  if (!is.null(token)) paste0("&pageToken=", token) else "")
    pg <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
                   error = function(e) NULL)
    if (is.null(pg) || !length(pg$studies)) break
    for (st in pg$studies)
      writeLines(jsonlite::toJSON(st, auto_unbox = TRUE, null = "null"), con)
    have <- have + length(pg$studies)
    token <- pg$nextPageToken
    writeLines(if (is.null(token)) "" else token, tokenPath)
    cat("\r  archived", have, "study record(s)")
    if (is.null(token)) break
    Sys.sleep(0.2)          # a public API, used politely
  }
  cat("\n\n")
}

## ---- phase 2: map --------------------------------------------------------
if (!file.exists(rawPath)) stop("no archive at ", rawPath, call. = FALSE)
lines <- readLines(rawPath, warn = FALSE)
cat("mapping", length(lines), "archived record(s)\n")

trials <- vector("list", length(lines))
cont   <- list(); cats <- list()
for (i in seq_along(lines)) {
  st <- tryCatch(jsonlite::fromJSON(lines[i], simplifyVector = FALSE),
                 error = function(e) NULL)
  if (is.null(st)) next
  id <- tryCatch(st$protocolSection$identificationModule$nctId,
                 error = function(e) NA_character_)
  dm <- tryCatch(st$protocolSection$designModule, error = function(e) NULL)
  veto <- tryCatch(ctgDesignVeto(st), error = function(e) NA_character_)
  m <- tryCatch(ctgToTemplate(st),
                error = function(e) list(data = NULL, why = conditionMessage(e)))
  nArms <- if (!is.null(m$data)) sum(m$data$ROW == m$data$ROW[1]) else NA_integer_
  trials[[i]] <- data.frame(
    NCT = id,
    PHASES = paste(unlist(dm$phases %||% list()), collapse = "/"),
    MODEL = (dm$designInfo$interventionModel %||% NA_character_),
    ALLOCATION = (dm$designInfo$allocation %||% NA_character_),
    LEAD_SPONSOR_CLASS =
      (st$protocolSection$sponsorCollaboratorsModule$leadSponsor$class
       %||% NA_character_),
    START = (st$protocolSection$statusModule$startDateStruct$date
             %||% NA_character_),
    ARMS = nArms,
    ROWS = if (!is.null(m$data)) length(unique(m$data$ROW)) else 0L,
    VETO = if (is.na(veto)) "" else veto,
    STATUS = if (is.null(m$data)) (m$why %||% "unmapped") else "mapped",
    stringsAsFactors = FALSE)
  if (is.null(m$data)) next

  d <- m$data
  baseCols <- c("N","MEAN","SD","SE","Q1","Q3",
                "ROUND_MEAN","ROUND_DISPERSION","ROUND_OBSERVATION")
  catCols <- setdiff(names(d), c("TRIAL","ROW", baseCols))
  # ARM index is the row's position within its ROW group - the template
  # has no arm column by design, so it must be reconstructed here.
  d$ARM <- ave(seq_len(nrow(d)), d$ROW, FUN = seq_along)
  isCat <- is.na(d$MEAN)
  if (any(!isCat)) {
    x <- d[!isCat, c("TRIAL","ROW","ARM", baseCols), drop = FALSE]
    cont[[length(cont) + 1L]] <- x
  }
  if (any(isCat) && length(catCols)) {
    sub <- d[isCat, c("TRIAL","ROW","ARM", catCols), drop = FALSE]
    for (cc in catCols) {
      v <- sub[[cc]]
      keep <- !is.na(v)
      if (!any(keep)) next
      cats[[length(cats) + 1L]] <- data.frame(
        TRIAL = sub$TRIAL[keep], ROW = sub$ROW[keep], ARM = sub$ARM[keep],
        CATEGORY = cc, COUNT = v[keep], stringsAsFactors = FALSE)
    }
  }
  if (i %% 500L == 0L) cat("\r  mapped", i)
}
cat("\n")

tr <- do.call(rbind, Filter(Negate(is.null), trials))
utils::write.csv(tr, file.path(outDir, "trials.csv"), row.names = FALSE)
cn <- if (length(cont)) do.call(rbind, cont) else NULL
if (!is.null(cn)) utils::write.csv(cn, file.path(outDir, "baselineContinuous.csv"),
                                   row.names = FALSE)
ct <- if (length(cats)) do.call(rbind, cats) else NULL
if (!is.null(ct)) utils::write.csv(ct, file.path(outDir, "baselineCategorical.csv"),
                                   row.names = FALSE)

cat("\n================ CTGOV BASELINE CORPUS ================\n")
cat("trials archived   :", nrow(tr), "\n")
cat("  mapped          :", sum(tr$STATUS == "mapped"), "\n")
cat("  design-vetoed   :", sum(nzchar(tr$VETO)), "\n")
if (!is.null(cn)) {
  cat("continuous rows   :", nrow(cn), "  (",
      length(unique(paste(cn$TRIAL, cn$ROW))), "distinct measures )\n")
}
if (!is.null(ct)) {
  cat("categorical cells :", nrow(ct), "  (",
      length(unique(paste(ct$TRIAL, ct$ROW))), "distinct measures )\n")
}
cat("archive           :", rawPath, "\n")
cat("                    ", round(file.size(rawPath) / 1024^2), "MB\n")
