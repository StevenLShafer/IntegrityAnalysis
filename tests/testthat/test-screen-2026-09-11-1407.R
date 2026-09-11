# Adjudication of security screen 2026-09-11-1407 (over cc229fb..5e49f62),
# finding F1 (MEDIUM, availability): the counter loop of .wideTrialLabels()
# recomputed the clipped stem and the SHA-1 of the whole long id on every
# collision step, so the cost was counters x bytes. On the xlsx route a
# "Trial:" marker cell is bounded only by the 100 MiB inflation cap, so
# one multi-megabyte marker beside thousands of literal counter spellings
# (the author computes the digest offline) pinned the request's thread:
# measured on the map itself, a 10 MB id against 5,000 taken spellings
# cost 101 s on 5e49f62 and 0.08 s once the stem and digest are computed
# once per id. N1: the byte-bound comment assumed a three-digit counter.
#
# PROVENANCE: written by Claude Code (model Claude Opus 4.8, Anthropic),
# 2026-09-11, with the fix in R/parseWideTable.R (stem and digest hoisted
# out of the counter loop) pinned in tools/securityCheck.R. The finding
# is in .wideTrialLabels(); the timing case drives it directly (the exact
# hot loop the screen names) and is checked to FAIL on 5e49f62 (101 s at
# 10 MB) and pass here; a genuine large-cell xlsx exercises the same path
# through .apiReadUpload().
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# the taken labels for a long id X: its plain spelling and its counter
# spellings (2)..(k), each a distinct literal an author can supply
takenSpellings <- function(X, k) {
  stem <- .ppClip(X, .iaMaxTrialIdChars - 24L)
  h <- substr(digest::digest(X, algo = "sha1", serialize = FALSE), 1L, 12L)
  c(.wideTrialId(X), paste0(stem, " #", h, " (", 2:k, ")"))
}

test_that("the counter loop is linear in the ids, not in their bytes (screen 1407 F1)", {
  # a 10 MB id against 5,000 of its own taken spellings: 101 s on 5e49f62
  # (each step re-hashed 10 MB), 0.08 s here (one clip, one digest)
  X <- strrep("Y", 1e7)
  taken <- takenSpellings(X, 5000L)
  t <- system.time(m <- .wideTrialLabels(c(taken, X)))[["elapsed"]]
  expect_lt(t, 20)                                          # 101 s on 5e49f62
  expect_identical(length(unique(m$label)), 5001L)
  stem <- .ppClip(X, .iaMaxTrialIdChars - 24L)
  h <- substr(digest::digest(X, algo = "sha1", serialize = FALSE), 1L, 12L)
  expect_identical(m$label[length(m$label)], paste0(stem, " #", h, " (5001)"))   # X takes the first free counter
})

test_that("the cost does not grow with the id's size (screen 1407 F1, the differential shape)", {
  # 100 KB and 10 MB ids, same 2,000 counters: on 5e49f62 the second cost
  # a hundred times the first; here they are within noise of each other
  t1 <- system.time(.wideTrialLabels(c(takenSpellings(strrep("y", 1e5), 2000L), strrep("y", 1e5))))[["elapsed"]]
  t2 <- system.time(.wideTrialLabels(c(takenSpellings(strrep("y", 1e7), 2000L), strrep("y", 1e7))))[["elapsed"]]
  expect_lt(t2, 10)                                         # about 40 s on 5e49f62
  expect_lt(t2, t1 + 5)                                     # 100x on 5e49f62; flat here
})

test_that("N1: a six-digit counter still fits the 200-byte bound", {
  X <- strrep("z", 300L)
  stem <- .ppClip(X, .iaMaxTrialIdChars - 24L)
  h <- substr(digest::digest(X, algo = "sha1", serialize = FALSE), 1L, 12L)
  expect_lte(nchar(paste0(stem, " #", h, " (100000)"), type = "bytes"), .iaMaxTrialIdChars)
  expect_lte(nchar(paste0(stem, " #", h, " (999999)"), type = "bytes"), .iaMaxTrialIdChars)
})

# build an xlsx whose one marker cell is genuinely large: openxlsx's
# writeData caps a cell at 32,767 characters, so the big id is spliced
# into sharedStrings.xml and the parts rezipped with the zip package,
# exactly as a hostile author would (and as the reader reads it back)
bigMarkerXlsx <- function(bigBytes, others) {
  X <- strrep("X", bigBytes)
  markers <- c(others, "PLACEHOLDERID")                    # PLACEHOLDER stands in for X at write time
  cells <- do.call(rbind, lapply(markers, function(id)
    rbind(c(paste0("Trial: ", id), "", ""),
          c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
          c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)"))))
  f <- tempfile(fileext = ".xlsx"); wb <- createWorkbook(); addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", as.data.frame(cells, stringsAsFactors = FALSE), colNames = FALSE)
  saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  ss <- file.path(d, "xl", "sharedStrings.xml")
  s <- readChar(ss, file.size(ss), useBytes = TRUE)
  writeChar(sub("PLACEHOLDERID", X, s, fixed = TRUE), ss, eos = NULL, useBytes = TRUE)
  g <- tempfile(fileext = ".xlsx")
  zip::zipr(g, file.path(d, list.files(d, all.files = TRUE, no.. = TRUE)), include_directories = TRUE)
  list(path = g, X = X)
}

# What the xlsx route admits after screen 2026-09-11-1455 F1. That screen
# found openxlsx's shared-string reader quadratic in a single cell's
# bytes and bounded every cell's text at 128 KiB (.iaMaxXlsxStringRun,
# .apiXlsxStringRunOK) before the read - so a marker cell over that is now
# refused outright, and the counter-loop cost this file exercises can only
# be reached by MANY within-bound ids, which the map test above covers
# directly. A cell within the bound is read and takes its counter label.
test_that("a marker cell over the 128 KiB text bound is refused before the read (screens 1407 and 1455 F1)", {
  fx2 <- bigMarkerXlsx(2e6, character(0))                   # 2 MB cell
  r2 <- .apiReadUpload(fx2$path, "big2mb.xlsx")
  expect_false(isTRUE(r2$ok))
  expect_match(r2$reasons, "100 MB", fixed = TRUE)           # .apiZipInflationOK refuses, before any parse
})

test_that("a marker cell within the 16 KiB bound is read and takes a distinct counter label (screen 1407 F1, through the route)", {
  X <- strrep("X", 8000L)                                   # 8 KB: under the 16 KiB cell bound
  # the other markers are X's own plain spelling and one counter, supplied
  # literally: X must resolve past them to (3), never merge into them
  fx <- bigMarkerXlsx(8000L, takenSpellings(X, 2L))
  t <- system.time(r <- .apiReadUpload(fx$path, "bigcell.xlsx"))[["elapsed"]]
  expect_true(isTRUE(r$ok)); expect_identical(r$engine, "wide")
  expect_lt(t, 20)
  tr <- unique(r$data$TRIAL)
  expect_identical(length(tr), 3L)                          # the two literals and X, all distinct
  expect_lte(max(nchar(tr, type = "bytes")), .iaMaxTrialIdChars)
  stem <- .ppClip(X, .iaMaxTrialIdChars - 24L)
  h <- substr(digest::digest(X, algo = "sha1", serialize = FALSE), 1L, 12L)
  expect_true(paste0(stem, " #", h, " (3)") %in% tr)        # X's own spelling and (2) were taken
})
