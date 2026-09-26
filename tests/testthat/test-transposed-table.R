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
