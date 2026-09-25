# test-narrow-gutter-band.R - a gutter no line of the page crosses is a
# column boundary at eight points wide (ISSUES.md issue 57, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# Loadsman corpus's Altuntas 2016 TJAR: its two columns are 9 points       #
# apart, short of .ppPageBands()' minGap of 12, so no band was found and   #
# the table in column 2 was read interleaved with column 1's prose. Zero   #
# coverage across every line of the page is the signature of the page's   #
# own layout; a gap inside a table's columns is crossed by the prose      #
# above and below it.                                                      #
############################################################################

# a page of `nLines` lines: column 1 spans x 40-291, column 2 x 300-560
twoColumnWords <- function(nLines = 40, gapFrom = 292, gapTo = 299, crossers = 0L) {
  rows <- list()
  for (k in seq_len(nLines)) {
    y <- 60 + 14 * k
    for (x in seq(40, gapFrom - 30, by = 30))
      rows[[length(rows) + 1]] <- data.frame(text = "word", x = x, y = y, width = 26, height = 10)
    for (x in seq(gapTo + 1, 540, by = 30))
      rows[[length(rows) + 1]] <- data.frame(text = "word", x = x, y = y, width = 26, height = 10)
  }
  # lines that cross the gutter, as a full-width table row would
  for (k in seq_len(crossers)) {
    y <- 60 + 14 * (nLines + k)
    for (x in seq(40, 540, by = 30))
      rows[[length(rows) + 1]] <- data.frame(text = "word", x = x, y = y, width = 26, height = 10)
  }
  do.call(rbind, rows)
}

test_that("a gutter of eight points that no line crosses splits the page; one crossed by lines does not", {
  b <- .ppPageBands(twoColumnWords(gapFrom = 292, gapTo = 299))
  expect_identical(nrow(b), 2L)
  expect_true(b$x1[1] > 285 && b$x1[1] < 305)
  # the same page with a handful of lines running across the gap: no band at eight points
  b2 <- .ppPageBands(twoColumnWords(gapFrom = 292, gapTo = 299, crossers = 6L))
  expect_identical(nrow(b2), 1L)
  # a wide gutter still splits even when a few lines cross it (the old rule)
  b3 <- .ppPageBands(twoColumnWords(gapFrom = 280, gapTo = 310, crossers = 2L))
  expect_identical(nrow(b3), 2L)
})
