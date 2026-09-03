# test-tatr.R - the Table Transformer + tesseract seam (R/parseTatr.R).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-02 by Claude Code (model Claude Fable 5.1) with the      #
# seam itself, at Steve Shafer's direction ("Add tatr-tesseract to pdf     #
# parser workflow"). The model cannot run in the suite (PyTorch lives on   #
# the Linux nodes), so these tests hand-build the XML tatrTables.py would  #
# write for the synthetic PDFs - whose cell coordinates the fixtures       #
# control - and assert that the seam reproduces the text-layer parse from  #
# geometry alone, with and without the text layer.                         #
############################################################################

# The XML tatrTables.py writes, for a table whose row and column bands are
# given in POINTS (top-left origin); the file carries rendered pixels at
# 150 dpi, exactly as the Python side does.
tatrXmlFor <- function(file, page, rows, cols, cells, keep = TRUE,
                       headRows = integer(0), dpi = 150) {
  k <- dpi / 72
  px <- function(v) sprintf("%.1f", v * k)
  box <- function(tag, b, index = NULL)
    sprintf('<%s%s x0="%s" y0="%s" x1="%s" y1="%s" />', tag,
            if (is.null(index)) "" else sprintf(' index="%d"', index),
            px(b[1]), px(b[2]), px(b[3]), px(b[4]))
  esc <- function(s) gsub("&", "&amp;", gsub("<", "&lt;", s))
  trs <- vapply(seq_len(nrow(cells)), function(r) paste0(
    sprintf('<tr row="%d" header="%s">', r - 1L,
            if (r %in% headRows) "true" else "false"),
    paste(sprintf('<td col="%d">%s</td>', seq_len(ncol(cells)) - 1L,
                  esc(cells[r, ])), collapse = ""),
    "</tr>"), character(1))
  tb <- c(min(cols[, 1]), min(rows[, 1]), max(cols[, 2]), max(rows[, 2]))
  xml <- paste0(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<tatr-tables schema-version="1" derived="true" ground-truth="false" ',
    'accession="test" render-dpi="', dpi, '">',
    '<provenance-note>test fixture</provenance-note>',
    sprintf('<table-wrap id="p%02dt0" page="%d" detection-score="0.9000" rows="%d" cols="%d" passed-plausibility="%s">',
            page, page, nrow(cells), ncol(cells), if (keep) "true" else "false"),
    "<table><tbody>", paste(trs, collapse = ""), "</tbody></table>",
    sprintf('<geometry units="rendered-px" dpi="%d">', dpi),
    box("table-box", tb),
    paste(vapply(seq_len(nrow(rows)), function(i)
      box("row-box", c(tb[1], rows[i, 1], tb[3], rows[i, 2]), i - 1L), character(1)),
      collapse = ""),
    paste(vapply(seq_len(nrow(cols)), function(i)
      box("col-box", c(cols[i, 1], tb[2], cols[i, 2], tb[4]), i - 1L), character(1)),
      collapse = ""),
    "</geometry></table-wrap></tatr-tables>")
  writeLines(xml, file, useBytes = TRUE)
  file
}

# The geometry of syntheticPdfMeanSD(): rows at these y's (text tops, per
# makeTablePdf), labels at x = 72, values centred at 300 and 420.
meanSDGeometry <- function() {
  ys <- c(110, 128, 150, 168, 186, 204, 222, 240, 258, 276, 294)
  list(rows = cbind(ys - 3, ys + 11),
       cols = rbind(c(60, 250), c(262, 338), c(382, 458)),
       cells = rbind(
         c("",                          "Control",      "Treatment"),
         c("",                          "(n = 15)",     "(n = 17)"),
         c("Age (yr)",                  "45.3 ± 12.1", "46.1 ± 11.8"),
         c("Weight (kg)",               "63 ± 13",     "68 ± 12"),
         c("Height (cm)",               "165 ± 7",     "167 ± 7"),
         c("Sex (M/F)",                 "10/5",         "12/5"),
         c("Type of surgery",           "",             ""),
         c("Upper abdominal",           "3",            "4"),
         c("Lower abdominal",           "5",            "6"),
         c("Urologic",                  "7",            "7"),
         c("Duration of surgery (min)", "127 [98-160]", "133 [101-155]")))
}
srt <- function(d) {
  d <- d[, c("ROW", "N", "MEAN", "SD")]
  d[order(d$ROW, d$N, d$MEAN, d$SD), , drop = FALSE]
}

