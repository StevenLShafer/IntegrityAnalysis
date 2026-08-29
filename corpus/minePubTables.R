# minePubTables.R - run the deterministic engine over PubTables-1M word
# boxes and score its structure against the dataset's ground truth.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-26 by Claude Code (model Claude Fable 5) at Steve        #
# Shafer's request (ISSUES.md issue 20). LOCAL CORPUS TOOLING ONLY -       #
# nothing here ships in the app.                                           #
#                                                                          #
# Design decisions, each from a lesson learned this week:                  #
# - The engine is loaded from a SNAPSHOT LIBRARY (R CMD INSTALL into      #
#   C:/Temp/ia-pubtables-lib), never load_all of a live tree: the         #
#   2026-08-25 Carlisle certification was contaminated by parse children  #
#   absorbing mid-run edits. Every result row records the engine commit.  #
# - Chunked and resumable exactly like buildParseOutcomes.R: one RDS per  #
#   chunk under <outDir>/chunks; a crash or reboot loses at most one      #
#   chunk; rerunning assembles instantly from cache.                       #
# - No subprocess per table: the input is JSON word boxes - there is no   #
#   poppler to hang, no PDF to render. That is why a million tables is    #
#   an overnight job, not a cluster job.                                   #
#                                                                          #
# Input (C:/temp/pubtables1m, the Hugging Face download 2026-08-26):      #
#   words_test/PMC*_words.json    - every word with its bbox (PDF points) #
#   annotations_test/PMC*.xml     - ground truth: table/row/column/header #
#   sample/test_filelist.txt      - the official 93,834-table test split  #
#                                                                          #
# v1 scoring (calibration): parse outcome, arm count, row/column counts   #
# vs the XML truth, wall time. Cell-level text scoring is v2, built only  #
# if v1 shows it is worth it.                                              #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/minePubTables.R [maxTables]                             #
#   (maxTables caps THIS run for pilots; the cache accumulates across     #
#   runs, so a nightly loop just calls it with no cap until done.)        #
############################################################################

libDir  <- file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ia-pubtables-lib")
dataDir <- file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "pubtables1m")
outDir  <- file.path(dataDir, "mining")
chunkDir <- file.path(outDir, "chunks")
dir.create(chunkDir, showWarnings = FALSE, recursive = TRUE)

suppressPackageStartupMessages(
  library(IntegrityAnalysis, lib.loc = libDir))
suppressPackageStartupMessages({library(jsonlite); library(xml2)})

engineCommit <- tryCatch(
  system2("git", c("-C", file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ia-pubtables"), "rev-parse", "--short",
                   "HEAD"), stdout = TRUE)[1],
  error = function(e) NA_character_)

args <- commandArgs(trailingOnly = TRUE)
maxTables <- if (length(args) >= 1) as.integer(args[1]) else NA_integer_

# ---- the worklist: the official test split ------------------------------
# test_filelist.txt lists annotation paths ("test/PMC..._table_0.xml") -
# NOT image names; the first extraction attempt assumed .jpg and matched
# zero members (2026-08-26).
flist <- file.path(dataDir, "sample", "test_filelist.txt")
stems <- sub("[.]xml$", "", basename(readLines(flist)))
cat(length(stems), "tables in the official test split\n")

wordsFile <- function(s) file.path(dataDir, "words_test",
                                   paste0(s, "_words.json"))
annFile   <- function(s) file.path(dataDir, "annotations_test",
                                   paste0(s, ".xml"))

have <- file.exists(wordsFile(stems)) & file.exists(annFile(stems))
cat(sum(have), "of", length(stems), "have both words and annotation on disk\n")
stems <- stems[have]

# ---- ground truth from the structure XML --------------------------------
truthCounts <- function(xmlPath) {
  x <- read_xml(xmlPath)
  objs <- xml_find_all(x, ".//object/name")
  nm <- xml_text(objs)
  c(rows = sum(nm == "table row"),
    cols = sum(nm == "table column"),
    spans = sum(nm == "table spanning cell"),
    headers = sum(nm == "table column header"))
}

# ---- baseline-shaped classifier -----------------------------------------
# PubTables is generic PMC tables; only a subset are baseline tables, and
# ONLY that subset may fairly judge the engine's semantic layer (mean/SD
# tokenization, arm N, percents). Steve's framing (2026-08-26): a table
# is a table for the STRUCTURAL layer, but semantics need the real
# thing. Signals, deliberately loose - this labels for stratified
# scoring, it does not gate the parse:
#   caption  - "baseline", "demographic", "characteristics of the
#              patients/subjects/participants"
#   plusminus - three or more plus-minus glyphs among the words (the
#              mean+/-SD look)
#   npct     - an "n (%)" style header anywhere in the text
.shapePat <- paste0(
  "(?i)\\bbaseline\\b|\\bdemographic|patient characteristics|",
  "characteristics of (the )?(patients|subjects|participants)")
baselineShape <- function(words) {
  txt <- paste(words$text, collapse = " ")
  why <- c(
    if (grepl(.shapePat, txt, perl = TRUE)) "caption",
    if (sum(grepl("±", words$text, fixed = TRUE)) >= 3) "plusminus",
    if (grepl("(?i)\\bno?\\.?\\s*\\(\\s*%\\s*\\)|\\bn\\s*\\(\\s*%\\s*\\)",
              txt, perl = TRUE)) "npct")
  list(shaped = length(why) > 0,
       why = if (length(why)) paste(why, collapse = "+") else "")
}

