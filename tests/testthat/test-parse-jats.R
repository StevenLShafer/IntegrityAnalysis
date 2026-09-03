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
  # an internal entity referenced many times inside the nesting: the
  # budget bounds it whatever the XPath says
  g <- tmp()
  writeLines(c('<!DOCTYPE article [<!ENTITY e "', paste(rep("y", 400000), collapse = ""), '">]>',
               "<article><body>", open, paste(rep("&e;", 5), collapse = " "), close,
               "</body></article>"), g)
  t0 <- Sys.time()
  d2 <- IntegrityAnalysis:::.ppJatsData(g)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  expect_lte(sum(nchar(d2$fullText)), IntegrityAnalysis:::.ppJatsMaxTextChars)
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
