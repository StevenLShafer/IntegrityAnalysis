# checkCaptionStraddle.R - the four Carlisle-corpus pages that decided how a
# full-width block straddling two side-by-side tables is scored (ISSUES.md
# issue 35, the misparse measurement of 2026-09-24/25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1). The articles  #
# are the journal corpus at INTEGRITY_CORPUS (default C:/temp/journals),   #
# copyrighted and outside the repository: this script SKIPS, with exit     #
# status 0, when a PDF is absent, like corpus/checkFujii11375852.R. The    #
# synthetic side-by-side page that always runs is in                       #
# tests/testthat/test-loadsman-layouts.R.                                  #
#                                                                          #
# The rule under test: a candidate whose caption names two tables is       #
# docked 8 ONLY when another candidate on the same page names exactly one  #
# table and it is the same first table (a split twin). The four pages:     #
#   16738291  split twin exists   -> TABLE I wins, not the straddle        #
#   16179044  split twin exists   -> Table 1 wins, not "Table 1 ... Table 4"#
#   15681941  NO split (single full-width layout, Table 1 beside Table 3)  #
#             -> the straddle is the only reading holding Table 1: kept    #
#   12193491  second anchor is prose on the caption line ("(Table II)")    #
#             -> no twin, no dock: TABLE I wins                             #
############################################################################

DIR <- Sys.getenv("INTEGRITY_CORPUS", "C:/temp/journals")
need <- c("PMID_16738291", "PMID_16179044", "PMID_15681941", "PMID_12193491")
have <- file.exists(file.path(DIR, paste0(need, ".pdf")))
if (!all(have)) {
  cat("SKIP: not present in ", DIR, ": ", paste(need[!have], collapse = ", "), "\n", sep = "")
  quit(save = "no", status = 0)
}
suppressWarnings(suppressPackageStartupMessages({ library(shiny); library(dqrng) }))
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(IntegrityAnalysis)
}
fails <- 0L
chk <- function(ok, what) {
  cat(if (isTRUE(ok)) "  [PASS] " else "  [FAIL] ", what, "\n", sep = "")
  if (!isTRUE(ok)) fails <<- fails + 1L
}
parse <- function(p) parseBaselineTableHeuristics(file.path(DIR, paste0(p, ".pdf")), quiet = TRUE)

cat("\n=== PMID_16738291: TABLE I, not the TABLE I + TABLE III straddle ===\n")
r <- parse("PMID_16738291")
chk(grepl("^TABLE I Baseline characteristics$", trimws(r$caption)),
    paste0("caption is TABLE I alone (", r$caption, ")"))
chk(nrow(r$arms) == 2L, "two arms, not four")
chk(!any(r$data$MEAN %in% c(84.7, 68.2), na.rm = TRUE), "no Table III value under Age")

cat("\n=== PMID_16179044: Table 1, not the Table 1 + Table 4 straddle ===\n")
r <- parse("PMID_16179044")
chk(!grepl("Table 4", r$caption), paste0("caption does not run into Table 4 (", r$caption, ")"))
chk(nrow(r$arms) == 2L && all(r$arms$N == 55), "two arms of 55")
chk(identical(sort(unique(r$data$ROW[!is.na(r$data$MEAN)])), c("Age; years", "Height; cm", "Weight; kg")),
    "Age, Weight, Height and nothing from Table 4")

cat("\n=== PMID_15681941: no split exists; the straddle holding Table 1 is kept ===\n")
r <- parse("PMID_15681941")
chk(grepl("^Table 1", r$caption), paste0("caption starts at Table 1 (", substr(r$caption, 1, 60), ")"))

cat("\n=== PMID_12193491: prose 'Table II' on the caption line is not a straddle ===\n")
r <- parse("PMID_12193491")
chk(grepl("^TABLE I Patient characteristics", r$caption),
    paste0("TABLE I wins (", substr(r$caption, 1, 60), ")"))

cat("\n", if (fails == 0L) "ALL CHECKS PASSED" else paste(fails, "CHECK(S) FAILED"), "\n")
quit(save = "no", status = if (fails == 0L) 0 else 1)
