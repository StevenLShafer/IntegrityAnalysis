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

# RETRY A BUSY ENDPOINT; DO NOT CALL IT A MOVED ONE.
#
# The control below is right to stop the run - a silently emptied identity
# column is the failure this whole file exists to prevent. But it used to
# stop on ANY failure while asserting a cause it had not checked: "the
# endpoint has moved or changed shape again". On 2026-09-02 the scheduled
# run met HTTP 429 - rate limiting, transient, and nothing to do with the
# endpoint's shape - and reported a move. The identical request succeeded by
# hand minutes later, first attempt.
#
# That is the same defect this repository keeps recording, in the message
# rather than the logic: an error handler that names a cause it never
# established sends the next reader somewhere there is nothing to find.
#
# So: transient failures (429, 5xx, a dropped connection) are retried with
# backoff, and only a persistent failure or a well-formed answer of the
# WRONG SHAPE is treated as the endpoint having changed. The distinction is
# reported, so the message matches what was observed.
# A USABLE answer is a table with ONE RECORD PER REQUESTED ID. The
# converter answers every id it is given - an id it does not know comes
# back as its own record with status "error" (verified against the live
# endpoint 2026-09-02) - so a table shorter than the request is a
# truncated reply, and accepting it would resolve part of a batch while
# the rest went on looking like PMCIDs that genuinely have no PMID
# (CodeRabbit on #143). The check keys on `requested-id`, which the API
# echoes upper-cased whatever case it was asked in.
#
# What is deliberately NOT required is a `pmid` column. A batch in which
# nothing maps comes back without one (2026-09-02: two unknown ids ->
# columns pmcid, requested-id, status, errmsg, and no pmid). The first
# version of this predicate demanded the column and would have stopped
# the whole run on such a batch as a "shape change".
#
# `is.list(r)` first: jsonlite returns an atomic vector for scalar JSON,
# and `$` on one is an error, not a NULL - the diagnostic would never
# have run (CodeRabbit on #143).
idconvOk <- function(r, ids) {
  if (!is.list(r) || !is.data.frame(r$records)) return(FALSE)
  if (!"requested-id" %in% names(r$records)) return(FALSE)
  got <- toupper(r$records[["requested-id"]])
  all(toupper(ids) %in% got) && !anyDuplicated(got)
}

# Name the failure that actually happened, because the remedies differ:
# a transport failure means wait and retry; a malformed or truncated reply
# means go and look at the endpoint. `kind` and `why` are set by
# idconvOnce's error handler; everything else is a well-formed reply of
# the wrong shape, diagnosed in the order idconvOk checks it.
idconvWhy <- function(r, ids) {
  w <- attr(r, "why")
  if (!is.null(w)) return(paste0(attr(r, "kind"), " - ", w))
  if (!is.list(r))
    return(paste0("the reply was not a JSON object (", class(r)[1], ")"))
  if (is.null(r$records))       return("the reply carried no 'records' field")
  if (!is.data.frame(r$records))
    return(paste0("'records' was not a table (", class(r$records)[1], ")"))
  if (!"requested-id" %in% names(r$records))
    return("'records' lacked the 'requested-id' column")
  got  <- toupper(r$records[["requested-id"]])
  miss <- setdiff(toupper(ids), got)
  if (length(miss))
    return(sprintf("the reply covered %d of %d requested ids (missing %s%s)",
                   length(ids) - length(miss), length(ids),
                   paste(head(miss, 3), collapse = ", "),
                   if (length(miss) > 3) ", ..." else ""))
  paste0("the reply repeated an id (",
         paste(head(unique(got[duplicated(got)]), 3), collapse = ", "), ")")
}

