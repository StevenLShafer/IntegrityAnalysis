# test-supplementary-table-anchor.R - a supplementary table's caption,
# "Table S1", is a caption anchor (ISSUES.md issue 58, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# Loadsman corpus's 2018RezkIJGO, which files its baseline table as       #
# "Table S1. Characteristics of the study participants" (Table 1 being an #
# outcome). The anchor knew only a plain or Roman numeral, so "S1" was no  #
# caption. (That paper's supplement is not in its PDF - the page holds     #
# the captions alone - so the rule is proved on a rebuilt page.)          #
############################################################################

test_that("'Table S1' anchors a caption, starts a caption, and is listed among a line's anchors", {
  w <- data.frame(text = c("Table", "S1.", "Characteristics", "of", "the", "study", "participants."),
                  x = c(300, 330, 350, 420, 432, 450, 480), y = 200,
                  width = c(28, 16, 68, 10, 16, 26, 60), stringsAsFactors = FALSE)
  a <- .ppCaptionAnchors(w)
  expect_identical(nrow(a), 1L)
  expect_true(a$startsBlock)
  expect_true(.ppCaptionStart("Table S1. Characteristics of the study participants"))
  expect_true(.ppCaptionStart("Table S12 Baseline data"))
  expect_false(.ppCaptionStart("table sx"))     # neither a numeral nor an unnumbered caption
  expect_identical(.ppCaptionAnchorList("Table S1 Characteristics; Table S2 Adverse effects"),
                   c("table s1", "table s2"))
})

test_that("a page whose baseline table is Table S1 is parsed", {
  f  <- file.path(tempdir(), "suppl.pdf")
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 72, y = 80, text = "Table S1. Characteristics of the study participants.", adj = 0)),
    rowCells(110, "", c("Misoprostol (n = 40)", "Placebo (n = 40)"), vx),
    rowCells(140, "Age (years)",   c("27.4 ± 5.1", "26.9 ± 4.8"), vx),
    rowCells(158, "BMI (kg/m2)",   c("28.1 ± 3.9", "27.6 ± 4.2"), vx),
    rowCells(176, "Parity",        c("1.8 ± 1.1", "1.7 ± 1.0"), vx),
    list(list(x = 72, y = 210, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_match(r$caption, "^Table S1")
  expect_identical(r$arms$N, c(40L, 40L))
  expect_identical(r$data$MEAN[r$data$ROW == "Age" & !is.na(r$data$MEAN)], c(27.4, 26.9))
})