test_that("a TATR file reads back with its geometry in points", {
  # the shape tatrTables.py wrote for a real article (IA018270, 2026-09-01)
  f <- tempfile(fileext = ".tatr.xml")
  writeLines(c(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<tatr-tables schema-version="1" derived="true" ground-truth="false" accession="IA018270" render-dpi="150">',
    '<provenance-note>x</provenance-note>',
    '<table-wrap id="p09t0" page="9" detection-score="0.7139" rows="2" cols="3" passed-plausibility="true">',
    '<table><tbody><tr row="0" header="false"><td col="0">IMP:</td><td col="1" /><td col="2" /></tr>',
    '<tr row="1" header="true"><td col="0">Analysis Plan</td><td col="1">8 of 40</td><td col="2">Version 1.0</td></tr></tbody></table>',
    '<geometry units="rendered-px" dpi="150"><table-box x0="318.6" y0="1464.6" x1="1077.8" y1="1543.3" />',
    '<row-box index="1" x0="307.8" y0="1515.7" x1="1090.0" y1="1549.9" /><row-box index="0" x0="308.5" y0="1466.6" x1="1089.4" y1="1508.3" />',
    '<col-box index="0" x0="308.4" y0="1467.4" x1="535.7" y1="1549.9" /><col-box index="1" x0="536.8" y0="1467.6" x1="792.6" y1="1549.7" /><col-box index="2" x0="794.6" y0="1467.2" x1="1090.3" y1="1550.3" />',
    '</geometry></table-wrap></tatr-tables>'), f, useBytes = TRUE)
  t <- .ppReadTatr(f)
  expect_length(t, 1L)
  t <- t[[1]]
  expect_identical(t$page, 9L)
  expect_true(t$keep)
  expect_identical(dim(t$cells), c(2L, 3L))
  expect_identical(t$cells[2, 2], "8 of 40")
  expect_identical(t$headRows, 2L)
  expect_equal(unname(t$box[["x0"]]), 318.6 * 72 / 150, tolerance = 1e-6)
  # row boxes come back in index order however the file listed them
  expect_true(t$rowBoxes[1, "y0"] < t$rowBoxes[2, "y0"])
  expect_identical(nrow(t$colBoxes), 3L)
  # not a TATR file
  expect_error(.ppReadTatr(system.file("extdata", "Example.xlsx", package = "IntegrityAnalysis")))
})

test_that("words land in the cell holding at least half of their box", {
  g <- meanSDGeometry()
  tbl <- list(rowBoxes = cbind(x0 = 60, y0 = g$rows[, 1], x1 = 458, y1 = g$rows[, 2]),
              colBoxes = cbind(x0 = g$cols[, 1], y0 = 107, x1 = g$cols[, 2], y1 = 305))
  colnames(tbl$rowBoxes) <- c("x0", "y0", "x1", "y1")
  colnames(tbl$colBoxes) <- c("x0", "y0", "x1", "y1")
  words <- data.frame(
    text = c("Age", "(yr)", "45.3", "±", "12.1", "stray", "half"),
    x = c(72, 90, 285, 300, 310, 500, 245), y = c(150, 150, 150, 150, 150, 150, 168),
    width = c(16, 16, 18, 6, 18, 20, 30), height = 8, stringsAsFactors = FALSE)
  m <- .ppTatrFillCells(tbl, words)
  expect_identical(m[3, 1], "Age (yr)")
  expect_identical(m[3, 2], "45.3 ± 12.1")
  expect_identical(m[3, 3], "")
  # "stray" lies outside every column; "half" straddles the label/value gap
  # with less than half its width in either column - neither is placed
  expect_false(any(grepl("stray|half", m)))
})

test_that("TATR geometry with the text layer reproduces the text-layer parse", {
  src <- syntheticPdfMeanSD()
  g <- meanSDGeometry()
  xml <- tatrXmlFor(tempfile(fileext = ".tatr.xml"), 1L, g$rows, g$cols, g$cells,
                    headRows = 1:2)
  direct <- parseBaselineTableHeuristics(src, quiet = TRUE)
  r <- parseBaselineTableTatr(src, xml, quiet = TRUE)
  expect_identical(r$engine, "heuristic-tatr")
  expect_identical(r$layout, "tatr")
  expect_true(all(r$provenance$ENGINE == "tatr"))
  expect_identical(r$pages, 1L)
  # the caption sits above the box in the page's own words
  expect_match(r$caption, "Table 1")
  expect_equal(srt(r$data), srt(direct$data), ignore_attr = TRUE)
  expect_identical(r$arms$N, direct$arms$N)
  # the footnote beneath the box reached the engine: the median [range]
  # row is skipped for the same stated reason
  expect_identical(nrow(r$skipped), nrow(direct$skipped))
})

