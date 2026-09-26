# test-size-group-without-its-sign.R - a bracketed size group whose sign the
# text layer dropped ("(n 25)") or set as a hyphen ("(n - 20)", "(n -- 60)",
# "(n -20)") is read as "(n = k)" (ISSUES.md issue 148, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 2: Clin Ther 2008, PMID 19108790 (four    #
# arms of 25, the equals signs on a line of their own), A&A 1999, PMID    #
# 10439770 ("(n 60)"), Clin Ther 2005, PMID 16117980 ("(n - 20)"), Clin  #
# Ther 2003, PMID 12749510 ("(n -- 60)"). Every cell read; no arm had an N.#
############################################################################

test_that("the size-sign repair writes the equals sign into a bracketed group and leaves prose alone", {
  line <- function(...) { w <- c(...); data.frame(text = w, x = seq(60, by = 40, length.out = length(w)), width = 12, stringsAsFactors = FALSE) }
  lines <- list(line("Table"),
                line("Variable", "(n", "25)", "(n", "25)", "(N", "25)"),
                line("Characteristic", "(n", "-", "20)", "(n", "--", "20)"),
                line("Characteristic", "(n", "-20)", "(n", "=", "20)", "(n", "60)."),
                line("with", "n", "25", "patients", "(n", "of", "them"),
                line("=", "=", "=", "="),
                line("Variable", "(n", "--", "3o)", "(,", "--", "30)"),
                line("=", "=", "=", "="),
                line("Variable", "(n--3o)", "(,--30)", "(n-30)", "(n", "5", "60)"))
  r <- .ppRepairSizeSign(lines, capIdx = 1L)
  expect_identical(r$lines[[2]]$text, c("Variable", "(n =", "25)", "(n =", "25)", "(N =", "25)"))
  expect_identical(r$lines[[3]]$text, c("Characteristic", "(n", "=", "20)", "(n", "=", "20)"))
  expect_identical(r$lines[[4]]$text, c("Characteristic", "(n", "= 20)", "(n", "=", "20)", "(n =", "60)."))
  expect_identical(r$lines[[5]]$text, c("with", "n", "25", "patients", "(n", "of", "them"))
  # a line of bare equals signs stays unless it follows a repaired line
  expect_identical(r$lines[[6]]$text, rep("=", 4))
  expect_identical(r$lines[[7]]$text, c("Variable", "(n", "=", "3o)", "(n", "=", "30)"))
  expect_identical(nrow(r$lines[[8]]), 0L)
  expect_identical(r$lines[[9]]$text, c("Variable", "(n = 3o)", "(n = 30)", "(n = 30)", "(n", "=", "60)"))
  expect_identical(r$repaired, 5L)
})

# Fujii & Itakura 2008 (PMID 19108790), rebuilt: the four "(n 25)" groups
# with their equals signs on a line of their own three points below, and
# Mean (SD) / Range sub-rows under each variable.
signOnItsOwnLinePdf <- function(file = file.path(tempdir(), "signOnItsOwnLine.pdf")) {
  vx <- c(215, 291, 385, 473)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  sub2 <- function(y, label, cells) c(list(w(70, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(57, 60, "Table I. Patient demographics and surgery type in the study population.")),
    list(w(214, 123, "Propofol"), w(285, 123, "Droperidol"), w(367, 123, "Metoclopramide"), w(473, 123, "Placebo")),
    c(list(w(57, 135, "Variable")), lapply(1:4, function(k) w(vx[k], 135, "(n")), lapply(1:4, function(k) w(vx[k] + 19, 135, "25)"))),
    lapply(1:4, function(k) w(vx[k] + 10, 139, "=")),
    list(w(57, 157, "Age, y")),
    sub2(168, "Mean (SD)", c("53 (6)", "53 (6)", "54 (6)", "52 (9)")),
    sub2(179, "Range", c("46-65", "43-65", "43-66", "42-64")),
    list(w(57, 190, "Height, cm")),
    sub2(201, "Mean (SD)", c("154 (7)", "154 (7)", "153 (6)", "156 (5)")),
    sub2(212, "Range", c("143-173", "140-173", "145-172", "145-166")),
    list(w(57, 223, "Weight, kg")),
    sub2(234, "Mean (SD)", c("53 (8)", "54 (7)", "52 (7)", "54 (6)")),
    sub2(245, "Range", c("44-68", "42-70", "42-67", "44-72")),
    list(w(57, 270, "Values are mean (SD) unless otherwise noted.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page whose size groups lost their equals signs reads four arms of 25", {
  r <- parseBaselineTableHeuristics(signOnItsOwnLinePdf(), quiet = TRUE, parenIsSD = "sd")
  expect_identical(r$arms$N, rep(25L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(53, 53, 54, 52))
  expect_identical(cont$SD[grepl("^Weight", cont$ROW)], c(8, 7, 7, 6))
})

# Fujii 2005 (PMID 16117980), rebuilt: "(n - 20)" under dose heads beneath a
# drug's name, and a caption total "(N - 80)" that is nobody's arm size.
hyphenForEqualsPdf <- function(file = file.path(tempdir(), "hyphenForEquals.pdf")) {
  vx <- c(258, 342, 424, 506)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(70, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(69, 81, "Table I. Demographic, clinical, and surgical data of the study population (N - 80).*")),
    list(w(325, 103, "Dexamethasone")),
    list(w(vx[1], 121, "4 mg"), w(vx[2], 121, "8 mg"), w(vx[3], 121, "16 mg"), w(vx[4], 121, "Vehicle")),
    c(list(w(70, 139, "Characteristic")), unlist(lapply(1:4, function(k) list(w(vx[k], 139, "(n"), w(vx[k] + 15, 139, "-"), w(vx[k] + 24, 139, "20)"))), recursive = FALSE)),
    row(160, "Age, y", c("60 (9)", "57 (10)", "61 (9)", "57 (11)")),
    row(178, "Height, cm", c("153 (7)", "152 (6)", "151 (7)", "154 (6)")),
    row(196, "Weight, kg", c("54 (8)", "55 (9)", "54 (8)", "53 (7)")),
    list(w(69, 230, "*Values are mean (SD) unless otherwise noted.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with hyphens for the equals signs reads four arms of 20, and the caption's 80 is nobody's", {
  r <- parseBaselineTableHeuristics(hyphenForEqualsPdf(), quiet = TRUE, parenIsSD = "sd")
  expect_identical(r$arms$N, rep(20L, 4))
  expect_false(any(!is.na(r$arms$N) & r$arms$N == 80L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(60, 57, 61, 57))
})
