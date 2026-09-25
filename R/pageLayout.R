# pageLayout.R - finding the table page, its lines, and its columns.
#
############################################################################
# Provenance                                                               #
# Ported 2026-08-15 by Claude Code (model: Claude Opus 5, Anthropic) from  #
# parseCovariateTable.R in the Integrity-Analysis repository (drafted      #
# 2026-08-14 by Claude Code, model Claude Fable 5). Logic unchanged; only  #
# the `.pcv` -> `.pp` rename and the file split.                          #
# Deterministic: no AI service is called here.                            #
# Status: run and verified by tests/testthat/test-page-layout.R.          #
############################################################################

# ---------------------------------------------------------------------------
# Page scoring: which page holds the baseline covariate table?
# ---------------------------------------------------------------------------
# Scores are additive vocabulary hits plus a numeric-density term, so a page
# of prose that merely says "baseline" loses to the page that says
# "baseline characteristics" over a block of mean +/- SD cells.
.ppScorePage <- function(pageWords) {
  txt <- paste(pageWords$text, collapse = " ")
  score <- 0
  score <- score + 4 * grepl("(?i)baseline\\s+(patient\\s+|demographic\\s+)?characteristics", txt, perl = TRUE)
  score <- score + 3 * grepl("(?i)patient\\s+characteristics", txt, perl = TRUE)
  score <- score + 2 * grepl("(?i)demographic", txt, perl = TRUE)
  score <- score + 2 * grepl("(?i)\\bbaseline\\b", txt, perl = TRUE)
  score <- score + 2 * grepl("(?i)table\\s+1\\b", txt, perl = TRUE)
  # Numeric density typical of a Table 1
  score <- score + min(4, sum(grepl(.ppPLUSMINUS, pageWords$text, fixed = TRUE)) / 3)
  score <- score + 1 * grepl("(?i)\\bn\\s*=\\s*\\d+", txt, perl = TRUE)
  score
}

# ---------------------------------------------------------------------------
# Page columns: where are the article's text columns?
# ---------------------------------------------------------------------------
# Journal articles are typeset in two (sometimes three) columns, and a table
# usually sits inside one of them with body prose beside it. Clustering words
# into lines by y across the whole page width therefore glues each table row
# onto a sentence of unrelated prose - which is fatal, because the row label
# and the arm columns end up interleaved with words. Splitting the page into
# its typographic columns first is what makes real articles parseable.
#
# A column gutter is a vertical band of x that almost no line writes into.
# "Almost" matters: the running head, the article title, and a full-width
# footnote all cross the gutter, so a strict page-wide emptiness test finds
# nothing on a real page. We therefore measure, for each 1-point x bin, the
# fraction of text lines that cover it, and call a run of low-coverage bins a
# gutter.
#
# Returns a data frame of bands with columns x0, x1 - a single row spanning
# the page when no gutter is convincing.
.ppPageBands <- function(pageWords, minGap = 12, maxCover = 0.08,
                         minBandFrac = 0.2) {
  single <- function(w) data.frame(x0 = -Inf, x1 = Inf)
  if (is.null(pageWords) || nrow(pageWords) < 40) return(single(pageWords))

  left  <- min(pageWords$x)
  right <- max(pageWords$x + pageWords$width)
  W     <- right - left
  if (!is.finite(W) || W <= 0) return(single(pageWords))

  lines <- .ppBuildLines(pageWords)
  if (length(lines) < 8) return(single(pageWords))

  # Coverage: for each x bin, the fraction of lines that have a word over it.
  # the bins span the words' x range in points; a hostile PDF that places
  # a word far off the page would make that gigabytes (screen
  # 2026-09-06-1749, N2), so the span is clamped to a generous page
  # width - binOf() already pins out-of-range positions to the last bin
  nBin  <- max(10L, min(20000L, as.integer(ceiling(W))))
  cover <- numeric(nBin)
  binOf <- function(x) pmin(nBin, pmax(1L, as.integer(floor(x - left)) + 1L))
  for (L in lines) {
    hit <- logical(nBin)
    for (i in seq_len(nrow(L)))
      hit[seq.int(binOf(L$x[i]), binOf(L$x[i] + L$width[i]))] <- TRUE
    cover <- cover + hit
  }
  cover <- cover / length(lines)

  # Candidate gutters: long low-coverage runs away from the page margins.
  r     <- rle(cover <= maxCover)
  ends  <- cumsum(r$lengths)
  start <- ends - r$lengths + 1L
  # A NARROW GUTTER (2026-09-25, ISSUES.md issue 57; Altuntas 2016 TJAR,
  # Loadsman corpus): the two columns of that page are 9 points apart,
  # short of minGap, and with no band found the table in column 2 was
  # read interleaved with column 1's prose ("Sex 0.510" on the line "ence
  # to VAS (while resting, coughing, during mobilization)"). A run that
  # NO line of the page crosses at all is a gutter at eight points too:
  # a gap inside a table's own columns is crossed by the prose lines
  # above and below it, so zero coverage over the whole page is the
  # signature of the page's own layout, not of a table's.
  zeroRun <- vapply(seq_along(r$lengths), function(k)
    r$values[k] && all(cover[seq.int(start[k], ends[k])] == 0), logical(1))
  cand  <- which(r$values & (r$lengths >= minGap | (zeroRun & r$lengths >= 8)) &
                 start > minBandFrac * nBin & ends < (1 - minBandFrac) * nBin)
  if (length(cand) == 0) return(single(pageWords))

  # Keep at most two gutters (a three-column layout); prefer the widest.
  # THE WIDEST, AND NO HOLE (2026-09-25, ISSUES.md issue 72; Akkus 2020, J
  # Anesth, Loadsman corpus): the first version sorted the candidates by
  # width and then re-sorted them by position before taking two - the two
  # LEFTMOST runs, whatever their width - and then dropped any band
  # narrower than minBandFrac of the page. On that page three runs
  # qualified: two gaps inside Table 1's own columns (19 and 12 points)
  # and the page's real gutter (25 points). The two table gaps were
  # taken, the 55-point band between them was dropped, and the words in
  # it - the table's second arm, "Group triple" and every one of its
  # cells - belonged to no column and were read by no candidate. The
  # gutters are now taken widest first, and a gutter is kept only if
  # every band it leaves is at least minBandFrac of the page wide; a
  # narrower one is skipped, not cut and discarded. No band is ever
  # dropped, so every word of the page lies in exactly one band.
  cand <- cand[order(r$lengths[cand], decreasing = TRUE)]
  cutOf <- function(k) left + (start[k] + ends[k]) / 2
  chosen <- integer(0)
  for (k in cand) {
    if (length(chosen) >= 2L) break
    edges <- sort(c(left - 1, cutOf(c(chosen, k)), right + 1))
    if (min(diff(edges)) >= minBandFrac * W) chosen <- c(chosen, k)
  }
  if (length(chosen) == 0) return(single(pageWords))
  cuts  <- sort(cutOf(chosen))
  edges <- c(left - 1, cuts, right + 1)
  bands <- data.frame(x0 = utils::head(edges, -1), x1 = utils::tail(edges, -1))
  bands$x0[1] <- -Inf
  bands$x1[nrow(bands)] <- Inf
  bands
}

