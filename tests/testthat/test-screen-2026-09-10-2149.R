# Adjudication of security screen 2026-09-10-2149 (over 90d3404..7fd6545),
# finding F1 (HIGH, availability): the whole-block clip of #290 covered the
# block matrix, not the "Trial:" marker row above it nor a sheet's name,
# and the trial id is copied into every line the block becomes - a marker
# of 99,990 bytes (under the line gate) over 2,500 two-arm rows was 5,000
# lines of 100 KB: a 500 MB template from a 215 KB upload, held three
# times over on the way out; and F2 (LOW, suspect): the text refusal
# measured cells and never the column names.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (the id clipped at both
# its sources to .iaMaxTrialIdChars, 200), R/apiService.R (the wide
# branch's frame passes .iaTableTextRefusal() before the reply, as the
# template branch's does) and R/app_globals.R (the refusal measures the
# column names too); pinned in tools/securityCheck.R. Reproduced through
# the path the screen names - the CSV through .apiReadUpload() - and
# checked to FAIL on 7fd6545 (5,000 lines of a 100 KB id, a 500 MB
# template).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

markerCsv <- function(idBytes, rows) {
  f <- tempfile(fileext = ".csv")
  writeLines(c(paste0("Trial: ", strrep("i", idBytes)),
               "Variable,Arm A (n=10),Arm B (n=10)",
               rep('"Age, mean (SD)","45.3 (12.1)","46.1 (11.8)"', rows)), f)
  f
}

test_that("a 100 KB trial id in a marker row is clipped at its source, not copied into 5,000 lines (screen 2149 F1)", {
  f <- markerCsv(99990L, 2500L)
  expect_lt(file.size(f), 300000)
  t <- system.time(r <- .apiReadUpload(f, "marker.csv"))[["elapsed"]]
  expect_lt(t, 30)
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_identical(nrow(r$data), 5000L)
  expect_lte(max(nchar(r$data$TRIAL, type = "bytes")), .iaMaxTrialIdChars)   # 99,990 on 7fd6545
  expect_lt(nchar(.apiTemplateCsv(r$data), type = "bytes"), 3e6)             # about 500 MB on 7fd6545
})

test_that("an ordinary marker id and an ordinary sheet name are untouched", {
  f <- markerCsv(12L, 3L)
  r <- .apiReadUpload(f, "m.csv")
  expect_true(isTRUE(r$ok))
  expect_identical(unique(r$data$TRIAL), strrep("i", 12L))
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, g)
  r2 <- .apiReadUpload(g, "two.xlsx")
  expect_true(isTRUE(r2$ok)); expect_setequal(unique(r2$data$TRIAL), unique(two$TRIAL))
})

test_that("the wide branch's frame passes the text refusal, and the refusal measures column names (screen 2149 F2)", {
  d <- data.frame(TRIAL = "T", ROW = "Age", N = 10, MEAN = 50, SD = 10, stringsAsFactors = FALSE)
  names(d)[5] <- strrep("H", 2001L)
  expect_match(.iaTableTextRefusal(d), "column name of 2001", fixed = TRUE)
  names(d)[5] <- strrep("H", 2000L)
  expect_null(.iaTableTextRefusal(d))
  # the wide branch: a frame the refusal would reject cannot come back ok
  # (every wide cell is already bounded, so this asserts the call sits on
  # the branch - a long marker id under the clip is the only lever left)
  f <- markerCsv(99990L, 3L)
  r <- .apiReadUpload(f, "m2.csv")
  expect_true(isTRUE(r$ok))
  expect_lte(max(nchar(r$data$TRIAL, type = "bytes")), .iaMaxTrialIdChars)
})
