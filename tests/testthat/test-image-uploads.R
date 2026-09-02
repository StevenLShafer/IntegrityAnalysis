# test-image-uploads.R - a picture of a table (jpg/png/tif/gif) as input.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-02 by Claude Code (model Claude Fable 5.1) at Steve      #
# Shafer's direction ("please start on the TIF / JPG upload"), with the    #
# image route in utils.R / parseBaselineTableHeuristics.R / aiFallback.R  #
# / app_server.R / apiService.R. Run and verified locally.                 #
#                                                                          #
# THE THREAT MODEL IS THE TEST PLAN. The uploader is the author under      #
# investigation and an image decoder is a classic attack surface, so       #
# the assertions below are, in order: the header parser reads the truth   #
# from the bytes and not the name; declared bombs are refused BEFORE any   #
# decoder runs; a real picture parses exactly like the page it was        #
# rendered from; a TIFF never reaches the model; and the app shades the    #
# result cyan. Fixtures are rendered from the synthetic PDFs with          #
# pdftools - no ImageMagick anywhere, by design.                           #
############################################################################

imgFrom <- function(pdf, fmt, dpi = 300, dir = tempdir()) {
  out <- file.path(dir, paste0("tbl_", dpi, ".", fmt))
  suppressWarnings(pdftools::pdf_convert(
    pdf, format = if (fmt == "jpg") "jpeg" else fmt, pages = 1, dpi = dpi,
    filenames = out, verbose = FALSE))
  out
}
rawFile <- function(bytes, ext, dir = tempdir()) {
  f <- tempfile(tmpdir = dir, fileext = ext)
  writeBin(as.raw(bytes), f)
  f
}
# A little-endian TIFF of n 10 x 10 directories chained together; with
# loop = TRUE the last directory points back at the first.
tiffChain <- function(n, loop = FALSE) {
  le16 <- function(v) c(v %% 256, v %/% 256)
  le32 <- function(v) c(v %% 256, (v %/% 256) %% 256, (v %/% 65536) %% 256,
                        (v %/% 16777216) %% 256)
  b <- c(0x49, 0x49, 0x2a, 0x00, le32(8))
  for (k in seq_len(n)) {
    nxt <- if (k < n) 8 + 30 * k else if (loop) 8 else 0
    b <- c(b, le16(2),
           le16(256), le16(3), le32(1), le16(10), le16(0),
           le16(257), le16(3), le32(1), le16(10), le16(0),
           le32(nxt))
  }
  rawFile(b, ".tif")
}

test_that("image dimensions come from the header, by magic bytes, with no decoder", {
  src <- syntheticPdfMeanSD()
  ps  <- pdftools::pdf_pagesize(src)[1, ]
  for (fmt in c("jpg", "png", "tiff")) {
    d <- .ppImageDims(imgFrom(src, fmt))
    expect_identical(d$format, c(jpg = "jpeg", png = "png", tiff = "tiff")[[fmt]],
                     info = fmt)
    expect_equal(d$width,  ps$width  * 300 / 72, tolerance = 0.01, info = fmt)
    expect_equal(d$height, ps$height * 300 / 72, tolerance = 0.01, info = fmt)
    expect_identical(d$pages, 1L)
  }
  # the name lies: PNG bytes called .jpg are still a PNG
  lie <- file.path(tempdir(), "lie.jpg")
  file.copy(imgFrom(src, "png"), lie, overwrite = TRUE)
  expect_identical(.ppImageDims(lie)$format, "png")
  # not an image at all, whatever it is called
  expect_null(.ppImageDims(rawFile(c(0x00, 0x11, 0x22, 0:199), ".jpg")))
  expect_null(.ppImageDims(src))
  expect_false(isTRUE(.ppImageOK(src)))
  expect_match(attr(.ppImageOK(src), "reason"), "whatever the file name says")
  # a real render passes, and carries its dimensions
  ok <- .ppImageOK(imgFrom(src, "jpg"))
  expect_true(isTRUE(ok))
  expect_identical(attr(ok, "dims")$format, "jpeg")
})

