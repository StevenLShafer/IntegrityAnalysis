# parseWideTable.R - read a journal-style WIDE baseline table as input
# (ISSUES.md issue 17).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-21,
# at Steve Shafer's request; reviewed against R/baselineTable.R (the
# generator this file inverts) and R/parseBaselineTableHeuristics.R (the
# PDF engine whose cell semantics it mirrors). Verified by the round-trip
# suite in tests/testthat/test-wide-table.R.
#
# The app's long "template" format (one line per variable per arm, columns
# N / MEAN / SD ...) is nobody's native habitat: editors have the
# manuscript's Table 1, and this app itself GENERATES a journal-style
# reconstruction of it (buildBaselineTables(), the Editor's View
# download). Steve's design for this feature: that generated table must
# be valid INPUT - download the Editor's View, feed it back, and the
# analysis reproduces. So the acceptance test is a round trip, pinned in
# test-wide-table.R, and R/baselineTable.R is the format's canonical
# specification. The parser is deliberately more tolerant than the
# generator, though (Steve, 2026-08-21): arbitrary real-world arm headers
# ("Control (n=50)", "Treatment") and untagged labels also parse, using
# the same cell-content rules as the PDF engine.
#
# What this file does NOT do:
#   - It never guesses between an IQR and a min-max range. A bracketed
#     interval is emitted as Q1/Q3 only when the row label SAYS it is an
#     IQR ("median [Q1, Q3]", "median (IQR)"); a label saying "range", or
#     saying nothing, sends the row to $skipped with a reason. Both
#     interval kinds straddle the median, so text is the only evidence -
#     and a wrong guess here would feed a fraud-screening verdict.
#   - Fractions ("15/10") and percent-only cells are skipped with
#     reasons; the full machinery for those lives in the PDF engine and
#     was not duplicated for v1.
#   - Mean and SD in SEPARATE columns is the template format, not this
#     one; such sheets are vetoed by .wideHeaderRow and flow to
#     validateData() unchanged.
#
# Rounding note: a spreadsheet cell that Excel typed as a NUMBER prints
# "12.1" even if the author formatted it "12.10", so printed-precision
# recovery is exact only for TEXT cells. Everything this app generates is
# written as text, so the round trip is unaffected.

# The template's own column names. A sheet whose header row contains two
# or more of these as whole cells is the LONG template format (or the
# results workbook's Test Results sheet) and must NOT be read as a wide
# table - validateData()'s substring grep is the right reader for it.
.wideTemplateNames <- c("TRIAL", "ROW", "N", "MEAN", "SD", "SE")

# SECURITY (2026-09-05, an outside reviewer's reproduction): a 6 KB
# workbook with one cell at row 400,000, column 2,000 passes the
# decompression preflight (19 KB declared) and then expands, in the
# reader that keeps empty rows and columns, to a 400,000 x 2,000 table -
# 3.2 GB in 19 seconds - before any row or column gate runs. Every
# spreadsheet read is now bounded to these caps FIRST: a sheet that
# reaches either cap is refused, not read. The caps are far above any
# baseline table (the API's gates are 5,000 rows and 200 columns).
.iaSheetRowCap <- 10000L
.iaSheetColCap <- 500L
.iaSheetCapMessage <- function(what = "sheet")
  paste0(what, " has more than ", .iaSheetRowCap, " rows or ",
         .iaSheetColCap, " columns and was not read")
# the CSV column count: the MAXIMUM over every line (screen 2026-09-05-2117
# F1: read.csv sizes a header = FALSE frame from its first five lines, so a
# two-field first line followed by four lines of 50,000 commas built a
# 10,001 x 50,001 frame past a first-line gate). count.fields is linear in
# the file, which the upload cap bounds. An unbalanced quote makes it NA
# (F5): NA refuses.
.iaCsvColumns <- function(path) {
  # comment.char = "": count.fields treats "#" as a comment by default and
  # read.csv does not, so a wide line opening with "#" was invisible to
  # the gate and built by the reader (screen 2026-09-06-1118 F1)
  n <- suppressWarnings(utils::count.fields(path, sep = ",", quote = "\"", comment.char = "",
                                            blank.lines.skip = TRUE))
  if (!length(n)) return(0L)
  if (anyNA(n)) return(NA_integer_)
  max(n)
}
.iaCsvTooWide <- function(path) {
  n <- .iaCsvColumns(path)
  is.na(n) || n > .iaSheetColCap
}
# THE LENGTH OF A LINE IS GATED BEFORE read.csv SEES IT (security screen
# 2026-09-10-1856, F2 - HIGH). read.table() sizes a header = FALSE frame
# from its first five lines and is QUADRATIC in the length of any of them:
# one field of 1 MB on line 2 - three fields, so the column gate passes it
# - took 107 s on this machine, a 25 MiB line about eighteen hours, before
# any of the bounds that follow the read. Every CSV route (the wide
# reader, the API's template read, the app's) paid it. readLines() is
# linear (0.02 s a megabyte), so the first five physical lines are
# measured in bytes first; 100 KB is five times the widest sheet the
# column cap admits (500 columns x 40 characters), and a quoted field
# spanning lines cannot hide behind it because count.fields() returns NA
# for the continuation lines and .iaCsvColumns refuses NA.
.iaCsvMaxLineBytes <- 100000L
# EVERY line is measured, not the first five (security screen
# 2026-09-10-2004, F1): read.table() counts its five sizing lines among
# the NON-EMPTY ones, so one empty first line put physical line 6 among
# them and past a five-line gate (400 KB there: 16 s, the quadratic curve
# intact). readLines() over the whole file is linear (0.02 s a megabyte)
# and, with the compressed-stream refusal below, bounded in memory by the
# on-disk cap; the measure also bounds every later line, which nothing
# bounded before.
# ...and measured as a STREAM of bytes (security screen 2026-09-10-2047,
# F1 and F4): readLines() over the file held a pointer per line - 25 MiB
# of newline bytes alone was 550 MB - and opened the file through
# file() in text mode, which inflates every compressed format R knows
# (the magic list below is R's, and R's list grows by version: zstd
# arrived in 4.5.0). file(path, "rb") does not inflate, readBin() in
# fixed chunks holds one chunk, and the longest run between newline
# bytes is the longest line: constant memory, linear time, immune to
# inflation whatever the bytes are.
.iaCsvLongLine <- function(path) {
  con <- file(path, "rb"); on.exit(close(con))
  run <- 0L
  repeat {
    chunk <- readBin(con, "raw", n = 2^18)
    if (!length(chunk)) break
    nl <- which(chunk == as.raw(0x0a))
    if (!length(nl)) {
      run <- run + length(chunk)
    } else {
      # the run that ends at the first newline, the runs between, the tail
      longest <- max(run + nl[1] - 1L, if (length(nl) > 1L) max(diff(nl)) - 1L else 0L)
      if (longest > .iaCsvMaxLineBytes) return(TRUE)
      run <- length(chunk) - nl[length(nl)]
    }
    if (run > .iaCsvMaxLineBytes) return(TRUE)
  }
  run > .iaCsvMaxLineBytes
}
# A COMPRESSED STREAM NAMED .csv IS REFUSED BY ITS BYTES (security screen
# 2026-09-10-2004, F2). R's file() in text mode detects gzip, bzip2 and
# xz magic and inflates transparently whatever the file is called, so
# every CSV reader on every route - count.fields(), readLines(),
# read.csv() - read the DECOMPRESSED stream while the request cap had
# bounded only the compressed bytes: a 388 KB gzip held a 400 MB line, a
# 146 KB xz a gigabyte (6,869:1), and a 25 MiB upload would be tens of
# gigabytes in one readLines() buffer before any gate could answer. The
# same vector was closed for JATS on 2026-09-03 (.ppJatsOK, libxml2's
# zlib) with a magic-byte check; this is that check for CSV, read with
# readBin(), which does not inflate.
# The magics are R's own list (src/main/connections.c, R 4.5): gzip,
# bzip2, xz, LZMA-alone in both spellings R accepts, and zstd (screen
# 2026-09-10-2047, F1: the first three alone left zstd and LZMA - a 6 KB
# zstd holding a 200 MB line, 32,300:1 - to inflate inside the gate).
.iaCsvCompressed <- function(path) {
  b <- readBin(path, "raw", n = 6L)
  starts <- function(...) { m <- as.raw(c(...)); length(b) >= length(m) && identical(b[seq_along(m)], m) }
  if (starts(0x1f, 0x8b)) return("gzip")
  if (starts(0x42, 0x5a, 0x68)) return("bzip2")
  if (starts(0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00)) return("xz")
  if (starts(0x5d, 0x00, 0x00, 0x80, 0x00)) return("lzma")
  if (starts(0xff, 0x4c, 0x5a, 0x4d, 0x41, 0x00)) return("lzma")
  if (starts(0x28, 0xb5, 0x2f, 0xfd)) return("zstd")
  NULL
}
# The one reason a CSV is refused before it is read, or NULL: the callers
# (the wide reader, the API's and the app's template reads) stop with it.
# The order matters: the bytes are judged before any reader opens the
# file through file(), which would inflate a compressed stream.
.iaCsvRefusal <- function(path) {
  z <- .iaCsvCompressed(path)
  if (!is.null(z))
    return(paste0("the file is a ", z, " stream, not a CSV - decompress it first"))
  if (.iaCsvLongLine(path))
    return(paste0("the file has a line over ", round(.iaCsvMaxLineBytes / 1000),
                  " KB and was not read"))
  if (.iaCsvTooWide(path)) return(.iaSheetCapMessage("the file"))
  NULL
}
# a workbook with more sheets than this is refused: each sheet read inflates
# the archive again (screen 2026-09-05-2117 F2), so the cost is sheets x
# declared size, and a baseline-table workbook has a handful
.iaSheetCountCap <- 10L

