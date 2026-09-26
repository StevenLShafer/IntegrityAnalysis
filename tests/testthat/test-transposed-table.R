# test-transposed-table.R - a table with the groups down the side and the
# variables across the top is rewritten the way the walker reads, and reads
# its groups as arms and its columns as variables (ISSUES.md issue 139,
# 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 29 AH3 (Aydin 2014, J Anesth, Loadsman corpus;    #
# four arms of 80): "Groups (n = 80) | Age (years) | Gender (M/F) |         #
# Duration of surgery (h) | Total remifentanyl consumption (ug)" across    #
# the top, Control / Strefen / Siccoral / Stomatovis down the side, a P    #
# row beneath; the engine read three arms called Age, Duration and Total.  #
############################################################################

pm <- "\u00b1"

transposedPdf <- function(file = file.path(tempdir(), "transposed.pdf")) {
  cx <- c(372, 432, 472, 522)   # wider than the page, so the fixture font does not fuse a label with its cell
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  cells <- c(
    list(w(306, 61, "Table 2 Patient characteristics and total remifentanyl consumption of groups")),
    list(w(306, 87, "Groups"), w(cx[1], 87, "Age"), w(cx[1] + 17, 87, "(years)"), w(cx[2], 87, "Gender"),
         w(cx[3], 87, "Duration"), w(cx[4], 87, "Total")),
    list(w(306, 97, "(n = 80)"), w(cx[2], 97, "(M/F)"), w(cx[3], 97, "of surgery"), w(cx[4], 97, "remifentanyl")),
    list(w(cx[3], 107, "(h)"), w(cx[4], 107, "consumption")),
    list(w(cx[4], 117, "(ug)")),
    list(w(306, 135, "Control"), w(cx[1], 135, paste("61.3", pm, "12.3")), w(cx[2], 135, "72/8"), w(cx[3], 135, paste("1.6", pm, "0.6")), w(cx[4], 135, paste("801.4", pm, "267.8"))),
    list(w(306, 148, "Strefen"), w(cx[1], 148, paste("56.5", pm, "13.8")), w(cx[2], 148, "72/8"), w(cx[3], 148, paste("1.7", pm, "1.0")), w(cx[4], 148, paste("797.6", pm, "429.5"))),
    list(w(306, 161, "Siccoral"), w(cx[1], 161, paste("60.0", pm, "12.1")), w(cx[2], 161, "73/7"), w(cx[3], 161, paste("1.5", pm, "0.8")), w(cx[4], 161, paste("722.3", pm, "360.4"))),
    list(w(306, 174, "Stomatovis"), w(cx[1], 174, paste("60.2", pm, "13.0")), w(cx[2], 174, "72/8"), w(cx[3], 174, paste("1.5", pm, "0.6")), w(cx[4], 174, paste("758.3", pm, "269.4"))),
    list(w(306, 186, "P"), w(cx[1] + 4, 186, "0.114"), w(cx[2], 186, "0.991"), w(cx[3], 186, "0.258"), w(cx[4] + 9, 186, "0.183")),
    list(w(306, 210, paste("Values are mean", pm, "SD or number."))))
  makeTablePdf(file, cells)
}

test_that("the transposer rewrites a groups-down-the-side block into arms across the top", {
  w <- function(text, x, y) data.frame(text = text, x = x, y = y, width = 5.5 * nchar(text), height = 10, stringsAsFactors = FALSE)
  L <- function(...) { d <- do.call(rbind, list(...)); d[order(d$x), ] }
  lines <- list(
    L(w("Table", 306, 61), w("2", 329, 61)),
    L(w("Groups", 306, 87), w("Age", 356, 87), w("(years)", 373, 87), w("Weight", 409, 87), w("Duration", 446, 87)),
    L(w("(n", 306, 97), w("=", 316, 97), w("80)", 325, 97), w("(kg)", 409, 97), w("(h)", 446, 97)),
    L(w("Control", 306, 135), w("61.3", 356, 135), w(pm, 373, 135), w("12.3", 383, 135), w("70", 409, 135), w(pm, 422, 135), w("9", 430, 135), w("1.6", 446, 135), w(pm, 460, 135), w("0.6", 469, 135)),
    L(w("Strefen", 306, 148), w("56.5", 356, 148), w(pm, 373, 148), w("13.8", 383, 148), w("72", 409, 148), w(pm, 422, 148), w("8", 430, 148), w("1.7", 446, 148), w(pm, 460, 148), w("1.0", 469, 148)),
    L(w("P", 306, 186), w("0.114", 360, 186), w("0.5", 409, 186), w("0.258", 446, 186)))
  tb <- .ppTransposeBlock(lines, capIdx = 1L)
  expect_false(is.null(tb))
  expect_identical(tb$groups, 2L)
  expect_identical(tb$variables, 3L)
  expect_identical(tb$lineTexts[2], "Control Strefen")
  expect_identical(tb$lineTexts[3], "(n = 80) (n = 80)")
  expect_identical(tb$lineTexts[4], paste("Age (years) 61.3", pm, "12.3 56.5", pm, "13.8"))
  expect_identical(tb$lineTexts[5], paste("Weight (kg) 70", pm, "9 72", pm, "8"))
  # an ordinary block, variables down the side, is left alone
  plain <- list(L(w("Table", 60, 61), w("1", 90, 61)),
                L(w("Age", 60, 100), w("61.3", 200, 100), w(pm, 220, 100), w("12.3", 230, 100), w("56.5", 300, 100), w(pm, 320, 100), w("13.8", 330, 100)),
                L(w("Weight", 60, 114), w("70", 200, 114), w(pm, 220, 114), w("9", 230, 114), w("72", 300, 114), w(pm, 320, 114), w("8", 330, 114)))
  expect_null(.ppTransposeBlock(plain, capIdx = 1L))
  # a group-word line further down the block, after data rows, heads a
  # LATER table and does not transpose this one (PMID 17523738's Table I
  # with Table II beneath it; issue 139, second cut)
  two <- c(plain, list(
    L(w("Table", 60, 200), w("II.", 90, 200)),
    L(w("Group", 60, 220), w("Grading", 200, 220), w("of", 240, 220), w("pain", 255, 220), w("Pain", 330, 220), w("score", 355, 220)),
    L(w("Placebo", 60, 240), w("(n", 100, 240), w("=", 112, 240), w("30)", 120, 240), w("3", 200, 240), w("(10)", 210, 240), w("9", 250, 240), w("(30)", 260, 240), w("2", 340, 240)),
    L(w("Lidocaine", 60, 254), w("(n", 100, 254), w("=", 112, 254), w("30)", 120, 254), w("22", 200, 254), w("(73)", 215, 254), w("5", 250, 254), w("(17)", 260, 254), w("0", 340, 254))))
  expect_null(.ppTransposeBlock(two, capIdx = 1L))
})

