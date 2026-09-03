# parseTatr.R - the Table Transformer + tesseract seam of the deterministic
# engine: geometry from a neural table detector, characters from the PDF's
# own text layer or, on a scanned page, from local OCR.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-02 by Claude Code (model Claude Fable 5.1) at Steve      #
# Shafer's direction: "Add tatr-tesseract to pdf parser workflow." The    #
# run-along it builds on (python/tatr/tatrTables.py, PR #137) had         #
# measured the case: on the 147 corpus articles whose text layer the       #
# engine reads and whose table it still cannot grid, TATR located a       #
# griddable table in 84% of those that have one; and it located tables    #
# on 97% of scanned pages with no text layer at all, where tesseract can  #
# supply the characters. Verified by tests/testthat/test-tatr.R against   #
# hand-built TATR XML for the synthetic PDFs, and measured on the corpus  #
# runs recorded in the PR.                                                 #
############################################################################
#
# THE DESIGN, in one sentence: a TATR table is already a grid of cells, so
# this file does what parseDocx.R does for a Word table - fabricates the
# word-coordinate `lines` the PDF engine's .ppParseBlock() expects through
# the SAME .ppDocxLines() adapter, and feeds it in verbatim - which buys
# every cell rule for free and changes nothing in the most heavily pinned
# code in the package.
#
# Where the characters come from:
#   - A page WITH a text layer: the XML already carries each cell's text,
#     assigned by the Python side from the same text layer poppler reads.
#   - A page WITHOUT one (a scan): the XML carries empty cells and their
#     boxes (tatrTables.py --write-empty). .ppOcrData() reads the page
#     with tesseract, and .ppTatrFillCells() assigns each OCR word to the
#     cell holding at least half of its box - the same rule the Python
#     side applies to text-layer words. Provenance is then "ocr", so the
#     app shades the whole table cyan exactly as it does for tier 2.
#
# What TATR must never do: decide WHICH table is the baseline table. It
# claimed one in a third of articles that have none (README). Selection
# stays with the engine's own caption scoring and parse scoring, run over
# every table the model found, exactly as the docx path does.
#
# What runs where. The model is PyTorch, pegged to weight revisions and
# library versions (python/tatr/README.md); it is available where
# tools/tatrProvision.sh has been run (the Linux nodes, a Docker image) and
# absent on shinyapps.io. So this seam is a RESCUE TIER that engages only
# when a TATR XML is supplied, or the runner finds its Python (see
# .ppTatrPython): with neither, parseBaselineTable() behaves exactly as
# before. Deterministic and offline either way - the weights load with
# local_files_only and same input gives same output.
#
# Security (AGENTS.md threat model - the manuscript author is the
# adversary): the runner hands the uploaded PDF to a Python process that
# decodes it with pdfium and pdfminer - two more decoders on hostile
# bytes - so it runs as a subprocess under an OS timeout, never in the
# worker, and inherits the memory-ceiling gap recorded as ISSUES 32. The
# XML it returns is parsed as data by xml2 and nothing in it is evaluated.

# ---------------------------------------------------------------------------
# Reading a TATR XML
# ---------------------------------------------------------------------------