# Read every sheet of `path` as a matrix of raw cell TEXT, untyped and
# headerless, named by sheet. Raw text matters twice: openxlsx's
# colNames = TRUE mangles header text ("Arm 1 (n = 20)" becomes
# "Arm.1.(n.=.20)"), and the stacked results-workbook layout carries
# "Trial: <id>" marker rows that are data here, not headers.
.wideRawCells <- function(path, ext) {
  toMat <- function(d) {
    if (is.null(d) || nrow(d) == 0 || ncol(d) == 0)
      return(matrix(character(0), nrow = 0, ncol = 0))
    m <- vapply(seq_len(ncol(d)), function(j) {
      x <- d[[j]]
      # keep numbers readable, not "45.299999999999997"
      if (is.numeric(x)) ifelse(is.na(x), "", format(x, trim = TRUE,
                                                     scientific = FALSE))
      else ifelse(is.na(x), "", as.character(x))
    }, character(nrow(d)))
    matrix(m, nrow = nrow(d))
  }
  capped <- function(d, what) {
    if (!is.null(d) && (nrow(d) > .iaSheetRowCap || ncol(d) > .iaSheetColCap))
      stop(.iaSheetCapMessage(what), call. = FALSE)
    d
  }
  if (ext == "csv") {
    msg <- .iaCsvRefusal(path)
    if (!is.null(msg)) stop(msg, call. = FALSE)
    d <- utils::read.csv(path, header = FALSE, colClasses = "character",
                         check.names = FALSE, nrows = .iaSheetRowCap + 1L)
    return(list(toMat(capped(d, "the file"))))
  }
  if (ext == "xlsx") {
    # the decompression preflight lives HERE, so every caller of the wide
    # reader is behind it - the app used to call this before its own
    # preflight (screen 2026-09-05-2117 F2)
    if (!.apiZipInflationOK(path, ext))
      stop("the workbook expands to more than ", round(.apiMaxUncompressed / 1024^2),
           " MB when decompressed and was not read", call. = FALSE)
    sheets <- openxlsx::getSheetNames(path)
    if (length(sheets) > .iaSheetCountCap)
      stop("the workbook has more than ", .iaSheetCountCap, " sheets and was not read", call. = FALSE)
    out <- lapply(sheets, function(s)
      toMat(capped(tryCatch(openxlsx::read.xlsx(path, sheet = s, colNames = FALSE,
                                                skipEmptyRows = FALSE,
                                                skipEmptyCols = FALSE,
                                                rows = seq_len(.iaSheetRowCap + 1L),
                                                cols = seq_len(.iaSheetColCap + 1L)),
                            error = function(e) NULL), paste("sheet", s))))
    names(out) <- sheets
    return(out)
  }
  # .xls: DROPPED (Steve, 2026-09-06, on security screen 2026-09-05-2117
  # F3). libxls parses a whole sheet and allocates its declared grid
  # before any row limit applies, so a few-KB file declaring row 65,535
  # x 256 cells costs ~800 MB per read inside the worker. Rather than
  # read it in a subprocess, the format is refused everywhere - every
  # spreadsheet program saves as .xlsx - and readxl has left the package.
  stop(.iaXlsMessage(), call. = FALSE)
}
.iaXlsMessage <- function() paste0("the old Excel format (.xls) is no longer accepted: its reader ",
                                   "builds a sheet's declared size before any limit can apply (a ",
                                   "security decision, 2026-09-06). Save the workbook as .xlsx")

