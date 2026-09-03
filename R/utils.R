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

.ppPdfData <- function(pdfFile) {
  pg   <- pdftools::pdf_data(pdfFile)
  txt  <- unlist(lapply(pg, function(d) if (nrow(d)) d$text else character(0)))
  dash <- .ppPlusMinusIsDash(.ppNormalizeGlyphs(txt))
  lapply(pg, function(d) {
    if (nrow(d)) {
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

  tmp <- tempfile("ppocr")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)

  # pdf_convert applies sprintf(filenames, page, format) itself, so hand
  # it the template - a pre-formatted name warns (found 2026-08-26).
  imgs <- pdftools::pdf_convert(
    pdfFile, format = "png", pages = pages, dpi = dpi, verbose = FALSE,
    filenames = file.path(tmp, "page%04d.%s"))

  if (want == "text")
    vapply(imgs, function(i) tesseract::ocr(i), character(1), USE.NAMES = FALSE)
  else
    lapply(imgs, function(i) tesseract::ocr_data(i))
}

.ppOcrData <- function(pdfFile, dpi = 300, pages = NULL) {
  pg <- .ppOcrPages(pdfFile, dpi = dpi, pages = pages, want = "data")
  if (is.data.frame(pg)) pg <- list(pg)
  lapply(pg, .ppOcrBoxes, scale = 72 / dpi)
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
.ppImageData <- function(imgFile, wordPt = .ppImageWordPt) {
  if (!requireNamespace("tesseract", quietly = TRUE))
    stop("Reading a table image needs the 'tesseract' package: ",
         "install.packages(\"tesseract\")", call. = FALSE)
  d <- as.data.frame(tesseract::ocr_data(imgFile), stringsAsFactors = FALSE)
  if (!nrow(d)) return(list(.ppOcrBoxes(d, 1)))
  bb <- do.call(rbind, lapply(strsplit(d$bbox, ","), as.numeric))
  h  <- bb[, 4] - bb[, 2]
  good  <- d$confidence > 50 & nchar(d$word) >= 2 & h > 0
  ruler <- if (any(good)) stats::median(h[good]) else stats::median(h[h > 0])
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

.ppDecimals <- function(txt) {
  txt <- .ppNumText(txt)
  ifelse(grepl("\\.", txt),
         nchar(sub("^[^.]*\\.", "", txt)),
         0L)
}

# Convert printed number text to numeric (comma / middle-dot decimals,
# thousands separators, stray < > signs from "<0.001"-style cells).
.ppAsNumeric <- function(txt) {
  suppressWarnings(as.numeric(.ppNumText(txt)))
}

# Collapse repeated whitespace and trim.
.ppSquish <- function(x) trimws(gsub("\\s+", " ", x))

# Clean a row label for use as the ROW entry: drop trailing "n (%)" /
# "no. (%)" annotations, a short trailing parenthetical unit like "(kg)"
# or "(yr)" (but NOT one containing "/" - that names categories, e.g.
# "(M/F)"), and trailing separator punctuation.
.ppCleanLabel <- function(label) {
  # Some PDFs map superscript footnote markers to control characters
  # (a BEL where a superscript "a" is printed - vocacapsaicin corpus,
  # 2026-08-22); strip them before anything pattern-matches the label.
  label <- gsub("[[:cntrl:]]", "", label)
  label <- .ppSquish(label)
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
# to the analysis, which applies it once, in one place (MBESS::s.u in the
# Integrity-Analysis server).
#
# ROUND_DISPERSION is the printed granularity of whichever of SD or SE was
# given. It cannot be inferred from ROUND_MEAN: a table may print "39 (4.06)".
.ppBaseColumns <- function() {
  c("TRIAL", "ROW", "N", "MEAN", "SD", "SE",
    "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION")
}
