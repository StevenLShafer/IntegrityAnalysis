# test-refuse-model-outcome-rows.R - a variable the model adds to the
# deterministic baseline table is refused when its label names an outcome
# (ISSUES.md issue 54, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 6 finding L2: on Polat 2018 the model, asked for  #
# the baseline table beside the deterministic reading, also returned      #
# Tables 2-3 ("Time to T10", "Time to first analgesic request",           #
# Bradycardia / Hypotension / Nausea / Pruritus), on Akkaya 2016 the VAS  #
# and ODI at every follow-up. The call is not reproducible, so a run may  #
# read every table on the page; the refusal is on our side of the merge.  #
############################################################################

test_that("model-added outcome variables are refused with a reason; a baseline variable is still added", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}],
    "continuous": [
      {"label": "Weight; kg", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 70, "sd": 11},
                  {"arm": "Treatment", "n": 17, "mean": 72, "sd": 12}]},
      {"label": "Time to first analgesic request (min)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 180, "sd": 40},
                  {"arm": "Treatment", "n": 17, "mean": 260, "sd": 55}]},
      {"label": "VAS at 24 h", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 3.2, "sd": 1.1},
                  {"arm": "Treatment", "n": 17, "mean": 2.1, "sd": 0.9}]}],
    "categorical": [
      {"label": "Nausea", "categories": ["Yes", "No"],
       "values": [{"arm": "Control", "counts": [4, 11]}, {"arm": "Treatment", "counts": [2, 15]}]}]
  }', simplifyVector = FALSE)
  canned <- .ppAiToTemplate(reply, trial = "T")
  fake <- structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = "Table 1", trial = "T", notes = "", engine = "ai"),
    class = "ParsePDFTable")
  local_mocked_bindings(
    parseBaselineTableAI = function(...) fake,
    reviewFlags = function(x) "one table line could not be used: forced")
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(syntheticPdfMeanSD(), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_identical(out$engine, "hybrid")
  expect_true("Weight; kg" %in% out$data$ROW)
  expect_false(any(grepl("Time to first analgesic|VAS at 24 h|^Nausea", out$data$ROW)))
  ref <- out$skipped[grepl("outcome vocabulary", out$skipped$reason), ]
  expect_setequal(ref$label, c("Time to first analgesic request (min)", "VAS at 24 h", "Nausea"))
  expect_true(any(grepl("refused as outcomes", out$flags)))
  # the deterministic rows are untouched
  expect_true(all(c("Age", "Weight", "Height") %in% out$data$ROW))
})
