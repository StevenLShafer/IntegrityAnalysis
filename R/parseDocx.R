# parseDocx.R - read the baseline table out of a Word .docx manuscript
# (ISSUES.md issue 19).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-21,
# at Steve Shafer's request. Verified by tests/testthat/test-parse-docx.R
# (synthetic .docx fixtures built with officer, mirroring the synthetic
# PDFs of helper-syntheticPdf.R).
#
# THE DESIGN, in one sentence: a Word table is already a grid of cells,
# so this file fabricates the word-coordinate `lines` structure the PDF
# engine's `.ppParseBlock()` expects and feeds it in VERBATIM - zero
# changes to the most heavily test-pinned code in the package - which
# buys every cell rule for free: mean ± SD, "a (b)" footnote
# disambiguation, n (%) complements, percent conversion, SD-vs-SE,
# median gating, and arm-N recovery.
#
# What is genuinely different from a PDF, and how it is handled:
#   - No pages, no coordinates. The body XML is read directly (xml2,
#     which travels with officer): paragraphs and tables in document
#     order, each table an exact grid of cells - see .ppDocxData for
#     why docx_summary() cannot do this job. Coordinates are then
#     synthesized (.ppDocxLines): column c's words sit at
#     x = (c-1) * pitch, where pitch is computed from the widest cell
#     so that .ppClusterColumns() (gapTol = 25) always sees each Word
#     column as exactly one cluster and a long label can never overrun
#     its neighbour. Pinned by a unit test.
#   - Submissions put tables at the END of the file, captions (usually)
#     just before each table. Caption-above-table is the engine's native
#     orientation, and here the pairing is exact rather than heuristic:
#     the nearest preceding non-empty paragraphs, scored by
#     .ppCaptionScore(). EVERY table in the document is a candidate and
#     the caption-preference rules of the PDF path decide, so placement
#     - end of manuscript or inline - does not matter.
#   - Footnotes are the paragraphs immediately after the table; appended
#     as synthetic lines so the engine's stopPattern/footnote machinery
#     drives "a (b)" and SD-vs-SE decisions unchanged.
#   - Arm-N recovery reads the document's paragraphs (the only PDF
#     coupling in armNRecovery.R was .ppPdfText). Both standing
#     invariants live inside .ppParseBlock/.ppParseScore untouched:
#     recovery only runs when no data-bearing arm printed an N, and
#     recovered Ns carry no weight in choosing between tables.
#   - `pages` in the result is the TABLE ORDINAL in the document (docx
#     has no pages); `layout` is "docx"; `engine` is "heuristic-docx".
#   - No glyph repair needed: officer returns real Unicode (the
#     Symbol-PUA damage the PDF path repairs happens at PDF export).
#
# Punted, deliberately (record kept in docs/parsepdf-architecture.md):
# "Table 1 continued" split into a second Word table object is not
# stitched (each candidate scores alone); vertical merges keep their
# text in the first row only.
#
# Security note (AGENTS.md threat model - the manuscript author is the
# adversary): a .docx is a zip of XML read by libxml2 via officer. It is
# parsed as DATA - nothing here evaluates document content - but crafted
# XML can stall or exhaust its parser, which is why the app routes .docx
# through parseBaselineTableFiles()'s one-subprocess-per-file OS timeout
# exactly like a PDF.

