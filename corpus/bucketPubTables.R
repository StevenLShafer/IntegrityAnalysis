# bucketPubTables.R - segment the PubTables-1M test split into the
# buckets that are actually useful for testing this parser.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-27 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request. LOCAL CORPUS TOOLING ONLY - nothing here ships.        #
#                                                                          #
# Steve's framing: "one can learn something about table geometry from all  #
# tables, whether or not they are baseline tables. However, many of the    #
# parsing issues are unique to baseline tables. In particular, we don't    #
# have a lot of testing for median [IQR]."                                 #
#                                                                          #
# THREE BUCKETS:                                                           #
#   A  baseline-shaped candidates - the engine's own SHAPED filter, plus   #
#      randomisation vocabulary. What Table 1 of an RCT looks like.        #
#   B  everything else - geometry only. Column clustering, spanning        #
#      headers and ragged rows are FORMAT problems, not baseline           #
#      problems, and 75,000 non-baseline tables exercise them for free.    #
#   C  median [IQR] - drawn from A and B alike, because the median branch  #
#      is the least-tested path in the engine and the numbers do not care  #
#      which kind of table they came from.                                 #
#                                                                          #
# WHAT PUBTABLES CAN AND CANNOT ADJUDICATE. Its ground truth is table      #
# STRUCTURE (rows, columns, spans), never cell semantics - so it cannot    #
# say whether we read "45.2" correctly.                                    #
#                                                                          #
# It CAN adjudicate the GATE. When a table says "median (IQR)" the words   #
# are there to read, so the engine's three-way decision                    #
#     IQR stated      -> emit MEAN/Q1/Q3                                   #
#     range stated    -> skip, "needs quartiles, not the range"            #
#     nothing stated  -> skip, conservative                                #
# has a checkable right answer. That is the part of the median path most   #
# worth checking, because emitting a RANGE as an IQR would corrupt a       #
# fraud verdict silently rather than failing loudly.                       #
#                                                                          #
# READING REGION - the correction that makes the labels trustworthy.       #
# The word boxes include SURROUNDING PROSE, not just the table. The first  #
# pilot scanned the whole blob and produced 15 "skip-range" and ZERO       #
# "emit" out of 400 - because "range" is an ordinary English word that     #
# appears in body text metres from any table. (The very first sample       #
# contains "household income above the study median" in its prose.) A      #
# mislabelled bucket is worse than no bucket: it would "prove" the gate    #
# wrong when the truth was wrong.                                          #
#                                                                          #
# So labels are read ONLY from the table's own bounding box plus a band    #
# above and below it - the caption and footnote, which the engine          #
# legitimately reads - and never from distant prose.                       #
#                                                                          #
# ...with one asymmetry, Steve's point 2026-08-27: "IQR is such an         #
# unusual term that I think any grep that returns IQR would signal a       #
# useful table. Not too many tables will contain 'Cirque'." Correct, and   #
# it cuts one way only. IQR is nearly unambiguous, so finding it is        #
# high-precision. "Range" is not, so it needs the region discipline and    #
# an explicit tie-break: when the evidence is mixed, the truth label is    #
# the CONSERVATIVE one, never "range".                                     #
#                                                                          #
# Usage:  Rscript corpus/bucketPubTables.R [maxTables]                     #
############################################################################

dataDir  <- "C:/temp/pubtables1m"
wordsDir <- file.path(dataDir, "words_test")
annDir   <- file.path(dataDir, "annotations_test")
outDir   <- file.path(dataDir, "buckets")
dir.create(outDir, showWarnings = FALSE, recursive = TRUE)

suppressPackageStartupMessages({library(jsonlite); library(xml2)})

args <- commandArgs(trailingOnly = TRUE)
maxTables <- if (length(args) >= 1) as.integer(args[1]) else 0L

files <- list.files(wordsDir, pattern = "_words[.]json$", full.names = TRUE)
if (maxTables > 0) files <- head(files, maxTables)
cat("scanning", format(length(files), big.mark = ","), "tables\n")

