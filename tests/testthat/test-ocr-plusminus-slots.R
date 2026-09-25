# test-ocr-plusminus-slots.R - a scanned page's plus-minus soup, repaired
# by the column where the block's other rows set the sign (ISSUES.md issue
# 65, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 12 finding Q1 (Fujii 1994, CJA 41:291, PMID       #
# 7954995): the OCR text layer sets the sign as a bullet, a plus, ":i:",   #
# "-t-", "-I-" and "4-" from one cell to the next, and glues one to its SD #
# ("-t-32"). Four rows of five lost every cell, so the half of the table   #
# inside one page column out-scored the whole read full width.            #
############################################################################

# One row of mean +/- SD cells set as a scanner reads them: the mean
# right-aligned to the sign's column, the sign as whatever glyph the OCR
# gave it, the SD after. A missing SD (NA) means the glyph carries it.
pmRow <- function(y, label, means, glyphs, sds, vx) {
  out <- list(list(x = 60, y = y, text = label, adj = 0))
  for (i in seq_along(means)) {
    out <- c(out, list(list(x = vx[i], y = y, text = means[i], adj = 1),
                       list(x = vx[i] + 3, y = y, text = glyphs[i], adj = 0)))
    if (!is.na(sds[i])) out <- c(out, list(list(x = vx[i] + 16, y = y, text = sds[i], adj = 0)))
  }
  out
}

soupPdf <- function(file = file.path(tempdir(), "soup.pdf"), footnote = "All values are expressed as mean -t- SD.",
                    ageGlyphs = c("•", "•", "+", "+"), weightGlyphs = c("-I-", "+", "•", "+"),
                    anGlyphs = c("+", "•", "+", "-I-")) {
  vx <- c(240, 330, 420, 510)
  cells <- c(
    list(list(x = 60, y = 70, text = "TABLE I Patient characteristics and surgical procedures", adj = 0)),
    rowCells(100, "", c("Placebo", "Low", "Mid", "High"), vx + 8),
    rowCells(118, "Group", c("(n = 25)", "(n = 25)", "(n = 25)", "(n = 25)"), vx + 8),
    pmRow(136, "Age (yr)", c("46.7", "46.3", "44.1", "45.4"), ageGlyphs, c("7.7", "11.8", "9.0", "7.9"), vx),
    pmRow(154, "Height (cm)", c("152.9", "154.4", "153.8", "152.8"), c("•", ":i:", "+", "-t-"), c("5.4", "4.9", "4.8", "5.1"), vx),
    pmRow(172, "Weight (kg)", c("54.2", "56.3", "55.3", "53.9"), weightGlyphs, c("7.1", "10.1", "7.3", "5.5"), vx),
    pmRow(190, "Duration of operation (min)", c("80", "80", "82", "81"), c("+", "+", "4-", "-t-32"), c("34", "24", "31", NA), vx),
    pmRow(208, "Duration of anaesthesia (min)", c("104", "105", "106", "105"), anGlyphs, c("32", "25", "30", "31"), vx),
    list(list(x = 60, y = 240, text = footnote, adj = 0)))
  makeTablePdf(file, cells)
}

test_that("soup glyphs at the block's plus-minus columns read as the sign, a glued SD is cut off", {
  r <- parseBaselineTableHeuristics(soupPdf(), quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW),
                  c("Age", "Height", "Weight", "Duration of operation", "Duration of anaesthesia"))
  expect_identical(nrow(r$arms), 4L)
  expect_identical(r$arms$N, rep(25L, 4))
  expect_identical(cont$SD[cont$ROW == "Height"], c(5.4, 4.9, 4.8, 5.1))
  expect_identical(cont$MEAN[cont$ROW == "Duration of operation"], c(80, 80, 82, 81))
  expect_identical(cont$SD[cont$ROW == "Duration of operation"], c(34, 24, 31, 32))
  expect_identical(cont$SD[cont$ROW == "Duration of anaesthesia"], c(32, 25, 30, 31))
  expect_identical(nrow(r$skipped), 0L)
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("with no genuine sign in the block and no announcement, the soup is left alone", {
  # "-I-" left this set on 2026-09-26: between two numbers it is the sign
  # without any column's evidence (ISSUES.md issue 123), and restored first
  # it becomes the genuine glyph the slot rule leans on for the rest
  soup <- c(":i:", "-t-", ":t:", "4-")
  f <- soupPdf(file.path(tempdir(), "soup-none.pdf"), footnote = "There were no differences between the groups.",
               ageGlyphs = soup, weightGlyphs = soup, anGlyphs = soup)
  r <- tryCatch(parseBaselineTableHeuristics(f, quiet = TRUE), error = function(e) NULL)
  got <- if (is.null(r)) character(0) else unique(r$data$ROW[!is.na(r$data$MEAN)])
  expect_false("Age" %in% got)
  expect_false("Weight" %in% got)
  expect_false("Duration of operation" %in% got)
})

test_that("the announcement 'mean -t- SD' alone licenses the repair", {
  soup <- c(":i:", "-t-", "-I-", "4-")
  f <- soupPdf(file.path(tempdir(), "soup-said.pdf"), ageGlyphs = soup, weightGlyphs = soup, anGlyphs = soup)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW),
                  c("Age", "Height", "Weight", "Duration of operation", "Duration of anaesthesia"))
  expect_identical(cont$SD[cont$ROW == "Age"], c(7.7, 11.8, 9.0, 7.9))
})