test_that("TATR geometry plus tesseract reproduces the parse with no text layer at all", {
  skip_if_not_installed("tesseract")
  skip_on_cran()
  src <- syntheticPdfMeanSD()
  g <- meanSDGeometry()
  empty <- matrix("", nrow(g$cells), ncol(g$cells))
  xml <- tatrXmlFor(tempfile(fileext = ".tatr.xml"), 1L, g$rows, g$cols, empty,
                    keep = FALSE)
  direct <- parseBaselineTableHeuristics(src, quiet = TRUE)
  # ocr = "always" stands in for a page with no text layer: the text the
  # engine sees comes from tesseract, the geometry from the XML
  r <- parseBaselineTableTatr(src, xml, ocr = "always", quiet = TRUE)
  expect_identical(r$engine, "heuristic-tatr-ocr")
  expect_true(all(r$provenance$ENGINE == "ocr"))
  expect_equal(srt(r$data), srt(direct$data), ignore_attr = TRUE)
  expect_identical(r$arms$N, direct$arms$N)
  # ...and with ocr = "never" the empty cells are, correctly, nothing
  expect_error(parseBaselineTableTatr(src, xml, ocr = "never", quiet = TRUE),
               "readable cells")
})

test_that("parseBaselineTable falls back to TATR when the text engine fails", {
  src <- syntheticPdfMeanSD()
  g <- meanSDGeometry()
  xml <- tatrXmlFor(tempfile(fileext = ".tatr.xml"), 1L, g$rows, g$cols, g$cells)
  direct <- parseBaselineTableHeuristics(src, quiet = TRUE)
  testthat::local_mocked_bindings(
    parseBaselineTableHeuristics = function(...) stop("no usable table in the text layer"))
  r <- parseBaselineTable(src, ai = "never", tatrXml = xml, quiet = TRUE)
  expect_identical(r$engine, "heuristic-tatr")
  expect_true(any(grepl("Table Transformer", r$flags)))
  expect_equal(srt(r$data), srt(direct$data), ignore_attr = TRUE)
  # tatr = "never" leaves the failure as it was
  expect_error(parseBaselineTable(src, ai = "never", tatr = "never", tatrXml = xml,
                                  quiet = TRUE), "no usable table")
  # and without an XML, on a machine with no model, nothing changes either
  testthat::local_mocked_bindings(.ppTatrAvailable = function() FALSE)
  expect_error(parseBaselineTable(src, ai = "never", quiet = TRUE), "no usable table")
})

test_that("with the text engine happy, TATR is consulted only on request", {
  src <- syntheticPdfMeanSD()
  g <- meanSDGeometry()
  xml <- tatrXmlFor(tempfile(fileext = ".tatr.xml"), 1L, g$rows, g$cols, g$cells)
  calls <- 0L
  testthat::local_mocked_bindings(
    parseBaselineTableTatr = function(...) { calls <<- calls + 1L; stop("should not run") })
  r <- parseBaselineTable(src, ai = "never", tatrXml = xml, quiet = TRUE)
  expect_identical(r$engine, "heuristic")
  expect_identical(calls, 0L)
})

test_that("a direct call removes the runner's work directory once the XML is consumed", {
  src <- syntheticPdfMeanSD()
  g <- meanSDGeometry()
  made <- NULL
  testthat::local_mocked_bindings(
    .ppTatrAvailable = function() TRUE,
    .ppTatrRun = function(pdfFile, timeout = 600, quiet = FALSE) {
      work <- tempfile("tatr"); dir.create(file.path(work, "xml"), recursive = TRUE)
      made <<- work
      tatrXmlFor(file.path(work, "xml", "upload.tatr.xml"), 1L, g$rows, g$cols, g$cells)
    },
    parseBaselineTableHeuristics = function(...) stop("no usable table in the text layer"))
  r <- parseBaselineTable(src, ai = "never", quiet = TRUE)
  expect_identical(r$engine, "heuristic-tatr")
  expect_false(is.null(made))
  expect_false(dir.exists(made))          # gone with the call, not the session
})

test_that("tatr = \"always\" keeps the model's provenance flags when it wins", {
  src <- syntheticPdfMeanSD()
  g <- meanSDGeometry()
  xml <- tatrXmlFor(tempfile(fileext = ".tatr.xml"), 1L, g$rows, g$cols, g$cells)
  # make the text engine's reading strictly worse than the model's
  weak <- parseBaselineTableHeuristics(src, quiet = TRUE)
  weak$data <- weak$data[weak$data$ROW == "Age", ]
  weak$arms$N[] <- NA
  testthat::local_mocked_bindings(parseBaselineTableHeuristics = function(...) weak)
  r <- parseBaselineTable(src, ai = "never", tatr = "always", tatrXml = xml, quiet = TRUE)
  expect_identical(r$engine, "heuristic-tatr")
  expect_true(any(grepl("Table Transformer", r$flags)))
})

