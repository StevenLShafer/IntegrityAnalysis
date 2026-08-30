# mecaPrefixScreen.R - decide whether a medRxiv .meca is an RCT by
# reading the first ~64 KB of it, instead of downloading the whole thing.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-29 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request, after he asked whether the RCT filter could run on     #
# metadata BEFORE paying to download each package.                         #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# THE PROBLEM. s3://medrxiv-src-monthly is requester-pays. The 2026-08-28  #
# backfill downloaded 10,750 packages - 78 GB, about $7.03 - and kept 224  #
# RCT PDFs. Roughly 97% of every byte paid for was discarded, because the  #
# filter could only run after unpacking the .meca. The object keys are     #
# opaque UUIDs, so nothing about a package is knowable from its name, and  #
# the bucket publishes no DOI index.                                       #
#                                                                          #
# THE OPENING. A .meca is a ZIP, and medRxiv writes content/<id>.xml -     #
# the JATS record carrying DOI, title and abstract - as its FIRST entry,   #
# ahead of the PDF. A ranged GET of the first 64 KB therefore contains     #
# the entire article record. Measured over 40 packages sampled from two    #
# months (2026-08-29):                                                     #
#                                                                          #
#   XML was the first file entry     40/40                                 #
#   bytes needed  min 11.9 KB   median 22.6 KB   max 46.1 KB               #
#   prefix as a share of the package        0.30%                          #
#   verdict vs the full pipeline's manifest 40/40 agreement                #
#                                                                          #
# WHY THE AGREEMENT IS STRUCTURAL, NOT LUCK. The prefix yields the SAME    #
# title and abstract the full unpack yields, and this code hands them to   #
# the SAME classifyRct(). There is no second implementation to drift. An   #
# earlier Python approximation of two of the filter's patterns disagreed   #
# on 2 of 40; the real function agreed on all 40. That is the argument     #
# for calling the shared function rather than reimplementing it.           #
#                                                                          #
# FAIL OPEN, ALWAYS. Every uncertainty - a short read, an unexpected       #
# layout, a streamed entry whose size is not in the local header, an       #
# inflate error - returns decided = FALSE, and the caller downloads the    #
# package and lets the existing phase 2 decide. Screening may only ever    #
# SAVE a download; it may never cause a paper to be missed.                #
############################################################################

# 64 KB: comfortably past the 46.1 KB maximum observed, and still 1.6% of
# a median package. A fixed 48 KB window was measured too tight - one
# package in an earlier sample exceeded it - and the cost of overshooting
# is a few kilobytes, while the cost of undershooting is a wasted request.
.mpsWindow <- 65536L

# Read a little-endian unsigned integer of `n` bytes from raw vector `r`
# at 0-based offset `off`.
.mpsInt <- function(r, off, n) {
  sum(as.integer(r[(off + 1):(off + n)]) * 256^(seq_len(n) - 1))
}

# Walk the ZIP local file headers in `r`, returning the first entry whose
# name ends in .xml. Directory entries (names ending "/") are skipped:
# two of the 40 sampled packages began with a zero-length "content/"
# entry, which would otherwise look like a non-XML first entry and defeat
# the screen.
.mpsFindXml <- function(r) {
  off <- 0L
  repeat {
    if (off + 30L > length(r)) return(NULL)
    if (!identical(as.integer(r[(off + 1):(off + 4)]),
                   c(80L, 75L, 3L, 4L))) return(NULL)   # "PK\3\4"
    flags <- .mpsInt(r, off + 6L, 2L)
    method <- .mpsInt(r, off + 8L, 2L)
    csize <- .mpsInt(r, off + 18L, 4L)
    nlen  <- .mpsInt(r, off + 26L, 2L)
    elen  <- .mpsInt(r, off + 28L, 2L)
    if (off + 30L + nlen > length(r)) return(NULL)
    name <- rawToChar(r[(off + 31L):(off + 30L + nlen)])
    Encoding(name) <- "UTF-8"
    # bit 3 set means the sizes live in a data descriptor AFTER the data,
    # and the local header carries zeros - the length is then unknowable
    # from the prefix, so refuse rather than guess.
    if (bitwAnd(flags, 8L) != 0L && csize == 0L) return(NULL)
    if (grepl("[.]xml$", name, ignore.case = TRUE))
      return(list(off = off, nlen = nlen, elen = elen, csize = csize,
                  usize = .mpsInt(r, off + 22L, 4L),
                  crc = r[(off + 15L):(off + 18L)],
                  method = method, name = name))
    if (!endsWith(name, "/") && csize == 0L) return(NULL)  # nothing to skip by
    off <- off + 30L + nlen + elen + csize
  }
}

