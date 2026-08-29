# measureMisparse.R - how often does the parser succeed with WRONG values?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-26 by Claude (Claude Code, model Claude Opus 5) at Steve  #
# Shafer's request, after the "unknown unknowns" review named this the one  #
# number the project claims implicitly but has never measured.             #
#                                                                          #
# WHY THIS IS THE IMPORTANT NUMBER. We measure the PARSE RATE (did a table  #
# come out?) and we have VALIDATED THE MONTE CARLO (given right numbers,    #
# right p). The unexamined middle is a parse that SUCCEEDS with wrong       #
# values - a swapped column, a misread digit - producing a confident,       #
# wrong p with nothing flagged. A failed parse is safe: the editor sees     #
# red cells and fixes them. A plausible misparse is the dangerous case,     #
# because an editor acts on it.                                            #
#                                                                          #
# METHOD. Carlisle hand-entered the baseline values for the trials in this  #
# corpus. For every corpus PDF we can map to one of his trials, parse it    #
# deterministically and compare our extracted numbers against his:          #
#                                                                          #
#   corroborated  our (MEAN, SD) pair matches one of his pairs in the same  #
#                 trial, within a tolerance that respects printed rounding  #
#   uncorroborated  we produced a pair that appears NOWHERE in his data     #
#                 for that trial - either a misparse, or a variable he      #
#                 chose not to record. This is an UPPER BOUND on misparse.  #
#   missed        he recorded a pair we did not produce (safe: a miss)      #
#                                                                          #
# Label matching is deliberately NOT used: his row labels are his own       #
# naming, and forcing a label join would manufacture disagreement. Values   #
# are the thing an analysis consumes, so values are what we compare.        #
#                                                                          #
# The headline is the per-FILE uncorroborated rate: on what fraction of     #
# files does the parser emit at least one number the ground truth cannot    #
# account for? That is the number to quote (as an upper bound) when         #
# telling an editor what to expect.                                        #
#                                                                          #
# Resumable: results append to misparse_rows.csv after every batch, and a   #
# rerun skips files already scored.                                        #
#                                                                          #
# Usage:  Rscript corpus/measureMisparse.R [maxFiles]                       #
############################################################################

suppressPackageStartupMessages({
  library(openxlsx)
})

root    <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
corpus  <- Sys.getenv("INTEGRITY_CORPUS", "C:/temp/journals")
outDir  <- file.path(root, ".NewCarlisle", "misparse")
dir.create(outDir, recursive = TRUE, showWarnings = FALSE)
rowsPath <- file.path(outDir, "misparse_rows.csv")
filePath <- file.path(outDir, "misparse_files.csv")

args     <- commandArgs(trailingOnly = TRUE)
maxFiles <- if (length(args) >= 1) as.integer(args[1]) else NA_integer_

# INSTALLED package, not load_all (corrected 2026-08-28). This script
# produces the corroboration figure quoted alongside the parse rate, and
# it was loading the LIVE TREE - the exact pattern that contaminated the
# 2026-08-25 Carlisle certification, where parse children absorbed
# mid-run edits. A number defended in public must come from a build that
# could not have changed underneath it.
# Read the snapshot library FIRST, because the check below has to look
# in it. Getting this order wrong made the guard test the wrong library
# (fixed 2026-08-30): requireNamespace() with no lib.loc searches only
# the default .libPaths(), so on a machine where the package is
# installed ONLY in the snapshot library - which is the recommended
# setup - the script refused to start. Worse, on a machine that also
# had a copy on the default path, the guard passed by finding THAT one:
# it was answering "is some IntegrityAnalysis installed somewhere"
# when the question is "is the build I am about to load present".
# That is precisely the stale-0.1.0 hazard described just above.
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
# PUT IT ON .libPaths(), not just lib.loc (fixed 2026-08-30). Two things
# depend on it being there, and lib.loc reaches neither:
#
#   1. The check below, which must ask about the library this run will
#      actually load from - not "is some copy installed anywhere".
#   2. THE SUBPROCESS CHILDREN. parseBaselineTableFiles() hands each
#      child the PARENT'S .libPaths(); with the snapshot library absent
#      from it, every child failed to load the package and returned
#      NULL, and the run reported "parsed: 0" with no error anywhere.
#
# Both symptoms were invisible on a machine that also had a copy on the
# default path - which is exactly the stale-build hazard described
# above, silently doing the work the snapshot library was meant to do.
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
haveEngine <- if (nzchar(libDir))
  requireNamespace("IntegrityAnalysis", quietly = TRUE, lib.loc = libDir) else
  requireNamespace("IntegrityAnalysis", quietly = TRUE)