# ---- adapter: words JSON -> the engine ----------------------------------
# The bbox is [x0, y0, x1, y1] in PDF points - the same frame
# pdftools::pdf_data reports - so the words drop straight into the
# engine's line builder. .ppParseBlock is reached through the same
# internal seam the docx adapter uses.
loadWords <- function(stem) {
  w <- fromJSON(wordsFile(stem), simplifyDataFrame = TRUE)
  if (!is.data.frame(w) || nrow(w) == 0) return(NULL)
  words <- data.frame(
    text   = IntegrityAnalysis:::.ppNormalizeGlyphs(w$text),
    x      = vapply(w$bbox, `[`, numeric(1), 1),
    y      = vapply(w$bbox, `[`, numeric(1), 2),
    width  = vapply(w$bbox, function(b) b[3] - b[1], numeric(1)),
    height = vapply(w$bbox, function(b) b[4] - b[2], numeric(1)),
    stringsAsFactors = FALSE)
  words[!is.na(words$text) & nzchar(trimws(words$text)), , drop = FALSE]
}

parseOneTable <- function(stem, words) {
  if (is.null(words) || nrow(words) == 0)
    return(list(outcome = "no words", rows = 0L, arms = 0L, cols = 0L))
  lines <- IntegrityAnalysis:::.ppBuildLines(words)
  if (length(lines) < 2)
    return(list(outcome = "too few lines", rows = 0L, arms = 0L, cols = 0L))
  lineTexts <- vapply(lines, IntegrityAnalysis:::.ppLineText, character(1))
  # caption line, if the words carry one ("Table 2 Summary of ...")
  capIdx <- 0L
  capScores <- vapply(lineTexts, IntegrityAnalysis:::.ppCaptionScore,
                      numeric(1))
  if (any(capScores > 0)) capIdx <- which.max(capScores)
  res <- IntegrityAnalysis:::.ppParseBlock(
    lines, lineTexts, capIdx = capIdx, trial = stem,
    parenIsSD = "auto", roundObsDelta = 1, say = function(...) NULL,
    textCands = NULL, textTotals = integer(0))
  if (is.null(res) || is.null(res$data) || nrow(res$data) == 0)
    return(list(outcome = "no usable rows", rows = 0L, arms = 0L,
                cols = 0L))
  list(outcome = "parsed",
       rows = length(unique(res$data$ROW)),
       arms = nrow(res$arms),
       cols = nrow(res$arms) + sum(!vapply(res$data, function(c)
         all(is.na(c)), logical(1))))
}

# ---- chunked, resumable loop --------------------------------------------
chunkSize <- 500L
nChunk <- ceiling(length(stems) / chunkSize)
done <- 0L
for (ci in seq_len(nChunk)) {
  chunkFile <- file.path(chunkDir, sprintf("chunk%05d.rds", ci))
  if (file.exists(chunkFile)) next
  idx <- ((ci - 1L) * chunkSize + 1L):min(ci * chunkSize, length(stems))
  rows <- vector("list", length(idx))
  for (j in seq_along(idx)) {
    s <- stems[idx[j]]
    t0 <- proc.time()[["elapsed"]]
    w  <- tryCatch(loadWords(s), error = function(e) NULL)
    sh <- if (is.null(w)) list(shaped = FALSE, why = "")
          else baselineShape(w)
    r <- tryCatch(parseOneTable(s, w),
                  error = function(e) list(outcome = paste0(
                    "ERROR: ", conditionMessage(e)),
                    rows = NA_integer_, arms = NA_integer_,
                    cols = NA_integer_))
    tc <- tryCatch(truthCounts(annFile(s)),
                   error = function(e) c(rows = NA, cols = NA,
                                         spans = NA, headers = NA))
    rows[[j]] <- data.frame(
      TABLE = s, ENGINE_COMMIT = engineCommit,
      SHAPED = sh$shaped, SHAPE_WHY = sh$why,
      OUTCOME = r$outcome, ENGINE_ROWS = r$rows, ENGINE_ARMS = r$arms,
      TRUE_ROWS = tc[["rows"]], TRUE_COLS = tc[["cols"]],
      TRUE_SPANS = tc[["spans"]],
      SECONDS = proc.time()[["elapsed"]] - t0,
      stringsAsFactors = FALSE)
  }
  saveRDS(do.call(rbind, rows), chunkFile)
  done <- done + length(idx)
  cat(sprintf("chunk %d/%d done (%d tables this run)\n", ci, nChunk, done))
  if (!is.na(maxTables) && done >= maxTables) break
}

# ---- assemble whatever is cached ----------------------------------------
all <- do.call(rbind, lapply(sort(list.files(chunkDir, full.names = TRUE)),
                             readRDS))
write.csv(all, file.path(outDir, "MiningOutcomes.csv"), row.names = FALSE)
cat("\nassembled:", nrow(all), "tables\n")
# Parse rate is only meaningful WITHIN the baseline-shaped stratum: a
# generic PMC table failing our baseline semantics is correct behavior.
for (grp in c(TRUE, FALSE)) {
  g <- all[all$SHAPED == grp, ]
  if (nrow(g) == 0) next
  cat(sprintf("%s: %d tables, %d parsed (%.1f%%)\n",
              if (grp) "baseline-shaped" else "other tables",
              nrow(g), sum(g$OUTCOME == "parsed"),
              100 * mean(g$OUTCOME == "parsed")))
}
cat("shaped fraction:", round(100 * mean(all$SHAPED), 1), "%\n")
cat("median seconds/table:", round(median(all$SECONDS), 3), "\n")