# Rebuild a one-entry ZIP from the bytes we fetched and let utils::unzip
# extract it. R has no raw-inflate primitive (memDecompress handles gzip
# and zlib wrappers, not the bare deflate stream a ZIP entry holds), so
# handing the work to unzip is both simpler and less to get wrong than
# synthesising a zlib header and trailer.
.mpsExtractXml <- function(r, e, exdir) {
  need <- e$off + 30L + e$nlen + e$elen + e$csize
  if (need > length(r)) return(NULL)              # XML exceeds the window
  local <- r[(e$off + 1L):need]
  nm <- charToRaw(e$name)
  int2 <- function(v) as.raw(c(v %% 256, (v %/% 256) %% 256))
  int4 <- function(v) as.raw(c(v %% 256, (v %/% 256) %% 256,
                               (v %/% 65536) %% 256, (v %/% 16777216) %% 256))
  cd <- c(as.raw(c(0x50, 0x4b, 0x01, 0x02)), int2(20), int2(20), int2(0),
          int2(e$method), int2(0), int2(0), e$crc,
          int4(e$csize), int4(e$usize), int2(length(nm)),
          int2(0), int2(0), int2(0), int2(0), int4(0), int4(0), nm)
  eocd <- c(as.raw(c(0x50, 0x4b, 0x05, 0x06)), int2(0), int2(0), int2(1),
            int2(1), int4(length(cd)), int4(length(local)), int2(0))
  zf <- tempfile(fileext = ".zip")
  on.exit(unlink(zf), add = TRUE)
  writeBin(c(local, cd, eocd), zf)
  ok <- tryCatch({ utils::unzip(zf, exdir = exdir); TRUE },
                 error = function(err) FALSE, warning = function(w) FALSE)
  if (!ok) return(NULL)
  f <- file.path(exdir, e$name)
  if (file.exists(f)) f else NULL
}

# Fetch the first .mpsWindow bytes of one object.
.mpsFetchPrefix <- function(awsExe, profile, bucket, key) {
  dst <- tempfile(fileext = ".bin")
  st <- tryCatch(
    suppressWarnings(system2(awsExe,
      c("s3api", "get-object", "--bucket", shQuote(bucket),
        "--key", shQuote(key), "--range",
        shQuote(paste0("bytes=0-", .mpsWindow - 1L)),
        "--request-payer", "requester", "--profile", shQuote(profile),
        shQuote(dst)), stdout = FALSE, stderr = FALSE)),
    error = function(e) 1L)
  if (!identical(as.integer(st), 0L) || !file.exists(dst)) return(NULL)
  on.exit(unlink(dst), add = TRUE)
  readBin(dst, "raw", n = file.info(dst)$size)
}

#' Screen one .meca by its prefix.
#'
#' @return list(decided, isRct, doi, title, abstract, license, bytes)
#'   decided = FALSE means "could not tell from the prefix - download it".
screenMecaPrefix <- function(awsExe, profile, bucket, key) {
  no <- list(decided = FALSE)
  r <- .mpsFetchPrefix(awsExe, profile, bucket, key)
  if (is.null(r) || length(r) < 64L) return(no)
  e <- .mpsFindXml(r)
  if (is.null(e)) return(no)
  exdir <- file.path(tempdir(), paste0("mps", basename(tempfile(""))))
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(exdir, recursive = TRUE), add = TRUE)
  f <- .mpsExtractXml(r, e, exdir)
  if (is.null(f)) return(no)
  out <- tryCatch({
    jats <- xml2::read_xml(f)
    doi <- xml2::xml_text(xml2::xml_find_first(
      jats, ".//front//article-id[@pub-id-type='doi']"))
    title <- xml2::xml_text(xml2::xml_find_first(jats, ".//front//article-title"))
    abstract <- paste(xml2::xml_text(
      xml2::xml_find_all(jats, ".//front//abstract//p")), collapse = " ")
    lic <- xml2::xml_text(xml2::xml_find_first(jats, ".//front//license"))
    # A record with no title AND no abstract tells us nothing; do not let
    # an empty parse masquerade as a confident "not an RCT".
    if (!nzchar(paste0(title, abstract))) return(no)
    list(decided = TRUE, isRct = classifyRct(title, abstract),
         doi = doi, title = title, abstract = abstract, license = lic,
         bytes = e$off + 30L + e$nlen + e$elen + e$csize)
  }, error = function(err) no)
  out
}
