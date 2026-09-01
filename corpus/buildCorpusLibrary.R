# buildCorpusLibrary.R - coalesce every scattered test and development
# corpus into ONE accession-numbered master library.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-31 by Claude Code (model Claude Opus 5, Anthropic) at    #
# Steve Shafer's direction: "The test and development corpora are          #
# currently scattered all over this computer... If we are going to         #
# collaborate with Adrian, we can't have this scattered set of files.      #
# Please coalesce into a single corpora with a master index and a logical  #
# tree. Papers should be assigned our own access numbers to preserve       #
# confidentiality."                                                        #
#                                                                          #
# And, after the A&A peer-review holdings were flagged: "Put them in the   #
# master index, but marked 'not sharable.' Move them to the master         #
# corpus. The master corpus itself is never shared. We extract and share   #
# only what the master index permits."                                     #
#                                                                          #
# That last sentence is the whole architecture. The library is not a       #
# shareable artefact with sensitive parts carved out; it is a complete     #
# private archive plus an index that DECIDES what may be extracted. See    #
# extractShareable.R for the extraction side.                              #
#                                                                          #
# Status: run 2026-08-31, output verified against the source inventory     #
# (counts per source recorded in index/BUILD.json).                        #
############################################################################
#
# WHAT THIS SOLVES. Before today the same paper could exist as
# C:/temp/Journals/Anaesthesia/2003/1.2.pdf, as
# C:/temp/Journals/PMID_12492668.pdf, and as
# _staging/pmc_corpus/xml/PMC154321.xml, with nothing linking the three.
# The XML-vs-PDF cross-check Steve wants is a JOIN, and there was no key
# to join on. After this script the three are one accession, and
# master/pdf/IA004512.pdf and master/xml/IA004512.xml are the same work
# BY CONSTRUCTION - the filename is the key.
#
# WHY HARD LINKS. Every source lives on C:, so file.link() gives a second
# NAME for the same bytes: instant, no extra disk for ~30 GB, and deleting
# either name is safe (the data survives while any name remains). Where a
# link is impossible (different volume, or a filesystem that refuses) the
# code falls back to a copy and records which happened, because "is this a
# link or a copy?" changes what deleting the original does.
#
# WHY THE ACCESSION IS ASSIGNED IN RANDOM ORDER. A sequential number
# assigned in scan order would leak exactly what the pseudonym is meant to
# hide: IA000001-IA001865 would obviously be the Carlisle journals set, and
# an outsider holding a directory listing could invert much of the map from
# order alone. pseudonymize.R randomises row order for the same reason and
# says so at length. The assignment is persisted in index/accessions.csv so
# it is STABLE across reruns; new works append.

suppressWarnings(suppressPackageStartupMessages({
  library(digest); library(jsonlite)
}))

corpusRoot <- Sys.getenv("INTEGRITY_CORPUS", "C:/dev/Corpus")
repoRoot   <- Sys.getenv("INTEGRITY_ROOT",   "C:/dev/IntegrityAnalysis")
staging    <- file.path(corpusRoot, "_staging")
indexDir   <- file.path(corpusRoot, "index")
masterDir  <- file.path(corpusRoot, "master")

## ---------------------------------------------------------------------
## 1. THE LICENCE VOCABULARY
## ---------------------------------------------------------------------
# SHARE is the single column that governs everything downstream. It is a
# property of the LICENCE plus the acquisition route, not of the file
# format. Two booleans are derived from it because they answer the two
# questions that actually get asked:
#
#   FILE_SHAREABLE    may the FILE ITSELF be sent to a collaborator?
#   DERIVED_SHAREABLE may a PARSED TABLE or statistic derived from it be?
#
# The distinction matters. A subscription PDF cannot be redistributed, but
# the mean and SD printed in its Table 1 are facts, and facts are not
# copyrightable - so restricted material can still contribute to a
# published analysis. Confidential peer-review manuscripts are different
# in kind: there the CONTENT is the confidence, so neither the file nor a
# per-item derived row may leave. Only aggregate statistics may.
licenceTable <- data.frame(
  LICENCE = c("CC0", "CC BY", "CC BY-SA", "US Gov public domain",
              "CC BY-NC", "CC BY-NC-SA",
              "CC BY-ND", "CC BY-NC-ND",
              "TDM", "none", "subscription", "unknown",
              "ctgov posted document",
              "confidential peer review"),
  SHARE = c(rep("public", 4),
            rep("noncommercial", 2),
            rep("verbatim-only", 2),
            rep("restricted", 5),
            "confidential"),
  stringsAsFactors = FALSE)

shareRule <- function(share)
  data.frame(
    FILE_SHAREABLE    = share %in% c("public", "noncommercial", "verbatim-only"),
    DERIVED_SHAREABLE = share != "confidential",
    stringsAsFactors  = FALSE)

## ---------------------------------------------------------------------
## 2. THE SOURCE REGISTRY - provenance at collection level
## ---------------------------------------------------------------------
# "Where, exactly, did it come from?" is answered in two places: here for
# the collection (who published it, how it was retrieved, when), and per
# file in master.csv (the exact original path and its SHA-256). Both are
# needed - the collection row explains the ROUTE, the file row proves the
# BYTES.
# ROLE separates the two kinds of thing a source can hold.
#
#   "work"       articles. One accession each, filed by format under
#                master/, identity held separately.
#   "collection" reference DATA about articles - the ClinicalTrials.gov
#                baseline extract, Carlisle's published supplement. These
#                are not papers and must not be accessioned: an accession
#                number on baselineContinuous.csv would be meaningless,
#                and worse, it would put a 68 MB table into the same
#                namespace as the articles it describes. They keep their
#                real filenames under registry/ and are listed in
#                collections.csv.
src <- function(id, path, pattern, origin, retrieved, method, licence,
                identity = "", note = "", recursive = TRUE, role = "work")
  data.frame(SOURCE_ID = id, PATH = path, PATTERN = pattern,
             RECURSIVE = recursive, ROLE = role, ORIGIN = origin,
             RETRIEVED = retrieved, METHOD = method,
             LICENCE_DEFAULT = licence, IDENTITY = identity, NOTE = note,
             stringsAsFactors = FALSE)