# Find the wide table's header row in `cells` (a character matrix), or NA.
# Conservative on purpose: anything not confidently wide falls through to
# the app's existing spreadsheet path, whose failure mode (raw grid plus
# "Missing column labeled ..." comments) is the long-standing behavior.
#
# A row is the header when it has at least two non-empty cells past the
# label column AND either
#   (a) one of them carries an arm size "(n = 15)"  - the app's own
#       format always does - or
#   (b) the label cell is blank or a label word ("Variable",
#       "Characteristic", ...), every body cell is non-numeric (arm NAMES,
#       not data), and at least two of the following rows look like data
#       (a labelled row whose cells hold "mean (SD)" / "a ± b" /
#       "median [a, b]" values).
# The template veto above trumps everything.
.wideHeaderRow <- function(cells) {
  if (nrow(cells) == 0 || ncol(cells) < 3) return(NA_integer_)
  valuePat <- paste0("^[<>]?-?\\d[\\d.,·]*\\s*",
                     "(\\(\\s*-?\\d[\\d.,·]*\\s*%?\\s*\\)",
                     "|±\\s*\\d[\\d.,·]*",
                     "|\\[[^]]+\\])")
  for (r in seq_len(min(10L, nrow(cells)))) {
    row  <- cells[r, ]
    up   <- toupper(trimws(row))
    if (sum(up %in% .wideTemplateNames) >= 2) return(NA_integer_)  # veto
    body <- trimws(row[-1])
    body <- body[nzchar(body)]
    if (length(body) < 2) next
    if (any(grepl("(?i)\\(\\s*n\\s*=\\s*\\d", body, perl = TRUE)))
      return(r)
    labelish <- !nzchar(trimws(row[1])) ||
      grepl("(?i)^(variable|characteristic|parameter|outcome|item)s?$",
            trimws(row[1]), perl = TRUE)
    if (labelish && !any(grepl("^[<>]?-?[\\d.,·]+$", body))) {
      below <- seq(r + 1L, length.out = min(15L, nrow(cells) - r))
      evidence <- sum(vapply(below, function(rr)
        nzchar(trimws(cells[rr, 1])) &&
          any(grepl(valuePat, trimws(cells[rr, -1]), perl = TRUE)),
        logical(1)))
      if (evidence >= 2) return(r)
    }
  }
  NA_integer_
}

# --- label tags: the generator writes the row's statistical type into its
# label ("Age, mean (SD)"); real-world tables often do the same. Each tag
# regex both DETECTS the type and is stripped to recover the ROW label.
# Labels are otherwise kept verbatim (no .ppCleanLabel): unlike a PDF text
# line, a spreadsheet label is deliberate, and stripping units ("(kg)")
# would break the round trip against the validated frame it came from.
# the separator before a tag: comma/semicolon, or a dash - real tables
# write "Age (years)-Mean (SD)" and "Female sex-N(%)" (vocacapsaicin
# corpus, 2026-08-22)
.wideTagMeanSD  <- "(?i)[,;–—-]?\\s*mean\\s*(\\(\\s*sd\\s*\\)|±\\s*sd)?\\s*$"
.wideTagMedIQR  <- paste0("(?i)[,;–—-]?\\s*median\\s*[\\[(]\\s*",
                          "(q1\\s*[,;]?\\s*q3|iqr|interquartile[^\\])]*",
                          "|25th[^\\])]*)\\s*[\\])]\\s*$")
.wideTagMedRng  <- "(?i)[,;–—-]?\\s*median\\s*[\\[(][^\\])]*range[^\\])]*[\\])]\\s*$"
# Two shapes of the count tag. "Sex, n (%)" / "Sex, No. (%)" / "Sex, number
# (%)": a separator, the word, an optional "(%)". And the whole thing in
# one bracket, "Male (number, %)" / "Male (n, %)" / "Male (No. %)". The
# separator is MANDATORY in the first shape because a bare trailing "n"
# is the last letter of Hemoglobin. Steve's Ticagrelor sheet (2026-09-02)
# had "Male (number, %)": unrecognised, the whole label became the
# category column's name, and the app's column normalizer - which maps
# any name containing NUMBER to N - then collided it with the real N and
# refused the sheet before Analyze was ever offered.
.wideTagCat     <- paste0(
  "(?i)(?:[,;–—-]\\s*(?:number|no\\.?|n)(?:\\s*\\(\\s*%\\s*\\))?",
  "|\\s*\\(\\s*(?:number|no\\.?|n)\\s*[,;/]?\\s*%\\s*\\))\\s*$")

# One number, as the engine prints it (comma/middle-dot decimals,
# thousands separators, stray < >) - kept in sync with tokenize.R's .ppNUM.
.wideNUM <- "[<>]?-?\\d+(?:[.,·]\\d+)*"

# "median [Q1, Q3]" as a whole cell: three numbers, the outer two
# bracketed and separated by a comma/semicolon/dash/"to". The engine's
# medianRng token cannot see the comma-separated form (its separators are
# dashes and "to"), which is why this file carries its own pattern.
.wideMedianPat <- paste0("^(", .wideNUM, ")\\s*[\\[(]\\s*(", .wideNUM,
                         ")\\s*(?:[,;]|–|—|−|-|to)\\s*(",
                         .wideNUM, ")\\s*[\\])]$")

# Parse one trial block. `cells` is the block's matrix (header row
# included), `hdr` the header row index within it, `trial` the trial id
# (NA when the caller does not know - the server substitutes the file
# stem). Returns list(trial, data, arms, skipped), or NULL when no line
# parsed.
# THE WIDE READER IS BOUNDED BEFORE IT BUILDS (security screen
# 2026-09-10-1628, F1 - HIGH). Every count row of a journal-style table
# adds category columns named from the author's label, and every output
# line is a list the width of every column; nothing capped either, so a
# 23 KB sheet of 1,000 distinct "n (%)" rows built a 2,000 x 2,009 frame
# in 237 s on one thread, and a workbook of thousands of "Trial:" blocks
# (3,333 fit one sheet under the row cap) would have folded to a frame
# of billions of cells and killed the process for memory - every gate on
# the way in passed, because they measure bytes, sheets and rows, not
# what the reader makes of them. The bounds are the ones the API's
# analysis already applies (.iaMaxLevelColumns = .apiMaxCols for the
# category columns; .iaMaxWideLines = .apiMaxRows for the template
# lines), counted as the rows are classified and again across a file's
# blocks, and a table past them is refused with a reason BEFORE a line
# is built - by a classed condition both callers turn into a refusal
# rather than a fallback (a file the wide reader refuses is not read
# again as a template: the same sheet would cost the same).
.iaMaxWideLines <- 5000L   # template lines a journal-style file may become: .apiMaxRows
# A TRIAL ID IS CLIPPED AT ITS SOURCE (security screen 2026-09-10-2149,
# F1). The block clip covers the block matrix, not the "Trial:" marker
# row above it nor a sheet's name, and the id is copied into every line
# the block becomes: a marker of 99,990 bytes (under the line gate) over
# 2,500 two-arm rows was 5,000 lines of 100 KB - a 500 MB template from
# a 215 KB upload, held three times over on the way out. A trial id is
# tens of characters; 200 is generous.
.iaMaxTrialIdChars <- 200L
# THE WORK IS COUNTED, NOT ONLY THE OUTPUT (security screen 2026-09-10-1822,
# F1 and F2 - both HIGH). Every arm cell of every row goes through the
# tokenizer (about 1.3 ms a cell, a data frame per token) whether or not
# the row becomes a line, and the line and row bounds above see only
# rows that produce output: 200 rows of bare "1" cells under 499 arm
# headers - a 207 KB CSV, admitted by every cap - cost 134 s and counted
# zero lines; and ONE cell of 40,000 tokens cost 37 s (a cap-sized cell,
# hours). So a file has a budget of cells classified (.iaMaxWideCells,
# carried across its blocks and checked before each block by rows x
# arms and inside the loop as the cells are handed to the tokenizer),
# and a cell longer than .iaMaxWideCellChars (200; a baseline cell is
# under forty characters) refuses the file before it is tokenised.
.iaMaxWideCells <- 50000L  # arm cells a journal-style file may hand the tokenizer
# A cell of a journal-style table is a number or two ("45.3 (12.1)",
# "127 [98, 160]", "12 (40%)"): under forty characters. The JATS and Word
# readers' cap (.ppMaxCellChars, 2,000) admitted a thousand tokens a cell
# (screen 1856 F1), so the wide reader has its own, an order of magnitude
# tighter and still five times any real cell.
.iaMaxWideCellChars <- 200L
.wideCheckCells <- function(nCells)
  if (nCells > .iaMaxWideCells)
    .iaWideTooLarge(sprintf(paste("the journal-style table has %d cells to read (rows x arms,",
                                  "across the file); the limit is %d - a baseline table has",
                                  "a few hundred"), nCells, .iaMaxWideCells))
