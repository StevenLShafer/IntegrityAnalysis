# regressionReport.R - did this refinement break anything that worked?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-27 by Claude Code (model Claude Opus 5), from Steve      #
# Shafer's statement of the problem:                                       #
#                                                                          #
#   "The fact that a parser built from a corpus works well on the corpus   #
#    isn't a good test... It's like saying that a model is great because   #
#    it predicts the data from which it was derived. It should, or         #
#    something wrong happened during the derivation. The actual test is    #
#    how well it works on data that were not used in training... What is   #
#    worth avoiding is having 'refinements' in the parser cause            #
#    significant deterioration in the ability to parse earlier corpora."   #
#                                                                          #
# The last sentence is a DIFFERENT problem from the holdout, and it is     #
# the one nothing in this repository measured. A holdout answers "does     #
# this generalise". It says nothing about whether a fix broke articles     #
# that used to work.                                                       #
#                                                                          #
# WHY THE HEADLINE NUMBER HIDES IT. Parse rate is an aggregate, and an     #
# aggregate cannot distinguish                                            #
#                                                                          #
#     84.9% -> 85.1%   because 4 more files parse, nothing broke           #
#     84.9% -> 85.1%   because 40 were fixed and 36 were BROKEN            #
#                                                                          #
# Those are very different pieces of work. The second is churn wearing     #
# the costume of progress, and every published parse rate this repository  #
# has quoted could have been either. Only a PER-FILE comparison between    #
# two runs can tell them apart, which is what this does.                   #
#                                                                          #
# NOT A HARD THRESHOLD BY DEFAULT. "Significant deterioration" is a        #
# judgment - a fix that breaks two files while repairing forty may be      #
# right, and a fix that breaks one flagship journal's layout may not be,   #
# even though the count is smaller. So the default behaviour is to REPORT  #
# and to name every broken file, and --max-broken is offered for           #
# automation that needs a gate. A number nobody chose is not a standard.  #
#                                                                          #
# WORKS ON ANY CORPUS. The Carlisle sheet is the default, but the same     #
# comparison applies to the A&A run, the medRxiv corpus and the           #
# PubTables mining outcomes - any table with one row per file and an       #
# outcome column.                                                          #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/regressionReport.R                                      #
#   Rscript corpus/regressionReport.R <current.csv> <baseline.csv>         #
#   Rscript corpus/regressionReport.R ... --max-broken 5                   #
#   Rscript corpus/regressionReport.R --snapshot   (make current the base) #
############################################################################

repo <- "C:/dev/IntegrityAnalysis"
args <- commandArgs(trailingOnly = TRUE)

maxBroken <- NA_integer_
if ("--max-broken" %in% args) {
  i <- which(args == "--max-broken")
  maxBroken <- as.integer(args[i + 1]); args <- args[-c(i, i + 1)]
}
snapshot <- "--snapshot" %in% args
args <- args[args != "--snapshot"]

curFile  <- if (length(args) >= 1) args[1] else
  file.path(repo, "corpus", "ParseOutcomes.csv")
baseFile <- if (length(args) >= 2) args[2] else
  sub("[.]csv$", ".baseline.csv", curFile)

if (!file.exists(curFile)) stop("no current file: ", curFile, call. = FALSE)

if (snapshot) {
  file.copy(curFile, baseFile, overwrite = TRUE)
  cat("snapshot taken:", basename(curFile), "->", basename(baseFile), "\n")
  cat("Future runs compare against this. Take a snapshot when a result is\n")
  cat("ACCEPTED, not merely produced - otherwise the baseline drifts along\n")
  cat("with the code and the comparison always looks clean.\n")
  quit(status = 0)
}

if (!file.exists(baseFile)) {
  cat("No baseline at", basename(baseFile), "\n")
  cat("Create one with:  Rscript corpus/regressionReport.R --snapshot\n")
  quit(status = 0)
}

cur  <- utils::read.csv(curFile,  stringsAsFactors = FALSE)
base <- utils::read.csv(baseFile, stringsAsFactors = FALSE)