sources <- rbind(
  src("pmc-oa", file.path(staging, "pmc_corpus"), "[.](xml|pdf|txt)$",
      "PubMed Central Open Access / Author Manuscript collections, AWS S3 bucket pmc-oa-opendata",
      "2026-08-31", "fetchPmc.sh on oldryzen, streamed to this host by tar over ssh",
      "per-file", "pmc-manifest",
      "10,325 articles reached from the clinicaltrials.gov PMID linkage. Licence is per article from the PMC metadata JSON, not a collection default."),

  src("ctgov-docs", file.path(staging, "ctgov_docs"), "[.]pdf$",
      "ClinicalTrials.gov posted documents (protocols, statistical analysis plans, informed consent forms), submitted by sponsors under FDAAA and published on the NIH registry site",
      "2026-08-30", "downloadCtgovDocs.R on surface, streamed to this host by tar over ssh",
      "ctgov posted document", "ctgov-doc-manifest",
      "3,000 documents across 2,246 NCTs (1,993 Prot_SAP, 919 Prot, 88 ICF). UNIQUELY USEFUL because the filename IS the NCT, so these join straight onto the registry baseline tables in registry/ctgov - a protocol states the planned analysis while the results section reports what was found, which is a comparison no other collection here supports. Marked RESTRICTED rather than public: the registry RECORD is a US Government work, but these documents are authored by the sponsors and merely hosted, so we do not own a licence to redistribute them. That costs a collaborator nothing - anyone can download them from ClinicalTrials.gov with the NCT, and the NCT list is shareable."),

  src("carlisle-journals", "C:/temp/Journals", "[.]pdf$",
      "Publisher web sites (Anaesthesia, Anesthesiology, CJA, JAMA, BJA, EJA), downloaded under Stanford institutional subscription",
      "2025 to 2026-08", "manual and scripted download by Steve Shafer",
      "subscription", "pmid-map",
      "The 1,865-article Carlisle corpus. <journal>/<year>/<issue.article>.pdf plus PMID_*.pdf at the top level; pmid_map.csv links the first naming to PMIDs. This is the ONLY corpus with printed-value ground truth."),

  src("aa-peer-review", "C:/temp/AA", "[.]pdf$",
      "Anesthesia & Analgesia editorial system (Editorial Manager), submissions handled by Steve Shafer as Editor-in-Chief",
      "2008 to 2016", "editorial download",
      "confidential peer review", "none",
      "UNPUBLISHED MANUSCRIPTS UNDER CONFIDENTIAL PEER REVIEW. Never shareable, file or derived row. Held for population realism: what actually arrives at a journal. All 6,328 carry AA-D-* manuscript numbers."),

  src("rct-screen-holdout", "C:/temp/AA_holdout", "[.]pdf$",
      "PubMed Central, selected as the frozen holdout for the RCT-screening classifier",
      "2026-08", "scripted PMC download", "unknown", "screen-manifest",
      "pos/ and neg/ subdirectories are the classifier labels; manifest.json carries pmcid, pmid, doi and label."),

  src("rct-screen-validation", "C:/temp/AA_validation", "[.]pdf$",
      "PubMed Central, selected as the validation split for the RCT-screening classifier",
      "2026-08", "scripted PMC download", "unknown", "screen-manifest",
      "Companion to the holdout split."),

  src("medrxiv", "C:/temp/medrxiv_rct", "[.]pdf$",
      "medRxiv preprint server, via its AWS S3 requester-pays bucket",
      "2026-08", "harvestMedrxivS3.R", "unknown", "medrxiv-manifest",
      "Preprints, DOI-named. Licence varies per preprint and is only known for the 72 rows in manifest.csv. Has never driven a parser fix, so it is one of the two uncontaminated corpora."),

  src("medrxiv-smoke", "C:/temp/medrxiv_smoketest", "[.]pdf$",
      "medRxiv preprint server, via its AWS S3 requester-pays bucket",
      "2026-08", "harvestMedrxivS3.R smoke test", "unknown", "medrxiv-manifest",
      "Ten-file smoke test for the harvester."),

  src("newcarlisle", file.path(repoRoot, ".NewCarlisle"), "[.]pdf$",
      "Publisher web sites, the prioritised manual download queue built after the automated routes were exhausted",
      "2026-08", "manual download by Steve Shafer, a handful a day",
      "subscription", "newcarlisle-manifest",
      "The extension corpus beyond Carlisle 2017. manifest.csv holds 5,084 targets; 21 files retrieved so far."),

  src("shafer-studies", "C:/temp/Shafer studies", "[.](docx|xlsx|pdf)$",
      "Manuscript drafts and published versions of trials Steve Shafer co-authored (the vocacapsaicin postsurgical-pain programme), plus hand-built Table 1 fixtures",
      "2023 to 2024", "author's own files",
      "subscription", "none",
      "The ONLY .docx and .xlsx article material in the library, which is why it is here: the parser accepts both formats (issues 17 and 19) and every other collection is PDF or XML. RESTRICTED, not confidential - Steve is an author rather than an editor holding someone else's confidence - but several are unpublished drafts under submission, so co-authors have an interest and they do not leave this machine."),

  src("regression-fixtures", file.path(repoRoot, "corpus"), "[.]pdf$",
      "Drawn from the Carlisle corpus as named regression fixtures",
      "2026-08", "selected by hand for buildTestSet.R", "subscription", "filename-pmid",
      "Test1..Test6 pin one named parser defect each (clean, missing N, categorical, skipped lines, scanned, poppler hang), plus the 61 articles in corpus/TEST used during parser development. RECURSIVE ON PURPOSE: the first version of this source set recursive = FALSE and silently collected only the 7 top-level files, leaving the whole TEST directory out of the library - which is exactly the kind of omission the audit was asked to find.",
      recursive = TRUE),

  src("carlisle-tables", repoRoot, "^(Carlisle|One Sheet).*[.]xlsx$",
      "John Carlisle's published supplementary data (Anaesthesia 2017;72:944-952) plus Steve Shafer's PMID and DOI resolutions",
      "2017 to 2026-08", "published supplement, then manual identifier resolution",
      "subscription", "none",
      "The printed-value ground truth for the Carlisle corpus. Spreadsheets, not articles - indexed as data, not as works.",
      recursive = FALSE, role = "collection"),

  src("ctgov", file.path(staging, "ctgov"), "[.](csv|ndjson)$",
      "ClinicalTrials.gov API v2 (US National Library of Medicine)",
      "2026-08-30", "ctgovMetadata.R / buildCtgovCorpus.R on i5, streamed by tar over ssh",
      "US Gov public domain", "none",
      "47,814 trials with posted baseline results: 178,252 continuous rows and 931,927 categorical rows. A US Government work, so public domain - this is the one collection that is unambiguously redistributable in full.",
      recursive = FALSE, role = "collection")
)

