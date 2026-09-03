# JATS/XML input (issue 29).
#
# The assertions that matter are the two the .docx path did not need:
# ROWSPAN carry-over, because JATS omits the continuation cell entirely
# and silent column drift would follow; and the SECURITY pair, because
# XML can attack a parser in ways a PDF cannot.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast)
  library(dqrng)
}))

tmp <- function(ext = ".xml") tempfile(fileext = ext)

# ---- the matrix: spans -------------------------------------------------

test_that("rowspan carries forward so later columns do not shift left", {
  # Row 2 has only THREE cells because column 1 is still covered by the
  # rowspan above it. Read naively, "31" would land in column 1 and
  # every value would be attributed to the wrong arm. This is the
  # failure mode measured in 36% of real PMC tables.
  f <- makeJatsArticle(tmp(), list(list(
    caption = "Baseline characteristics",
    rows = list(c("",       "Drug (n = 40)", "Placebo (n = 40)", "P"),
                c("Sex",    "M",             "F",                "0.4"),
                c(          "30",            "31",               "0.5"),
                c("Age",    "60",            "61",               "0.6")),
    spans = list(NULL, c(NA, NA, NA, NA), NULL, NULL))))
  # give "Sex" a rowspan of 2 so row 3 legitimately has one fewer cell
  x <- readLines(f, warn = FALSE)
  x <- sub('<td colspan="1" rowspan="1">Sex</td>',
           '<td colspan="1" rowspan="2">Sex</td>', x, fixed = TRUE)
  writeLines(x, f, useBytes = TRUE)

  d <- IntegrityAnalysis:::.ppJatsData(f)
  m <- d$tables[[1]]$cells
  expect_equal(ncol(m), 4)
  # The carried column is BLANK on the continuation row...
  expect_identical(m[3, 1], "")
  # ...and the numbers stay in the columns they were written in.
  expect_identical(m[3, 2], "30")
  expect_identical(m[3, 3], "31")
  expect_identical(m[3, 4], "0.5")
})

test_that("colspan replicates only when it carries an arm size", {
  f <- makeJatsArticle(tmp(), list(list(
    caption = "Baseline characteristics",
    rows = list(c("", "Drug (n = 40)", "Comparison"),
                c("Age", "60", "61")),
    spans = list(c(NA, "c2", "c2"), NULL))))
  m <- IntegrityAnalysis:::.ppJatsData(f)$tables[[1]]$cells
  # the arm-size header is repeated across its span, so both spanned
  # columns keep their N ...
  expect_identical(m[1, 2], "Drug (n = 40)")
  expect_identical(m[1, 3], "Drug (n = 40)")
  # ... while a plain spanned header leaves the extra column empty.
  expect_identical(m[1, 4], "Comparison")
  expect_identical(m[1, 5], "")
})

# ---- captions and footnotes, as real publishers write them -------------

test_that("caption comes from label plus caption/p, footnotes from the foot", {
  f <- makeJatsArticle(tmp(), list(list(
    label = "Table 2.", caption = "Baseline characteristics by group",
    rows = list(c("", "A (n = 10)"), c("Age", "50")),
    foot = c("Values are mean (SD).", "SD = standard deviation."))))
  t1 <- IntegrityAnalysis:::.ppJatsData(f)$tables[[1]]
  expect_true(grepl("Table 2", t1$caption))
  expect_true(grepl("Baseline characteristics by group", t1$caption))
  expect_length(t1$footnotes, 2)
  expect_true(any(grepl("mean \\(SD\\)", t1$footnotes)))
})

# ---- end to end ---------------------------------------------------------

test_that("a JATS baseline table parses end to end", {
  f <- makeJatsArticle(tmp(), list(list(
    caption = "Baseline characteristics of the randomised groups",
    rows = list(c("",       "Drug (n = 40)", "Placebo (n = 40)"),
                c("Age",    "61.2 (10.1)",   "59.8 (11.4)"),
                c("Weight", "78.4 (14.2)",   "79.1 (13.6)"),
                c("BMI",    "27.1 (4.4)",    "26.8 (4.9)")),
    foot = "Values are mean (SD).")),
    prose = "Participants were randomly assigned to two groups.")
  r <- parseBaselineTableJats(f, quiet = TRUE)
  expect_s3_class(r, "ParsePDFTable")
  expect_identical(r$layout, "jats")
  expect_identical(r$engine, "heuristic-jats")
  expect_equal(nrow(r$arms), 2)
  expect_setequal(unique(r$data$ROW), c("Age", "Weight", "BMI"))
  expect_equal(r$data$MEAN[r$data$ROW == "Age"], c(61.2, 59.8))
  expect_equal(r$data$SD[r$data$ROW == "Age"], c(10.1, 11.4))
  expect_equal(r$data$N[r$data$ROW == "Age"], c(40, 40))
})