test_that("the helper: a slot needs two lines, a negative number is never a glued sign", {
  mk <- function(text, x) data.frame(text = text, x = x, width = rep(8, length(text)),
                                     y = 0, stringsAsFactors = FALSE)
  lines <- list(
    mk(c("Table", "1"), c(60, 90)),
    mk(c("Age", "46.7", "±", "7.7", "46.3", "±", "11.8"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "152.9", ":i:", "5.4", "154.4", "-t-", "4.9"), c(60, 180, 200, 210, 240, 260, 270)),
    # a "+" between two numbers marks the second slot with the Age line
    mk(c("Weight", "54.2", "±", "7.1", "56.3", "+", "10.1"), c(60, 180, 200, 210, 240, 260, 270)),
    # a negative number at a slot stays a number; a glued soup is cut
    mk(c("Change", "-3.2", "-32", "1.0", "80", "-t-32"), c(60, 180, 200, 210, 240, 260)),
    # a soup glyph at an x no line marks is not a sign
    mk(c("Sex", "12", ":i:", "13"), c(60, 100, 120, 130)))
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx = 1L)
  expect_identical(rep$repaired, 3L)
  expect_identical(lines[[2]]$text, rep$lines[[2]]$text)
  expect_identical(rep$lines[[3]]$text, c("Height", "152.9", "±", "5.4", "154.4", "±", "4.9"))
  # the plain "+" is evidence for the slot but is never repaired here (issue 45 decides it)
  expect_identical(rep$lines[[4]]$text, lines[[4]]$text)
  expect_identical(rep$lines[[5]]$text, c("Change", "-3.2", "-32", "1.0", "80", "±", "32"))
  expect_identical(rep$lines[[6]]$text, lines[[6]]$text)
  # one genuine sign only and no announcement: nothing is touched
  one <- lines[c(1, 2, 3)]
  one[[2]]$text[6] <- "+"
  one[[2]]$text[5] <- "n"
  expect_identical(.ppRepairPlusMinusGlyphs(one, 1L)$repaired, 0L)
})

test_that("the evidence is this table's alone, and a lone hyphen is a range unless announced", {
  mk <- function(text, x) data.frame(text = text, x = x, width = rep(8, length(text)),
                                     y = 0, stringsAsFactors = FALSE)
  soupRows <- list(
    mk(c("Age", "46.7", ":i:", "7.7", "46.3", "-t-", "11.8"), c(60, 180, 200, 210, 240, 260, 270)),
    mk(c("Height", "152.9", "-I-", "5.4", "154.4", "4-", "4.9"), c(60, 180, 200, 210, 240, 260, 270)))
  # a LATER table's announcement licenses nothing here (CodeRabbit on PR #370)
  later <- c(list(mk(c("Table", "1", "Patient", "data"), c(60, 90, 100, 140))), soupRows,
             list(mk(c("Table", "2", "Outcomes"), c(60, 90, 100)),
                  mk(c("Values", "are", "mean", "-t-", "SD."), c(60, 90, 110, 130, 150))))
  expect_identical(.ppRepairPlusMinusGlyphs(later, capIdx = 1L)$repaired, 0L)
  # a later table's sign columns are not evidence either
  laterSigns <- c(list(mk(c("Table", "1", "Patient", "data"), c(60, 90, 100, 140))), soupRows,
                  list(mk(c("Table", "2", "Outcomes"), c(60, 90, 100)),
                       mk(c("Pain", "3.1", "±", "1.0", "2.9", "±", "1.1"), c(60, 180, 200, 210, 240, 260, 270)),
                       mk(c("Nausea", "1.1", "±", "0.4", "1.3", "±", "0.5"), c(60, 180, 200, 210, 240, 260, 270))))
  expect_identical(.ppRepairPlusMinusGlyphs(laterSigns, capIdx = 1L)$repaired, 0L)
  # this table's own caption line announces the notation
  own <- c(list(mk(c("Table", "1", "Patient", "data", "(mean", "-t-", "SD)"), c(60, 90, 100, 140, 160, 190, 210))), soupRows)
  expect_identical(.ppRepairPlusMinusGlyphs(own, capIdx = 1L)$repaired, 4L)
  # a lone hyphen between two numbers is a range, not a sign - even under an announcement
  ranges <- c(own, list(mk(c("Range", "20", "-", "30", "40", "-", "50"), c(60, 180, 200, 210, 240, 260, 270))))
  rep <- .ppRepairPlusMinusGlyphs(ranges, capIdx = 1L)
  expect_identical(rep$repaired, 4L)
  expect_identical(rep$lines[[4]]$text, c("Range", "20", "-", "30", "40", "-", "50"))
  # unless the hyphen IS the announced glyph
  dash <- c(list(mk(c("Table", "1", "Patient", "data", "(mean", "-", "SD)"), c(60, 90, 100, 140, 160, 190, 210))),
            list(mk(c("Age", "46", "-", "7", "45", "-", "8"), c(60, 180, 200, 210, 240, 260, 270))))
  expect_identical(.ppRepairPlusMinusGlyphs(dash, capIdx = 1L)$repaired, 2L)
})