# Split before anything else touches them. Collections never enter the
# accession namespace.
collectionSources <- sources[sources$ROLE == "collection", ]
sources           <- sources[sources$ROLE == "work", ]

## ---------------------------------------------------------------------
## 3. IDENTITY MAPS - how each source names its papers
## ---------------------------------------------------------------------
# Each source knows its own files by a different natural key: a PMCID in
# the filename, a journal/year/issue path, a DOI with the slash turned
# into an underscore, an opaque manuscript number. These readers turn all
# of them into the same four columns so the dedup step downstream does not
# need to know where anything came from.
# safeMatch - match() that refuses to join on a missing key.
#
# match(NA, table) returns the position of the FIRST NA in table, which
# is a real index, not a miss. Where the right-hand table legitimately
# contains blanks - pmidToPmcid.csv has 11,428 PMIDs with no PMC record,
# manifest.csv has rows for articles never retrieved - that turns every
# unidentified row into a confident, wrong identification. It did exactly
# that on 2026-08-31: all 3,149 anonymous A&A manuscripts were assigned
# one unrelated paper's PMID, and the coverage report read 17,035/17,035.
# Use this for every join whose keys can be missing on either side.
safeMatch <- function(x, table) {
  bl <- function(v) is.na(v) | !nzchar(as.character(v))
  i <- match(x, table)
  i[bl(x)] <- NA_integer_
  i[!is.na(i) & bl(table[i])] <- NA_integer_
  i
}

emptyIdent <- function(n)
  data.frame(PMID = rep(NA_character_, n), PMCID = NA_character_,
             DOI = NA_character_, NCT = NA_character_,
             LICENCE = NA_character_, stringsAsFactors = FALSE)

readIdentity <- function(kind, paths, srcRow) {
  n <- length(paths); out <- emptyIdent(n)
  base <- basename(paths)
  if (kind == "pmc-manifest") {
    # Filename IS the PMCID; the manifest adds the licence, which here is
    # per article and is the difference between shareable and not.
    m <- utils::read.csv(file.path(srcRow$PATH, "manifest.csv"),
                         colClasses = "character")
    out$PMCID <- sub("[.].*$", "", base)
    i <- safeMatch(out$PMCID, m$PMCID)
    # "none" in the PMC metadata means no licence was declared, which is
    # NOT the same as public domain - treat it as restricted.
    out$LICENCE <- ifelse(is.na(i), "unknown", m$LICENSE[i])
  } else if (kind == "pmid-map") {
    # Two namings in one tree. PMID_<digits>.pdf carries its own answer;
    # <journal>/<year>/<n.m>.pdf needs corpus/pmid_map.csv.
    out$PMID <- ifelse(grepl("^PMID_\\d+[.]pdf$", base),
                       sub("^PMID_(\\d+)[.]pdf$", "\\1", base), NA)
    mp <- utils::read.csv(file.path(repoRoot, "corpus", "pmid_map.csv"),
                          colClasses = "character")
    rel <- sub("^.*/Journals/", "", gsub("\\\\", "/", paths))
    i <- safeMatch(tolower(rel), tolower(mp$PDF))
    out$PMID[is.na(out$PMID)] <- mp$PMID[i][is.na(out$PMID)]
  } else if (kind == "screen-manifest") {
    j <- jsonlite::fromJSON(file.path(srcRow$PATH, "manifest.json"))
    key <- tolower(gsub("\\\\", "/", j$path))
    rel <- tolower(sub("^.*/(pos|neg)/", "\\1/", gsub("\\\\", "/", paths)))
    i <- safeMatch(rel, key)
    out$PMCID <- as.character(j$pmcid)[i]
    out$PMID  <- as.character(j$pmid)[i]
    out$DOI   <- as.character(j$doi)[i]
  } else if (kind == "medrxiv-manifest") {
    # DOI-named with the slash replaced: 10.1101_19007195.pdf.
    out$DOI <- sub("_", "/", sub("[.]pdf$", "", base))
    mf <- file.path(srcRow$PATH, "manifest.csv")
    if (file.exists(mf)) {
      m <- utils::read.csv(mf, colClasses = "character")
      i <- safeMatch(out$DOI, m$doi)
      # cc_no means "no Creative Commons licence chosen", i.e. all rights
      # reserved - restricted, not unknown.
      lic <- m$license[i]
      out$LICENCE <- ifelse(is.na(lic), "unknown",
                     ifelse(lic == "cc_no", "none",
                     ifelse(lic == "cc0", "CC0",
                     ifelse(lic == "cc_by", "CC BY",
                     ifelse(lic == "cc_by_nc", "CC BY-NC",
                     ifelse(lic == "cc_by_nd", "CC BY-ND",
                     ifelse(lic == "cc_by_nc_nd", "CC BY-NC-ND", "unknown")))))))
    }
  } else if (kind == "newcarlisle-manifest") {
    out$PMID <- sub("^PMID_(\\d+)[.]pdf$", "\\1", base)
    out$PMID[!grepl("^\\d+$", out$PMID)] <- NA
    m <- utils::read.csv(file.path(srcRow$PATH, "manifest.csv"),
                         colClasses = "character")
    i <- safeMatch(out$PMID, m$PMID)
    out$PMCID <- m$PMCID[i]
  } else if (kind == "ctgov-doc-manifest") {
    # The filename carries the NCT: NCT02692248_Prot_ICF_000.pdf. That is
    # the only identifier these have - a protocol has no PMID and no DOI -
    # and it is the one that matters, because it joins to the registry
    # baseline tables.
    out$NCT <- sub("^(NCT\\d+)_.*$", "\\1", base)
    out$NCT[!grepl("^NCT\\d+$", out$NCT)] <- NA
  } else if (kind == "filename-pmid") {
    out$PMID <- ifelse(grepl("^PMID_\\d+", base),
                       sub("^PMID_(\\d+).*$", "\\1", base), NA)
  }
  out$PMID[!is.na(out$PMID) & !grepl("^\\d+$", out$PMID)] <- NA
  out
}

