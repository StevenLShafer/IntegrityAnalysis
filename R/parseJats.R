# parseJats.R - baseline tables from JATS XML (PubMed Central, Europe
# PMC, medRxiv MECA, and whatever a publisher's production system emits).
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction: "should the parser handle xml? It is possible that   #
# publishers would prefer to communicate over the API using xml than any   #
# of the supported formats." Scoped as issue 29.                           #
#                                                                          #
# WHY THIS EXISTS, in one measurement. Of the 13,113 registry-linked       #
# papers that exist in PubMed Central, 3,208 are author manuscripts and    #
# only 160 of those carry a PDF. They are XML or nothing - and they are    #
# the ones most worth having, because an author manuscript holds the       #
# baseline table as submitted while ClinicalTrials.gov holds the           #
# sponsor's own structured values for the same trial. That pairing is      #
# ground truth by construction for the parser itself.                      #
#                                                                          #
# XML IS ALSO BETTER INPUT. No column clustering, no caption scoring       #
# against page geometry, no OCR, no decimal recovered from a glyph. A      #
# JATS table is real <tr>/<td>; the only interpretation left is the one    #
# we actually want to test - what the numbers mean.                        #
#                                                                          #
# THE ENGINE IS UNCHANGED. .ppDocxLines() already converts a cell matrix   #
# into the synthetic coordinates .ppParseBlock() consumes, so mean+/-SD,   #
# n (%), footnote-driven SD-vs-SE disambiguation, arm-N recovery and       #
# every skip reason work here exactly as they do for .docx and PDF. This   #
# file is extraction and plumbing.                                         #
#                                                                          #
# MEASURED AGAINST 42 REAL TABLES in 14 PMC author manuscripts             #
# (2026-08-30) rather than against the JATS specification, because         #
# publishers use far less of it than the specification permits:            #
#                                                                          #
#   <label>              98%     <thead>               100%               #
#   <caption>            93%     <table-wrap-foot>      83%               #
#   caption text in <p>  93%     caption in <title>      0%               #
#   colspan > 1          60%     ROWSPAN > 1            36%               #
#                                                                          #
# THE ROWSPAN FINDING IS THE IMPORTANT ONE and it is why this file is      #
# not a thin wrapper. In .docx a vertically merged cell still emits a      #
# placeholder <w:tc>, so column alignment survives without anyone          #
# thinking about it. JATS emits nothing: a rowspan="2" cell appears once   #
# and the next row simply carries one fewer <td>. Without carry-over,      #
# every cell after it shifts LEFT by one column - silently, in 36% of      #
# real tables. Ragged declared row widths were measured at exactly the     #
# rowspan rate, which is that failure already visible in the data.         #
#                                                                          #
# SECURITY. XML carries two attacks a PDF does not. "Billion laughs" is    #
# nested entity definitions expanding a sub-kilobyte file into gigabytes;  #
# XXE is <!ENTITY x SYSTEM "file:///etc/passwd"> making the parser read    #
# local files or forward requests. libxml2 defends against both BY         #
# DEFAULT. The entire risk is in options that switch the defence off -     #
# NOENT, DTDLOAD, and above all HUGE, which is the one someone adds to     #
# get past a "document too large" complaint. This file passes NOBLANKS     #
# and nothing else, tools/securityCheck.R fails the build if the           #
# dangerous options ever appear, and parseBaselineTableFiles() runs each   #
# document in its own subprocess so that what remains kills a child        #
# rather than the app.                                                     #
############################################################################

#' Read a JATS document with the safe parser options only.
#'
#' NOBLANKS is passed and nothing else. Never add HUGE, NOENT or
#' DTDLOAD: see the header, and the tripwire in tools/securityCheck.R.
#' @noRd
.ppJatsRead <- function(file) {
  if (!requireNamespace("xml2", quietly = TRUE))
    stop("Package 'xml2' is required: install.packages('xml2')")
  doc <- tryCatch(xml2::read_xml(file, options = "NOBLANKS"),
                  error = function(e)
                    stop("Could not read ", file, " as XML: ",
                         conditionMessage(e), call. = FALSE))
  # Publishers declare xlink and mml (on attributes); JATS elements
  # themselves are unprefixed, so plain XPath works. Stripping anyway
  # costs nothing and makes the XPath below immune to a publisher who
  # puts JATS in a default namespace.
  xml2::xml_ns_strip(doc)
  doc
}

