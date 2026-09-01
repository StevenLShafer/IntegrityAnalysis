# fetchCorpusIdentity.R - fill the RESTRICTED half of the corpus index:
# who published what, where.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-31 by Claude Code (model Claude Opus 5, Anthropic) at    #
# Steve Shafer's direction: "We will have a second list that has the       #
# PMID, Journal, issue and page, Title, and Authors."                      #
#                                                                          #
# Runs after buildCorpusLibrary.R, which writes index/identity.csv with    #
# the identifiers it could read off filenames and local manifests. This    #
# script resolves the rest from NCBI and fills in the bibliographic        #
# columns that only NCBI has.                                              #
#                                                                          #
# Status: run 2026-08-31; coverage recorded in index/BUILD.json.           #
############################################################################
#
# WHY THIS IS A SEPARATE FILE, AND A SEPARATE SCRIPT. index/master.csv is
# the half that may circulate: accessions, formats, hashes, licences,
# provenance, and nothing that names a paper. index/identity.csv is the
# half that turns an accession back into an accusation, and it is the one
# that stays here. Keeping them in different files - written by different
# scripts, at different times - means "send Adrian the index" cannot
# accidentally mean "send Adrian the crosswalk".
#
# WHY PMCID -> PMID NEEDS A LOOKUP. The PMC bulk download names files by
# PMCID, and 11,524 of our works arrived that way. A PMCID is not derivable
# from a PMID; the mapping is a fact held by NCBI. We already have 24,542
# of those pairs from the clinicaltrials.gov linkage work, so the local
# table is tried first and the network is only asked about what is left.

suppressWarnings(suppressPackageStartupMessages({
  library(xml2); library(jsonlite)
}))

corpusRoot <- Sys.getenv("INTEGRITY_CORPUS", "C:/dev/Corpus")
repoRoot   <- Sys.getenv("INTEGRITY_ROOT",   "C:/dev/IntegrityAnalysis")
indexDir   <- file.path(corpusRoot, "index")
staging    <- file.path(corpusRoot, "_staging")
apiKey     <- Sys.getenv("ENTREZ_KEY", "")

ident <- utils::read.csv(file.path(indexDir, "identity.csv"),
                         colClasses = "character")
# blank() is the local name for the shared iaBlankKey() - kept because
# eight tests below read better with it, and because a rename would have
# made this audit's diff about something other than the joins.
source(file.path(repoRoot, "corpus", "safeMatch.R"))
blank <- iaBlankKey

# safeMatch - match() that refuses to join on a missing key.
#
# THIS EXISTS BECAUSE THE OBVIOUS VERSION SILENTLY CORRUPTED THE INDEX.
# pmidToPmcid.csv holds 24,541 rows of which 11,428 have an EMPTY PMCID
# (they are PMIDs with no PMC record). A plain match(ident$PMCID,
# m$PMCID) with an NA on the left finds the first NA on the right and
# returns its position - so every work without a PMCID, including all
# 3,149 confidential A&A manuscripts, was assigned one unrelated paper's
# PMID. EFetch then dutifully filled in that paper's journal, title and
# authors, and the coverage report said 17,035/17,035: a perfect score,
# entirely wrong.
#
# The lesson is narrower than "check your joins". The positive controls
# above test that the ENDPOINT works. They cannot test that the KEYS are
# right, because a healthy API answers a wrong question just as happily
# as a right one. Coverage that rises to 100% is a red flag, not a
# success - see the negative control at the end of this script.
# (The definition itself now lives in corpus/safeMatch.R, sourced above.
# It was hand-copied here from buildCorpusLibrary.R on 2026-08-31; the
# 2026-09-01 join audit found five more scripts that needed it, at which
# point a third transcription would have been the defect, not the fix.)

# Which accessions arrived here ALREADY carrying a PMID, before this
# script touched anything. The negative control at the end compares
# against this, so that a legitimately-known PMID is not mistaken for a
# leaked one.
identifiedAtBuild <- ident$ACCESSION[!blank(ident$PMID)]

## ---------------------------------------------------------------------
## 1. PMCID -> PMID from the table we already hold
## ---------------------------------------------------------------------
map <- file.path(staging, "ctgov", "pmidToPmcid.csv")
if (file.exists(map)) {
  m <- utils::read.csv(map, colClasses = "character")
  # The stored PMCIDs have carried a "pmcid:" prefix before (the bug that
  # produced three silent NCBI failures in August), so normalise both
  # sides rather than trusting either.
  norm <- function(x) toupper(sub("^pmcid:", "", trimws(x)))
  i <- safeMatch(norm(ident$PMCID), norm(m$PMCID))
  # A MATCHED ROW IS NOT THE SAME AS A ROW WITH A PMID. safeMatch refuses
  # to join on a blank KEY; it cannot know that the VALUE we are about to
  # copy is itself blank. Without this, a pmidToPmcid.csv row holding a
  # PMCID but no PMID would overwrite a missing PMID with an empty one -
  # which every blank() test downstream reads identically, but which the
  # coverage counter at the end of this script would score as a fill.
  # (2026-09-01 join audit.)
  fill <- blank(ident$PMID) & !is.na(i) & !blank(m$PMID[i])
  ident$PMID[fill] <- m$PMID[i][fill]
  message(sprintf("local PMCID->PMID map filled %d PMIDs", sum(fill)))
}