# One Word table element -> a character matrix of cell text.
#
# Read from the XML directly (xml2 travels with officer) rather than
# from officer::docx_summary(), whose output cannot reassemble tables:
# measured on generated fixtures (2026-08-21/22), its doc_index is
# unique per CELL, its row_id runs on ACROSS tables, and EMPTY cells
# are omitted while still consuming doc_index values - so no rule over
# the summary can tell one table from two, and a real manuscript's
# Table 1 shattered into 8 fragments (Steve's vocacapsaicin corpus).
# The XML has none of these ambiguities: one <w:tbl>, its <w:tr> rows,
# their <w:tc> cells - empty ones included - and <w:gridSpan> for
# horizontal merges.
.ppDocxTableMatrix <- function(tbl) {
  rows <- xml2::xml_find_all(tbl, "./w:tr")
  if (length(rows) == 0) return(NULL)
  cellsList <- lapply(rows, function(tr) {
    tcs <- xml2::xml_find_all(tr, "./w:tc")
    if (length(tcs) == 0) return(character(0))
    txt <- vapply(tcs, xml2::xml_text, character(1))
    span <- vapply(tcs, function(tc) {
      gs <- xml2::xml_find_first(tc, "./w:tcPr/w:gridSpan")
      v <- xml2::xml_attr(gs, "val")
      if (is.na(v)) 1L else max(1L, suppressWarnings(as.integer(v)))
    }, integer(1))
    span[is.na(span)] <- 1L
    out <- character(sum(span))
    pos <- 1L
    for (k in seq_along(txt)) {
      out[pos] <- txt[k]
      # A merged HEADER cell spanning several columns ("Treatment
      # (n = 50)" over its subcolumns) is replicated across its span
      # when it carries an arm size, so each spanned column keeps its
      # N. Everything else spanned stays empty - an empty cell yields
      # no token, which the engine already tolerates.
      if (span[k] > 1L && grepl("(?i)n\\s*=\\s*\\d", txt[k], perl = TRUE))
        out[pos + seq_len(span[k] - 1L)] <- txt[k]
      pos <- pos + span[k]
    }
    out
  })
  nc <- max(lengths(cellsList))
  if (nc == 0) return(NULL)
  mat <- matrix("", nrow = length(cellsList), ncol = nc)
  for (r in seq_along(cellsList)) {
    cl <- cellsList[[r]]
    if (length(cl) > 0) mat[r, seq_along(cl)] <- cl
  }
  mat
}

# Read the document body in order: paragraphs (doc_index, text) and
# tables (cell matrix plus its position among the body's children).
# Consecutive same-width tables with nothing but empty paragraphs
# between them are STITCHED into one: manuscripts routinely split one
# visual Table 1 into several Word table objects, and the header rows
# (arm names, arm Ns) live in the first fragment while the data rows
# live in the rest. A NON-empty paragraph between two tables - the next
# table's caption - blocks stitching.
.ppDocxData <- function(docxFile) {
  x <- officer::read_docx(docxFile)
  body <- xml2::xml_find_first(x$doc_obj$get(), "//w:body")
  kids <- xml2::xml_children(body)
  para <- list()
  tabs <- list()
  for (i in seq_along(kids)) {
    nm <- xml2::xml_name(kids[[i]])
    if (nm == "p") {
      para[[length(para) + 1]] <-
        data.frame(doc_index = i, text = xml2::xml_text(kids[[i]]),
                   stringsAsFactors = FALSE)
    } else if (nm == "tbl") {
      mat <- .ppDocxTableMatrix(kids[[i]])
      if (!is.null(mat))
        tabs[[length(tabs) + 1]] <-
          list(docFirst = i, docLast = i, cells = mat)
    }
  }
  para <- if (length(para) > 0) do.call(rbind, para) else
    data.frame(doc_index = integer(0), text = character(0),
               stringsAsFactors = FALSE)
  para$text[is.na(para$text)] <- ""

  stitched <- list()
  for (t in tabs) {
    prev <- if (length(stitched) > 0) stitched[[length(stitched)]] else NULL
    between <- para$text[para$doc_index > (if (is.null(prev)) -1 else
                                             prev$docLast) &
                           para$doc_index < t$docFirst]
    # a table that opens with its own full-width "Table ..." title row
    # is a NEW table, never a continuation, even with nothing between
    nz1 <- which(nzchar(.ppSquish(t$cells[1, ])))
    ownTitle <- length(nz1) == 1 &&
      grepl("(?i)^(table|tab\\.?)\\b", .ppSquish(t$cells[1, nz1[1]]),
            perl = TRUE)
    if (!is.null(prev) && !ownTitle &&
        ncol(prev$cells) == ncol(t$cells) &&
        !any(nzchar(.ppSquish(between)))) {
      prev$cells <- rbind(prev$cells, t$cells)
      prev$docLast <- t$docLast
      stitched[[length(stitched)]] <- prev
    } else {
      stitched[[length(stitched) + 1]] <- t
    }
  }
  list(tables = stitched, paragraphs = para)
}

