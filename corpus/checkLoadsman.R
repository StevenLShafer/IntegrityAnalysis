# checkLoadsman.R - the three parser defects of the Loadsman finding, checked
# on the real articles (docs/audits/2026-09-24-duplicate-rows-and-percent-
# as-sd-cowork.md; ISSUES.md issue 35), and an invariant over the corpus.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1). The corpus    #
# is 52 randomised trials supplied by John Loadsman (editor, Anaesthesia   #
# and Intensive Care); the PDFs are copyrighted and live outside the       #
# repository, so this script SKIPS, with exit status 0, when the folder    #
# is not present - like corpus/checkFujii11375852.R. The synthetic         #
# regressions that always run are tests/testthat/test-loadsman-layouts.R. #
#                                                                          #
# Deterministic engine only (ai = "never"): what is asserted here is the   #
# parser, not a model reply. The AI-merge behaviour on Polat (the model's  #
# fuller labels dropped as value duplicates) is exercised by the mocked    #
# merge test in test-loadsman-layouts.R and was seen live on 2026-09-24.   #
#                                                                          #
# Usage (from the repository root, R 4.5.3):                               #
#   "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" corpus/checkLoadsman.R    #
# Set INTEGRITY_LOADSMAN to the folder holding the PDFs if it is elsewhere.#
############################################################################

DIR <- Sys.getenv("INTEGRITY_LOADSMAN", "C:/dev/Fujii Boldt Reuben/Loadsman/RCT")
if (!dir.exists(DIR)) {
  cat("SKIP: ", DIR, " is not present on this machine.\n", sep = "")
  quit(save = "no", status = 0)
}
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(dqrng)
}))
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(IntegrityAnalysis)
}
cat("engine from:", if (isNamespaceLoaded("IntegrityAnalysis"))
  getNamespaceInfo("IntegrityAnalysis", "path") else "?", "\n")

fails <- 0L
chk <- function(ok, what) {
  cat(if (isTRUE(ok)) "  [PASS] " else "  [FAIL] ", what, "\n", sep = "")
  if (!isTRUE(ok)) fails <<- fails + 1L
  invisible(ok)
}
parse <- function(name) {
  parseBaselineTableHeuristics(file.path(DIR, paste0(name, ".pdf")), quiet = TRUE)
}
contRows <- function(d) !is.na(d$MEAN) & !is.na(d$SD)

cat("\n=== Polat 2015 DA Retracted: truncated labels, duplicated variables ===\n")
r <- parse("Polat 2015 DA Retracted"); d <- r$data
chk(sum(contRows(d)) == 9L,
    paste0("9 continuous rows, 3 variables x 3 arms of 30 (got ", sum(contRows(d)), ")"))
chk(all(d$N[contRows(d)] == 30), "every continuous row carries N = 30")
chk(!anyDuplicated(d[contRows(d), c("ROW", "N", "MEAN", "SD")]),
    "no (ROW, N, MEAN, SD) tuple is repeated")
lab <- unique(d$ROW)
chk(!any(vapply(lab, function(a) any(lab != a & startsWith(lab, paste0(a, " "))), logical(1))),
    "no label is a word-prefix of another (no truncated twin)")
chk("Amount of intraoperative fluid" %in% lab && "Infusion duration of study drug" %in% lab,
    "the wrapped labels are read whole")

cat("\n=== Akkaya 2015 EJA: counts with percentages, and the download rail ===\n")
r <- parse("Akkaya 2015 EJA"); d <- r$data
chk(!any(grepl("(?i)downloaded|http|lww", d$ROW, perl = TRUE)),
    "no row label carries a word from the download banner")
chk(sum(contRows(d) & d$SD > d$MEAN) == 0L,
    paste0("no scored mean (SD) row has SD > MEAN (got ",
           sum(contRows(d) & d$SD > d$MEAN), ")"))
chk(sum(contRows(d)) < 48L,
    paste0("not 48 continuous rows (got ", sum(contRows(d)), ")"))
catCols <- setdiff(names(d), c(.ppBaseColumns(), "Q1", "Q3"))
chk(length(catCols) > 0, paste0("the counts are categories (", length(catCols), " level columns)"))

cat("\n=== 10.17826-cumj.1221051-2839894: ASA I and ASA II stay two variables ===\n")
r <- parse("10.17826-cumj.1221051-2839894"); d <- r$data
lab <- unique(d$ROW)
chk(any(grepl("^ASA I$|^I$", lab)) && any(grepl("^ASA II$|^II$", lab)),
    paste0("ASA I and ASA II both present as rows (rows: ",
           paste(grep("ASA|^I{1,2}$", lab, value = TRUE), collapse = ", "), ")"))

cat("\n=== corpus invariant: a table that is mostly SD > MEAN is flagged ===\n")
pdfs <- list.files(DIR, "[.]pdf$", full.names = TRUE)
bad <- character(0); parsed <- 0L
for (f in pdfs) {
  r <- tryCatch(parseBaselineTableHeuristics(f, quiet = TRUE), error = function(e) NULL)
  if (is.null(r) || nrow(r$data) == 0) next
  parsed <- parsed + 1L
  d <- r$data; cont <- contRows(d)
  if (sum(cont) >= 3 && sum(cont & d$MEAN >= 0 & d$SD > d$MEAN) >= 0.5 * sum(cont) &&
      !any(grepl("SD larger than the mean", reviewFlags(r))))
    bad <- c(bad, basename(f))
}
chk(length(bad) == 0L,
    paste0(parsed, " of ", length(pdfs), " PDFs parsed; every table with SD > MEAN on ",
           "half or more of its mean (SD) cells carries the flag",
           if (length(bad)) paste0(" - EXCEPT: ", paste(bad, collapse = ", ")) else ""))

cat("\n", if (fails == 0L) "ALL CHECKS PASSED" else paste(fails, "CHECK(S) FAILED"), "\n")
quit(save = "no", status = if (fails == 0L) 0 else 1)