## ---------------------------------------------------------------------
## 2. Anything still unmatched: ask NCBI's ID converter
## ---------------------------------------------------------------------
# THE ENDPOINT MOVED, AND THE OLD ONE FAILS SILENTLY. The v1.0 path
# under www.ncbi.nlm.nih.gov now answers 301 to
# pmc.ncbi.nlm.nih.gov/tools/idconv/api/v1/articles/, and
# jsonlite::fromJSON does not follow redirects - it parses the redirect
# HTML, finds no $records, and returns nothing. No error is raised, so the
# loop simply resolves zero identifiers and reports success. That is the
# THIRD time an NCBI move has produced a silent zero in this project
# (oa.fcgi 404, an unfollowed 301, a "pmcid:" prefix left in the parsed
# value). Hence the positive control below: a known PMCID whose PMID we
# already know, checked BEFORE the run, so a moved endpoint stops the
# script instead of quietly emptying the column.
idconvUrl <- "https://pmc.ncbi.nlm.nih.gov/tools/idconv/api/v1/articles/"
idconv <- function(ids)
  tryCatch(jsonlite::fromJSON(paste0(
    idconvUrl, "?tool=IntegrityAnalysis&email=steveshafer@gmail.com",
    "&format=json&ids=", paste(ids, collapse = ","))),
    error = function(e) NULL)

ctl <- idconv("PMC4280683")            # -> PMID 25433674, verified 2026-08-31
if (is.null(ctl$records) || !identical(as.character(ctl$records$pmid[1]),
                                       "25433674"))
  stop("ID converter positive control FAILED - the endpoint has moved or ",
       "changed shape again. Fix it before trusting any coverage number.")
message("ID converter positive control passed")

need <- unique(ident$PMCID[blank(ident$PMID) & !blank(ident$PMCID)])
if (length(need)) {
  message(sprintf("asking NCBI to convert %d PMCIDs", length(need)))
  got <- list()
  for (k in seq(1, length(need), by = 200)) {
    ids <- need[k:min(k + 199, length(need))]
    r <- idconv(ids)
    if (!is.null(r$records))
      got[[length(got) + 1L]] <- r$records[, intersect(c("pmcid", "pmid"),
                                                       names(r$records)), drop = FALSE]
    Sys.sleep(0.2)
    if (k %% 2000 == 1) message(sprintf("  %d/%d", k, length(need)))
  }
  if (length(got)) {
    # !is.na() is not enough: the converter answers with an empty pmid
    # field for a PMCID it knows but cannot map, and "" would be counted
    # as a fill. Same reasoning as the local-map branch above.
    g <- do.call(rbind, got); g <- g[!blank(g$pmid), , drop = FALSE]
    i <- safeMatch(toupper(ident$PMCID), toupper(g$pmcid))
    fill <- blank(ident$PMID) & !is.na(i) & !blank(g$pmid[i])
    ident$PMID[fill] <- g$pmid[i][fill]
    message(sprintf("  converter filled %d more", sum(fill)))
  }
}

## ---------------------------------------------------------------------
## 3. EFetch the bibliographic record
## ---------------------------------------------------------------------
# Journal, volume, issue, pages, title, authors. Only EFetch has volume/
# issue/pages - the local pubmedMetadata.csv stopped at journal and year.
pmids <- unique(ident$PMID[!blank(ident$PMID)])
message(sprintf("fetching %d PubMed records", length(pmids)))

fetchBatch <- function(ids) {
  url <- paste0("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi",
                "?db=pubmed&retmode=xml&id=", paste(ids, collapse = ","),
                if (nzchar(apiKey)) paste0("&api_key=", apiKey) else "")
  # NOBLANKS only - the same safe-option rule as R/parseJats.R. NCBI is a
  # trusted source, but "trusted" is not a parser setting.
  doc <- tryCatch(xml2::read_xml(url, options = "NOBLANKS"),
                  error = function(e) NULL)
  if (is.null(doc)) return(NULL)
  arts <- xml2::xml_find_all(doc, ".//PubmedArticle")
  if (!length(arts)) return(NULL)
  one <- function(a) {
    g <- function(xp) {
      v <- xml2::xml_text(xml2::xml_find_first(a, xp))
      if (length(v) && !is.na(v)) v else NA_character_
    }
    au <- xml2::xml_find_all(a, ".//AuthorList/Author")
    names <- vapply(au, function(x) {
      l <- xml2::xml_text(xml2::xml_find_first(x, "./LastName"))
      i <- xml2::xml_text(xml2::xml_find_first(x, "./Initials"))
      c <- xml2::xml_text(xml2::xml_find_first(x, "./CollectiveName"))
      if (!is.na(l)) paste(l, ifelse(is.na(i), "", i)) else
        if (!is.na(c)) c else NA_character_
    }, character(1))
    names <- names[!is.na(names)]
    data.frame(
      PMID = g(".//PMID"),
      JOURNAL = g(".//Journal/ISOAbbreviation"),
      JOURNAL_FULL = g(".//Journal/Title"),
      YEAR = g(".//JournalIssue/PubDate/Year"),
      VOLUME = g(".//JournalIssue/Volume"),
      ISSUE = g(".//JournalIssue/Issue"),
      PAGES = g(".//Pagination/MedlinePgn"),
      TITLE = g(".//ArticleTitle"),
      AUTHORS = if (length(names)) paste(names, collapse = "; ") else NA_character_,
      stringsAsFactors = FALSE)
  }
  do.call(rbind, lapply(arts, one))
}

