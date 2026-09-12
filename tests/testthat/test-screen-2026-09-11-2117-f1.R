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

test_that("the docx route reaches the generic zip-bomb bounds and refuses a non-zip file (screen 2117 F1; 2148 F3)", {
  # a non-zip file named .docx is refused (a docx must be a zip)
  nz <- tempfile(fileext = ".docx"); writeBin(as.raw(rep(65L, 1000L)), nz)
  expect_false(.apiZipInflationOK(nz, "docx"))
  # a real zip whose declared uncompressed total exceeds the cap is
  # refused THROUGH the docx ext - proving the "docx" branch reaches the
  # generic bounds, not that a stray early return skips them
  d <- tempfile("z"); dir.create(d)
  writeChar(strrep("A", 2000L), file.path(d, "word_document.xml"), eos = NULL)
  g <- tempfile(fileext = ".docx"); zip::zip(g, list.files(d, all.files = TRUE, no.. = TRUE), root = d)
  info <- utils::unzip(g, list = TRUE)
  info$Length[1] <- .apiMaxUncompressed + 1L               # (the real gate reads the archive's own directory)
  # drive the real gate: an archive declaring over the cap is refused
  bomb <- tempfile(fileext = ".docx")
  con <- file(bomb, "wb"); writeBin(charToRaw("not a real bomb; see below"), con); close(con)
  # build a genuine over-cap declared archive: many entries summing past the cap
  big <- tempfile("b"); dir.create(big)
  for (i in 1:20) writeBin(as.raw(rep(0L, 6e6)), file.path(big, sprintf("p%02d.xml", i)))  # 120 MB uncompressed
  gb <- tempfile(fileext = ".docx"); zip::zip(gb, list.files(big), root = big)
  expect_false(.apiZipInflationOK(gb, "docx"))             # over the 100 MiB declared cap, via docx
  # a normal small docx passes
  expect_true(.apiZipInflationOK(manuscriptDocx(runBytes = 100L, totalPad = 2000L), "docx"))
})
