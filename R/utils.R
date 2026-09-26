# utils.R - small text and number helpers shared by both engines.
#
############################################################################
# Provenance                                                               #
# Ported 2026-08-15 by Claude Code (model: Claude Opus 5, Anthropic) at    #
# Steve Shafer's request, from parseCovariateTable.R in the               #
# Integrity-Analysis repository - which Claude Code (model: Claude Fable   #
# 5) drafted on 2026-08-14. The logic here is unchanged from that draft;   #
# the only edits were mechanical: the internal prefix `.pcv` became `.pp`, #
# and the original single file was split into utils.R / tokenize.R /       #
# pageLayout.R / parseBaselineTableHeuristics.R.                          #
#                                                                          #
# Everything in this file is deterministic - it calls no AI service.       #
# Status: run and verified by tests/testthat/test-utils.R.                #
############################################################################

# The plus-minus sign, kept here as an escape so that every source file in
# the package stays pure ASCII (R CMD check notes non-ASCII bytes in R/).
.ppPLUSMINUS <- "\u00b1"

# --------------------------------------------------------------------------
# Font-encoding repair
# --------------------------------------------------------------------------
# Some journals embed fonts whose glyphs are mapped to the wrong Unicode
# points, so poppler faithfully reports characters that are not what is
# printed. Anesthesiology is the worst: in its PDFs a printed "=" comes back
# as U+2AFD or U+2D1D and a printed "+/-" as U+2AFE - the ASCII forms never
# appear at all. That is invisible until you look, and it is fatal here,
# because "45 +/- 12" stops being a mean-and-SD cell and "(n = 20)" stops
# being an arm size. Repairing this recovers whole journals.
#
# Every entry below was read off surrounding context in the corpus rather
# than guessed - e.g. U+2AFE from "Data are presented as mean <U+2AFE> SD",
# U+2D1D from "20% mannitol (n <U+2D1D> 20)". A wrong entry would corrupt
# numbers silently, so anything ambiguous was left alone.
.ppGlyphMap <- c(
  "\u2afe" = "\u00b1",  # mean +/- SD
  "\u2afd" = "=",       # "osmolarity = ", "1 = perfectly relaxed"
  "\u2d1d" = "=",       # "(n = 20)"
  "\u2b0d" = "<",       # "P < 0.05"
  "\u2b0e" = ">",       # "> 150"
  "\u2afa" = "-",       # minus: "stored at -20 C", "kg-1"
  "\u2af9" = "+",       # "Ca2+"
  "\u2c55" = "\u2264",  # <=
  "\u2c56" = "\u2265",  # >=
  "\u2afb" = "\u00d7",  # multiplication sign
  "\u2d1b" = "\u00d7",
  "\u4860" = "\u00b7",  # middle dot, as in "kg-1 . min-1" and BJA decimals
  "\u242e" = "\u00b5",  # micro
  "\u2423" = "\u03b1", "\u2424" = "\u03b2",   # Greek, in labels only
  "\u2425" = "\u03b3", "\u2426" = "\u03b4",
  "\u2440" = "\u03b5",
  # BJA / EJA house font: "p \u00bc 0.04", "n \u00bc 503" - another "=".
  "\u00bc" = "=",
  # ...and its "fl" ligature, which turns desflurane into "des-urane".
  # Affects row labels only, never numbers.
  "\u00af" = "fl",
  # Windows Symbol-font private-use glyphs (2026-08-21, found by comparing
  # the deterministic run of 654 A&A submissions against an AI-only run):
  # Word documents that type "+/-" or "=" with the Symbol font export as
  # U+F0xx, where xx is the character's position in the Adobe Symbol
  # encoding - a fixed, documented mapping, not a per-document guess. The
  # cost of missing it is total: "47.7<U+F0B1>14.9" reads as one number, so
  # every mean/SD cell in the table vanishes (e.g. AA-D-15-01175), and
  # "(n <U+F03D> 59)" stops being an arm size. Each entry below was also
  # confirmed against printed context in the corpus: U+F0B1 from
  # "MAC was 1.86 <U+F0B1> 0.40%", U+F0A3 from "probability of <U+F0A3>
  # 0.05", U+F0B3 from "aged <U+F0B3> 45 years", U+F06D from
  # "<U+F06D>g/mL", U+F0B0 from "a distal 40<U+F0B0> angle".
  "\uf0b1" = "\u00b1",  # plus-minus
  "\uf03d" = "=",        # equals: "(n = 59)"
  "\uf0a3" = "\u2264",  # less-or-equal
  "\uf0b3" = "\u2265",  # greater-or-equal
  "\uf03c" = "<",
  "\uf03e" = ">",
  "\uf02b" = "+",
  "\uf02d" = "-",
  "\uf0b4" = "\u00d7",  # multiplication
  "\uf0d7" = "\u00b7",  # middle dot: "mg<U+F0D7>kg-1"
  "\uf0b0" = "\u00b0",  # degree
  "\uf06d" = "\u00b5",  # micro (Symbol mu, used in units)
  "\uf061" = "\u03b1", "\uf062" = "\u03b2",   # Greek, in labels only
  "\uf063" = "\u03c7", "\uf064" = "\u03b4",
  "\uf067" = "\u03b3", "\uf06c" = "\u03bb",
  "\uf070" = "\u03c0", "\uf072" = "\u03c1",
  "\uf073" = "\u03c3")

# Apply the repair to a character vector.
#
# Deliberately NOT chartr(): its "old" and "new" arguments are range
# specifications, so a map containing ">", "-" and "+" in sequence is read as
# the range ">-+" and the call fails. Fixed-string gsub has no such
# interpretation. Only strings that actually contain a non-ASCII byte are
# touched, which keeps the cost off the many PDFs that need no repair.
.ppNormalizeGlyphs <- function(x) {
  if (!length(x)) return(x)
  hit <- grepl("[^\x01-\x7F]", x)
  if (!any(hit)) return(x)
  for (i in seq_along(.ppGlyphMap))
    x[hit] <- gsub(names(.ppGlyphMap)[i], .ppGlyphMap[[i]], x[hit], fixed = TRUE)
  x
}

# pdftools wrappers that apply the repair at the point of reading, so no
# caller has to remember to do it.
# Some documents use U+00B1 - a real plus-minus character - where an EN DASH
# is printed. British Journal of Anaesthesia's 2003 volumes do this
# throughout: "pages 502<pm>6", "propofol 1.5<pm>2.5 mg kg<pm>1",
# "Creutzfeldt<pm>Jakob disease". Left alone, the tokenizer reads "1.5<pm>2.5"
# as a mean of 1.5 with an SD of 2.5 and INVENTS a baseline value, which is
# far worse than missing one.
#
# The tell is a plus-minus with a LETTER ON BOTH SIDES: hyphenated words
# ("Creutzfeldt<pm>Jakob", "non<pm>selective") occur only when the glyph is
# really a dash, and the BJA genre produces dozens of them. One-sided
# contact is NOT evidence (revised 2026-08-21, found by comparing the
# deterministic run of 654 A&A submissions against an AI-only run): a real
# plus-minus legitimately touches a letter on one side in "BP<pm>20 mm Hg"
# (the Aldrete score definition) - that pattern flipped this heuristic and
# rewrote every genuine plus-minus in AA-D-13-00678, erasing the whole
# baseline table. Two two-sided occurrences are taken as proof for the
# whole document, and every plus-minus in it is then read as a dash.
.ppPlusMinusIsDash <- function(txt) {
  if (!length(txt)) return(FALSE)
  j <- paste(txt, collapse = " ")
  # "mean±SD" written without surrounding spaces is NOTATION, not a dash.
  # An A&A submission wrote it that way twice, the two letter-contacts
  # counted as proof, and every genuine plus-minus in its table was then
  # rewritten to a hyphen - twenty real mean/SD cells destroyed by a repair
  # aimed at a different journal's font. Notation contexts are discounted
  # before the evidence is counted (2026-08-20).
  j <- gsub(paste0("(?i)\\b(means?|medians?)\\s*", .ppPLUSMINUS), " ", j,
            perl = TRUE)
  j <- gsub(paste0("(?i)", .ppPLUSMINUS,
                   "\\s*((sd|sem|se)\\b|s\\.d\\.|s\\.e\\.m?\\.)"), " ", j,
            perl = TRUE)
  pat <- paste0("[A-Za-z]", .ppPLUSMINUS, "[A-Za-z]")
  m   <- gregexpr(pat, j)[[1]]
  if (m[1] == -1) return(FALSE)
  length(m) >= 2
}

# Typographic spaces that poppler does NOT split words on. Springer sets
# "Table 1" + EN SPACE + THIN SPACE + caption text, so the numeral and the
# first caption word arrive as ONE token ("1  Baseline"); the caption
# anchor - the word "Table" followed by a word that IS a numeral - then
# never matches, the document's real Table 1 never becomes a candidate,
# and the parser falls back on cross-reference mentions and returns
# prose (Steve's ticagrelor article, Springer 10072_2022_6525,
# 2026-09-02: 36 lines of ground truth, 1 variable parsed).
#
# Built with intToUtf8 rather than \u escapes so that no editing tool
# can quietly turn the escapes into characters or eat a backslash.
# U+2000-U+200A are the en/em/thin/hair family, U+202F the narrow
# no-break space, U+205F the medium mathematical space, U+3000 the
# ideographic space. NBSP (U+00A0) is deliberately ABSENT: it is the
# thousands separator of "1 000" in several journals, and splitting it
# would shred numbers that today at least stay in one piece.
.ppUNISPACE <- sprintf("[%s]+", intToUtf8(c(0x2000:0x200a, 0x202f,
                                            0x205f, 0x3000)))

# Split every token holding such a space into the words poppler would
# have delivered had the space been an ordinary one, apportioning the
# token's box by character count (each gap counted as one character).
.ppSplitUnicodeSpaces <- function(d) {
  has <- grepl(.ppUNISPACE, d$text, perl = TRUE)
  if (!any(has)) return(d)
  rows <- vector("list", nrow(d))
  for (i in seq_len(nrow(d))) {
    if (!has[i]) { rows[[i]] <- d[i, , drop = FALSE]; next }
    txt <- d$text[i]
    # the parts by their TRUE character offsets, so a run of several
    # spaces (Springer's en + thin) is measured as the characters it is,
    # not as one boundary (CodeRabbit on #146)
    m        <- gregexpr(.ppUNISPACE, txt, perl = TRUE)[[1]]
    sepStart <- as.integer(m); sepLen <- attr(m, "match.length")
    starts   <- c(1L, sepStart + sepLen)
    ends     <- c(sepStart - 1L, nchar(txt))
    keep     <- ends >= starts
    starts <- starts[keep]; ends <- ends[keep]
    parts  <- substring(txt, starts, ends)
    if (length(parts) <= 1) {
      one <- d[i, , drop = FALSE]
      one$text <- if (length(parts)) parts else ""
      rows[[i]] <- one
      next
    }
    n   <- nchar(txt)
    out <- d[rep(i, length(parts)), , drop = FALSE]
    out$text  <- parts
    out$x     <- d$x[i] + d$width[i] * (starts - 1) / n
    out$width <- d$width[i] * (ends - starts + 1) / n
    rows[[i]] <- out
  }
  do.call(rbind, rows)
}

.ppPdfData <- function(pdfFile) {
  pg   <- pdftools::pdf_data(pdfFile)
  txt  <- unlist(lapply(pg, function(d) if (nrow(d)) d$text else character(0)))
  dash <- .ppPlusMinusIsDash(.ppNormalizeGlyphs(txt))
  lapply(pg, function(d) {
    if (nrow(d)) {
      d <- .ppSplitUnicodeSpaces(d)
      d$text <- .ppNormalizeGlyphs(d$text)
      if (dash) d$text <- gsub(.ppPLUSMINUS, "-",d$text, fixed = TRUE)
    }
    d
  })
}