# \\b(429|5[0-9]{2})\\b, not 429|50[0-9]: the old pattern matched 500-509
# and stopped, so 510-599 were called permanent and never retried; and
# being unanchored it could fire on any digits that happened to contain
# "429" or "50x" (CodeRabbit on #140).
#
# perl = TRUE IS LOAD-BEARING. grepl() defaults to POSIX ERE, where \b is
# not a word boundary, and the pattern then matches NOTHING - every
# transient failure would be reported as a permanent shape change, the
# exact bug this block was written to fix, only inverted. Caught by
# exercising the pattern against real curl messages before committing.
#
# A MALFORMED BODY IS NOT A TRANSPORT FAILURE. fromJSON raises both from
# the same call, and the handler used to file every error as transport
# (CodeRabbit on #143). jsonlite's parser prefixes each syntax complaint
# with "lexical error:" or "parse error:" (yajl; verified 2026-09-02) and
# curl's messages never do, so the prefix tells them apart. A body that
# was cut off - "premature EOF" - is a dropped connection and is retried;
# any other non-JSON body is a page that is not the API (a redirect, an
# outage notice) and retrying it changes nothing.
idconvOnce <- function(ids)
  tryCatch(jsonlite::fromJSON(paste0(
    idconvUrl, "?tool=IntegrityAnalysis&email=steveshafer@gmail.com",
    "&format=json&ids=", paste(ids, collapse = ","))),
    error = function(e) {
      msg <- gsub("\\s+", " ", conditionMessage(e))   # yajl's is multi-line
      malformed <- grepl("^(lexical|parse) error", msg)
      structure(list(),
        kind = if (malformed) "malformed reply" else "transport failure",
        transient = if (malformed) grepl("premature EOF", msg, fixed = TRUE)
                    else grepl("\\b(429|5[0-9]{2})\\b|timed out|cannot open|connection",
                               msg, ignore.case = TRUE, perl = TRUE),
        why = msg)
    })

idconv <- function(ids, tries = 4L) {
  for (i in seq_len(tries)) {
    r <- idconvOnce(ids)
    if (idconvOk(r, ids)) return(r)
    if (!isTRUE(attr(r, "transient"))) return(r)   # a real shape change
    if (i < tries) {
      message(sprintf("  ID converter attempt %d/%d transient (%s) - retrying",
                      i, tries, substr(attr(r, "why"), 1, 60)))
      Sys.sleep(5 * i)
    }
  }
  structure(r, exhausted = TRUE)   # so the report can say WHICH it was
}

# "after N attempts" only when we actually made them. The old message said
# "FAILED after retries" even for a shape failure, which idconv returns on
# the first call without retrying anything.
ctlId <- "PMC4280683"                  # -> PMID 25433674, verified 2026-08-31
ctl <- idconv(ctlId)
if (!idconvOk(ctl, ctlId))
  stop("ID converter positive control FAILED ",
       if (isTRUE(attr(ctl, "exhausted"))) "after 4 attempts" else "immediately",
       " - ", idconvWhy(ctl, ctlId),
       ". Fix it before trusting any coverage number.")
# The control is one id that DOES map, so here - and only here - a missing
# pmid column is itself the wrong answer.
ctlPmid <- if ("pmid" %in% names(ctl$records))
  as.character(ctl$records$pmid[1]) else "<no pmid column>"
if (!identical(ctlPmid, "25433674"))
  stop("ID converter positive control returned the WRONG ANSWER for ",
       ctlId, ": expected PMID 25433674, got '", ctlPmid,
       "'. The endpoint still answers, so this is a mapping change, not ",
       "an outage.")
message("ID converter positive control passed")

need <- unique(ident$PMCID[blank(ident$PMID) & !blank(ident$PMCID)])
if (length(need)) {
  message(sprintf("asking NCBI to convert %d PMCIDs", length(need)))
  got <- list()
  for (k in seq(1, length(need), by = 200)) {
    ids <- need[k:min(k + 199, length(need))]
    r <- idconv(ids)
    # REFUSE A PARTIAL INDEX. This used to skip a failed batch and carry on,
    # so a converter outage after the positive control passed produced an
    # identity.csv that was quietly short - every unconverted PMCID looking
    # exactly like a PMCID with no PMID, and the coverage number that gets
    # quoted from this file silently understating itself. A run that cannot
    # finish its conversions has to fail loudly, not round down.
    if (!idconvOk(r, ids))
      stop(sprintf(paste0("ID converter failed on the batch starting at %d ",
                          "of %d %s - %s. Refusing to write a partial ",
                          "identity index; re-run when it answers."),
                   k, length(need),
                   if (isTRUE(attr(r, "exhausted"))) "after 4 attempts"
                   else "immediately", idconvWhy(r, ids)))
    # Keyed on requested-id, the column idconvOk guarantees (and the API
    # upper-cases), and tolerant of a batch with no pmid column at all -
    # which is what "none of these 200 map" looks like, not a failure.
    rec <- r$records
    got[[length(got) + 1L]] <- data.frame(
      pmcid = as.character(rec[["requested-id"]]),
      pmid  = if ("pmid" %in% names(rec)) as.character(rec$pmid)
              else NA_character_,
      stringsAsFactors = FALSE)
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