# One tatr-tables file -> a list of tables. Geometry is converted from the
# renderer's pixels to PDF points (top-left origin, like pdf_data), so the
# boxes and the engine's word coordinates share a frame.
.ppReadTatr <- function(xmlFile) {
  doc <- xml2::read_xml(xmlFile)
  if (xml2::xml_name(doc) != "tatr-tables")
    stop("Not a Table Transformer file: ", basename(xmlFile), call. = FALSE)
  dpi <- suppressWarnings(as.numeric(xml2::xml_attr(doc, "render-dpi")))
  if (is.na(dpi) || dpi <= 0) dpi <- 150
  k <- 72 / dpi
  boxOf <- function(node) {
    v <- suppressWarnings(as.numeric(c(xml2::xml_attr(node, "x0"),
                                       xml2::xml_attr(node, "y0"),
                                       xml2::xml_attr(node, "x1"),
                                       xml2::xml_attr(node, "y1")))) * k
    names(v) <- c("x0", "y0", "x1", "y1")
    v
  }
  boxes <- function(nodes) {
    if (!length(nodes)) return(NULL)
    idx <- suppressWarnings(as.integer(xml2::xml_attr(nodes, "index")))
    m <- do.call(rbind, lapply(nodes, boxOf))
    if (!anyNA(idx)) m <- m[order(idx), , drop = FALSE]
    m
  }
  lapply(xml2::xml_find_all(doc, "./table-wrap"), function(tw) {
    a <- function(n, x = tw) xml2::xml_attr(x, n)
    trs <- xml2::xml_find_all(tw, "./table/tbody/tr")
    nr <- suppressWarnings(as.integer(a("rows"))); nc <- suppressWarnings(as.integer(a("cols")))
    if (is.na(nr)) nr <- length(trs)
    if (is.na(nc)) nc <- max(0L, vapply(trs, function(tr)
      length(xml2::xml_find_all(tr, "./td")), integer(1)))
    cells <- matrix("", max(nr, 0L), max(nc, 0L))
    headRows <- integer(0)
    for (tr in trs) {
      r <- suppressWarnings(as.integer(a("row", tr))) + 1L
      if (is.na(r) || r < 1 || r > nr) next
      if (identical(a("header", tr), "true")) headRows <- c(headRows, r)
      for (td in xml2::xml_find_all(tr, "./td")) {
        cl <- suppressWarnings(as.integer(a("col", td))) + 1L
        if (!is.na(cl) && cl >= 1 && cl <= nc) cells[r, cl] <- xml2::xml_text(td)
      }
    }
    geo <- xml2::xml_find_first(tw, "./geometry")
    list(id       = a("id"),
         page     = suppressWarnings(as.integer(a("page"))),
         score    = suppressWarnings(as.numeric(a("detection-score"))),
         keep     = identical(a("passed-plausibility"), "true"),
         cells    = cells,
         headRows = headRows,
         box      = boxOf(xml2::xml_find_first(geo, "./table-box")),
         rowBoxes = boxes(xml2::xml_find_all(geo, "./row-box")),
         colBoxes = boxes(xml2::xml_find_all(geo, "./col-box")))
  })
}

# ---------------------------------------------------------------------------
# Words into cells
# ---------------------------------------------------------------------------

# Page words (points, top-left origin: text/x/y/width/height, the shape
# .ppPdfData() and .ppOcrData() both return) into a table's cells: a word
# belongs to the cell holding at least HALF of its box, in reading order -
# the rule tatrTables.py applies to text-layer words. A cell is a row band
# crossed with a column band, so the overlap is the product of two 1-D
# overlaps and no cell rectangles need building.
.ppTatrFillCells <- function(tbl, words) {
  rb <- tbl$rowBoxes; cb <- tbl$colBoxes
  nr <- if (is.null(rb)) 0L else nrow(rb); nc <- if (is.null(cb)) 0L else nrow(cb)
  cells <- matrix("", nr, nc)
  if (nr == 0 || nc == 0 || is.null(words) || !nrow(words)) return(cells)
  wx0 <- words$x; wy0 <- words$y
  wx1 <- words$x + words$width
  wy1 <- words$y + if (is.null(words$height)) 8 else words$height
  area <- pmax(wx1 - wx0, 0) * pmax(wy1 - wy0, 0)
  ovRow <- vapply(seq_len(nr), function(r)
    pmax(0, pmin(wy1, rb[r, "y1"]) - pmax(wy0, rb[r, "y0"])), numeric(length(wx0)))
  ovCol <- vapply(seq_len(nc), function(cl)
    pmax(0, pmin(wx1, cb[cl, "x1"]) - pmax(wx0, cb[cl, "x0"])), numeric(length(wx0)))
  ovRow <- matrix(ovRow, ncol = nr); ovCol <- matrix(ovCol, ncol = nc)
  r  <- max.col(ovRow, ties.method = "first")
  cl <- max.col(ovCol, ties.method = "first")
  inter <- ovRow[cbind(seq_along(r), r)] * ovCol[cbind(seq_along(cl), cl)]
  ok <- area > 0 & inter / area >= 0.5
  # Reading order within a cell: group the words into lines by their
  # vertical CENTRES (a new line when the gap exceeds 3 pt), then x. Not
  # by their tops - tesseract boxes a small glyph ("=", the plus-minus) a
  # couple of points lower than the digits beside it, and top-first
  # ordering wrote "(n 15) =" and "45.3 12.1 +-"; fixed bands split
  # "Type of surgery" at a band edge (both found by the fixture,
  # 2026-09-02). Centres of glyphs on one line agree to a point or two.
  mid <- (wy0 + wy1) / 2
  for (key in unique(paste(r[ok], cl[ok]))) {
    idx <- which(ok)[paste(r[ok], cl[ok]) == key]
    o <- idx[order(mid[idx])]
    lineId <- cumsum(c(1, diff(mid[o]) > 3))
    o <- o[order(lineId, wx0[o])]
    cells[r[o[1]], cl[o[1]]] <- paste(words$text[o], collapse = " ")
  }
  cells
}