test_that("the runner is inert without the pegged Python, and discovers nothing", {
  # configuration only (screen F2): no home-directory or cwd discovery
  withr::local_envvar(INTEGRITY_TATR_PYTHON = NA, INTEGRITY_TATR_SCRIPT = NA,
                      INTEGRITY_ROOT = NA)
  expect_identical(.ppTatrPython(), "")
  expect_identical(.ppTatrScript(), "")
  expect_false(.ppTatrAvailable())
  expect_null(.ppTatrRun(syntheticPdfMeanSD(), quiet = TRUE))
  withr::local_envvar(INTEGRITY_TATR_PYTHON = file.path(tempdir(), "no-such-python"))
  expect_identical(.ppTatrPython(), "")
})

test_that("the runner copies the upload under a fixed name and keeps to half the child's budget", {
  # Rscript stands in for the pegged Python: a fake tatrTables that checks
  # what it was handed and writes an XML where the runner will look
  fake <- tempfile(fileext = ".R")
  writeLines(c(
    'a <- commandArgs(trailingOnly = TRUE)',
    'lst <- a[which(a == "--list") + 1]; out <- a[which(a == "--out") + 1]',
    'stopifnot("--write-empty" %in% a, "--max-mem-mb" %in% a)',
    'row <- strsplit(readLines(lst), ",")[[1]]',
    'stopifnot(row[1] == "upload", basename(row[2]) == "upload.pdf", file.exists(row[2]))',
    'if (nzchar(Sys.getenv("FAKE_TATR_SLEEP"))) Sys.sleep(as.numeric(Sys.getenv("FAKE_TATR_SLEEP")))',
    'dir.create(out, showWarnings = FALSE)',
    'writeLines(\'<?xml version="1.0"?><tatr-tables render-dpi="150"></tatr-tables>\', file.path(out, "upload.tatr.xml"))'),
    fake)
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  withr::local_envvar(INTEGRITY_TATR_PYTHON = rscript, INTEGRITY_TATR_SCRIPT = fake,
                      INTEGRITY_PARSE_BUDGET = NA, FAKE_TATR_SLEEP = NA)
  expect_true(.ppTatrAvailable())
  src <- file.path(tempdir(), "Table 1, revised.pdf")   # the F5 filename
  file.copy(syntheticPdfMeanSD(), src, overwrite = TRUE)
  xml <- .ppTatrRun(src, quiet = TRUE)
  expect_false(is.null(xml))
  expect_identical(basename(xml), "upload.tatr.xml")
  expect_length(.ppReadTatr(xml), 0L)
  # the budget: half of the child's, and a run past it returns NULL -
  # and a failed run removes its own work directory (CodeRabbit on #147)
  before <- list.files(tempdir(), pattern = "^tatr")
  withr::local_envvar(INTEGRITY_PARSE_BUDGET = "4", FAKE_TATR_SLEEP = "6")
  expect_null(.ppTatrRun(src, quiet = TRUE))
  expect_identical(setdiff(list.files(tempdir(), pattern = "^tatr"), before), character(0))
  # ...as does a run whose upload cannot even be copied
  expect_null(.ppTatrRun(file.path(tempdir(), "no-such.pdf"), quiet = TRUE))
  expect_identical(setdiff(list.files(tempdir(), pattern = "^tatr"), before), character(0))
})

test_that("a page too large to rasterise is skipped before OCR, not rendered", {
  skip_if_not_installed("tesseract")
  # a 200 x 200 inch page: 3.6 gigapixels at 300 dpi, which is exactly the
  # bitmap the cap exists to refuse (screen F1)
  big <- file.path(tempdir(), "huge.pdf")
  grDevices::pdf(big, width = 200, height = 200)
  graphics::plot.new(); graphics::text(0.5, 0.5, "Table 1")
  grDevices::dev.off()
  expect_length(.ppOcrData(big), 0L)
  expect_identical(.ppOcrPages(big, want = "text"), character(0))
  # an ordinary page is untouched
  expect_true(nrow(.ppOcrData(syntheticPdfMeanSD())[[1]]) > 10)
})

test_that("the batch runner leaves no child temporary directory behind", {
  before <- list.files(tempdir(), pattern = "^child")
  res <- parseBaselineTableFiles(syntheticPdfMeanSD(), ai = "never", timeout = 60, quiet = TRUE)
  expect_true(res$ok[1])
  after <- list.files(tempdir(), pattern = "^child")
  expect_identical(setdiff(after, before), character(0))
  # and the parent's own environment is restored
  expect_false(nzchar(Sys.getenv("INTEGRITY_PARSE_BUDGET")))
})