# Words whose horizontal centre falls inside one band.
.ppWordsInBand <- function(pageWords, band) {
  mid <- pageWords$x + pageWords$width / 2
  pageWords[mid > band$x0 & mid <= band$x1, , drop = FALSE]
}

# ---------------------------------------------------------------------------
# Margin line-number rails (submitted manuscripts)
# ---------------------------------------------------------------------------
# FIX (2026-08-20, measured on the A&A submitted-manuscript corpus):
# manuscripts under review number every line down the left margin. To the
# parser those numbers are a column of bare integers: they make prose lines
# look like data rows, and they seed the column clustering with an x
# position that belongs to no treatment arm. The rail is recognised - a run
# of small integers, left of essentially all other text, spanning most of
# the page, counting upward in small steps - and removed at the point of
# reading.
#
# The guards matter more than the detection. A "Patient no." column inside a
# table is also ascending integers, but it sits to the RIGHT of the row
# labels, so the "left of the 10th percentile of everything else" test
# excludes it; a page number or section number is a lone integer, not eight
# of them in a vertical run; and a column of counts in a table is neither
# ascending nor tall enough to span half the page.
.ppStripLineNumberRail <- function(pageWords) {
  if (is.null(pageWords) || nrow(pageWords) < 20) return(pageWords)
  isInt <- grepl("^\\d{1,4}$", pageWords$text)
  if (sum(isInt) < 8) return(pageWords)
  others <- pageWords[!isInt, , drop = FALSE]
  if (nrow(others) < 10) return(pageWords)
  textLeft <- stats::quantile(others$x, 0.10, names = FALSE)
  mid  <- pageWords$x + pageWords$width / 2
  rail <- isInt & mid < (textLeft - 6)
  # FIX (2026-08-25, found on 5 corpus files that lost their captions):
  # a rail number is the LEFTMOST word of its visual line - it stands
  # alone in the margin. A table-caption digit is not: "Table 1" prints
  # the word "Table" to its left. On published pages the caption digits
  # of "Table 1".."Table 3" plus the numbered reference list at the
  # page's foot lined up into a fake rail - ascending, left of the
  # body text's 10th percentile, spanning the page - and stripping them
  # deleted the numbers .ppCaptionAnchors() anchors on, so the
  # document's REAL tables never became candidates (PMID_20952427).
  # With caption digits excluded here, a reference list alone fails the
  # half-page span test below.
  for (i in which(rail)) {
    sameLine <- abs(pageWords$y - pageWords$y[i]) <= 3
    sameLine[i] <- FALSE
    if (any(sameLine & pageWords$x + pageWords$width <= pageWords$x[i]))
      rail[i] <- FALSE
  }
  if (sum(rail) < 8) return(pageWords)
  ys <- pageWords$y[rail]
  if (diff(range(ys)) < 0.5 * diff(range(pageWords$y))) return(pageWords)
  v  <- as.integer(pageWords$text[rail][order(ys)])
  dv <- diff(v)
  # Ascending by a small step: 1 for every-line numbering, up to 5 for
  # every-fifth-line numbering. The 0.7 threshold tolerates one mid-page
  # reset (continuous numbering restarting) without letting a column of
  # table counts - whose differences are effectively random - through.
  if (length(dv) == 0 || mean(dv %in% 1:5) < 0.7) return(pageWords)
  pageWords[!rail, , drop = FALSE]
}