#' One <table-wrap> to a character matrix, spans expanded.
#'
#' Two span rules, and they differ deliberately:
#'
#' COLSPAN follows the .docx convention exactly (R/parseDocx.R): the
#' text lands in the first spanned column, and is REPLICATED across the
#' rest only when it carries an arm size ("Treatment (n = 50)" over its
#' subcolumns), so each spanned column keeps its N. Anything else
#' spanned leaves empty cells, which the engine already tolerates.
#'
#' ROWSPAN has no .docx equivalent to copy. A spanning cell occupies
#' later rows that contain no markup for it at all, so this carries a
#' per-column countdown forward and emits an empty placeholder while it
#' is live. Without that, later cells shift left - see the header.
#' @noRd
.ppJatsMatrix <- function(tw) {
  rows <- xml2::xml_find_all(tw, ".//tr")
  if (length(rows) == 0) return(NULL)
  out <- list()
  carry <- integer(0)          # per column: rows still occupied above
  for (tr in rows) {
    cells <- xml2::xml_find_all(tr, "./td|./th")
    line <- character(0)
    col <- 1L
    for (cell in cells) {
      # Step over any column still covered by a rowspan from above.
      while (length(carry) >= col && carry[col] > 0L) {
        line[col] <- ""
        carry[col] <- carry[col] - 1L
        col <- col + 1L
      }
      txt <- .ppSquish(xml2::xml_text(cell))
      cs <- suppressWarnings(as.integer(xml2::xml_attr(cell, "colspan")))
      rs <- suppressWarnings(as.integer(xml2::xml_attr(cell, "rowspan")))
      if (is.na(cs) || cs < 1L) cs <- 1L
      if (is.na(rs) || rs < 1L) rs <- 1L
      line[col] <- txt
      if (cs > 1L) {
        repl <- if (grepl("(?i)n\\s*=\\s*\\d", txt, perl = TRUE)) txt else ""
        line[col + seq_len(cs - 1L)] <- repl
      }
      if (rs > 1L)
        for (k in seq_len(cs)) {
          j <- col + k - 1L
          if (length(carry) < j) carry <- c(carry, integer(j - length(carry)))
          carry[j] <- rs - 1L
        }
      col <- col + cs
    }
    # Trailing columns still covered from above.
    while (length(carry) >= col && carry[col] > 0L) {
      line[col] <- ""
      carry[col] <- carry[col] - 1L
      col <- col + 1L
    }
    line[is.na(line)] <- ""
    out[[length(out) + 1L]] <- line
  }
  nc <- max(lengths(out))
  if (!is.finite(nc) || nc == 0) return(NULL)
  mat <- matrix("", nrow = length(out), ncol = nc)
  for (r in seq_along(out)) if (length(out[[r]])) mat[r, seq_along(out[[r]])] <- out[[r]]
  mat
}

