# buildAnalysisFrame.R - assemble the registry corpus into a shareable
# analysis frame, with everything identifying held back.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction: "keep author names local ... also keep year, issue,  #
# and page number local, as well as PMID and NCT. Use an assigned          #
# identifier for PMID, just as we are doing for Carlisle corpus. We keep   #
# the cross walk, which we can use for auditing, or share with             #
# investigators."                                                          #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# THE PRINCIPLE, which is Steve's and predates this script: a table that   #
# joins an identifiable trial to a baseline-homogeneity p-value is an      #
# implicit accusation with no right of reply. It was his objection to the  #
# identifying tables in Carlisle's 2017 paper, and he applied it to this   #
# project's own EndToEndValidation.csv before applying it here.            #
#                                                                          #
# WHAT IS HELD BACK, AND WHY EACH ONE                                      #
#   NCT, PMID   - direct identifiers.                                      #
#   authors     - MORE identifying than a PMID, not less.                  #
#   year, issue, pages - a journal plus a volume, issue and page range     #
#                 resolves to one paper. Individually innocuous, jointly a #
#                 citation.                                                #
#   TITLE       - added to the local tier on the same logic, which Steve   #
#                 did not name but which follows: pasting a title into     #
#                 PubMed returns the authors, the journal and the trial in #
#                 one step. It identifies MORE completely than the fields  #
#                 he listed, so holding those and publishing this would be #
#                 incoherent.                                              #
#                                                                          #
# WHAT IS PUBLISHED, and why it is enough                                  #
#   TRIAL_ID, PUB_ID, journal, discipline, phase, model, masking, sponsor  #
#   class, enrolment, arms, rows, and the p-value.                         #
#                                                                          #
# JOURNAL STAYS. It is the axis a calibration paper wants - "do baseline   #
# p-value distributions differ across journals" is a question about        #
# editorial process, and a journal publishes thousands of papers, so       #
# naming it identifies no one.                                             #
#                                                                          #
# TWO ID NAMESPACES, deliberately not one. TR- keys a trial (by NCT),      #
# PUB- keys a publication (by PMID). A trial and the paper reporting it    #
# are different objects; linking them should require the crosswalk rather  #
# than fall out of the identifiers.                                        #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/buildAnalysisFrame.R [corpusDir]                        #
############################################################################

args      <- commandArgs(trailingOnly = TRUE)
corpusDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
root      <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
source(file.path(root, "corpus", "pseudonymize.R"))
idDir <- iaIdDir(root)
dir.create(idDir, recursive = TRUE, showWarnings = FALSE)

rd <- function(f) {
  p <- file.path(corpusDir, f)
  if (!file.exists(p)) { cat("  (missing:", f, ")\n"); return(NULL) }
  utils::read.csv(p, colClasses = "character")
}

scr <- rd("screened.csv")        # NCT, PHASES, MODEL, ARMS, ROWS, VETO, STATUS, P
md  <- rd("trialMetadata.csv")   # discipline, sponsor, enrolment, PMID, ...
pm  <- rd("pubmedMetadata.csv")  # journal, year, type, n_authors, title
if (is.null(scr) || is.null(md))
  stop("need screened.csv and trialMetadata.csv", call. = FALSE)
cat("screened:", nrow(scr), " metadata:", nrow(md),
    " pubmed:", if (is.null(pm)) 0 else nrow(pm), "\n")

# One row per trial: the screen's verdict plus the registry's covariates.
d <- merge(scr, md, by = "NCT", all.x = TRUE, suffixes = c("", ".md"))
if (!is.null(pm)) d <- merge(d, pm, by = "PMID", all.x = TRUE)

d$TRIAL_ID <- iaPseudonym(d$NCT, root, prefix = "TR")
d$PUB_ID   <- iaPseudonym(d$PMID, root, prefix = "PUB")

# ---- the two tiers -------------------------------------------------------
IDENTIFYING <- c("NCT", "PMID", "TITLE", "YEAR", "CITATION_VOLUME",
                 "CITATION_ISSUE", "CITATION_PAGES", "AUTHORS",
                 "CONDITIONS", "MESH", "ANCESTORS", "START", "COMPLETION")
# CONDITIONS/MESH/START are held too: a rare condition plus a start date
# plus a journal narrows to a handful of trials, which is identification
# by another route. DISCIPLINE survives as the coarse, safe version.

share <- d[, setdiff(names(d), IDENTIFYING), drop = FALSE]
share <- share[, c("TRIAL_ID", "PUB_ID",
                   setdiff(names(share), c("TRIAL_ID", "PUB_ID"))),
               drop = FALSE]
# Shuffle: publishing pseudonyms in registry order leaks the mapping to
# anyone who can reproduce that order. Seeded from the secret salt.
set.seed(strtoi(substr(iaIdSalt(root), 1, 6), 16L) %% .Machine$integer.max)
share <- share[sample(nrow(share)), , drop = FALSE]

xref <- d[, intersect(c("TRIAL_ID", "PUB_ID", IDENTIFYING), names(d)),
          drop = FALSE]

outShare <- file.path(corpusDir, "analysisFrame.csv")
utils::write.csv(share, outShare, row.names = FALSE)
utils::write.csv(xref, file.path(idDir, "ctgovCrosswalk.csv"), row.names = FALSE)

cat("\n================ ANALYSIS FRAME ================\n")
cat("rows                :", nrow(share), "\n")
cat("columns (shareable) :", paste(names(share), collapse = ", "), "\n")
cat("\nheld back to", idDir, ":\n  ",
    paste(intersect(IDENTIFYING, names(d)), collapse = ", "), "\n")
scrOnly <- share[share$STATUS == "screened" & !is.na(share$P) & nzchar(share$P), ]
cat("\ntrials with a p-value:", nrow(scrOnly), "\n")
if (nrow(scrOnly)) {
  p <- suppressWarnings(as.numeric(scrOnly$P)); p <- p[!is.na(p)]
  cat(sprintf("  p<0.05 %.1f%%   p>0.95 %.1f%%   median %.3f\n",
              100 * mean(p < .05), 100 * mean(p > .95), stats::median(p)))
}
cat("\nshareable :", outShare, "\n")
cat("crosswalk :", file.path(idDir, "ctgovCrosswalk.csv"), "  (LOCAL ONLY)\n")