# Rotated margin text - the "Downloaded from http://... by <institution>
# on <date>" watermark rail running up the edge of many published PDFs -
# arrives from pdf_data() with its glyph box SWAPPED: a multi-character
# word 5 points wide and up to hundreds of points tall. An upright word
# of two or more characters is never taller than it is wide, so the swap
# is a clean signature (single characters are exempt - an upright "I" is
# genuinely tall and narrow, and ASA class rows depend on it).
#
# Left in place, the rail shreds across the table's own text lines: on
# the vocacapsaicin corpus (2026-08-22) a lone "from" landed between two
# category rows and silently became the open block header - orphaning
# the remaining children into mean/SD rows - and the URL's digits seeded
# a phantom arm cluster whose missing N vetoed every n (%) row.
.ppStripRotatedText <- function(pageWords) {
  if (is.null(pageWords) || nrow(pageWords) < 8) return(pageWords)
  # candidate words: implausibly narrow for their length (the reported
  # "width" of a rotated word is the font height's ~5 points, whatever
  # its character count). Narrow UPRIGHT words exist too ("yr", "kg" in
  # a condensed font), which is why narrowness alone must not strip -
  # the rail test below is what decides.
  # THE OUP RAIL IS SEVEN POINTS WIDE (2026-09-25, ISSUES.md issue 86;
  # PMIDs 9389277 and 9861126, BJA, the corpus session's batch 21 AA1):
  # "Downloaded from https://academic.oup.com/bja/article/.../254374 by
  # ... user on 25 September 2026" runs up the right margin in a font one
  # point larger than the LWW rail this test was measured on, so none of
  # its words was narrow by the six-point rule; the URL's article number
  # became a fourth arm with N = 254996 and the validator refused the
  # table for its size. A rotated word is far taller than it is wide: a
  # word up to eight points wide whose height is at least twice its
  # width is a candidate too. An upright two-letter word is about as
  # wide as it is tall and stays.
  narrow <- (pageWords$width <= 6 |
               (pageWords$width <= 8 & pageWords$height >= 2 * pageWords$width)) &
    nchar(pageWords$text) >= 2
  if (sum(narrow) < 4) return(pageWords)
  # the rail: four or more narrow words sharing one x position and
  # spanning a third of the page's height - running text never stacks
  # words in a perfect vertical line.
  # THE SPAN IS MEASURED FROM THE TOP OF THE FIRST WORD TO THE BOTTOM OF
  # THE LAST, not between their y's (2026-09-24, Loadsman corpus, Akkaya
  # 2015 EJA). A rotated word's y is where its box STARTS; its text runs
  # on for `height` points - the URL alone is 120 points tall. Measured by
  # y only, the five words of that page's rail (Downloaded / from / the
  # URL / by / a token) spanned 184 of a 700-point page and the rail was
  # kept; "Downloaded" then straddled the table's "Mild" line and the
  # engine returned a row named "Downloaded Mild". By extent the same
  # rail spans 340 points.
  drop <- rep(FALSE, nrow(pageWords))
  top  <- pageWords$y
  bot  <- pageWords$y + pageWords$height
  pageSpan <- max(bot) - min(top)
  for (x0 in unique(pageWords$x[narrow])) {
    g <- which(narrow & abs(pageWords$x - x0) <= 1)
    if (length(g) >= 4 &&
        max(bot[g]) - min(top[g]) > 0.3 * pageSpan)
      drop[g] <- TRUE
  }
  if (!any(drop)) return(pageWords)
  pageWords[!drop, , drop = FALSE]
}

# A STRETCHED GLYPH (2026-09-25, ISSUES.md issue 44; Fujii 2002, PMID
# 12182258, Carlisle-168). Some PDFs carry a watermark or running head
# whose letters pdf_data() reports one at a time, each with a box a
# hundred points and more wide: "C", "A", "R", "ET" at 130 points each,
# with normal height, threaded between the table's lines and even off
# the page's left edge (x = -62). The rail stripper above looks for the
# opposite shape - a narrow, tall, rotated word - so these stayed, and
# each became a label line: "A" between "Age, y" and its "Mean +/- SD"
# line, "R" glued to "Duration of anesthesia" as "R Duration ...". No
# printed word is 30 points wide per character (body text runs 5-7, a
# display heading under 15), so the ratio alone identifies them.
.ppStripStretchedGlyphs <- function(pageWords) {
  if (is.null(pageWords) || nrow(pageWords) == 0) return(pageWords)
  perChar   <- pageWords$width / pmax(1L, nchar(pageWords$text))
  stretched <- !is.na(perChar) & perChar > 30 & pageWords$width > pageWords$height
  if (!any(stretched)) return(pageWords)
  pageWords[!stretched, , drop = FALSE]
}