test_that("the .xml extension dispatches without touching parseOne", {
  f <- makeJatsArticle(tmp(), list(list(
    caption = "Baseline characteristics",
    rows = list(c("", "A (n = 20)", "B (n = 20)"),
                c("Age", "50.0 (5.0)", "51.0 (6.0)")))))
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(r$engine, "heuristic-jats")
})

test_that("a document with no table says so, rather than failing obscurely", {
  f <- tmp()
  writeLines('<?xml version="1.0"?><article><body><p>No tables here.</p></body></article>',
             f, useBytes = TRUE)
  expect_error(parseBaselineTableJats(f, quiet = TRUE), "table-wrap")
})

# ---- security: the two attacks a PDF cannot carry ----------------------

test_that("a billion-laughs bomb cannot exhaust memory", {
  f <- makeBillionLaughs(tmp())
  # libxml2 caps entity expansion unless HUGE is set. Either it errors,
  # or it returns without the expansion - both are safe. What must NOT
  # happen is a gigabyte of "lol" and a dead session, so this is also a
  # timing assertion: the bomb resolves in well under a second.
  t0 <- Sys.time()
  res <- tryCatch(IntegrityAnalysis:::.ppJatsRead(f), error = function(e) "refused")
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  expect_lt(elapsed, 10)
  if (!identical(res, "refused")) {
    txt <- xml2::xml_text(res)
    expect_lt(nchar(txt), 1e6)   # not the ~3 GB the bomb intends
  }
  expect_true(TRUE)
})

test_that("XXE cannot read a local file into the parsed output", {
  secret <- tempfile(fileext = ".txt")
  writeLines("TOPSECRET-CANARY-VALUE", secret)
  f <- makeXxe(tmp(), secret)
  res <- tryCatch(IntegrityAnalysis:::.ppJatsRead(f), error = function(e) NULL)
  if (!is.null(res)) {
    # The canary must not appear anywhere in the document text.
    expect_false(grepl("TOPSECRET-CANARY-VALUE", xml2::xml_text(res)))
  }
  # And it must not reach a parsed table either.
  out <- tryCatch(parseBaselineTableJats(f, quiet = TRUE),
                  error = function(e) NULL)
  if (!is.null(out))
    expect_false(any(grepl("TOPSECRET-CANARY-VALUE",
                           unlist(lapply(out$data, as.character)))))
})

test_that("the reader passes only the safe libxml2 options", {
  # A source-level assertion, because the danger is a future edit adding
  # HUGE to get past a "document too large" complaint. Mirrored by a
  # tripwire in tools/securityCheck.R.
  f <- "../../R/parseJats.R"
  skip_if_not(file.exists(f), "source not reachable from the test dir")
  # COMMENTS ONLY ARE STRIPPED FIRST. The header of parseJats.R names
  # all three options at length, explaining why they must never be
  # passed - so a naive grep over the whole file matches its own
  # documentation and fails. The assertion is about CODE.
  code <- sub("#.*$", "", readLines(f, warn = FALSE))
  code <- paste(code, collapse = "\n")
  expect_false(grepl("HUGE", code))
  expect_false(grepl("NOENT", code))
  expect_false(grepl("DTDLOAD", code))
  expect_false(grepl("DTDVALID", code))
  expect_false(grepl("DTDATTR", code))
  expect_false(grepl("XINCLUDE", code))
  # And the one call that does exist passes the safe option explicitly -
  # on BYTES, never a path (screen of PR #162: libxml2's file reader
  # inflates a gzip stream named .xml; its memory parser never does).
  expect_true(grepl('read_xml\\(bytes, options = "NOBLANKS"\\)', code))
  expect_false(grepl('read_xml\\(file', code))
})

# ---- security: the bounds the screen of PR #162 asked for (2026-09-03) ----

