# test-model-raw-reply.R - the model's reply rides along verbatim on the
# parse result (ISSUES.md issue 43, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 4b finding J2: two runs of the same page can       #
# disagree (the call runs with thinking on, which fixes temperature at 1), #
# and only the merged table survived in the checkpoints, so a disagreement #
# could not be attributed to the model or to the template step. The reply  #
# text is now attached to the structured output and returned as aiReply.   #
############################################################################

test_that("the structured output carries the reply text, and parseBaselineTableAI returns it as aiReply", {
  reply <- '{"found": true, "notes": "", "arms": [{"name": "Control", "n": 15}, {"name": "Treatment", "n": 17}], "continuous": [{"label": "Age (yr)", "decimalsMean": 1, "dispersion": "sd", "values": [{"arm": "Control", "n": 15, "mean": 45.3, "sd": 12.1}, {"arm": "Treatment", "n": 17, "mean": 46.1, "sd": 11.8}]}], "categorical": []}'
  # a reply split across two text blocks arrives as one string
  resp <- list(stop_reason = "end_turn",
               content = list(list(type = "text", text = substr(reply, 1, 40)),
                              list(type = "thinking", thinking = "..."),
                              list(type = "text", text = substr(reply, 41, nchar(reply)))),
               usage = list(input_tokens = 10L, output_tokens = 20L))
  parsed <- .ppClaudeStructuredOutput(resp)
  expect_identical(attr(parsed, "raw"), reply)
  expect_true(isTRUE(parsed$found))
  # through the whole route, mocked at the HTTP boundary only
  local_mocked_bindings(.ppClaudePost = function(body, key) resp)
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key-not-used")
  r <- parseBaselineTableAI(syntheticPdfMeanSD(), trial = "T", quiet = TRUE)
  expect_identical(r$aiReply, reply)
  expect_identical(jsonlite::fromJSON(r$aiReply, simplifyVector = FALSE)$arms[[2]]$n, 17L)
  expect_identical(r$arms$N, c(15L, 17L))
  # a test double that hands back a plain list leaves the element NULL
  local_mocked_bindings(.ppClaudeStructuredOutput = function(resp) jsonlite::fromJSON(reply, simplifyVector = FALSE))
  r2 <- parseBaselineTableAI(syntheticPdfMeanSD(), trial = "T", quiet = TRUE)
  expect_null(r2$aiReply)
})