# A TABLE PRINTED SIDEWAYS (2026-09-25, ISSUES.md issue 38; the corpus
# session's I1, RezkHiF2020). A wide table is often set rotated 90 degrees
# on a portrait page. pdf_data() reports each rotated word with its box
# swapped - a few points wide, as tall as the word is long - exactly the
# signature the watermark-rail stripper above removes, so the whole table
# vanished from the deterministic engine, and the caption page-chooser
# handed the model the OUTCOMES page instead. Here the rotated words of a
# page are found (a multi-character word taller than it is wide), and
# when there are enough of them to be a table rather than a rail - at
# least 30, and a fifth of the page's multi-character words - every word
# in their x-band (short words such as "8.21" or "+/-" are square and would
# not show as rotated) is transposed into an upright page: x' runs along
# the reading direction, y' across it. The block's reading direction is
# read from its caption: on a table rotated counter-clockwise (the usual
# case - the top of the table faces the left margin) the word after
# "Table" sits ABOVE it on the page, so x' = pageHeight - (y + height);
# clockwise, below, so x' = y. The result is appended to the document's
# pages as an extra page that reads through the ordinary pipeline; the
# driver maps it back to the real page for reporting and for the model's
# page image.
.ppRotatedBlock <- function(w, pageHeight) {
  if (is.null(w) || nrow(w) < 30) return(NULL)
  multi <- nchar(w$text) >= 3
  rot   <- multi & w$height > w$width
  if (sum(rot) < 30 || mean(rot[multi]) < 0.2) return(NULL)
  # the block: every rotated word, plus the short words (a "+/-", a "162)")
  # inside the rotated words' box - a short word is as wide as it is tall
  # and cannot show its rotation; upright prose in the same x-band but
  # outside the box is left out
  x0 <- min(w$x[rot]) - 6; x1 <- max(w$x[rot] + w$width[rot]) + 6
  y0 <- min(w$y[rot]) - 6; y1 <- max(w$y[rot] + w$height[rot]) + 6
  inBox <- w$x >= x0 & w$x + w$width <= x1 & w$y >= y0 & w$y + w$height <= y1
  keep  <- rot | (!multi & inBox)
  blk <- w[keep, , drop = FALSE]
  rot <- rot[keep]
  if (nrow(blk) < 30) return(NULL)
  # reading direction from a caption anchor: the word that follows
  # "Table" in the same column of text
  ccw <- TRUE
  ti <- which(rot & grepl("(?i)^tab(le|\\.)$", blk$text))
  if (length(ti)) {
    i <- ti[1]
    same <- which(abs(blk$x - blk$x[i]) <= 2 & seq_len(nrow(blk)) != i)
    if (length(same)) {
      # nearest neighbour in that column, by gap from the anchor's box
      gapAbove <- blk$y[i] - (blk$y[same] + blk$height[same])
      gapBelow <- blk$y[same] - (blk$y[i] + blk$height[i])
      above <- same[gapAbove >= 0]; below <- same[gapBelow >= 0]
      dA <- if (length(above)) min(gapAbove[gapAbove >= 0]) else Inf
      dB <- if (length(below)) min(gapBelow[gapBelow >= 0]) else Inf
      ccw <- dA <= dB
    }
  }
  out <- blk
  if (ccw) {
    out$x <- pageHeight - (blk$y + blk$height)
  } else {
    out$x <- blk$y
  }
  out$y      <- blk$x
  out$width  <- blk$height
  out$height <- blk$width
  out[order(out$y, out$x), , drop = FALSE]
}