# Fujii 2007's page (PMID 17523738), rebuilt: Table I with its four arms of
# 30 across the top and Table II beneath it with the groups down the side.
# Table I must still read as itself (issue 139, second cut).
twoTablesPdf <- function(file = file.path(tempdir(), "twoTables.pdf")) {
  vx <- c(230, 300, 370, 440)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  cell <- function(y, k, mean, sd) list(w(vx[k], y, mean), w(vx[k] + 16, y, pm), w(vx[k] + 26, y, sd))
  row <- function(y, label, means, sds) c(list(w(33, y, label)),
    unlist(lapply(1:4, function(k) cell(y, k, means[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(w(33, 60, "Table I. Summary of patient demographics. Data are mean (SD) or number as appropriate")),
    rowCells(80, "Variable", c("Placebo", "Lidocaine", "Flurbiprofen", "Both"), vx + 14, labelX = 33),
    rowCells(94, "", c("(n = 30)", "(n = 30)", "(n = 30)", "(n = 30)"), vx + 14, labelX = 33),
    row(112, "Age (y)", c("43", "43", "41", "42"), c("15", "14", "12", "14")),
    rowCells(130, "Sex (male/female)", c("14/16", "13/17", "14/16", "15/15"), vx + 14, labelX = 33),
    row(148, "Height (cm)", c("161", "160", "162", "163"), c("11", "8", "9", "7")),
    row(166, "Weight (kg)", c("60", "58", "58", "60"), c("11", "10", "11", "9")),
    list(w(33, 240, "Table II. Overall incidence and intensity of pain during injection of propofol")),
    list(w(33, 260, "Group"), w(200, 260, "Grading of pain [no. (%)]"), w(420, 260, "Pain score"), w(500, 260, "Pain total")),
    list(w(200, 274, "None"), w(260, 274, "Mild"), w(320, 274, "Moderate"), w(380, 274, "Severe")),
    list(w(33, 292, "Placebo (n = 30)"), w(200, 292, "3 (10)"), w(260, 292, "9 (30)"), w(320, 292, "10 (33)"), w(380, 292, "8 (27)"), w(430, 292, "2"), w(500, 292, "27 (90)")),
    list(w(33, 306, "Lidocaine (n = 30)"), w(200, 306, "22 (73)"), w(260, 306, "5 (17)"), w(320, 306, "3 (10)"), w(380, 306, "0 (0)"), w(430, 306, "0"), w(500, 306, "8 (27)")),
    list(w(33, 320, "Flurbiprofen (n = 30)"), w(200, 320, "17 (57)"), w(260, 320, "9 (30)"), w(320, 320, "4 (13)"), w(380, 320, "0 (0)"), w(430, 320, "0"), w(500, 320, "13 (43)")),
    list(w(33, 334, "Both (n = 30)"), w(200, 334, "29 (97)"), w(260, 334, "0 (0)"), w(320, 334, "1 (3)"), w(380, 334, "0 (0)"), w(430, 334, "0"), w(500, 334, "1 (3)")))
  makeTablePdf(file, cells)
}

test_that("a page with a plain table above a groups-down-the-side table still reads the plain one", {
  r <- parseBaselineTableHeuristics(twoTablesPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(30L, 4))
  expect_identical(r$arms$arm, c("Placebo", "Lidocaine", "Flurbiprofen", "Both"))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[cont$ROW == "Age"], c(43, 43, 41, 42))
  expect_identical(cont$SD[cont$ROW == "Weight"], c(11, 10, 11, 9))
  expect_false(any(grepl("^Column", cont$ROW)))
})

test_that("a rebuilt transposed page reads its groups as arms of 80 and its columns as variables", {
  r <- parseBaselineTableHeuristics(transposedPdf(), quiet = TRUE)
  expect_identical(r$arms$arm, c("Control", "Strefen", "Siccoral", "Stomatovis"))
  expect_identical(r$arms$N, rep(80L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(61.3, 56.5, 60.0, 60.2))
  expect_identical(cont$SD[grepl("^Duration", cont$ROW)], c(0.6, 1.0, 0.8, 0.6))
  expect_identical(cont$MEAN[grepl("^Total", cont$ROW)], c(801.4, 797.6, 722.3, 758.3))
  expect_false(any(grepl("^Control|^Strefen", cont$ROW)))
})
