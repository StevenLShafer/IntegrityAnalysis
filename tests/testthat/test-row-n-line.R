# test-row-n-line.R - a "(n = k)" line printed under a row's cells is that
# row's N, arm by arm (ISSUES.md issue 47, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's re-run of Fujii 2002 (PMID 12182258) on dc39659: "Last  #
# menstrual cycle, d*" is followed by "(n = 12) (n = 13) (n = 12) (n = 12)" #
# under its cells (the footnote: "*N = 49. Patients who had experienced    #
# menopause were excluded"). The line was skipped as a header kind, the   #
# row went out with the arm's N of 20, and the hybrid merge kept the       #
# model's row (N 12/13/12/12, same means and SDs) beside it - the variable #
# double-counted. The page cannot ship; the layout is rebuilt here.        #
############################################################################

rowNPdf <- function(file = file.path(tempdir(), "rowN.pdf")) {
  vx <- c(250, 320, 390, 460)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1. Demographic characteristics.", adj = 0)),
    rowCells(96,  "", c("0.15 mg", "0.3 mg", "0.6 mg", "Placebo"), vx),
    rowCells(112, "", c("(n = 20)", "(n = 20)", "(n = 20)", "(n = 20)"), vx),
    rowCells(140, "Age, y", c("46 ± 8", "47 ± 8", "47 ± 8", "48 ± 6"), vx),
    rowCells(158, "Last menstrual cycle, d*", c("15 ± 4", "16 ± 3", "16 ± 2", "16 ± 3"), vx),
    rowCells(172, "", c("(n = 12)", "(n = 13)", "(n = 12)", "(n = 12)"), vx),
    rowCells(190, "Duration of surgery, min", c("170 ± 38", "172 ± 47", "177 ± 43", "174 ± 48"), vx),
    list(list(x = 60, y = 220, text = "*N = 49. Patients who had experienced menopause were excluded.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the (n = k) line under a row gives that row its N; the other rows keep the arm's", {
  r <- parseBaselineTableHeuristics(rowNPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(20L, 4))
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$N[grepl("^Last menstrual", d$ROW)], c(12L, 13L, 12L, 12L))
  expect_identical(d$N[d$ROW == "Age, y"], rep(20L, 4))
  expect_identical(d$N[grepl("^Duration", d$ROW)], rep(20L, 4))
  expect_identical(d$MEAN[grepl("^Last menstrual", d$ROW)], c(15, 16, 16, 16))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("the hybrid merge then recognises the model's reading of that row as the same row", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "0.15 mg", "n": 20}, {"name": "0.3 mg", "n": 20},
             {"name": "0.6 mg", "n": 20}, {"name": "Placebo", "n": 20}],
    "continuous": [
      {"label": "Last menstrual cycle, d", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "0.15 mg", "n": 12, "mean": 15, "sd": 4},
                  {"arm": "0.3 mg",  "n": 13, "mean": 16, "sd": 3},
                  {"arm": "0.6 mg",  "n": 12, "mean": 16, "sd": 2},
                  {"arm": "Placebo", "n": 12, "mean": 16, "sd": 3}]}],
    "categorical": []}', simplifyVector = FALSE)
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
  out <- parseBaselineTable(rowNPdf(), ai = "fallback", quiet = TRUE)
  expect_identical(sum(grepl("^Last menstrual", out$data$ROW)), 4L)
  expect_false("Last menstrual cycle, d" %in% out$data$ROW)
})