# ---------------------------------------------------------------------------
# Table captions: "Table 1", "TABLE I", "Tab. 2"
# ---------------------------------------------------------------------------
# Numbering style varies by journal - Anaesthesia and CJA print Roman
# numerals, most others Arabic - so both are matched. The anchor is found as a
# pair of adjacent words rather than by a regex over the joined line, because
# on a two-column page the joined line may contain prose from the other
# column.
.ppCaptionAnchors <- function(pageWords) {
  empty <- data.frame(x = numeric(0), y = numeric(0), startsBlock = logical(0))
  if (is.null(pageWords) || nrow(pageWords) == 0) return(empty)
  w    <- pageWords[order(pageWords$y, pageWords$x), ]
  isTb <- grepl("^(?i)(table|tab\\.?)$", w$text, perl = TRUE)
  # ... or a SUPPLEMENTARY table's, "S1" (2026-09-25, ISSUES.md issue 58;
  # 2018RezkIJGO in the Loadsman corpus files its baseline table as "Table
  # S1. Characteristics of the study participants" while Table 1 is an
  # outcome; the anchor knew only a plain numeral and the paper's only
  # baseline table was never a candidate)
  isNo <- grepl("^(S?[0-9]{1,2}|[IVXLivxl]{1,4})[.:)]?$", w$text)
  sameLine <- c(abs(diff(w$y)) <= 3, FALSE)
  # "Table" immediately followed by a numeral on the same visual line
  hit  <- which(isTb & c(utils::tail(isNo, -1), FALSE) & sameLine)
  # An UNNUMBERED caption (issue 39, 2026-09-25): a paper with a single
  # table may print it as "TABLE Demographic data" (CJA 1997, 2003 - the
  # Saitoh papers of the Loadsman corpus), and requiring a numeral lost
  # the whole table. The word is "TABLE" or "Table" itself - not "table"
  # inside a sentence ("the table and the knee of the patient") - and the
  # word after it is a Capitalised word, which a numeral ("I", "II") and
  # a cross-reference ("Table shows") are not. Unlike a numbered anchor
  # the unnumbered one must START its block: the only evidence that
  # "Table" is a caption at all is the gap to its left.
  isBare <- grepl("^(TABLE|Table)$", w$text)
  isCap  <- grepl("^[A-Z][a-z]+", w$text)
  hitU   <- which(isBare & c(utils::tail(isCap, -1), FALSE) & sameLine)
  hitU   <- setdiff(hitU, hit)
  hit    <- sort(c(hit, hitU))
  if (length(hit) == 0) return(empty)

  # A caption begins a block of text; a cross-reference sits inside a
  # sentence ("as demonstrated in Table 3 B and C, where ..."), with a word
  # right before it. Without this test the prose under such a mention gets
  # parsed as a table.
  #
  # The test is a *gap* to the left, not the absence of anything to the left:
  # a full-width table at the foot of a two-column page has its caption on the
  # same visual line as the other column's prose, and requiring nothing to the
  # left would reject exactly those captions.
  # Rather than discard the cross-references, flag them: they are ranked last
  # so a real caption always wins, but they remain available when a document
  # yields nothing else. Excluding them outright cost real tables whose
  # captions this test misjudged.
  startsBlock <- vapply(hit, function(i) {
    same <- abs(w$y - w$y[i]) <= 3 & w$x < w$x[i]
    if (!any(same)) return(TRUE)
    (w$x[i] - max(w$x[same] + w$width[same])) >= 30
  }, logical(1))
  keep <- startsBlock | !(hit %in% hitU)      # an unnumbered anchor must start its block
  data.frame(x = w$x[hit][keep], y = w$y[hit][keep], startsBlock = startsBlock[keep])
}

# Does a line of text BEGIN a table caption? "Table 1", "TABLE II",
# "Tab. 3" - or, since issue 39, the unnumbered "TABLE Demographic data"
# (an all-caps or capitalised "Table" followed by a Capitalised word).
# Used wherever a new caption ends the block being read: the block
# walker, the continuation-page extender and the TATR adapter all asked
# the same numbered-only question before, and an unnumbered caption on
# the next page would have been swallowed as that page's data.
.ppCaptionStart <- function(txt) {
  grepl("(?i)^\\s*(table|tab\\.?)\\s+(S?[0-9]{1,2}|[IVXLivxl]{1,4})\\b", txt, perl = TRUE) |
    grepl("^\\s*(TABLE|Table)\\s+[A-Z][a-z]+", txt, perl = TRUE)
}

