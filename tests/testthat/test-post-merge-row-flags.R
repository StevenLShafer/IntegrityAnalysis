# test-post-merge-row-flags.R - the row flags are recomputed on the merged
# table, so a degenerate row the model added is named (ISSUES.md issue 60,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 8 finding N4 (PMID 15281514, a canine paper):     #
# the hybrid merge appended eight "%Edi" rows at 100.0 +/- 0.0 - a          #
# normalised baseline fixed by construction - and issue 36's degenerate    #
# flag, computed before the merge, never named them.                       #
############################################################################

test_that("a degenerate row the model adds is flagged on the hybrid result", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}],
    "continuous": [
      {"label": "Body mass index", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 24.1, "sd": 3.2},
                  {"arm": "Treatment", "n": 17, "mean": 24.6, "sd": 3.0}]},
      {"label": "%Edi at baseline", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 100.0, "sd": 0.0},
                  {"arm": "Treatment", "n": 17, "mean": 100.0, "sd": 0.0}]}],
    "categorical": []}', simplifyVector = FALSE)
  canned <- .ppAiToTemplate(reply, trial = "T")
  fake <- structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = "Table 1", trial = "T", notes = "", engine = "ai"),
    class = "ParsePDFTable")
  local_mocked_bindings(parseBaselineTableAI = function(...) fake)
  # the deterministic table (syntheticPdfMeanSD) is clean; the median row it skips gates the consult
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(syntheticPdfMeanSD(), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_identical(out$engine, "hybrid")
  expect_true("%Edi at baseline" %in% out$data$ROW)
  expect_true(any(grepl("same value with no dispersion", out$flags)))
  expect_true(any(grepl("%Edi at baseline", out$flags)))
  # and only once, though reviewFlags() would repeat the flags the merge already carried
  expect_identical(sum(grepl("could not be used", out$flags)), 1L)
})
