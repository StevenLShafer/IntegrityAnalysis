# test-caption-number-with-glyph.R - a caption whose number carries a stray
# OCR glyph ("Table 1<bullet> Demographic Data") is still a caption anchor
# (ISSUES.md issue 115, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE9 (Donmez 1998 JCVA, Loadsman corpus): once  #
# issue 96 kept the word "1<bullet>", neither anchor rule matched, page 2   #
# had no candidate, and the assisted route handed the model page 1, which  #
# has no table.                                                            #
############################################################################

test_that("the caption anchor accepts a number followed by one stray glyph, and the plain forms as before", {
  page <- data.frame(
    text = c("Table", "1\u2022", "Demographic", "Data",
             "Table", "2.", "Outcomes",
             "TABLE", "III", "Adverse", "events",
             "Table", "1x", "Not", "a", "caption"),
    x = c(53, 73, 82, 129, 53, 73, 82, 53, 80, 95, 130, 53, 73, 82, 100, 110),
    y = c(100, 100, 100, 100, 300, 300, 300, 500, 500, 500, 500, 700, 700, 700, 700, 700),
    width = 20, height = 8, stringsAsFactors = FALSE)
  a <- .ppCaptionAnchors(page)
  expect_identical(nrow(a), 3L)
  expect_setequal(a$y, c(100, 300, 500))
})

glyphCaptionPdf <- function(file = file.path(tempdir(), "glyphCaption.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 53, y = 60, text = "Table 1\u2022 Demographic Data, CPB Time, and Type of Operation", adj = 0)),
    rowCells(90, "", c("Etomidate (n = 15)", "Ketamine (n = 15)"), vx, labelX = 53),
    rowCells(108, "Age (yr)", c("5.1 \u00b1 0.9", "3.0 \u00b1 0.7"), vx, labelX = 53),
    rowCells(126, "Weight (kg)", c("15.9 \u00b1 1.8", "13.3 \u00b1 1.9"), vx, labelX = 53),
    rowCells(144, "CPB time (min)", c("60.9 \u00b1 6.2", "56.4 \u00b1 7.3"), vx, labelX = 53),
    list(list(x = 53, y = 176, text = "Data are presented as mean \u00b1 standard error.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page whose caption number carries a bullet is found and read", {
  r <- parseBaselineTableHeuristics(glyphCaptionPdf(), quiet = TRUE)
  expect_true(grepl("^Table 1", r$caption))
  expect_identical(r$arms$N, c(15L, 15L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(5.1, 3.0))
  expect_true(all(is.na(cont$SD)) && all(!is.na(cont$SE)))   # "standard error" in the footnote
})
