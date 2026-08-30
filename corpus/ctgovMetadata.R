# ctgovMetadata.R - the covariates for the baseline corpus: discipline,
# design, sponsor, enrolment, and the linking PMID.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction: "we should perhaps have a dataframe with all of the  #
# variables, p values, study designs ... the metadata including            #
# discipline, and the PMID of course."                                     #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY A SEPARATE PASS. buildCtgovCorpus.R fetched only the fields the      #
# baseline mapping needs. Re-fetching it with more fields would rewrite    #
# raw.ndjson underneath the screen currently reading it - the same         #
# mistake that killed a harvest batch on 2026-08-29. This writes its own   #
# files and joins on NCT.                                                  #
#                                                                          #
# THE DISCIPLINE AXIS. ClinicalTrials.gov has no specialty field. What it  #
# does have, for 81% of trials with results, is MeSH: `meshes` (specific   #
# terms) and `ancestors` (the broader terms above them). The ancestors are #
# the usable axis - "Neoplasms", "Infections", "Cardiovascular Diseases"   #
# are exactly the cut Steve asked for, and they are assigned by NLM        #
# indexers rather than by us.                                              #
#                                                                          #
# PRECEDENCE MATTERS, and is a judgement rather than a fact. A trial of    #
# febrile neutropenia in leukaemia carries BOTH "Neoplasms" and            #
# "Infections". Assigning it twice would double-count it in any            #
# per-discipline rate; assigning it arbitrarily would be worse. The order  #
# below puts the more specific organ/system disciplines ahead of the       #
# broad ones, and ONCOLOGY ahead of everything, because an oncology trial  #
# that also involves infection is still run by oncologists. The full       #
# ancestor list is kept in the output so anyone can reclassify without     #
# re-fetching.                                                             #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/ctgovMetadata.R [maxStudies] [outDir]                   #
#     maxStudies  0 = all (default 0)                                      #
#     outDir      default <INTEGRITY_WORK>/ctgov_corpus                    #
#                                                                          #
# OUTPUT                                                                   #
#   meta.ndjson        the archive of what was fetched                     #
#   trialMetadata.csv  one row per trial, ready to join to screened.csv    #
############################################################################

suppressPackageStartupMessages({ library(jsonlite) })

args   <- commandArgs(trailingOnly = TRUE)
maxN   <- if (length(args) >= 1) as.integer(args[1]) else 0L
outDir <- if (length(args) >= 2) args[2] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
dir.create(outDir, recursive = TRUE, showWarnings = FALSE)
rawPath <- file.path(outDir, "meta.ndjson")
outCsv  <- file.path(outDir, "trialMetadata.csv")
API <- "https://clinicaltrials.gov/api/v2/studies"

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- fetch ---------------------------------------------------------------
fields <- paste("protocolSection.identificationModule.nctId",
                "protocolSection.identificationModule.briefTitle",
                "protocolSection.conditionsModule",
                "protocolSection.designModule",
                "protocolSection.sponsorCollaboratorsModule.leadSponsor",
                "protocolSection.statusModule",
                "protocolSection.referencesModule",
                "derivedSection.conditionBrowseModule", sep = ",")
if (!file.exists(rawPath) || maxN > 0) {
  con <- file(rawPath, open = "w", encoding = "UTF-8")
  token <- NULL; have <- 0L
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
    cat("\r  fetched", have)
    if (is.null(token)) break
    Sys.sleep(0.2)
  }
  close(con); cat("\n")
}

## ---- discipline ----------------------------------------------------------
# Ordered: first match wins. See the header on why precedence is a
# judgement and why the raw ancestor list is retained regardless.
DISCIPLINE <- list(
  oncology         = "Neoplasms",
  hematology       = "Hemic and Lymphatic Diseases|Hematologic Diseases",
  infectious       = "^Infections$|Bacterial Infections and Mycoses|Virus Diseases|Parasitic Diseases",
  cardiology       = "Cardiovascular Diseases|Heart Diseases",
  neurology        = "Nervous System Diseases",
  psychiatry       = "Mental Disorders|Behavioral Disciplines",
  pulmonology      = "Respiratory Tract Diseases|Lung Diseases",
  gastroenterology = "Digestive System Diseases|Gastrointestinal Diseases",
  endocrine        = "Endocrine System Diseases|Nutritional and Metabolic Diseases",
  nephrology       = "Urologic Diseases|Kidney Diseases",
  urology          = "Male Urogenital Diseases",
  gynecology       = "Female Urogenital Diseases and Pregnancy Complications",
  rheum_ortho      = "Musculoskeletal Diseases|Connective Tissue Diseases|Rheumatic Diseases",
  dermatology      = "Skin and Connective Tissue Diseases|Skin Diseases",
  ophthalmology    = "Eye Diseases",
  ent              = "Otorhinolaryngologic Diseases",
  immunology       = "Immune System Diseases",
  anesth_pain      = "Pain|Anesthesia|Analgesia")

