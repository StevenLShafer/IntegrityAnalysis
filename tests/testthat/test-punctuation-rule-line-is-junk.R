# test-punctuation-rule-line-is-junk.R - a line of punctuation fragments
# (a printed rule the scan's text layer rendered as glyph soup) between the
# header and the rows is skipped, not read as prose that ends the block
# (ISSUES.md issue 153, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 3 AL11 (Clin Ther 2010, PMID 20974320;    #
# three arms of 30): the rule line "_ ¥ . _ ._ _..... ~-_._""--- .." of    #
# fifty-four fragments ended the block before its first row.               #
############################################################################

ruleLinePdf <- function(file = file.path(tempdir(), "ruleLine.pdf")) {
  vx <- c(254, 352, 446)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells) c(list(w(58, y, label)), lapply(1:3, function(k) w(vx[k], y, cells[k])))
  frags <- c("_", ".", "_", "._", "_.....", "~-_.", "..", "_--_", "........", "_._---", "-----_", "......", "..", "_._---.-", ".....", "-", "..", "~--_", "...", ".....")
  cells <- c(
    list(w(58, 60, "Table I. Patient demographic characteristics.")),
    list(w(vx[1], 100, "Midazolam 50"), w(vx[2], 100, "Midazolam 75"), w(vx[3], 100, "Placebo")),
    c(list(w(58, 125, "Characteristic")), lapply(1:3, function(k) w(vx[k] + 14, 125, "(n = 30)"))),
    lapply(seq_along(frags), function(k) w(58 + 12 * (k - 1), 138, frags[k])),
    row(147, "Age, y", c("36 (7)", "36 (6)", "35 (6)")),
    row(164, "Height, cm", c("157 (5)", "158 (5)", "159 (6)")),
    row(181, "Weight, kg", c("53 (9)", "52 (8)", "53 (6)")),
    list(w(58, 215, "Values are mean (SD).")))
  makeTablePdf(file, cells)
}

test_that("a line of punctuation fragments between the header and the rows is skipped, and the rows are read", {
  r <- parseBaselineTableHeuristics(ruleLinePdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(30L, 3))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(36, 36, 35))
  expect_identical(cont$SD[grepl("^Weight", cont$ROW)], c(9, 8, 6))
  expect_identical(length(unique(cont$ROW)), 3L)
})
