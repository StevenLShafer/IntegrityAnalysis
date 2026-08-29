# corroborationReport.R - the honest companion to the parse rate, and a
# test of whether corroboration PREDICTS a wrong verdict.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-27 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction, after the end-to-end validation showed the verdict   #
# damage is concentrated in a handful of articles rather than spread.      #
#                                                                          #
# WHAT WAS ALREADY THERE, and what was missing. measureMisparse.R already  #
# compares our extracted (MEAN, SD) pairs against Carlisle's hand-entered  #
# values and classifies them corroborated / uncorroborated / missed. That  #
# is the right measurement and it has been run over 1,110 files.           #
#                                                                          #
# What nobody had done is JOIN IT TO THE VERDICT. Corroboration says the   #
# numbers were wrong; validateEndToEnd says the p was wrong. Whether those #
# are the SAME ARTICLES is the question that decides whether corroboration #
# is merely a quality statistic or an actionable GATE - if low             #
# corroboration predicts a catastrophic p, the app can refuse to report a  #
# verdict it cannot corroborate, which is ISSUES 24's whole purpose.       #
#                                                                          #
# THE TWO NUMBERS AN EDITOR NEEDS, side by side:                           #
#   parse rate     - did a table come out?          (84.9%)                #
#   corroboration  - was it the RIGHT table?        (this)                 #
# Quoting the first without the second overstates the tool, because a      #
# confident parse of the wrong table is the failure mode that produces a   #
# false accusation. A FAILED parse is safe - the editor sees red cells.    #
#                                                                          #
# NOTE ON measureMisparse.R's ENGINE LOADING. It calls pkgload::load_all   #
# on the live tree, which AGENTS.md forbids for batch runs: the 2026-08-25 #
# Carlisle certification was contaminated by parse children absorbing      #
# mid-run edits. This script only READS its output, so it inherits the     #
# risk rather than adding to it - but the existing rows were produced that #
# way and that is recorded here rather than assumed away. Issue filed.     #
#                                                                          #
# Usage:  Rscript corpus/corroborationReport.R                             #
############################################################################

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
mf <- file.path(root, ".NewCarlisle", "misparse", "misparse_files.csv")
e2 <- file.path(root, "corpus", "EndToEndValidation.csv")
hp <- file.path(root, "corpus", "Holdout.csv")

if (!file.exists(mf))
  stop("no misparse_files.csv - run corpus/measureMisparse.R first",
       call. = FALSE)

m <- utils::read.csv(mf, stringsAsFactors = FALSE)
cat("misparse rows:", nrow(m), "\ncolumns:", paste(names(m), collapse = ", "),
    "\n\n")

## ---- the headline pair ---------------------------------------------------
num <- function(x) suppressWarnings(as.numeric(x))
corrCol <- intersect(c("CORROBORATED","corroborated","nCorroborated"), names(m))
uncCol  <- intersect(c("UNCORROBORATED","uncorroborated","nUncorroborated"),
                     names(m))
missCol <- intersect(c("MISSED","missed","nMissed"), names(m))
if (!length(corrCol) || !length(uncCol))
  stop("cannot find corroborated / uncorroborated columns", call. = FALSE)

m$nCorr <- num(m[[corrCol[1]]]); m$nUnc <- num(m[[uncCol[1]]])
m$nCorr[is.na(m$nCorr)] <- 0; m$nUnc[is.na(m$nUnc)] <- 0
m$total <- m$nCorr + m$nUnc
m$rate  <- ifelse(m$total > 0, m$nCorr / m$total, NA_real_)

scored <- m[m$total > 0, ]
cat("========== THE TWO NUMBERS, SIDE BY SIDE ==========\n")
cat("  files with a parsed table scored:", nrow(scored), "\n\n")
cat(sprintf("  FULLY corroborated (every value found)  : %4d  (%.1f%%)\n",
            sum(scored$rate == 1), 100*mean(scored$rate == 1)))