classify <- function(terms) {
  if (!length(terms)) return(NA_character_)
  hay <- paste(terms, collapse = " | ")
  for (nm in names(DISCIPLINE))
    if (grepl(DISCIPLINE[[nm]], hay, perl = TRUE)) return(nm)
  "other"
}

## ---- flatten -------------------------------------------------------------
lines <- readLines(rawPath, warn = FALSE)
cat("flattening", length(lines), "record(s)\n")
rows <- vector("list", length(lines))
for (i in seq_along(lines)) {
  st <- tryCatch(jsonlite::fromJSON(lines[i], simplifyVector = FALSE),
                 error = function(e) NULL)
  if (is.null(st)) next
  ps <- st$protocolSection %||% list()
  dm <- ps$designModule %||% list()
  cb <- (st$derivedSection %||% list())$conditionBrowseModule %||% list()
  anc <- vapply(cb$ancestors %||% list(), function(x) x$term %||% "", "")
  msh <- vapply(cb$meshes %||% list(), function(x) x$term %||% "", "")
  refs <- (ps$referencesModule %||% list())$references %||% list()
  pmids <- unique(unlist(lapply(refs, function(r) r$pmid)))
  # A DERIVED reference is one NLM linked automatically; RESULT is one
  # the sponsor declared as reporting this trial. Prefer RESULT when
  # present - it is the paper the registry itself says reports the trial.
  pmidResult <- unique(unlist(lapply(refs, function(r)
    if (identical(r$type, "RESULT")) r$pmid else NULL)))
  rows[[i]] <- data.frame(
    NCT        = ps$identificationModule$nctId %||% NA_character_,
    PHASES     = paste(unlist(dm$phases %||% list()), collapse = "/"),
    MODEL      = dm$designInfo$interventionModel %||% NA_character_,
    ALLOCATION = dm$designInfo$allocation %||% NA_character_,
    MASKING    = dm$designInfo$maskingInfo$masking %||% NA_character_,
    PURPOSE    = dm$designInfo$primaryPurpose %||% NA_character_,
    ENROLLMENT = as.integer(dm$enrollmentInfo$count %||% NA),
    SPONSOR    = ps$sponsorCollaboratorsModule$leadSponsor$class %||% NA_character_,
    STATUS     = ps$statusModule$overallStatus %||% NA_character_,
    START      = ps$statusModule$startDateStruct$date %||% NA_character_,
    COMPLETION = ps$statusModule$completionDateStruct$date %||% NA_character_,
    DISCIPLINE = classify(c(anc, msh)),
    N_MESH     = length(msh),
    MESH       = substr(paste(msh, collapse = "; "), 1, 200),
    ANCESTORS  = substr(paste(anc, collapse = "; "), 1, 300),
    CONDITIONS = substr(paste(unlist(ps$conditionsModule$conditions %||% list()),
                              collapse = "; "), 1, 200),
    PMID       = if (length(pmidResult)) pmidResult[1] else
                 if (length(pmids)) pmids[1] else NA_character_,
    N_PMID     = length(pmids),
    stringsAsFactors = FALSE)
  if (i %% 2000L == 0L) cat("\r  ", i)
}
cat("\n")
md <- do.call(rbind, Filter(Negate(is.null), rows))
utils::write.csv(md, outCsv, row.names = FALSE)

cat("\n================ TRIAL METADATA ================\n")
cat("trials            :", nrow(md), "\n")
cat("with a PMID       :", sum(!is.na(md$PMID)),
    sprintf("(%.0f%%)\n", 100 * mean(!is.na(md$PMID))))
cat("with MeSH terms   :", sum(md$N_MESH > 0),
    sprintf("(%.0f%%)\n", 100 * mean(md$N_MESH > 0)))
cat("\ndiscipline:\n")
tb <- sort(table(md$DISCIPLINE, useNA = "ifany"), decreasing = TRUE)
for (k in seq_along(tb))
  cat(sprintf("  %-18s %6d  (%.1f%%)\n", names(tb)[k], tb[k],
              100 * tb[k] / nrow(md)))
cat("\nwritten:", outCsv, "\n")
cat("join to screened.csv on NCT for the analysis frame.\n")
