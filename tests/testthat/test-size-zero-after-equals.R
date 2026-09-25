# test-size-zero-after-equals.R - "(n =3o)" with the equals sign glued to
# the size is repaired like "(n=3o)" and "(n = 3o)" (ISSUES.md issue 100,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24: the CJA 1998 scan PMID 9512856 prints         #
# "(n = 3o) (n =3o)" over its two arms; issue 75's repair reached the      #
# first and the second read as an arm of 3 named "o)".                     #
############################################################################

test_that("the helper repairs the size after a glued equals sign, and only in an (n = k) group", {
  mk <- function(text) data.frame(text = text, x = seq_along(text) * 40, width = 20, y = 0,
                                  stringsAsFactors = FALSE)
  lines <- list(
    mk(c("Table", "1")),
    mk(c("Group", "ET", "Group", "LMA")),
    mk(c("(n", "=", "3o)", "(n", "=3o)")),
    mk(c("pH", "=7.4o", "7.35")))                  # not a size: untouched
  rep <- .ppRepairSizeZeros(lines, capIdx = 1L)
  expect_identical(rep$lines[[3]]$text, c("(n", "=", "30)", "(n", "=30)"))
  expect_identical(rep$lines[[4]]$text, lines[[4]]$text)
  expect_identical(rep$repaired, 2L)
})

gluedEqPdf <- function(file = file.path(tempdir(), "gluedEq.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 60, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(90, "", c("Group ET", "Group LMA"), vx),
    list(list(x = 288, y = 104, text = "(n = 3o)", adj = 0), list(x = 408, y = 104, text = "(n =3o)", adj = 0)),
    rowCells(122, "Age (yr)", c("6.7 \u00b1 2.3", "6.4 \u00b1 2.2"), vx),
    rowCells(140, "Height (cm)", c("120.4 \u00b1 11.1", "119.6 \u00b1 12.5"), vx),
    rowCells(158, "Weight (kg)", c("24.2 \u00b1 6.4", "24.4 \u00b1 6.6"), vx),
    list(list(x = 60, y = 190, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with '(n = 3o) (n =3o)' reads two arms of 30", {
  r <- parseBaselineTableHeuristics(gluedEqPdf(), quiet = TRUE)
  expect_identical(r$arms$N, c(30L, 30L))
  expect_false(any(grepl("o[)]", r$arms$arm)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