test_that("a gzip stream named .xml is refused by name, fast, without inflation", {
  f <- tmp()
  con <- gzfile(f, "wb")
  # 40 MB of XML in a ~40 KB gzip: what libxml2's file reader would have
  # inflated into a multi-gigabyte DOM
  writeLines(c("<article><body>", rep("<b/>", 10000000), "</body></article>"), con)
  close(con)
  expect_lt(file.size(f), 200000)
  ok <- IntegrityAnalysis:::.ppJatsOK(f)
  expect_false(isTRUE(ok))
  expect_match(attr(ok, "reason"), "gzip")
  t0 <- Sys.time()
  expect_error(IntegrityAnalysis:::.ppJatsRead(f), "gzip")
  expect_error(parseBaselineTableJats(f, quiet = TRUE), "gzip")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
})

test_that("a JATS file over the ceiling is refused before it is read", {
  f <- tmp()
  con <- file(f, "wb")
  writeLines(c("<article><body>", rep("<p>padding padding padding padding padding padding</p>", 200000),
               "</body></article>"), con)
  close(con)
  expect_gt(file.size(f), IntegrityAnalysis:::.ppJatsMaxBytes)
  ok <- IntegrityAnalysis:::.ppJatsOK(f)
  expect_false(isTRUE(ok))
  expect_match(attr(ok, "reason"), "MiB")
  expect_error(IntegrityAnalysis:::.ppJatsRead(f), "MiB")
})

test_that("an author's colspan or rowspan cannot size the matrix", {
  f <- tmp()
  writeLines(c(
    '<article><body><table-wrap><label>Table 1</label><caption><p>Baseline</p></caption><table>',
    '<tr><td></td><td colspan="100000000">Control (n = 40)</td><td>Treatment (n = 42)</td></tr>',
    '<tr><td rowspan="100000000">Age</td><td>61 (10)</td><td>60 (11)</td></tr>',
    '</table></table-wrap></body></article>'), f)
  t0 <- Sys.time()
  d <- IntegrityAnalysis:::.ppJatsData(f)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
  m <- d$tables[[1]]$cells
  expect_lte(ncol(m), IntegrityAnalysis:::.ppMaxCellSpan + 2L)
  expect_equal(nrow(m), 2L)
})

test_that("nested paragraphs and rows do not multiply the text (second screen of #162)", {
  # 250 nested <p> around a 3 MB leaf: the descendant axis used to put
  # every ancestor's text - each containing the leaf - into fullText
  # (1.25 GB of characters from a 5 MB file). Outermost nodes only, and
  # a clip and a budget on top.
  f <- tmp()
  leaf <- paste(rep("x", 3000000), collapse = "")
  open <- paste0(vapply(1:250, function(i) sprintf("<p>%d", i), character(1)), collapse = "")
  close <- paste(rep("</p>", 250), collapse = "")
  writeLines(c("<article><body>", open, leaf, close, "</body></article>"), f)
  t0 <- Sys.time()
  d <- IntegrityAnalysis:::.ppJatsData(f)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  expect_lte(sum(nchar(d$fullText)), IntegrityAnalysis:::.ppMaxParaChars)
  # an internal entity referenced many times inside the nesting used to be
  # bounded by the budget; since the third screen a declared entity is
  # refused before any parse (see the "declared entity" test below)
  g <- tmp()
  writeLines(c('<!DOCTYPE article [<!ENTITY e "', paste(rep("y", 400000), collapse = ""), '">]>',
               "<article><body>", open, paste(rep("&e;", 5), collapse = " "), close,
               "</body></article>"), g)
  expect_error(IntegrityAnalysis:::.ppJatsData(g), "entity")
  # rows nested inside a cell are that cell's text, not more rows
  h <- tmp()
  inner <- paste(rep("<tr><td>", 120), collapse = "")
  writeLines(c("<article><body><table-wrap><table><tr><td>a</td><td>", inner,
               paste(rep("z", 100000), collapse = ""), paste(rep("</td></tr>", 120), collapse = ""),
               "</td></tr><tr><td>b</td><td>2</td></tr></table></table-wrap></body></article>"), h)
  t0 <- Sys.time()
  d3 <- IntegrityAnalysis:::.ppJatsData(h)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  m <- d3$tables[[1]]$cells
  expect_equal(nrow(m), 2L)
  expect_lte(max(nchar(m)), IntegrityAnalysis:::.ppMaxCellChars)
})

