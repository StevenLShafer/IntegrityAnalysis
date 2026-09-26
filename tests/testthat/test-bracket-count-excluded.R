# test-bracket-count-excluded.R - a bracketed count after a cell that the
# footnote calls the excluded patients is the arm's N less that count, not
# the cell's n (ISSUES.md issue 162, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 34 AN2 (Clin Ther 2004, PMID 15336470; five arms  #
# of 20): the menstrual row's "[9]" became that cell's N.                  #
############################################################################

excludedBracketPdf <- function(file = file.path(tempdir(), "excludedBracket.pdf")) {
  vx <- c(230, 300, 370, 440)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(52, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(52, 60, "Table I. Baseline characteristics of study patients (n = 20 patients per study group).*")),
    list(w(vx[1], 90, "Granisetron"), w(vx[2], 90, "Granisetron"), w(vx[3], 90, "Granisetron"), w(vx[4], 90, "Placebo")),
    list(w(vx[1], 102, "20"), w(vx[2], 102, "40"), w(vx[3], 102, "80")),
    row(126, "Age, mean (SD), y", c("46 (8)", "47 (7)", "45 (11)", "50 (11)")),
    row(144, "Weight, mean (SD), kg", c("57 (7)", "57 (9)", "54 (7)", "58 (8)")),
    row(162, "Last menstrual cycle, mean (SD), d", c("16 (3) [10]", "16 (3) [11]", "16 (3) [9]", "16 (3) [10]")),
    row(180, "Duration of surgery, mean (SD), min", c("86 (35)", "117 (33)", "83 (34)", "92 (27)")),
    list(w(52, 210, "*Values are mean (SD) unless otherwise indicated. Postmenopausal patients (brackets) were excluded.")))
  makeTablePdf(file, cells)
}

test_that("a bracket the footnote calls the excluded gives the cell the arm's N less the count", {
  r <- parseBaselineTableHeuristics(excludedBracketPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  men <- cont[grepl("^Last menstrual", cont$ROW), ]
  expect_identical(men$MEAN, c(16, 16, 16, 16))
  expect_identical(men$N, c(10L, 9L, 11L, 10L))
  expect_identical(cont$N[grepl("^Age", cont$ROW)], rep(20L, 4))
})

# THE SAME PAGE AS THE OCR READS IT (issue 163): "[t0]" and "[t t]" for
# [10] and [11] - every arm's bracket subtracted, not only the one that read
# as digits.
excludedBracketOcrPdf <- function(file = file.path(tempdir(), "excludedBracketOcr.pdf")) {
  vx <- c(230, 300, 370, 440)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(52, y, label)), lapply(1:4, function(k) w(vx[k], y, cells[k])))
  cells <- c(
    list(w(52, 60, "Table I. Baseline characteristics of study patients (n = 20 patients per study group).*")),
    list(w(vx[1], 90, "Granisetron"), w(vx[2], 90, "Granisetron"), w(vx[3], 90, "Granisetron"), w(vx[4], 90, "Placebo")),
    list(w(vx[1], 102, "20"), w(vx[2], 102, "40"), w(vx[3], 102, "80")),
    row(126, "Age, mean (SD), y", c("46 (8)", "47 (7)", "45 (11)", "50 (11)")),
    row(144, "Weight, mean (SD), kg", c("57 (7)", "57 (9)", "54 (7)", "58 (8)")),
    row(162, "Last menstrual cycle, mean (SD), d", c("16 (3) [t0]", "16 (3) [t t]", "16 (3) [9]", "16 (3) [t0]")),
    row(180, "Duration of surgery, mean (SD), min", c("86 (35)", "117 (33)", "83 (34)", "92 (27)")),
    list(w(52, 210, "*Values are mean (SD) unless otherwise indicated. Postmenopausal patients (brackets) were excluded.")))
  makeTablePdf(file, cells)
}

test_that("an exclusion bracket OCR'd with look-alike letters is subtracted like one read as digits", {
  r <- parseBaselineTableHeuristics(excludedBracketOcrPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 4))
  cont <- r$data[!is.na(r$data$MEAN), ]
  men <- cont[grepl("^Last menstrual", cont$ROW), ]
  expect_identical(men$MEAN, c(16, 16, 16, 16))
  expect_identical(men$N, c(10L, 9L, 11L, 10L))
})