# Word boxes from OCR, in the same shape .ppPdfData() returns, so a scanned
# article can go through the identical pipeline.
#
# The units matter. pdf_ocr_data() reports pixels at the rendering dpi, while
# pdf_data() reports PDF points (72 per inch) - and every tolerance in this
# package is in points: a 3-point line gap, a 25-point column gap. Handing the
# parser raw 300-dpi pixels makes every gap look four times too wide and
# nothing clusters into lines or columns at all.
# Render the pages of a PDF to images, OCR them, and DELETE THE IMAGES.
#
# pdftools::pdf_ocr_text() and pdf_ocr_data() render each page to a .png named
# after the PDF in the *current working directory* and leave it there. For a
# package whose output feeds peer-review fraud screening - where the promise is
# that the manuscript is deleted and nothing is retained - leaving full-page
# images of a submission lying about is unacceptable, quite apart from
# littering the caller's working directory.
#
# So the rendering is done explicitly into a temporary directory that is
# removed on exit, including when OCR throws.
.ppOcrPages <- function(pdfFile, dpi = 300, pages = NULL,
                        want = c("data", "text")) {
  want <- match.arg(want)
  if (!requireNamespace("tesseract", quietly = TRUE))
    stop("OCR needs the 'tesseract' package: install.packages(\"tesseract\")",
         call. = FALSE)
  if (is.null(pages)) pages <- seq_len(pdftools::pdf_info(pdfFile)$pages)
  # A page-size cap BEFORE the rasteriser (screen F1, 2026-09-02): a PDF may
  # declare a MediaBox of 200 x 200 inches, which at 300 dpi is a 3.6-gigapixel
  # bitmap, and the OS timeout on the parse child bounds time, not memory.
  # Pages over 30 inches on a side or over .ppRasterMaxPixels at this dpi
  # are not rendered; a journal page is 8.4 megapixels at 300 dpi.
  pages <- .ppRenderablePages(pdfFile, pages, dpi)
  if (length(pages) == 0)
    return(if (want == "text") character(0) else list())

  tmp <- tempfile("ppocr")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)

  # pdf_convert applies sprintf(filenames, page, format) itself, so hand
  # it the template - a pre-formatted name warns (found 2026-08-26).
  imgs <- pdftools::pdf_convert(
    pdfFile, format = "png", pages = pages, dpi = dpi, verbose = FALSE,
    filenames = file.path(tmp, "page%04d.%s"))

  # Named by page number, so a caller that asked for some pages can put
  # each result back at its page index (the cap above may have dropped
  # some of the pages asked for).
  if (want == "text") {
    out <- vapply(imgs, function(i) tesseract::ocr(i), character(1), USE.NAMES = FALSE)
  } else {
    out <- lapply(imgs, function(i) tesseract::ocr_data(i))
  }
  names(out) <- as.character(pages)
  out
}

# The one page-geometry gate for every rasteriser (repeat security screen
# 2026-09-06, F3: the AI route's renderer had none, so a 4 KB PDF
# declaring 200 x 200 inch pages reached pdf_convert at 150 dpi - 900
# megapixels). Returns the subset of `pages` that may be rendered at
# `dpi`; fails CLOSED (screen 2026-09-03, N2): a document whose page sizes
# cannot be read renders nothing. Pages over 30 inches on a side, or over
# .ppRasterMaxPixels at this dpi, are dropped.
.ppRenderablePages <- function(pdfFile, pages, dpi) {
  if (!length(pages)) return(integer(0))
  ps <- tryCatch(pdftools::pdf_pagesize(pdfFile), error = function(e) NULL)
  if (is.null(ps) || nrow(ps) < max(pages)) return(integer(0))
  w <- ps$width[pages]; h <- ps$height[pages]
  big <- w > 30 * 72 | h > 30 * 72 | (w * dpi / 72) * (h * dpi / 72) > .ppRasterMaxPixels
  pages[!big]
}
.ppRasterMaxPixels <- 20e6

.ppOcrData <- function(pdfFile, dpi = 300, pages = NULL) {
  pg <- .ppOcrPages(pdfFile, dpi = dpi, pages = pages, want = "data")
  if (is.data.frame(pg)) pg <- list(pg)
  lapply(pg, .ppOcrBoxes, scale = 72 / dpi)   # lapply keeps the page names
}

# Render and OCR ONLY the pages asked for, returned as one entry per
# document page with an empty word frame everywhere else, so a caller's
# page indices still line up with the document's. Until 2026-09-03 the
# engine rendered and OCRed every page of a document at 300 dpi even
# when the OCR rescue had aimed it at the two image pages - a 30-page
# preprint spent the whole child budget on pages the text layer had
# already read, and the rescue failed on exactly the documents it was
# built for (screen 2026-09-03, F1). NULL pages = every page, as before.
.ppOcrPagesAt <- function(pdfFile, dpi = 300, pages = NULL) {
  n <- tryCatch(pdftools::pdf_info(pdfFile)$pages, error = function(e) 0L)
  if (!is.numeric(n) || n < 1L) return(list())
  got <- .ppOcrData(pdfFile, dpi = dpi, pages = pages)
  empty <- data.frame(text = character(0), x = numeric(0), y = numeric(0),
                      width = numeric(0), height = numeric(0),
                      stringsAsFactors = FALSE)
  out <- rep(list(empty), n)
  at <- suppressWarnings(as.integer(names(got)))
  keep <- !is.na(at) & at >= 1L & at <= n
  out[at[keep]] <- got[keep]
  out
}

# One tesseract word table -> the page-words shape, at `scale` points per
# pixel. Factored out of .ppOcrData (2026-09-02) so an uploaded IMAGE can
# take the same road: the only difference is where the scale comes from.
.ppOcrBoxes <- function(d, scale) {
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  empty <- data.frame(text = character(0), x = numeric(0), y = numeric(0),
                      width = numeric(0), height = numeric(0))
  if (!nrow(d)) return(empty)
  bb <- do.call(rbind, lapply(strsplit(d$bbox, ","), as.numeric))
  out <- data.frame(text   = .ppNormalizeGlyphs(d$word),
                    x      = bb[, 1] * scale,
                    y      = bb[, 2] * scale,
                    width  = (bb[, 3] - bb[, 1]) * scale,
                    height = (bb[, 4] - bb[, 2]) * scale,
                    stringsAsFactors = FALSE)
  # tesseract reads the plus-minus sign as a plain plus, in three
  # shapes seen live (2026-08-26, synthetic page at 300 dpi): a
  # standalone word between mean and SD ("45.3 + 12.1"), glued to the
  # mean ("63+ 13"), and fully glued ("165+7"). Without the repair no
  # continuous row survives tokenization. In a baseline table a plus
  # touching digits IS a plus-minus, so the repair lives HERE - in the
  # OCR adapter - never in the global glyph normalizer, where a
  # genuine plus (e.g. "T+ group") must survive.
  out$text <- gsub("^\\+$", "\u00b1", out$text)
  out$text <- gsub("(\\d)\\+$", "\\1\u00b1", out$text)
  out$text <- gsub("(\\d)\\+(\\d)", "\\1\u00b1\\2", out$text)
  # ...and a fourth, glued to the SD instead ("63" "+13"): what JPEG
  # artefacts at 300 dpi did to the same cell (2026-09-02, image uploads).
  out$text <- gsub("^\\+(\\d)", "\u00b1\\1", out$text)
  out[!is.na(out$text) & nzchar(trimws(out$text)), , drop = FALSE]
}

# ---------------------------------------------------------------------------
# Uploaded table IMAGES (jpg/png/tif) - Steve, 2026-09-02
# ---------------------------------------------------------------------------
# A picture of a table takes the scanned-page road: tesseract word boxes
# into the same deterministic engine, "ocr" provenance, whole-table cyan
# in the app. It differs from a scanned PDF page in two ways, both
# handled here.
#
# THREAT MODEL FIRST. The uploader is the author under investigation, and
# an image decoder is a classic attack surface. Three decisions follow:
#   - NO ImageMagick. tesseract reads JPEG/PNG/TIFF through its own
#     leptonica reader, so the app needs no magick dependency and never
#     exposes ImageMagick's few-hundred-format decoder to hostile bytes.
#     tools/securityCheck.R pins that no image path ever calls it.
#   - THE HEADER IS READ BY US, BEFORE ANY DECODER. A 1 KB JPEG can
#     declare 65,000 x 65,000 pixels and a TIFF can chain thousands of
#     directories; a decoder would try to allocate all of it.
#     .ppImageDims() parses only the dimensions and page count, from a
#     bounded prefix (or, for TIFF, by seeking to each directory), with
#     no decoding, and .ppImageOK() refuses anything over the caps. It
#     decides the FORMAT from the magic bytes, never from the file name.
#   - NO GIF. The security screen of 2026-09-02 (F1) showed that a GIF's
#     logical screen - the only size its header states up front - is
#     not what the decoder allocates from: giflib sizes every frame from
#     its own image descriptor, so a 1 x 1 screen can precede a
#     65535 x 65535 frame and pass any header check short of walking the
#     block stream. Steve's rule was GIF and PNG "unless they are free";
#     GIF stopped being free, so it is out. PNG stays: IHDR is the
#     dimension the decoder uses.
#   - DECODING HAPPENS ONLY IN THE SUBPROCESS. The app and the API hand
#     images to parseBaselineTableFiles() exactly like PDFs, so a decoder
#     crash or stall costs one child under an OS timeout, never the
#     worker.
#
# SCALE. The engine's tolerances are in PDF points (a 3-pt line gap, a
# 25-pt column gap). A PDF page rendered at a known dpi converts by
# 72/dpi; an image carries no trustworthy dpi. Measured 2026-09-02 on a
# journal page rendered at 300, 150 and 96 dpi: the median height of a
# confident OCR word box was 6.72 pt at every resolution (28, 14 and 9
# px). So the median word box IS the ruler: scale so it lands at
# .ppImageWordPt, and the tolerances hold whatever the pixel size.

.ppImageExts <- c("jpg", "jpeg", "png", "tif", "tiff")
.ppIsImageFile <- function(path)
  tolower(tools::file_ext(path)) %in% .ppImageExts

.ppImageMaxPixels   <- 20e6   # 8.4 MP is a Letter page at 300 dpi; A4 at 400 is 15
.ppImageMaxPages    <- 10L    # a table is one picture; a TIFF chain is not
.ppImageHeaderBytes <- 4e6    # JPEG/PNG dimensions live in the prefix; TIFF seeks
.ppImageWordPt      <- 6.75

