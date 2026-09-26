# test-per-cell-n-in-parentheses.R - a row of cells with "(n = k*)" after
# each cell is a data row with a per-cell n, not a header or a stratum
# (ISSUES.md issue 131, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG2 (Am J Obstet Gynecol 2000, PMID 10649150;  #
# three arms of 40): "Last menstrual cycle (d, mean +/- SD) 16 +/- 3 (n = #
# 38*) 16 +/- 3 (n = 37*) 16 +/- 3 (n = 38*)" read as a stratum over the  #
# rows beneath, which went out with N 38/37/38 and the prefix "Last       #
# menstrual cycle (d, mean +/- SD) 16 +/- 3:"; the three menstrual cells   #
# were lost.                                                               #
############################################################################

pm <- "\u00b1"

perCellNPdf <- function(file = file.path(tempdir(), "perCellN.pdf")) {
  vx <- c(261, 354, 460)
  cell <- function(y, k, mean, sd, n = NULL) c(
    list(list(x = vx[k], y = y, text = mean, adj = 0), list(x = vx[k] + 10, y = y, text = pm, adj = 0),
         list(x = vx[k] + 17, y = y, text = sd, adj = 0)),
    if (!is.null(n)) list(list(x = vx[k] + 26, y = y, text = paste0("(n = ", n, "*)"), adj = 0)))
  row <- function(y, label, means, sds, ns = NULL) c(
    list(list(x = 63, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], sds[k], ns[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 63, y = 60, text = "Table I. Patient characteristics", adj = 0)),
    rowCells(80, "", c("Granisetron", "Droperidol", "Metoclopramide"), vx + 10, labelX = 63),
    rowCells(94, "", c("(n = 40)", "(n = 40)", "(n = 40)"), vx + 10, labelX = 63),
    row(114, "Age (y, mean and SD)", c("45", "44", "43"), c("8", "7", "10")),
    row(132, "Height (cm, mean and SD)", c("154", "153", "155"), c("5", "4", "6")),
    row(150, "Last menstrual cycle (d)", c("16", "16", "16"), c("3", "3", "3"), c("38", "37", "38")),
    row(168, "Duration of operation (min)", c("76", "78", "76"), c("26", "26", "31")),
    row(186, "Duration of anesthesia (min)", c("99", "98", "101"), c("25", "25", "31")),
    list(list(x = 63, y = 220, text = "*Patients with a regular cycle.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a row of cells with (n = k*) after each cell is a row with its own n, and the rows beneath keep the arm N", {
  r <- parseBaselineTableHeuristics(perCellNPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(40L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  men <- cont[grepl("^Last menstrual", cont$ROW), ]
  expect_identical(men$MEAN, c(16, 16, 16))
  expect_identical(men$N, c(38L, 37L, 38L))
  dur <- cont[grepl("^Duration of operation", cont$ROW), ]
  expect_identical(dur$N, rep(40L, 3))
  expect_identical(dur$MEAN, c(76, 78, 76))
  expect_false(any(grepl("16 .* 3:", cont$ROW)))
  expect_identical(length(unique(cont$ROW)), 5L)
})

# A FLOW DIAGRAM BESIDE THE TABLE (issue 131, second cut; Rezk 2018, Gynecol
# Endocrinol, the Loadsman corpus): the CONSORT diagram's boxes - "Assessed
# for eligibility (n=225)", "Excluded (n=16)", "Randomized (n=209)" - sit in
# the left column at the table's rows' heights. Read full width, a box's
# "(n=k)" before the row's cells must not seed an arm: the table has two
# arms of 102 and 100, and no arm of 225.
flowBesideTablePdf <- function(file = file.path(tempdir(), "flowBesideTable.pdf")) {
  vx <- c(400, 465)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  cell <- function(y, k, mean, sd) list(w(vx[k], y, mean), w(vx[k] + 24, y, pm), w(vx[k] + 32, y, sd))
  row <- function(y, label, means, sds, p) c(list(w(310, y, label)),
    unlist(lapply(1:2, function(k) cell(y, k, means[k], sds[k])), recursive = FALSE), list(w(545, y, p)))
  cells <- c(
    list(w(310, 51, "Table 1. Patients characteristics.")),
    list(w(395, 74, "Metformin group"), w(470, 74, "group"), w(540, 74, "Student's")),
    list(w(405, 83, "(n = 102)"), w(470, 83, "(n = 100)"), w(545, 83, "t-test")),
    list(w(90, 86, "Assessed for eligibility (n=225)")),
    row(95, "Age (years)", c("24.6", "24.2"), c("2.1", "2.8"), "1.15"),
    list(w(180, 99, "Excluded (n=16)")),
    row(104, "Body mass index (kg/m2)", c("24.2", "23.7"), c("4.3", "4.8"), "0.78"),
    list(w(50, 110, "Enrollment"), w(180, 110, "-Not meeting inclusion")),
    list(w(310, 113, "20-25"), w(425, 113, "44"), w(473, 113, "46"), w(517, 113, "0.07")),
    list(w(180, 117, "criteria (n=14).")),
    list(w(310, 120, ">25"), w(425, 122, "58"), w(473, 122, "54")),
    list(w(180, 124, "-Declined to participate")),
    list(w(180, 131, "(n=2).")),
    row(131, "Infertility (months)", c("28.2", "27.8"), c("6.9", "7.1"), "0.41"),
    list(w(310, 140, "Basal hormones")),
    row(149, "FSH (IU/L)", c("5.3", "5.5"), c("1.4", "1.2"), "1.09"),
    list(w(120, 152, "Randomized (n=209)")),
    row(158, "LH (IU/L)", c("12.7", "12.8"), c("4.2", "4.3"), "0.17"),
    list(w(310, 170, "FSH: Follicle stimulating hormone; LH: Leutinizing hormone.")),
    # the page's two columns of prose beneath the diagram and the table,
    # which give the page its gutter (the real page is two-column)
    unlist(lapply(0:9, function(k) list(
      w(44, 200 + 11 * k, "The patients received letrozole twice daily"),
      w(310, 200 + 11 * k, "The letrozole arm had a higher rate of ovulation"))), recursive = FALSE))
  makeTablePdf(file, cells)
}

test_that("a flow diagram's (n=k) boxes beside the table seed no arm", {
  r <- parseBaselineTableHeuristics(flowBesideTablePdf(), quiet = TRUE)
  expect_identical(sort(r$arms$N), c(100L, 102L))
  expect_false(any(grepl("eligibility", r$arms$arm)))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(24.6, 24.2))
  expect_identical(cont$MEAN[grepl("^FSH", cont$ROW)], c(5.3, 5.5))
  expect_false(any(grepl("Excluded|Randomized|criteria|\\(n=", cont$ROW)))
})
