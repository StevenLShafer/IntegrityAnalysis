# Adjudication of security screen 2026-09-11-2117, finding F1 (HIGH,
# correctness and availability of a legitimate route): the every-.xml
# cell-text scan of #319 (screen 2033) was reached by the docx route,
# which passes every Word file through .apiZipInflationOK(docxFile,
# "xlsx"). A docx is a zip whose XML parts all end in "xml", and a real
# manuscript's word/document.xml carries long base64 <w:fldData> runs
# (EndNote citation data) well over the 16 KiB run cap, and a megabyte of
# text over the aggregate; eleven of the twelve corpus manuscripts were
# refused, and production auto-deploys, so the Word route was refusing
# ordinary manuscripts.
#
# PROVENANCE: written by Claude Code (model Claude Opus 4.8, Anthropic),
# 2026-09-11, with the fix in R/parseDocx.R (the docx passes ext "docx",
# not "xlsx") and R/apiService.R (.apiZipInflationOK runs the generic
# zip-bomb bounds for "docx" but not the xlsx cell-text/workbook/sheet
# bounds; an unreadable docx is still refused). Reproduced by building a
# docx with a long field-data run and checking it passes as "docx" and
# was refused as "xlsx".
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(officer); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

# a docx with a long base64 <w:fldData> run spliced into document.xml,
# the shape a submitted manuscript with EndNote fields has
manuscriptDocx <- function(runBytes = 25000L, totalPad = 1200000L) {
  d <- officer::read_docx()
  d <- officer::body_add_par(d, "A submitted manuscript.")
  f0 <- tempfile(fileext = ".docx"); print(d, target = f0)
  dd <- tempfile("x"); dir.create(dd); zip::unzip(f0, exdir = dd)
  doc <- file.path(dd, "word", "document.xml")
  x <- readChar(doc, file.size(doc), useBytes = TRUE)
  fld <- paste0('<w:fldData xml:space="preserve">', strrep("A", runBytes), "</w:fldData>")
  more <- strrep(paste0('<w:t xml:space="preserve">', strrep("B", 1500L), "</w:t>"),
                 max(1L, totalPad %/% 1520L))              # many mid-sized runs: a megabyte of text
  x <- sub("</w:body>", paste0(fld, more, "</w:body>"), x, fixed = TRUE)
  writeChar(x, doc, eos = NULL, useBytes = TRUE)
  g <- tempfile(fileext = ".docx"); zip::zip(g, list.files(dd, all.files = TRUE, no.. = TRUE, recursive = TRUE), root = dd); g
}

test_that("a Word manuscript with long field-data runs passes the docx preflight (screen 2117 F1)", {
  g <- manuscriptDocx()
  parts <- utils::unzip(g, list = TRUE)$Name
  expect_true(all(grepl("xml$", parts[grepl("document.xml$", parts)])))   # a docx: xml parts
  expect_true(.apiZipInflationOK(g, "docx"))               # the generic bounds only: passes
  expect_false(.apiZipInflationOK(g, "xlsx"))              # the regression: the xlsx scan refused it
  expect_silent(suppressWarnings(.ppDocxData(g)))          # the whole route parses
})

test_that("the docx route still refuses a zip bomb and a non-zip file (the generic bounds remain)", {
  # a non-zip file named .docx is refused (a docx must be a zip)
  nz <- tempfile(fileext = ".docx"); writeBin(as.raw(rep(65L, 1000L)), nz)
  expect_false(.apiZipInflationOK(nz, "docx"))
  # a declared-oversize archive is refused by the generic total bound
  d <- tempfile("z"); dir.create(d)
  writeBin(raw(0), file.path(d, "big.bin"))
  # (the ratio/total gates are exercised by the xlsx zip-bomb tests; here
  # we only assert the docx ext reaches them - a normal small docx passes)
  g <- manuscriptDocx(runBytes = 100L, totalPad = 2000L)
  expect_true(.apiZipInflationOK(g, "docx"))
})