# The per-file key and the outcome column, discovered rather than assumed,
# so the same script serves ParseOutcomes, MiningOutcomes and the A&A run.
keyCol <- intersect(c("PDF", "TABLE", "FILE", "KEY"), names(cur))[1]
outCol <- intersect(c("OUTCOME", "STATUS", "VERDICT"), names(cur))[1]
if (is.na(keyCol) || is.na(outCol))
  stop("cannot find a key column and an outcome column", call. = FALSE)
cat("comparing on key '", keyCol, "', outcome '", outCol, "'\n", sep = "")

passed <- function(x) grepl("success|parsed|^ok$", x, ignore.case = TRUE) &
                      !grepl("not success|fail", x, ignore.case = TRUE)

m <- merge(base[, c(keyCol, outCol)], cur[, c(keyCol, outCol)],
           by = keyCol, all = TRUE, suffixes = c(".base", ".cur"))
ob <- m[[paste0(outCol, ".base")]]; oc <- m[[paste0(outCol, ".cur")]]
pb <- passed(ob); pc <- passed(oc)

added   <- is.na(ob) & !is.na(oc)
removed <- !is.na(ob) & is.na(oc)
both    <- !is.na(ob) & !is.na(oc)

fixed  <- both & !pb &  pc
broken <- both &  pb & !pc
stable <- both & (pb == pc)

cat("\n=================== regression report ===================\n")
cat("baseline:", basename(baseFile), " (", sum(!is.na(ob)), "files )\n")
cat("current :", basename(curFile),  " (", sum(!is.na(oc)), "files )\n\n")
rate <- function(v) if (!length(v)) "n/a" else sprintf("%.1f%%", 100*mean(v))
cat("parse rate  baseline:", rate(pb[!is.na(ob)]),
    "  current:", rate(pc[!is.na(oc)]), "\n\n")
cat("  FIXED   (failed -> parses) :", sum(fixed), "\n")
cat("  BROKEN  (parsed -> fails)  :", sum(broken), "   <-- the number that matters\n")
cat("  stable                     :", sum(stable), "\n")
if (any(added))   cat("  new files (not in baseline):", sum(added), "\n")
if (any(removed)) cat("  files gone from current    :", sum(removed), "\n")

net <- sum(fixed) - sum(broken)
cat("\n  net change:", sprintf("%+d", net), "file(s)\n")
if (sum(fixed) + sum(broken) > 0) {
  churn <- sum(fixed) + sum(broken)
  cat("  churn     :", churn, "file(s) changed outcome to move the net by",
      abs(net), "\n")
  if (sum(broken) > 0 && net > 0)
    cat("  (a net gain that costs", sum(broken),
        "working file(s) is a trade, not a free win)\n")
}

if (sum(broken) > 0) {
  cat("\n--- EVERY BROKEN FILE, named so it can be looked at ---\n")
  b <- m[broken, ]
  for (i in seq_len(min(nrow(b), 60))) {
    cat(sprintf("  %-46s %s -> %s\n", substr(b[[keyCol]][i], 1, 46),
                substr(b[[paste0(outCol, ".base")]][i], 1, 22),
                substr(b[[paste0(outCol, ".cur")]][i], 1, 22)))
  }
  if (nrow(b) > 60) cat("  ...and", nrow(b) - 60, "more\n")
  # a regression that clusters in one source is a different bug from one
  # scattered at random, and the clustering is visible for free
  if ("SOURCE" %in% names(cur) || grepl("/", b[[keyCol]][1])) {
    src <- if ("SOURCE" %in% names(cur)) cur$SOURCE[match(b[[keyCol]], cur[[keyCol]])]
           else ifelse(grepl("/", b[[keyCol]]), sub("/.*$", "", b[[keyCol]]), "pool")
    cat("\n  by source:\n"); print(sort(table(src), decreasing = TRUE))
    cat("  (clustering in one source means a layout assumption changed;\n")
    cat("   scattered breakage means something more general moved)\n")
  }
}

if (!is.na(maxBroken) && sum(broken) > maxBroken) {
  cat("\nGATE FAILED:", sum(broken), "broken exceeds --max-broken",
      maxBroken, "\n")
  quit(status = 1)
}
cat("\n")
