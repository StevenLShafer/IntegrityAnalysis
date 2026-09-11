# Adjudication of the third full-pass independent statistical audit of
# 2026-09-11 (docs/audits/2026-09-11-full-independent-statistical-audit-chatgpt.md),
# finding F2 (numerical P2): the 200-byte clip of a journal-style trial id
# (screen 2149 F1, #294) made two distinct ids that share their first 200
# bytes ONE trial - two two-arm blocks of the same variable became a
# four-arm trial, and the file's overall p of 0.07139 read 0.005275
# (0.0048-0.0058), below the screen's 0.01, with no flag. A wide CSV whose
# ids were 200 bytes, the same file as a template, and the same 201-byte
# file on the commit before the clip all kept two trials.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-11, with the fix in R/parseWideTable.R (.wideTrialId(): an id
# within the bound is used as it is; a longer one becomes its first 184
# bytes, " #" and twelve hex digits of the SHA-1 of the whole id, so it
# stays bounded and keeps its identity), pinned in tools/securityCheck.R.
# The fixture is the auditor's (evidence-2026-09-11-full/
# fixture-trial-id-201-delta-0.5.csv, two "Trial:" blocks with 201-byte
# ids differing in their last byte), through the path the report names -
# the CSV through .apiReadUpload() and .apiAnalyze() (the real /parse and
# /analyze requests are in test-api-service.R) - and checked to FAIL on
# 6db32ee (one trial, 0.005275).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# the auditor's fixture: two blocks, ids of 200 common bytes plus one
# each (201), or any ids given
wideCsv <- function(ids, var = '"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"') {
  f <- tempfile(fileext = ".csv")
  writeLines(c(rbind(paste0("Trial: ", ids), "Variable,Arm A (n=30),Arm B (n=30)", var)), f)
  f
}
longIds <- function(n = 201L, suffixes = c("A", "B"))
  paste0(substr(strrep("Synthetic baseline comparison ", 8L), 1L, n - 1L), suffixes)

test_that("two 201-byte ids sharing their first 200 bytes stay two trials, bounded (audit 2026-09-11 full, F2)", {
  ids <- longIds()
  expect_identical(nchar(ids, type = "bytes"), c(201L, 201L))
  expect_identical(substr(ids[1], 1, 200), substr(ids[2], 1, 200))
  r <- .apiReadUpload(wideCsv(ids), "two.csv")
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  tr <- unique(r$data$TRIAL)
  expect_identical(length(tr), 2L)                         # 1 on 6db32ee
  expect_identical(nrow(r$data), 4L)                       # two arms each
  expect_lte(max(nchar(tr, type = "bytes")), .iaMaxTrialIdChars)
  expect_identical(substr(tr, 1, 184), substr(ids, 1, 184))   # the label is still the id's own text
  expect_match(tr, " #[0-9a-f]{12}$")
  a <- shiny::isolate(.apiAnalyze(r$data, seed = 42))
  expect_true(isTRUE(a$ok))
  expect_equal(a$trials, 2L)
  p <- as.numeric(a$overallP)
  expect_gt(p, 0.04); expect_lt(p, 0.12)                   # 0.07139 at seed 42; 0.005275 on 6db32ee
})

test_that("ids within the bound are untouched, and the same long id in two blocks is one trial", {
  ids <- longIds(200L)
  r <- .apiReadUpload(wideCsv(ids), "two200.csv")
  expect_true(isTRUE(r$ok))
  expect_setequal(unique(r$data$TRIAL), ids)               # exactly the ids, no digest
  same <- rep(longIds(240L, "X"), 2)
  r2 <- .apiReadUpload(wideCsv(same, var = c('"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"',
                                             '"Weight, mean (SD)","70.0 (12.0)","71.0 (12.0)"')), "same.csv")
  expect_true(isTRUE(r2$ok))
  expect_identical(length(unique(r2$data$TRIAL)), 1L)      # one trial, two variables
  expect_setequal(unique(r2$data$ROW), c("Age", "Weight"))
})

test_that(".wideTrialId(): bounded, identity-preserving, deterministic, byte-wise", {
  expect_identical(.wideTrialId("Trial A"), "Trial A")
  expect_identical(.wideTrialId(NA_character_), "")
  x <- strrep("x", 200L); expect_identical(.wideTrialId(x), x)
  a <- paste0(x, "A"); b <- paste0(x, "B")
  ta <- .wideTrialId(a); tb <- .wideTrialId(b)
  expect_false(identical(ta, tb))
  expect_identical(ta, .wideTrialId(a))                    # deterministic
  expect_identical(nchar(ta, type = "bytes"), 184L + 2L + 12L)
  expect_identical(substr(ta, 1, 184), strrep("x", 184L))
  expect_identical(substr(ta, 185, 186), " #")
  expect_identical(substr(ta, 187, 198), substr(digest::digest(a, algo = "sha1", serialize = FALSE), 1, 12))
  # a multibyte id: clipped on a character boundary, still bounded
  u <- strrep("\u00e9", 150L)                              # 300 bytes
  tu <- .wideTrialId(u)
  expect_lte(nchar(tu, type = "bytes"), .iaMaxTrialIdChars)
  expect_true(validUTF8(tu))
  # a 100 KB id (screen 2149 F1) is bounded the same way
  big <- strrep("i", 99990L)
  expect_identical(nchar(.wideTrialId(big), type = "bytes"), 198L)
})
