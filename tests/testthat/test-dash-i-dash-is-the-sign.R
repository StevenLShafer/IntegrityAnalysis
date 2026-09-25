# test-dash-i-dash-is-the-sign.R - "-I-" between two numbers is the
# plus-minus sign, alone or glued to a number, on a page with no genuine
# glyph for the slot rule to lean on (ISSUES.md issue 123, 2026-09-26); and
# "-1-", the digit one for the I, is the same sign (issue 124).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's survey of "-I-" across the Fujii, Boldt, Reuben and     #
# Loadsman PDFs (batch 27): eight papers carry it as the sign on data      #
# lines ("149 -I- 13", "54.2 -I-7.1", "18.0 --I-1.8", "10141-I- 1977",     #
# "114.7 -I- 5.5a,b,c"), the other five in prose only ("ASA-I- bis").      #
# PMID 7889590 sets every sign so, over nine lines, and read no cell.      #
############################################################################

words <- function(...) {
  w <- c(...)
  data.frame(text = w, x = cumsum(c(0, head(nchar(w) + 1, -1))) * 6, width = nchar(w) * 6,
             stringsAsFactors = FALSE)
}
pm <- "\u00b1"

test_that("the helper restores the sign alone, glued before, after, and both, and only between numbers", {
  r <- .ppRepairDashIDash(list(words("Table"), words("Age", "149", "-I-", "13", "152", "-I-", "12")), capIdx = 1L)
  expect_identical(r$repaired, 2L)
  expect_identical(r$lines[[2]]$text, c("Age", "149", pm, "13", "152", pm, "12"))
  r <- .ppRepairDashIDash(list(words("Weight", "54.2", "-I-7.1", "18.0", "--I-1.8", "10141-I-", "1977")))
  expect_identical(r$repaired, 3L)
  expect_identical(r$lines[[1]]$text, c("Weight", "54.2", pm, "7.1", "18.0", pm, "1.8", "10141", pm, "1977"))
  # the split words keep their x extent: the sign sits where its characters were
  L <- r$lines[[1]]
  expect_true(all(diff(L$x) > 0))
  expect_equal(L$x[nrow(L)] + L$width[nrow(L)], 6 * (nchar("Weight 54.2 -I-7.1 18.0 --I-1.8 10141-I- 1977")))
  r <- .ppRepairDashIDash(list(words("MAP", "114.7", "-I-", "5.5a,b,c")))
  expect_identical(r$lines[[1]]$text[3], pm)
  # the digit one for the I (issue 124; PMID 7497558's "62-1-11"): the same
  # family; the "-k I1" cell of that line has no route and stays as it is
  r <- .ppRepairDashIDash(list(words("Age", "(yr)", "63+8", "60", "-k", "I1", "62-1-11")))
  expect_identical(r$repaired, 1L)
  expect_identical(r$lines[[1]]$text, c("Age", "(yr)", "63+8", "60", "-k", "I1", "62", pm, "11"))
  r <- .ppRepairDashIDash(list(words("HR", "72", "-1-", "11", "75", "--1-", "10")))
  expect_identical(r$lines[[1]]$text, c("HR", "72", pm, "11", "75", pm, "10"))
  # ... but not an address: the digit form needs a cell's numbers on both
  # sides and no comma after (BJA1999_340's "2-1-1, Hongo" read as "2 +/- 1")
  r <- .ppRepairDashIDash(list(words("Hospital,", "2-1-1,", "Hongo,", "Toride"), words("at", "12-1-1", "Hongo"),
                               words("5", "-1-", "3", "ratio")))
  expect_identical(r$repaired, 0L)
  # prose forms are not signs: no number on both sides
  r <- .ppRepairDashIDash(list(words("ASA-I-", "bis", "II"), words("HS-I-IES"), words("ROCHA-I-SILVA", "1990")))
  expect_identical(r$repaired, 0L)
  # a line before the caption is untouched
  r <- .ppRepairDashIDash(list(words("2", "-I-", "3"), words("Table")), capIdx = 2L)
  expect_identical(r$repaired, 0L)
})

dashIDashPdf <- function(file = file.path(tempdir(), "dashIDash.pdf")) {
  vx <- c(230, 320, 410)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Haemodynamic data", adj = 0)),
    rowCells(100, "", c("A (n = 20)", "B (n = 20)", "C (n = 20)"), vx),
    rowCells(130, "Heart rate (beats/min)", c("72 -I- 11", "75 -I- 10", "70 -I- 12"), vx),
    rowCells(148, "MAP (mmHg)", c("94 -I- 12", "96 -I-11", "93 -1- 13"), vx),
    rowCells(166, "Weight (kg)", c("54.2 -I-7.1", "55.0 --I-6.8", "53.9 -I- 7.4"), vx),
    list(list(x = 60, y = 200, text = "Values are mean and SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page whose every sign is -I- reads every cell", {
  r <- parseBaselineTableHeuristics(dashIDashPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Heart rate", cont$ROW)], c(72, 75, 70))
  expect_identical(cont$SD[cont$ROW == "MAP"], c(12, 11, 13))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(54.2, 55.0, 53.9))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(7.1, 6.8, 7.4))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