.wideNewTotals <- function()   # the file's running totals, shared by its blocks
  list2env(list(nLines = 0L, cols = character(0), nCells = 0L),
           envir = new.env(parent = emptyenv()))
.iaWideTooLarge <- function(msg)
  stop(structure(class = c("iaWideTooLarge", "error", "condition"),
                 list(message = msg, call = NULL)))
.wideCheckWidth <- function(catColumns)
  if (length(catColumns) > .iaMaxLevelColumns)
    .iaWideTooLarge(sprintf(paste("the journal-style table would need %d category columns",
                                  "(one per count level and its complement); the limit is %d -",
                                  "a baseline table's categorical variables have a handful of",
                                  "levels each"), length(catColumns), .iaMaxLevelColumns))
.wideCheckLines <- function(nLines)
  if (nLines > .iaMaxWideLines)
    .iaWideTooLarge(sprintf(paste("the journal-style table would become %d template lines",
                                  "(one per variable per arm); the limit is %d"),
                            nLines, .iaMaxWideLines))

# THE COST OF REACHING THE BOUNDS IS BOUNDED TOO (security screen
# 2026-09-10-1715, F1 and F2 - both HIGH). The 1628 fix placed the line
# bound AFTER the row loop and recomputed the file's totals over every
# block on every block, so the work of reaching a refusal was itself
# unbounded: 4,000 identical "Age, mean (SD)" rows took 141 s to be
# refused (.ppUniqueName tried "Age", "Age 2", ... "Age k" against a
# growing vector - cubic in the rows), and 6,666 one-line "Trial:" blocks
# took nine minutes (the totals summed over all blocks at every block -
# quadratic). Now the lines are counted as each row joins outRows and
# checked against the FILE's running total (linesBefore, colsBefore come
# in from the caller), row names are made unique through a hash set with
# a per-base hint (amortised constant), and the file's totals are carried
# forward rather than recomputed.
.wideParseBlock <- function(cells, hdr, trial, acc = .wideNewTotals()) {
  linesBefore <- acc$nLines          # the file's totals before this block
  colsBefore  <- acc$cols            # (the cell count is updated in place,
                                     # so a block that yields nothing still counts)
  # THE WHOLE BLOCK IS CLIPPED ON ENTRY, BY DECISION (security screens
  # 2026-09-10-2004 F3 and -2047 F3). Arm cells are capped at
  # .iaMaxWideCellChars; the labels and header cells were bounded only by
  # R's 10,000-byte symbol limit (a 10 KB label became 499 lines of
  # 10 KB); and the 2004 fix clipped column 1 and the header only, which
  # left the cells under a "Total" column - dropped from the arms below,
  # so never capped - to be pasted whole into the skip text of every row
  # (2,000 rows x 20 such columns of 30 KB: 1.3 GB). Every cell is
  # clipped to .ppMaxCellChars (2,000, the JATS and Word readers' cap; a
  # variable name with its units is under a hundred) before anything
  # reads it: one pass over the matrix, substr on the long cells only.
  cells[] <- .ppClip(cells, .ppMaxCellChars)
  header  <- cells[hdr, ]
  armCols <- which(vapply(seq_len(ncol(cells))[-1], function(j)
    nzchar(trimws(header[j])) ||
      any(nzchar(trimws(cells[-seq_len(hdr), j]))), logical(1))) + 1L
  if (length(armCols) == 0) return(NULL)
  nArms <- length(armCols)

  # Arm N from "(n = 15)" in the header; the remainder is the arm's name.
  # Bare names ("Treatment") leave N as NA - validation paints the gap.
  armN    <- rep(NA_real_, nArms)
  armName <- character(nArms)
  for (k in seq_len(nArms)) {
    h <- trimws(header[armCols[k]])
    m <- regmatches(h, regexec("(?i)n\\s*=\\s*(\\d[\\d,]*)", h,
                               perl = TRUE))[[1]]
    if (length(m) == 2) {
      armN[k] <- .ppAsNumeric(m[2])
      h <- trimws(sub("(?i)[,;]?\\s*\\(?\\s*n\\s*=\\s*\\d[\\d,]*\\s*\\)?",
                      "", h, perl = TRUE))
    }
    armName[k] <- if (nzchar(h)) h else paste("Arm", k)
  }

  # A "Total"/"Overall" column is arithmetic over the arms, not an arm;
  # analyzed as one it would corrupt the Monte Carlo (same rule, same
  # conservative patterns, as the engine's totals-column drop -
  # vocacapsaicin corpus, 2026-08-22).
  tot <- which(grepl(paste0("(?i)^(total|overall|all\\s+(patients|subjects|",
                            "participants)|entire\\s+cohort)$"),
                     trimws(armName), perl = TRUE))
  if (length(tot) > 0) {
    armCols <- armCols[-tot]
    armN    <- armN[-tot]
    armName <- armName[-tot]
    nArms   <- length(armCols)
    if (nArms == 0) return(NULL)
  }

  outRows      <- list()   # same shape as the engine's: row / type / perArm
  skipped      <- list()
  catColumns   <- character(0)
  anyMedian    <- FALSE
  # Row names are unique within the block: the same rule as .ppUniqueName
  # ("Age", "Age 2", "Age 3", ...) but through a hash set with a per-base
  # hint of the next suffix to try, so a sheet of identical labels costs
  # each row a constant, not a scan of every earlier name for every
  # candidate (screen 1715 F1: cubic in the rows).
  usedRowNames <- new.env(hash = TRUE, parent = emptyenv())
  nextSuffix   <- new.env(hash = TRUE, parent = emptyenv())
  takeRowName <- function(base) {
    if (!nzchar(base)) base <- "Unnamed"
    if (is.null(usedRowNames[[base]])) { usedRowNames[[base]] <- TRUE; return(base) }
    k <- nextSuffix[[base]]; if (is.null(k)) k <- 2L
    while (!is.null(usedRowNames[[paste(base, k)]])) k <- k + 1L
    nm <- paste(base, k)
    usedRowNames[[nm]] <- TRUE; nextSuffix[[base]] <- k + 1L
    nm
  }
  # Every row joins outRows through addOutRow(), which counts the lines it
  # will become (one per arm up to the last filled one, the count the
  # build uses) against the FILE's running total and refuses mid-loop
  # (screen 1715 F1: the bound after the loop left the loop unbounded).
  nLines <- 0L
  addOutRow <- function(rr) {
    outRows[[length(outRows) + 1]] <<- rr
    filled <- which(!vapply(rr$perArm, is.null, logical(1)))
    nLines <<- nLines + (if (length(filled)) max(filled) else 0L)
    .wideCheckLines(linesBefore + nLines)
  }
  # the width, likewise against the file's union (colsBefore is bounded
  # by the same cap, so the difference is cheap)
  checkWidth <- function()
    .wideCheckWidth(c(colsBefore, setdiff(catColumns, colsBefore)))

  addSkip <- function(label, reason, txt)
    skipped[[length(skipped) + 1]] <<-
      data.frame(label = label, reason = reason, text = txt,
                 stringsAsFactors = FALSE)
  # The text a skipped row carries to the grid's hover note: the label and
  # the ARM cells (never a "Total" column, which sits outside the arms and
  # their cap - screen 2047 F3), clipped to a note's length. It used to be
  # the whole row, which a dropped column of long cells made unbounded.
  rowText <- function(r)
    .ppClip(paste(c(cells[r, 1], cells[r, armCols]), collapse = " | "), 500L)

  # A category variable accumulates over consecutive count rows (the
  # generator writes a "Sex, n" header then one indented row per
  # category); it flushes when anything else appears. catHeaderNPct
  # records that the header announced count cells ("Race-N(%)"), which
  # is what licenses "a (b)" children as counts (vocacapsaicin corpus).
  catHeader     <- NA_character_
  catHeaderNPct <- FALSE
  catAccum  <- NULL   # list(row = <ROW label>, perArm = list of named lists)
  flushCat <- function(reset = TRUE) {
    if (!is.null(catAccum)) addOutRow(catAccum)
    catAccum <<- NULL
    if (reset) {
      catHeader     <<- NA_character_
      catHeaderNPct <<- FALSE
    }
  }
  addCount <- function(colName, counts) {
    # counts: integer vector over arms, NA where the cell was empty
    if (is.null(catAccum)) {
      rowName <- takeRowName(catHeader)
      catAccum <<- list(row = rowName, type = "category",
                        perArm = vector("list", nArms))
    }
    for (j in seq_len(nArms))
      if (!is.na(counts[j]))
        catAccum$perArm[[j]] <<- c(catAccum$perArm[[j]],
                                   stats::setNames(list(counts[j]), colName))
  }

  # Classify one cell (already stripped of its "; n = X" suffix).
  # medianTriple is checked first - the engine's tokenizer cannot match
  # the comma-separated form; everything else defers to .ppTokenizeLine
  # so the cell rules stay identical to the PDF engine's.
  classify <- function(txt) {
    m <- regmatches(txt, regexec(.wideMedianPat, txt, perl = TRUE))[[1]]
    if (length(m) == 4)
      return(list(type = "medianTriple",
                  num1 = .ppAsNumeric(m[2]), num2 = .ppAsNumeric(m[3]),
                  num3 = .ppAsNumeric(m[4]), dec1 = .ppDecimals(m[2])))
    # the first token only - one scan of the cell, not a data frame per
    # token it holds (screen 2026-09-10-1856, F1)
    t <- .ppTokenizeLine(data.frame(text = txt, x = 0, width = nchar(txt),
                                    stringsAsFactors = FALSE), first = TRUE)
    if (nrow(t) == 0) return(NULL)
    as.list(t[1, ])
  }

  dataRows <- seq(hdr + 1L, length.out = nrow(cells) - hdr)
  # A row that parses becomes at least one line, so a block with more
  # rows past its header than the file has lines left cannot be within
  # the bound: refused here, before a row is tokenised (screen 1715 F1 -
  # the per-row cost is linear now, about 3 ms, but 9,999 rows of it is
  # still half a minute for a refusal the count alone can give).
  if (linesBefore + length(dataRows) > .iaMaxWideLines)
    .iaWideTooLarge(sprintf(paste("the journal-style table has %d rows past its header",
                                  "(%d template lines already counted); the limit is %d",
                                  "lines, and every usable row becomes at least one"),
                            length(dataRows), linesBefore, .iaMaxWideLines))
  .wideCheckCells(acc$nCells + length(dataRows) * nArms)   # screen 1822 F2: rows x arms, up front
  for (r in dataRows) {
    checkWidth()                         # screen 1628 F1: refuse before the build
    rawLabel <- cells[r, 1]
    bodyTxt  <- cells[r, armCols]
    if (!nzchar(trimws(rawLabel)) && !any(nzchar(trimws(bodyTxt)))) {
      flushCat()
      next
    }
    indent <- grepl("^\\s{2,}", rawLabel)
    label  <- .ppSquish(rawLabel)

    # -- label tags ----------------------------------------------------
    tag <- if (grepl(.wideTagMeanSD, label, perl = TRUE))      "meanSD"
           else if (grepl(.wideTagMedIQR, label, perl = TRUE)) "medIQR"
           else if (grepl(.wideTagMedRng, label, perl = TRUE)) "medRng"
           else if (grepl(.wideTagCat, label, perl = TRUE))    "cat"
           else NA_character_
    if (!is.na(tag))
      label <- .ppSquish(sub(switch(tag, meanSD = .wideTagMeanSD,
                                    medIQR = .wideTagMedIQR,
                                    medRng = .wideTagMedRng,
                                    cat = .wideTagCat),
                             "", label, perl = TRUE))

    # A label that SAYS "median (IQR)" or "median [range]" earns the Q1/Q3
    # columns HERE, where the label is resolved and before ANY branch below
    # can consume the row. It was consumed twice over: #140 set the flag
    # inside the median branch, so a row whose cells did not tokenize left
    # at "cells not in a recognized format - enter by hand" with no Q1/Q3
    # (CodeRabbit on #140); the fix for that sat below the no-cells branch,
    # so a labelled row with EMPTY cells - which becomes a variable heading
    # for the "Mean"/"Median" line that customarily follows it - still
    # earned nothing (CodeRabbit on #142). Same defect each time, "enter by
    # hand" into a grid with nowhere to type, and the same cure: read the
    # label at the one place it is known. An unlabelled medianTriple row
    # still sets the flag in the median branch, where its shape is what
    # identifies it.
    if (!is.na(tag) && tag %in% c("medIQR", "medRng")) anyMedian <- TRUE

    # -- header line of a category variable ("Sex, n" - no cells) ------
    if (!any(nzchar(trimws(bodyTxt)))) {
      flushCat()
      catHeader <- if (nzchar(label)) label else "Category"
      catHeaderNPct <- identical(tag, "cat")
      next
    }

    # -- per-cell N override "45.3 (12.1); n = 14" ---------------------
    lineN <- rep(NA_real_, nArms)
    cellTxt <- trimws(bodyTxt)
    for (j in seq_len(nArms)) {
      m <- regmatches(cellTxt[j],
                      regexec("[,;]\\s*n\\s*=\\s*(\\d[\\d,]*)\\s*$",
                              cellTxt[j], perl = TRUE))[[1]]
      if (length(m) == 2) {
        lineN[j] <- .ppAsNumeric(m[2])
        cellTxt[j] <- trimws(sub("[,;]\\s*n\\s*=\\s*\\d[\\d,]*\\s*$", "",
                                 cellTxt[j], perl = TRUE))
      }
    }

    # screen 1822 F1 and F2: a cell is bounded in length before the
    # tokenizer sees it, and the file's budget of cells is spent here
    long <- nchar(cellTxt) > .iaMaxWideCellChars
    if (any(long))
      .iaWideTooLarge(sprintf(paste("a cell of %d characters in the row labelled '%s';",
                                    "the limit is %d - a baseline cell is a number or two"),
                              max(nchar(cellTxt)), substr(label, 1, 60), .iaMaxWideCellChars))
    acc$nCells <- acc$nCells + nArms
    .wideCheckCells(acc$nCells)
    toks <- lapply(cellTxt, function(x)
      if (nzchar(x)) classify(x) else NULL)
    types <- vapply(toks, function(t)
      if (is.null(t)) NA_character_ else t$type, character(1))
    present <- !is.na(types)
    if (!any(present)) {
      addSkip(if (nzchar(label)) label else paste(cellTxt, collapse = " "),
              "cells not in a recognized format - enter by hand",
              rowText(r))
      next
    }
    mainType <- names(sort(table(types), decreasing = TRUE))[1]

    # -- an arm-N row supplies missing arm Ns --------------------------
    # Two shapes: a labelled "No. of patients" row of bare integers, and
    # the two-line header's second row - no label, every cell "N=36"
    # (vocacapsaicin corpus, 2026-08-22).
    nCells <- nzchar(cellTxt)
    if ((mainType == "plain" &&
         grepl("(?i)^(no\\.?|n|number)\\b.*(patient|subject|participant|randomi)|^n$",
               label, perl = TRUE)) ||
        (!nzchar(label) && any(nCells) &&
           all(grepl("(?i)^n\\s*=\\s*[\\d,]+$", cellTxt[nCells],
                     perl = TRUE)))) {
      for (j in seq_len(nArms))
        if (!is.null(toks[[j]]) && toks[[j]]$type == "plain" &&
            is.na(armN[j]))
          armN[j] <- as.numeric(toks[[j]]$num1)
      next
    }

    # A row whose whole label is "N (%)" is the count row OF the
    # heading above it ("NSAID use" / "N (%)  4 (11%) ..."), not a
    # child level named "N (%)" - route it to the standalone branch,
    # which names it from the heading (vocacapsaicin corpus).
    if (grepl("(?i)^(no\\.?|n)\\s*\\(\\s*%\\s*\\)$", label, perl = TRUE)) {
      tag <- "cat"
      label <- ""
    }

    # -- category count rows -------------------------------------------
    # The generator indents them under the header; real-world sheets
    # often do not, so any count-shaped row under an active category
    # header is a child: bare integers always, "a (b%)" cells always
    # (the % marks a count), and bare "a (b)" cells when the header
    # itself announced N (%). A row carrying its OWN tag is standalone.
    isChild <- is.na(tag) && !is.na(catHeader) &&
      (mainType %in% c("plain", "nPct") ||
         (mainType == "numParen" && catHeaderNPct))
    if ((mainType == "plain" && indent) || isChild) {
      # "Median  71.9 ..." under a variable heading is a summary
      # statistic: skip with its own reason - and as.integer() must
      # never truncate a non-integer into a "count". Both skips leave
      # the heading OPEN for the variable's next line.
      if (grepl("(?i)^median\\b", label, perl = TRUE)) {
        addSkip(paste(c(catHeader[!is.na(catHeader)], label),
                      collapse = " "),
                paste("median without quartiles - enter median/Q1/Q3 by",
                      "hand if an IQR is printed"),
                rowText(r))
        next
      }
      nonInt <- vapply(toks, function(t)
        !is.null(t) && t$type == "plain" && !is.na(t$num1) &&
          t$num1 != round(t$num1), logical(1))
      if (any(nonInt)) {
        addSkip(if (nzchar(label)) label else catHeader,
                paste("non-integer values under a category heading -",
                      "not counts; enter by hand"),
                rowText(r))
        next
      }
      if (is.na(catHeader)) catHeader <- "Category"
      counts <- vapply(seq_len(nArms), function(j) {
        t <- toks[[j]]
        if (is.null(t) || !t$type %in% c("plain", "nPct", "numParen"))
          NA_integer_
        else as.integer(t$num1)
      }, integer(1))
      colName <- .ppUniqueName(if (nzchar(label)) label else "Category",
                               catColumns)
      catColumns <- unique(c(catColumns, colName))
      addCount(colName, counts)
      next
    }
    flushCat(reset = FALSE)
    hdrName <- catHeader
    catHeader <- NA_character_
    catHeaderNPct <- FALSE

    txt <- rowText(r)

    # -- median rows ----------------------------------------------------
    if (mainType == "medianTriple" || tag %in% c("medIQR", "medRng")) {
      # COLUMNS FIRST, VERDICT SECOND (Steve, 2026-09-02). anyMedian used to
      # be set only where a median row SURVIVED, several `next`s below. So a
      # sheet whose median rows were all skipped got no Q1/Q3 columns - while
      # the skip reason told the reader to "enter median/Q1/Q3 by hand".
      # There was nowhere to type them: the grid had no Q1 and no Q3. Seeing
      # a median row is what justifies the columns; whether we could use it
      # is a separate question, and the answer to it is the reason the user
      # needs somewhere to type.
      anyMedian <- TRUE
      # The interval's meaning comes from the LABEL, never from the
      # numbers: an IQR and a range both straddle the median. Same
      # conservative gate as the engine (issue 18): explicit IQR -> emit
      # Q1/Q3; explicit range -> skip; unlabeled -> skip. Feeding a range
      # into the metalog null would be a correctness bug in a
      # fraud-screening verdict, so ambiguity always loses.
      saysIQR <- identical(tag, "medIQR") ||
        grepl("(?i)iqr|interquartile|quartile|\\bq1\\b|25th", rawLabel,
              perl = TRUE)
      saysRng <- identical(tag, "medRng") ||
        grepl("(?i)\\brange\\b|min\\s*[-–]?\\s*max|minimum", rawLabel,
              perl = TRUE)
      if (saysRng) {
        addSkip(label, paste("median [range] - the analysis needs",
                             "quartiles (Q1/Q3), not the range"), txt)
        next
      }
      if (!saysIQR) {
        addSkip(label, paste("median with an unlabeled interval - if it",
                             "is an IQR, enter median/Q1/Q3 by hand"), txt)
        next
      }
      # A median outside its own [Q1, Q3] is IMPOSSIBLE, so the arm carrying
      # it cannot be analyzed. It used to take the whole variable with it -
      # `any(bad)` skipped the row - which is backwards for a screening tool
      # on two counts: the arms that ARE internally consistent were thrown
      # away with the one that is not, and the impossible value itself, which
      # is precisely the kind of finding this app exists to surface,
      # disappeared from the grid. Drop only the offending arm, name it, and
      # keep the rest (Steve's Ticagrelor sheet, 2026-09-02: Age was dropped
      # over the Aspirin arm's "68.8 (59-64)" while Ticagrelor's
      # "62 (60-67)" was perfectly usable).
      # medPresent, not `present`: the row loop already has a `present`
      # built from `types`, and reusing the name here shadowed it.
      medPresent <- vapply(toks, function(t)
        !is.null(t) && t$type == "medianTriple", logical(1))
      bad <- medPresent & vapply(toks, function(t)
        !is.null(t) && t$type == "medianTriple" &&
          (t$num2 > t$num1 || t$num3 < t$num1), logical(1))
      if (any(medPresent) && !any(medPresent & !bad)) {
        # Nothing survives - same outcome, and same message, as before.
        addSkip(label, "median outside its own [Q1, Q3] - check the cells",
                txt)
        next
      }
      if (any(bad))
        addSkip(paste0(label, " - ", paste(armName[bad], collapse = ", ")),
                paste("median outside its own [Q1, Q3] in this arm, so the",
                      "arm was dropped - the other arm(s) were kept. Check",
                      "these cells against the manuscript"), txt)
      rowName <- takeRowName(if (nzchar(label)) label else "Unnamed")
      perArm <- lapply(seq_len(nArms), function(j) {
        t <- toks[[j]]
        if (is.null(t) || t$type != "medianTriple") return(NULL)
        if (bad[j]) return(NULL)          # impossible: reported, not analyzed
        list(N = if (!is.na(lineN[j])) lineN[j] else armN[j],
             MEAN = t$num1, Q1 = t$num2, Q3 = t$num3,
             SD = NA_real_, SE = NA_real_,
             ROUND_MEAN = t$dec1, ROUND_DISPERSION = NA_integer_,
             ROUND_OBSERVATION = t$dec1)
      })
      addOutRow(list(row = rowName, type = "median", perArm = perArm))
      next
    }

    # -- "a (b)": SD or percent? ---------------------------------------
    # The engine's decision ladder (parseBaselineTableHeuristics.R,
    # "numParen"), minus the table-level footnote evidence a lone
    # spreadsheet does not carry: an explicit tag or a continuous-sounding
    # label reads SD; a percent-sounding label reads n (%); the default is
    # SD, the overwhelming convention.
    if (mainType == "numParen") {
      labelSaysPct <- grepl("(?i)\\(%\\)|percent", rawLabel, perl = TRUE)
      mainType <- if (identical(tag, "meanSD")) "meanSD"
                  else if (labelSaysPct || identical(tag, "cat")) "nPct"
                  else "meanSD"
    }

    if (mainType == "meanSD") {
      # A bare "Mean (SD)" label is a summary-statistic line under a
      # variable heading ("Weight (kg)" on the line above): the
      # variable's name is that heading, which is then RESTORED so the
      # "Median" line that customarily follows still knows its variable
      # (vocacapsaicin corpus, 2026-08-22).
      statRow <- !is.na(hdrName) &&
        (!nzchar(label) || grepl("(?i)^mean$", label, perl = TRUE))
      rowName <- takeRowName(if (statRow) hdrName
                             else if (nzchar(label)) label else "Unnamed")
      if (statRow) catHeader <- hdrName
      # "Age, mean (SEM)" in the label files the value as SE, mirroring
      # the engine's row-level override; there is no footnote here to
      # consult, so the label is the only evidence.
      isSE <- grepl("(?i)\\bs\\.?e\\.?m?\\.?\\b|standard\\s+error",
                    rawLabel, perl = TRUE) &&
              !grepl("(?i)\\bs\\.?d\\.?\\b|standard\\s+deviation",
                     rawLabel, perl = TRUE)
      perArm <- lapply(seq_len(nArms), function(j) {
        t <- toks[[j]]
        if (is.null(t) || !t$type %in% c("meanSD", "numParen")) return(NULL)
        list(N = if (!is.na(lineN[j])) lineN[j] else armN[j],
             MEAN = t$num1,
             SD = if (isSE) NA_real_ else t$num2,
             SE = if (isSE) t$num2 else NA_real_,
             ROUND_MEAN = t$dec1,
             ROUND_DISPERSION = t$dec2,
             # ROUND_OBSERVATION is not printed in a wide table, and
             # validateData() defaults it to ROUND_MEAN - matching that
             # default (NOT the PDF engine's ROUND_MEAN + 1) is what lets
             # the round trip close exactly.
             ROUND_OBSERVATION = t$dec1)
      })
      addOutRow(list(row = rowName, type = "continuous", perArm = perArm))
      next
    }

    if (mainType == "nPct") {
      # Binary n (%) row: count column plus its complement when the arm N
      # is known - mirroring the engine's nPct branch, including the skip
      # when no N makes the complement uncomputable. An empty label takes
      # the heading above it (the "N (%)" row of an "NSAID use" heading
      # names the NSAID variable, not "Category").
      catName <- .ppUniqueName(
        if (nzchar(label)) label
        else if (!is.na(hdrName)) hdrName else "Category", catColumns)
      complementName <- .ppUniqueName(paste("Not", catName),
                                      c(catColumns, catName))
      effN <- ifelse(is.na(lineN), armN, lineN)
      haveN <- all(!is.na(effN[!vapply(toks, is.null, logical(1))]))
      catColumns <- unique(c(catColumns, catName,
                             if (haveN) complementName))
      if (!haveN) {
        addSkip(label, paste("n (%) with unknown arm N - complement",
                             "category cannot be computed; edit by hand"),
                txt)
        next
      }
      rowName <- takeRowName(catName)
      perArm <- lapply(seq_len(nArms), function(j) {
        t <- toks[[j]]
        if (is.null(t) || !t$type %in% c("nPct", "numParen")) return(NULL)
        cnt <- as.integer(t$num1)
        stats::setNames(list(cnt, as.integer(effN[j] - cnt)),
                        c(catName, complementName))
      })
      addOutRow(list(row = rowName, type = "category", perArm = perArm))
      next
    }

    if (mainType == "fraction") {
      addSkip(label, paste("fraction cell (a/b) - enter the counts as",
                           "category columns by hand"), txt)
      next
    }
    if (mainType == "pctOnly") {
      addSkip(label, "percent only, no count - enter by hand", txt)
      next
    }
    addSkip(if (nzchar(label)) label else "Unnamed",
            "bare numbers - cannot tell counts from means; enter by hand",
            txt)
  }
  flushCat()

  if (length(outRows) == 0) return(NULL)

  # ---- Assemble the template-format frame (engine layout) ------------
  # One line per variable per arm; arm identity is positional, so an
  # interior empty cell becomes an all-NA line (holding the position, and
  # painting yellow in the grid) while TRAILING empties - the generator's
  # padding for a variable with fewer arms - produce no line at all.
  flushCat()
  checkWidth()
  .wideCheckLines(linesBefore + nLines)
  allCols <- c(.ppBaseColumns(), if (anyMedian) c("Q1", "Q3"), catColumns)
  rows <- list()
  for (rr in outRows) {
    filled <- which(!vapply(rr$perArm, is.null, logical(1)))
    if (length(filled) == 0) next
    for (j in seq_len(max(filled))) {
      v <- rr$perArm[[j]]
      line <- stats::setNames(as.list(rep(NA, length(allCols))), allCols)
      line$TRIAL <- trial
      line$ROW   <- rr$row
      if (!is.null(v)) {
        if (rr$type %in% c("continuous", "median")) {
          for (nm in intersect(names(v), allCols)) line[[nm]] <- v[[nm]]
        } else {
          for (nm in names(v)) line[[nm]] <- v[[nm]]
        }
      }
      rows[[length(rows) + 1]] <- line
    }
  }
  DATA <- do.call(rbind, lapply(rows, function(l)
    as.data.frame(l, check.names = FALSE, stringsAsFactors = FALSE)))

  list(trial   = trial,
       data    = DATA,
       arms    = data.frame(arm = armName, N = armN,
                            stringsAsFactors = FALSE),
       skipped = if (length(skipped) > 0) do.call(rbind, skipped) else
         data.frame(label = character(0), reason = character(0),
                    text = character(0)))
}

