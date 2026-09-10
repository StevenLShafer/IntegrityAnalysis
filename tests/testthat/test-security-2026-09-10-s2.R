# Adjudication of the private security audit of 2026-09-10, S2 (MEDIUM):
# a model response naming its category levels N, MEAN and SD wrote its
# counts into the reserved template fields, so a categorical variable
# reached the validator as two continuous lines.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/aiFallback.R and R/app_globals.R
# (.iaLevelColumnName). Reproduced THROUGH THE PATH THE REPORT NAMES: the
# structured response through parseBaselineTableAI() - only the model
# transport (.ppClaudePost) replaced by a canned reply - then the
# converter, the validator and the API's analysis. Checked to FAIL on
# d6496e0.
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

test_that("levels named after reserved fields become category columns, not continuous data (security audit 2026-09-10, S2)", {
  skip_if_not_installed("pdftools")
  pdf <- syntheticPdfMeanSD()
  testthat::local_mocked_bindings(
    .ppClaudePost = function(body, apiKey, timeout = 300) cannedResponse(c("N", "MEAN", "SD")),
    .package = "IntegrityAnalysis")
  r <- parseBaselineTableAI(pdf, trial = "T", apiKey = "sk-ant-synthetic-audit-only", quiet = TRUE)
  d <- r$data
  cat <- d[d$ROW == "Category", , drop = FALSE]
  expect_equal(nrow(cat), 2L)
  # the reserved fields are untouched...
  expect_true(all(is.na(cat$N))); expect_true(all(is.na(cat$MEAN))); expect_true(all(is.na(cat$SD)))
  # ...and the counts sit in three category columns of their own
  catCols <- setdiff(names(d), .ppBaseColumns())
  expect_equal(length(catCols), 3L)
  expect_equal(unname(unlist(cat[1, catCols])), c(30L, 50L, 10L))
  expect_equal(unname(unlist(cat[2, catCols])), c(30L, 51L, 10L))
  # and the whole thing analyses as the categorical variable it is
  a <- shiny::isolate(.apiAnalyze(d, seed = 42))
  expect_true(isTRUE(a$ok))
  expect_true(any(grepl("Category, n", a$journalTables[[1]], fixed = TRUE)))
  expect_false(any(grepl("Category, mean (SD)", a$journalTables[[1]], fixed = TRUE)))
  p <- suppressWarnings(as.numeric(as.character(
    a$results$P[!is.na(a$results$KIND) & a$results$KIND == "summary"][1])))
  expect_lt(p, 0.05)                                    # 0.297 as two continuous lines
})

test_that("the level-name rule: base columns and header tokens are renamed, other levels kept", {
  expect_equal(.iaLevelColumnName("Category", "N"), "category n")
  expect_equal(.iaLevelColumnName("Category", "mean"), "category mean")
  expect_equal(.iaLevelColumnName("Category", "Row count"), "category row count")
  expect_equal(.iaLevelColumnName("Sex", "Male"), "Male")
  expect_equal(.iaLevelColumnName("Sex", "Female"), "Female")
})
