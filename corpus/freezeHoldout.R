# freezeHoldout.R - split the Carlisle corpus into development and
# holdout, once, reproducibly, and never look at the holdout again.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-27 by Claude Code (model Claude Opus 5), from Steve      #
# Shafer's question: "Should we perhaps test parsing refinements built     #
# from medRxiv PDFs on the PubTables corpus, and vice versa, before        #
# deploying the refinements to parsePDF and testing against the Carlisle   #
# and AA corpora?"                                                         #
#                                                                          #
# Yes - and the question exposed a larger gap. AGENTS.md's optimization    #
# loop reads the failures in ParseOutcomes.csv, fixes the code, and        #
# re-measures ON THE SAME 1,865 ARTICLES. There is no held-out set         #
# anywhere in this repository. Every parse-rate number it has ever         #
# produced, including the 84.9% (1,584/1,865) being quoted to editors      #
# this week, was measured on the corpus the fixes were developed against.  #
#                                                                          #
# WHAT THIS FIXES AND WHAT IT CANNOT. Freezing a holdout today protects    #
# the FUTURE. It cannot purify the past: these articles have been read,    #
# their failures studied, and fixes written against them for weeks, so     #
# the holdout drawn today has already influenced the code. Nobody should   #
# describe a number measured on it as clean until it has survived a        #
# development cycle it did not participate in.                            #
#                                                                          #
# The honest consequence, worth stating plainly because it affects what    #
# gets said to editors: the best UNCONTAMINATED estimate available today   #
# does not come from this corpus at all. It comes from corpora that have   #
# never driven a fix - medRxiv preprints and PubTables-1M - which is       #
# exactly why Steve's cross-corpus proposal is not merely good hygiene     #
# but the only way to get an honest number right now.                      #
#                                                                          #
# DESIGN                                                                   #
# - Stratified by SOURCE, not simple random: the corpus is five named      #
#   journals plus a large pool of loose PMID files, and a naive draw can   #
#   over-sample one journal's typesetting conventions - which is the very  #
#   thing the parser is fitting to.                                        #
# - Stratified by OUTCOME as well, so the split does not accidentally      #
#   hand the holdout an easier or harder mix than development. The two     #
#   halves start at the same parse rate BY CONSTRUCTION; any later         #
#   divergence is signal.                                                  #
# - Fixed seed, and the result is COMMITTED as corpus/Holdout.csv. A       #
#   split that can be regenerated differently is not a holdout. Only PDF   #
#   names and PMIDs are written - no copyrighted content.                  #
#                                                                          #
# Usage:  Rscript corpus/freezeHoldout.R [fraction]     (default 0.25)     #
#         It REFUSES to overwrite an existing Holdout.csv - see below.     #
############################################################################

repo <- "C:/dev/IntegrityAnalysis"
outFile <- file.path(repo, "corpus", "Holdout.csv")

args <- commandArgs(trailingOnly = TRUE)
frac <- if (length(args) >= 1) as.numeric(args[1]) else 0.25

# The refusal is the point. Re-drawing a holdout after seeing results on
# it is how a holdout stops being one - and it would happen by accident,
# from someone re-running a script, not by anyone deciding to cheat.
if (file.exists(outFile)) {
  cat("corpus/Holdout.csv already exists - NOT regenerating.\n")
  cat("A holdout that can be re-drawn is not a holdout. If it genuinely\n")
  cat("must change, delete the file deliberately and record why in\n")
  cat("ISSUES.md, so the next reader knows the split moved.\n")
  h <- utils::read.csv(outFile, stringsAsFactors = FALSE)
  cat("\ncurrent split:", sum(h$SET == "holdout"), "holdout /",
      sum(h$SET == "development"), "development\n")
  quit(status = 0)
}

d <- utils::read.csv(file.path(repo, "corpus", "ParseOutcomes.csv"),
                     stringsAsFactors = FALSE)
cat("corpus:", nrow(d), "articles\n")

# Source stratum: the journal directory when there is one, otherwise the
# loose-PMID pool.
d$SOURCE <- ifelse(grepl("/", d$PDF), sub("/.*$", "", d$PDF), "PMID-pool")
big <- names(which(table(d$SOURCE) >= 20))
d$STRATUM <- paste(ifelse(d$SOURCE %in% big, d$SOURCE, "PMID-pool"),
                   d$OUTCOME, sep = " | ")

set.seed(20260827)                     # the date, so it is not a magic number
d$SET <- "development"
for (s in unique(d$STRATUM)) {
  idx <- which(d$STRATUM == s)
  n <- max(1L, round(length(idx) * frac))
  if (length(idx) < 4) next            # too small to split meaningfully
  d$SET[sample(idx, n)] <- "holdout"
}

out <- d[, c("PDF", "PMID", "SOURCE", "OUTCOME", "SET")]
utils::write.csv(out, outFile, row.names = FALSE)

cat("\nwritten:", outFile, "\n\n")
tab <- table(out$SET)
cat("development:", tab[["development"]], "\n")
cat("holdout    :", tab[["holdout"]], "\n\n")

rate <- function(x) sprintf("%.1f%%",
  100 * mean(x == "successfully parsed"))
cat("parse rate at the moment of freezing - equal BY CONSTRUCTION,\n")
cat("so any later divergence is signal rather than an artefact of the draw:\n")
cat("  development:", rate(out$OUTCOME[out$SET == "development"]), "\n")
cat("  holdout    :", rate(out$OUTCOME[out$SET == "holdout"]), "\n")
cat("  whole corpus:", rate(out$OUTCOME), "\n\n")
cat("composition by source:\n")
print(table(out$SOURCE, out$SET))
cat("\nFROM NOW ON: develop against SET == \"development\".\n")
cat("Report against SET == \"holdout\", and only after the change is\n")
cat("finished - a holdout consulted during development is a test set.\n")