# Dimensions, page count and format from the file's own header - no
# decoder involved. NULL when the bytes are not one of the three formats,
# whatever the file is called.
.ppImageDims <- function(path) {
  size <- file.size(path)
  if (is.na(size) || size < 12) return(NULL)
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  head <- readBin(con, "raw", n = min(size, .ppImageHeaderBytes))
  u16 <- function(b, i, le = FALSE) {
    v <- as.integer(b[i:(i + 1)])
    if (le) v[1] + 256 * v[2] else 256 * v[1] + v[2]
  }
  u32 <- function(b, i, le = FALSE) {
    v <- as.numeric(as.integer(b[i:(i + 3)]))
    if (le) sum(v * 256^(0:3)) else sum(v * 256^(3:0))
  }
  hx <- function(...) as.raw(c(...))

  # PNG: 8-byte signature, then the IHDR chunk - width and height at 17..24
  if (identical(head[1:8], hx(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))) {
    # raw comparison, not rawToChar(): a NUL among these bytes made
    # rawToChar() throw, turning a refusal into a 500 (screen F2)
    if (size < 24 || !identical(head[13:16], hx(0x49, 0x48, 0x44, 0x52)))
      return(NULL)
    return(list(format = "png", width = u32(head, 17), height = u32(head, 21),
                pages = 1L))
  }
  # JPEG: walk the marker segments to the first SOFn frame header
  if (identical(head[1:2], hx(0xff, 0xd8))) {
    i <- 3L; n <- length(head); steps <- 0L
    while (i + 3 <= n && steps < 2000L) {
      steps <- steps + 1L
      if (head[i] != as.raw(0xff)) return(NULL)
      m <- as.integer(head[i + 1])
      if (m == 0xff) { i <- i + 1L; next }                # fill byte
      if (m == 0xd8 || (m >= 0xd0 && m <= 0xd7) || m == 0x01) {
        i <- i + 2L; next                                  # no payload
      }
      if (m == 0xd9 || m == 0xda) return(NULL)            # EOI / scan: no SOF seen
      len <- u16(head, i + 2)
      isSOF <- m >= 0xc0 && m <= 0xcf && !m %in% c(0xc4, 0xc8, 0xcc)
      if (isSOF) {
        if (i + 8 > n) return(NULL)
        return(list(format = "jpeg", width = u16(head, i + 7),
                    height = u16(head, i + 5), pages = 1L))
      }
      i <- i + 2L + len
    }
    return(NULL)
  }
  # TIFF: byte order, magic 42, then a chain of image file directories.
  # Directories usually sit at the END of the file, so this seeks rather
  # than reading the whole file. BigTIFF (magic 43) is refused.
  le <- identical(head[1:4], hx(0x49, 0x49, 0x2a, 0x00))
  be <- identical(head[1:4], hx(0x4d, 0x4d, 0x00, 0x2a))
  if (le || be) {
    readAt <- function(off, n) {
      if (off < 0 || off + n > size) return(NULL)
      seek(con, off)
      b <- readBin(con, "raw", n = n)
      if (length(b) < n) NULL else b
    }
    off <- u32(head, 5, le)
    width <- height <- NA_real_
    pages <- 0L; seen <- numeric(0)
    while (off != 0 && pages <= .ppImageMaxPages) {
      if (off %in% seen) return(NULL)                     # a loop, not a file
      seen <- c(seen, off)
      cnt <- readAt(off, 2); if (is.null(cnt)) return(NULL)
      nEnt <- u16(cnt, 1, le)
      if (nEnt == 0 || nEnt > 4096) return(NULL)
      ent <- readAt(off + 2, 12 * nEnt + 4); if (is.null(ent)) return(NULL)
      pages <- pages + 1L
      # EVERY directory is read, not only the first: a tiny page 1 ahead
      # of a 60000 x 60000 page 2 must not pass the cap, whichever page a
      # decoder chooses to read (screen 2026-09-03, F2)
      for (k in seq_len(nEnt)) {
        e   <- ent[(12 * (k - 1) + 1):(12 * k)]
        tag <- u16(e, 1, le)
        if (tag != 256 && tag != 257) next
        typ <- u16(e, 3, le); cnt <- u32(e, 5, le)
        # A dimension is ONE SHORT or LONG. With any other type, or a
        # count above one, the 4-byte value field is an OFFSET to the
        # values, and what sits at that offset is the author's - so the
        # file is refused rather than a small offset read as a small
        # width (screen 2026-09-03, F1). This also keeps max() away from
        # an NA, which was a warning in the API's parent process.
        if (cnt != 1 || !typ %in% c(3, 4)) return(NULL)
        val <- if (typ == 3) u16(e, 9, le) else u32(e, 9, le)
        # a repeated tag is illegal in an IFD; whichever occurrence a
        # decoder honours, the LARGER value is the one the cap must see
        # (screen F3, 2026-09-02)
        if (tag == 256) width  <- max(width,  val, na.rm = TRUE)
        if (tag == 257) height <- max(height, val, na.rm = TRUE)
      }
      off <- u32(ent, 12 * nEnt + 1, le)
    }
    if (is.na(width) || is.na(height)) return(NULL)
    return(list(format = "tiff", width = width, height = height,
                pages = pages))
  }
  NULL
}

# TRUE when the image may be decoded; otherwise FALSE carrying a "reason".
.ppImageOK <- function(path) {
  dims <- .ppImageDims(path)
  no <- function(why) structure(FALSE, reason = why)
  if (is.null(dims))
    return(no("not a JPEG, PNG or TIFF image, whatever the file name says"))
  if (dims$pages > .ppImageMaxPages)
    return(no(sprintf("a TIFF with more than %d pages", .ppImageMaxPages)))
  if (dims$width < 1 || dims$height < 1) return(no("an empty image"))
  if (dims$width * dims$height > .ppImageMaxPixels)
    return(no(sprintf("%.0f x %.0f pixels - more than the %d-megapixel limit",
                      dims$width, dims$height, .ppImageMaxPixels / 1e6)))
  structure(TRUE, dims = dims)
}

# OCR word boxes for one image, in the page-words shape, scaled so the
# median confident word box is .ppImageWordPt points tall (see above).
# Callers MUST have passed .ppImageOK() first; the engine and the API
# gate both do, and tools/securityCheck.R checks the order.
# A screen-resolution picture is too small for tesseract. A pasted
# screenshot is ~96 dpi: its word boxes are ~10 px tall, and tesseract
# drops most of them as noise (measured 2026-09-03 on the ticagrelor
# table page: 43 confident words from the 96 dpi raster, 338 after a
# two-times pixel replication, 347 from a true 300 dpi render; the DPI
# hint and the page-segmentation mode changed nothing). So a picture
# whose median confident word box is under .ppImageUpscaleMin pixels is
# decoded, its pixels replicated (nearest neighbour: no interpolation,
# no new library, and the letters stay crisp) until the boxes reach
# about .ppImageUpscaleTarget pixels, written as an uncompressed BMP
# (which the OCR engine reads natively) and read again. Only PNG and
# JPEG are decoded - the two formats a clipboard or a phone produces;
# a TIFF is a scan and arrives at its scanner's resolution. The pixel
# ceiling .ppImageMaxPixels bounds the enlarged picture too.
.ppImageUpscaleMin    <- 20      # px: median word box below this loses words
.ppImageUpscaleTarget <- 30      # px: about a 300 dpi page's word box
.ppImageUpscaleMax    <- 4L      # replication factor ceiling

# The picture as a matrix of grey BYTES (columns = x, rows = y), or NULL
# when it is not a PNG or JPEG the decoders read. This is the only place
# the two decoders are called (tripwire group 6). The decoded doubles are
# turned into one byte per pixel at once, so everything downstream - the
# replication, the BMP - is a raw vector: the screen of PR #168 measured
# the double-precision road at 765 MB for an ordinary 5-megapixel
# screenshot, and the child has no memory ceiling (ISSUES 32).
.ppImageGrey <- function(imgFile) {
  dims <- .ppImageDims(imgFile)
  if (is.null(dims) || !(dims$format %in% c("png", "jpeg"))) return(NULL)
  # the cap enforced HERE too, not only by the caller (second screen of
  # PR #168, note 1): a future direct call must not decode 20 megapixels
  if (as.numeric(dims$width) * dims$height > .ppImageMaxPixels) return(NULL)
  a <- tryCatch(
    if (dims$format == "png") png::readPNG(imgFile) else jpeg::readJPEG(imgFile),
    error = function(e) NULL)
  if (is.null(a)) return(NULL)
  if (length(dim(a)) == 2L) g <- a
  else if (dim(a)[3] >= 3L) g <- 0.299 * a[, , 1] + 0.587 * a[, , 2] + 0.114 * a[, , 3]
  else g <- a[, , 1]
  rm(a)
  m <- matrix(as.raw(as.integer(round(pmin(pmax(g, 0), 1) * 255))), nrow = nrow(g))
  rm(g)
  t(m)                                     # to x-by-y, one byte per pixel
}

# Replicate every pixel k times in both directions and write a 24-bit
# BMP; returns the file (in the session's temporary directory, which the
# parent removes) or NULL when the enlargement would pass the pixel cap.
# The factor is decided from the HEADER, before any decode: the screen of
# PR #168 (F1) showed an 88 KB blank PNG over 5 megapixels costing a
# gigabyte to decode for an enlargement the cap then refused.
.ppImageUpscaled <- function(imgFile, k) {
  dims <- .ppImageDims(imgFile)
  if (is.null(dims) || !(dims$format %in% c("png", "jpeg"))) return(NULL)
  k <- as.integer(k)
  while (k > 1L && as.numeric(dims$width) * dims$height * k * k > .ppImageMaxPixels) k <- k - 1L
  if (k < 2L) return(NULL)
  g <- .ppImageGrey(imgFile)
  if (is.null(g)) return(NULL)
  m <- g[rep(seq_len(nrow(g)), each = k), rep(seq_len(ncol(g)), each = k), drop = FALSE]
  rm(g)
  # in the child's own temporary directory, which the parent removes
  # whatever the child's fate (second screen of PR #168, note 2)
  out <- tempfile("upscaled", fileext = ".bmp")
  .ppWriteBmp(m, out)
  out
}

# An uncompressed 24-bit BMP from a matrix of grey bytes (x-by-y): 54
# bytes of header, then rows bottom-up, each padded to four bytes. The
# pixel block is built with vector operations and written ONCE - a
# per-row write loop cost 4.5 us a row, and a 1 x 5,000,000 picture has
# ten million rows at factor two (screen of PR #168, F2).
.ppWriteBmp <- function(m, file) {
  w <- nrow(m); h <- ncol(m)
  rowBytes <- (3L * w + 3L) %/% 4L * 4L; pad <- rowBytes - 3L * w
  px <- rep(as.vector(m[, rev(seq_len(h)), drop = FALSE]), each = 3L)
  if (pad > 0L)
    px <- as.vector(rbind(matrix(px, nrow = 3L * w),
                          matrix(as.raw(0L), nrow = pad, ncol = h)))
  con <- file(file, "wb"); on.exit(close(con), add = TRUE)
  i4 <- function(v) writeBin(as.integer(v), con, size = 4L, endian = "little")
  i2 <- function(v) writeBin(as.integer(v), con, size = 2L, endian = "little")
  writeBin(charToRaw("BM"), con); i4(54 + rowBytes * h); i4(0); i4(54)
  i4(40); i4(w); i4(h); i2(1); i2(24); i4(0); i4(rowBytes * h)
  i4(2835); i4(2835); i4(0); i4(0)
  writeBin(px, con)
  invisible(file)
}

