# Adjudication of security screen 2026-09-11-1455 (over 5e49f62..ba6f5ea),
# finding F1 (HIGH, availability): openxlsx's shared-string reader is
# quadratic in a single string's bytes when it holds non-ASCII characters,
# and nothing bounded a "Trial:" marker cell before that read. A workbook
# whose marker cell is 1,000,000 non-ASCII characters (2 MB), padded with
# one incompressible entry to defeat the compression-ratio ceiling, is
# 308 KB on disk, passes every gate, and read for 115 s in .apiReadUpload
# (250,000 chars 6.9 s, 500,000 28 s, 1,000,000 115 s - quadratic),
# pinning the single worker. The counter-loop fix of #309 addressed a
# minor contributor. F2 (LOW): the 1407 tripwire's re-hash check was
# skipped when the loop keywords changed - now it fails closed.
#
# PROVENANCE: written by Claude Code (model Claude Opus 4.8, Anthropic),
# 2026-09-11, with the fix in R/apiService.R (.apiXlsxStringRunOK(),
# called from .apiZipInflationOK(): the string-bearing xlsx parts are
# streamed and the longest run of bytes without "<" - an upper bound on
# one cell's text - is bounded at .iaMaxXlsxStringRun, 128 KiB, before
# openxlsx reads them), pinned in tools/securityCheck.R. Reproduced
# through the path the screen names - the padded non-ASCII workbook
# through .apiReadUpload() - and checked to FAIL on ba6f5ea (28 s at
# 500,000 chars; the guard passed the file).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# a workbook whose one marker cell is `nchars` non-ASCII characters,
# spliced into sharedStrings.xml (openxlsx's writeData caps a cell at
# 32,767), with an incompressible padding entry so the compression-ratio
# ceiling does not catch it - exactly the screen's construction
padNonAsciiXlsx <- function(nchars, pad = 3e5) {
  cells <- rbind(c("Trial: PLACEHOLDERID", "", ""), c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
                 c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)"))
  f <- tempfile(fileext = ".xlsx"); wb <- createWorkbook(); addWorksheet(wb, "S")
  writeData(wb, "S", as.data.frame(cells, stringsAsFactors = FALSE), colNames = FALSE)
  saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  ss <- file.path(d, "xl", "sharedStrings.xml")
  X <- paste(rep("é", nchars), collapse = "")
  s <- readChar(ss, file.size(ss), useBytes = TRUE)
  writeChar(sub("PLACEHOLDERID", X, s, fixed = TRUE), ss, eos = NULL, useBytes = TRUE)
  if (pad > 0) writeBin(as.raw(sample(0:255, pad, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx")
  zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d, include_directories = FALSE)
  g
}

test_that("a padded non-ASCII marker cell is refused before the quadratic read, in milliseconds (screen 1455 F1)", {
  g <- padNonAsciiXlsx(5e5)                                 # 1 MB cell; 28 s on ba6f5ea
  expect_lt(file.size(g), 5e5)                              # a small workbook: the padding, not the cell
  t <- system.time(r <- .apiReadUpload(g, "attack.xlsx"))[["elapsed"]]
  expect_lt(t, 5)                                           # 28 s on ba6f5ea, quadratic to hours
  expect_false(isTRUE(r$ok))                                # refused: the string-run bound
  expect_match(r$reasons, "100 MB|not read", fixed = FALSE)  # the decompression preflight's message
})

test_that("the guard scales: a 2 MB cell is refused as cheaply as a 1 MB one (screen 1455 F1, the differential shape)", {
  t2 <- system.time(r2 <- .apiReadUpload(padNonAsciiXlsx(1e6), "a2.xlsx"))[["elapsed"]]
  expect_lt(t2, 5)                                          # 115 s on ba6f5ea
  expect_false(isTRUE(r2$ok))
})

test_that(".apiXlsxStringRunOK: it bounds the longest run, not the total, and streams from the zip", {
  # a workbook of MANY small cells (a legitimate large table) passes;
  # one oversized cell fails, wherever it sits
  ok <- padNonAsciiXlsx(1000L, pad = 0)                     # a 1,000-char marker: legitimate
  info <- utils::unzip(ok, list = TRUE)
  expect_true(.apiXlsxStringRunOK(ok, info$Name))
  bad <- padNonAsciiXlsx(2e5, pad = 0)                      # 200,000 chars: over the 128 KiB run
  expect_false(.apiXlsxStringRunOK(bad, utils::unzip(bad, list = TRUE)$Name))
  # the run bound is a property of the bytes: a synthetic part with a long
  # "<"-free run is caught, and one broken by tags is not
  d <- tempfile("z"); dir.create(d); dir.create(file.path(d, "xl"))
  writeChar(paste0("<sst><si><t>", strrep("A", 2e5), "</t></si></sst>"),
            file.path(d, "xl", "sharedStrings.xml"), eos = NULL)
  z <- tempfile(fileext = ".zip"); zip::zip(z, "xl/sharedStrings.xml", root = d)
  expect_false(.apiXlsxStringRunOK(z, "xl/sharedStrings.xml"))
})

# The AGGREGATE bound (security screen 2026-09-11-1602, F1 - HIGH): the
# per-cell bound above does not bound the SUM, and openxlsx's cost is
# quadratic PER string summed over every string, so many cells each just
# under the per-cell cap restore the stall - ~740 cells of 127 KiB read
# for 5.5 minutes with every gate green. .iaMaxXlsxStringBytes bounds the
# total "<"-free bytes; a workbook past it is refused before the read.
manyCellXlsx <- function(nStrings, eachChars, pad = 3e5) {
  # nStrings distinct marker rows, each carrying eachChars non-ASCII bytes
  ids <- vapply(seq_len(nStrings), function(i) paste0(strrep("é", eachChars), i), character(1))
  cells <- do.call(rbind, lapply(ids, function(id)
    rbind(c(paste0("Trial: ", id), "", ""), c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
          c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)"))))
  f <- tempfile(fileext = ".xlsx"); wb <- createWorkbook(); addWorksheet(wb, "S")
  writeData(wb, "S", as.data.frame(cells, stringsAsFactors = FALSE), colNames = FALSE)
  saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d)
  if (pad > 0) { zip::unzip(f, exdir = d); writeBin(as.raw(sample(0:255, pad, TRUE)), file.path(d, "docProps", "pad.bin"))
    g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d); g }
  else f
}

test_that("many mid-sized cells summing past the aggregate budget are refused before the read (screen 1602 F1)", {
  # 1,200 cells of ~8 KB each is ~9.6 MB of text, over the 8 MiB budget:
  # under the old per-cell-only guard this read for minutes (each cell is
  # under the per-cell cap); now the aggregate bound catches it
  g <- manyCellXlsx(1200L, 4000L)                          # 4,000 é = 8 KB each
  expect_lt(file.size(g), 2e6)                             # a small workbook
  info <- utils::unzip(g, list = TRUE)
  expect_false(.apiXlsxStringRunOK(g, info$Name))
  t <- system.time(r <- .apiReadUpload(g, "many.xlsx"))[["elapsed"]]
  expect_lt(t, 5)                                          # minutes under the old guard
  expect_false(isTRUE(r$ok))
})

# The per-SHEET multiplier (security screen 2026-09-11-1655, F1 - MEDIUM):
# openxlsx re-parses the shared-string table on every sheet read, so the
# per-file aggregate budget did not bound the total work - a 10-sheet
# workbook whose shared strings fill the budget read for ~36 s, ten times
# a single sheet's. The budget is now divided by the sheet count.
manySheetXlsx <- function(nSheets, nStrings, eachChars, pad = 3e5) {
  wb <- createWorkbook()
  k <- 0L
  for (sh in seq_len(nSheets)) {
    addWorksheet(wb, paste0("S", sh))
    ids <- vapply(seq_len(nStrings), function(i) { k <<- k + 1L
      paste0(strrep("\u00e9", eachChars), k) }, character(1))
    cells <- do.call(rbind, lapply(ids, function(id)
      rbind(c(paste0("Trial: ", id), "", ""), c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
            c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)"))))
    writeData(wb, sh, as.data.frame(cells, stringsAsFactors = FALSE), colNames = FALSE)
  }
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  writeBin(as.raw(sample(0:255, pad, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d); g
}

test_that("a 10-sheet workbook past the per-sheet budget is refused (screen 1655 F1)", {
  g <- manySheetXlsx(10L, 90L, 4000L)                     # ~7 MB distinct shared text; over 8 MiB/10
  info <- utils::unzip(g, list = TRUE)
  expect_false(.apiXlsxStringRunOK(g, info$Name))
  t <- system.time(r <- .apiReadUpload(g, "tensheet.xlsx"))[["elapsed"]]
  expect_lt(t, 5)                                          # ~36 s on 84dcc21
  expect_false(isTRUE(r$ok))
})

# workbook.xml can declare more sheets than there are worksheet PARTS,
# and openxlsx loops over the declarations (getSheetNames), so counting
# parts under-counted the multiplier (security screen 2026-09-11-1730,
# F1): a one-part workbook declaring ten sheets over ~7 MB of shared text
# re-parsed it ten times - 57 s - while the part count was one. The budget
# is now divided by the sheet-count CEILING, so the declaration cannot
# widen it.
lyingSheetsXlsx <- function(nDecl, nStrings, eachChars, pad = 3e5) {
  wb <- createWorkbook(); addWorksheet(wb, "S1")
  ids <- vapply(seq_len(nStrings), function(i) paste0(strrep("\u00e9", eachChars), i), character(1))
  cells <- do.call(rbind, lapply(ids, function(id)
    rbind(c(paste0("Trial: ", id), "", ""), c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
          c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)"))))
  writeData(wb, 1, as.data.frame(cells, stringsAsFactors = FALSE), colNames = FALSE)
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  wbx <- file.path(d, "xl", "workbook.xml")
  x <- readChar(wbx, file.size(wbx), useBytes = TRUE)
  m <- regmatches(x, regexpr("<sheet [^>]*/>", x))                # the one real declaration
  extra <- paste(vapply(2:nDecl, function(k)
    sub('sheetId="[0-9]+"', sprintf('sheetId="%d"', k),
        sub('name="[^"]*"', sprintf('name="S%d"', k), m)), character(1)), collapse = "")
  writeChar(sub(m, paste0(m, extra), x, fixed = TRUE), wbx, eos = NULL, useBytes = TRUE)
  writeBin(as.raw(sample(0:255, pad, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d); g
}

test_that("the sheet count is openxlsx's own, so a tag-name desync cannot undercount it (screen 1730 F1; screen 1826 F1)", {
  # a workbook whose xl/workbook.xml declares its sheets with a tag
  # openxlsx matches loosely (<sheet[^>]*>) but a hand-rolled "<sheet "
  # regex would miss - the exact desync that reopened the stall. Counting
  # via getSheetNames() cannot undercount what read.xlsx will loop over.
  wb <- createWorkbook(); addWorksheet(wb, "S1"); writeData(wb, 1, data.frame(a = "x"))
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d); wbx <- file.path(d, "xl", "workbook.xml")
  x <- readChar(wbx, file.size(wbx), useBytes = TRUE)
  m <- regmatches(x, regexpr("<sheet [^>]*/>", x))
  extra <- paste(vapply(2:10, function(k) sub("^<sheet ", "<sheetZ ",
    sub('name="[^"]*"', sprintf('name="S%d"', k), sub('sheetId="[0-9]+"', sprintf('sheetId="%d"', k), m))), character(1)), collapse = "")
  writeChar(sub(m, paste0(m, extra), x, fixed = TRUE), wbx, eos = NULL, useBytes = TRUE)
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d)
  expect_gt(length(openxlsx::getSheetNames(g)), 1L)        # openxlsx sees the <sheetZ ...> declarations
  expect_identical(.apiXlsxSheetCount(g), length(openxlsx::getSheetNames(g)))   # the divisor matches, whatever the tag
})

test_that("a one-part workbook declaring ten sheets cannot keep the whole budget (screen 1730 F1)", {
  g <- lyingSheetsXlsx(10L, 450L, 8000L)                  # 1 worksheet part, 10 declared, ~7.2 MB shared text
  expect_identical(sum(grepl("xl/worksheets/.*xml$", utils::unzip(g, list = TRUE)$Name)), 1L)   # one part
  expect_identical(length(openxlsx::getSheetNames(g)), 10L)                                      # ten declared
  expect_false(.apiXlsxStringRunOK(g, utils::unzip(g, list = TRUE)$Name))
  t <- system.time(r <- .apiReadUpload(g, "lying.xlsx"))[["elapsed"]]
  expect_lt(t, 5)                                          # 57 s on 32de737 (part count = 1 kept the 8 MiB budget)
  expect_false(isTRUE(r$ok))
})

test_that("a single-sheet workbook keeps the full budget (screen 1655 F1, no over-refusal)", {
  g <- manySheetXlsx(1L, 90L, 4000L)                      # same text, one sheet: under both bounds
  expect_true(.apiXlsxStringRunOK(g, utils::unzip(g, list = TRUE)$Name))
})

test_that("a workbook within the aggregate budget still reads (screen 1602 F1, the accept side)", {
  g <- manyCellXlsx(200L, 40L)                             # 200 small cells, well under budget
  info <- utils::unzip(g, list = TRUE)
  expect_true(.apiXlsxStringRunOK(g, info$Name))
})

test_that("a CDATA marker cell is refused, not silently emptied (screen 1455 F1; CodeRabbit on #310)", {
  # openxlsx returns a CDATA cell empty in 0 s (no quadratic), but the
  # trial id is silently lost; the "<"-run heuristic would be fooled by
  # the internal "<" bytes, so the preflight refuses any "<!" markup in
  # the string parts outright
  cells <- rbind(c("Trial: PLACEHOLDERID", "", ""), c("Variable", "Arm A (n=10)", "Arm B (n=10)"),
                 c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)"))
  f <- tempfile(fileext = ".xlsx"); wb <- createWorkbook(); addWorksheet(wb, "S")
  writeData(wb, "S", as.data.frame(cells, stringsAsFactors = FALSE), colNames = FALSE)
  saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  ss <- file.path(d, "xl", "sharedStrings.xml")
  s <- readChar(ss, file.size(ss), useBytes = TRUE)
  inner <- paste(rep("a<b", 2e5), collapse = "")                     # over the run cap, and full of "<"
  # replace only the TEXT content, so it works whatever attributes the
  # <t> tag carries: CDATA is valid element content
  s2 <- sub("Trial: PLACEHOLDERID", paste0("<![CDATA[", inner, "]]>"), s, fixed = TRUE)
  stopifnot(!identical(s2, s))
  writeChar(s2, ss, eos = NULL, useBytes = TRUE)
  writeBin(as.raw(sample(0:255, 3e5, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d)
  expect_false(.apiXlsxStringRunOK(g, utils::unzip(g, list = TRUE)$Name))
  r <- .apiReadUpload(g, "cdata.xlsx")
  expect_false(isTRUE(r$ok))
})

test_that("an ordinary workbook still reads (the guard does not refuse real tables)", {
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, g)
  info <- utils::unzip(g, list = TRUE)
  expect_true(.apiXlsxStringRunOK(g, info$Name))
  r <- .apiReadUpload(g, "ok.xlsx")
  expect_true(isTRUE(r$ok)); expect_setequal(unique(r$data$TRIAL), unique(two$TRIAL))
})
