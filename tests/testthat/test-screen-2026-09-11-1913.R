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

test_that("an ordinary workbook still reads (the bound does not refuse real files)", {
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, g)
  expect_true(.apiZipInflationOK(g, "xlsx"))
  r <- .apiReadUpload(g, "ok.xlsx")
  expect_true(isTRUE(r$ok)); expect_setequal(unique(r$data$TRIAL), unique(two$TRIAL))
})
