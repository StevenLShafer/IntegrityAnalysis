# test-long-layout-roman-letter-groups.R - "Ia" and "Ib" under Group are
# letter labels, and a size that names the group beats a count-less
# statement for another experiment's groups (ISSUES.md issue 110,
# 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 AE1 (Fujii, CJA 2000, PMID 11132748): the      #
# reader stood aside on "Ia"/"Ib" and the wide reader took Baseline and    #
# 30 min for the arms, twelve "variables" in two arms of 8, p 0.359.       #
############################################################################

romanLetterPdf <- function(file = file.path(tempdir(), "romanLetter.pdf")) {
  vx <- c(230, 320, 420)   # Group, Baseline, 30 min
  row <- function(y, label, g, base, later) c(
    if (nzchar(label)) list(list(x = 60, y = y, text = label, adj = 0)) else list(),
    list(list(x = vx[1], y = y, text = g, adj = 0.5),
         list(x = vx[2], y = y, text = base, adj = 0.5),
         list(x = vx[3], y = y, text = later, adj = 0.5)))
  cells <- c(
    list(list(x = 60, y = 40, text = "Dogs were randomized among four groups: Groups Ia (n=6), Ib (n=8), IIa (n=8) and IIb (n=8).", adj = 0)),
    list(list(x = 60, y = 52, text = "In Groups IIa and IIb (n=8 each), diaphragmatic fatigue was induced by stimulation.", adj = 0)),
    list(list(x = 60, y = 90, text = "TABLE I Hemodynamic data and changes in nonfatigued diaphragm", adj = 0)),
    list(list(x = vx[3], y = 104, text = "30 min (Group Ia)", adj = 0.5)),
    list(list(x = 60, y = 116, text = "Variable", adj = 0),
         list(x = vx[1], y = 116, text = "Group", adj = 0.5),
         list(x = vx[2], y = 116, text = "Baseline", adj = 0.5),
         list(x = vx[3], y = 116, text = "Olprinone (Group Ib)", adj = 0.5)),
    row(134, "HR (bpm)", "Ia", "141 \u00b1 10", "140 \u00b1 11"),
    row(146, "", "Ib", "141 \u00b1 10", "149 \u00b1 12"),
    row(164, "MAP (mmHg)", "Ia", "123 \u00b1 7", "122 \u00b1 8"),
    row(176, "", "Ib", "121 \u00b1 7", "112 \u00b1 6"),
    row(194, "RAP (mmHg)", "Ia", "5 \u00b1 1", "5 \u00b1 2"),
    row(206, "", "Ib", "5 \u00b1 1", "5 \u00b1 2"),
    row(224, "CO (L/min)", "Ia", "2.0 \u00b1 0.6", "2.1 \u00b1 0.5"),
    row(236, "", "Ib", "2.0 \u00b1 0.5", "2.4 \u00b1 0.6"),
    list(list(x = 60, y = 266, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("Ia/Ib group rows read as two arms from the Baseline column, sized by name, not by another experiment's 'n=8 each'", {
  r <- parseBaselineTableHeuristics(romanLetterPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$arm, c("Group Ia", "Group Ib"))
  expect_identical(r$arms$N, c(6L, 8L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(length(unique(cont$ROW)), 4L)
  expect_identical(cont$MEAN[grepl("^HR", cont$ROW)], c(141, 141))
  expect_identical(cont$MEAN[grepl("^MAP", cont$ROW)], c(123, 121))
  expect_false(any(grepl("30 min|Olprinone|Ib$", cont$ROW)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