#' Read a journal-style wide baseline table as input
#'
#' Detects and parses spreadsheets laid out the way journals print a
#' baseline table - variables as rows, arms as columns, cells like
#' "45.3 (12.1)" - including the Editor's View workbook this app itself
#' generates (both its shapes: one sheet per trial, and the results
#' workbook's stacked "Trial: ..." blocks). Returns NULL when nothing in
#' the file looks like a wide table, so the caller can fall back to the
#' ordinary template reader.
#'
#' @param path the spreadsheet file.
#' @param ext lower-case extension ("csv", "xlsx", "xls").
#' @return NULL, or a list of blocks, each
#'   `list(trial, data, arms, skipped)`: `trial` may be NA (caller names
#'   it), `data` is a template-format frame, `skipped` names each
#'   unusable row and why (the app turns these into red grid rows).
#' @noRd
# A block joins the file's list only while the file as a whole is within
# the bounds (screen 1628 F1): the lines add up, and the category columns
# are the UNION across blocks - which is the width of the frame the
# callers build from them. The totals are CARRIED (screen 1715 F2: a
# recount over every block at every block was quadratic - nine minutes
# for 6,666 one-line blocks) and handed to each block as it is parsed,
# so a block refuses mid-loop once the file is past a bound.
.wideAddBlock <- function(acc, blk) {
  base <- c(.ppBaseColumns(), "Q1", "Q3")
  acc$nLines <- acc$nLines + nrow(blk$data)
  acc$cols   <- unique(c(acc$cols, setdiff(names(blk$data), base)))
  .wideCheckLines(acc$nLines)
  .wideCheckWidth(acc$cols)
  invisible(acc)
}

