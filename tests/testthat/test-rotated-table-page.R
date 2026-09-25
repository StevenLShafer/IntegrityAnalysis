# test-rotated-table-page.R - a table printed sideways on a portrait page is
# read upright (ISSUES.md issue 38, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's finding I1 (RezkHiF2020, Hypertens Pregnancy 2020): the #
# baseline table is printed rotated 90 degrees on page 5, poppler reports  #
# every one of its words with the box swapped, the watermark-rail stripper #
# removed them as a rail, and both engines scored the OUTCOMES tables of   #
# page 6 as the baseline table. .ppRotatedBlock() now transposes such a    #
# block into an extra upright page. The pdf() device sets text sideways    #
# with srt = 90, and poppler reports it exactly as it reports the real     #
# page, so the synthetic page here exercises the whole route.              #
############################################################################

rotatedPagePdf <- function(file = file.path(tempdir(), "rotated.pdf")) {
  # a table rotated counter-clockwise: each row of the table is a column of
  # text on the page, read bottom to top; rows advance left to right. The
  # table's y-band is 700 (bottom of the words) upward; cell "columns" are
  # at increasing page y for successive table columns.
  rowX <- c(90, 104, 118, 132, 146, 160, 174)            # header + 6 rows, left to right
  colY <- c(720, 540, 410, 280, 150)                      # label, arm 1, arm 2, arm 3, p
  cell <- function(r, c, text) list(x = rowX[r], y = colY[c], text = text, adj = 0, srt = 90)
  cells <- list(
    list(x = 76, y = 720, text = "Table 1. Maternal characteristics.", adj = 0, srt = 90),
    cell(1, 2, "Methyldopa (n = 164)"), cell(1, 3, "Labetalol (n = 160)"),
    cell(1, 4, "Control (n = 162)"),    cell(1, 5, "P-value"),
    cell(2, 1, "SBP at enrollment (mmHg)"),   cell(2, 2, "152.12 ± 5.62"), cell(2, 3, "151.13 ± 5.24"), cell(2, 4, "151.1 ± 5.33"),  cell(2, 5, ">0.05"),
    cell(3, 1, "DBP at enrollment (mmHg)"),   cell(3, 2, "97.2 ± 4.77"),   cell(3, 3, "98.11 ± 4.12"),  cell(3, 4, "98.21 ± 4.33"),  cell(3, 5, ">0.05"),
    cell(4, 1, "Gestational age (weeks)"),    cell(4, 2, "8.21 ± 1.67"),   cell(4, 3, "8.11 ± 1.74"),   cell(4, 4, "8.21 ± 1.42"),   cell(4, 5, ">0.05"),
    cell(5, 1, "Duration of hypertension (years)"), cell(5, 2, "3.51 ± 1.72"), cell(5, 3, "3.68 ± 1.43"), cell(5, 4, "3.71 ± 1.73"), cell(5, 5, ">0.05"),
    cell(6, 1, "Weight (kg)"),                cell(6, 2, "71.2 ± 9.8"),    cell(6, 3, "70.4 ± 10.1"),   cell(6, 4, "72.0 ± 9.5"),    cell(6, 5, ">0.05"),
    cell(7, 1, "Values are mean ± SD."),
    # upright prose in the right-hand column, as on the real page
    list(x = 330, y = 120, text = "Results", adj = 0),
    list(x = 330, y = 140, text = "The three groups were comparable at enrollment", adj = 0),
    list(x = 330, y = 156, text = "with respect to blood pressure and gestational age.", adj = 0),
    list(x = 330, y = 172, text = "Severe hypertension developed in 14 women of the", adj = 0),
    list(x = 330, y = 188, text = "methyldopa group and 12 of the labetalol group.", adj = 0))
  makeTablePdf(file, cells)
}

test_that("the rotated block of a page is found and transposed; a normal page and a rail are left alone", {
  w <- pdftools::pdf_data(rotatedPagePdf())[[1]]
  H <- pdftools::pdf_pagesize(rotatedPagePdf())$height[1]
  # the rotated words really are rotated as poppler reports them
  rot <- w[nchar(w$text) >= 3 & w$height > w$width, ]
  expect_true(nrow(rot) >= 30)
  rb <- .ppRotatedBlock(w, H)
  expect_false(is.null(rb))
  # upright prose is not in the block
  expect_false(any(grepl("comparable|hypertension developed", rb$text)))
  # the caption reads in order along x' - the block is upright now
  lines <- .ppBuildLines(rb)
  lt <- vapply(lines, .ppLineText, character(1))
  expect_true(any(grepl("^Table 1\\. Maternal characteristics", lt)))
  expect_true(any(grepl("^SBP at enrollment.*152\\.12", lt)))
  # an upright page yields nothing; a six-word watermark rail is not a table
  upright <- data.frame(text = c("Age", "45.3", "(12.1)", "Weight", "76.4", "(16.5)"),
                        x = c(72, 230, 260, 72, 230, 260), y = c(100, 100, 100, 130, 130, 130),
                        width = c(18, 20, 28, 35, 20, 28), height = 11, stringsAsFactors = FALSE)
  expect_null(.ppRotatedBlock(upright, 792))
})

test_that("a table printed sideways is read as the baseline table, with its values and its page", {
  r <- parseBaselineTableHeuristics(rotatedPagePdf(), quiet = TRUE)
  expect_match(r$caption, "^Table 1\\. Maternal characteristics")
  expect_identical(r$pages, 1L)                          # reported as the REAL page
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$MEAN[grepl("^SBP", d$ROW)], c(152.12, 151.13, 151.1))
  expect_identical(d$SD[grepl("^SBP", d$ROW)],   c(5.62, 5.24, 5.33))
  expect_identical(d$MEAN[grepl("^Weight", d$ROW)], c(71.2, 70.4, 72.0))
  expect_true(all(c(164L, 160L, 162L) %in% r$arms$N))
  v <- vdShared(r$data)
  expect_false(isTRUE(v$FAIL))
})