# Fabricate one engine "line" (a data frame of words with text/x/y/width/
# height) from free text starting at x = x0.
.ppDocxTextLine <- function(txt, y, x0 = 0, charW = 6) {
  ws <- strsplit(.ppSquish(txt), " ")[[1]]
  ws <- ws[nzchar(ws)]
  if (length(ws) == 0) return(NULL)
  x <- x0
  out <- vector("list", length(ws))
  for (i in seq_along(ws)) {
    out[[i]] <- data.frame(text = ws[i], x = x, y = y,
                           width = charW * nchar(ws[i]), height = 10,
                           stringsAsFactors = FALSE)
    x <- x + charW * nchar(ws[i]) + charW
  }
  do.call(rbind, out)
}

# The synthetic-coordinate adapter: a cell matrix (plus optional caption
# text before and footnote paragraphs after) becomes the (lines,
# lineTexts, capIdx) triple .ppParseBlock() consumes.
.ppDocxLines <- function(mat, caption = NULL, footnotes = character(0)) {
  charW <- 6
  # Column pitch: wide enough that the widest cell's words stay inside
  # their own slot (a cell of n characters spans about charW * n points
  # plus inter-word gaps), so inter-column gaps stay far above
  # .ppClusterColumns()'s gapTol = 25 and every Word column becomes
  # exactly one cluster. Pinned by a test on a pathologically wide cell.
  pitch <- max(60, charW * max(0L, nchar(mat)) + 60)
  lines <- list()
  y <- 0
  add <- function(df) if (!is.null(df))
    lines[[length(lines) + 1]] <<- df[order(df$x), , drop = FALSE]
  if (!is.null(caption) && nzchar(.ppSquish(caption))) {
    add(.ppDocxTextLine(caption, y)); y <- y + 12
  }
  for (r in seq_len(nrow(mat))) {
    words <- list()
    for (cl in seq_len(ncol(mat))) {
      txt <- mat[r, cl]
      if (!nzchar(.ppSquish(txt))) next
      words[[length(words) + 1]] <-
        .ppDocxTextLine(txt, y, x0 = (cl - 1) * pitch, charW = charW)
    }
    if (length(words) > 0) add(do.call(rbind, words))
    y <- y + 12
  }
  for (fn in footnotes) {
    if (!nzchar(.ppSquish(fn))) next
    add(.ppDocxTextLine(fn, y)); y <- y + 12
  }
  list(lines = lines,
       lineTexts = vapply(lines, .ppLineText, character(1)),
       capIdx = if (!is.null(caption) && nzchar(.ppSquish(caption))) 1L
                else 0L)
}