# The caption and footnotes of a table, from the page's own words: the
# best-scoring "Table N" anchor line that sits above the table (within
# 120 pt) or level with its top (a side caption), and up to four lines
# directly beneath it. The engine's stop-pattern and "a (b)" machinery
# reads the footnotes exactly as it does for a PDF block.
.ppTatrCaption <- function(tbl, pageWords) {
  none <- list(caption = NA_character_, capScore = 0, footnotes = character(0))
  if (is.null(pageWords) || !nrow(pageWords) || anyNA(tbl$box)) return(none)
  lines <- .ppBuildLines(pageWords)
  if (!length(lines)) return(none)
  lt <- vapply(lines, .ppLineText, character(1))
  ly <- vapply(lines, function(L) min(L$y), numeric(1))
  anchors <- .ppCaptionAnchors(pageWords)
  caption <- NA_character_; best <- -Inf
  for (a in seq_len(nrow(anchors))) {
    if (anchors$y[a] > tbl$box[["y1"]] || anchors$y[a] < tbl$box[["y0"]] - 120) next
    li <- which.min(abs(ly - anchors$y[a]))
    s <- .ppCaptionScore(lt[li])
    if (s > best) { best <- s; caption <- lt[li] }
  }
  below <- which(ly > tbl$box[["y1"]] & ly < tbl$box[["y1"]] + 60)
  list(caption = caption, capScore = if (is.finite(best)) best else 0,
       footnotes = utils::head(lt[below], 4))
}

# ---------------------------------------------------------------------------
# The parse
# ---------------------------------------------------------------------------