# A SIDE CAPTION shares its visual line with the table's own header row.
# Springer prints "Table 1 Baseline criteria of / participants" in a
# narrow margin column to the LEFT of a full-width table, level with the
# header, so the caption's line reads "Table 1 Baseline criteria of
# Character Ticagrelor arm Aspirin arm (n = 99) P-value". .ppParseBlock()
# starts at the line AFTER the caption, so that header - and arm 2's N
# with it - was never read, and every n (%) row was then skipped for want
# of the N (Steve's ticagrelor article, Springer 10072_2022_6525,
# 2026-09-02: 15 of 18 variables lost to a header that was on the page).
#
# The signature is geometric, and deliberately strict, because a caption
# at the FOOT of a two-column page also shares its line with the other
# column's prose, and that prose must not be promoted to a header:
#   - the anchor word leads the line;
#   - a gap of >= 25 pt (the package's column-gap tolerance) follows a
#     leading run of words spanning at most 30% of the band's width - a
#     margin column, not a text column;
#   - the words right of the gap hold no caption of their own;
#   - THE TABLE BODY SITS BESIDE THE CAPTION, NOT UNDER IT: of the lines
#     that follow, those not wholly inside the margin column start right
#     of it. This is the test that separates a side caption from the
#     common "Table 1 <wide gap> Patient characteristics" caption whose
#     table then runs full width from the left edge: the first version
#     lacked it and fired on 207 of 1,865 corpus articles, and on 13 of
#     those it pushed the caption text into the header row and cost arms
#     and arm Ns (before/after run, 2026-09-02).
# Then the leading run stays the caption, the remainder becomes the next
# line, and in the few lines below, words lying wholly within the
# caption's x-range - its wrapped continuation, "participants" - are moved
# into the caption text rather than left to be read as a category header.
# Returns NULL when the line is not a side caption.
.ppSplitSideCaption <- function(lines, li, maxLead = 0.3, gap = 25) {
  L <- lines[[li]]
  if (is.null(L) || nrow(L) < 3) return(NULL)
  L <- L[order(L$x), ]
  if (!grepl("^(?i)(table|tab\\.?)$", L$text[1], perl = TRUE)) return(NULL)
  ends <- L$x + L$width
  gaps <- L$x[-1] - ends[-nrow(L)]
  g <- which(gaps >= gap)
  if (!length(g)) return(NULL)
  g <- g[1]
  if (g < 2) return(NULL)                       # "Table" alone is not a caption
  bandX0 <- min(vapply(lines, function(z) min(z$x), numeric(1)))
  bandX1 <- max(vapply(lines, function(z) max(z$x + z$width), numeric(1)))
  if (ends[g] - L$x[1] > maxLead * (bandX1 - bandX0)) return(NULL)
  cap  <- L[seq_len(g), , drop = FALSE]
  rest <- L[seq(g + 1, nrow(L)), , drop = FALSE]
  if (any(grepl("^(?i)(table|tab\\.?)$", rest$text, perl = TRUE))) return(NULL)
  capX1 <- ends[g]
  # the body test: look at up to six lines below; a line lying wholly
  # inside the margin column is the caption's own wrap and does not vote
  if (li >= length(lines)) return(NULL)
  below <- lines[seq(li + 1, min(li + 6, length(lines)))]
  inCol <- vapply(below, function(z) all(z$x + z$width <= capX1 + 2), logical(1))
  starts <- vapply(below[!inCol], function(z) min(z$x), numeric(1))
  if (length(starts) < 2 || mean(starts >= capX1 + gap / 2) < 0.75) return(NULL)
  out <- append(lines, list(rest), after = li)
  out[[li]] <- cap
  capText <- cap$text
  # wrapped continuation: up to four lines below, words entirely within
  # the margin column (right edge at or before the caption's, and clear of
  # the table by the same gap)
  for (j in seq(li + 2, min(li + 5, length(out)))) {
    if (j > length(out)) break
    Z <- out[[j]]
    cont <- (Z$x + Z$width) <= capX1 + 2 & Z$x < rest$x[1] - gap
    if (!any(cont)) next
    capText <- c(capText, Z$text[cont])
    out[[j]] <- Z[!cont, , drop = FALSE]
  }
  keep <- vapply(out, nrow, integer(1)) > 0
  list(lines = out[keep], caption = .ppSquish(paste(capText, collapse = " ")))
}

# How much does this caption look like a baseline-characteristics table?
# Used to choose between "Table 1 Patient characteristics" and "Table 2
# Intraoperative drug usage" on the same page.
.ppCaptionScore <- function(txt) {
  s <- 0
  s <- s + 4 * grepl("(?i)baseline", txt, perl = TRUE)
  s <- s + 4 * grepl("(?i)demographic|anthropometric", txt, perl = TRUE)
  # "Characteristics" only means baseline data when it is qualified. Bare
  # "Characteristics of sensory and motor blocks" is a results table, and
  # scoring it as a baseline table made it beat the real one.
  qualChar <- paste0("(?i)(patient|baseline|demographic|clinical|subject",
                     "|participant|study|group)s?[' ]*\\s*characteristic",
                     "|characteristics\\s+of\\s+(the\\s+)?",
                     "(patient|subject|participant|study|group|population)")
  s <- s + 3 * grepl(qualChar, txt, perl = TRUE)
  s <- s + 1 * (grepl("(?i)characteristic", txt, perl = TRUE) &&
                  !grepl(qualChar, txt, perl = TRUE))
  s <- s + 2 * grepl("(?i)patient(s)?\\s+(data|profile|detail)", txt, perl = TRUE)
  s <- s + 1 * grepl("(?i)preoperative|pre-operative|on\\s+admission", txt, perl = TRUE)
  s <- s + 1 * grepl("(?i)\\bpatients?\\b|\\bsubjects?\\b|\\bgroups?\\b", txt, perl = TRUE)
  # Baseline data is nearly always the first table, so its number is evidence
  # in its own right - enough to separate "Table 1 Patient data" from
  # "Table 4 Patient data at 24 h".
  # Switched on 2026-09-25 (issue 40): the pattern had been case-sensitive
  # since it was written, so it never fired on a printed "Table 1" or
  # "TABLE I". Measured before switching (corpus/measureMisparse.R, 1,110
  # Carlisle-linked PDFs, main dc39659): fully corroborated files 435 ->
  # 444 of ~940 with this +2, 441 with +1; twelve files up, two down
  # (PMID 14687093 and 14722167, where the bonus picks the paper's real
  # Table 1 but the reading of it is poor and Carlisle recorded Table 2).
  # An unnumbered caption ("TABLE Demographic data", issue 39) is a
  # paper's only table, so its first: it takes the bonus too.
  s <- s + 2 * (grepl("(?i)^\\s*(table|tab\\.?)\\s+(1|I)\\b", txt, perl = TRUE) ||
                grepl("^\\s*(TABLE|Table)\\s+[A-Z][a-z]+", txt, perl = TRUE))
  # Tables of results are not baseline tables, even when they tabulate people.
  # But the penalty must not override an explicit announcement: "Table 1
  # Baseline and pre- and intra-operative data" is a baseline table that
  # happens to mention intra-operative variables, and docking it for that
  # pushed a real baseline table below the threshold.
  saysBaseline <- grepl("(?i)baseline|demographic", txt, perl = TRUE) ||
    grepl(qualChar, txt, perl = TRUE)
  if (!saysBaseline)
    s <- s - 3 * grepl(paste0("(?i)outcome|complication|adverse|side.?effect",
                              "|intra-?operative|post-?operative|pain score",
                              "|recovery|haemodynamic|hemodynamic"),
                       txt, perl = TRUE)
  s
}

