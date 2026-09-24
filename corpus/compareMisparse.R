# compareMisparse.R - two measureMisparse.R runs, side by side.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1) for ISSUES.md   #
# issue 34, whose finding made a quantitative prediction about its own     #
# fix: a table that sheds its follow-up columns matches Carlisle's         #
# hand-entered values on every pair it returns, so the "partial" bucket    #
# should shrink and "fully corroborated" should grow. This is the test of  #
# that prediction - and of the scorer change that rode along with the fix, #
# which can move candidate selection on files that have nothing to do with #
# repeated measures.                                                       #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/compareMisparse.R <beforeDir> <afterDir>                #
# where each directory holds a measureMisparse.R misparse_files.csv.       #
# Buckets follow issue 24's definitions exactly: FULL = every pair matched #
# (UNCORROBORATED == 0, CORROBORATED > 0); ZERO = nothing matched          #
# (CORROBORATED == 0); PARTIAL = the rest. Files that parsed on only one   #
# side are listed separately, because a file that went from "parsed with  #
# wrong values" to "not parsed" is an improvement the buckets would hide.  #
############################################################################

a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 2) stop("usage: Rscript corpus/compareMisparse.R <beforeDir> <afterDir>")
rd <- function(d) {
  x <- utils::read.csv(file.path(d, "misparse_files.csv"), stringsAsFactors = FALSE)
  x$bucket <- ifelse(x$OUTCOME != "parsed", "not parsed",
              ifelse(x$CORROBORATED == 0, "zero",
              ifelse(x$UNCORROBORATED == 0, "full", "partial")))
  x
}
b <- rd(a[1]); af <- rd(a[2])
lab <- c(basename(a[1]), basename(a[2]))

cat("=================== MISPARSE, BEFORE vs AFTER ===================\n")
cat(sprintf("%-14s %10s %10s\n", "", lab[1], lab[2]))
for (k in c("full", "partial", "zero", "not parsed")) {
  nb <- sum(b$bucket == k); na <- sum(af$bucket == k)
  cat(sprintf("%-14s %10d %10d   %+d\n", k, nb, na, na - nb))
}
cat(sprintf("%-14s %10d %10d\n", "files", nrow(b), nrow(af)))
pb <- b[b$OUTCOME == "parsed", ]; pa <- af[af$OUTCOME == "parsed", ]
cat(sprintf("\n%-38s %10s %10s\n", "", lab[1], lab[2]))
cat(sprintf("%-38s %10d %10d\n", "our pairs", sum(pb$OURS), sum(pa$OURS)))
cat(sprintf("%-38s %10d %10d\n", "corroborated", sum(pb$CORROBORATED), sum(pa$CORROBORATED)))
cat(sprintf("%-38s %9.1f%% %9.1f%%\n", "corroborated share of ours",
            100 * sum(pb$CORROBORATED) / sum(pb$OURS), 100 * sum(pa$CORROBORATED) / sum(pa$OURS)))
cat(sprintf("%-38s %10d %10d\n", "his pairs missed", sum(pb$MISSED), sum(pa$MISSED)))
cat(sprintf("%-38s %9.1f%% %9.1f%%\n", "missed share of his",
            100 * sum(pb$MISSED) / sum(pb$THEIRS), 100 * sum(pa$MISSED) / sum(pa$THEIRS)))

m <- merge(b[, c("PDF", "bucket", "OURS", "CORROBORATED", "UNCORROBORATED")],
           af[, c("PDF", "bucket", "OURS", "CORROBORATED", "UNCORROBORATED")],
           by = "PDF", suffixes = c(".b", ".a"))
moved <- m[m$bucket.b != m$bucket.a, ]
cat(sprintf("\nfiles that changed bucket: %d of %d\n", nrow(moved), nrow(m)))
if (nrow(moved)) {
  tr <- table(paste(moved$bucket.b, "->", moved$bucket.a))
  for (i in order(-tr)) cat(sprintf("  %-26s %d\n", names(tr)[i], tr[i]))
  cat("\n  worst regressions (full -> partial/zero), by uncorroborated pairs gained:\n")
  reg <- moved[moved$bucket.b == "full" & moved$bucket.a != "full", ]
  reg <- reg[order(-(reg$UNCORROBORATED.a - reg$UNCORROBORATED.b)), ]
  for (i in seq_len(min(8, nrow(reg))))
    cat(sprintf("    %-24s ours %d->%d  uncorroborated %d->%d\n", reg$PDF[i],
                reg$OURS.b[i], reg$OURS.a[i], reg$UNCORROBORATED.b[i], reg$UNCORROBORATED.a[i]))
  cat("\n  best improvements (partial/zero -> full):\n")
  imp <- moved[moved$bucket.a == "full" & moved$bucket.b != "full", ]
  for (i in seq_len(min(8, nrow(imp))))
    cat(sprintf("    %-24s ours %d->%d  uncorroborated %d->%d\n", imp$PDF[i],
                imp$OURS.b[i], imp$OURS.a[i], imp$UNCORROBORATED.b[i], imp$UNCORROBORATED.a[i]))
}
cat("\nfiles with an identical (OURS, CORROBORATED, UNCORROBORATED) triple:",
    sum(m$OURS.b == m$OURS.a & m$CORROBORATED.b == m$CORROBORATED.a &
        m$UNCORROBORATED.b == m$UNCORROBORATED.a), "of", nrow(m), "\n")