#' Parse a baseline table using Table Transformer geometry
#'
#' The Table Transformer counterpart of [parseBaselineTableHeuristics()]:
#' the table's rows and columns come from the model's detections (a
#' `*.tatr.xml` written by `python/tatr/tatrTables.py`), the characters
#' from the PDF's text layer or, on a page with none, from local OCR
#' (tesseract). Every table the model found is a candidate; the engine's
#' own caption and parse scoring choose the winner. Deterministic and
#' offline.
#'
#' @param pdfFile path to the PDF.
#' @param tatrXml path to the Table Transformer XML for that PDF.
#' @param ocr `"auto"` reads pages with no text layer through tesseract,
#'   `"always"` reads every table's page through tesseract, `"never"`
#'   uses only the text the XML carries.
#' @inheritParams parseBaselineTableHeuristics
#' @return A `ParsePDFTable`, as [parseBaselineTableHeuristics()] returns
#'   it, with `layout = "tatr"` and `engine` `"heuristic-tatr"` or, when
#'   the winning table was read by OCR, `"heuristic-tatr-ocr"` (rows then
#'   carry `"ocr"` provenance and the app shades them cyan).
#' @export
parseBaselineTableTatr <- function(pdfFile, tatrXml,
                                   trial         = tools::file_path_sans_ext(basename(pdfFile)),
                                   parenIsSD     = c("auto", "sd", "percent"),
                                   roundObsDelta = 1,
                                   maxCandidates = 6,
                                   pctApprox     = FALSE,
                                   ocr           = c("auto", "never", "always"),
                                   ocrDpi        = 300,
                                   quiet         = FALSE) {
  parenIsSD <- match.arg(parenIsSD)
  ocr <- match.arg(ocr)
  say <- function(...) if (!quiet) message(...)

  tbls <- .ppReadTatr(tatrXml)
  if (!length(tbls))
    stop("The Table Transformer found no tables in ", basename(pdfFile), ".",
         call. = FALSE)

  pageTexts <- tryCatch(.ppPdfText(pdfFile), error = function(e) character(0))
  imgPages  <- if (length(pageTexts)) .ppImageOnlyPages(pageTexts) else integer(0)
  allWords  <- tryCatch(.ppPdfData(pdfFile), error = function(e) list())
  textCands  <- .ppArmNCandidatesFromText(pageTexts)
  textTotals <- .ppRandomizedTotals(pageTexts)

  # OCR once per page, only for pages that need it
  ocrCache <- list()
  ocrWords <- function(p) {
    key <- as.character(p)
    if (is.null(ocrCache[[key]]))
      ocrCache[[key]] <<- tryCatch(.ppOcrData(pdfFile, dpi = ocrDpi, pages = p)[[1]],
                                   error = function(e) NULL)
    ocrCache[[key]]
  }

  cand <- list()
  for (t in seq_along(tbls)) {
    tb <- tbls[[t]]
    if (is.na(tb$page)) next
    useOcr <- ocr == "always" || (ocr == "auto" && tb$page %in% imgPages)
    if (useOcr && !requireNamespace("tesseract", quietly = TRUE)) next
    # A text-layer table the gate rejected is a prose block - skip it. A
    # rejected table on a scanned page is the opposite: its cells are
    # empty because there was nothing to read, and OCR fills them.
    if (!useOcr && !tb$keep) next
    pw  <- if (useOcr) ocrWords(tb$page)
           else if (tb$page <= length(allWords)) allWords[[tb$page]] else NULL
    mat <- if (useOcr) .ppTatrFillCells(tb, pw) else tb$cells
    if (!length(mat) || !any(nzchar(.ppSquish(mat)))) next
    cap <- .ppTatrCaption(tb, pw)
    caption <- cap$caption; capScore <- cap$capScore
    # The detection box often includes the caption as a lone first-row
    # cell; promote it, as the docx path does, rather than let it trip
    # the engine's next-table stop pattern.
    while (nrow(mat) > 0) {
      nz <- which(nzchar(.ppSquish(mat[1, ])))
      first <- if (length(nz) == 1) .ppSquish(mat[1, nz[1]]) else ""
      if (nzchar(first) &&
          grepl("(?i)^(table|tab\\.?)\\s+([0-9]{1,2}|[IVXLivxl]{1,4})\\b",
                first, perl = TRUE)) {
        cs <- .ppCaptionScore(first)
        if (cs >= capScore || is.na(caption)) { capScore <- cs; caption <- first }
        mat <- mat[-1, , drop = FALSE]
      } else break
    }
    adapted <- .ppDocxLines(mat, caption = caption, footnotes = cap$footnotes)
    if (length(adapted$lines) < 2) next
    cand[[length(cand) + 1]] <- list(
      ordinal = t, page = tb$page, ocr = useOcr, score = tb$score,
      lines = adapted$lines, lineTexts = adapted$lineTexts,
      capIdx = adapted$capIdx, caption = caption, capScore = capScore)
  }
  if (length(cand) == 0)
    stop("None of the Table Transformer's ", length(tbls), " table(s) in ",
         basename(pdfFile), " carried readable cells.", call. = FALSE)

  # ---- Choose the winner: the docx path's rules, which are the PDF path's -
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
    stop("No usable baseline table could be parsed from the Table ",
         "Transformer's geometry for ", basename(pdfFile), ".", call. = FALSE)

  say("Table Transformer table ", bestCand$ordinal, " of ", length(tbls),
      " (page ", bestCand$page, if (bestCand$ocr) ", read by OCR" else "", ")",
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
                                 ENGINE = rep(if (bestCand$ocr) "ocr" else "tatr",
                                              nrow(best$data)),
                                 stringsAsFactors = FALSE),
         pages      = bestCand$page,
         caption    = bestCand$caption,
         trial      = trial,
         layout     = "tatr",
         dispersion = best$dispersion,
         armNSource = best$armNSource,
         derivedCounts = best$derivedCounts,
         approxCounts  = best$approxCounts,
         derivedCells  = best$derivedCells,
         engine     = if (bestCand$ocr) "heuristic-tatr-ocr" else "heuristic-tatr"),
    class = "ParsePDFTable")
}

