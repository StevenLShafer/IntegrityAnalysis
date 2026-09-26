# test-digit-for-the-sign-at-a-slot.R - a digit set for the sign at a slot
# is the sign, not a number: alone between two numbers ("5.5 2 0.7"), or
# glued to a mean that has one more digit than every other mean on the line
# ("972 29" among "95 +/- 23" and "98 +/- 27") (ISSUES.md issue 130,
# 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 28 AG1 (Anesth Analg 1998, PMID 9495425, a scan;  #
# three arms of 50) and its false-cell audit: the engine read "972 +/- 29" #
# and "5.5 +/- 2", values that are not on the page (97 +/- 29, 5.5 +/-    #
# 0.7).                                                                    #
############################################################################

pm <- "\u00b1"

test_that("the slot repair reads a lone digit at the slot, and a digit glued to an over-long mean, as the sign", {
  line <- function(...) {
    w <- c(...); x <- c(48, 228, 245, 253, 342, 359, 368, 462, 478, 486)
    data.frame(text = w, x = x[seq_along(w)], width = c(30, 11, 5, 7, 11, 5, 7, 11, 5, 7)[seq_along(w)],
               stringsAsFactors = FALSE)
  }
  lines <- list(line("Table"),
                line("Age", "44", pm, "7", "45", pm, "10", "43", pm, "7"),
                line("Height", "154", pm, "5", "156", pm, "6", "154", pm, "4"),
                # "972" ends at the slot (233 + 11 = 244, slot 245): its last digit is the sign
                data.frame(text = c("Duration", "972", "29", "95", pm, "23", "98", pm, "27"),
                           x = c(48, 233, 253, 347, 359, 368, 466, 478, 486), width = c(35, 11, 7, 7, 5, 7, 7, 4, 7),
                           stringsAsFactors = FALSE),
                # "2" alone at the slot between 5.5 and 0.7 is the sign
                data.frame(text = c("Morphine", "5.5", pm, "0.8", "5.5", "2", "0.7", "5.4", pm, "0.7"),
                           x = c(57, 230, 245, 253, 345, 359, 368, 463, 478, 486), width = c(38, 9, 5, 9, 9, 5, 9, 9, 2, 9),
                           stringsAsFactors = FALSE),
                # the sign dropped entirely between numbers of the line's own length: rule (b) as before
                data.frame(text = c("Weight", "55", "8", "55", pm, "8", "54", pm, "7"),
                           x = c(48, 233, 253, 347, 359, 368, 466, 478, 486), width = c(30, 8, 5, 8, 5, 5, 8, 5, 5),
                           stringsAsFactors = FALSE))
  r <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(r$lines[[4]]$text, c("Duration", "97", pm, "29", "95", pm, "23", "98", pm, "27"))
  expect_identical(r$lines[[5]]$text, c("Morphine", "5.5", pm, "0.8", "5.5", pm, "0.7", "5.4", pm, "0.7"))
  expect_identical(r$lines[[6]]$text, c("Weight", "55", pm, "8", "55", pm, "8", "54", pm, "7"))
  # the split sign stands where the digit stood
  L <- r$lines[[4]]
  expect_equal(L$x[3], 233 + 11 * 2 / 3)
})

digitSignPdf <- function(file = file.path(tempdir(), "digitSign.pdf")) {
  vx <- c(233, 347, 466)
  # the mean right-aligned four points before the sign column, the SD eight
  # after it: the words stay separate in the text layer, and the glued "972"
  # ends where the other rows' signs begin
  cell <- function(y, k, mean, sign, sd) c(
    list(list(x = vx[k] + 20, y = y, text = mean, adj = 1)),
    if (nzchar(sign)) list(list(x = vx[k] + 24, y = y, text = sign, adj = 0)),
    list(list(x = vx[k] + 32, y = y, text = sd, adj = 0)))
  row <- function(y, label, means, signs, sds) c(
    list(list(x = 48, y = y, text = label, adj = 0)),
    unlist(lapply(1:3, function(k) cell(y, k, means[k], signs[k], sds[k])), recursive = FALSE))
  cells <- c(
    list(list(x = 36, y = 60, text = "Table 1. Patient Demographic Data", adj = 0)),
    rowCells(80, "", c("Group G", "Group D", "Group GD"), vx + 10, labelX = 48),
    rowCells(94, "", c("(n = 50)", "(n = 50)", "(n = 50)"), vx + 10, labelX = 48),
    row(112, "Age (yr)", c("44", "45", "43"), rep(pm, 3), c("7", "10", "7")),
    row(130, "Height (cm)", c("154", "156", "154"), rep(pm, 3), c("5", "6", "4")),
    row(148, "Duration of anesthesia (min)", c("972", "95", "98"), c("", pm, pm), c("29", "23", "27")),
    row(166, "Morphine (mg)", c("5.5", "5.5", "5.4"), c(pm, "2", pm), c("0.8", "0.7", "0.7")),
    list(list(x = 48, y = 200, text = "Values are expressed as mean +- SD or n.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page reads 97 +/- 29 and 5.5 +/- 0.7, not the digit-for-sign false cells", {
  r <- parseBaselineTableHeuristics(digitSignPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(50L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  dur <- cont[grepl("^Duration", cont$ROW), ]
  expect_identical(dur$MEAN, c(97, 95, 98))
  expect_identical(dur$SD, c(29, 23, 27))
  mor <- cont[cont$ROW == "Morphine", ]
  expect_identical(mor$MEAN, c(5.5, 5.5, 5.4))
  expect_identical(mor$SD, c(0.8, 0.7, 0.7))
})