test_that("declared bombs are refused before any decoder runs", {
  # JPEG: SOI, then a SOF0 frame header declaring 65535 x 65535, then EOI
  jpg <- rawFile(c(0xff, 0xd8, 0xff, 0xc0, 0x00, 0x11, 0x08, 0xff, 0xff,
                   0xff, 0xff, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01,
                   0x03, 0x11, 0x01, 0xff, 0xd9), ".jpg")
  d <- .ppImageDims(jpg)
  expect_identical(c(d$width, d$height), c(65535, 65535))
  ok <- .ppImageOK(jpg)
  expect_false(isTRUE(ok))
  expect_match(attr(ok, "reason"), "megapixel")
  # the same header behind a 60 KB APP1 (EXIF) segment is still found
  exif <- c(0xff, 0xd8, 0xff, 0xe1, 0xea, 0x62, rep(0x00, 60000),
            0xff, 0xc0, 0x00, 0x11, 0x08, 0xff, 0xff, 0xff, 0xff, 0x03,
            0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xff, 0xd9)
  expect_identical(.ppImageDims(rawFile(exif, ".jpg"))$width, 65535)
  # PNG: an IHDR declaring 100000 x 100000
  png <- rawFile(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
                   0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52,
                   0x00, 0x01, 0x86, 0xa0, 0x00, 0x01, 0x86, 0xa0,
                   8, 2, 0, 0, 0, 0, 0, 0, 0), ".png")
  expect_identical(.ppImageDims(png)$width, 100000)
  expect_false(isTRUE(.ppImageOK(png)))
  # TIFF: a chain of twelve directories is refused; three is fine
  expect_identical(.ppImageDims(tiffChain(3))$pages, 3L)
  expect_identical(.ppImageDims(tiffChain(3))$width, 10)
  expect_true(isTRUE(.ppImageOK(tiffChain(3))))
  tw <- .ppImageOK(tiffChain(12))
  expect_false(isTRUE(tw))
  expect_match(attr(tw, "reason"), "pages")
  # ...and a directory pointer that loops is not a file
  expect_null(.ppImageDims(tiffChain(2, loop = TRUE)))
  # the engine refuses too, by name, before reading a pixel
  expect_error(parseBaselineTableHeuristics(tiffChain(12), quiet = TRUE),
               "Refused to read")
  expect_error(parseBaselineTableHeuristics(jpg, quiet = TRUE), "megapixel")
})

test_that("a JPEG, PNG or TIFF of a table parses like the page it was rendered from", {
  skip_if_not_installed("tesseract")
  skip_on_cran()
  src <- syntheticPdfMeanSD()
  direct <- parseBaselineTableHeuristics(src, quiet = TRUE)
  srt <- function(d) {
    d <- d[, c("ROW", "N", "MEAN", "SD")]
    d[order(d$ROW, d$N, d$MEAN, d$SD), , drop = FALSE]
  }
  for (fmt in c("jpg", "png", "tiff")) {
    r <- parseBaselineTableHeuristics(imgFrom(src, fmt), quiet = TRUE)
    expect_identical(r$engine, "heuristic-ocr", info = fmt)
    expect_true(all(r$provenance$ENGINE == "ocr"), info = fmt)
    expect_equal(srt(r$data), srt(direct$data), ignore_attr = TRUE, info = fmt)
  }
  # the scale came from the words, not from a dpi tag: the same word
  # lands on the same point coordinates from a 150-dpi and a 300-dpi JPEG
  half <- .ppImageData(imgFrom(src, "jpg", dpi = 150))[[1]]
  full <- .ppImageData(imgFrom(src, "jpg", dpi = 300))[[1]]
  w150 <- half[half$text == "Weight", ]
  w300 <- full[full$text == "Weight", ]
  expect_true(nrow(w150) >= 1 && nrow(w300) >= 1)
  expect_equal(w150$x[1], w300$x[1], tolerance = 0.05)
  expect_equal(w150$y[1], w300$y[1], tolerance = 0.05)
})

