# test-model-arm-n-from-text.R - a model-read table whose arms came back
# with no N gets its sizes from the document text (ISSUES.md issue 42,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 4b finding J1: nine of the eleven Carlisle-168    #
# trials that failed validation were model-read tables (the deterministic #
# engine had failed) with N missing in every row - Fujii's canine papers, #
# whose group sizes are stated in the Methods ("randomly divided into     #
# three groups of eight each", "Group Ia (n = 5) ... Group IIb (n = 8)")  #
# and nowhere in the table. The text ladder ran only inside the           #
# deterministic parser. The model is mocked at the HTTP boundary          #
# (.ppClaudePost / .ppClaudeStructuredOutput), so the whole of            #
# parseBaselineTableAI() runs: page text, request body, template, flags.  #
############################################################################

# a page whose table prints no arm size, above the Methods sentence
methodsPdf <- function(sentence, file = file.path(tempdir(), "methods.pdf")) {
  vx <- c(300, 400, 500)
  cells <- c(
    list(list(x = 72, y = 60, text = "Methods", adj = 0)),
    list(list(x = 72, y = 78, text = sentence, adj = 0)),
    list(list(x = 72, y = 120, text = "Table 1. Hemodynamic values before drug", adj = 0)),
    rowCells(140, "", c("Group Ia", "Group Ib", "Group II"), vx),
    rowCells(160, "Heart rate (beats/min)", c("112 ± 14", "118 ± 12", "115 ± 16"), vx),
    rowCells(178, "MAP (mmHg)",             c("98 ± 11",  "101 ± 9",  "97 ± 12"),  vx),
    list(list(x = 72, y = 200, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

# the model's reply: the two variables read, every arm without an n
modelReply <- function() jsonlite::fromJSON('{
  "found": true, "notes": "",
  "arms": [{"name": "Group Ia", "n": null}, {"name": "Group Ib", "n": null},
           {"name": "Group II", "n": null}],
  "continuous": [
    {"label": "Heart rate (beats/min)", "decimalsMean": 0, "dispersion": "sd",
     "values": [{"arm": "Group Ia", "mean": 112, "sd": 14},
                {"arm": "Group Ib", "mean": 118, "sd": 12},
                {"arm": "Group II", "mean": 115, "sd": 16}]},
    {"label": "MAP (mmHg)", "decimalsMean": 0, "dispersion": "sd",
     "values": [{"arm": "Group Ia", "mean": 98, "sd": 11},
                {"arm": "Group Ib", "mean": 101, "sd": 9},
                {"arm": "Group II", "mean": 97, "sd": 12}]}],
  "categorical": []}', simplifyVector = FALSE)

withModelReply <- function(reply, expr) {
  local_mocked_bindings(
    .ppClaudePost             = function(body, key) list(usage = NULL),
    .ppClaudeStructuredOutput = function(resp) reply)
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  force(expr)
}

test_that("'divided into three groups of eight each' sizes every model arm, with the sentence and the flag", {
  pdf <- methodsPdf("Twenty-four dogs were randomly divided into three groups of eight each.")
  r <- withModelReply(modelReply(),
                      parseBaselineTableAI(pdf, trial = "T", quiet = TRUE))
  expect_identical(r$engine, "ai")
  expect_identical(r$arms$N, c(8L, 8L, 8L))
  expect_identical(r$data$N, rep(8L, 6))
  expect_true(all(grepl("^document text", r$armNSource)))
  expect_match(r$flags, "3 arm size\\(s\\) recovered from the document text")
  expect_match(r$flags, "CONSORT")
  expect_match(r$flags, "three groups of eight")
  # reviewFlags() reads the same element, so the app's review list says it too
  expect_true(any(grepl("CONSORT", reviewFlags(r))))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("per-group '(n = k)' mentions are matched to the arm names, roman tags included", {
  pdf <- methodsPdf(paste("In Group Ia (n = 5) the dogs received saline, in Group Ib (n = 7)",
                          "lidocaine, and in Group II (n = 8) bupivacaine."))
  r <- withModelReply(modelReply(),
                      parseBaselineTableAI(pdf, trial = "T", quiet = TRUE))
  expect_identical(r$arms$N, c(5L, 7L, 8L))
  expect_identical(r$data$N[r$data$ROW == "MAP (mmHg)"], c(5L, 7L, 8L))
  expect_true(all(grepl("arm name matched", r$armNSource)))
})

test_that("a table that printed any arm size keeps the model's reading; nothing stated leaves N missing", {
  reply <- modelReply()
  reply$arms[[2]]$n <- 7L
  pdf <- methodsPdf("Twenty-four dogs were randomly divided into three groups of eight each.")
  r <- withModelReply(reply, parseBaselineTableAI(pdf, trial = "T", quiet = TRUE))
  expect_identical(r$arms$N, c(NA_integer_, 7L, NA_integer_))
  expect_null(r$armNSource)
  expect_null(r$flags)
  pdf2 <- methodsPdf("The dogs were anesthetized with pentobarbital and ventilated.")
  r2 <- withModelReply(modelReply(), parseBaselineTableAI(pdf2, trial = "T", quiet = TRUE))
  expect_true(all(is.na(r2$arms$N)))
  expect_null(r2$armNSource)
})

test_that("the fallback route keeps the model result's own flags behind the failure note", {
  fake <- structure(list(data = data.frame(), arms = data.frame(arm = "A", N = 8L),
                         flags = "1 arm size(s) recovered from the document text",
                         engine = "ai"), class = "ParsePDFTable")
  local_mocked_bindings(
    parseBaselineTableHeuristics = function(...) stop("no table"),
    parseBaselineTableAI = function(...) fake)
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  out <- parseBaselineTable(methodsPdf("x"), ai = "fallback", tatr = "never", quiet = TRUE)
  expect_identical(length(out$flags), 2L)
  expect_match(out$flags[1], "^deterministic parse failed")
  expect_match(out$flags[2], "recovered from the document text")
})
