# checkFujii11375852.R - the end-to-end check on the real article.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1) for ISSUES.md   #
# issue 34, from docs/audits/2026-09-24-repeated-measures-parse-finding-    #
# cowork.md. This is CORPUS TOOLING, not the test suite: the suite is       #
# deliberately corpus-free (AGENTS.md), and the article is a retracted,    #
# copyrighted paper that is not committed. The script skips cleanly when   #
# the file is absent, so it runs on Steve's machine and is silent in CI.   #
#                                                                          #
# THE ARTICLE. Fujii, Hoshi, Uemura & Toyooka, "Dose-response              #
# characteristics of midazolam for reducing diaphragmatic contractility",  #
# Anesth Analg 2001;92:1590-3 (PMID 11375852, retracted) - reference 10 of #
# Carlisle et al., Anaesthesia 2015;70:848-858, whose Table 1 prints the   #
# trial's baseline table and whose text gives p = 1.2e-6.                  #
#                                                                          #
# WHAT THE PAGE ACTUALLY HOLDS, which the finding's model got backwards.    #
# Table 1 "Hemodynamic Data" is a LONG table: a Group column running 1..3  #
# down the rows beneath each variable, a Baseline column, and an after-    #
# midazolam column. Six variables (HR, MAP, RAP, MPAP, PAOP, CO). The two   #
# "Stimulation" rows of Carlisle's nine are the baseline column of Table 2 #
# (Pdi), a separate table beside it; and his "RAP(2)" row is Table 1's     #
# after-dose RAP column. So the correct single-table parse of Table 1 is   #
#     6 variables x 3 arms = 18 rows, N = 8 each, no after-drug value      #
# - not the 27 the finding named, which mixes two tables and one           #
# post-treatment row. The engine reads one table; that is documented.      #
#                                                                          #
# TWO RESULTS ARE REPORTED, AND ONLY ONE IS ASSERTED. The deterministic    #
# engine (ai = "never") is what this fix changed, and it is asserted        #
# exactly. The hybrid (ai = "fallback") consults the AI whenever any flag   #
# remains - "N recovered from the document text" is one, rightly - and     #
# appends any variable the AI names that the engine did not. That can      #
# legitimately add Table 2's baseline rows, or wrongly add after-drug      #
# rows under new labels; it is the AI's reading, not the engine's, and it  #
# is reported here so the difference is visible, not asserted.             #
#                                                                          #
# Usage (R 4.5.3, from the repository root, with the dev tree or the       #
# installed package):                                                       #
#   "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" corpus/checkFujii11375852.R #
############################################################################

PDF <- Sys.getenv("INTEGRITY_FUJII_11375852",
                  "C:/dev/Fujii Boldt Reuben/Fujii/PMID_11375852.pdf")
if (!file.exists(PDF)) {
  cat("SKIP: ", PDF, " is not present on this machine.\n", sep = "")
  quit(save = "no", status = 0)
}
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
  if (requireNamespace("pkgload", quietly = TRUE) &&
      file.exists("DESCRIPTION") && !nzchar(Sys.getenv("INTEGRITY_SNAPSHOT_LIB")))
    pkgload::load_all(".", quiet = TRUE) else library(IntegrityAnalysis)
}))

# Table 1's baseline column, transcribed from the page (matches Carlisle's
# Table 1 for these six variables), and every after-dose value on it.
baseline <- data.frame(
  ROW  = rep(c("HR", "MAP", "RAP", "MPAP", "PAOP", "CO"), each = 3),
  MEAN = c(141, 143, 140, 130, 132, 131, 5, 5, 5, 12, 12, 12, 8, 8, 8, 2.2, 2.2, 2.3),
  SD   = c(15, 10, 12, 15, 12, 11, 2, 2, 2, 2, 2, 2, 2, 1, 2, 0.5, 0.4, 0.4))
afterDose <- data.frame(
  MEAN = c(142, 133, 123, 131, 121, 110, 5, 5, 5, 12, 11, 10, 8, 7, 6, 2.2, 1.8, 1.3),
  SD   = c(17, 10, 10, 17, 11, 10, 2, 1, 2, 1, 2, 1, 1, 2, 1, 0.6, 0.4, 0.5))