test_that("nested caption titles, a declared entity, and a wide row are bounded (third screen of #162)", {
  # 250 nested <title> around a 1 MB leaf inside a caption: the <title>
  # branch lacked the outermost-node guard the <p> branch had
  f <- tmp()
  leaf <- paste(rep("x", 1000000), collapse = "")
  open <- paste(rep("<title>", 250), collapse = ""); close <- paste(rep("</title>", 250), collapse = "")
  writeLines(c("<article><body><table-wrap><label>Table 1</label><caption>", open, leaf, close,
               "</caption><table><tr><td>a</td><td>1</td></tr><tr><td>b</td><td>2</td></tr></table></table-wrap></body></article>"), f)
  t0 <- Sys.time()
  d <- IntegrityAnalysis:::.ppJatsData(f)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  expect_lte(nchar(d$tables[[1]]$caption), IntegrityAnalysis:::.ppMaxParaChars + 20L)
  # an internal entity declaration is refused by name, before any parse:
  # no real JATS article declares one (0 of the corpus's 10,108)
  g <- tmp()
  writeLines(c('<!DOCTYPE article [<!ENTITY e "', paste(rep("y", 100000), collapse = ""), '">]>',
               "<article><body><p>", paste(rep("&e;", 4), collapse = " "), "</p></body></article>"), g)
  ok <- IntegrityAnalysis:::.ppJatsOK(g)
  expect_false(isTRUE(ok))
  expect_match(attr(ok, "reason"), "entity")
  expect_error(IntegrityAnalysis:::.ppJatsRead(g), "entity")
  # a row of 200 cells of 500 words is capped at .ppMaxLineWords words
  m <- matrix(paste(rep("1", 500), collapse = " "), nrow = 2, ncol = 200)
  t0 <- Sys.time()
  ln <- IntegrityAnalysis:::.ppDocxLines(m)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  expect_true(all(vapply(ln$lines, nrow, integer(1)) <= IntegrityAnalysis:::.ppMaxLineWords))
})

test_that("a five-megabyte cell of one-character words does not stall the word adapter", {
  txt <- paste(rep("a", 2500000), collapse = " ")
  t0 <- Sys.time()
  ln <- IntegrityAnalysis:::.ppDocxTextLine(txt, 0)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
  expect_lte(nrow(ln), IntegrityAnalysis:::.ppMaxLineWords)
  # and a real cell still becomes the same words at the same places
  ln2 <- IntegrityAnalysis:::.ppDocxTextLine("Control (n = 40)", 0, x0 = 12)
  expect_identical(ln2$text, c("Control", "(n", "=", "40)"))
  expect_equal(ln2$x, 12 + c(0, 48, 66, 78))
})

test_that("a wall of table-wraps and a table wider than any baseline table are bounded", {
  f <- tmp()
  one <- '<table-wrap><table><tr><td>a</td><td>1</td></tr><tr><td>b</td><td>2</td></tr></table></table-wrap>'
  writeLines(c("<article><body>", rep(one, 500), "</body></article>"), f)
  d <- IntegrityAnalysis:::.ppJatsData(f)
  expect_lte(length(d$tables), IntegrityAnalysis:::.ppMaxTableWraps)
  # 400 real cells in one row: wider than a table the engine reads
  g <- tmp()
  writeLines(c("<article><body><table-wrap><table><tr>",
               rep("<td>x</td>", 400), "</tr><tr>", rep("<td>1</td>", 400),
               "</tr></table></table-wrap></body></article>"), g)
  expect_length(IntegrityAnalysis:::.ppJatsData(g)$tables, 0L)
})

# ---- fourth screen of PR #162 ---------------------------------------------

test_that("a UTF-16 file cannot hide a declared entity from the byte gate (fourth screen of #162)", {
  # the same document that is refused as UTF-8 passed the ASCII search
  # as UTF-16, because every letter is followed by a NUL
  doc <- paste0('<?xml version="1.0"?><!DOCTYPE article [<!ENTITY z "',
                strrep("z", 1000), '">]><article><body><p>',
                strrep("&z;", 400), '</p></body></article>')
  f8 <- tmp(); writeBin(charToRaw(doc), f8)
  ok <- IntegrityAnalysis:::.ppJatsOK(f8)
  expect_false(isTRUE(ok)); expect_match(attr(ok, "reason"), "ENTITY")
  f16 <- tmp()
  writeBin(c(as.raw(c(0xff, 0xfe)), iconv(doc, "UTF-8", "UTF-16LE", toRaw = TRUE)[[1]]), f16)
  expect_false(any(grepRaw("<!ENTITY", readBin(f16, "raw", file.size(f16)), fixed = TRUE)))
  ok <- IntegrityAnalysis:::.ppJatsOK(f16)
  expect_false(isTRUE(ok)); expect_match(attr(ok, "reason"), "NUL")
  expect_error(IntegrityAnalysis:::.ppJatsRead(f16), "NUL")
  # a UTF-8 BOM and leading whitespace are fine; anything else in front
  # of the first "<" is not XML markup
  fb <- tmp(); writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("\n  <article><body><p>x</p></body></article>")), fb)
  expect_true(isTRUE(IntegrityAnalysis:::.ppJatsOK(fb)))
  fe <- tmp(); writeBin(charToRaw("MZ<article/>"), fe)
  ok <- IntegrityAnalysis:::.ppJatsOK(fe)
  expect_false(isTRUE(ok)); expect_match(attr(ok, "reason"), "begin")
  fw <- tmp(); writeBin(charToRaw("   \n\t "), fw)
  expect_false(isTRUE(IntegrityAnalysis:::.ppJatsOK(fw)))
})