# ---- patterns -----------------------------------------------------------
NUM <- "[0-9]+(?:[.,][0-9]+)?"
# A summary cell: a value, then TWO bounds inside an enclosure.
#
# Steve, 2026-08-27, on how a min/max range is written: "usually
# expressed as number (dash, comma, colon, emdash) number", enclosed in
# "brackets, curly braces, or parentheses".
#
# The important consequence is what this pattern CANNOT do. A median with
# its IQR and a median with its min/max range have the SAME SHAPE -
# "45 (30-60)" could be either. So no cell-level regex can tell them
# apart, and the label really is the only discriminator. That is why the
# engine's gate reads the row label, caption and footnote rather than the
# numbers, and why this bucket is scored on the gate's DECISION.
#
# Separators: comma, semicolon, hyphen, en dash, em dash, COLON (Steve's
# list - the colon was missing), or the word "to". Enclosures: (), [], {}.
medianCell <- sprintf(
  "%s\\s*[\\[({]\\s*%s\\s*(?:,|;|:|-|\u2013|\u2014|to)\\s*%s\\s*[\\])}]",
  NUM, NUM, NUM)

# SPACE as a separator - "45 (30 60)" - measured, NOT assumed. Steve,
# 2026-08-27: "sep might also be a space, I guess. Not sure I've ever
# seen that. We can check the in-the-wild downloads."
#
# Deliberately counted in its OWN column instead of being folded into
# medianCell, because a bare space between two numbers inside brackets is
# ambiguous in a way the punctuated forms are not: "100 (50 50)" could be
# two counts, "12 (5.2 %)" is a percentage with a spaced sign. Folding it
# in would silently inflate bucket C with non-median cells and there
# would be no way to tell afterwards.
#
# So the corpus answers the question. If SPACE_SEP comes back at a
# meaningful rate the separator list can be widened deliberately, with
# examples to look at; if it comes back near zero, the doubt is settled
# and nothing was contaminated meanwhile.
spaceCell <- sprintf("%s\\s*[\\[({]\\s*%s\\s+%s\\s*[\\])}]", NUM, NUM, NUM)
iqrWord   <- "IQR|inter-?quartile|quartile|\\bQ1\\b|\\bQ3\\b|25th|75th"
# "range" must NOT match inside "interquartile range" - the phrase that
# means the OPPOSITE. Found 2026-08-27: PMC1175887_table_2 says "data are
# expressed as median [interquartile range]", exactly the case the gate
# should EMIT, and the naive \brange\b labelled it ambiguous. Every table
# that stated the right thing in the commonest way was being mislabelled,
# which is why the first pilots showed zero "emit".
#
# ...and Steve's second refinement, 2026-08-27: "I think (but don't know)
# that 'range' would typically be enclosed in brackets, curly braces, or
# parentheses." That matches what a LABEL looks like - "median (range)",
# "[range]", "Age, years (range)" - whereas prose says "a wide range of
# outcomes" bare. Requiring the bracket is what separates the two, and it
# is the same asymmetry as before: IQR can be matched loosely because the
# token is rare; "range" cannot, because it is a common English word.
#
# The bare form is kept as a WEAK signal, recorded separately, so the
# assumption is testable rather than baked in - Steve flagged that he
# doesn't know it, and a corpus is how we find out.
rangeStrong <- paste0("[\\[({]\\s*(?:inter-?quartile\\s+)?+range\\s*[\\])}]",
                      "|median\\s*[\\[({]\\s*range",
                      "|min\\s*[-\u2013]\\s*max")
rangeWord <- paste0("(?<!inter)(?<!inter-)(?<!interquartile )",
                    "(?<!quartile )\\brange\\b",
                    "|min\\s*[-\u2013]\\s*max|\\bminimum\\b|\\bmaximum\\b")
medWord   <- "\\bmedian\\b"
rctWord   <- paste("randomi[sz]ed|randomi[sz]ation|placebo|double-?blind",
                   "allocated|intervention group|control group|trial arm",
                   sep = "|")

# The caption/footnote band, in PDF points. Wide enough for a two-line
# caption above and a footnote below, narrow enough to exclude body text.
BAND <- 60

tableBox <- function(annFile) {
  if (!file.exists(annFile)) return(NULL)
  x <- tryCatch(read_xml(annFile), error = function(e) NULL)
  if (is.null(x)) return(NULL)
  objs <- xml_find_all(x, ".//object")
  if (!length(objs)) return(NULL)
  nm <- xml_text(xml_find_first(objs, ".//name"))
  tb <- objs[nm == "table"]
  if (!length(tb)) return(NULL)
  as.numeric(xml_text(xml_children(xml_find_first(tb[1], ".//bndbox"))))
}

