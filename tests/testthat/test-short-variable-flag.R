# test-short-variable-flag.R - a continuous variable with fewer cells than
# the table has arms is a review flag, so the model is consulted and the
# arm-by-arm merge fills the missing cells (ISSUES.md issue 51, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 5 finding K2 (CJA 1995;42:992, six arms of 15):   #
# Age read in all six arms, Height and Weight in four - the OCR of two    #
# cells failed - and the deterministic table was accepted as it stood, so #
# the fallback never consulted the model and both variables entered the   #
# analysis two arms short (P_FULL 0.0368 -> 0.128 against the model's     #
# six-arm reading). The layout is rebuilt here with one cell unreadable.  #
############################################################################

shortPdf <- function(file = file.path(tempdir(), "short.pdf")) {
  vx <- c(230, 320, 410)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Demographic data", adj = 0)),
    rowCells(100, "", c("A (n = 15)", "B (n = 15)", "C (n = 15)"), vx),
    rowCells(130, "Age (yr)",    c("45.5 ± 11.4", "45.0 ± 9.5", "48.9 ± 9.1"), vx),
    rowCells(148, "Height (cm)", c("167.1 ± 10.0", "l66.9 + l0.2", "165.5 ± 10.9"), vx),   # the middle cell as OCR mangled it
    rowCells(166, "Weight (kg)", c("56.7 ± 6.9", "57.1 ± 6.7", "56.0 ± 7.0"), vx),
    list(list(x = 60, y = 200, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a variable with fewer cells than arms raises the review flag; full variables do not", {
  r <- parseBaselineTableHeuristics(shortPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(sum(!is.na(r$data$MEAN) & r$data$ROW == "Height"), 2L)
  fl <- reviewFlags(r)
  expect_true(any(grepl("fewer cells than the table has arms", fl)))
  expect_true(any(grepl("Height \\(2 of 3\\)", fl)))
  expect_false(any(grepl("Age \\(", fl)))
  full <- parseBaselineTableHeuristics(syntheticPdfMeanSD(), quiet = TRUE)
  expect_false(any(grepl("fewer cells", reviewFlags(full))))
})

test_that("the flag consults the model, and the arm-by-arm merge fills the missing cell from its reading", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "A", "n": 15}, {"name": "B", "n": 15}, {"name": "C", "n": 15}],
    "continuous": [
      {"label": "Height (cm)", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "A", "n": 15, "mean": 167.1, "sd": 10.0},
                  {"arm": "B", "n": 15, "mean": 166.9, "sd": 10.2},
                  {"arm": "C", "n": 15, "mean": 165.5, "sd": 10.9}]}],
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
  out <- parseBaselineTable(shortPdf(), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_identical(out$engine, "hybrid")
  h <- out$data[out$data$ROW == "Height" & !is.na(out$data$MEAN), ]
  expect_identical(nrow(h), 3L)
  expect_true(166.9 %in% h$MEAN)
  expect_true(any(out$provenance$ENGINE[out$provenance$ROW == "Height"] == "ai"))
  # the reply rides along on the hybrid result too (the corpus session's L1)
  fake2 <- fake; fake2$aiReply <- "{\"found\": true}"
  local_mocked_bindings(parseBaselineTableAI = function(...) fake2)
  out2 <- parseBaselineTable(shortPdf(), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_identical(out2$aiReply, "{\"found\": true}")
})