.ppImageData <- function(imgFile, wordPt = .ppImageWordPt) {
  if (!requireNamespace("tesseract", quietly = TRUE))
    stop("Reading a table image needs the 'tesseract' package: ",
         "install.packages(\"tesseract\")", call. = FALSE)
  d <- as.data.frame(tesseract::ocr_data(imgFile), stringsAsFactors = FALSE)
  rulerOf <- function(d) {
    if (!nrow(d)) return(list(ruler = NA_real_, good = 0L))
    bb <- do.call(rbind, lapply(strsplit(d$bbox, ","), as.numeric))
    h  <- bb[, 4] - bb[, 2]
    good <- d$confidence > 50 & nchar(d$word) >= 2 & h > 0
    list(ruler = if (any(good)) stats::median(h[good]) else stats::median(h[h > 0]),
         good = sum(good))
  }
  r <- rulerOf(d)
  # small words, or (almost) none read at all: enlarge and read again,
  # keeping the reading that found more confident words
  if (!nrow(d) || (is.finite(r$ruler) && r$ruler < .ppImageUpscaleMin)) {
    k <- if (is.finite(r$ruler) && r$ruler > 0)
      min(.ppImageUpscaleMax, max(2L, ceiling(.ppImageUpscaleTarget / r$ruler)))
    else 3L
    up <- .ppImageUpscaled(imgFile, k)
    if (!is.null(up)) {
      on.exit(unlink(up), add = TRUE)
      d2 <- as.data.frame(tesseract::ocr_data(up), stringsAsFactors = FALSE)
      r2 <- rulerOf(d2)
      if (r2$good > r$good) { d <- d2; r <- r2 }
    }
  }
  if (!nrow(d)) return(list(.ppOcrBoxes(d, 1)))
  ruler <- r$ruler
  scale <- wordPt / ruler
  # a ruler outside 72-1440 dpi is not a photograph of a table; fall back
  # to 300 dpi rather than blow every tolerance up or down by orders
  if (!is.finite(scale) || scale > 1 || scale < 0.05) scale <- 72 / 300
  list(.ppOcrBoxes(d, scale))
}

# Plain OCR text, for the AI paths, which want prose rather than word boxes.
.ppOcrText <- function(pdfFile, dpi = 300, pages = NULL) {
  .ppNormalizeGlyphs(.ppOcrPages(pdfFile, dpi = dpi, pages = pages,
                                 want = "text"))
}

.ppPdfText <- function(pdfFile) {
  x <- .ppNormalizeGlyphs(pdftools::pdf_text(pdfFile))
  if (.ppPlusMinusIsDash(x)) x <- gsub(.ppPLUSMINUS, "-",x, fixed = TRUE)
  x
}

# Number of decimal places in the *printed* number (from its text, not its
# value): "63" -> 0, "61.3" -> 1, "0.71" -> 2.  Handles comma and middle-dot
# decimal separators ("61,3", "61\u00b73") used by some journals.
#
# This is the single most important quantity for a Carlisle-style analysis:
# the rounding of the reported mean determines how much of the difference
# between the reported and the reconstructed value is explained by rounding
# alone, so it is read from the glyphs rather than inferred from the number.
# Normalise printed number text to a plain machine-readable number.
#
# The comma is the hazard: European journals use it as a decimal separator
# ("61,3" = 61.3) and English ones as a thousands separator ("4,335" = 4335).
# Treating every comma as a decimal point turned a blood-loss figure of
# 4,335 ml into 4.335 - a thousand-fold error that looks perfectly plausible
# in a spreadsheet. The rule below reads it the way a person would:
#
#   * a comma followed by exactly three digits, in a number made only of such
#     groups, is a thousands separator      "4,335" -> 4335
#   * a number containing both a comma and a dot has commas as thousands
#     separators                            "1,234.5" -> 1234.5
#   * otherwise the comma is a decimal separator, as is the middle dot that
#     BJA and others print                  "61,3" / "61.3" -> 61.3
.ppNumText <- function(txt) {
  txt  <- gsub("[<>\u2212]", "", txt)
  both <- grepl(",", txt, fixed = TRUE) & grepl("[.\u00b7]", txt)
  thou <- grepl("^\\s*[-+]?\\d{1,3}(,\\d{3})+\\s*$", txt)
  txt  <- ifelse(both | thou, gsub(",", "", txt, fixed = TRUE), txt)
  gsub("[,\u00b7]", ".", txt)
}

# THE DIGITS A PRINTED NUMBER SHOWS. Everything after the first "." used
# to be counted, exponent included, so "5.0e1" read THREE decimals where
# it shows the same unit precision as "50" - one mantissa decimal less
# one exponent (independent audit 2026-09-09, F4). A spreadsheet writes
# scientific notation for large and small magnitudes without being asked,
# and the count feeds ROUND_MEAN, which is the width of the interval the
# engine draws over: the fictitious precision took a row from p = 0.083
# to p = 0.0024.
#
# The exponent is subtracted and the result FLOORED AT ZERO. The audit
# asked for negative precisions to be retained as well, and that is
# right in principle - "5e1" is a number printed to the nearest ten. It
# is deliberately not taken here: this helper also feeds the document
# tokenizer, so a negative would put coarse-grid claims into every parsed
# manuscript, and the same audit's F3 shows how fragile the handling of a
# negative precision still is. Reading "5e1" as "50" is the conservative
# error, and it is the reading the old code gave for the plain spelling.
.ppDecimals <- function(txt) {
  txt <- .ppNumText(txt)
  mant <- sub("[eE][+-]?[0-9]+$", "", txt)
  dec  <- ifelse(grepl(".", mant, fixed = TRUE),
                 nchar(sub("^[^.]*[.]", "", mant)),
                 0L)
  expo <- suppressWarnings(as.integer(sub("^.*[eE]([+-]?[0-9]+)$", "\\1",
                                          ifelse(grepl("[eE][+-]?[0-9]+$", txt),
                                                 txt, "0"))))
  expo[is.na(expo)] <- 0L
  pmax(0L, as.integer(dec) - expo)
}

# Convert printed number text to numeric (comma / middle-dot decimals,
# thousands separators, stray < > signs from "<0.001"-style cells).
.ppAsNumeric <- function(txt) {
  suppressWarnings(as.numeric(.ppNumText(txt)))
}

# Collapse repeated whitespace and trim.
.ppSquish <- function(x) trimws(gsub("\\s+", " ", x))

# A LETTER O FOR A ZERO IN AN ARM SIZE (2026-09-25, ISSUES.md issue 75;
# Fujii 1999, Can J Anaesth, PMID 10522590 - the corpus session's batch 17
# W2). The scanned page's text layer prints the header sizes as "(n=4O)"
# beside "(n=40)": the size regex read 4, the remainder "O)" became part
# of the first arm's name ("Granisetron O)"), and the first arm went out
# with N = 4 - a wrong number that the hybrid merge then doubled into a
# phantom arm. Within a word that IS an "(n = k)" group ("(n=4O)",
# "n=1OO"), or the number word of a split one ("(n" "=" "4O)"), a letter
# O among digits is a zero. At least one digit must be present, and
# nothing outside such a group is touched.
.ppRepairSizeZeros <- function(lines, capIdx = 0L) {
  n <- length(lines); repaired <- 0L
  if (n <= capIdx) return(list(lines = lines, repaired = 0L))
  for (i in seq(capIdx + 1L, n)) {
    s <- lines[[i]]$text
    if (!any(grepl("[Oo]", s, perl = TRUE))) next
    glued <- grepl("^\\(?[Nn]\\s*=\\s*(?=[0-9Oo]*[0-9])(?=[0-9Oo]*[Oo])[0-9Oo]+\\)?$", s, perl = TRUE)
    prev1 <- c("", s[-length(s)])
    prev2 <- c("", "", s[seq_len(max(0L, length(s) - 2L))])
    split <- grepl("^(?=[0-9Oo]*[0-9])(?=[0-9Oo]*[Oo])[0-9Oo]+\\)?$", s, perl = TRUE) &
      grepl("^=$", prev1) & grepl("^\\(?[Nn]$", prev2)
    # "(n =3o)" - the equals sign glued to the size (2026-09-25, ISSUES.md
    # issue 100; CJA 1998, PMID 9512856, the corpus session's batch 24):
    # the page prints "(n = 3o) (n =3o)", and only the first was repaired;
    # the second read as an arm of 3 named "o)".
    afterEq <- grepl("^=\\s*(?=[0-9Oo]*[0-9])(?=[0-9Oo]*[Oo])[0-9Oo]+\\)?$", s, perl = TRUE) &
      grepl("^\\(?[Nn]$", prev1)
    hit <- glued | split | afterEq
    if (!any(hit)) next
    s[hit] <- gsub("[Oo]", "0", s[hit])
    lines[[i]]$text <- s
    repaired <- repaired + sum(hit)
  }
  list(lines = lines, repaired = repaired)
}

# A LETTER FOR A DIGIT IN THE SD AFTER THE SIGN (2026-09-26, ISSUES.md issue
# 116; CJA 1998, PMID 9717598, the corpus session's batch 26 AE6): the scan
# sets the Weight row as "58 <bullet> l0" - the OCR's lowercase l for the 1
# of "10" - and the tokenizer, which wants a number after the sign, read
# no cell; the whole row was lost. A word that follows a genuine sign
# glyph (the plus-minus, the bullet, "+/-") and is made of digits and the
# look-alike letters l, I, | and O - at least one true digit among them,
# never all letters - is the SD with its letters restored: l, I and |
# become 1, O becomes 0. A word with any other letter ("l0a", "kg") is
# left alone, and so is a word not directly after a sign.
.ppRepairLetterDigitsAfterSign <- function(lines, capIdx = 0L) {
  n <- length(lines); repaired <- 0L
  if (n <= capIdx) return(list(lines = lines, repaired = 0L))
  signRe <- paste0("^(", .ppPLUSMINUS, "|\u2022|\\+/-|\\+-|\u2afe)$")
  for (i in seq(capIdx + 1L, n)) {
    s <- lines[[i]]$text
    if (length(s) < 2L) next
    afterSign <- c(FALSE, grepl(signRe, s[-length(s)], perl = TRUE))
    # ... AND BEFORE IT (2026-09-27, ISSUES.md issue 136; Anesth Analg
    # 2002, PMID 12182258, the corpus session's batch 28 AG7): "Duration of
    # anesthesia, min 20l +/- 40 205 +/- 40 ..." - the OCR's l for the 1 of
    # the MEAN "201", the sign genuine after it. The word before a genuine
    # sign glyph is the cell's mean as surely as the word after it is the
    # SD, and it is read the same way.
    beforeSign <- c(grepl(signRe, s[-1L], perl = TRUE), FALSE)
    lookalike <- grepl("^[0-9lI|Oo]+(?:[.,][0-9lI|Oo]+)?$", s, perl = TRUE) &
      grepl("[0-9]", s) & grepl("[lI|Oo]", s)
    hit <- (afterSign | beforeSign) & lookalike
    if (!any(hit)) next
    s[hit] <- chartr("lI|Oo", "11100", s[hit])
    lines[[i]]$text <- s
    repaired <- repaired + sum(hit)
  }
  list(lines = lines, repaired = repaired)
}