## ---------------------------------------------------------------------
## 4. SCAN
## ---------------------------------------------------------------------
message("=== scanning sources ===")
scan1 <- function(k) {
  s <- sources[k, ]
  if (!dir.exists(s$PATH)) {
    message(sprintf("  %-22s MISSING (%s)", s$SOURCE_ID, s$PATH)); return(NULL)
  }
  f <- list.files(s$PATH, pattern = s$PATTERN, full.names = TRUE,
                  recursive = s$RECURSIVE, ignore.case = TRUE)
  # The staging tree holds its own manifests; they are provenance, not
  # corpus members, and must not become accessioned "works".
  f <- f[!grepl("/(manifest|pmcStatus|scanState|candidates|s3Manifest)[.](csv|json)$", f)]
  if (!length(f)) { message(sprintf("  %-22s 0 files", s$SOURCE_ID)); return(NULL) }
  ident <- readIdentity(s$IDENTITY, f, s)
  lic <- ifelse(is.na(ident$LICENCE) | ident$LICENCE == "",
                s$LICENCE_DEFAULT, ident$LICENCE)
  message(sprintf("  %-22s %6d files", s$SOURCE_ID, length(f)))
  data.frame(SOURCE_ID = s$SOURCE_ID, ORIGINAL_PATH = f,
             EXT = tolower(tools::file_ext(f)),
             BYTES = file.info(f)$size,
             ident[, c("PMID", "PMCID", "DOI", "NCT")],
             LICENCE = lic, stringsAsFactors = FALSE)
}
files <- do.call(rbind, lapply(seq_len(nrow(sources)), scan1))
message(sprintf("  TOTAL %d files", nrow(files)))

# A SOURCE THAT VANISHES MUST STOP THE BUILD, NOT SHRINK THE INDEX.
# scan1() returns NULL for a missing directory, and everything below
# rewrites master.csv, works.csv and identity.csv from whatever survived -
# so an unplugged drive, a renamed folder, or a node share that did not
# mount would silently delete thousands of works from the index while
# their files sat untouched in master/. That matters more now that this
# runs unattended at 04:00: nobody would see it until a later question
# came back with a smaller answer. Compare against the LAST BUILD and
# refuse to proceed if a source that previously contributed has gone
# quiet. INTEGRITY_ALLOW_SHRINK=1 is the deliberate override, for the
# genuine case of retiring a collection.
priorMaster <- file.path(indexDir, "master.csv")
if (file.exists(priorMaster)) {
  pm <- utils::read.csv(priorMaster, colClasses = "character")
  was <- table(pm$SOURCE_ID)
  now <- table(files$SOURCE_ID)
  lost <- setdiff(names(was), names(now))
  shrunk <- names(was)[!is.na(match(names(was), names(now))) &
                       as.integer(now[names(was)]) < as.integer(was) * 0.9]
  shrunk <- shrunk[!is.na(shrunk)]
  bad <- c(lost, setdiff(shrunk, lost))
  if (length(bad) && !nzchar(Sys.getenv("INTEGRITY_ALLOW_SHRINK"))) {
    for (b in bad)
      message(sprintf("  !! %s: %s files last build, %s now", b, was[b],
                      if (is.na(now[b])) "0 (source MISSING)" else now[b]))
    stop("a source lost more than 10% of its files since the last build. ",
         "NOTHING WAS WRITTEN - the index still describes the last good ",
         "state. Fix the source, or set INTEGRITY_ALLOW_SHRINK=1 if the ",
         "collection is genuinely being retired.")
  }
}

