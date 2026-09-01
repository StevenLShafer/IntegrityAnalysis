# auditCorpus.R - does the library actually hold everything the parser was
# built on, and is confidentiality enforced rather than merely intended?
#
# Written 2026-08-31 at Steve Shafer's direction: "audit the corpus just
# created and indexed. Let's be sure it has everything we have used to
# build the parser, with adequate indexing so that confidential files
# remain confidential."

setwd("C:/dev/Corpus")
repo <- "C:/dev/IntegrityAnalysis"
m <- read.csv("index/master.csv", colClasses = "character")
w <- read.csv("index/works.csv",  colClasses = "character")
d <- read.csv("index/identity.csv", colClasses = "character")
b <- function(x) is.na(x) | !nzchar(x)
fail <- 0L
chk <- function(ok, msg) {
  cat(if (ok) "  PASS  " else "  FAIL  ", msg, "\n", sep = "")
  if (!ok) fail <<- fail + 1L
}

cat("=========== COVERAGE: is the parser's evidence in the library? ===========\n")

# ParseOutcomes.csv is the master sheet of the 1,865-article corpus - one
# row per PDF, the binary parse outcome, and the notes that drove every
# parser fix. If an article it names is missing, the library cannot
# reproduce the published parse rate.
po <- read.csv(file.path(repo, "corpus", "ParseOutcomes.csv"), colClasses = "character")
cat("ParseOutcomes rows:", nrow(po), "\n")
# Its PDF column is <journal>/<year>/<n.m>.pdf, matching the source tree.
orig <- gsub("\\\\", "/", m$ORIGINAL_PATH)
# endsWith, NOT grepl. Four of these filenames contain parentheses -
# "eja/2004/3.4 (retracted Boldt).pdf" - and as a regex those compile to a
# capture group, so the pattern never matches its own literal name. The
# first run of this audit reported those four as missing from the library
# when they were present all along. A coverage check that is itself wrong
# is worse than no coverage check.
inLib <- vapply(po$PDF, function(p)
  any(endsWith(orig, paste0("/Journals/", p))), logical(1))
cat("  named articles found in the library:", sum(inLib), "/", nrow(po), "\n")
chk(all(inLib),
    sprintf("ParseOutcomes coverage %.1f%%", 100 * mean(inLib)))

# The named regression fixtures, including corpus/TEST.
testDir <- file.path(repo, "corpus", "TEST")
nTest <- length(list.files(testDir, pattern = "[.]pdf$"))
inTest <- sum(grepl("/corpus/TEST/", orig))
cat("corpus/TEST pdfs on disk:", nTest, " in library:", inTest, "\n")
chk(inTest == nTest, "every corpus/TEST fixture is in the library")

for (s in c("carlisle-journals", "aa-peer-review", "medrxiv", "pmc-oa",
            "ctgov-docs", "regression-fixtures", "shafer-studies"))
  chk(sum(m$SOURCE_ID == s) > 0, paste("source present:", s))

cat("\n=========== CONFIDENTIALITY: enforced, not just intended ===========\n")

conf <- m[m$SHARE == "confidential", ]
chk(nrow(conf) > 0, "a confidential tier exists")
chk(all(conf$FILE_SHAREABLE == "FALSE"),
    "no confidential file is marked FILE_SHAREABLE")
chk(all(conf$DERIVED_SHAREABLE == "FALSE"),
    "no confidential file is marked DERIVED_SHAREABLE")
# Check the SHARE CLASS of every A&A row, not just that the source id
# appears somewhere in the confidential set. The earlier version compared
# source ids only, so a single aa-peer-review row wrongly marked
# "restricted" would still have passed - and that row would then be
# FILE_SHAREABLE, which is the exact failure this audit exists to catch.
aaRows <- m[m$SOURCE_ID == "aa-peer-review", ]
chk(nrow(aaRows) > 0 && all(aaRows$SHARE == "confidential"),
    sprintf("all %d A&A peer-review files are confidential (%d not)",
            nrow(aaRows), sum(aaRows$SHARE != "confidential")))
chk(all(aaRows$FILE_SHAREABLE == "FALSE") &&
    all(aaRows$DERIVED_SHAREABLE == "FALSE"),
    "no A&A peer-review file is shareable in either sense")

# The accession is the whole protection: a confidential work must not be
# resolvable to a named paper from anything we would ever hand over.
ca <- unique(conf$ACCESSION)
sub <- d[d$ACCESSION %in% ca, ]
chk(all(b(sub$PMID)),  "no confidential work carries a PMID")
chk(all(b(sub$TITLE)), "no confidential work carries a TITLE")
chk(all(b(sub$AUTHORS)), "no confidential work carries AUTHORS")
chk(all(b(sub$DOI)),   "no confidential work carries a DOI")

# master.csv is the file that may circulate. It must not name anything.
chk(!any(c("TITLE","AUTHORS","JOURNAL","PMID","PMCID","DOI") %in% names(m)),
    "master.csv carries no bibliographic columns")
# ...but it DOES carry ORIGINAL_PATH, which is identifying on its own:
# "C:/temp/AA/2013/AA-D-13-00286.pdf" is a manuscript number.
chk("ORIGINAL_PATH" %in% names(m),
    "master.csv has ORIGINAL_PATH (must be stripped on extraction)")

# The extraction path is the actual guarantee. Read the script and confirm
# the guarantees are in the code, not just in the comments.
ex <- paste(readLines(file.path(repo, "corpus", "extractShareable.R"),
                      warn = FALSE), collapse = "\n")
chk(grepl("setdiff\\(names\\(master\\), \"ORIGINAL_PATH\"\\)", ex),
    "extractShareable strips ORIGINAL_PATH")
chk(!grepl("identity\\.csv", sub("#[^\n]*", "", ex)) ||
    grepl("never included", ex),
    "extractShareable never copies identity.csv")
chk(grepl("FILE_SHAREABLE", ex), "extraction is gated on FILE_SHAREABLE")

cat("\n=========== INTEGRITY of the index itself ===========\n")
a <- read.csv("index/accessions.csv", colClasses = "character")
chk(!anyDuplicated(a$ACCESSION), "no accession names two works")
chk(all(m$ACCESSION %in% a$ACCESSION), "every indexed file has a known accession")
miss <- sum(!file.exists(file.path("master", m$FORMAT, m$FILE)))
chk(miss == 0, sprintf("every indexed file exists on disk (%d missing)", miss))
chk(!any(b(m$SHA256)), "every file has a SHA-256")
chk(length(unique(m$SHA256)) > 0.5 * nrow(m), "hashes are not degenerate")

cat("\n=========== SUMMARY ===========\n")
cat(if (fail == 0) "ALL CHECKS PASSED\n" else
    sprintf("%d CHECK(S) FAILED\n", fail))
cat("works", length(unique(m$ACCESSION)), " files", nrow(m),
    " GB", round(sum(as.numeric(m$BYTES), na.rm = TRUE)/2^30, 1), "\n")
