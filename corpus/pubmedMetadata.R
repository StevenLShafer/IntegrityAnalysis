# pubmedMetadata.R - journal, year, article type and author count for the
# PMIDs the registry links to its trials.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's suggestion: "you can likely fetch all of the titles and authors #
# from PubMed using the built in connector without downloading the PDF at  #
# all."                                                                    #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY E-UTILITIES RATHER THAN THE MCP CONNECTOR. The connector batches and #
# returns exactly the right fields, and is the better tool for looking up  #
# a handful of articles. For ~25,800 PMIDs it is the wrong shape: every    #
# reply carries full abstracts through the conversation. NCBI's efetch is  #
# what the connector wraps, takes 200 ids per request, and needs about 130 #
# requests for the whole corpus.                                           #
#                                                                          #
# WHAT THIS ADDS THAT THE REGISTRY CANNOT                                  #
#   journal      - the axis a calibration paper actually wants. "Which     #
#                  journals publish trials with extreme baseline           #
#                  p-values" is a question about editorial process, and    #
#                  it is answerable in aggregate without naming a trial.   #
#   year         - publication year, distinct from the trial's start date  #
#   article_type - PubMed indexers mark "Randomized Controlled Trial"      #
#                  INDEPENDENTLY of the registry's allocation field. Where #
#                  the two disagree, one of them is wrong, and that is     #
#                  itself worth knowing.                                   #
#   n_authors    - a count, not names. See below.                          #
#                                                                          #
# AUTHOR NAMES ARE DELIBERATELY NOT WRITTEN TO THE COMMITTED FILE.         #
#                                                                          #
# A table joining author names to baseline-homogeneity p-values is exactly #
# the artefact Steve argued should have been withdrawn from Carlisle's     #
# 2017 paper, and exactly what corpus/pseudonymize.R was written to        #
# prevent for trials. Authors are MORE identifying than a PMID, not less.  #
# So this script writes:                                                   #
#                                                                          #
#   committed tier : PMID, journal, year, type, n_authors                  #
#   local tier     : .NewCarlisle/validation/pubmedAuthors.csv             #
#                                                                          #
# The local file exists because an investigator asking "which trial is      #
# this?" deserves an answer - and because a journal-level finding should   #
# be checkable by someone who can also hear the authors' side of it.       #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/pubmedMetadata.R [metadataCsv] [outDir]                 #
#     metadataCsv  trialMetadata.csv from corpus/ctgovMetadata.R           #
############################################################################

suppressPackageStartupMessages({ library(xml2) })

args   <- commandArgs(trailingOnly = TRUE)
mdCsv  <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus",
            "trialMetadata.csv")
outDir <- if (length(args) >= 2) args[2] else dirname(mdCsv)
root   <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")

if (!file.exists(mdCsv))
  stop("no trialMetadata.csv - run corpus/ctgovMetadata.R first", call. = FALSE)
md <- utils::read.csv(mdCsv, colClasses = "character")
pmids <- unique(md$PMID[!is.na(md$PMID) & nzchar(md$PMID)])
cat("distinct PMIDs to fetch:", length(pmids), "\n")

EFETCH <- "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
chunk <- 200L
pub <- list(); aut <- list()
for (s in seq(1, length(pmids), by = chunk)) {
  ids <- pmids[s:min(s + chunk - 1L, length(pmids))]
  url <- paste0(EFETCH, "?db=pubmed&retmode=xml&id=", paste(ids, collapse = ","))
  x <- tryCatch(xml2::read_xml(url), error = function(e) NULL)
  if (is.null(x)) { Sys.sleep(1); next }
  for (a in xml2::xml_find_all(x, "//PubmedArticle")) {
    g <- function(p) {
      v <- xml2::xml_text(xml2::xml_find_first(a, p)); if (is.na(v)) "" else v
    }
    pmid <- g(".//MedlineCitation/PMID")
    if (!nzchar(pmid)) next
    types <- xml2::xml_text(xml2::xml_find_all(a, ".//PublicationType"))
    au <- xml2::xml_find_all(a, ".//AuthorList/Author")
    last <- xml2::xml_text(xml2::xml_find_all(a, ".//AuthorList/Author/LastName"))
    yr <- g(".//JournalIssue/PubDate/Year")
    if (!nzchar(yr)) yr <- substr(g(".//JournalIssue/PubDate/MedlineDate"), 1, 4)
    pub[[length(pub) + 1L]] <- data.frame(
      PMID = pmid,
      JOURNAL = g(".//Journal/ISOAbbreviation"),
      JOURNAL_FULL = substr(g(".//Journal/Title"), 1, 120),
      YEAR = yr,
      IS_RCT_PUBMED = any(grepl("^Randomized Controlled Trial$", types)),
      N_AUTHORS = length(au),
      TITLE = substr(gsub("[\r\n]+", " ", g(".//ArticleTitle")), 1, 250),
      stringsAsFactors = FALSE)
    # LOCAL TIER ONLY - see the header.
    aut[[length(aut) + 1L]] <- data.frame(
      PMID = pmid, AUTHORS = substr(paste(last, collapse = "; "), 1, 400),
      stringsAsFactors = FALSE)
  }
  cat("\r  fetched", min(s + chunk - 1L, length(pmids)), "of", length(pmids))
  Sys.sleep(0.4)      # NCBI allows 3 requests/second without an API key
}
cat("\n")

p <- do.call(rbind, pub)
utils::write.csv(p, file.path(outDir, "pubmedMetadata.csv"), row.names = FALSE)

idDir <- file.path(root, ".NewCarlisle", "validation")
dir.create(idDir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, aut), file.path(idDir, "pubmedAuthors.csv"),
                 row.names = FALSE)

cat("\n================ PUBMED METADATA ================\n")
cat("articles retrieved :", nrow(p), "of", length(pmids), "requested\n")
cat("marked RCT by PubMed:", sum(p$IS_RCT_PUBMED),
    sprintf("(%.0f%%)\n", 100 * mean(p$IS_RCT_PUBMED)))
cat("\ntop journals:\n")
tb <- sort(table(p$JOURNAL), decreasing = TRUE)
for (k in seq_len(min(12, length(tb))))
  cat(sprintf("  %-42s %4d\n", names(tb)[k], tb[k]))
cat("\npublication years:", min(p$YEAR[nzchar(p$YEAR)], na.rm = TRUE), "-",
    max(p$YEAR[nzchar(p$YEAR)], na.rm = TRUE), "\n")
cat("\nwritten:", file.path(outDir, "pubmedMetadata.csv"), "\n")
cat("author names (LOCAL ONLY):", file.path(idDir, "pubmedAuthors.csv"), "\n")
