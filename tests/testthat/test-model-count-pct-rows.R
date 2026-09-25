# test-model-count-pct-rows.R - a count (%) row the model called continuous
# is filed as a category with its complement, by the same identity the
# deterministic engine applies to its own cells (ISSUES.md issue 53,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 6 finding L3 (Ozkan 2019, Der Anaesthesist        #
# 68:90; arms n = 26/25): the model returned "Intubation success (at the   #
# first-pass attempt)" 26 (100) / 20 (80) and "Mallampati score" 8 (31) /  #
# 4 (16) as continuous rows, and they entered the analysis as MEAN 26,    #
# SD 100. The percentages are the counts' share of the arm sizes.         #
############################################################################

test_that("a model 'continuous' row whose sd is the count's percentage of N becomes a category with its complement", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "Videolaryngoscope", "n": 26}, {"name": "Macintosh", "n": 25}],
    "continuous": [
      {"label": "Age (years)", "decimalsMean": 1, "dispersion": "sd",
       "values": [{"arm": "Videolaryngoscope", "mean": 50.5, "sd": 8.0},
                  {"arm": "Macintosh", "mean": 46.8, "sd": 7.3}]},
      {"label": "Intubation success at the first-pass attempt", "decimalsMean": 0,
       "values": [{"arm": "Videolaryngoscope", "mean": 26, "sd": 100},
                  {"arm": "Macintosh", "mean": 20, "sd": 80}]},
      {"label": "Mallampati score 3", "decimalsMean": 0,
       "values": [{"arm": "Videolaryngoscope", "mean": 8, "sd": 31},
                  {"arm": "Macintosh", "mean": 4, "sd": 16}]}],
    "categorical": []}', simplifyVector = FALSE)
  t <- .ppAiToTemplate(reply, trial = "T")
  d <- t$data
  # Age stays continuous
  expect_identical(d$MEAN[d$ROW == "Age (years)"], c(50.5, 46.8))
  # the success row is counts: no MEAN, a level column with the counts, a complement
  s <- d[d$ROW == "Intubation success at the first-pass attempt", ]
  expect_true(all(is.na(s$MEAN)))
  lv <- setdiff(names(s), c(.ppBaseColumns(), "Q1", "Q3"))
  cnt <- vapply(lv, function(c) all(!is.na(s[[c]])), logical(1))
  expect_identical(sum(cnt), 2L)
  vals <- lapply(lv[cnt], function(c) s[[c]])
  expect_true(any(vapply(vals, function(v) identical(as.integer(v), c(26L, 20L)), logical(1))))
  expect_true(any(vapply(vals, function(v) identical(as.integer(v), c(0L, 5L)), logical(1))))
  # a "score" row keeps its continuous reading, whatever its numbers
  m <- d[d$ROW == "Mallampati score 3", ]
  expect_identical(m$MEAN, c(8, 4))
  expect_identical(m$SD, c(31, 16))
})

test_that("a row whose 'sd' is not the count's share of N stays continuous", {
  reply <- jsonlite::fromJSON('{
    "found": true, "notes": "",
    "arms": [{"name": "A", "n": 20}, {"name": "B", "n": 20}],
    "continuous": [
      {"label": "Heart rate", "decimalsMean": 0, "dispersion": "sd",
       "values": [{"arm": "A", "mean": 72, "sd": 10}, {"arm": "B", "mean": 75, "sd": 12}]}],
    "categorical": []}', simplifyVector = FALSE)
  t <- .ppAiToTemplate(reply, trial = "T")
  expect_identical(t$data$MEAN, c(72, 75))
  expect_identical(t$data$SD, c(10, 12))
})
