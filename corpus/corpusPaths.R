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
corpusShareDir <- function(share) {
  # An unknown share class is not defaulted. Guessing has two failure modes
  # and both are bad: guess "master" for a confidential file and it is
  # exposed to every path-based copy; guess "master-confidential" for a
  # public one and it silently disappears from extraction. Refuse instead -
  # every row in master.csv has carried a SHARE since the index was built,
  # so this can only fire on a corrupted or hand-edited index.
  bad <- is.na(share) | !nzchar(as.character(share))
  if (any(bad))
    stop(sum(bad), " file(s) have no SHARE class, so their location cannot ",
         "be determined. Fix index/master.csv; do not guess.")
  ifelse(share == "confidential", "master-confidential", "master")
}

#' Full path to a corpus file
#'
#' @param root Corpus root, e.g. `"C:/dev/Corpus"`, or `"."` when the
#'   working directory is already the corpus root.
#' @param share,format,file Parallel vectors from `index/master.csv`.
#' @return Character vector of paths.
corpusFilePath <- function(root, share, format, file)
  file.path(root, corpusShareDir(share), format, file)