rows <- vector("list", length(files))
t0 <- Sys.time()
for (i in seq_along(files)) {
  f <- files[i]
  stem <- sub("_words[.]json$", "", basename(f))
  w <- tryCatch(fromJSON(f), error = function(e) NULL)
  blank <- data.frame(
    KEY = stem, WORDS = 0L, IN_TABLE = 0L, MEDIAN_CELLS = 0L,
    HAS_MEDIAN = FALSE, HAS_IQR = FALSE, HAS_RANGE = FALSE,
    HAS_RCT = FALSE, GATE_TRUTH = NA_character_, REGION = "none",
    LINES_EMIT = 0L, LINES_RANGE = 0L, LINES_UNLABELLED = 0L,
    stringsAsFactors = FALSE)
  if (is.null(w) || !is.data.frame(w) || !"text" %in% names(w) ||
      !nrow(w)) { rows[[i]] <- blank; next }

  box <- tableBox(file.path(annDir, paste0(stem, ".xml")))
  keep <- rep(TRUE, nrow(w))
  region <- "whole-file"
  if (!is.null(box) && length(box) == 4 && "bbox" %in% names(w)) {
    bb <- tryCatch(do.call(rbind, w$bbox), error = function(e) NULL)
    if (!is.null(bb) && ncol(bb) == 4 && nrow(bb) == nrow(w)) {
      # inside the table, or within BAND points above/below it
      keep <- bb[, 4] >= (box[2] - BAND) & bb[, 2] <= (box[4] + BAND)
      region <- "table+band"
    }
  }
  txt <- paste(w$text[keep], collapse = " ")

  mm <- gregexpr(medianCell, txt, perl = TRUE)[[1]]
  nMed <- if (mm[1] == -1) 0L else length(mm)

  hasIQR   <- grepl(iqrWord,   txt, perl = TRUE, ignore.case = TRUE)
  hasRange <- grepl(rangeWord, txt, perl = TRUE, ignore.case = TRUE)

  # PER-LINE labels, because the gate decides PER ROW and real tables mix
  # summary types - one variable reported as median (IQR), the next as
  # median (range). A table-level label collapses that into "ambiguous"
  # and throws away exactly the rows worth testing. line_num groups the
  # word boxes back into visual lines.
  nEmit <- nRange <- nUnlab <- 0L
  if (nMed > 0 && "line_num" %in% names(w)) {
    ln <- w$line_num[keep]; tx <- w$text[keep]
    for (L in unique(ln)) {
      lineTxt <- paste(tx[ln == L], collapse = " ")
      lm <- gregexpr(medianCell, lineTxt, perl = TRUE)[[1]]
      if (lm[1] == -1) next
      lIQR   <- grepl(iqrWord,   lineTxt, perl = TRUE, ignore.case = TRUE)
      lRange <- grepl(rangeWord, lineTxt, perl = TRUE, ignore.case = TRUE)
      # the line's own label wins; otherwise inherit the table's, which
      # is where a "all values are median (IQR)" footnote lives
      if (!lIQR && !lRange) { lIQR <- hasIQR; lRange <- hasRange }
      if (lIQR && !lRange)       nEmit  <- nEmit  + 1L
      else if (lRange && !lIQR)  nRange <- nRange + 1L
      else if (!lIQR && !lRange) nUnlab <- nUnlab + 1L
    }
  }

  # Tie-break toward the conservative answer. "IQR and range both
  # present" is recorded as ambiguous - those are for a human to read,
  # not for a script to guess - and "range only" is the ONLY way to
  # earn a skip-range label.
  truth <- if (nMed == 0) NA_character_
           else if (hasIQR && !hasRange) "emit"
           else if (hasIQR &&  hasRange) "ambiguous"
           else if (hasRange)            "skip-range"
           else                          "skip-unlabelled"

  rows[[i]] <- data.frame(
    KEY = stem, WORDS = nrow(w), IN_TABLE = sum(keep), MEDIAN_CELLS = nMed,
    HAS_MEDIAN = grepl(medWord, txt, perl = TRUE, ignore.case = TRUE),
    HAS_IQR = hasIQR, HAS_RANGE = hasRange,
    HAS_RCT = grepl(rctWord, txt, perl = TRUE, ignore.case = TRUE),
    GATE_TRUTH = truth, REGION = region,
    LINES_EMIT = nEmit, LINES_RANGE = nRange, LINES_UNLABELLED = nUnlab,
    stringsAsFactors = FALSE)

  if (i %% 5000 == 0)
    cat("  ", format(i, big.mark = ","), "/",
        format(length(files), big.mark = ","), " (",
        round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
        " min)\n", sep = "")
}
scan <- do.call(rbind, rows)

