# test-n-row-label.R - the N row's label: "Number", "No.", "N", "n" and
# "Number of <group noun>" (ISSUES.md issue 48, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from CJA      #
# 1996;43:362 (Loadsman corpus, Saitoh): "Number 15 15 15 15" under an     #
# arm-name header without "(n = k)". A bare "Number" was not the N row's  #
# label, the line was skipped as a bare number, and the one arm the text  #
# ladder could not place ("PIT-AP", an OCR misreading of the Methods'     #
# "PTT-AP") stayed without N. Once the row was read, a fifth cluster with #
# an N and neither a name nor a cell surfaced as an arm; an arm with an N  #
# alone is now a phantom too.                                              #
############################################################################

nRowPdf <- function(label, values, file = file.path(tempdir(), "nrow.pdf")) {
  vx <- c(230, 310, 390, 470)[seq_along(values)]
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE I Demographic data", adj = 0)),
    rowCells(100, "", c("PTT-DI", "PTT-AP", "TOF-DI", "TOF-AP")[seq_along(values)], vx),
    rowCells(118, label, values, vx),
    rowCells(136, "Sex (M/F)", rep("7/8", length(values)), vx),
    rowCells(154, "Age (yr)",  c("48.8 ± 10.0", "47.0 ± 9.1", "45.7 ± 8.8", "48.2 ± 8.9")[seq_along(values)], vx),
    rowCells(172, "Weight (kg)", c("54.8 ± 6.0", "58.0 ± 6.1", "58.5 ± 5.8", "56.9 ± 6.3")[seq_along(values)], vx),
    list(list(x = 60, y = 200, text = "(Number or mean ± SD). DI = the first dorsal interosseous muscle.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("'Number' alone labels the N row, and so do its kin", {
  r <- parseBaselineTableHeuristics(nRowPdf("Number", c("15", "15", "15", "15")), quiet = TRUE)
  # the pdf() device sets "-" as U+2212; fold it back before comparing
  expect_identical(gsub(intToUtf8(0x2212), "-", r$arms$arm), c("PTT-DI", "PTT-AP", "TOF-DI", "TOF-AP"))
  expect_identical(r$arms$N, rep(15L, 4))
  expect_false(any(grepl("^Number", r$skipped$label)))
  expect_identical(r$data$N[r$data$ROW == "Age"], rep(15L, 4))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
  for (lbl in c("No.", "N", "No. of dogs", "Number of participants")) {
    r2 <- parseBaselineTableHeuristics(nRowPdf(lbl, c("8", "8", "8"), file.path(tempdir(), "nrow2.pdf")), quiet = TRUE)
    expect_identical(r2$arms$N, rep(8L, 3), info = lbl)
  }
})

test_that("a label that merely begins with a count word is a variable, not the N row", {
  r <- parseBaselineTableHeuristics(nRowPdf("Number of previous operations", c("2", "1", "3", "2")), quiet = TRUE)
  expect_true(all(is.na(r$arms$N)) || !identical(r$arms$N, c(2L, 1L, 3L, 2L)))
})

# ---- CodeRabbit on PR #351 -------------------------------------------------
test_that("a printed N row outranks a size recovered from the document text, and clears its provenance", {
  f  <- file.path(tempdir(), "nrow3.pdf")
  vx <- c(230, 310, 390)
  cells <- c(
    list(list(x = 60, y = 50, text = "Dogs were allocated to the saline (n = 8), ketamine (n = 8) and propofol (n = 8) groups.", adj = 0)),
    list(list(x = 60, y = 80, text = "TABLE I Demographic data", adj = 0)),
    rowCells(100, "", c("Saline", "Ketamine", "Propofol"), vx),
    rowCells(118, "Number", c("10", "10", "10"), vx),
    rowCells(136, "Age (yr)", c("48.8 ± 10.0", "47.0 ± 9.1", "45.7 ± 8.8"), vx),
    rowCells(154, "Weight (kg)", c("54.8 ± 6.0", "58.0 ± 6.1", "58.5 ± 5.8"), vx))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$arms$N, rep(10L, 3))
  expect_true(all(is.na(r$armNSource)))
  expect_false(any(grepl("recovered from the document text", reviewFlags(r))))
})

