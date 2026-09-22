# corpusPaths.R - where a corpus file lives, given what it is.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-22 by Claude Code (Opus 5) at Steve Shafer's request.    #
# Extracted here, rather than repeated, for the same reason safeMatch.R    #
# was: four scripts built the path by hand and all four had to agree.      #
#                                                                          #
# WHY THE CONFIDENTIAL TIER GETS ITS OWN DIRECTORY                          #
#                                                                          #
# Until now every file lived in master/<format>/, so master/pdf held       #
# 38,091 files of which 6,328 were the confidential A&A peer-review tier,  #
# interleaved and indistinguishable: IA000013.pdf sits beside IA000012.pdf #
# and nothing in the path says which is which.                             #
#                                                                          #
# Every ordinary tool for keeping files somewhere - robocopy /XD, rclone   #
# --exclude, S3 prefixes, Dropbox and OneDrive selective sync - selects by #
# PATH. None of them can express "everything except these 6,328 basenames",#
# so protecting the tier required a 6,328-entry allowlist that each new    #
# tool had to be taught separately. On 2026-09-22 a routine whole-folder   #
# backup copied all 6,328 to a third-party cloud, silently, because the    #
# obvious exclusion pattern matched nothing.                               #
#                                                                          #
# Splitting the directory makes the distinction expressible in the one     #
# language every tool already speaks.                                      #
#                                                                          #
# THE INDEX IS UNCHANGED. The directory is a pure function of SHARE, which #
# master.csv already records, so FILE and FORMAT keep their meanings and   #
# no re-indexing is needed. A caller that forgets to use this function     #
# looks in master/ for a confidential file, finds nothing, and fails       #
# loudly - it never silently reads or writes the wrong file.               #
############################################################################

#' The directory holding a given share class
#'
#' @param share Character vector of SHARE values from `index/master.csv`.
#' @return "master-confidential" for the confidential tier, "master" otherwise.
## The share classes this resolver knows how to place. Deliberately an
## ALLOWLIST, not a test for emptiness (CodeRabbit on PR #325): the first
## version rejected NA and "" but mapped every other unrecognised value -
## "embargoed", "confidential-2", a typo - to "master", the SHARED tree.
## That is the exact failure this split was made to prevent, reintroduced
## inside the guard meant to prevent it.
##
## Adding a share class therefore BREAKS this function until someone says
## where files of that class belong. That is the intended behaviour: a new
## tier is a decision about confidentiality, and it should not be possible
## to add one and have its files quietly inherit the shared directory.
.corpusShareClasses <- c("public", "noncommercial", "verbatim-only",
                         "restricted", "confidential")

corpusShareDir <- function(share) {
  # An unknown share class is not defaulted. Guessing has two failure modes
  # and both are bad: guess "master" for a confidential file and it is
  # exposed to every path-based copy; guess "master-confidential" for a
  # public one and it silently disappears from extraction. Refuse instead -
  # every row in master.csv has carried a known SHARE since the index was
  # built, so this can only fire on a corrupted, hand-edited, or newly
  # extended index.
  s   <- as.character(share)
  bad <- is.na(s) | !nzchar(s) | !(s %in% .corpusShareClasses)
  if (any(bad)) {
    seen <- unique(ifelse(is.na(s[bad]) | !nzchar(s[bad]), "<blank>", s[bad]))
    stop(sum(bad), " file(s) have an unrecognised SHARE class (",
         paste(utils::head(seen, 5), collapse = ", "),
         "), so their location cannot be determined. Known classes: ",
         paste(.corpusShareClasses, collapse = ", "),
         ". Fix index/master.csv, or add the new class to ",
         ".corpusShareClasses and decide which tree it belongs in. ",
         "Do not guess.")
  }
  ifelse(s == "confidential", "master-confidential", "master")
}

#' Full path to a corpus file
#'
#' @param root Corpus root, e.g. `"C:/dev/Corpus"`, or `"."` when the
#'   working directory is already the corpus root.
#' @param share,format,file Parallel vectors from `index/master.csv`.
#' @return Character vector of paths.
corpusFilePath <- function(root, share, format, file)
  file.path(root, corpusShareDir(share), format, file)
