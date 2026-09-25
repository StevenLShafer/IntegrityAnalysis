# test-degenerate-flags.R - reviewFlags() names rows that carry no sampling
# information (ISSUES.md issue 36, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) at Steve       #
# Shafer's instruction ("add the degenerate-row flag at parse time"), from #
# the corpus session's proposals: a variable printing the same value with  #
# zero dispersion in every arm (MTS2006_49, "%Edi 100.0 +/- 0.0"); a       #
# median pinned at its quartile in every arm (Akelma 2020, intraoperative  #
# ephedrine "0 (0-20)", which alone took a trial from p = 0.0084 to        #
# 0.00094); and two variables printing identical N, mean and SD in every   #
# arm - a row read twice, or the page itself (BJA2001_814 and CJA2003_342  #
# print Age and Weight with the same numbers), hence a flag and never an   #
# assertion. Synthetic pages via the pdf() device; each flag asserted on   #
# its own, and the controls that must NOT fire asserted too.               #
############################################################################

flagPage <- function(file, rows, footnote = "Values are mean ± SD.") {
  vx <- c(300, 400, 500)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline characteristics", adj = 0)),
    rowCells(110, "", c("Group 1", "Group 2", "Group 3"), vx),
    rowCells(128, "", c("(n = 8)", "(n = 8)", "(n = 8)"), vx))
  y <- 150
  for (r in rows) { cells <- c(cells, rowCells(y, r[[1]], r[[2]], vx)); y <- y + 18 }
  cells <- c(cells, list(list(x = 72, y = y + 10, text = footnote, adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a variable printing the same value with zero dispersion in every arm is flagged by name", {
  f <- file.path(tempdir(), "degenerate1.pdf")
  flagPage(f, list(
    list("Age (years)",    c("41 ± 9",      "43 ± 10",     "42 ± 8")),
    list("%Edi baseline",  c("100.0 ± 0.0", "100.0 ± 0.0", "100.0 ± 0.0")),
    list("Weight (kg)",    c("63 ± 13",     "68 ± 12",     "65 ± 11"))))
  r  <- parseBaselineTableHeuristics(f, quiet = TRUE)
  fl <- reviewFlags(r)
  expect_true(any(grepl("same value with no dispersion in every arm", fl)))
  expect_true(any(grepl("%Edi baseline", fl, fixed = TRUE)))
  expect_false(any(grepl("Age", fl)))
  expect_false(any(grepl("identical N, mean and SD", fl)))
})

test_that("zero dispersion in some arms only, or the same mean with dispersion, is not degenerate", {
  f <- file.path(tempdir(), "degenerate2.pdf")
  flagPage(f, list(
    list("Age (years)",   c("41 ± 9",   "43 ± 10", "42 ± 8")),
    list("ASA score",     c("2.0 ± 0.0", "2.1 ± 0.3", "2.0 ± 0.0")),   # SD 0 in two arms, not all
    list("Height (cm)",   c("170 ± 7",  "170 ± 6",  "170 ± 8"))))     # same mean, real SDs
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_false(any(grepl("no dispersion in every arm", reviewFlags(r))))
})

test_that("a median pinned at its quartile in every arm is flagged", {
  f <- file.path(tempdir(), "degenerate3.pdf")
  flagPage(f, list(
    list("Age (years)",                    c("41 ± 9",   "43 ± 10", "42 ± 8")),
    list("Ephedrine (mg), median [IQR]",   c("0 [0, 20]", "0 [0, 20]", "0 [0, 10]")),
    list("Duration (min), median [IQR]",   c("62 [50, 80]", "58 [45, 75]", "60 [48, 79]"))),
    footnote = "Values are mean ± SD or median [interquartile range].")
  r  <- parseBaselineTableHeuristics(f, quiet = TRUE)
  fl <- reviewFlags(r)
  expect_true(any(grepl("median pinned at its quartile", fl)))
  expect_true(any(grepl("Ephedrine", fl)))
  expect_false(any(grepl("Duration", fl)))
})

test_that("two variables printing identical N, mean and SD in every arm are flagged together, as a flag not a refusal", {
  f <- file.path(tempdir(), "degenerate4.pdf")
  flagPage(f, list(
    list("Age (years)",  c("55 ± 12", "62 ± 9",  "58 ± 10")),
    list("Weight (kg)",  c("55 ± 12", "62 ± 9",  "58 ± 10")),
    list("Height (cm)",  c("165 ± 7", "167 ± 7", "166 ± 8"))))
  r  <- parseBaselineTableHeuristics(f, quiet = TRUE)
  fl <- reviewFlags(r)
  expect_true(any(grepl("identical N, mean and SD in every arm", fl)))
  expect_true(any(grepl("Age = Weight|Weight = Age", fl)))
  expect_false(any(grepl("Height", fl)))
  # the rows are still there: the reader decides, the engine does not refuse
  expect_identical(sum(r$data$ROW == "Weight"), 3L)
  v <- vdShared(r$data)
  expect_false(isTRUE(v$FAIL))
})

test_that("a table with none of these raises none of these flags", {
  f <- file.path(tempdir(), "degenerate5.pdf")
  flagPage(f, list(
    list("Age (years)",  c("41 ± 9",  "43 ± 10", "42 ± 8")),
    list("Weight (kg)",  c("63 ± 13", "68 ± 12", "65 ± 11"))))
  fl <- reviewFlags(parseBaselineTableHeuristics(f, quiet = TRUE))
  expect_false(any(grepl("no dispersion|pinned at its quartile|identical N, mean and SD", fl)))
})