# The "Table N" anchors a caption line names, lower-cased and squished:
# "TABLE I Baseline characteristics TABLE III Treatment outcomes" gives
# c("table i", "table iii"). Used by the candidate scorer to recognise a
# full-width block that straddles two side-by-side tables (issue 35).
.ppCaptionAnchorList <- function(txt) {
  if (is.null(txt) || length(txt) != 1L || is.na(txt)) return(character(0))
  m <- regmatches(txt, gregexpr("(?i)\\btab(le|\\.)\\s+(s?[0-9]+|[ivx]+)\\b", txt, perl = TRUE))[[1]]
  tolower(gsub("\\s+", " ", m))
}

# A candidate whose caption names two tables is a full-width block that
# STRADDLES two side-by-side tables, and its rows are two tables' rows.
# When the page also offers the halves - a TWIN: a candidate on the same
# page whose caption BEGINS with the same first table and names no other -
# the straddle is MARKED ($straddleTwin = the shared first anchor, e.g.
# "table 1") and the candidate loop defers it: it competes only if the
# twin itself yields no usable reading. A prose candidate "... presented
# in table 1. The CSF ..." is not a twin (its anchor is mid-sentence, and
# it has no rows), and a page with no split at all keeps its straddle,
# because it is the only reading holding the baseline table.
#
# Why a mark and not a score (2026-09-25, misparse run 3): setting the
# straddle's capScore to -100 let a twin that parses to NOTHING still
# knock it out - on PMID 20608923 the "Table 1" column candidate has no
# usable rows, the straddle held Height and Weight, and an outcome table
# (Table 2) won instead. Whether the twin delivers is known only after
# it is parsed, so the decision belongs to the selection loop. Each
# element of `cand` carries $page, $caption and $capScore; the list comes
# back with $straddleTwin set on the straddles and nothing else touched.
# Tested with hand-built candidate lists in test-loadsman-layouts.R; the
# corpus pages that decided the rule are in corpus/checkCaptionStraddle.R.
.ppSetAsideStraddles <- function(cand) {
  if (length(cand) < 2) return(cand)
  anchorsOf <- lapply(cand, function(x) .ppCaptionAnchorList(x$caption))
  nAnch  <- lengths(anchorsOf)
  firstA <- vapply(anchorsOf, function(a) if (length(a)) a[1] else NA_character_, character(1))
  capLow <- vapply(cand, function(x) tolower(.ppSquish(as.character(x$caption))), character(1))
  startsWithAnchor <- !is.na(firstA) &
    mapply(function(cp, a) !is.na(a) && startsWith(cp, a), capLow, firstA)
  pageOfC <- vapply(cand, function(x) as.numeric(x$page), numeric(1))
  for (k in which(nAnch >= 2)) {
    twin <- pageOfC == pageOfC[k] & nAnch == 1 & startsWithAnchor &
      !is.na(firstA) & firstA == firstA[k]
    if (any(twin)) cand[[k]]$straddleTwin <- firstA[k]
  }
  cand
}

# The key under which a candidate counts as a parsed TWIN for the rule
# above: its page and the single anchor its caption begins with, or NA
# when it is not such a candidate.
.ppTwinKey <- function(x) {
  a <- .ppCaptionAnchorList(x$caption)
  if (length(a) != 1L) return(NA_character_)
  if (!startsWith(tolower(.ppSquish(as.character(x$caption))), a)) return(NA_character_)
  paste(x$page, a)
}