# ---------------------------------------------------------------------------
# Running the model
# ---------------------------------------------------------------------------

# The pegged Python (tools/tatrProvision.sh installs ~/tatrenv). Absent -
# shinyapps.io, a developer machine without torch - the seam stays out of
# the way and parseBaselineTable() behaves exactly as before.
.ppTatrPython <- function() {
  p <- Sys.getenv("INTEGRITY_TATR_PYTHON", "")
  if (nzchar(p) && file.exists(p)) return(p)
  for (cand in path.expand(c("~/tatrenv/bin/python", "~/tatrenv/Scripts/python.exe")))
    if (file.exists(cand)) return(cand)
  ""
}
.ppTatrScript <- function() {
  s <- Sys.getenv("INTEGRITY_TATR_SCRIPT", "")
  if (nzchar(s) && file.exists(s)) return(s)
  for (cand in c(file.path(getwd(), "python", "tatr", "tatrTables.py"),
                 path.expand("~/IntegrityAnalysis/python/tatr/tatrTables.py")))
    if (file.exists(cand)) return(cand)
  ""
}
.ppTatrAvailable <- function() nzchar(.ppTatrPython()) && nzchar(.ppTatrScript())

# Run the model over ONE PDF in a subprocess under an OS timeout and return
# the path of its XML, or NULL when it produced none (no table, a crash,
# the timeout). Offline by construction: the weights load with
# local_files_only, and --write-empty keeps the text-less geometry a
# scanned page needs.
.ppTatrRun <- function(pdfFile, timeout = 600, quiet = FALSE) {
  py <- .ppTatrPython(); sc <- .ppTatrScript()
  if (!nzchar(py) || !nzchar(sc)) return(NULL)
  work <- tempfile("tatr"); dir.create(work)
  acc  <- "upload"
  lst  <- file.path(work, "list.csv")
  writeLines(paste0(acc, ",", normalizePath(pdfFile, winslash = "/")), lst)
  out  <- file.path(work, "xml")
  if (!quiet) message("Running the Table Transformer over ", basename(pdfFile), " ...")
  status <- tryCatch(
    system2(py, c(shQuote(sc), "--list", shQuote(lst), "--out", shQuote(out),
                  "--manifest", shQuote(file.path(work, "manifest.csv")),
                  "--threads", "1", "--write-empty"),
            stdout = FALSE, stderr = FALSE, timeout = timeout),
    warning = function(w) 124L, error = function(e) 1L)
  xml <- file.path(out, paste0(acc, ".tatr.xml"))
  if (identical(status, 0L) && file.exists(xml)) xml else NULL
}