# THE SIGN FUSED INSIDE THE CELL WORD (2026-09-25, ISSUES.md issue 85;
# Saitoh, Acta Anaesthesiol Scand 1998;42:851, the corpus session's batch
# 20 Z1). The scanned page's text layer sets each mean +/- SD cell as ONE
# word with a letter or symbol where the sign was: "48.4k7.2",
# "46.9Z7.7", "168.0?8.5", "166.9k8.4" - and, in three cells, a DIGIT
# ("47.357.9", "56.429.2", "58.527.8"). The tokenizer reads none of
# them: its number pattern refuses a digit run that a letter touches on
# either side, so the row held no cell and Table 1 read as Gender alone.
# A word of the shape NUMBER, one or two glyphs that are not digits,
# NUMBER - the glyphs not "e"/"E" (an exponent) and not "x"/"X" (a
# dimension, "10x20") - is a mean +/- SD cell when the line holds two or
# more of them: it is split into its three words, the sign written as
# the plus-minus glyph, the widths shared by character count.
#
# TWO MORE FORMS ON SUCH A LINE (2026-09-25, ISSUES.md issue 90; the
# corpus session's batch 23 on the same page, where the letter rule
# read Height but left Age and Weight as bare numbers). A line that
# holds two or more sign cells - letter-fused or the plus-minus glyph
# itself - fixes the PRECISION of its cells: every mean on the line has
# the same number of decimals, and so has every SD. With that settled,
# (a) a word of two decimal points, "47.357.9", is a mean +/- SD cell
# whose sign was set as a digit, and it splits in exactly one way:
# "47.3", the one stray digit "5", "7.9"; and (b) a glyph-soup word that
# is glued to an SD alone, "k8.0", and follows a bare number of the
# line's precision, "50.1", is that number's sign and SD. Neither form
# is read on a line with fewer than two sign cells, and the digit form
# needs at least one decimal on each side (an integer mean "4757" could
# split anywhere). The precision must agree across the line's sign
# cells; where it does not, only the letter form is read.
# A DECIMAL SD SPLIT AT ITS POINT (2026-09-27, ISSUES.md issue 127; CJA
# 1994, PMID 8004733, the corpus session's batch 25 "5. I"). The scan's
# Height line reads "152.8 4- 5.9 152.4 4- 4,7 153.5 5: 5. I": the third
# arm's SD "5.1" set as two words, "5." and "I" - the point kept with the
# first digit, the OCR's capital I for the 1 - touching each other on
# the page. Neither word is a number, so the slot rule could not read
# the "5:" before them (issue 125 wants a number after the sign) and the
# cell was lost. A word of digits ending in a point, followed within two
# points by a one-character word that is a digit or its look-alike
# (l, I, |), is one decimal number: joined, the look-alike read as its
# digit, the width the sum. Runs first of the repairs, so the slot rule
# and the letter-digit rule see the number. The same two pieces come
# FUSED from a layer that sets them closer ("5.I", "60.l"): a word of
# digits, a point and one of the look-alikes l, I or | is that number
# too. O and o are left out of BOTH forms: "5.o" and "5." "o" could be a
# number and its footnote letter, and a zero read into an SD is a wrong
# value, not a lost one (CodeRabbit on PR #435); "5.I" cannot be a
# footnote.
.ppSplitDecimalHead <- "^[0-9]+[.]$"
.ppFusedDecimalTail <- "^[0-9]+[.][lI|]$"
.ppRepairSplitDecimals <- function(lines, capIdx = 0L) {
  n <- length(lines); repaired <- 0L
  if (n <= capIdx) return(list(lines = lines, repaired = 0L))
  for (i in seq(capIdx + 1L, n)) {
    L <- lines[[i]]; s <- L$text
    fused <- grepl(.ppFusedDecimalTail, s, perl = TRUE)
    if (any(fused)) {
      L$text[fused] <- chartr("lI|", "111", s[fused]); s <- L$text
      repaired <- repaired + sum(fused); lines[[i]] <- L
    }
    if (length(s) < 2L) next
    head <- grepl(.ppSplitDecimalHead, s, perl = TRUE)
    if (!any(head)) next
    tail <- c(grepl("^[0-9lI|]$", s[-1L], perl = TRUE), FALSE)
    gap  <- c(L$x[-1L] - (L$x[-length(s)] + L$width[-length(s)]), Inf)
    hit  <- head & tail & gap <= 2
    if (!any(hit)) next
    keep <- rep(TRUE, nrow(L))
    for (k in which(hit)) {
      L$text[k]  <- paste0(s[k], chartr("lI|", "111", s[k + 1L]))
      L$width[k] <- L$x[k + 1L] + L$width[k + 1L] - L$x[k]
      keep[k + 1L] <- FALSE
      repaired <- repaired + 1L
    }
    lines[[i]] <- L[keep, , drop = FALSE]
    rownames(lines[[i]]) <- NULL
  }
  list(lines = lines, repaired = repaired)
}

# A STRAY DOT FUSED TO A DECIMAL NUMBER (2026-09-26, ISSUES.md issue 126;
# CJA 1996, PMID 8706192, the corpus session's AF7). The scan's text layer
# sets a speck before the first cell of the Morphine row and fuses it to
# the mean: ".5.0 5:0.6 5.0 -t- 0.8 ...". A number cannot begin after a
# dot (the tokenizer's guard, which keeps "1.5" from yielding a "5"), so
# ".5.0" was no token, the row label swallowed it ("... operation (mg)
# .5.0") and the first arm's cell was lost. A word of a dot and then a
# number that carries its own decimal point is that number: ".5.0" can
# be nothing else, since no notation writes two points. A dot before a
# whole number (".5") is left alone - it may be "0.5" without its zero,
# and that is a different reading, not a stray mark.
.ppStrayDot <- "^[.]([0-9]+[.][0-9]+)$"
.ppRepairStrayDots <- function(lines, capIdx = 0L) {
  n <- length(lines); repaired <- 0L
  if (n <= capIdx) return(list(lines = lines, repaired = 0L))
  for (i in seq(capIdx + 1L, n)) {
    L <- lines[[i]]; s <- L$text
    hit <- grepl(.ppStrayDot, s, perl = TRUE)
    if (!any(hit)) next
    for (k in which(hit)) {
      nc <- nchar(s[k]); w <- L$width[k]
      L$text[k]  <- sub(.ppStrayDot, "\\1", s[k], perl = TRUE)
      L$x[k]     <- L$x[k] + w / nc
      L$width[k] <- w * (nc - 1) / nc
      repaired <- repaired + 1L
    }
    lines[[i]] <- L
  }
  list(lines = lines, repaired = repaired)
}

# "-I-" BETWEEN TWO NUMBERS IS THE PLUS-MINUS SIGN (2026-09-26, ISSUES.md
# issue 123; the corpus session's survey of batch 27). The OCR of a scanned
# plus-minus is often a minus, a capital I and a minus - "149 -I- 13",
# "54.2 -I-7.1", "18.0 --I-1.8", "10141-I- 1977" - and the survey found
# the form on data lines of eight papers (Fujii 23568117, 7497558,
# 7534216, 7614644, 7889590, 7954995, 8055614 and Loadsman CJA1995_992)
# and in prose only elsewhere ("ASA-I- bis", "HS-I-IES", a reference's
# "ROCHA-I-SILVA"), never between two numbers. The slot rule below reads
# it only where another row sets a genuine glyph at that x, so a page
# whose every sign is "-I-" (7889590, nine lines) read no cell. Between
# two numbers on a line after the caption the form is the sign, whether
# it stands alone or is glued to the number before it, after it, or
# both; the glued word is split by its characters' share of its width,
# as the fused-sign repair splits. A number may carry a footnote mark
# ("5.5a,b,c", "10t"). Runs BEFORE the slot repair, so the signs it
# restores are the genuine glyphs the slot rule then leans on.
# (a text layer may set the hyphens as the minus sign U+2212, as R's pdf
# device does in the test fixture; both are accepted)
# ... AND THE DIGIT ONE FOR THE I (2026-09-26, ISSUES.md issue 124; CJA
# 1995, PMID 7497558, the corpus session's AF6): "Age (yr) 63+8 60 -k I1
# 62-1-11" - the third arm's sign is "-1-", the same OCR family read with
# a one for the capital I, and the cell was a bare number. Between two
# numbers "-1-" can be nothing else on a table line: a hyphenated code
# begins with a letter and a range has no second hyphen. But an ADDRESS
# has the shape too - "2-1-1, Hongo, Toride City" on the title page of
# BJA1999_340 (Loadsman corpus) read as a cell "2 +/- 1" and made a
# one-cell table of an affiliation line - so the digit form is held to
# a cell's numbers: two digits or a decimal on each side, and no comma
# on the number after the sign. "62-1-11" passes, "2-1-1," and "12-1-1"
# do not; a one-digit SD after "-1-" is missed, and left to the slot rule.
.ppDashIDash <- "^([0-9]+(?:[.,][0-9]+)?)?([-\u2212]{1,2}[I1][-\u2212])([0-9]+(?:[.,][0-9]+)?[A-Za-z,]*)?$"
.ppRepairDashIDash <- function(lines, capIdx = 0L) {
  n <- length(lines); repaired <- 0L
  if (n <= capIdx) return(list(lines = lines, repaired = 0L))
  isNum <- function(x) grepl("^[0-9]+(?:[.,][0-9]+)?[A-Za-z,]*$", x, perl = TRUE) &
    grepl("^[0-9]", x, perl = TRUE)
  for (i in seq(capIdx + 1L, n)) {
    L <- lines[[i]]; s <- L$text
    hit <- grepl(.ppDashIDash, s, perl = TRUE)
    if (!any(hit)) next
    out <- vector("list", nrow(L))
    for (k in seq_len(nrow(L))) {
      out[[k]] <- L[k, , drop = FALSE]
      if (!hit[k]) next
      m <- regmatches(s[k], regexec(.ppDashIDash, s[k], perl = TRUE))[[1]]
      before <- m[2]; after <- m[4]
      # a number on each side: glued to the word, or the neighbouring word
      okBefore <- nzchar(before) || (k > 1L && isNum(s[k - 1L]))
      okAfter  <- nzchar(after)  || (k < length(s) && isNum(s[k + 1L]))
      if (!okBefore || !okAfter) next
      if (grepl("1", m[3], fixed = TRUE)) {
        numBefore <- if (nzchar(before)) before else s[k - 1L]
        numAfter  <- if (nzchar(after))  after  else s[k + 1L]
        cellNum <- function(x) grepl("^(?:[0-9]{2,}|[0-9]+[.,][0-9]+)", x, perl = TRUE)
        if (!cellNum(numBefore) || !cellNum(numAfter) || grepl(",$", numAfter)) next
      }
      nc <- nchar(s[k]); w <- L$width[k]; x0 <- L$x[k]
      f1 <- nchar(before) / nc; f2 <- nchar(m[3]) / nc
      parts <- list()
      if (nzchar(before)) {
        w1 <- L[k, , drop = FALSE]; w1$text <- before; w1$width <- w * f1
        parts <- c(parts, list(w1))
      }
      w2 <- L[k, , drop = FALSE]; w2$text <- .ppPLUSMINUS
      w2$x <- x0 + w * f1; w2$width <- w * f2
      parts <- c(parts, list(w2))
      if (nzchar(after)) {
        w3 <- L[k, , drop = FALSE]; w3$text <- after
        w3$x <- x0 + w * (f1 + f2); w3$width <- w * (1 - f1 - f2)
        parts <- c(parts, list(w3))
      }
      out[[k]] <- do.call(rbind, parts)
      repaired <- repaired + 1L
    }
    lines[[i]] <- do.call(rbind, out)
    rownames(lines[[i]]) <- NULL
  }
  list(lines = lines, repaired = repaired)
}

