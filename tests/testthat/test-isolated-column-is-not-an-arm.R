# test-isolated-column-is-not-an-arm.R - a column whose feeding lines
# carry no token of any other column is not an arm column: prose numbers
# beneath a table, at an x no cell uses, do not seed an arm (ISSUES.md
# issue 128, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 26 item on Anaesthesia 1999, PMID 10193218: the   #
# table in the page's right-hand column, the prose of the left running on #
# beneath it ("between 62% and 80% [2, 3]"), a fourth arm named from the  #
# legend line ("mean (SD) or median"), empty on every row.                 #
############################################################################

proseBelowPdf <- function(file = file.path(tempdir(), "proseBelow.pdf")) {
  vx <- c(342, 405, 465)
  cells <- c(
    # the paper's own size statement, which the arm-N recovery applies to every column
    list(list(x = 47, y = 30, text = "Patients were allocated to granisetron, droperidol or metoclopramide (n = 60 for each).", adj = 0)),
    list(list(x = 47, y = 60, text = "Table 1 Patient demographics. Results are", adj = 0)),
    # the legend's second line shares the arm names' line, as on the page, and
    # its "mean (SD) or median" stands over the x the prose numbers will use
    list(list(x = 47, y = 71, text = "expressed as number,", adj = 0),
         list(x = 140, y = 71, text = "mean (SD) or median", adj = 0)),
    rowCells(71, "", c("Granisetron", "Droperidol", "Metoclopramide"), vx, labelX = 215),
    # the sizes as the page's layer gives them, the equals sign lost to a
    # glyph on the next line ("(n 60)"): unreadable, so every column takes
    # the statement's 60 - the phantom column with the rest
    rowCells(84, "", c("(n 60)", "(n 60)", "(n 60)"), vx, labelX = 215),
    rowCells(102, "Height; cm", c("157 (7)", "157 (6)", "157 (6)"), vx, labelX = 215),
    rowCells(114, "Weight; kg", c("55 (7)", "55 (7)", "55 (8)"), vx, labelX = 215),
    rowCells(126, "Duration of surgery; min", c("219 (40)", "215 (41)", "221 (40)"), vx, labelX = 215),
    rowCells(138, "Duration of anaesthesia; min", c("248 (41)", "244 (43)", "249 (40)"), vx, labelX = 215),
    # the left column's prose runs on beneath the table, its citation numbers
    # and percentages at an x no cell uses (the block runs on into it, as on the page)
    list(list(x = 47, y = 170, text = "There were no differences among the treatment groups.", adj = 0)),
    list(list(x = 47, y = 184, text = "This incidence was in accordance with previous reports [1, 4]", adj = 0)),
    # a count with its percentage in the prose, at the phantom column's x: a
    # cell-shaped token, which is what lets the column take the statement's N
    list(list(x = 47, y = 196, text = "PONV after surgery in", adj = 0), list(x = 140, y = 196, text = "8", adj = 0),
         list(x = 150, y = 196, text = "(13%)", adj = 0), list(x = 185, y = 196, text = "of patients [5]", adj = 0)),
    # the sentence's numbers as the page sets them, three within 25 points of
    # each other, which cluster into one column no cell of the table uses
    list(list(x = 47, y = 208, text = "between", adj = 0), list(x = 85, y = 208, text = "62%", adj = 0),
         list(x = 108, y = 208, text = "and", adj = 0), list(x = 125, y = 208, text = "80%", adj = 0),
         list(x = 147, y = 208, text = "[2,", adj = 0), list(x = 162, y = 208, text = "3].", adj = 0),
         list(x = 200, y = 208, text = "Therefore, the use of a", adj = 0)),
    list(list(x = 47, y = 220, text = "prophylactic anti-emetic for the prevention of PONV in", adj = 0)),
    list(list(x = 47, y = 232, text = "patients undergoing middle ear surgery was justified.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("prose numbers beneath the table at their own x do not seed a fourth arm", {
  r <- parseBaselineTableHeuristics(proseBelowPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$arm, c("Granisetron", "Droperidol", "Metoclopramide"))
  expect_identical(r$arms$N, rep(60L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Height", cont$ROW)], c(157, 157, 157))
  expect_identical(cont$MEAN[grepl("^Duration of surgery", cont$ROW)], c(219, 215, 221))
  expect_false(any(grepl("mean \\(SD\\)", r$arms$arm)))
})