cat(sprintf("  PARTIAL                                 : %4d  (%.1f%%)\n",
            sum(scored$rate > 0 & scored$rate < 1),
            100*mean(scored$rate > 0 & scored$rate < 1)))
cat(sprintf("  ZERO corroboration (likely WRONG TABLE) : %4d  (%.1f%%)\n",
            sum(scored$rate == 0), 100*mean(scored$rate == 0)))
cat("\n  Zero corroboration is the dangerous class: a confident parse of a\n")
cat("  table that is not the baseline table. A FAILED parse is safe - the\n")
cat("  editor sees red cells and fixes them.\n")

## ---- does corroboration PREDICT a wrong verdict? -------------------------
if (!file.exists(e2)) {
  cat("\n(no EndToEndValidation.csv - run corpus/validateEndToEnd.R to test\n")
  cat(" whether corroboration predicts verdict damage)\n")
  quit(status = 0)
}
v <- utils::read.csv(e2, stringsAsFactors = FALSE)
v <- v[v$status == "ok" & is.finite(v$parsedP) & is.finite(v$carlisle) &
       v$parsedP > 0 & v$carlisle > 0, ]

key <- function(x) basename(as.character(x))
fileCol <- intersect(c("FILE","PDF","file"), names(m))[1]
m$KEY <- key(m[[fileCol]]); v$KEY <- key(v$PDF)
j <- merge(v, m[, c("KEY","rate","nCorr","nUnc")], by = "KEY")
cat("\n========== DOES CORROBORATION PREDICT A WRONG VERDICT? ==========\n")
cat("  articles with BOTH a corroboration score and a verdict:", nrow(j), "\n")
if (nrow(j) < 20) {
  cat("  too few to test - the two runs cover different file sets\n")
  quit(status = 0)
}
j$dP <- abs(log10(j$parsedP) - log10(j$carlisle))

band <- cut(j$rate, breaks = c(-0.01, 0, 0.5, 0.999, 1),
            labels = c("zero", "low (<50%)", "partial", "full"))
cat("\n  median |log10 p error| by corroboration band:\n")
for (b in levels(band)) {
  d <- j$dP[band == b & !is.na(band)]
  if (length(d))
    cat(sprintf("    %-12s n=%3d   median %.4f   worst %.3f\n",
                b, length(d), stats::median(d), max(d)))
}

# The operational question: if we refused to report a verdict below some
# corroboration threshold, how much damage would we avoid and how much
# legitimate work would we refuse?
cat("\n  IF THE APP REFUSED A VERDICT BELOW A CORROBORATION THRESHOLD:\n")
cat(sprintf("    %-10s %-10s %-14s %-14s\n",
            "threshold", "refused", "bad caught", "good refused"))
for (t in c(0.01, 0.25, 0.5, 0.75, 1.0)) {
  refuse <- j$rate < t
  bad <- j$dP > 1                       # off by >10x - a wrong verdict
  cat(sprintf("    %-10s %-10s %-14s %-14s\n",
      paste0(round(100*t), "%"),
      sprintf("%d (%.0f%%)", sum(refuse), 100*mean(refuse)),
      sprintf("%d of %d", sum(refuse & bad), sum(bad)),
      sprintf("%d", sum(refuse & !bad))))
}
cat("\n  'bad caught' = catastrophic verdicts (>10x off) that would be\n")
cat("  withheld; 'good refused' = sound analyses the editor loses. The\n")
cat("  right threshold is a judgment about which error costs more, and\n")
cat("  it is Steve's to make - this only supplies the trade-off.\n")

if (file.exists(hp)) {
  h <- utils::read.csv(hp, stringsAsFactors = FALSE)
  j$SET <- h$SET[match(j$PDF, h$PDF)]
  if (any(!is.na(j$SET))) {
    cat("\n  by holdout split:\n")
    for (s in c("development","holdout")) {
      d <- j$rate[which(j$SET == s)]
      if (length(d)) cat(sprintf("    %-12s n=%3d  zero-corroboration %.1f%%\n",
                                 s, length(d), 100*mean(d == 0)))
    }
  }
}
