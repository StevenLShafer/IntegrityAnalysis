# test-refusal-spares-printed-rows.R - the outcome refusal of issue 54 spares
# a model row that the chosen table itself prints (ISSUES.md issue 61,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 9 finding O1 (Polat 2015 KJMS, Sakizci-Uyar 2021): #
# "Duration of anesthesia" and "Duration of surgery" stand in those        #
# papers' own Table 1; the deterministic pass skipped them and the model   #
# supplied them, and the refusal meant for another table's rows threw     #
# them out (P_FULL 0.60 -> 0.16 on two variables). The synthetic table    #
# below prints "Duration of surgery (min)" as a median [range] the         #
# deterministic pass skips.                                                #
############################################################################

test_that("a model row printed inside the chosen table is kept; one from elsewhere is still refused", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}],
    "continuous": [
      {"label": "Duration of surgery (min)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 127, "sd": 20},
                  {"arm": "Treatment", "n": 17, "mean": 133, "sd": 18}]},
      {"label": "Time to first analgesic request (min)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 180, "sd": 40},
                  {"arm": "Treatment", "n": 17, "mean": 260, "sd": 55}]}],
    "categorical": []}', simplifyVector = FALSE)
  canned <- .ppAiToTemplate(reply, trial = "T")
  fake <- structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = "Table 1", trial = "T", notes = "", engine = "ai"),
    class = "ParsePDFTable")
  local_mocked_bindings(parseBaselineTableAI = function(...) fake)
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(syntheticPdfMeanSD(), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_true("Duration of surgery (min)" %in% out$data$ROW)
  expect_false(any(grepl("Time to first analgesic", out$data$ROW)))
  ref <- out$skipped[grepl("outcome vocabulary", out$skipped$reason), ]
  expect_identical(ref$label, "Time to first analgesic request (min)")
  # the block text rides on the deterministic result
  expect_true(any(grepl("Duration of surgery", out$blockText)))
})
