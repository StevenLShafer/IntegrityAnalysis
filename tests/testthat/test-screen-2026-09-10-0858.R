# Security screen 2026-09-10-0858, the merged range 24a8177..ae37f0e.
#
# The diff itself held up: no defect in the changed code. Two LOWs in
# code it touches or leans on.
#
# F1 (LOW, pre-existing, verified end to end): a "count (pct%)" cell
#   implying an arm size over 2^31 - "25000000 (0.01%)", about 1.7e11 -
#   made as.integer() NA in .ppNFromCountPct(), the comparison after it
#   raised, and on the JATS route the block parser's tryCatch swallowed
#   the error: the WHOLE document failed to parse, with a message naming
#   no cell. "30000 (0.001%)" did the same.
# F2 (LOW): the tripwire pin of screen 0815 named the variable rowTotal
#   rather than the quantity it sums; mutation-tested in the harness.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-10,
# per the AGENTS.md rule: the F1 test drives the screen's own cells
# through parseBaselineTableJats(), and was checked to FAIL on ae37f0e.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

test_that("an implied arm size the analysis could never accept does not sink the document", {
  skip_if_not(file.exists(test_path("helper-syntheticJats.R")))
  jats <- function(cell) {
    f <- tempfile(fileext = ".xml")
    makeJatsArticle(f, list(list(caption = "Baseline characteristics",
      rows = list(c("", "Control", "Treatment"),
                  c("Age", "60", "61"),
                  c("Male sex", cell, cell)))))
    f
  }
  # the honest cell derives the arm size, as it always did
  res <- suppressWarnings(parseBaselineTableJats(jats("25 (50%)"), trial = "T", quiet = TRUE))
  expect_equal(res$arms$N, c(50, 50))
  # the screen's two cells: on ae37f0e both raised inside the block parser
  # and the reader stopped with "No usable baseline table could be parsed"
  for (cell in c("30000 (0.001%)", "25000000 (0.01%)")) {
    res <- tryCatch(
      suppressWarnings(parseBaselineTableJats(jats(cell), trial = "T", quiet = TRUE)),
      error = function(e) e)
    expect_false(inherits(res, "error"), info = cell)
    # the table is read; that arm's N is simply unknown
    expect_false(is.null(res$data), info = cell)
    expect_true(all(is.na(res$arms$N)), info = cell)
  }
})

test_that(".ppNFromCountPct() refuses in doubles, before as.integer()", {
  # honest: 25 of 50%, integer percent
  expect_equal(.ppNFromCountPct(25, 50, 0L), 50L)
  # an implied size above the arm ceiling yields nothing - the same rule
  # validateData() applies, one function later
  expect_length(.ppNFromCountPct(30000, 0.001, 3L), 0L)
  expect_length(.ppNFromCountPct(25000000, 0.01, 2L), 0L)
  # ...and never a warning from as.integer() on the way
  expect_silent(.ppNFromCountPct(25000000, 0.01, 2L))
  # the ceiling itself is admitted
  expect_true(5000L %in% .ppNFromCountPct(2500, 50, 0L))
})