test_that("a TIFF never reaches the model; a JPEG goes as a JPEG image block", {
  skip_if_not_installed("tesseract")
  skip_on_cran()
  src <- syntheticPdfMeanSD()
  posted <- 0L
  testthat::local_mocked_bindings(
    .ppClaudePost = function(body, key) {
      posted <<- posted + 1L
      stop("must not be called")
    })
  r <- parseBaselineTable(imgFrom(src, "tiff"), ai = "fallback",
                          apiKey = "FAKE", quiet = TRUE)
  expect_identical(posted, 0L)
  expect_identical(r$engine, "heuristic-ocr")
  expect_true(any(grepl("OCR", r$flags)))

  seen <- NULL
  testthat::local_mocked_bindings(
    .ppClaudePost = function(body, key) { seen <<- body; stop("stop here") })
  expect_error(parseBaselineTableAI(imgFrom(src, "jpg"), apiKey = "FAKE",
                                    quiet = TRUE), "stop here")
  blk <- seen$messages[[1]]$content[[1]]
  expect_identical(blk$type, "image")
  expect_identical(blk$source$media_type, "image/jpeg")
  expect_true(nchar(blk$source$data) > 1000)
  # a PNG says so, and a rendered PDF page still says png
  expect_error(parseBaselineTableAI(imgFrom(src, "png"), apiKey = "FAKE",
                                    quiet = TRUE), "stop here")
  expect_identical(seen$messages[[1]]$content[[1]]$source$media_type, "image/png")
})

test_that("the app accepts a table image and shades the whole table cyan", {
  skip_if_not_installed("tesseract")
  skip_on_cran()
  d <- file.path(tempdir(), "imgup")
  dir.create(d, showWarnings = FALSE)
  up <- file.path(d, "table.jpg")
  file.copy(imgFrom(syntheticPdfMeanSD(), "jpg"), up, overwrite = TRUE)
  shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "table.jpg", datapath = up, stringsAsFactors = FALSE))
    expect_match(commentsLog(), "picture was read by optical character")
    expect_true("Age" %in% reactiveData()$ROW)
    reg <- parseDerived()
    expect_false(is.null(reg))
    expect_true(any(reg$KIND == "ocr"))
  })
  # a bomb is refused with the reason, and the app carries on. (Its own
  # directory: the purge-on-exit handler removed the first session's.)
  d2 <- file.path(tempdir(), "imgbomb")
  dir.create(d2, showWarnings = FALSE)
  bomb <- file.path(d2, "bomb.jpg")
  writeBin(as.raw(c(0xff, 0xd8, 0xff, 0xc0, 0x00, 0x11, 0x08, 0xff, 0xff,
                    0xff, 0xff, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01,
                    0x03, 0x11, 0x01, 0xff, 0xd9)), bomb)
  shiny::testServer(app_server, {
    session$setInputs(upload = data.frame(
      name = "bomb.jpg", datapath = bomb, stringsAsFactors = FALSE))
    expect_match(commentsLog(), "megapixel")
  })
})

test_that("the API preflights an image before spending a child on it", {
  bomb <- rawFile(c(0xff, 0xd8, 0xff, 0xc0, 0x00, 0x11, 0x08, 0xff, 0xff,
                    0xff, 0xff, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01,
                    0x03, 0x11, 0x01, 0xff, 0xd9), ".jpg")
  spawned <- 0L
  testthat::local_mocked_bindings(
    parseBaselineTableFiles = function(...) { spawned <<- spawned + 1L; stop("no") })
  r <- .apiReadUpload(bomb, "bomb.jpg")
  expect_false(r$ok)
  expect_match(r$reasons, "megapixel")
  expect_identical(spawned, 0L)
})