.ppFusedSoup <- "^([A-DF-WYZa-df-wyz?;~!|]{1,2})([0-9]+(?:\\.[0-9]+)?)$"
# (its own name: .ppDecimals() in text precision is a different helper)
.ppFusedDecimals <- function(x) ifelse(grepl(".", x, fixed = TRUE), nchar(sub("^[^.]*\\.", "", x)), 0L)
# A COLON IS A RATIO, NOT A SIGN (2026-09-25, ISSUES.md issue 92; CJA
# 1997;44:390, the corpus session's batch 23b AB2): "19:21" under "Sex
# M:F" is a two-level count, and with the colon in this glyph set three
# such cells on a line were split into 19 +/- 21 and the row became a
# continuous variable that moved the trial's p from 0.013 to 0.125. The
# colon is out of the set; an OCR sign of that shape ("5:9") is still
# read by the slot rule above, which needs the column's other rows to
# set a genuine glyph there.
.ppFusedSign <- "^([0-9]+(?:\\.[0-9]+)?)([A-DF-WYZa-df-wyz?;~!|]{1,2})([0-9]+(?:\\.[0-9]+)?)$"
.ppRepairFusedSigns <- function(lines, capIdx = 0L) {
  n <- length(lines); repaired <- 0L
  if (n <= capIdx) return(list(lines = lines, repaired = 0L))
  isNum <- function(x) grepl("^[0-9]+(?:\\.[0-9]+)?$", x, perl = TRUE)
  for (i in seq(capIdx + 1L, n)) {
    L <- lines[[i]]; s <- L$text
    hit  <- grepl(.ppFusedSign, s, perl = TRUE)
    glyph <- s == .ppPLUSMINUS
    if (sum(hit) + sum(glyph) < 2L) next
    # the line's precision, from its letter-fused cells and its glyph cells
    # (the numbers either side of a glyph); NA when the cells disagree
    parts <- lapply(which(hit), function(k)
      regmatches(s[k], regexec(.ppFusedSign, s[k], perl = TRUE))[[1]][c(2, 4)])
    means <- vapply(parts, `[`, character(1), 1); sds <- vapply(parts, `[`, character(1), 2)
    for (k in which(glyph)) {
      if (k > 1L && isNum(s[k - 1L])) means <- c(means, s[k - 1L])
      if (k < length(s) && isNum(s[k + 1L])) sds <- c(sds, s[k + 1L])
    }
    dm <- unique(.ppFusedDecimals(means)); ds <- unique(.ppFusedDecimals(sds))
    dm <- if (length(dm) == 1L) dm else NA_integer_
    ds <- if (length(ds) == 1L) ds else NA_integer_
    # (a) the digit-fused form, split by that precision (issue 90)
    digitRe <- if (!is.na(dm) && !is.na(ds) && dm >= 1L && ds >= 1L)
      sprintf("^([0-9]+\\.[0-9]{%d})([0-9])([0-9]+\\.[0-9]{%d})$", dm, ds) else NULL
    dhit <- if (is.null(digitRe)) rep(FALSE, length(s)) else grepl(digitRe, s, perl = TRUE)
    # (a2) THE DIGIT-FUSED FORM AT INTEGER PRECISION (2026-09-27, ISSUES.md
    # issue 141; BJA 1998, PMID 9689270, the corpus session's arm-count
    # audit; four arms of 30). "Age (years) 45i8 44i7 4329 4428", "Height
    # (cm) 154i6 153i4 15626 15625", "Duration of anaesthesia (min) 98t26
    # 99526 102232 95528": whole-number cells, the sign a letter in some
    # and a digit in the rest. Rule (a) wants a decimal point on each side
    # to know where the digit sits; with none, the letter-fused cells of
    # the line say how many digits the SD has (one on Age, two on the
    # durations), and a word of digits alone splits before that many and
    # one: "4329" is 43, a 2 for the sign, 9; "102232" is 102, a 2, 32. The
    # mean must have two digits or more and lie within a factor of three
    # of the letter-fused means - a bare count on such a line ("120") is
    # not touched.
    dInt <- rep(FALSE, length(s)); intRe <- NULL
    if (!is.na(dm) && !is.na(ds) && dm == 0L && ds == 0L && length(parts) >= 1L) {
      sdDigits <- unique(nchar(sds)); mNum <- suppressWarnings(as.numeric(means))
      if (length(sdDigits) == 1L && all(!is.na(mNum)) && sdDigits >= 1L) {
        intRe <- sprintf("^([0-9]{2,})([0-9])([0-9]{%d})$", sdDigits)
        cand <- grepl(intRe, s, perl = TRUE) & !hit
        for (k in which(cand)) {
          mk <- as.numeric(sub(intRe, "\\1", s[k], perl = TRUE))
          if (mk >= min(mNum) / 3 && mk <= max(mNum) * 3) dInt[k] <- TRUE
        }
      }
    }
    dhit <- dhit | dInt
    # (b) a soup word glued to the SD alone, after a bare number of the line's
    #     mean precision ("50.1" "k8.0"; issue 90)
    shit <- grepl(.ppFusedSoup, s, perl = TRUE) & c(FALSE, isNum(s[-length(s)])) &
      c(FALSE, !is.na(dm) & .ppFusedDecimals(s[-length(s)]) == dm)
    shit[is.na(shit)] <- FALSE
    if (!any(hit | dhit | shit)) next
    out <- vector("list", nrow(L))
    for (k in seq_len(nrow(L))) {
      if (!(hit[k] || dhit[k] || shit[k])) { out[[k]] <- L[k, , drop = FALSE]; next }
      nc <- nchar(s[k]); w <- L$width[k]; x0 <- L$x[k]
      if (shit[k]) {
        m  <- regmatches(s[k], regexec(.ppFusedSoup, s[k], perl = TRUE))[[1]]
        f1 <- nchar(m[2]) / nc
        w1 <- L[k, , drop = FALSE]; w2 <- w1
        w1$text <- .ppPLUSMINUS; w1$width <- w * f1
        w2$text <- m[3]; w2$x <- x0 + w * f1; w2$width <- w * (1 - f1)
        out[[k]] <- rbind(w1, w2)
        repaired <- repaired + 1L
        next
      }
      re <- if (hit[k]) .ppFusedSign else if (dInt[k]) intRe else digitRe
      m  <- regmatches(s[k], regexec(re, s[k], perl = TRUE))[[1]]
      f1 <- nchar(m[2]) / nc; f2 <- nchar(m[3]) / nc
      w1 <- L[k, , drop = FALSE]; w2 <- w1; w3 <- w1
      w1$text <- m[2]; w1$width <- w * f1
      w2$text <- .ppPLUSMINUS; w2$x <- x0 + w * f1; w2$width <- w * f2
      w3$text <- m[4]; w3$x <- x0 + w * (f1 + f2); w3$width <- w * (1 - f1 - f2)
      out[[k]] <- rbind(w1, w2, w3)
      repaired <- repaired + 1L
    }
    lines[[i]] <- do.call(rbind, out)
    rownames(lines[[i]]) <- NULL
  }
  list(lines = lines, repaired = repaired)
}