parseWideTable <- function(path, ext) {
  sheetList <- tryCatch(.wideRawCells(path, ext), error = function(e) NULL)
  if (is.null(sheetList)) return(NULL)
  blocks <- list()
  acc <- .wideNewTotals()   # the file's running totals: lines, columns, cells
  for (s in seq_along(sheetList)) {
    cells <- sheetList[[s]]
    if (nrow(cells) == 0) next
    sheetName <- names(sheetList)[s]
    markers <- which(grepl("^Trial:\\s*\\S", cells[, 1]))
    if (length(markers) > 0) {
      # the stacked results-workbook shape: each "Trial: <id>" row opens
      # a block; ids here are exact (no sheet-name truncation), which is
      # why this shape round-trips long trial names faithfully
      ends <- c(markers[-1] - 1L, nrow(cells))
      for (b in seq_along(markers)) {
        if (ends[b] <= markers[b]) next   # marker with nothing under it
        sub <- cells[seq(markers[b] + 1L, ends[b]), , drop = FALSE]
        hdr <- .wideHeaderRow(sub)
        if (is.na(hdr)) next
        blk <- .wideParseBlock(sub, hdr,
                               .ppClip(sub("^Trial:\\s*", "", cells[markers[b], 1]),
                                       .iaMaxTrialIdChars), acc)
        if (!is.null(blk)) {
          .wideAddBlock(acc, blk)
          blocks[[length(blocks) + 1]] <- blk
        }
      }
    } else {
      hdr <- .wideHeaderRow(cells)
      if (is.na(hdr)) next
      # sheet-per-trial shape: the sheet name IS the trial id (as
      # writeBaselineTablesXlsx names them), except Excel's meaningless
      # defaults ("Sheet1"), which the caller replaces with the file stem
      trial <- if (is.null(sheetName) || !nzchar(sheetName) ||
                   grepl("(?i)^sheet ?\\d*$", sheetName))
        NA_character_ else .ppClip(sheetName, .iaMaxTrialIdChars)
      blk <- .wideParseBlock(cells, hdr, trial, acc)
      if (!is.null(blk)) {
        .wideAddBlock(acc, blk)
        blocks[[length(blocks) + 1]] <- blk
      }
    }
  }
  if (length(blocks) == 0) NULL else blocks
}