#' Parse the baseline table of a Word .docx manuscript
#'
#' The .docx counterpart of [parseBaselineTableHeuristics()], which
#' dispatches here when its `pdfFile` argument ends in `.docx`. Every
#' table in the document is tried as a candidate; the caption-preference
#' and parse-score rules of the PDF path pick the winner, so it does not
#' matter where in the manuscript the table sits. Purely deterministic -
#' no AI service is called.
#'
#' @param docxFile path to the .docx file.
#' @inheritParams parseBaselineTableHeuristics
#' @return A `ParsePDFTable` (the class name is historical), as
#'   [parseBaselineTableHeuristics()] returns it, except: `pages` is the
#'   winning table's ordinal in the document (a .docx has no pages),
#'   `layout` is `"docx"`, and `engine` is `"heuristic-docx"`.
#' @noRd
parseBaselineTableDocx <- function(docxFile,
                                   trial = tools::file_path_sans_ext(basename(docxFile)),
                                   parenIsSD     = c("auto", "sd", "percent"),
                                   roundObsDelta = 1,
                                   maxCandidates = 6,
                                   pctApprox     = FALSE,
                                   quiet         = FALSE) {
  parenIsSD <- match.arg(parenIsSD)
  if (!requireNamespace("officer", quietly = TRUE))
    stop("Package 'officer' is required: install.packages('officer')")
  say <- function(...) if (!quiet) message(...)

  doc <- .ppDocxData(docxFile)
  if (length(doc$tables) == 0) {
    # A revision that lists "Table 1 / Baseline characteristics ..." as
    # caption paragraphs but contains no table at all is a journal
    # convention, not an accident: several journals collect tables as
    # separate files at submission, and some manuscripts paste the
    # table as a picture (both seen in the vocacapsaicin corpus,
    # 2026-08-25). Say which situation this looks like, and what to
    # upload instead.
    hasCaption <- any(grepl("(?i)^\\s*(table|tab\\.?)\\s+([0-9]{1,2}|[IVXLivxl]{1,4})\\b",
                            doc$paragraphs$text, perl = TRUE))
    stop("No tables found in ", docxFile,
         if (hasCaption)
           paste0(" - the file lists table captions, but the tables",
                  " themselves are not in it (journals often collect",
                  " tables as separate files at submission, and a table",
                  " pasted as a picture has no text to read). Upload",
                  " the file that holds the baseline table, or the",
                  " compiled submission PDF.")
         else
           paste0(" - the baseline table must be a Word table, not an",
                  " image or tabbed text."))
  }

  # Document-level arm-N recovery constants, exactly as the PDF path
  # extracts them once from .ppPdfText() (armNRecovery.R is pure text).
  fullText   <- doc$paragraphs$text
  textCands  <- .ppArmNCandidatesFromText(fullText)
  textTotals <- .ppRandomizedTotals(fullText)

  # ---- Enumerate candidates: every table, paired with its caption ---------
  para <- doc$paragraphs[nzchar(.ppSquish(doc$paragraphs$text)), ,
                         drop = FALSE]
  tableIdx <- vapply(doc$tables, `[[`, numeric(1), "docFirst")
  cand <- list()
  for (t in seq_along(doc$tables)) {
    tab <- doc$tables[[t]]
    # caption: the best-scoring of the two nearest preceding non-empty
    # paragraphs (Word puts the caption paragraph directly above the
    # table; "two" tolerates a stray empty style paragraph between).
    # Note: an auto-numbered Word caption (a SEQ field) can render in
    # docx_summary without its number, costing .ppCaptionScore()'s
    # "Table 1" bonus - the vocabulary terms still score.
    prev <- utils::tail(para$text[para$doc_index < tab$docFirst], 2)
    capScore <- -Inf; caption <- NA_character_
    for (pt in prev) {
      cs <- .ppCaptionScore(pt)
      if (cs >= capScore) { capScore <- cs; caption <- pt }
    }
    if (!is.finite(capScore)) capScore <- 0
    # Manuscripts often write the caption INSIDE the table, as its
    # first row ("Table 1: Baseline characteristics of study subjects"
    # across the width - vocacapsaicin corpus, 2026-08-22). Left in
    # place, that row would trip the engine's next-table stop pattern
    # AND the candidate would score 0, letting a larger results table
    # win. Promote it: a leading row with exactly one non-empty cell
    # whose text is caption-shaped becomes the candidate's caption.
    mat <- tab$cells
    while (nrow(mat) > 0) {
      nz <- which(nzchar(.ppSquish(mat[1, ])))
      first <- if (length(nz) == 1) .ppSquish(mat[1, nz[1]]) else ""
      if (nzchar(first) &&
          grepl("(?i)^(table|tab\\.?)\\s+([0-9]{1,2}|[IVXLivxl]{1,4})\\b",
                first, perl = TRUE)) {
        cs <- .ppCaptionScore(first)
        if (cs >= capScore || is.na(caption)) {
          capScore <- cs
          caption <- first
        }
        mat <- mat[-1, , drop = FALSE]
      } else break
    }
    tab$cells <- mat
    # footnotes: up to 4 paragraphs after this table and before the next
    nextTable <- c(tableIdx, Inf)[t + 1]
    after <- para$text[para$doc_index > tab$docLast &
                         para$doc_index < nextTable]
    footnotes <- utils::head(after, 4)
    adapted <- .ppDocxLines(tab$cells, caption = caption,
                            footnotes = footnotes)
    if (length(adapted$lines) < 2) next
    cand[[length(cand) + 1]] <- list(
      ordinal = t, lines = adapted$lines, lineTexts = adapted$lineTexts,
      capIdx = adapted$capIdx, caption = caption, capScore = capScore)
  }
  if (length(cand) == 0)
    stop("No usable table content found in ", docxFile, ".")

  # ---- Choose the winner: same rules as the PDF path ----------------------
  # A caption that clearly announces a baseline table beats any table
  # whose caption does not, however large; the parse score breaks ties
  # within a class (see parseBaselineTableHeuristics()).
  capScores <- vapply(cand, function(x) x$capScore, numeric(1))
  isStrong  <- capScores >= 3
  ordBase   <- order(-capScores, vapply(cand, `[[`, numeric(1), "ordinal"))
  ord  <- c(ordBase[isStrong[ordBase]], ordBase[!isStrong[ordBase]])
  cand <- cand[ord]
  strongOrdered <- isStrong[ord]

  tried <- 0L
  best <- NULL; bestScore <- -Inf; bestCand <- NULL; bestStrong <- FALSE
  for (i in seq_along(cand)) {
    cc <- cand[[i]]
    if (tried >= maxCandidates && bestScore > -Inf) break
    tried <- tried + 1L
    res <- tryCatch(
      .ppParseBlock(cc$lines, cc$lineTexts, cc$capIdx, trial, parenIsSD,
                    roundObsDelta, function(...) invisible(NULL),
                    textCands = textCands, textTotals = textTotals,
                    pctApprox = pctApprox),
      error = function(e) NULL)
    sc <- .ppParseScore(res)
    if (!is.finite(sc)) next
    sc <- sc + 2 * cc$capScore
    better <- if (strongOrdered[i] != bestStrong) strongOrdered[i] else
      sc > bestScore
    if (better) {
      bestScore <- sc; best <- res; bestCand <- cc
      bestStrong <- strongOrdered[i]
    }
  }
  if (is.null(best))
    stop("No usable baseline table could be parsed from ", docxFile, ".")

  say("Table ", bestCand$ordinal, " of ", length(doc$tables),
      " in the document",
      if (!is.na(bestCand$caption))
        paste0(": \"", substr(bestCand$caption, 1, 60), "\"") else "")
  say("Parsed ", length(unique(best$data$ROW)), " variable(s) x ",
      nrow(best$arms), " arm(s) = ", nrow(best$data), " template lines.")
  if (nrow(best$skipped) > 0) {
    say("SKIPPED ", nrow(best$skipped), " line(s) - review these by hand:")
    for (s in seq_len(nrow(best$skipped)))
      say("  - ", best$skipped$label[s], ": ", best$skipped$reason[s])
  }

  structure(
    list(data       = best$data,
         arms       = best$arms,
         skipped    = best$skipped,
         provenance = data.frame(ROW = best$data$ROW,
                                 ENGINE = rep("heuristic", nrow(best$data)),
                                 stringsAsFactors = FALSE),
         # table ordinal, not a page - a .docx has no pages
         pages      = bestCand$ordinal,
         caption    = bestCand$caption,
         trial      = trial,
         layout     = "docx",
         dispersion = best$dispersion,
         armNSource = best$armNSource,
         derivedCounts = best$derivedCounts,
         approxCounts  = best$approxCounts,
         derivedCells  = best$derivedCells,
         engine     = "heuristic-docx"),
    class = "ParsePDFTable")
}