if (!haveEngine)
  stop("IntegrityAnalysis is not installed in ",
       if (nzchar(libDir)) libDir else "THIS R's library path",
       " - install it there first (R CMD INSTALL --library=<dir> .); ",
       "a corroboration figure from a live tree is not defensible.",
       call. = FALSE)
# SNAPSHOT LIBRARY, named explicitly. INTEGRITY_SNAPSHOT_LIB points at a
# library built by `R CMD INSTALL --library=<dir> .` from a known commit;
# without it the script falls back to the ordinary path, which is how a
# STALE build (0.1.0, months old) silently produced the figure before.
if (nzchar(libDir)) {
  library(IntegrityAnalysis, lib.loc = libDir)
} else {
  libDir <- NULL
  library(IntegrityAnalysis)
}
library(shiny)
engineVersion <- as.character(
  utils::packageVersion("IntegrityAnalysis",
                        lib.loc = if (is.null(libDir)) NULL else libDir))
engineCommit <- tryCatch({
  s <- IntegrityAnalysis::buildCommit(); if (is.na(s)) "unknown" else s
}, error = function(e) "unknown")
cat("engine: version", engineVersion, " commit",
    substr(engineCommit, 1, 8), "
")
source(file.path(root, "corpus", "parallelHelper.R"))
suppressWarnings(suppressPackageStartupMessages({
  library(foreach); library(Rfast); library(MBESS); library(dqrng)
}))

## ---- ground truth --------------------------------------------------------
os <- read.xlsx(file.path(root, "One Sheet Carlisle Data.xlsx"))
wide <- read.xlsx(file.path(root, "Carlisle Data with PMIDs and DOIs.xlsx"),
                  sheet = "All Data")
cat("One Sheet rows:", nrow(os), " wide trials:", nrow(wide), "\n")

# PMID -> his trial key. The wide file carries PMIDs; the One Sheet carries
# the values, joined by journal + trial number (with the A&A >= 1235 offset
# the 2026-08-17 archaeology established - see validateCarlisle2017.R).
wide$PMID <- suppressWarnings(as.numeric(wide$PMID))
wide$key  <- paste(wide$Journal, wide$trial)

osTrial <- as.character(os$TRIAL)
osNum    <- as.integer(gsub("[^0-9]", "", osTrial))
osPrefix <- trimws(gsub("[0-9 ]+$", "", osTrial))
prefMap <- c("Anaesthesia" = "Anaesthesia", "Anesthesiology" = "Anesthesiology",
             "BJA" = "British Journal of Anaesthesia",
             "CJA" = "Canadian Journal of Anesthesia",
             "EJA" = "European Journal of Anaesthesiology",
             "JAMA" = "JAMA", "NEJM" = "New England Journal of Medicine",
             "Anesthesia and Analgesia" = "Anesthesia & Analgesia")
osJournal <- unname(prefMap[osPrefix])
osAdj <- ifelse(!is.na(osJournal) & osJournal == "Anesthesia & Analgesia" &
                  !is.na(osNum) & osNum >= 1235, osNum + 1L, osNum)
os$key <- paste(osJournal, osAdj)

## ---- corpus files with a PMID -------------------------------------------
pdfs <- list.files(corpus, pattern = "[.]pdf$", recursive = TRUE,
                   full.names = TRUE)
pmidFromName <- function(p) {
  m <- regmatches(basename(p), regexpr("PMID_([0-9]+)", basename(p)))
  if (!length(m)) return(NA_real_)
  as.numeric(sub("PMID_", "", m))
}
pm <- vapply(pdfs, pmidFromName, numeric(1), USE.NAMES = FALSE)
mapPath <- file.path(root, "corpus", "pmid_map.csv")
if (file.exists(mapPath)) {
  pmap <- read.csv(mapPath, colClasses = "character")
  nmCol <- intersect(c("PDF", "file", "FILE"), names(pmap))[1]
  idCol <- intersect(c("PMID", "pmid"), names(pmap))[1]
  if (!is.na(nmCol) && !is.na(idCol)) {
    rel <- sub(paste0("^", gsub("([.|()\\^{}+$*?])", "\\\\\\1", corpus), "/"),
               "", gsub("\\\\", "/", pdfs))
    hit <- match(rel, gsub("\\\\", "/", pmap[[nmCol]]))
    pm[is.na(pm) & !is.na(hit)] <-
      suppressWarnings(as.numeric(pmap[[idCol]][hit[is.na(pm) & !is.na(hit)]]))
  }
}
have <- !is.na(pm) & pm %in% wide$PMID[!is.na(wide$PMID)]
work <- data.frame(pdf = pdfs[have], pmid = pm[have],
                   stringsAsFactors = FALSE)
work$key <- wide$key[match(work$pmid, wide$PMID)]
work <- work[!is.na(work$key) & work$key %in% os$key, , drop = FALSE]
cat(nrow(work), "corpus PDF(s) map to a Carlisle trial with values\n")

done <- if (file.exists(rowsPath))
  unique(read.csv(rowsPath, colClasses = "character")$PDF) else character(0)
work <- work[!(basename(work$pdf) %in% done), , drop = FALSE]
if (!is.na(maxFiles)) work <- utils::head(work, maxFiles)
cat(nrow(work), "still to score\n")

## ---- compare -------------------------------------------------------------
# A pair matches if the means agree to the coarser printed precision and the
# dispersions likewise; rounding, not identity, is the standard.
near <- function(a, b, dec) {
  if (is.na(a) || is.na(b)) return(FALSE)
  tol <- 10^(-dec) / 2 + 1e-9
  abs(a - b) <= tol
}

# PARALLEL BY BATCH (2026-08-28). Each worker parses and scores its own
# 25 files and RETURNS the rows; the PARENT does all the writing.
# Workers must never append to one CSV concurrently - interleaved writes
# corrupt it, and corrupted rows would look like data rather than damage.
batch <- 25L
starts <- seq(1, max(nrow(work), 1), by = batch)
scoreBatch <- function(start) {
  if (nrow(work) == 0) return(NULL)
  idx <- start:min(start + batch - 1L, nrow(work))
  res <- parseBaselineTableFiles(work$pdf[idx], ai = "never",
                                 timeout = 90, quiet = TRUE)
  outRows <- list()
  for (k in seq_along(idx)) {
    i <- idx[k]
    r <- res$result[[k]]
    theirs <- os[os$key == work$key[i], , drop = FALSE]
    theirM <- suppressWarnings(as.numeric(theirs$MEAN))
    theirS <- suppressWarnings(as.numeric(theirs$SD))
    keepT  <- !is.na(theirM) & !is.na(theirS)
    theirM <- theirM[keepT]; theirS <- theirS[keepT]

    if (is.null(r) || nrow(r$data) == 0) {
      outRows[[length(outRows) + 1]] <- data.frame(
        PDF = basename(work$pdf[i]), PMID = work$pmid[i], KEY = work$key[i],
        OUTCOME = "not parsed", OURS = 0L, THEIRS = length(theirM),
        CORROBORATED = 0L, UNCORROBORATED = 0L, MISSED = length(theirM),
        stringsAsFactors = FALSE)
      next
    }
    d <- r$data
    ourM <- suppressWarnings(as.numeric(d$MEAN))
    ourS <- suppressWarnings(as.numeric(d$SD))
    dec  <- suppressWarnings(as.integer(d$ROUND_MEAN))
    dec[is.na(dec)] <- 2L
    keepO <- !is.na(ourM) & !is.na(ourS)
    ourM <- ourM[keepO]; ourS <- ourS[keepO]; dec <- dec[keepO]

    corro <- vapply(seq_along(ourM), function(j) {
      any(vapply(seq_along(theirM), function(t)
        near(ourM[j], theirM[t], dec[j]) && near(ourS[j], theirS[t], dec[j]),
        logical(1)))
    }, logical(1))
    missed <- vapply(seq_along(theirM), function(t) {
      !any(vapply(seq_along(ourM), function(j)
        near(ourM[j], theirM[t], dec[j]) && near(ourS[j], theirS[t], dec[j]),
        logical(1)))
    }, logical(1))

    outRows[[length(outRows) + 1]] <- data.frame(
      PDF = basename(work$pdf[i]), PMID = work$pmid[i], KEY = work$key[i],
      OUTCOME = "parsed", OURS = length(ourM), THEIRS = length(theirM),
      CORROBORATED = sum(corro), UNCORROBORATED = sum(!corro),
      MISSED = sum(missed), stringsAsFactors = FALSE)
  }
  do.call(rbind, outRows)
}

chunks <- iaParallel(starts, scoreBatch,
                     export = c("work", "os", "near", "batch"),
                     libDir = libDir)
allRows <- do.call(rbind, Filter(Negate(is.null), chunks))
if (!is.null(allRows) && nrow(allRows)) {
  write.table(allRows, rowsPath, sep = ",", row.names = FALSE,
              col.names = !file.exists(rowsPath),
              append = file.exists(rowsPath))
  cat(sprintf("scored %d file(s)
", nrow(allRows)))
}

## ---- report --------------------------------------------------------------
if (file.exists(rowsPath)) {
  all <- read.csv(rowsPath)
  p <- all[all$OUTCOME == "parsed", , drop = FALSE]
  cat("\n================ SILENT MISPARSE MEASUREMENT ================\n")
  cat("files scored:", nrow(all), " parsed:", nrow(p), "\n")
  if (nrow(p)) {
    cat("our mean/SD pairs:", sum(p$OURS),
        " corroborated by Carlisle:", sum(p$CORROBORATED),
        sprintf(" (%.1f%%)\n", 100 * sum(p$CORROBORATED) / max(sum(p$OURS), 1)))
    cat("UNCORROBORATED pairs (upper bound on misparse):",
        sum(p$UNCORROBORATED),
        sprintf(" (%.1f%% of ours)\n",
                100 * sum(p$UNCORROBORATED) / max(sum(p$OURS), 1)))
    cat("files with >=1 uncorroborated pair:",
        sum(p$UNCORROBORATED > 0),
        sprintf(" (%.1f%% of parsed files)\n",
                100 * mean(p$UNCORROBORATED > 0)))
  # VACUOUS CASES EXCLUDED (2026-08-29). "Fully corroborated" was
  # UNCORROBORATED == 0 over every parsed file - which counts a file
  # that extracted NOTHING as perfect, because a file with no pairs has
  # no uncorroborated pairs. 101 of 988 parsed files were in that state,
  # inflating the headline from 42.8% to 48.7%.
  #
  # (Those two percentages are from the 2026-08-29 run, since SUPERSEDED:
  # its parse subprocesses were running the stale 0.1.0 engine - see
  # corpus/CorroborationByFile.README.md and PR #115. The exclusion
  # described here is unaffected and still correct; only the numbers
  # moved. Current figures: 1,047 parsed, 81 vacuous, 44.8%.)
  #
  # That is the same error as quoting a parse rate without asking
  # whether the table was right: it rewards extracting nothing. This
  # figure exists to be the honest companion to the parse rate, so it
  # reports over files that actually produced values, and states the
  # vacuous count rather than hiding it.
  hasPairs <- p$OURS > 0
  vacuous  <- sum(!hasPairs)
  q <- p[hasPairs, , drop = FALSE]
  cat("files that extracted no pairs at all:", vacuous,
      "(excluded below - nothing to corroborate)\n")
  cat("files fully corroborated:", sum(q$UNCORROBORATED == 0), "of",
      nrow(q), sprintf(" (%.1f%%)\n", 100 * mean(q$UNCORROBORATED == 0)))
  cat("files with >=1 UNCORROBORATED pair:", sum(q$UNCORROBORATED > 0),
      sprintf(" (%.1f%%)\n", 100 * mean(q$UNCORROBORATED > 0)))
    cat("his pairs we missed:", sum(p$MISSED),
        sprintf(" (%.1f%% of his)\n",
                100 * sum(p$MISSED) / max(sum(p$THEIRS), 1)), "\n")
    write.csv(p[order(-p$UNCORROBORATED), ], filePath, row.names = FALSE)
    cat("worst files (most uncorroborated) written to", filePath, "\n")
  }
}
