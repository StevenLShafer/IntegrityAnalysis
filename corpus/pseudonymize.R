# pseudonymize.R - stable, non-reversible study identifiers, with a
# cross-reference held locally.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction: "Maybe we can have our own identifier, with a        #
# cross-reference that we can give interested investigators."              #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY. corpus/EndToEndValidation.csv joined a PMID to a baseline-          #
# homogeneity p-value, 457 rows, in a PUBLIC repository - eleven trials    #
# with a Carlisle p below 0.01 and four with ours. That is precisely the   #
# artefact Steve argued should have been withdrawn from Carlisle's 2017    #
# paper: an implicit accusation with no opportunity to reply. The          #
# validation statistics - correlation, alarm concordance, holdout split -  #
# need PAIRED values, not identities, so nothing scientific is lost by     #
# removing them.                                                           #
#                                                                          #
# WHY SALTED, and this is the part that is easy to get wrong. A PMID is    #
# about eight digits. An unsalted hash of it is not a pseudonym at all:    #
# anyone can hash all 10^8 candidates in seconds and invert the whole      #
# table. The salt is a secret, it lives outside the repository, and        #
# WITHOUT IT THE CROSS-REFERENCE CANNOT BE REBUILT - so it is worth        #
# backing up alongside the corpus.                                         #
#                                                                          #
# WHAT IS PUBLISHED vs HELD                                                #
#   published : IA-<10 hex>, the p-values, the holdout split               #
#   held      : .NewCarlisle/validation/crosswalk.csv  (ID -> PMID/PDF)    #
#               .NewCarlisle/validation/idSalt.txt     (the secret)        #
#                                                                          #
# An investigator asking "which trial is IA-3f2a9c1b04?" gets an answer    #
# from Steve, who can also hear their side of it. That is the difference   #
# between a finding and an accusation.                                     #
#                                                                          #
# ROW ORDER IS RANDOMISED on write. Publishing pseudonyms in the original   #
# file order would leak the mapping to anyone holding a directory listing  #
# of the corpus - the identifiers would be opaque and the ORDER would not. #
############################################################################

# Where the secret and the cross-reference live. Under .NewCarlisle/,
# which .gitignore excludes because it holds copyrighted PDFs; the same
# exclusion is what keeps these out of the repository.
iaIdDir <- function(root = Sys.getenv("INTEGRITY_ROOT",
                                      "C:/dev/IntegrityAnalysis"))
  file.path(root, ".NewCarlisle", "validation")

# Read the salt, creating one on first use. 32 bytes from the R RNG is
# not cryptographic randomness, but the threat here is enumeration of an
# 8-digit space by an outsider, not an adversary with the file.
iaIdSalt <- function(root = Sys.getenv("INTEGRITY_ROOT",
                                       "C:/dev/IntegrityAnalysis")) {
  d <- iaIdDir(root)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, "idSalt.txt")
  if (!file.exists(f)) {
    s <- paste(sprintf("%02x", sample(0:255, 32, replace = TRUE)),
               collapse = "")
    writeLines(s, f)
    message("created a NEW id salt at ", f,
            " - back this up; the cross-reference cannot be rebuilt without it")
  }
  readLines(f, warn = FALSE)[1]
}

#' Stable pseudonym for a study.
#'
#' @param key character vector of PMIDs (or any stable study key).
#' @return "IA-" followed by 10 hex characters.
iaPseudonym <- function(key, root = Sys.getenv("INTEGRITY_ROOT",
                                               "C:/dev/IntegrityAnalysis")) {
  if (!requireNamespace("digest", quietly = TRUE))
    stop("package 'digest' is required for pseudonymous identifiers",
         call. = FALSE)
  salt <- iaIdSalt(root)
  vapply(as.character(key), function(k)
    if (is.na(k) || !nzchar(k)) NA_character_ else
      paste0("IA-", substr(digest::digest(paste0(salt, "|", k),
                                          algo = "sha256"), 1, 10)),
    character(1), USE.NAMES = FALSE)
}

#' Write the ID -> identity cross-reference, and return the public frame.
#'
#' @param df data frame carrying the identifying columns.
#' @param idFrom column holding the stable key (default "PMID").
#' @param drop identifying columns to remove from the public frame.
iaDeidentify <- function(df, idFrom = "PMID",
                         drop = c("PDF", "PMID", "TRIAL"),
                         root = Sys.getenv("INTEGRITY_ROOT",
                                           "C:/dev/IntegrityAnalysis"),
                         xrefName = "crosswalk.csv") {
  stopifnot(idFrom %in% names(df))
  salt <- iaIdSalt(root)
  df$ID <- iaPseudonym(df[[idFrom]], root)
  d <- iaIdDir(root)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  xrefCols <- intersect(c("ID", drop), names(df))
  utils::write.csv(df[, xrefCols, drop = FALSE],
                   file.path(d, xrefName), row.names = FALSE)
  pub <- df[, c("ID", setdiff(names(df), c("ID", drop))), drop = FALSE]
  # Randomise row order - see the header. The seed comes from the SALT,
  # not from a constant: a fixed seed would make the permutation
  # reproducible by anyone, so a reader who could regenerate the original
  # row order could invert it. Seeded from the secret, the shuffle is
  # reproducible for us and not for them.
  oldSeed <- if (exists(".Random.seed", .GlobalEnv))
    get(".Random.seed", .GlobalEnv) else NULL
  on.exit(if (!is.null(oldSeed)) assign(".Random.seed", oldSeed, .GlobalEnv),
          add = TRUE)
  set.seed(strtoi(substr(salt, 1, 6), 16L) %% .Machine$integer.max)
  pub[sample(nrow(pub)), , drop = FALSE]
}
