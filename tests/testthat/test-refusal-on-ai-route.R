# test-refusal-on-ai-route.R - the outcome refusal applies on the AI-only
# retry route too, by vocabulary alone (ISSUES.md issue 64, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 11 finding P2 (Fujii, PMID 9773135, engine "ai"): #
# with no deterministic table beside it, the model's page reading carried #
# Table 2's operative management beside Table 1's rows and nothing        #
# refused them (p 0.24 -> 0.039). The hybrid route had refused such rows  #
# since issue 54; the AI-only route now shares the test.                   #
############################################################################

test_that(".ppOutcomeLabel() names outcomes, spares a label printed in the block, and needs no block", {
  labs <- c("Age (years)", "Duration of surgery (min)", "Time to first analgesic request", "Weight (kg)")
  expect_identical(.ppOutcomeLabel(labs, NULL), c(FALSE, TRUE, TRUE, FALSE))
  blk <- c("Table 1", "Age (years) 30 (5)", "Duration of surgery (min) 84 (26)")
  expect_identical(.ppOutcomeLabel(labs, blk), c(FALSE, FALSE, TRUE, FALSE))
})

test_that("on the AI-only route an outcome variable is refused with its reason and a flag", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Placebo", "n": 28}, {"name": "Granisetron", "n": 27}],
    "continuous": [
      {"label": "Age (years)", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 28, "mean": 31.2, "sd": 4.1}, {"arm": "Granisetron", "n": 27, "mean": 30.8, "sd": 4.4}]},
      {"label": "Duration of surgery (min)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 28, "mean": 48, "sd": 12}, {"arm": "Granisetron", "n": 27, "mean": 46, "sd": 11}]},
      {"label": "I-D interval (min)", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 28, "mean": 8.1, "sd": 2.2}, {"arm": "Granisetron", "n": 27, "mean": 8.4, "sd": 2.0}]}],
    "categorical": []}', simplifyVector = FALSE)
  canned <- .ppAiToTemplate(reply, trial = "T")
  fake <- structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = NA_character_, trial = "T", notes = "", engine = "ai"),
    class = "ParsePDFTable")
  local_mocked_bindings(
    parseBaselineTableHeuristics = function(...) stop("no table"),
    parseBaselineTableAI = function(...) fake)
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(syntheticPdfMeanSD(), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_identical(out$engine, "ai")
  expect_identical(unique(out$data$ROW), "Age (years)")
  expect_setequal(out$skipped$label, c("Duration of surgery (min)", "I-D interval (min)"))
  expect_true(any(grepl("refused as outcomes", out$flags)))
  expect_false(any(out$provenance$ROW %in% out$skipped$label))
})