#' Tables, captions, footnotes and body text from a JATS document.
#' @noRd
.ppJatsData <- function(file) {
  doc <- .ppJatsRead(file)
  tws <- xml2::xml_find_all(doc, "//table-wrap")
  tables <- list()
  for (i in seq_along(tws)) {
    tw <- tws[[i]]
    mat <- .ppJatsMatrix(tw)
    if (is.null(mat) || nrow(mat) < 2) next
    # Caption: <label> ("Table 1.") plus <caption>'s paragraphs. Both
    # were present in 98% and 93% of real tables; <title> in none, so it
    # is read only as a fallback rather than assumed.
    lab <- .ppSquish(xml2::xml_text(xml2::xml_find_first(tw, "./label")))
    capNode <- xml2::xml_find_first(tw, "./caption")
    cap <- ""
    if (!inherits(capNode, "xml_missing")) {
      ps <- xml2::xml_find_all(capNode, ".//p|.//title")
      cap <- .ppSquish(paste(vapply(ps, xml2::xml_text, character(1)),
                             collapse = " "))
      if (!nzchar(cap)) cap <- .ppSquish(xml2::xml_text(capNode))
    }
    caption <- .ppSquish(paste(c(lab, cap), collapse = " "))
    foot <- xml2::xml_find_all(tw, ".//table-wrap-foot//p")
    footnotes <- vapply(foot, function(n) .ppSquish(xml2::xml_text(n)),
                        character(1))
    tables[[length(tables) + 1L]] <- list(
      cells = mat, caption = if (nzchar(caption)) caption else NA_character_,
      footnotes = utils::head(footnotes[nzchar(footnotes)], 6),
      ordinal = i)
  }
  # Body text for arm-N recovery. Table content is excluded: a number
  # inside the table is not independent evidence of the arm sizes the
  # same table is being asked to supply.
  body <- xml2::xml_find_all(doc, "//body//p[not(ancestor::table-wrap)]")
  fullText <- vapply(body, function(n) .ppSquish(xml2::xml_text(n)),
                     character(1))
  list(tables = tables, fullText = fullText[nzchar(fullText)])
}

#' Parse a baseline table out of a JATS XML document
#'
#' @param xmlFile path to a JATS XML file (PubMed Central, Europe PMC,
#'   or the `content/<id>.xml` inside a medRxiv MECA package).
#' @param trial trial label; defaults to the file name.
#' @param parenIsSD,roundObsDelta,maxCandidates,pctApprox,quiet as in
#'   [parseBaselineTableHeuristics()].
#' @return a `ParsePDFTable`, with `pages` carrying the table's ordinal
#'   (XML has no pages) and `layout` "jats".
#' @export
parseBaselineTableJats <- function(xmlFile,
                                   trial = tools::file_path_sans_ext(basename(xmlFile)),
                                   parenIsSD     = c("auto", "sd", "percent"),
                                   roundObsDelta = 1,
                                   maxCandidates = 6,
                                   pctApprox     = FALSE,
                                   quiet         = FALSE) {
  parenIsSD <- match.arg(parenIsSD)
  say <- function(...) if (!quiet) message(...)

  doc <- .ppJatsData(xmlFile)
  if (length(doc$tables) == 0)
    stop("No usable <table-wrap> content in ", xmlFile,
         " - the baseline table must be XML markup. A table supplied",
         " only as a <graphic> has no text to read; upload the PDF so",
         " the OCR path can see it.")

  textCands  <- .ppArmNCandidatesFromText(doc$fullText)
  textTotals <- .ppRandomizedTotals(doc$fullText)

  cand <- list()
  for (t in seq_along(doc$tables)) {
    tab <- doc$tables[[t]]
    capScore <- if (is.na(tab$caption)) 0 else .ppCaptionScore(tab$caption)
    if (!is.finite(capScore)) capScore <- 0
    adapted <- .ppDocxLines(tab$cells, caption = tab$caption,
                            footnotes = tab$footnotes)
    if (length(adapted$lines) < 2) next
    cand[[length(cand) + 1L]] <- list(
      ordinal = tab$ordinal, lines = adapted$lines,
      lineTexts = adapted$lineTexts, capIdx = adapted$capIdx,
      caption = tab$caption, capScore = capScore)
  }
  if (length(cand) == 0)
    stop("No usable table content could be read from ", xmlFile, ".")

  # Winner selection is the PDF and .docx rule, unchanged: a caption
  # that clearly announces a baseline table beats any table whose
  # caption does not, however large; parse score breaks ties within a
  # class.
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
    stop("No usable baseline table could be parsed from ", xmlFile, ".")

  say("Table ", bestCand$ordinal,
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
         # table ordinal, not a page - XML has no pages
         pages      = bestCand$ordinal,
         caption    = bestCand$caption,
         trial      = trial,
         layout     = "jats",
         dispersion = best$dispersion,
         armNSource = best$armNSource,
         derivedCounts = best$derivedCounts,
         approxCounts  = best$approxCounts,
         derivedCells  = best$derivedCells,
         engine     = "heuristic-jats"),
    class = "ParsePDFTable")
}