# OCR PLUS-MINUS GLYPHS, REPAIRED BY THEIR COLUMN (2026-09-25, ISSUES.md
# issue 65; Fujii 1994, CJA 41:291, PMID 7954995 - the corpus session's
# batch 12 finding Q1). A scanned page's text layer sets the plus-minus
# sign differently from one cell to the next: a bullet in "46.7 <bullet>
# 7.7", a plain plus in "44.1 + 9.0", then "154.4 :i: 4.9", "152.8 -t-
# 5.1", "54.2 -I- 7.1", "82 4- 31" and "81 -t-32". The bullet and the plus
# are known (issue 45), but ":i:", "-t-", "-I-" and "4-" are not, and a
# row with fewer than two readable cells lost every cell it had - four
# rows of five on that page, so the cut half of the table in one page
# column out-scored the whole of it read full width.
#
# What is constant is WHERE the glyph sits: in every row the plus-minus of
# a given arm's cell starts at the same x. So the block's lines are read
# for their plus-minus SLOTS - x positions at which two or more lines set
# a plus-minus glyph (the sign itself, the bullet, "+/-", or a "+" between
# two numbers) - and, in any line, a short glyph-soup word that starts at
# a slot between two numbers is a plus-minus. The soup may be glued to the
# SD ("-t-32"); it is cut off. A plain "+" is never repaired here - it is
# evidence for a slot, but whether "5 + 2" is a cell stays with the rules
# of issue 45 (announced, or beside two cells on its own line). Guards:
# the block must show at least two genuine plus-minus glyphs of its own,
# or announce the notation with a soup glyph ("All values are expressed
# as mean -t- SD." - then every line with two or more soup cells is
# repaired, slot or no slot); and a glued soup must be at least two
# characters, so a negative number ("-32") is never touched. Two more
# (CodeRabbit on PR #370): the evidence is this table's alone - the lines
# stop at the next caption, so a later table's announcement or sign
# columns license nothing here, while this table's own caption line does
# count for the announcement; and a one-character word ("-" between "20"
# and "30" is a range, not a sign) is repaired only when it IS the
# announced glyph.
#
# THREE MORE FORMS (2026-09-25, issue 77; Fujii 1994, PMID 8055614, the
# corpus session's batch 17 W1, a page whose OCR sets the sign as "5:9",
# "-1-", "+" and, in six cells, as nothing at all - "142 10", "121 14"):
# (a) the legend may spell SD with a space, "mean -t- S D"; (b) a plain
# "+" between two numbers IS the sign at a slot that two or more lines
# mark with the sign itself (not with a "+"), or, under an announced
# soup, at any slot; (c) the sign dropped entirely: two numbers that
# straddle such a slot, with a gap of four to twenty points between them
# for the missing glyph, get the sign inserted. The gap bound keeps two
# arms' counts on an "n 20 20" row - forty points apart - from becoming
# one cell.
#
# THE ANNOUNCED GLYPH MAY BE A LETTER (2026-09-25, issue 67; Fujii 2006,
# PMID 17126782, the corpus session's batch 13 R1): a Symbol-font
# plus-minus mapped to "F" - "Values are means F SD or numbers." over
# "Age (y) 30 F 4 31 F 5 32 F 5 31 F 4". A single letter is never a
# soup word on its own, but once the legend names it as the sign, the
# letter between two numbers is the sign, two or more to a line as the
# other announced notations require (the digit case, "mean 6 sd", stays
# with the block walker's digitSD rule). "means" is accepted as "mean".
#
# A GLUED SOUP NEVER EATS THE NUMBER (2026-09-25, issue 70; Fujii 1996, PMID
# 8706192, the corpus session's batch 15a T2): the first version's glued
# class held "4" and ".", so "+4.9" - a plain plus set against its SD -
# matched as the soup "+4." and the SD "9", and Height's second arm went
# out as 154.1 +/- 9.0 for the printed 4.9. The glued prefix is now
# strokes and stroke-like letters only, no digit and no dot; the one
# digit form admitted is "5:" - a digit and a colon, which is how that
# page's OCR sets the sign in "55.3 5:5.4" - and only at a sign slot,
# never on the announcement alone.
#
# `lines` is the block's list of word data frames (text, x, width, ...);
# the lines from `capIdx + 1` on are read. Returns the lines with the
# repaired words (the sign written as the plus-minus glyph, a glued SD
# split into its own word) and the count of repairs.
# "_+" IS SOUP TOO (2026-09-25, ISSUES.md issue 107; CJA 1996, PMID 8665632,
# the corpus session's batch 25 AD5): a scanned page under a diagonal
# RETRACTED watermark sets the sign as "_+" in three cells - an underscore
# for the lower stroke - and the second arm's Duration of operation,
# Acetaminophen and Pentazocine went unread. The underscore joins the
# strokes and stroke-like letters of the soup class.
.ppSoupGlyph <- "^[-+:~_\u2212\u2013\u00b7\u2022\u00b1iIlTt4]{1,4}$"
.ppRepairPlusMinusGlyphs <- function(lines, capIdx = 0L, tol = 6) {
  n <- length(lines)
  none <- list(lines = lines, repaired = 0L)
  if (n <= capIdx) return(none)
  idx <- seq(capIdx + 1L, n)
  # this table's lines end where the next caption starts
  texts <- vapply(lines, function(L) paste(L$text, collapse = " "), character(1))
  later <- idx[vapply(texts[idx], .ppCaptionStart, logical(1))]
  if (length(later)) idx <- idx[idx < later[1]]
  if (!length(idx)) return(none)
  isNum <- function(s) grepl(paste0("^", .ppNUM, "$"), s, perl = TRUE)
  true  <- function(s) s %in% c(.ppPLUSMINUS, "\u2022", "\u2afe", "+/-", "+-")
  # a soup word is not a number and carries at least one stroke
  isSoup <- function(s) grepl(.ppSoupGlyph, s, perl = TRUE) & !isNum(s) &
    grepl("[-+:~\u2212\u2013\u00b7\u2022\u00b1]", s, perl = TRUE)
  # (i) genuine markers, with the line they sit on and their left edge
  markX <- numeric(0); markLine <- integer(0); markTrue <- logical(0); nTrue <- 0L
  for (i in idx) {
    L <- lines[[i]]; if (nrow(L) < 3L) next
    s <- L$text
    prevNum <- c(FALSE, isNum(s[-length(s)]))
    nextNum <- c(isNum(s[-1L]), FALSE)
    g <- true(s) | (s == "+" & prevNum & nextNum)
    nTrue <- nTrue + sum(true(s))
    if (any(g)) {
      markX <- c(markX, L$x[g]); markLine <- c(markLine, rep(i, sum(g)))
      markTrue <- c(markTrue, true(s)[g])
    }
  }
  # "mean -t- SD" announces the soup glyph as the notation - in the
  # table's own caption line or its footnote
  annGlyph <- NA_character_
  for (txt in texts[c(if (capIdx >= 1L) capIdx, idx)]) {
    m <- regmatches(txt, regexpr("(?i)\\bmeans?\\s+(\\S{1,4})\\s+s\\.?\\s?d\\.?\\b", txt, perl = TRUE))
    if (length(m) == 1L) {
      g <- strsplit(m, "\\s+")[[1]][2]
      if (isSoup(g) || grepl("^[A-Za-z]$", g)) { annGlyph <- g; break }
    }
  }
  announced <- !is.na(annGlyph)
  # UNDER AN ANNOUNCED NOTATION THE SOUP ITSELF MARKS THE SLOTS (2026-09-25,
  # ISSUES.md issue 108; CJA 1994, PMID 8004733, the corpus session's batch
  # 25 AD4). "All values are expressed as mean ~ SD." over a page whose
  # signs are "4-", "-t-" and, in three cells, the glued digit-colon "5:34",
  # "5:38", "5:5.1". The announcement repairs the soup words two or more to
  # a line, but the glued digit form is a slot's evidence only (issue 70),
  # and the slots were built from genuine glyphs and plain pluses alone -
  # this page has none, so "81 5:34" stayed three words and the first
  # arm's durations went unread. Once the notation is announced, every
  # soup word set between two numbers marks its column: "4-" at one x on
  # four lines is a slot, and "5:34" at that x is the sign and its SD.
  if (announced) for (i in idx) {
    L <- lines[[i]]; if (nrow(L) < 3L) next
    s <- L$text
    prevNum <- c(FALSE, isNum(s[-length(s)]))
    nextNum <- c(isNum(s[-1L]), FALSE)
    # ... AND SO DOES THE GLUED DIGIT-COLON FORM (2026-09-26, ISSUES.md issue
    # 119; CJA 1995, PMID 7614644, the corpus session's batch 27 AF3): "All
    # values are expressed as mean + SD." over "154.0 5:3.8 154.9 5:4.8
    # 156.3 5:6.2 154.4 5:4.9" - the sign set as "5:" glued to every SD of
    # the middle arms, with a plain "+" in the outer ones. The glued digit
    # form is a slot's evidence only (issue 70), and the middle columns had
    # no other marker on two lines, so their cells stayed unread and the
    # table read two arms of four. Under an announced notation a glued
    # digit-colon word standing after a number marks its column as the
    # soup words above do; "5:" then repairs at that column on every line.
    gd <- grepl("^[0-9]:[0-9]", s, perl = TRUE) & prevNum & !true(s)
    g <- ((isSoup(s) | s == annGlyph) & prevNum & nextNum & !true(s) & s != "+") | gd
    if (any(g)) {
      markX <- c(markX, L$x[g]); markLine <- c(markLine, rep(i, sum(g)))
      markTrue <- c(markTrue, rep(FALSE, sum(g)))
    }
  }
  # (ii) slots: clusters of marker left edges set on two or more lines
  slots <- numeric(0); strong <- numeric(0)
  if (length(markX) > 0L) {
    o <- order(markX); mx <- markX[o]; ml <- markLine[o]; mt <- markTrue[o]
    cl <- cumsum(c(1L, diff(mx) > tol))
    grp <- split(seq_along(mx), cl)
    slots  <- vapply(grp, function(k)
      if (length(unique(ml[k])) >= 2L) mean(mx[k]) else NA_real_, numeric(1))
    # a strong slot is placed by the genuine markers alone: pluses in the
    # same cluster must not pull it toward themselves (CodeRabbit on PR #381)
    strong <- vapply(grp, function(k)
      if (length(unique(ml[k][mt[k]])) >= 2L) mean(mx[k][mt[k]]) else NA_real_, numeric(1))
    slots <- slots[!is.na(slots)]; strong <- strong[!is.na(strong)]
  }
  if (!announced && (nTrue < 2L || length(slots) == 0L)) return(none)
  # (iii) the repair, line by line
  repaired <- 0L
  soupGlued <- paste0("^((?:[-+:~\u2212\u2013\u00b7\u2022\u00b1iIlTt]{2,4})|(?:[0-9]:))",
                      "([0-9]+(?:[.,][0-9]+)*)$")
  for (i in idx) {
    L <- lines[[i]]; if (nrow(L) < 3L) next
    s <- L$text
    atSlot <- vapply(L$x, function(x) any(abs(slots - x) <= tol), logical(1))
    prevNum <- c(FALSE, isNum(s[-length(s)]))
    nextNum <- c(isNum(s[-1L]), FALSE)
    glued <- grepl(soupGlued, s, perl = TRUE) & !isNum(s)
    gluedDigit <- glued & grepl("^[0-9]:", s, perl = TRUE)   # "5:5.4": a slot's evidence only
    # A MINUS AND ONE DIGIT AS THE SIGN (2026-09-26, ISSUES.md issue 114; CJA
    # 1995, PMID 7534216, the corpus session's batch 26 AE8): "All values
    # are expressed as mean + SD." over "59 -6 14  59 -6 11  56 + 11  56 +
    # 10" and "154 -6 9" - the OCR sets the plus-minus as "-6", which the
    # tokenizer reads as a negative number, so the cell fell apart and the
    # table read one arm. Under an announced notation, a word that is a
    # minus and a single digit, standing between two numbers at a slot the
    # block's other rows mark, is the sign. A negative single-digit value
    # between two positive numbers at the sign column of a baseline table
    # is not a thing a page prints.
    minusDigit <- announced & grepl("^[-\u2212\u2013][0-9]$", s, perl = TRUE) & prevNum & nextNum & atSlot
    # A DIGIT AND A COLON STANDING ALONE AT A SLOT (2026-09-26, ISSUES.md
    # issue 125; CJA 1996, PMID 8706192, the corpus session's AF7): the
    # Awakening time line reads "6.1 5:2.5 6.2 5:22.8 6.0 5:3.0 9.2 5:
    # 5.5*" - the fourth arm's sign set as "5:" on its own, the SD after
    # it with the paper's significance star. The glued "5:2.5" is read
    # (issue 70) but "5:" alone is no soup word (a digit is not a stroke)
    # and "5.5*" is no number, so the cell was lost and the row read
    # three arms of four. A word of one digit and a colon, between a
    # number and a number that may carry a footnote mark, at a slot the
    # block's other rows set, is the sign: a ratio has digits on both
    # sides of its colon, and a time has two.
    isNumMark <- function(x) grepl(paste0("^", .ppNUM, "[*a-z]{0,2}$"), x, perl = TRUE)
    nextNumMark <- c(isNumMark(s[-1L]), FALSE)
    digitColon <- grepl("^[0-9]:$", s, perl = TRUE) & prevNum & nextNumMark & atSlot
    # A LETTER OR A QUESTION MARK ALONE AT A SLOT, AND SOUP GLUED TO THE
    # MEAN (2026-09-27, ISSUES.md issue 129; Anesth Analg 1998, PMID
    # 9495425, the corpus session's batch 28 AG1; three arms of 50 under
    # "mean +- SD"). The scan sets the sign as "?" and "k" on their own
    # ("154 ? 5", "98 k 27") and as a glyph glued to the MEAN ("55? 8",
    # "71+ 29", "75? 27"). Neither is a soup word - a letter has no stroke,
    # and the glued form is a number with a tail - so the third arm read
    # nowhere and the columns fell to two. At a slot the block's other
    # rows set, a single letter or question mark between two numbers is
    # the sign (the fused-sign repair's alphabet, one character, less the
    # exponent e and the dimension x), and a number with one or two such
    # glyphs glued to its end, followed by a number, is the mean and its
    # sign when the glued glyph stands at the slot: split as the glued SD
    # form is. Both need the slot; a letter between two numbers elsewhere
    # on a line is left alone.
    letterSign <- grepl("^[A-DF-WYZa-df-wyz?;!|]$", s, perl = TRUE) & prevNum & nextNum & atSlot
    meanGluedRe <- "^([0-9]+(?:[.,][0-9]+)?)([-+?;!|~A-DF-WYZa-df-wyz]{1,2})$"
    mgTail <- regmatches(s, regexec(meanGluedRe, s, perl = TRUE))
    mgFrac <- vapply(seq_along(s), function(k) {
      m <- mgTail[[k]]; if (length(m) < 3L) return(NA_real_); nchar(m[2]) / nchar(s[k]) }, numeric(1))
    mgX <- L$x + L$width * mgFrac
    meanGlued <- !is.na(mgFrac) & nextNum &
      vapply(mgX, function(x) !is.na(x) && any(abs(slots - x) <= tol), logical(1))
    isSign <- isSoup(s) | (announced & s == annGlyph) | minusDigit
    base <- prevNum & ((isSign & nextNum) | glued | digitColon | letterSign) & !true(s) & s != "+" &
      (nchar(s) > 1L | (announced & s == annGlyph) | letterSign)
    base <- base & !(grepl("^[-\u2212\u2013][0-9]$", s, perl = TRUE) & !minusDigit)   # a real negative number stays one
    hit  <- base & (atSlot | (announced & !gluedDigit & sum(base & !gluedDigit) >= 2L))
    # (a) a plain "+" between two numbers at a slot two or more lines mark
    # with the sign itself, or at any slot under an announced soup (issue 77)
    atStrong <- vapply(L$x, function(x) any(abs(strong - x) <= tol), logical(1))
    hit <- hit | (s == "+" & prevNum & nextNum & (atStrong | (announced & atSlot)))
    # (b) the sign dropped entirely: two numbers straddling such a slot with
    # a gap of 4 to 20 points between them (issue 77)
    back   <- if (announced) slots else strong
    xEnd   <- L$x + L$width
    gapHit <- logical(nrow(L))
    # only a LABELLED line: a figure's axis ticks under a scanned table
    # ("15 20 25 30 35 40", issue 46) have no row label, and two of them
    # straddling a slot are not a cell
    # A DIGIT FOR THE SIGN (2026-09-27, ISSUES.md issue 130; Anesth Analg
    # 1998, PMID 9495425, the corpus session's batch 28 AG1 - the two false
    # cells its false-cell audit found). The scan sets the sign as a
    # digit: "972 29" for "97 +/- 29" (the 2 glued to the mean) and "5.5 2
    # 0.7" for "5.5 +/- 0.7" (the 2 on its own at the sign column). Rule
    # (b) saw two numbers straddling a slot and put the sign between
    # them, building "972 +/- 29" and "5.5 +/- 2" - values that are not on
    # the page. Two forms, both judged before rule (b) fires:
    # (c) a word of ONE digit standing at the slot, with a number before
    #     it and a number close after it, is the sign, not a number: no
    #     cell has three numbers, and a one-digit SD is never followed by
    #     another number within the arm's width;
    # (d) the number before the gap has one more digit before its point
    #     than every other mean on the line (972 among 95 and 98), and
    #     that last digit ends at the slot: the digit is the sign, and
    #     the word is split there.
    digitSign <- logical(nrow(L)); splitDigit <- logical(nrow(L))
    intDigits <- function(x) nchar(sub("[.,].*$", "", x))
    if (length(back) && !isNum(s[1])) for (k in seq_len(nrow(L) - 1L)) {
      if (!isNum(s[k]) || !isNum(s[k + 1L])) next
      if (grepl("^-", s[k + 1L], perl = TRUE)) next   # a negative number is never an SD
      gap <- L$x[k + 1L] - xEnd[k]
      if (gap < 4 || gap > 20) next
      if (!any(back > xEnd[k] - 1 & back < L$x[k + 1L] + 1)) next
      if (grepl("^[0-9]$", s[k + 1L], perl = TRUE) && k + 2L <= nrow(L) && isNum(s[k + 2L]) &&
          any(abs(back - L$x[k + 1L]) <= tol) && L$x[k + 2L] - xEnd[k + 1L] <= 20) {
        digitSign[k + 1L] <- TRUE
        next
      }
      others <- setdiff(which(isNum(s) & c(true(s[-1L]) | hit[-1L], FALSE)), k)
      if (intDigits(s[k]) >= 2L && length(others) >= 1L &&
          all(intDigits(s[others]) == intDigits(s[k]) - 1L) &&
          any(abs(back - xEnd[k]) <= tol)) {
        splitDigit[k] <- TRUE
        next
      }
      gapHit[k] <- TRUE
    }
    hit <- hit | digitSign
    if (!any(hit) && !any(gapHit) && !any(meanGlued) && !any(splitDigit)) next
    out <- vector("list", nrow(L))
    for (k in seq_len(nrow(L))) {
      if (meanGlued[k] && !hit[k]) {
        # "55?" at the slot: the number, then the sign in the glyph's place
        repaired <- repaired + 1L
        w1 <- L[k, , drop = FALSE]; w2 <- L[k, , drop = FALSE]
        w1$text <- mgTail[[k]][2]; w1$width <- L$width[k] * mgFrac[k]
        w2$text <- .ppPLUSMINUS; w2$x <- mgX[k]; w2$width <- L$width[k] * (1 - mgFrac[k])
        out[[k]] <- rbind(w1, w2)
      } else if (splitDigit[k]) {
        # "972" at the slot: "97", then the sign in the last digit's place
        repaired <- repaired + 1L
        nc <- nchar(s[k]); f <- (nc - 1) / nc
        w1 <- L[k, , drop = FALSE]; w2 <- L[k, , drop = FALSE]
        w1$text <- substr(s[k], 1, nc - 1); w1$width <- L$width[k] * f
        w2$text <- .ppPLUSMINUS; w2$x <- L$x[k] + L$width[k] * f; w2$width <- L$width[k] * (1 - f)
        out[[k]] <- rbind(w1, w2)
      } else if (!hit[k]) {
        out[[k]] <- L[k, , drop = FALSE]
      } else {
        repaired <- repaired + 1L
        if (glued[k]) {
          m  <- regmatches(s[k], regexec(soupGlued, s[k], perl = TRUE))[[1]]
          w1 <- L[k, , drop = FALSE]; w2 <- L[k, , drop = FALSE]
          frac <- nchar(m[2]) / nchar(s[k])
          w1$text <- .ppPLUSMINUS; w1$width <- L$width[k] * frac
          w2$text <- m[3]; w2$x <- L$x[k] + L$width[k] * frac; w2$width <- L$width[k] * (1 - frac)
          out[[k]] <- rbind(w1, w2)
        } else {
          w1 <- L[k, , drop = FALSE]; w1$text <- .ppPLUSMINUS
          out[[k]] <- w1
        }
      }
      if (gapHit[k]) {
        repaired <- repaired + 1L
        w <- L[k, , drop = FALSE]
        w$text <- .ppPLUSMINUS; w$x <- xEnd[k] + 1; w$width <- max(2, L$x[k + 1L] - xEnd[k] - 2)
        out[[k]] <- rbind(out[[k]], w)
      }
    }
    lines[[i]] <- do.call(rbind, out)
    rownames(lines[[i]]) <- NULL
  }
  list(lines = lines, repaired = repaired)
}

