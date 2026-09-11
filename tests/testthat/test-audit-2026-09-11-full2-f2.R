# Adjudication of the fourth full-pass independent statistical audit of
# 2026-09-11 (docs/audits/2026-09-11-full2-independent-statistical-audit-chatgpt.md),
# finding F2 (numerical P2): the bounded trial label of #302 - a long id's
# first 184 bytes, " #" and twelve hex digits of its SHA-1 - was also the
# trial's identity, so a short id supplied LITERALLY as that spelling (an
# author can copy a label out of an earlier result) collided with the long
# id by construction, with no digest collision needed: two differently
# named trials became one four-arm trial (0.005275 where the file's two
# trials combine to 0.07139), through /parse and /analyze alike, while the
# template route kept both.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-11, with the fix in R/parseWideTable.R (.wideTrialLabels(): the
# labels are assigned for the whole file at once - an id within the bound
# is its own label, a longer id takes its generated spelling unless that
# is another id's label, in which case a shorter prefix and a counter),
# pinned in tools/securityCheck.R. The fixture is the auditor's
# (evidence-2026-09-11-full2/fixture-trial-id-namespace-wide.csv: L =
# "Synthetic identity " x 12 + "A", 229 bytes, and S = the 198-byte
# spelling the reader generates for L), through the path the report names
# - the CSV through .apiReadUpload() and .apiAnalyze() (the real /parse and
# /analyze requests are in test-api-service.R) - with the report's four
# controls, and checked to FAIL on 7c6583f (one trial, 0.005275).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

wideCsv <- function(ids, var = '"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"') {
  f <- tempfile(fileext = ".csv")
  writeLines(c(rbind(paste0("Trial: ", ids), "Variable,Arm A (n=30),Arm B (n=30)", var)), f)
  f
}
L <- paste0(strrep("Synthetic identity ", 12L), "A")
S <- .wideTrialId(L)

test_that("the fixture is the auditor's: a 229-byte id and its own 198-byte generated spelling", {
  expect_identical(nchar(L, type = "bytes"), 229L)
  expect_identical(nchar(S, type = "bytes"), 198L)
  expect_match(S, " #a020339ac28c$")                      # the report's digest
  expect_identical(.wideTrialId(S), S)                     # S is within the bound: its own spelling
})

test_that("a literal id equal to a long id's generated spelling stays a separate trial (audit 2026-09-11 full2, F2)", {
  r <- .apiReadUpload(wideCsv(c(L, S)), "namespace.csv")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  tr <- unique(r$data$TRIAL)
  expect_identical(length(tr), 2L)                         # 1 on 7c6583f
  expect_identical(nrow(r$data), 4L)
  expect_true(S %in% tr)                                   # the literal id keeps its text
  other <- setdiff(tr, S)
  expect_match(other, " #a020339ac28c \\(2\\)$")           # the long id: a shorter prefix and a counter
  expect_lte(nchar(other, type = "bytes"), .iaMaxTrialIdChars)
  a <- shiny::isolate(.apiAnalyze(r$data, seed = 42))
  expect_true(isTRUE(a$ok)); expect_equal(a$trials, 2L)
  p <- as.numeric(a$overallP)
  expect_gt(p, 0.04); expect_lt(p, 0.12)                   # 0.07139 at seed 42; 0.005275 on 7c6583f
})

test_that("the order of the two blocks is immaterial: the literal id is its own label either way", {
  r <- .apiReadUpload(wideCsv(c(S, L)), "namespace-rev.csv")
  expect_true(isTRUE(r$ok))
  tr <- unique(r$data$TRIAL)
  expect_identical(length(tr), 2L)
  expect_true(S %in% tr)
  expect_match(setdiff(tr, S), " \\(2\\)$")
})

test_that("the report's controls: two short ids, the same long id twice, the template route", {
  r <- .apiReadUpload(wideCsv(c("Trial A", "Trial B")), "two-short.csv")
  expect_setequal(unique(r$data$TRIAL), c("Trial A", "Trial B"))
  r2 <- .apiReadUpload(wideCsv(c(L, L), var = c('"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"',
                                                '"Weight, mean (SD)","70.0 (12.0)","71.0 (12.0)"')), "same.csv")
  expect_identical(unique(r2$data$TRIAL), S)               # one trial, its plain generated spelling
  expect_identical(nrow(r2$data), 4L)
  d <- data.frame(TRIAL = rep(c(L, S), each = 2), ROW = "Age", N = 30, MEAN = c(50, 50.5, 50, 50.5), SD = 10,
                  stringsAsFactors = FALSE)
  f <- tempfile(fileext = ".csv"); utils::write.csv(d, f, row.names = FALSE)
  r3 <- .apiReadUpload(f, "template.csv")
  expect_true(isTRUE(r3$ok)); expect_identical(length(unique(r3$data$TRIAL)), 2L)
})

test_that(".wideTrialLabels(): literal ids are their own labels, generated ones never collide, the bound holds", {
  x <- strrep("x", 210L); y <- strrep("y", 210L)
  m <- .wideTrialLabels(c("A", x, "A", y))                 # a repeated original is one entry
  expect_identical(m$original, c("A", x, y))
  expect_identical(m$label, c("A", .wideTrialId(x), .wideTrialId(y)))
  # the generated spelling supplied literally: the literal keeps it, the long id moves on
  m2 <- .wideTrialLabels(c(.wideTrialId(x), x))
  expect_identical(m2$label[1], .wideTrialId(x))
  expect_match(m2$label[2], " \\(2\\)$")
  # ...and the counter climbs past every taken spelling
  m3 <- .wideTrialLabels(c(.wideTrialId(x), m2$label[2], x))
  expect_match(m3$label[3], " \\(3\\)$")
  expect_true(all(nchar(m3$label, type = "bytes") <= .iaMaxTrialIdChars))
  expect_identical(length(unique(m3$label)), 3L)
  # lookup
  expect_identical(.wideTrialLabel(m3, x), m3$label[3])
  expect_identical(.wideTrialLabel(m3, "A"), "A")          # absent from the map: the bare spelling
  # a 100 KB id (screen 2149) is bounded the same way
  big <- strrep("i", 99990L)
  expect_identical(.wideTrialLabels(big)$label, .wideTrialId(big))
})
