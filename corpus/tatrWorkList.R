# tatrWorkList.R - choose which PDFs a TATR run-along pass may touch, and
# write the node's work list.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-01 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction, as the front half of the run-along: "test it on our  #
# entire corpus of PDF files".                                             #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# CONFIDENTIAL WORK IS EXCLUDED BY DEFAULT, AND THAT IS THE POINT OF THIS  #
# SCRIPT EXISTING SEPARATELY FROM THE RUNNER.                              #
#                                                                          #
# The 6,328 A&A peer-review manuscripts are marked `confidential`: neither #
# the file nor a per-item derived row leaves this machine. A fleet run     #
# would copy PDFs to the Linux compute nodes. Those are Steve's own        #
# machines on his own LAN, not third parties - but "never leaves this      #
# machine" is the rule as written, and widening it is his decision to make #
# explicitly, not a side effect of a convenience script.                   #
#                                                                          #
# So: --include-confidential exists, it is off by default, and it refuses  #
# to combine with a remote destination unless --i-accept-copying-          #
# confidential-files is also given. The flag is deliberately tedious.      #
#                                                                          #
# The irony worth recording: TATR is the ONLY parsing route that could     #
# ever process this tier, because it runs locally and sends nothing to an  #
# API. Running it on THIS machine over the confidential works is entirely  #
# within the rule. It is only the fleet that raises the question.          #
############################################################################

args <- commandArgs(trailingOnly = TRUE)
getArg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1L]
}
hasFlag <- function(flag) flag %in% args

corpusRoot <- Sys.getenv("INTEGRITY_CORPUS", "C:/dev/Corpus")
out        <- getArg("--out", "tatrWorkList.csv")
nodes      <- as.integer(getArg("--nodes", "1"))
sourceOnly <- getArg("--source", NA_character_)
sample     <- suppressWarnings(as.integer(getArg("--sample", NA_character_)))
remote     <- hasFlag("--remote")
inclConf   <- hasFlag("--include-confidential")
accepted   <- hasFlag("--i-accept-copying-confidential-files")

m <- utils::read.csv(file.path(corpusRoot, "index", "master.csv"),
                     colClasses = "character")
message(sprintf("master.csv: %d files", nrow(m)))

pdfs <- m[m$FORMAT == "pdf", , drop = FALSE]
message(sprintf("  PDFs: %d", nrow(pdfs)))

conf <- pdfs$SHARE == "confidential"
message(sprintf("  of which confidential: %d", sum(conf)))

if (!inclConf) {
  pdfs <- pdfs[!conf, , drop = FALSE]
  message("  EXCLUDED confidential works (default). Pass --include-confidential to keep them.")
} else if (remote && !accepted) {
  stop("--include-confidential with --remote would copy peer-review manuscripts ",
       "off this machine. The corpus rule is that neither the file nor a ",
       "per-item derived row leaves it. If that is genuinely intended, add ",
       "--i-accept-copying-confidential-files. NOTHING WAS WRITTEN.")
} else {
  message("  KEEPING confidential works",
          if (remote) " AND permitting them off this machine (explicitly accepted)"
          else " (local run only - within the rule)")
}

if (!is.na(sourceOnly)) {
  pdfs <- pdfs[pdfs$SOURCE_ID == sourceOnly, , drop = FALSE]
  message(sprintf("  restricted to source '%s': %d", sourceOnly, nrow(pdfs)))
}

# One row per WORK, not per file. A work held twice - the same manuscript in
# two source trees - would otherwise be parsed twice to produce two
# identical XMLs under one accession.
pdfs <- pdfs[!duplicated(pdfs$ACCESSION), , drop = FALSE]
message(sprintf("  distinct works: %d", nrow(pdfs)))

if (!is.na(sample) && sample < nrow(pdfs)) {
  # Fixed seed: a pilot that cannot be reproduced cannot be compared against
  # the full run it is meant to predict.
  set.seed(20260901L)
  pdfs <- pdfs[sort(sample.int(nrow(pdfs), sample)), , drop = FALSE]
  message(sprintf("  sampled %d (seed 20260901)", nrow(pdfs)))
}

pdfs$PATH <- file.path(corpusRoot, "master", "pdf", pdfs$FILE)
missing <- !file.exists(pdfs$PATH)
if (any(missing)) {
  message(sprintf("  !! %d listed PDFs are not on disk - excluded", sum(missing)))
  pdfs <- pdfs[!missing, , drop = FALSE]
}

# Round-robin rather than contiguous blocks, for the same reason the medRxiv
# harvest partitions that way: a node going down costs a scattering of
# articles rather than one whole collection.
if (nodes > 1L) {
  grp <- (seq_len(nrow(pdfs)) - 1L) %% nodes + 1L
  for (k in seq_len(nodes)) {
    # sub() only substitutes when the pattern matches, so an --out without a
    # .csv suffix produced the SAME filename for every node and each write
    # overwrote the last: one node's list, silently, instead of three.
    # (CodeRabbit, PR #137.)
    f <- if (grepl("[.]csv$", out)) sub("[.]csv$", sprintf("_%02d.csv", k), out)
         else sprintf("%s_%02d.csv", out, k)
    utils::write.csv(data.frame(ACCESSION = pdfs$ACCESSION[grp == k],
                                PATH = pdfs$PATH[grp == k]),
                     f, row.names = FALSE, quote = FALSE)
    message(sprintf("  wrote %s (%d works)", f, sum(grp == k)))
  }
} else {
  utils::write.csv(data.frame(ACCESSION = pdfs$ACCESSION, PATH = pdfs$PATH),
                   out, row.names = FALSE, quote = FALSE)
  message(sprintf("  wrote %s (%d works)", out, nrow(pdfs)))
}
