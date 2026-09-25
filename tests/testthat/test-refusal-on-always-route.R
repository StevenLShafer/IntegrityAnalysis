# test-refusal-on-always-route.R - the outcome refusal applies on the
# explicit ai = "always" route as on the fallback (ISSUES.md issue 66,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 13 finding R2 (Fujii, PMID 9542558): the batches  #
# retry a failed trial with ai = "always", and on that route the model's   #
# reading kept Table 2's operative management (duration of surgery, I-D   #
# interval, total ephedrine, tubal ligation) beside Table 1's five rows -  #
# 16 rows became 40 and p moved from 0.059 to 7e-05 - while the same page #
# through the fallback route was refused (issue 64). The refusal is one    #
# helper now, .ppRefuseModelOutcomes(), and both routes call it.           #
############################################################################

fakeModelTable <- function() {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Placebo", "n": 25}, {"name": "Granisetron", "n": 25}],
    "continuous": [
      {"label": "Age (years)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 25, "mean": 29, "sd": 4}, {"arm": "Granisetron", "n": 25, "mean": 30, "sd": 5}]},
      {"label": "Duration of surgery (min)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 25, "mean": 48, "sd": 12}, {"arm": "Granisetron", "n": 25, "mean": 46, "sd": 11}]},
      {"label": "I-D interval (min)", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 25, "mean": 8.1, "sd": 2.2}, {"arm": "Granisetron", "n": 25, "mean": 8.4, "sd": 2.0}]},
      {"label": "Total ephedrine (mg)", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "Placebo", "n": 25, "mean": 12, "sd": 6}, {"arm": "Granisetron", "n": 25, "mean": 11, "sd": 5}]}],
    "categorical": []}', simplifyVector = FALSE)
  canned <- .ppAiToTemplate(reply, trial = "T")
  structure(list(
    data = canned$data, arms = canned$arms,
    skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
    provenance = data.frame(ROW = canned$data$ROW, ENGINE = "ai", stringsAsFactors = FALSE),
    pages = 1L, caption = NA_character_, trial = "T", notes = "", engine = "ai"),
    class = "ParsePDFTable")
}

test_that("ai = 'always' refuses outcome variables with their reason and a flag, as the fallback does", {
  local_mocked_bindings(parseBaselineTableAI = function(...) fakeModelTable())
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(syntheticPdfMeanSD(), ai = "always", tatr = "never", quiet = TRUE)
  expect_identical(out$engine, "ai")
  # the true outcome (a vasopressor dose) is refused; the two durations are
  # the durations class, kept by default and flagged (issue 74)
  expect_setequal(unique(out$data$ROW),
                  c("Age (years)", "Duration of surgery (min)", "I-D interval (min)"))
  expect_identical(out$skipped$label, "Total ephedrine (mg)")
  expect_true(any(grepl("refused as outcomes", out$flags)))
  expect_true(any(grepl("post-randomisation quantities", out$flags)))
  expect_false(any(out$provenance$ROW %in% out$skipped$label))
  # ?durations=exclude on this route drops them too
  gone <- parseBaselineTable(syntheticPdfMeanSD(), ai = "always", tatr = "never", quiet = TRUE,
                             durations = "exclude")
  expect_identical(unique(gone$data$ROW), "Age (years)")
  expect_setequal(gone$skipped$label,
                  c("Total ephedrine (mg)", "Duration of surgery (min)", "I-D interval (min)"))
})

test_that("the helper leaves a result with no outcome label untouched, and ignores other engines", {
  fake <- fakeModelTable()
  keep <- !grepl("surgery|interval|ephedrine", fake$data$ROW)
  fake$data <- fake$data[keep, , drop = FALSE]
  fake$provenance <- fake$provenance[keep, , drop = FALSE]
  expect_identical(.ppRefuseModelOutcomes(fake), fake)
  other <- fakeModelTable(); other$engine <- "hybrid"
  expect_identical(.ppRefuseModelOutcomes(other), other)
})
