# test-widest-gutters-no-hole.R - the page's column gutters are taken
# widest first, and no band is ever dropped, so every word lies in one
# band (ISSUES.md issue 72, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 16 finding V1 (Akkus 2020, J Anesth, Loadsman     #
# corpus, page 4): three low-coverage runs qualified - two gaps inside     #
# Table 1's own columns (19 and 12 points) and the real gutter (25         #
# points). The two leftmost were taken, the narrow band between them was  #
# dropped, and the table's second arm ("Group triple" and all its cells)  #
# belonged to no column and was read by no candidate.                     #
############################################################################

# A page of word boxes: `spans` is a list of x ranges per line kind, each
# line one word per range, `n` lines of each kind, stacked down the page.
wordPage <- function(kinds) {
  out <- list(); y <- 50
  for (k in kinds) for (i in seq_len(k$n)) {
    for (sp in k$spans)
      out[[length(out) + 1]] <- data.frame(text = "w", x = sp[1], width = sp[2] - sp[1], y = y,
                                           height = 8, stringsAsFactors = FALSE)
    y <- y + 12
  }
  do.call(rbind, out)
}

test_that("two table-internal gaps left of the real gutter do not swallow the table's second arm", {
  w <- wordPage(list(
    list(n = 30, spans = list(c(50, 188))),                                  # short column-1 prose
    list(n = 30, spans = list(c(310, 540))),                                 # column-2 prose
    list(n = 10, spans = list(c(50, 150), c(160, 190), c(210, 248), c(262, 280)))))  # the table
  b <- .ppPageBands(w)
  expect_identical(nrow(b), 2L)
  expect_true(b$x1[1] > 280 && b$x1[1] < 310)           # the cut is the real gutter
  mids <- w$x + w$width / 2
  inBand <- vapply(mids, function(m) any(m > b$x0 & m <= b$x1), logical(1))
  expect_true(all(inBand))                                # no hole
  expect_true(all(mids[mids > 200 & mids < 260] <= b$x1[1]))   # the second arm is in column 1
})

test_that("a genuine three-column page still gives three bands", {
  w <- wordPage(list(
    list(n = 40, spans = list(c(50, 180), c(200, 330), c(350, 480)))))
  b <- .ppPageBands(w)
  expect_identical(nrow(b), 3L)
})

test_that("a gutter that would leave a band too narrow is skipped, not cut and discarded", {
  # one real gutter at 281..309 and one gap at 191..209 that no line crosses
  w <- wordPage(list(
    list(n = 40, spans = list(c(50, 190), c(210, 280))),
    list(n = 40, spans = list(c(310, 540)))))
  b <- .ppPageBands(w)
  expect_identical(nrow(b), 2L)
  expect_true(b$x1[1] > 280)
})