# RAP's after-dose pairs coincide with baseline pairs on this page (5 (2) both
# ways), so the leak test uses only the pairs that are distinguishable.
key <- function(d) paste(d$MEAN, d$SD)
afterOnly <- afterDose[!key(afterDose) %in% key(baseline), ]

fails <- 0L
chk <- function(ok, msg) {
  cat(sprintf("  [%s] %s\n", if (isTRUE(ok)) "PASS" else "FAIL", msg))
  if (!isTRUE(ok)) fails <<- fails + 1L
}

cat("=== DETERMINISTIC ENGINE (asserted) ===\n")
r <- parseBaselineTable(PDF, ai = "never", quiet = TRUE)
d <- r$data
cat("engine:", r$engine, "| caption:", r$caption, "| rows:", nrow(d), "\n")
chk(nrow(d) == 18L,                       sprintf("18 rows, 6 variables x 3 arms (got %d)", nrow(d)))
chk(nrow(r$arms) == 3L,                   sprintf("3 arms (got %d)", nrow(r$arms)))
chk(!any(is.na(r$arms$arm)) &&
      all(grepl("Group [123]", r$arms$arm)), "every arm named from the table's legend")
chk(all(r$arms$N == 8),                   "N = 8 on every arm, recovered from the Methods")
chk(all(grepl("^document text", r$armNSource)), "N is flagged as recovered from the document text")
chk(!any(key(afterOnly) %in% key(d)),     "no after-dose (MEAN, SD) pair appears in the output")
chk(all(key(baseline) %in% key(d)),       "every baseline (MEAN, SD) pair of Table 1 is present")
chk(nrow(r$skipped) == 0L,                "nothing skipped")

v <- shiny::isolate(validateData(d))
chk(!isTRUE(v$FAIL), "validateData does not fail")
if (!isTRUE(v$FAIL)) {
  set.seed(42); dqrng::dqset.seed(42)
  x <- suppressWarnings(shiny::isolate(P_Calc(v$TRIALS[1], v$DATA, v$CategoryNames, m)))
  s <- x[which(x$ROW == "Summary")[1], ]
  pNum <- suppressWarnings(as.numeric(sub("^<", "", as.character(s$P))))
  cat(sprintf("  trial p, the 6 variables of Table 1 alone: %s (max %s replicates on a row)\n",
              as.character(s$P), max(as.integer(x$M), na.rm = TRUE)),
      "  Carlisle 2015, 9 variables incl. Table 2's two and the after-dose RAP: 1.2e-6\n")
  # NOT the display floor, and deliberately so. The first draft of this check
  # asserted "<0.0001" and it FAILED at 0.00012: six variables cannot reach
  # what nine did, and the published figure includes two variables from a
  # different table. What the single-table parse must show is an unambiguous
  # alarm on the same data Carlisle read - p well below 0.01 - and that is
  # what is asserted. The 27-row engine fixture in the test suite covers the
  # published nine-variable figure separately.
  chk(is.finite(pNum) && pNum < 0.001,
      sprintf("the six Table-1 variables alone are an unambiguous alarm (p = %s < 0.001)", as.character(s$P)))
}

cat("\n=== HYBRID, ai = \"fallback\" (reported, not asserted) ===\n")
if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY"))) {
  cat("  (no ANTHROPIC_API_KEY in this session - hybrid not run)\n")
} else {
  h <- tryCatch(parseBaselineTable(PDF, ai = "fallback", quiet = TRUE),
                error = function(e) NULL)
  if (is.null(h)) cat("  hybrid parse errored\n") else {
    cat("  engine:", h$engine, "| rows:", nrow(h$data),
        "| variables:", paste(unique(h$data$ROW), collapse = ", "), "\n")
    leaked <- key(afterOnly) %in% key(h$data)
    cat("  after-dose pairs present in the hybrid output:", sum(leaked), "\n")
    kept <- all(key(d) %in% key(h$data))
    cat("  every deterministic row survives the merge:", kept, "\n")
  }
}

cat("\n", if (fails == 0L) "ALL ASSERTED CHECKS PASSED" else paste(fails, "CHECK(S) FAILED"), "\n")
quit(save = "no", status = if (fails == 0L) 0 else 1)
