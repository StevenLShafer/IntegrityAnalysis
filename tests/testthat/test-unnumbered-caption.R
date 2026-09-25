# test-unnumbered-caption.R - a paper's only table, captioned "TABLE
# Demographic data" with no numeral, is found (ISSUES.md issue 39,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's finding on the Saitoh papers of the Loadsman corpus     #
# (CJA 1997;44:390 "TABLE Demographic data", CJA 2003;50:342 "TABLE        #
# Patient characteristics (number or mean +/- SD)"): .ppCaptionAnchors()  #
# required a numeral after "Table", so neither table became a candidate   #
# and both papers failed with "no usable baseline table". The anchor now  #
# also accepts a bare "TABLE"/"Table" followed by a Capitalised word,     #
# provided the caption starts its block.                                   #
############################################################################

test_that("a bare TABLE followed by a capitalised word anchors a caption; prose and cross-references do not", {
  cap <- data.frame(text = c("TABLE", "Demographic", "data"),
                    x = c(306, 340, 400), y = 640, width = c(30, 56, 22),
                    stringsAsFactors = FALSE)
  a <- .ppCaptionAnchors(cap)
  expect_identical(nrow(a), 1L)
  expect_true(a$startsBlock)
  # the same words with the other column's prose on the line: a gap of
  # 30 pt or more to the left still makes it a caption ...
  prose <- data.frame(text = c("Tokyo,", "Japan)"), x = c(216, 248), y = 640,
                      width = c(30, 28), stringsAsFactors = FALSE)
  expect_identical(nrow(.ppCaptionAnchors(rbind(prose, cap))), 1L)
  # ... but "TABLE Demographic" run on from the words before it is not
  # (an unnumbered anchor must start its block; a numbered one is merely
  # demoted)
  tight <- cap; tight$x <- c(292, 326, 386)
  expect_identical(nrow(.ppCaptionAnchors(rbind(prose, tight))), 0L)
  numbered <- data.frame(text = c("in", "Table", "3", "we"), x = c(270, 292, 320, 330),
                         y = 640, width = c(10, 26, 8, 14), stringsAsFactors = FALSE)
  an <- .ppCaptionAnchors(numbered)
  expect_identical(nrow(an), 1L)
  expect_false(an$startsBlock)
  # lower-case "table" in a sentence, and "Table shows" (no capital), anchor nothing
  sentence <- data.frame(text = c("table", "and", "the", "knee"), x = c(54, 80, 100, 120),
                         y = 683, width = c(24, 18, 16, 22), stringsAsFactors = FALSE)
  expect_identical(nrow(.ppCaptionAnchors(sentence)), 0L)
  shows <- data.frame(text = c("Table", "shows", "that"), x = c(54, 84, 118),
                      y = 683, width = c(26, 30, 22), stringsAsFactors = FALSE)
  expect_identical(nrow(.ppCaptionAnchors(shows)), 0L)
  # a numeral after "TABLE" is the numbered anchor, counted once
  roman <- data.frame(text = c("TABLE", "II", "Outcomes"), x = c(54, 90, 110),
                      y = 100, width = c(30, 12, 44), stringsAsFactors = FALSE)
  expect_identical(nrow(.ppCaptionAnchors(roman)), 1L)
})

test_that(".ppCaptionStart() knows numbered and unnumbered captions, and an unnumbered caption scores as a numbered one", {
  expect_identical(.ppCaptionStart(c("Table 1 Patient data", "TABLE II. Outcomes", "Tab. 3",
                                     "TABLE Demographic data", "Table Patient characteristics",
                                     "table and the knee", "Table shows", "TABLE I")),
                   c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE))
  expect_equal(.ppCaptionScore("TABLE Demographic data"),
               .ppCaptionScore("Table 1 Demographic data"))
  expect_equal(.ppCaptionScore("TABLE Patient characteristics (number or mean)"),
               .ppCaptionScore("TABLE I Patient characteristics (number or mean)"))
})

test_that("a page whose only table is captioned without a number is parsed", {
  f  <- file.path(tempdir(), "unnumbered.pdf")
  vx <- c(300, 380, 460)
  cells <- c(
    list(list(x = 72, y = 80, text = "TABLE Demographic data", adj = 0)),
    rowCells(110, "", c("Group 1", "Group 2", "Group 3"), vx),
    rowCells(128, "n", c("40", "40", "10"), vx),
    rowCells(150, "Sex M:F",   c("19:21", "19:21", "5:5"), vx),
    rowCells(168, "Age (yr)",  c("45.6 ± 8.2", "47.7 ± 7.7", "46.2 ± 7.7"), vx),
    rowCells(186, "Height (cm)", c("166.6 ± 8.4", "167.3 ± 9.8", "166.3 ± 8.9"), vx),
    rowCells(204, "Weight (kg)", c("56.5 ± 6.7", "57.9 ± 6.4", "55.8 ± 6.2"), vx),
    list(list(x = 72, y = 230, text = "Number or mean ± SD.", adj = 0)),
    list(list(x = 72, y = 260, text = "Sex, age, height, or body weight did not differ among the groups.", adj = 0))
  )
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_match(r$caption, "^TABLE Demographic data")
  expect_identical(r$arms$N, c(40L, 40L, 10L))
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$MEAN[grepl("^Age", d$ROW)], c(45.6, 47.7, 46.2))
  expect_identical(d$SD[grepl("^Weight", d$ROW)], c(6.7, 6.4, 6.2))
})