## ---------------------------------------------------------------------
## 5. HASH - the bytes, so provenance is provable and duplicates collapse
## ---------------------------------------------------------------------
# The same article genuinely does live in several trees (a manuscript kept
# both in AA/ and in "AA Peer Review Files for Parsing/", a PDF fetched
# once by PMCID and once by PMID). Hashing is what turns that from a
# double count into one work with two provenance rows.
message("=== hashing (SHA-256) ===")
t0 <- Sys.time()
# HASH CACHE. Re-reading 24 GB every night to re-derive hashes that cannot
# have changed is the difference between a rebuild that can run nightly and
# one that cannot. A cached hash is reused when the path, the byte size AND
# the modification time all match. Size alone would be unsafe - an edit that
# preserves length is exactly the kind of corruption a hash is for.
cacheFile <- file.path(indexDir, "hashCache.csv")
cache <- if (file.exists(cacheFile))
  utils::read.csv(cacheFile, colClasses = "character") else
  data.frame(ORIGINAL_PATH = character(0), BYTES = character(0),
             MTIME = character(0), SHA256 = character(0))
fi <- file.info(files$ORIGINAL_PATH)
files$MTIME <- format(fi$mtime, "%Y-%m-%dT%H:%M:%S")
key  <- paste(files$ORIGINAL_PATH, files$BYTES, files$MTIME)
ckey <- paste(cache$ORIGINAL_PATH, cache$BYTES, cache$MTIME)
hit  <- match(key, ckey)
files$SHA256 <- cache$SHA256[hit]
todo <- which(is.na(files$SHA256))
if (length(todo))
  files$SHA256[todo] <- vapply(files$ORIGINAL_PATH[todo], function(p)
    tryCatch(digest::digest(file = p, algo = "sha256"),
             error = function(e) NA_character_), character(1), USE.NAMES = FALSE)