# ---- join the engine's verdict ------------------------------------------
# NOTE the key: MiningOutcomes stores "PMC1064078_table_0" and the words
# file is "PMC1064078_table_0_words.json". The first version stripped
# ".json" before "_words.json", so nothing ever matched and bucket A came
# out empty - a merge that silently produces zero is indistinguishable
# from a real finding until you look.
mo <- file.path(dataDir, "mining", "MiningOutcomes.csv")
if (file.exists(mo)) {
  m <- utils::read.csv(mo, stringsAsFactors = FALSE)
  m$KEY <- m$TABLE
  before <- nrow(scan)
  scan <- merge(scan, m[, c("KEY", "SHAPED", "OUTCOME", "ENGINE_ARMS",
                            "TRUE_ROWS", "TRUE_COLS")],
                by = "KEY", all.x = TRUE)
  matched <- sum(!is.na(scan$SHAPED))
  cat("\nmerge: ", matched, " of ", before, " matched MiningOutcomes\n",
      sep = "")
  if (matched == 0) cat("  WARNING: nothing matched - check the key\n")
} else {
  scan$SHAPED <- NA; scan$OUTCOME <- NA_character_
}

scan$BUCKET_A <- scan$SHAPED %in% c(TRUE, "TRUE")
scan$BUCKET_B <- !scan$BUCKET_A
scan$BUCKET_C <- scan$MEDIAN_CELLS > 0

utils::write.csv(scan, file.path(outDir, "Buckets.csv"), row.names = FALSE)

n <- function(x) format(sum(x, na.rm = TRUE), big.mark = ",")
cat("\n================ buckets ================\n")
cat("A  baseline-shaped      :", n(scan$BUCKET_A), "\n")
cat("   ...with RCT wording  :", n(scan$BUCKET_A & scan$HAS_RCT), "\n")
cat("B  geometry only        :", n(scan$BUCKET_B), "\n")
cat("C  median [x, y] cells  :", n(scan$BUCKET_C), "\n")
cat("   of which in A        :", n(scan$BUCKET_C & scan$BUCKET_A), "\n")
cat("   labelled IQR         :", n(scan$BUCKET_C & scan$HAS_IQR), "\n\n")
cat("bucket C, the gate's correct answer:\n")
print(table(scan$GATE_TRUTH[scan$BUCKET_C], useNA = "ifany"))
cat("\nreading region used:\n"); print(table(scan$REGION))
cat("\nwritten:", file.path(outDir, "Buckets.csv"), "\n")

# LINE-level totals: the granularity the gate actually works at.
cat("\nbucket C, LINE-level (the granularity the gate decides at):\n")
cat("  lines to EMIT (IQR stated)      :", n(scan$LINES_EMIT), "\n")
cat("  lines to SKIP (range stated)    :", n(scan$LINES_RANGE), "\n")
cat("  lines to SKIP (no label)        :", n(scan$LINES_UNLABELLED), "\n")
cat("  tables holding >=1 emit line    :",
    n(scan$LINES_EMIT > 0), "\n")

# Steve's open question, answered by the corpus rather than by opinion:
# does anyone actually write "45 (30 60)" with a bare space?
cat("\nspace-separated candidates (Steve's open question):\n")
cat("  tables with >=1 'N (N N)' cell  :", n(scan$SPACE_SEP_CELLS > 0), "\n")
cat("  ...that have NO punctuated cell :",
    n(scan$SPACE_SEP_CELLS > 0 & scan$MEDIAN_CELLS == 0), "\n")
cat("  (the second number is the one that matters - tables the current\n")
cat("   separator list would MISS entirely)\n")