# Clean a row label for use as the ROW entry: drop trailing "n (%)" /
# "no. (%)" annotations, a short trailing parenthetical unit like "(kg)"
# or "(yr)" (but NOT one containing "/" - that names categories, e.g.
# "(M/F)"), and trailing separator punctuation.
.ppCleanLabel <- function(label) {
  # Some PDFs map superscript footnote markers to control characters
  # (a BEL where a superscript "a" is printed - vocacapsaicin corpus,
  # 2026-08-22); strip them before anything pattern-matches the label.
  label <- gsub("[[:cntrl:]]", "", label)
  # a footnote marker after the unit ("first (mg)*", Fujii 2006, PMID
  # 17126782, issue 69) would keep the unit rule below from seeing the
  # closing bracket at the end; the marker goes first
  label <- sub("[*\u2020\u2021\u00a7]+\\s*$", "", label, perl = TRUE)
  # ...and the zero-width characters a typesetter leaves where a line
  # was allowed to break (U+200B in "ACA\u200b", ticagrelor article,
  # seen in the API's results CSV 2026-09-03): invisible in the grid,
  # they defeat label matching and cannot be written by every encoding.
  label <- gsub("[\u200b\u200c\u200d\u2060\ufeff]", "", label)
  label <- .ppSquish(label)
  # "[ranges]" / "[range]" / "[min-max]" after a label announces the
  # bracketed ranges of the row's cells (Fujii 1998, issue 63): notation,
  # removed first so that a unit before it is still trailing
  label <- sub("(?i)\\s*\\[\\s*(ranges?|min\\s*[-\u2013]\\s*max)\\s*\\]\\s*$", "", label, perl = TRUE)
  label <- sub("(?i)[,;\u2014-]?\\s*(no\\.?|n)\\s*\\(%\\)\\s*$", "", label, perl = TRUE)
  label <- sub("(?i)[,;\u2014-]?\\s*\\(%\\)\\s*$", "", label, perl = TRUE)
  # trailing "(kg)", "(yr)", "(mmHg)" ... : parenthetical with no slash,
  # UNIT-LIKE content only - all lowercase up to 8 characters, or a
  # 1-4 letter mixed-case symbol ("mmHg", "SD", "IQR"). "(Hispanic)"
  # fit the old any-8-characters rule and a category level lost its
  # distinguishing qualifier (vocacapsaicin corpus, 2026-08-22).
  label <- sub("\\(([a-z\u00b5\u00b0%\u00b2\u00b30-9.\u00b7\\s-]{1,8}|[A-Za-z]{1,4}\\d?)\\)\\s*$",
               "", label)
  label <- sub("[[:space:],;:\u2014-]+$", "", label)
  .ppSquish(label)
}

# Is a category level's printed name unreadable - OCR noise rather than a
# word or a band (ISSUES.md issue 46, 2026-09-25)? Letters, when present,
# must make up at least half of the non-space characters, unless the name
# is a roman numeral; and the name is at most forty characters. "Male",
# "ASA III", "<65", "0-1", "3" and "IIb" pass; ". T", "i I | I I t" and
# "and past-tetanic count (PTC) (D .... [ vceuronium" do not.
.ppUnreadableLevel <- function(label) {
  if (is.na(label)) return(TRUE)
  if (nchar(label) > 40) return(TRUE)
  if (grepl("^[IVXivx]+[a-d]?$", label)) return(FALSE)
  chars   <- gsub("\\s", "", label)
  letters <- nchar(gsub("[^A-Za-z]", "", chars))
  letters > 0 && letters * 2 < nchar(chars)
}

# The level names a "levels across the line" row prints between its
# label's colon and its first cell (ISSUES.md issue 49, 2026-09-25):
# "20-30 31-40" gives two, "P1-2 >= P3" two (a lone comparison sign is
# glued to the token after it), "18-25 25.1-29.9 >= 30" three.
.ppSpreadLevels <- function(txt) {
  w <- strsplit(.ppSquish(txt), " ", fixed = TRUE)[[1]]
  w <- w[nzchar(w)]
  if (!length(w)) return(character(0))
  out <- character(0); glue <- ""
  for (t in w) {
    if (grepl("^[<>≤≥=]+$", t)) { glue <- paste0(glue, t); next }
    out  <- c(out, paste0(glue, t)); glue <- ""
  }
  if (nzchar(glue)) out <- c(out, glue)
  out
}

# Make `nm` unique against `existing` by appending " 2", " 3", ...
.ppUniqueName <- function(nm, existing) {
  base <- nm
  k <- 2
  while (nm %in% existing) {
    nm <- paste(base, k)
    k <- k + 1
  }
  nm
}

# rbind two data frames that may not share all columns, filling the gaps with
# NA.  Used when merging deterministic and AI-derived rows, which can name
# different category columns.
# Every frame at once, on the union of their columns, in one rbind - the
# shape the app uses to combine files (screen 2026-09-10-1628, F1: folding
# .ppRbindFill pairwise copies the accumulated frame at every step).
.ppRbindFillAll <- function(frames) {
  frames <- Filter(function(f) !is.null(f) && nrow(f) > 0, frames)
  if (length(frames) == 0) return(NULL)
  allCols <- unique(unlist(lapply(frames, names)))
  do.call(rbind, lapply(frames, function(d) {
    for (cn in setdiff(allCols, names(d))) d[[cn]] <- NA
    d[, allCols, drop = FALSE]
  }))
}

.ppRbindFill <- function(a, b) {
  if (is.null(a) || nrow(a) == 0) return(b)
  if (is.null(b) || nrow(b) == 0) return(a)
  allCols <- union(names(a), names(b))
  for (cn in setdiff(allCols, names(a))) a[[cn]] <- NA
  for (cn in setdiff(allCols, names(b))) b[[cn]] <- NA
  rbind(a[, allCols, drop = FALSE], b[, allCols, drop = FALSE])
}

# The column layout the Integrity-Analysis app expects before the
# one-column-per-category block.
#
# SD and SE are separate columns, and exactly one of them is populated for any
# continuous row. This is deliberate and it matters: papers print a standard
# deviation or a standard error, never a variance, and converting one to the
# other is a MODELLING decision, not an extraction fact. Recording whichever
# was printed keeps every number traceable to a cell on the page, and leaves
# the conversion - and the small-sample bias correction that goes with it,
# since the sample SD is a biased estimator of sigma by Jensen's inequality -
# to the analysis, which applies it once, in one place (the c4 correction
# of the pooled SD in P_Calc).
#
# ROUND_DISPERSION is the printed granularity of whichever of SD or SE was
# given. It cannot be inferred from ROUND_MEAN: a table may print "39 (4.06)".
.ppBaseColumns <- function() {
  c("TRIAL", "ROW", "N", "MEAN", "SD", "SE",
    "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION")
}
