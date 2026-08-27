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

root    <- "C:/dev/IntegrityAnalysis"
corpus  <- "C:/temp/journals"
outDir  <- file.path(root, ".NewCarlisle", "misparse")
dir.create(outDir, recursive = TRUE, showWarnings = FALSE)
rowsPath <- file.path(outDir, "misparse_rows.csv")
filePath <- file.path(outDir, "misparse_files.csv")

args     <- commandArgs(trailingOnly = TRUE)
maxFiles <- if (length(args) >= 1) as.integer(args[1]) else NA_integer_

pkgload::load_all(root, quiet = TRUE)
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

batch <- 25L
for (start in seq(1, max(nrow(work), 1), by = batch)) {
  if (nrow(work) == 0) break
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
  chunk <- do.call(rbind, outRows)
  write.table(chunk, rowsPath, sep = ",", row.names = FALSE,
              col.names = !file.exists(rowsPath), append = file.exists(rowsPath))
  cat(sprintf("scored %d / %d\n", min(start + batch - 1L, nrow(work)),
              nrow(work)))
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
    cat("files fully corroborated:", sum(p$UNCORROBORATED == 0),
        sprintf(" (%.1f%%)\n", 100 * mean(p$UNCORROBORATED == 0)))
    cat("his pairs we missed:", sum(p$MISSED),
        sprintf(" (%.1f%% of his)\n",
                100 * sum(p$MISSED) / max(sum(p$THEIRS), 1)), "\n")
    write.csv(p[order(-p$UNCORROBORATED), ], filePath, row.names = FALSE)
    cat("worst files (most uncorroborated) written to", filePath, "\n")
  }
}