# The same discipline for EFetch: one record we know the answer to. If
# NCBI changes the XML shape, this stops the run rather than writing 17,000
# rows of NA and calling it coverage.
# Check the VALUES, not a substring of one of them. The first version of
# this control matched "Cardiovasc" against JOURNAL_FULL and failed on a
# correct record, because NCBI stores that title lower-case ("BMC
# cardiovascular disorders"). A control that cries wolf gets deleted, and
# then the silent failure it existed to catch comes back.
#
# ISSUE is deliberately NOT required: BMC and many online-only journals
# publish without one, and this very record has none. Requiring it would
# make the control fail on the majority of modern articles.
ctl <- fetchBatch("25433674")
ok <- !is.null(ctl) &&
      identical(ctl$PMID[1], "25433674") &&
      identical(ctl$VOLUME[1], "14") &&
      identical(ctl$PAGES[1], "172") &&
      grepl("Pozehl", ctl$AUTHORS[1], fixed = TRUE) &&
      nzchar(ctl$TITLE[1])
if (!ok)
  stop("EFetch positive control FAILED - shape changed. Got: ",
       paste(utils::capture.output(print(ctl)), collapse = " | "))
message("EFetch positive control passed: ", ctl$JOURNAL[1], " ",
        ctl$VOLUME[1], "(", ctl$ISSUE[1], "):", ctl$PAGES[1])

out <- list(); t0 <- Sys.time()
for (k in seq(1, length(pmids), by = 200)) {
  ids <- pmids[k:min(k + 199, length(pmids))]
  r <- fetchBatch(ids)
  if (!is.null(r)) out[[length(out) + 1L]] <- r
  # With a key NCBI allows 10 requests/second; one every 0.15 s is well
  # inside that and leaves headroom for the other boxes.
  Sys.sleep(if (nzchar(apiKey)) 0.15 else 0.4)
  if ((k - 1) %% 2000 == 0)
    message(sprintf("  %d/%d  (%.0f s)", k, length(pmids),
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
bib <- if (length(out)) do.call(rbind, out) else NULL

if (!is.null(bib)) {
  bib <- bib[!duplicated(bib$PMID), ]
  i <- safeMatch(ident$PMID, bib$PMID)
  for (col in c("JOURNAL", "JOURNAL_FULL", "YEAR", "VOLUME", "ISSUE",
                "PAGES", "TITLE", "AUTHORS")) {
    v <- bib[[col]][i]
    ident[[col]] <- ifelse(is.na(v), ident[[col]], v)
  }
  message(sprintf("resolved %d of %d PubMed records", nrow(bib), length(pmids)))
}

## ---------------------------------------------------------------------
## 4. NEGATIVE CONTROL - refuse to write an index that resolved too much
## ---------------------------------------------------------------------
# The positive controls prove the endpoints answer. This proves we asked
# about the right papers, and it is the check that would have caught the
# NA-join described at the top of this file.
#
# The invariant: a work with NO identifier of any kind cannot acquire a
# PMID. The A&A peer-review manuscripts are unpublished and have no PMID,
# PMCID or DOI - if any of them comes out of this script named, the join
# is matching on a missing key and every downstream number is fiction.
#
# This aborts BEFORE writing, because a contaminated identity.csv is
# worse than no identity.csv: it is confidently wrong, and it is the file
# that decides which real author gets attached to which accession.
anon <- blank(ident$PMCID) & blank(ident$DOI) &
        !(ident$ACCESSION %in% identifiedAtBuild)
leaked <- sum(anon & !blank(ident$PMID))
if (leaked > 0)
  stop("NEGATIVE CONTROL FAILED: ", leaked, " work(s) with no PMCID, no ",
       "DOI and no PMID at build time now carry a PMID. A join is ",
       "matching on a missing key. NOTHING WAS WRITTEN.")
message(sprintf("negative control passed: %d anonymous works stayed anonymous",
                sum(anon)))

ident <- ident[order(ident$ACCESSION), ]
utils::write.csv(ident, file.path(indexDir, "identity.csv"), row.names = FALSE)

cov <- function(x) sum(!blank(x))
message("=== identity coverage ===")
for (col in c("PMID", "PMCID", "DOI", "JOURNAL", "VOLUME", "ISSUE",
              "PAGES", "TITLE", "AUTHORS"))
  message(sprintf("  %-12s %6d / %d", col, cov(ident[[col]]), nrow(ident)))
