# Adjudication of security screen 2026-09-10-1628 (over 68f1ed5..84051f3),
# finding F3 (LOW): two levels of ONE variable whose names collapse to the
# same column overwrote each other in the AI converter, and one level's
# count silently vanished from the categorical row.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/aiFallback.R (the level names are made
# unique one at a time, each result joining the set the next is checked
# against; the S2 fix's vapply() checked every level against the same
# set). Reproduced through the path the screen names - a structured
# response through the actual parser with only the transport mocked, as
# the S2 test does - and checked to FAIL on 84051f3 ("N" and "n" both
# spelled "category n"; two columns where there are three levels).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

cannedResponse <- function(levels) {
  parsed <- list(found = TRUE, notes = "",
                 arms = list(list(name = "A", n = 90L), list(name = "B", n = 91L)),
                 continuous = list(),
                 categorical = list(list(label = "Category", categories = as.list(levels),
                                         values = list(list(arm = "A", counts = list(30L, 50L, 10L)),
                                                       list(arm = "B", counts = list(30L, 51L, 10L))))))
  list(stop_reason = "end_turn",
       content = list(list(type = "text",
                           text = as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE)))))
}

test_that("two levels of one variable that spell the same column keep separate columns and counts (screen 1628 F3)", {
  skip_if_not_installed("pdftools")
  pdf <- syntheticPdfMeanSD()
  testthat::local_mocked_bindings(
    .ppClaudePost = function(body, apiKey, timeout = 300) cannedResponse(c("N", "n", "Male")),
    .package = "IntegrityAnalysis")
  r <- parseBaselineTableAI(pdf, trial = "T", apiKey = "sk-ant-test", quiet = TRUE)
  d <- r$data
  cat <- d[d$ROW == "Category", , drop = FALSE]
  expect_equal(nrow(cat), 2L)
  catCols <- setdiff(names(d), .ppBaseColumns())
  expect_equal(length(catCols), 3L)                     # three levels, three columns
  expect_equal(unname(unlist(cat[1, catCols])), c(30L, 50L, 10L))
  expect_equal(unname(unlist(cat[2, catCols])), c(30L, 51L, 10L))
  expect_true(all(is.na(cat$N)))                        # the reserved field untouched
  # and the category totals are the arms' totals, every count present
  expect_equal(unname(rowSums(cat[, catCols])), c(90, 91))
})

test_that("the unique names are made one at a time within a variable", {
  # the rule's spelling for both "N" and "n" is "category n"; the second
  # takes the next free name rather than the first's column
  seen <- c(.ppBaseColumns(), "Q1", "Q3", "LEVEL")
  lv <- vapply(c("N", "n"), function(l) .iaLevelColumnName("Category", l), character(1))
  out <- character(0)
  for (k in seq_along(lv)) { out[k] <- .ppUniqueName(lv[k], existing = seen); seen <- c(seen, out[k]) }
  expect_equal(unname(out), c("category n", "category n 2"))
})
