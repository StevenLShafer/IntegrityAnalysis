# extractShareable.R - build a package for a collaborator, from the index.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-31 by Claude Code (model Claude Opus 5, Anthropic) at    #
# Steve Shafer's direction: "The master corpus itself is never shared. We  #
# extract and share only what the master index permits."                   #
#                                                                          #
# Status: run 2026-08-31 in --dry-run to produce the counts quoted in      #
# C:/dev/Corpus/README.md.                                                 #
############################################################################
#
# THE RULE THIS ENFORCES. Nothing is copied because a human believed it
# was shareable; a file is copied if and only if index/master.csv says
# FILE_SHAREABLE is TRUE for that row. If a licence is wrong in the index,
# fix the index - never special-case the extraction, because the index is
# the thing we can audit later and an argument in a shell history is not.
#
# THREE TIERS, because collaborators need different things:
#
#   files    the articles themselves. Only public / noncommercial /
#            verbatim-only licences. This is what lets someone else RUN
#            the parser on the same inputs.
#   derived  parsed tables and per-item statistics for everything except
#            confidential peer-review manuscripts. A subscription PDF
#            cannot be redistributed, but the numbers printed in its
#            Table 1 are facts, and facts are not copyrightable.
#   index    the non-identifying index alone - accessions, formats,
#            licences, hashes, provenance. Never identity.csv.
#
# identity.csv is EXCLUDED from every tier, unconditionally. Turning an
# accession back into a named paper is a decision Steve makes one paper at
# a time, so that the author can be heard before anything is said about
# them. That is the whole reason the accession exists.

args       <- commandArgs(trailingOnly = TRUE)
corpusRoot <- Sys.getenv("INTEGRITY_CORPUS", "C:/dev/Corpus")
indexDir   <- file.path(corpusRoot, "index")
outDir     <- if (length(args) >= 1 && !grepl("^--", args[1])) args[1] else
              file.path(corpusRoot, "_share")
tiers      <- if (any(grepl("^--tier=", args)))
              strsplit(sub("^--tier=", "", grep("^--tier=", args, value = TRUE)),
                       ",")[[1]] else c("files", "derived", "index")
dryRun     <- "--dry-run" %in% args

master <- utils::read.csv(file.path(indexDir, "master.csv"),
                          colClasses = c(SHA256 = "character"))
works  <- utils::read.csv(file.path(indexDir, "works.csv"))

message("=== extraction plan ===")
message("  target : ", outDir)
message("  tiers  : ", paste(tiers, collapse = ", "))

## --- tier: index ------------------------------------------------------
# Shipped for every tier, because a bag of accession-named files with no
# index is unusable - and because it carries the licence of each file, so
# the recipient inherits the terms rather than having to guess them.
if ("index" %in% tiers) {
  n <- nrow(master)
  message(sprintf("  index  : %d file rows, %d works", n, nrow(works)))
  if (!dryRun) {
    dir.create(file.path(outDir, "index"), recursive = TRUE, showWarnings = FALSE)
    # ORIGINAL_PATH is dropped: it leaks the local directory names, and
    # "C:/temp/AA/2013/AA-D-13-00286.pdf" identifies a manuscript even
    # when the accession does not.
    pub <- master[, setdiff(names(master), "ORIGINAL_PATH")]
    utils::write.csv(pub, file.path(outDir, "index", "master.csv"),
                     row.names = FALSE)
    utils::write.csv(works, file.path(outDir, "index", "works.csv"),
                     row.names = FALSE)
    for (f in c("licences.csv", "sources.csv"))
      file.copy(file.path(indexDir, f), file.path(outDir, "index", f),
                overwrite = TRUE)
  }
}

## --- tier: files ------------------------------------------------------
if ("files" %in% tiers) {
  take <- master[master$FILE_SHAREABLE %in% c(TRUE, "TRUE", "True"), ]
  message(sprintf("  files  : %d of %d (%.1f%%), %.1f GB",
                  nrow(take), nrow(master), 100 * nrow(take) / nrow(master),
                  sum(take$BYTES, na.rm = TRUE) / 2^30))
  print(table(take$LICENCE))
  if (!dryRun) {
    for (fmt in unique(take$FORMAT))
      dir.create(file.path(outDir, "files", fmt), recursive = TRUE,
                 showWarnings = FALSE)
    ok <- vapply(seq_len(nrow(take)), function(k) {
      from <- file.path(corpusRoot, "master", take$FORMAT[k], take$FILE[k])
      to   <- file.path(outDir, "files", take$FORMAT[k], take$FILE[k])
      if (file.exists(to)) return(TRUE)
      isTRUE(suppressWarnings(file.link(from, to))) ||
        isTRUE(suppressWarnings(file.copy(from, to)))
    }, logical(1))
    message(sprintf("    copied %d, failed %d", sum(ok), sum(!ok)))
  }
}

## --- tier: derived ----------------------------------------------------
# Not the files, but everything computed from them, for every accession
# whose DERIVED_SHAREABLE is TRUE. The registry data is included whole:
# ClinicalTrials.gov is a US Government work and carries no restriction.
if ("derived" %in% tiers) {
  d <- unique(master$ACCESSION[master$DERIVED_SHAREABLE %in% c(TRUE, "TRUE", "True")])
  message(sprintf("  derived: %d of %d works (%d withheld as confidential)",
                  length(d), nrow(works), nrow(works) - length(d)))
  if (!dryRun) {
    dir.create(file.path(outDir, "derived"), recursive = TRUE, showWarnings = FALSE)
    writeLines(d, file.path(outDir, "derived", "shareableAccessions.txt"))
    reg <- file.path(corpusRoot, "registry", "ctgov")
    if (dir.exists(reg)) {
      dir.create(file.path(outDir, "derived", "ctgov"), recursive = TRUE,
                 showWarnings = FALSE)
      for (f in list.files(reg, full.names = TRUE))
        file.link(f, file.path(outDir, "derived", "ctgov", basename(f)))
      message("    registry/ctgov included (US Gov public domain)")
    }
  }
}

if (dryRun) message("\n(dry run - nothing written)") else
  message("\nwritten to ", outDir)
message("identity.csv is never included in any tier.")
