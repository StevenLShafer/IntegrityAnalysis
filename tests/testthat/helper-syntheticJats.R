# Synthetic JATS fixtures, mirroring helper-syntheticDocx.R.
#
# Written from the structure MEASURED across 42 tables in 14 real PMC
# author manuscripts (2026-08-30), not from the JATS specification:
# <label> and <caption><p> carry the caption, <table-wrap-foot><p> the
# footnotes, and every cell carries explicit colspan/rowspan attributes
# even when they are 1 - which is why a probe that counted cells with a
# span attribute measured 100% and told us nothing.

#' Build a JATS article with one or more tables.
#'
#' @param file where to write.
#' @param tables list of lists: `caption`, `rows` (list of character
#'   vectors), optional `foot`, optional `spans` (a matrix of "cR" span
#'   specs the same shape as the row grid, e.g. "c2" or "r2").
#' @param prose paragraphs placed in <body> before the tables - the text
#'   arm-N recovery reads.
makeJatsArticle <- function(file, tables, prose = character(0)) {
  esc <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
  }
  cellsFor <- function(cells, spec) {
    out <- character(0)
    for (j in seq_along(cells)) {
      s <- if (is.null(spec)) "" else spec[j]
      cs <- if (!is.na(s) && grepl("^c", s)) sub("^c", "", s) else "1"
      rs <- if (!is.na(s) && grepl("^r", s)) sub("^r", "", s) else "1"
      out <- c(out, sprintf('<td colspan="%s" rowspan="%s">%s</td>',
                            cs, rs, esc(cells[j])))
    }
    paste(out, collapse = "")
  }
  tw <- character(0)
  for (t in tables) {
    rows <- character(0)
    for (i in seq_along(t$rows)) {
      spec <- if (!is.null(t$spans)) t$spans[[i]] else NULL
      rows <- c(rows, paste0("<tr>", cellsFor(t$rows[[i]], spec), "</tr>"))
    }
    foot <- if (is.null(t$foot)) "" else
      paste0("<table-wrap-foot>",
             paste(sprintf("<p>%s</p>", esc(t$foot)), collapse = ""),
             "</table-wrap-foot>")
    tw <- c(tw, sprintf(paste0('<table-wrap id="t%s"><label>%s</label>',
                               '<caption><p>%s</p></caption>',
                               '<table>%s</table>%s</table-wrap>'),
                        substr(digest_ish(t$caption), 1, 6),
                        esc(t$label %||% "Table 1."),
                        esc(t$caption), paste(rows, collapse = ""), foot))
  }
  body <- paste0(paste(sprintf("<p>%s</p>", esc(prose)), collapse = ""),
                 paste(tw, collapse = ""))
  writeLines(paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<article xmlns:xlink="http://www.w3.org/1999/xlink">',
    '<front><article-meta><title-group><article-title>Synthetic',
    '</article-title></title-group></article-meta></front>',
    '<body>', body, '</body></article>'), file, useBytes = TRUE)
  file
}

`%||%` <- function(a, b) if (is.null(a)) b else a
digest_ish <- function(x) paste0(sprintf("%02x", utf8ToInt(substr(x, 1, 1))), "0000")

#' A billion-laughs bomb: nested entities expanding to ~10^9 copies.
makeBillionLaughs <- function(file) {
  ent <- '<!ENTITY a0 "lol">'
  for (i in 1:9)
    ent <- paste0(ent, sprintf('<!ENTITY a%d "%s">', i,
                               paste(rep(sprintf("&a%d;", i - 1), 10),
                                     collapse = "")))
  writeLines(paste0('<?xml version="1.0"?><!DOCTYPE article [', ent,
                    ']><article><body><p>&a9;</p></body></article>'),
             file, useBytes = TRUE)
  file
}

#' An XXE probe: an external entity pointing at a local file whose
#' contents must NOT appear in anything the parser returns.
makeXxe <- function(file, secret) {
  writeLines(paste0(
    '<?xml version="1.0"?><!DOCTYPE article [',
    sprintf('<!ENTITY xxe SYSTEM "file:///%s">',
            gsub("\\\\", "/", normalizePath(secret, winslash = "/"))),
    ']><article><body><table-wrap><label>Table 1.</label>',
    '<caption><p>Baseline characteristics</p></caption><table>',
    '<tr><td>Age</td><td>&xxe;</td></tr>',
    '</table></table-wrap></body></article>'), file, useBytes = TRUE)
  file
}
