# test-label-suffix-merge-pairs.R - the same variable under a label suffix,
# one cell apart, is one variable in the hybrid merge (ISSUES.md issue 52,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 5 finding K3 (CJA 1997;44:390, Saitoh): the       #
# table's "Weight" and the model's "Weight - kg" held the same cells but   #
# one - the page prints "57.9 ± 64", a missing decimal point, read as 6.4  #
# by the table's reading and 64.0 by the model - so the value signature   #
# did not match and both survived, the variable counted twice.            #
############################################################################

withModel <- function(reply, pdfFile) {
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
  parseBaselineTable(pdfFile, ai = "fallback", tatr = "never", quiet = TRUE)
}

test_that("a model variable that is the table's own under a suffix, differing in one cell, is dropped and the cell named", {
  # syntheticPdfMeanSD: Control 15 / Treatment 17; Weight 63 ± 13 / 68 ± 12
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}],
    "continuous": [
      {"label": "Weight - kg", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 63, "sd": 13},
                  {"arm": "Treatment", "n": 17, "mean": 68, "sd": 1.2}]}],
    "categorical": []}', simplifyVector = FALSE)
  out <- withModel(reply, syntheticPdfMeanSD())
  expect_identical(sum(out$data$ROW == "Weight"), 2L)
  expect_false("Weight - kg" %in% out$data$ROW)
  w <- out$data[out$data$ROW == "Weight" & !is.na(out$data$MEAN), ]
  expect_identical(w$SD, c(13, 12))                      # the table's own reading is kept
  expect_true(any(grepl("label suffix", out$flags)))
  expect_true(any(grepl("1 of 2 cell", out$flags)))
})

test_that("a model variable under a similar label whose cells mostly differ is still a new variable", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}],
    "continuous": [
      {"label": "Weight - kg", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Control", "n": 15, "mean": 70, "sd": 11},
                  {"arm": "Treatment", "n": 17, "mean": 72, "sd": 12}]}],
    "categorical": []}', simplifyVector = FALSE)
  out <- withModel(reply, syntheticPdfMeanSD())
  expect_true("Weight - kg" %in% out$data$ROW)
  expect_false(any(grepl("label suffix", out$flags)))
})
