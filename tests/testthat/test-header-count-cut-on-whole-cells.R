# test-header-count-cut-on-whole-cells.R - when the header names k arms and
# the k-way cut of the full rows is refused, the rows whose every token is a
# whole cell cut the columns by themselves (ISSUES.md issue 120, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 27 AF3 (CJA 1995, PMID 7614644, a scan; four arms  #
# of 22 in columns 48 to 60 points apart). The Age line carries a bare mean #
# (its SD lost to the text layer, issue 118) and the count rows beneath    #
# "Types of operation performed" set their integers under the SDs, so the  #
# columns' spreads over all full rows grew past the narrowest cut gap and  #
# the cut was refused; the table read three arms of four. The geometry     #
# below reproduces that: whole cells span x to x + 38 (mid x + 19), the    #
# counts sit at x + 33 to x + 44 (mid x + 39) and the bare mean at x to    #
# x + 18 (mid x + 9), in columns at 195, 243, 296 and 356.                  #
############################################################################

wholeCellCutPdf <- function(file = file.path(tempdir(), "wholeCellCut.pdf")) {
  vx <- c(195, 243, 296, 356)
  cell <- function(y, k, mean, sd) list(
    list(x = vx[k], y = y, text = mean, adj = 0),
    list(x = vx[k] + 18, y = y, text = "\u00b1", adj = 0),
    list(x = vx[k] + 26, y = y, text = sd, adj = 0))
  row <- function(y, label, means, sds) c(
    list(list(x = 62, y = y, text = label, adj = 0)),
    unlist(lapply(1:4, function(k) cell(y, k, means[k], sds[k])), recursive = FALSE))
  counts <- function(y, label, n) c(
    list(list(x = 70, y = y, text = label, adj = 0)),
    lapply(1:4, function(k) list(x = vx[k] + 44, y = y, text = n[k], adj = 1)))
  cells <- c(
    list(list(x = 61, y = 60, text = "TABLE I Patient demographics and types of operation", adj = 0)),
    rowCells(80, "", c("Placebo", "Granisetron", "Dexamethasone", "Both"), vx + 19, labelX = 62),
    rowCells(94, "", c("(n = 22)", "(n = 22)", "(n = 22)", "(n = 22)"), vx + 19, labelX = 62),
    # the second arm's SD is lost: a bare mean and a sign with nothing after it
    row(112, "Age (yr)", c("40.1", "45.3", "43", "42.5"), c("7.5", "", "8", "9.4")),
    row(130, "Height (cm)", c("154.0", "154.9", "156.3", "154.4"), c("3.8", "4.8", "6.2", "4.9")),
    row(148, "Weight (kg)", c("54.0", "53.2", "54.9", "54.1"), c("7.3", "8.0", "9.0", "7.6")),
    row(166, "Duration of operation (min)", c("74", "81", "78", "83"), c("28", "24", "32", "25")),
    row(184, "Duration of anaesthesia (min)", c("96", "109", "103", "106"), c("30", "26", "33", "25")),
    row(202, "Morphine (mg)", c("4.9", "4.9", "5.0", "5.0"), c("0.8", "0.9", "0.9", "0.9")),
    list(list(x = 61, y = 224, text = "Types of operation performed", adj = 0)),
    counts(236, "Abdominal hysterectomy", c("16", "17", "16", "18")),
    counts(248, "Vaginal hysterectomy", c("0", "1", "0", "0")),
    counts(260, "Salpingo-oophorectomy", c("4", "3", "5", "2")),
    counts(272, "Others", c("2", "1", "1", "2")),
    list(list(x = 62, y = 300, text = "All values are expressed as mean \u00b1 SD.", adj = 0)))
  cells <- Filter(function(z) nzchar(z$text), cells)
  makeTablePdf(file, cells)
}

test_that("the rows of whole cells cut four arms when the full rows with bare numbers refuse the cut", {
  r <- parseBaselineTableHeuristics(wholeCellCutPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(22L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Height"], c(154.0, 154.9, 156.3, 154.4))
  expect_identical(cont$SD[cont$ROW == "Height"], c(3.8, 4.8, 6.2, 4.9))
  expect_identical(cont$MEAN[cont$ROW == "Weight"], c(54.0, 53.2, 54.9, 54.1))
  expect_identical(cont$MEAN[grepl("^Duration of operation", cont$ROW)], c(74, 81, 78, 83))
  expect_identical(cont$MEAN[grepl("^Duration of anaesthesia", cont$ROW)], c(96, 109, 103, 106))
  expect_identical(cont$MEAN[cont$ROW == "Morphine"], c(4.9, 4.9, 5.0, 5.0))
  # the bare mean is not a cell and no cell is built from a neighbour's mean
  age <- cont[cont$ROW == "Age", ]
  expect_true(all(age$SD < 20))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
