# test-arm-n-from-fraction.R - a table that prints no arm size but a sex
# fraction in every arm gets its N from the fraction (ISSUES.md issue 41,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's Loadsman batch (CJA 2003;50:342, Saitoh): the table's  #
# only statement of its arm sizes is "Sex (female/male) 6/9" in each of   #
# four arms; the n (%) derivation of arm N had no counterpart for a       #
# fraction cell, so the table parsed with N missing and failed validation.#
############################################################################

fractionPdf <- function(cells2 = NULL, file = file.path(tempdir(), "fraction.pdf")) {
  vx <- c(230, 310, 390, 470)
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE Patient characteristics (number or mean ± SD)", adj = 0)),
    rowCells(100, "", c("P-PTC", "S-PTC", "P-TOF", "S-TOF"), vx),
    rowCells(118, "Sex (female/male)", c("6/9", "6/9", "6/9", "6/9"), vx),
    rowCells(136, "Age (yr)",    c("46 ± 8", "47 ± 7", "47 ± 7", "48 ± 7"), vx),
    rowCells(154, "Weight (kg)", c("56 ± 6", "57 ± 6", "56 ± 7", "57 ± 6"), vx),
    cells2,
    list(list(x = 60, y = 200, text = "P = prone; S = supine; PTC = post-tetanic count.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("every arm's N is the sum of its fraction, with its source, and the table validates", {
  r <- parseBaselineTableHeuristics(fractionPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(15L, 4))
  expect_true(all(grepl("fraction cell", r$armNSource)))
  expect_identical(r$data$N[r$data$ROW == "Age"], rep(15L, 4))
  expect_true(any(grepl("a/b fraction cells", reviewFlags(r))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("two fraction rows that disagree leave N unknown; a printed arm size switches the derivation off", {
  disagree <- rowCells(172, "ASA (I/II)", c("5/8", "6/9", "7/8", "5/10"), c(230, 310, 390, 470))
  r <- parseBaselineTableHeuristics(fractionPdf(disagree, file.path(tempdir(), "fr2.pdf")), quiet = TRUE)
  expect_identical(r$arms$N, c(NA_integer_, 15L, 15L, 15L))   # arms 3 and 4: both fractions sum to 15
  # with "(n = 15)" printed for one arm no derivation runs for any
  f <- file.path(tempdir(), "fr3.pdf")
  vx <- c(230, 310, 390, 470)
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE Patient characteristics", adj = 0)),
    rowCells(100, "", c("P-PTC (n = 15)", "S-PTC", "P-TOF", "S-TOF"), vx),
    rowCells(118, "Sex (female/male)", c("6/9", "6/9", "6/9", "6/9"), vx),
    rowCells(136, "Age (yr)", c("46 ± 8", "47 ± 7", "47 ± 7", "48 ± 7"), vx))
  makeTablePdf(f, cells)
  r3 <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r3$arms$N, c(15L, NA_integer_, NA_integer_, NA_integer_))
})