# Which page carries the most baseline-like table caption?
#
# This is how a page is chosen for the AI engine, and it matters more than it
# looks: sending the model the wrong page is indistinguishable, from its side,
# from an article with no baseline table. Selecting by caption instead of by
# the vocabulary score in .ppScorePage() took the table fallback from 50% to
# 79% of known values over the corpus trials it is meant to rescue, and turned
# seven outright "no table on this page" refusals into answers.
#
# Returns NULL when the document has no caption at all, leaving the caller to
# fall back on .ppScorePage().
.ppBestCaptionPage <- function(allPages, pageIdx = seq_along(allPages)) {
  best <- -Inf
  bestPage <- NULL
  for (p in pageIdx) {
    w <- allPages[[p]]
    if (is.null(w) || nrow(w) == 0) next
    bands <- .ppPageBands(w)
    for (b in seq_len(nrow(bands))) {
      bw <- .ppWordsInBand(w, bands[b, ])
      if (nrow(bw) < 10) next
      anchors <- .ppCaptionAnchors(bw)
      if (nrow(anchors) == 0) next
      lines <- .ppBuildLines(bw)
      lt    <- vapply(lines, .ppLineText, character(1))
      for (i in seq_len(nrow(anchors))) {
        li <- which.min(vapply(lines, function(L) min(abs(L$y - anchors$y[i])),
                               numeric(1)))
        # No penalty for an anchor that does not begin its line, unlike the
        # candidate ranking in parseBaselineTableHeuristics(). There, a
        # penalised candidate is still tried; here exactly one page is chosen
        # and there is no second chance, and the penalty demoted the correct
        # page in two of twenty-one corpus trials - both of which then came
        # back as "no table on this page". A bare cross-reference scores low
        # on caption text anyway, so the penalty buys little here.
        s <- .ppCaptionScore(lt[li])
        if (s > best) { best <- s; bestPage <- p }
      }
    }
  }
  bestPage
}

# ---------------------------------------------------------------------------
# Lines: cluster the words of a page into visual lines by y coordinate
# ---------------------------------------------------------------------------
.ppBuildLines <- function(pageWords, yTol = 3) {
  pageWords <- pageWords[order(pageWords$y, pageWords$x), ]
  # New line whenever the y gap to the previous word exceeds yTol points
  lineId <- cumsum(c(1, diff(pageWords$y) > yTol))
  lines  <- split(pageWords, lineId)
  lines  <- lapply(lines, function(d) d[order(d$x), ])
  # Keep reading order (top to bottom)
  lines[order(vapply(lines, function(d) min(d$y), numeric(1)))]
}

.ppLineText <- function(line) .ppSquish(paste(line$text, collapse = " "))

# ---------------------------------------------------------------------------
# 1-D clustering of token midpoints into table columns
# ---------------------------------------------------------------------------
# Sort the midpoints and cut where the gap between neighbors exceeds
# `gapTol` points.  Column spacing in a journal table is typically well
# over 40 pt while jitter within a column (mean +/- SD vs a lone count)
# stays under ~20 pt.
#
# THE HEADER'S ARM COUNT AS A SECOND OPINION (2026-09-25, ISSUES.md issue
# 71; Fujii & Itakura 2009, PMID 19358990, the corpus session's batch 15a
# T1). That table's three columns are 35 points apart and the "(n = 30)"
# header tokens sit 8 points right of the cells beneath them, so the gap
# between the first two columns' tokens narrows to 22 points and the
# gap rule fused them: two arms, "Placebo Propofol, 0.25" and "g/kg
# Propofol, 0.5 mg/kg", on every build. With `k` given - the number of
# "(n = k)" groups the header prints - and the gap rule finding fewer
# columns than that, the midpoints are cut at the k - 1 largest gaps
# instead, and the cut is accepted only when the narrowest of those gaps
# is a real column gap (at least `minGap` points) and wider than every
# column's own spread; otherwise NULL, and the caller keeps the gap rule's
# answer. A header that counts a "total" column among its groups asks for
# one column too many, and the spread test refuses the split of a real
# column, whose inner gaps are a few points.
.ppClusterColumns <- function(mids, gapTol = 25, k = NULL, minGap = 12) {
  o <- order(mids)
  s <- mids[o]
  if (!is.null(k)) {
    if (length(s) < k || k < 2L) return(NULL)
    gaps <- diff(s)
    cutAt <- sort(order(gaps, decreasing = TRUE)[seq_len(k - 1L)])
    if (min(gaps[cutAt]) < minGap) return(NULL)
    cl <- cumsum(c(1, seq_along(gaps) %in% cutAt))
    spread <- tapply(s, cl, function(v) max(v) - min(v))
    if (max(spread) >= min(gaps[cutAt])) return(NULL)
  } else {
    cl <- cumsum(c(1, diff(s) > gapTol))
  }
  centers <- tapply(s, cl, mean)
  list(assign = function(x) {
         # nearest center
         vapply(x, function(v) which.min(abs(centers - v)), integer(1))
       },
       centers = as.numeric(centers),
       n = length(centers))
}
