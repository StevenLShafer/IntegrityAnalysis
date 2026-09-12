# Adjudication of security screen 2026-09-11-1913 (over a94674d..739ed34),
# finding F1 (HIGH, availability): the getSheetNames sheet-count fix of
# #314 removed the only bounded reader of xl/workbook.xml. openxlsx's
# getSheetNames() runs a regex over the whole of workbook.xml that is
# quadratic on a crafted body - repeated "<sheets>" openers with no
# closer - so a ~15 KB upload whose workbook.xml is 256 KB of that body
# (an incompressible padding entry holds the ratio gate) read for 85 s
# per call, called up to three times per upload, with every gate green.
# F2 (LOW): the tripwire searched the whole file for getSheetNames, so a
# revert of the divisor would not be caught.
#
# PROVENANCE: written by Claude Code (model Claude Opus 4.8, Anthropic),
# 2026-09-11, with the fix in R/apiService.R (.apiZipInflationOK bounds
# xl/workbook.xml - declared size and stream-bounded actual bytes - at
# .iaMaxWorkbookXmlBytes, 16 KiB, before any getSheetNames call;
# .apiWorkbookXmlBounded), pinned in tools/securityCheck.R. Reproduced
# through .apiReadUpload and checked to stall on 739ed34 (85 s x3) and
# refuse in milliseconds here.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# a workbook whose xl/workbook.xml is `bytes` of the quadratic body, plus
# an incompressible padding entry so the compression-ratio gate passes
wbXmlDosXlsx <- function(bytes, pad = 3e5) {
  wb <- createWorkbook(); addWorksheet(wb, "S1"); writeData(wb, 1, data.frame(a = "x"))
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  writeChar(paste0("<workbook>", strrep("<sheets>", bytes %/% 8L)),
            file.path(d, "xl", "workbook.xml"), eos = NULL, useBytes = TRUE)
  writeBin(as.raw(sample(0:255, pad, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d); g
}

test_that("a large xl/workbook.xml is refused before getSheetNames runs its quadratic regex (screen 1913 F1)", {
  g <- wbXmlDosXlsx(262144L)                               # 256 KB workbook.xml; 85 s x3 on 739ed34
  expect_lt(file.size(g), 5e5)                             # a small upload
  t <- system.time(ok <- .apiZipInflationOK(g, "xlsx"))[["elapsed"]]
  expect_false(ok)                                          # refused by the workbook.xml bound
  expect_lt(t, 3)                                           # in milliseconds, not minutes
  t2 <- system.time(r <- .apiReadUpload(g, "wbdos.xlsx"))[["elapsed"]]
  expect_false(isTRUE(r$ok)); expect_lt(t2, 3)             # >255 s on 739ed34
})

test_that(".apiWorkbookXmlBounded catches an under-declared oversized part, and passes a small one", {
  big <- wbXmlDosXlsx(262144L, pad = 0)
  expect_false(.apiWorkbookXmlBounded(big))               # the actual bytes exceed the cap
  wb <- createWorkbook(); addWorksheet(wb, "S1"); writeData(wb, 1, data.frame(a = "x"))
  ok <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, ok, overwrite = TRUE)
  expect_true(.apiWorkbookXmlBounded(ok))                 # a real workbook.xml is a few KB
})

# openxlsx selects the workbook part by the "workbook.xml$" SUFFIX, not
# the literal "xl/workbook.xml", so the bound matches every suffix hit
# (security screen 2026-09-11-1946, F1): a part named "evil/workbook.xml"
# reaches openxlsx's regex, and a docx routed through this gate with a
# "word/workbook.xml" would too (F2).
suffixWbXmlXlsx <- function(entry, bytes, pad = 3e5) {
  wb <- createWorkbook(); addWorksheet(wb, "S1"); writeData(wb, 1, data.frame(a = "x"))
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  dir.create(file.path(d, dirname(entry)), showWarnings = FALSE, recursive = TRUE)
  writeChar(paste0("<workbook>", strrep("<sheets>", bytes %/% 8L)), file.path(d, entry), eos = NULL, useBytes = TRUE)
  writeBin(as.raw(sample(0:255, pad, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d); g
}

test_that("an oversized workbook.xml under any path is refused, matching openxlsx's suffix selector (screen 1946 F1)", {
  g <- suffixWbXmlXlsx("evil/workbook.xml", 262144L)       # real xl/workbook.xml stays small
  hits <- utils::unzip(g, list = TRUE)$Name[grepl("workbook.xml$", utils::unzip(g, list = TRUE)$Name)]
  expect_true("evil/workbook.xml" %in% hits && "xl/workbook.xml" %in% hits)
  t <- system.time(ok <- .apiZipInflationOK(g, "xlsx"))[["elapsed"]]
  expect_false(ok); expect_lt(t, 3)                        # missed by a literal-name bound on 1d5e936
  expect_false(.apiWorkbookXmlBounded(g, "evil/workbook.xml"))
})

test_that("a docx carrying a quadratic word/workbook.xml is bounded on the xlsx-routed gate (screen 1946 F2)", {
  # .ppDocxData routes docx through .apiZipInflationOK(., 'xlsx'); the
  # suffix bound covers word/workbook.xml the same way
  g <- suffixWbXmlXlsx("word/workbook.xml", 262144L)
  t <- system.time(ok <- .apiZipInflationOK(g, "xlsx"))[["elapsed"]]
  expect_false(ok); expect_lt(t, 3)
})

test_that("a decoy workbook part is refused: the archive must have exactly one xl/workbook.xml (screen 2006 F1)", {
  # openxlsx selects with an UNESCAPED "workbook.xml$" (the "." a wildcard),
  # so "xl/workbookAxml" is a part openxlsx reads but a dot-escaped bound
  # misses. The gate requires exactly one match, named xl/workbook.xml.
  for (entry in c("xl/workbookAxml", "evil/workbook.xml")) {
    g <- suffixWbXmlXlsx(entry, 262144L)                   # real xl/workbook.xml stays small
    hits <- utils::unzip(g, list = TRUE)$Name[grepl("workbook.xml$", utils::unzip(g, list = TRUE)$Name)]
    expect_gt(length(hits), 1L)                            # openxlsx would pick more than one
    t <- system.time(ok <- .apiZipInflationOK(g, "xlsx"))[["elapsed"]]
    expect_false(ok); expect_lt(t, 3)                      # refused as an ambiguous/decoy naming
  }
})

test_that("the workbook rels part is bounded, and a duplicate entry name is refused (screen 2117 F3, F4)", {
  # an oversized xl/_rels/workbook.xml.rels (openxlsx runs a quadratic
  # regex over it per sheet) is refused, matching openxlsx's selector
  wb <- createWorkbook(); addWorksheet(wb, "S1"); writeData(wb, 1, data.frame(a = "x"))
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE)
  d <- tempfile("x"); dir.create(d); zip::unzip(f, exdir = d)
  writeChar(paste0("<Relationships>", strrep('Target="', 262144L %/% 8L)),
            file.path(d, "xl", "_rels", "workbook.xml.rels"), eos = NULL, useBytes = TRUE)
  writeBin(as.raw(sample(0:255, 3e5, TRUE)), file.path(d, "docProps", "pad.bin"))
  g <- tempfile(fileext = ".xlsx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = d)
  t <- system.time(ok <- .apiZipInflationOK(g, "xlsx"))[["elapsed"]]
  expect_false(ok); expect_lt(t, 3)                        # minutes if openxlsx grepped it unbounded
  # duplicate entry names: R's zip cannot make them, Python's zipfile can
  skip_if_not(nzchar(Sys.which("python")))
  py <- tempfile(fileext = ".py"); zf <- tempfile(fileext = ".xlsx")
  writeLines(c("import zipfile,sys", "z=zipfile.ZipFile(sys.argv[1],'w')",
               "z.writestr('xl/sharedStrings.xml','<sst/>')",
               "z.writestr('xl/sharedStrings.xml','<sst>'+('x'*100)+'</sst>')",
               "z.writestr('[Content_Types].xml','<Types/>')", "z.close()"), py)
  system2("python", c(py, zf), stdout = NULL, stderr = NULL)
  skip_if_not(file.exists(zf))
  expect_gt(anyDuplicated(utils::unzip(zf, list = TRUE)$Name), 0L)
  expect_false(.apiZipInflationOK(zf, "xlsx"))             # the scan reads the first entry, openxlsx the last
})

test_that("an ordinary workbook still reads (the bound does not refuse real files)", {
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, g)
  expect_true(.apiZipInflationOK(g, "xlsx"))
  r <- .apiReadUpload(g, "ok.xlsx")
  expect_true(isTRUE(r$ok)); expect_setequal(unique(r$data$TRIAL), unique(two$TRIAL))
})