# A FAILED HASH CANNOT BE TOLERATED, because of what it does two steps
# later. An anonymous file with no PMID/PMCID/DOI falls back to
# paste0("sha:", SHA256) for its work key - so every file whose hash
# failed becomes the key "sha:NA", and they all collapse into ONE
# accession. On this corpus that would merge unrelated confidential
# manuscripts under a single number, which is the precise opposite of
# what the accession is for. Stop and name the files instead.
files$HASH_FRESH <- seq_len(nrow(files)) %in% todo
badHash <- which(is.na(files$SHA256))
if (length(badHash)) {
  for (p in head(files$ORIGINAL_PATH[badHash], 10)) message("  !! ", p)
  stop(length(badHash), " file(s) could not be hashed (listed above). ",
       "NOTHING WAS WRITTEN: an unhashable anonymous file would key as ",
       "\"sha:NA\" and collapse with every other such file into one ",
       "accession.")
}
message(sprintf("  %d files: %d cached, %d hashed, %.0f s", nrow(files),
                nrow(files) - length(todo), length(todo),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
utils::write.csv(files[, c("ORIGINAL_PATH", "BYTES", "MTIME", "SHA256")],
                 cacheFile, row.names = FALSE)

## ---------------------------------------------------------------------
## 6. WORK KEY and DEDUP
## ---------------------------------------------------------------------
# Precedence PMID > PMCID > DOI > hash. A work known by a stable public
# identifier keeps ONE accession no matter how many copies or formats
# exist; anything anonymous (the A&A manuscripts) falls back to its
# content hash, which correctly merges byte-identical duplicates and
# correctly separates revisions.
# RESOLVE ALIASES FIRST, OR THE DEDUP SILENTLY FAILS. A PMC file knows
# only its PMCID; a Carlisle journal PDF knows only its PMID. Keyed as
# they arrive, the SAME PAPER gets "pmcid:PMC154321" from one source and
# "pmid:12492668" from the other - two accessions, two halves of one work,
# and the multi-source overlap that is supposed to reveal parser
# disagreement reads as near zero. (It read 18 before this was fixed,
# which was the tell: two collections of the same literature should
# overlap far more than that.)
#
# fetchCorpusIdentity.R does resolve PMCID -> PMID, but it runs AFTER
# accessions are assigned, so it cannot merge what has already been split.
# The mapping has to happen here, before the key is formed. The local
# table covers most of it; anything unresolved simply keeps its PMCID key,
# which is correct - an unmergeable pair is better than a wrong merge.
pmcMap <- file.path(staging, "ctgov", "pmidToPmcid.csv")
if (file.exists(pmcMap)) {
  mp <- utils::read.csv(pmcMap, colClasses = "character")
  nrm <- function(x) toupper(sub("^pmcid:", "", trimws(x)))
  i <- safeMatch(nrm(files$PMCID), nrm(mp$PMCID))
  fill <- is.na(files$PMID) & !is.na(i)
  files$PMID[fill] <- mp$PMID[i][fill]
  message(sprintf("  alias resolution: %d PMCIDs mapped to PMIDs before keying",
                  sum(fill)))
}

files$WORK_KEY <- with(files, ifelse(
  !is.na(PMID),  paste0("pmid:",  PMID),
  ifelse(!is.na(PMCID), paste0("pmcid:", PMCID),
  ifelse(!is.na(DOI),   paste0("doi:",   tolower(DOI)),
                        paste0("sha:",   SHA256)))))

## ---------------------------------------------------------------------
## 7. ACCESSION - stable across reruns, assigned in random order
## ---------------------------------------------------------------------
accFile <- file.path(indexDir, "accessions.csv")
dir.create(indexDir, recursive = TRUE, showWarnings = FALSE)
prior <- if (file.exists(accFile))
  utils::read.csv(accFile, colClasses = "character") else
  data.frame(ACCESSION = character(0), WORK_KEY = character(0),
             FIRST_SEEN = character(0))
today <- format(Sys.Date(), "%Y-%m-%d")
# Backfill, once. Accessions assigned before FIRST_SEEN existed as a column
# carry today's date, which is honest: the library was built today, and
# nothing in it can be shown to have arrived earlier. Do NOT invent an
# earlier date from file timestamps - a PDF downloaded in 2025 and copied
# in 2026 has a modification time that says nothing about when the corpus
# gained it, and a temporal holdout built on a guessed date is worse than
# one built on a coarse but true date.
if (is.null(prior$FIRST_SEEN)) prior$FIRST_SEEN <- rep(today, nrow(prior))
prior$FIRST_SEEN[is.na(prior$FIRST_SEEN) | !nzchar(prior$FIRST_SEEN)] <- today

# MIGRATE PRIOR KEYS THROUGH THE SAME ALIAS MAP. Accessions already
# assigned under a "pmcid:" key must follow the work when that PMCID
# resolves to a PMID, or every merged work would be issued a brand new
# number and its old one would dangle. When two prior accessions turn out
# to be the same work, the LOWER number wins - it is the earlier
# observation, and FIRST_SEEN must reflect the earliest sighting, not the
# rebuild that noticed the duplication.
if (nrow(prior) && exists("mp")) {
  isPmcid <- grepl("^pmcid:", prior$WORK_KEY)
  if (any(isPmcid)) {
    j <- safeMatch(nrm(sub("^pmcid:", "", prior$WORK_KEY[isPmcid])), nrm(mp$PMCID))
    newk <- ifelse(is.na(j), prior$WORK_KEY[isPmcid],
                   paste0("pmid:", mp$PMID[j]))
    moved <- sum(newk != prior$WORK_KEY[isPmcid])
    prior$WORK_KEY[isPmcid] <- newk
    if (moved) message(sprintf("  migrated %d prior accession(s) onto their PMID key",
                               moved))
  }
  dup <- duplicated(prior$WORK_KEY)
  if (any(dup)) {
    o <- order(prior$WORK_KEY, prior$ACCESSION)
    prior <- prior[o, ]
    keepFirst <- !duplicated(prior$WORK_KEY)
    message(sprintf("  %d prior accession(s) retired as duplicates of a merged work",
                    sum(!keepFirst)))
    utils::write.csv(prior[!keepFirst, ],
                     file.path(indexDir, "accessionsRetired.csv"),
                     row.names = FALSE)
    prior <- prior[keepFirst, ]
  }
}
keys <- unique(files$WORK_KEY)
newKeys <- setdiff(keys, prior$WORK_KEY)
if (length(newKeys)) {
  # Fixed seed so a rebuild from scratch reproduces the same assignment,
  # but the ORDER is shuffled so the number does not encode the source.
  set.seed(20260831L)
  newKeys <- sample(newKeys)
  # NUMBER FROM THE HIGHEST EVER ISSUED, NOT FROM THE ROW COUNT.
  #
  # nrow(prior) + 1 was wrong, and it corrupted the index the first time a
  # merge retired anything: pruning 24 duplicate rows made the row count
  # 24 lower than the highest number issued, so the next build reissued
  # IA017012-IA017035 to completely different works. IA017028 ended up
  # naming both a ClinicalTrials.gov protocol and PMID 31891134.
  #
  # An accession is a permanent name for one work. A retired number is
  # retired forever - it is never recycled, precisely because someone may
  # still be holding it. So the ceiling must include the retired file too.
  everIssued <- prior$ACCESSION
  retiredFile <- file.path(indexDir, "accessionsRetired.csv")
  if (file.exists(retiredFile))
    everIssued <- c(everIssued,
                    utils::read.csv(retiredFile, colClasses = "character")$ACCESSION)
  highest <- if (length(everIssued))
    max(as.integer(sub("^IA", "", everIssued))) else 0L
  start <- highest + 1L
  prior <- rbind(prior, data.frame(
    ACCESSION = sprintf("IA%06d", seq(start, length.out = length(newKeys))),
    WORK_KEY = newKeys, FIRST_SEEN = today, stringsAsFactors = FALSE))
}
# An accession naming two works is the one thing this file must never
# contain, so assert it rather than trusting the arithmetic above. It
# already happened once (see the numbering comment); a build that produced
# it again would quietly give two different papers the same name, and the
# only reason it was caught the first time was that the staleness check
# noticed seven master files whose bytes did not match their index row.
dupAcc <- unique(prior$ACCESSION[duplicated(prior$ACCESSION)])
if (length(dupAcc))
  stop("accession collision: ", length(dupAcc), " number(s) assigned to ",
       "more than one work (", paste(head(dupAcc, 5), collapse = ", "),
       "). NOTHING WAS WRITTEN.")
utils::write.csv(prior, accFile, row.names = FALSE)
i <- match(files$WORK_KEY, prior$WORK_KEY)
files$ACCESSION  <- prior$ACCESSION[i]
# FIRST_SEEN is the date the work ENTERED THE LIBRARY, and it never
# changes afterwards. It is what makes a TEMPORAL holdout possible:
# "train on FIRST_SEEN <= X, evaluate on what arrived after X" is a split
# that the code being evaluated genuinely could not have seen, which the
# frozen random holdout in corpus/Holdout.csv cannot claim - those
# articles had already been read and their failures studied when it was
# drawn. Publication year (identity.csv) answers a different question:
# how OLD the science is, not how new the evidence is to us.
files$FIRST_SEEN <- prior$FIRST_SEEN[i]
files$COHORT     <- substr(files$FIRST_SEEN, 1, 7)
message(sprintf("=== %d works, %d files ===", length(keys), nrow(files)))

## ---------------------------------------------------------------------
## 8. SHARE CLASS
## ---------------------------------------------------------------------
files$LICENCE[is.na(files$LICENCE) | files$LICENCE == ""] <- "unknown"
i <- match(files$LICENCE, licenceTable$LICENCE)
files$SHARE <- ifelse(is.na(i), "restricted", licenceTable$SHARE[i])
# A confidential source overrides any licence guess: the constraint comes
# from HOW the file was obtained, not from what the publisher later chose.
files$SHARE[files$SOURCE_ID == "aa-peer-review"] <- "confidential"
files <- cbind(files, shareRule(files$SHARE))

## ---------------------------------------------------------------------
## 9. MATERIALISE - master/<format>/<accession>.<ext>
## ---------------------------------------------------------------------
# One accession, many formats, same stem. That is what makes the XML vs
# PDF comparison a join on filename instead of a fuzzy title match.
message("=== linking into the master tree ===")
files <- files[order(files$ACCESSION, files$EXT, files$SOURCE_ID), ]
files$COPY <- ave(seq_len(nrow(files)),
                  paste(files$ACCESSION, files$EXT), FUN = seq_along)
files$MASTER_PATH <- with(files, file.path(
  masterDir, EXT, ifelse(COPY == 1L,
                         sprintf("%s.%s", ACCESSION, EXT),
                         sprintf("%s.c%d.%s", ACCESSION, COPY, EXT))))
for (d in unique(dirname(files$MASTER_PATH)))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# "ALREADY THERE" IS NOT THE SAME AS "CORRECT". If a source file is
# replaced at the same path - a publisher reissues a PDF, a download is
# retried - and it still resolves to the same identifier, then the master
# path already exists while its bytes are the OLD ones. Taking the
# shortcut would write the NEW hash into master.csv beside the OLD file,
# and extractShareable.R would then hand a collaborator a file that does
# not match the hash we published for it. Verify size first (cheap) and
# fall back to the recorded hash only when size matches but the cache
# says the content moved.
files$STORED <- vapply(seq_len(nrow(files)), function(k) {
  to <- files$MASTER_PATH[k]; from <- files$ORIGINAL_PATH[k]
  if (file.exists(to)) {
    # Only files whose SOURCE changed this run need checking. A hash
    # served from the cache means path, size and mtime all matched, so
    # the source did not move and master/ cannot have gone stale. Without
    # this test the verification would re-read all 24 GB every night and
    # undo the entire point of the cache.
    if (!files$HASH_FRESH[k]) return("present")
    same <- isTRUE(file.info(to)$size == files$BYTES[k]) &&
            identical(digest::digest(file = to, algo = "sha256"),
                      files$SHA256[k])
    if (same) return("present")
    # Stale. Replace the link so the tree matches the index again.
    unlink(to)
    if (isTRUE(suppressWarnings(file.link(from, to)))) return("relink")
    if (isTRUE(suppressWarnings(file.copy(from, to)))) return("recopy")
    return("FAILED")
  }
  if (isTRUE(suppressWarnings(file.link(from, to)))) return("link")
  if (isTRUE(suppressWarnings(file.copy(from, to)))) return("copy")
  "FAILED"
}, character(1))
if (any(files$STORED == "FAILED"))
  stop(sum(files$STORED == "FAILED"), " file(s) could not be stored in ",
       "master/. The index would describe files that are not there.")
message("  ", paste(names(table(files$STORED)), table(files$STORED),
                    sep = "=", collapse = "  "))

## ---------------------------------------------------------------------
## 9b. COLLECTIONS - reference data, kept under its own real names
## ---------------------------------------------------------------------
message("=== linking collections into registry/ ===")
collRows <- list()
for (k in seq_len(nrow(collectionSources))) {
  s <- collectionSources[k, ]
  if (!dir.exists(s$PATH)) next
  f <- list.files(s$PATH, pattern = s$PATTERN, full.names = TRUE,
                  recursive = s$RECURSIVE, ignore.case = TRUE)
  if (!length(f)) next
  dest <- file.path(corpusRoot, "registry", s$SOURCE_ID)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  lic <- s$LICENCE_DEFAULT
  sh  <- licenceTable$SHARE[match(lic, licenceTable$LICENCE)]
  if (is.na(sh)) sh <- "restricted"
  for (p in f) {
    to <- file.path(dest, basename(p))
    if (!file.exists(to))
      suppressWarnings(file.link(p, to)) || suppressWarnings(file.copy(p, to))
    collRows[[length(collRows) + 1L]] <- data.frame(
      SOURCE_ID = s$SOURCE_ID, FILE = basename(p),
      PATH = file.path("registry", s$SOURCE_ID, basename(p)),
      BYTES = file.info(p)$size,
      SHA256 = tryCatch(digest::digest(file = p, algo = "sha256"),
                        error = function(e) NA_character_),
      ORIGINAL_PATH = p, LICENCE = lic, SHARE = sh,
      FILE_SHAREABLE = sh %in% c("public", "noncommercial", "verbatim-only"),
      stringsAsFactors = FALSE)
  }
  message(sprintf("  %-18s %d files", s$SOURCE_ID, length(f)))
}
collections <- if (length(collRows)) do.call(rbind, collRows) else
  data.frame(SOURCE_ID = character(0))
utils::write.csv(collections, file.path(indexDir, "collections.csv"),
                 row.names = FALSE)

## ---------------------------------------------------------------------
## 10. THE INDEX
## ---------------------------------------------------------------------
# master.csv is deliberately free of titles, authors and journals: it is
# the file that can be shown to anyone. identity.csv is the other half,
# and is the one that must be held back.
master <- data.frame(
  ACCESSION = files$ACCESSION,
  FILE = basename(files$MASTER_PATH),
  FORMAT = files$EXT,
  COPY = files$COPY,
  BYTES = files$BYTES,
  SHA256 = files$SHA256,
  FIRST_SEEN = files$FIRST_SEEN,
  COHORT = files$COHORT,
  FILE_MTIME = files$MTIME,
  SOURCE_ID = files$SOURCE_ID,
  ORIGINAL_PATH = files$ORIGINAL_PATH,
  STORED_AS = files$STORED,
  LICENCE = files$LICENCE,
  SHARE = files$SHARE,
  FILE_SHAREABLE = files$FILE_SHAREABLE,
  DERIVED_SHAREABLE = files$DERIVED_SHAREABLE,
  stringsAsFactors = FALSE)
master <- master[order(master$ACCESSION, master$FORMAT, master$COPY), ]
utils::write.csv(master, file.path(indexDir, "master.csv"), row.names = FALSE)

# works.csv - one row per accession, which formats exist, and the single
# most permissive/most restrictive share class across its files.
agg <- function(f) tapply(f, files$ACCESSION, function(x) paste(sort(unique(x)), collapse = "|"))
worksAcc <- sort(unique(files$ACCESSION))
rank <- c(public = 1, noncommercial = 2, `verbatim-only` = 3,
          restricted = 4, confidential = 5)
worst <- tapply(files$SHARE, files$ACCESSION, function(x)
  names(rank)[max(rank[x])])
works <- data.frame(
  ACCESSION = worksAcc,
  FORMATS = agg(files$EXT)[worksAcc],
  N_FILES = as.integer(table(files$ACCESSION)[worksAcc]),
  SOURCES = agg(files$SOURCE_ID)[worksAcc],
  SHARE = worst[worksAcc],
  FIRST_SEEN = tapply(files$FIRST_SEEN, files$ACCESSION, function(x) x[1])[worksAcc],
  COHORT = tapply(files$COHORT, files$ACCESSION, function(x) x[1])[worksAcc],
  MULTI_FORMAT = grepl("[|]", agg(files$EXT)[worksAcc]),
  MULTI_SOURCE = grepl("[|]", agg(files$SOURCE_ID)[worksAcc]),
  stringsAsFactors = FALSE)
utils::write.csv(works, file.path(indexDir, "works.csv"), row.names = FALSE)

# identity.csv - RESTRICTED. Bibliographic identity, held back so that
# master.csv can circulate. Volume/issue/pages/authors are filled by
# fetchIdentity.R from NCBI; this build writes what is already known.
ident <- unique(files[, c("ACCESSION", "PMID", "PMCID", "DOI", "NCT")])
ident <- ident[!duplicated(ident$ACCESSION), ]
bibCols <- c("JOURNAL", "JOURNAL_FULL", "YEAR", "VOLUME", "ISSUE",
             "PAGES", "TITLE", "AUTHORS")
for (col in bibCols) ident[[col]] <- NA_character_
# A REBUILD MUST NOT THROW AWAY WHAT fetchCorpusIdentity.R RESOLVED.
# Those columns cost thousands of NCBI round trips; the accession is
# stable, so carry them forward and let the fetcher fill only the gaps.
old <- file.path(indexDir, "identity.csv")
if (file.exists(old)) {
  o <- utils::read.csv(old, colClasses = "character")
  i <- safeMatch(ident$ACCESSION, o$ACCESSION)
  for (col in c("PMID", bibCols))
    if (!is.null(o[[col]])) {
      v <- o[[col]][i]
      ident[[col]] <- ifelse(is.na(v) | !nzchar(v), ident[[col]], v)
    }
  message(sprintf("carried %d previously resolved identities forward",
                  sum(!is.na(o$TITLE[i]) & nzchar(o$TITLE[i]))))
}
# Fall back to the local PubMed extract for anything still blank.
pm <- file.path(staging, "ctgov", "pubmedMetadata.csv")
if (file.exists(pm)) {
  p <- utils::read.csv(pm, colClasses = "character")
  i <- safeMatch(ident$PMID, p$PMID)
  for (col in c("JOURNAL", "JOURNAL_FULL", "YEAR", "TITLE")) {
    v <- p[[col]][i]
    ident[[col]] <- ifelse(is.na(ident[[col]]) | !nzchar(ident[[col]]),
                           v, ident[[col]])
  }
}
ident <- ident[order(ident$ACCESSION), ]
utils::write.csv(ident, file.path(indexDir, "identity.csv"), row.names = FALSE)

utils::write.csv(rbind(sources, collectionSources),
                 file.path(indexDir, "sources.csv"), row.names = FALSE)
utils::write.csv(licenceTable, file.path(indexDir, "licences.csv"), row.names = FALSE)

jsonlite::write_json(list(
  built = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
  builder = "corpus/buildCorpusLibrary.R",
  seed = 20260831L,
  works = length(worksAcc), files = nrow(files),
  bytes = sum(files$BYTES, na.rm = TRUE),
  by_source = as.list(table(files$SOURCE_ID)),
  by_format = as.list(table(files$EXT)),
  by_share  = as.list(table(files$SHARE)),
  by_cohort = as.list(table(files$COHORT)),
  stored_as = as.list(table(files$STORED)),
  # The signature the backup uses to decide whether anything changed.
  # Derived from CONTENT (every file hash) rather than from timestamps, so
  # a rebuild that touches nothing does not trigger a 24 GB upload.
  signature = digest::digest(paste(sort(files$SHA256), collapse = ""),
                             algo = "sha256")),
  file.path(indexDir, "BUILD.json"), auto_unbox = TRUE, pretty = TRUE)

message("=== done ===")
print(table(files$SHARE))
print(table(files$EXT))