test_that("cells are counted before any is built, per table and per document", {
  # 300 rows x 100 columns = 30,000 cells: under the row and column caps,
  # over the per-table cell cap, so the matrix is never built
  big <- c('<table-wrap><label>Table 9</label><caption><p>Supplement</p></caption><table>',
           rep(paste0("<tr>", strrep("<td>1</td>", 100), "</tr>"), 300),
           '</table></table-wrap>')
  small <- c('<table-wrap><label>Table 1</label><caption><p>Baseline characteristics</p></caption><table>',
             '<tr><td></td><td>Control (n = 40)</td><td>Treatment (n = 42)</td></tr>',
             '<tr><td>Age (yr)</td><td>61 (10)</td><td>60 (11)</td></tr>',
             '<tr><td>Weight (kg)</td><td>80 (12)</td><td>79 (13)</td></tr>',
             '</table></table-wrap>')
  f <- tmp()
  writeLines(c("<article><body>", big, small, "</body></article>"), f)
  tw <- xml2::xml_find_first(IntegrityAnalysis:::.ppJatsRead(f), "//table-wrap")
  expect_null(IntegrityAnalysis:::.ppJatsMatrix(tw))
  t0 <- Sys.time()
  d <- IntegrityAnalysis:::.ppJatsData(f)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
  expect_equal(length(d$tables), 1L)      # the big one was skipped, the real one read
  expect_equal(as.integer(attr(d$tables[[1]]$cells, "cells")), 9L)
  r <- parseBaselineTableJats(f, quiet = TRUE)
  expect_equal(sort(unique(r$data$ROW)), c("Age", "Weight"))
  # the document budget: many tables each under the per-table cap stop
  # being read once their cells exceed .ppMaxDocCells
  mid <- c('<table-wrap><label>Table 2</label><caption><p>More</p></caption><table>',
           rep(paste0("<tr>", strrep("<td>1</td>", 50), "</tr>"), 100),
           '</table></table-wrap>')                       # 5,000 cells each
  f2 <- tmp()
  writeLines(c("<article><body>", rep(mid, 40), "</body></article>"), f2)   # 200,000 cells
  d2 <- IntegrityAnalysis:::.ppJatsData(f2)
  expect_lte(length(d2$tables), IntegrityAnalysis:::.ppMaxDocCells %/% 5000L + 1L)
})

test_that("a body of empty paragraphs is capped by count, and the adapter runs only for tried tables", {
  f <- tmp()
  writeLines(c("<article><body>",
               '<table-wrap><label>Table 1</label><caption><p>Baseline characteristics</p></caption><table>',
               '<tr><td></td><td>Control (n = 40)</td><td>Treatment (n = 42)</td></tr>',
               '<tr><td>Age (yr)</td><td>61 (10)</td><td>60 (11)</td></tr>',
               '</table></table-wrap>',
               rep("<p/>", 60000), "<p>Patients were randomized 1:1.</p>",
               "</body></article>"), f)
  t0 <- Sys.time()
  d <- IntegrityAnalysis:::.ppJatsData(f)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  expect_lte(length(d$fullText), IntegrityAnalysis:::.ppMaxBodyParas)
  # candidates carry cells, not adapted lines: the adapter is deferred
  r <- parseBaselineTableJats(f, quiet = TRUE)
  expect_equal(unique(r$data$ROW), "Age")
  # ...and a document whose only table adapts to nothing still says so
  fn <- tmp()
  writeLines(c("<article><body>",
               '<table-wrap><table><tr><td>a</td></tr><tr><td>b</td></tr></table></table-wrap>',
               "</body></article>"), fn)
  expect_error(parseBaselineTableJats(fn, quiet = TRUE), "usable")
})
