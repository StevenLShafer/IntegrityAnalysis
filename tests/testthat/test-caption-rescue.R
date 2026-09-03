# Regressions from the 2026-08-25 corpus certification (parse rate
# 71.9% -> 83.1%): five files that "parsed" under the 2026-08-17 engine
# flipped to "No usable baseline table". Reproducing the OLD parses
# showed every one had been a misparse - a pain-scores table, a
# side-effects table, body prose, even the reference list - so the flip
# itself was progress. But tracing WHY the genuine Table 1 of each file
# was refused exposed three real defects, pinned here. Each fixture
# rebuilds the defeating layout synthetically (the articles are
# copyrighted; see corpus/README.md).
#
############################################################################
# Provenance                                                               #
# Drafted 2026-08-25 by Claude Code (model: Claude Fable 5) while          #
# adjudicating the five parse-outcome regressions of the corpus            #
# certification run (PR: caption-rescue). Run and verified against the     #
# full suite and the five corpus files named below.                        #
############################################################################

# --------------------------------------------------------------------------
# 1. Caption digits mistaken for a margin line-number rail
# --------------------------------------------------------------------------
# On a published BJA page (PMID_20952427, p. 4) the digits of "Table 1"
# .. "Table 3" - all at one x, ascending down the page - lined up with
# the numbered reference list at the page's foot into a fake rail:
# nine ascending integers, left of the body text's 10th percentile,
# spanning more than half the page. .ppStripLineNumberRail() removed
# them, .ppCaptionAnchors() then found no "Table <n>" pair, and the
# document's real tables never became candidates. The guard added
# 2026-08-25: a rail number is the LEFTMOST word of its visual line;
# a caption digit has the word "Table" to its left.
test_that("caption digits and a reference list are not stripped as a rail", {
  # Geometry distilled from the real page: three captions down the page,
  # a numbered reference list at the foot, body text right of x = 100.
  cap <- function(y, digit, rest)
    data.frame(text = c("Table", digit, rest), x = c(60, 81, 89),
               y = y, width = c(19, 4, 40), stringsAsFactors = FALSE)
  refs <- data.frame(text = c("16", "17", "18", "19", "22", "24"),
                     x = 63, y = seq(626, 706, by = 16), width = 8,
                     stringsAsFactors = FALSE)
  body <- data.frame(text = rep(c("subjects", "received", "caudal",
                                  "blockade", "after"), 8),
                     x = rep(c(100, 160, 220, 280, 340), 8),
                     y = rep(seq(140, 700, length.out = 8), each = 5),
                     width = 40, stringsAsFactors = FALSE)
  w <- rbind(cap(122, "1", "Subject"), cap(392, "2", "Comparison"),
             cap(582, "3", "Duration"), refs, body)
  out <- .ppStripLineNumberRail(w)
  # every caption digit survives, so the caption anchors still exist
  expect_identical(sum(out$x == 81), 3L)
  expect_identical(nrow(.ppCaptionAnchors(out)), 3L)
})

test_that("a genuine margin rail is still stripped", {
  # 25 integers standing alone in the left margin - nothing to their
  # left - spanning the page: the manuscript rail the stripper is for.
  rail <- data.frame(text = as.character(1:25), x = 20,
                     y = 60 + 26 * (1:25), width = 8,
                     stringsAsFactors = FALSE)
  body <- data.frame(text = rep(c("the", "patients", "were", "randomly",
                                  "assigned"), 5),
                     x = rep(c(72, 110, 160, 200, 260), 5),
                     y = rep(seq(112, 632, length.out = 5), each = 5),
                     width = 30, stringsAsFactors = FALSE)
  out <- .ppStripLineNumberRail(rbind(rail, body))
  expect_false(any(grepl("^\\d+$", out$text)))
})

# --------------------------------------------------------------------------
# 2. A wrapped caption's own legend text is not the table's end
# --------------------------------------------------------------------------
# Long captions wrap, and the wrapped text is exactly what the footnote
# stop-pattern hunts: "Table 1 Patient characteristics ..., / presented
# as mean (SD) or number" (PMID_20581215, p. 4). Stopping there killed
# the block before its first data line, the genuine Table 1 scored -Inf,
# and a results table won the document instead. Since 2026-08-25 a
# footnote-shaped line BEFORE the first data line is read as caption
# legend: a label line whose text still feeds the "a (b)" notation
# evidence. (A footnote after the data still ends the table - pinned by
# the syntheticPdfMeanSD fixture in test-parse-synthetic.R.)
wrappedCaptionPdf <- function(dir = tempdir()) {
  f  <- file.path(dir, "wrapped-caption.pdf")
  vx <- c(300, 420)
  makeTablePdf(f, c(
    list(list(x = 72, y = 80,
              text = "Table 1 Patient characteristics and intraoperative dose of",
              adj = 0),
         list(x = 72, y = 98,
              text = "fentanyl, presented as mean (SD) or number. Data are presented",
              adj = 0),
         list(x = 72, y = 116,
              text = "as mean (SD) with the exception of gender.", adj = 0)),
    rowCells(146, "", c("Control", "Treatment"), vx),
    rowCells(164, "", c("(n = 15)", "(n = 17)"), vx),
    rowCells(190, "Age (yr)",    c("45.3 (12.1)", "46.1 (11.8)"), vx),
    rowCells(208, "Weight (kg)", c("63 (13)",     "68 (12)"),     vx),
    rowCells(226, "Height (cm)", c("165 (7)",     "167 (7)"),     vx)
  ))
}

test_that("a caption wrapping into 'presented as ...' does not end the block", {
  res <- parseBaselineTableHeuristics(wrappedCaptionPdf(), trial = "T",
                                      quiet = TRUE)
  expect_identical(res$arms$N, c(15L, 17L))
  expect_identical(res$arms$arm, c("Control", "Treatment"))
  age <- res$data[res$data$ROW == "Age", ]
  expect_equal(age$MEAN, c(45.3, 46.1))
  # the legend's "mean (SD)" settled the "a (b)" reading - SD, not percent
  expect_equal(age$SD, c(12.1, 11.8))
})

# --------------------------------------------------------------------------
# 3. The next table's caption is not this table's footnote
# --------------------------------------------------------------------------
# The block ends where the next caption begins, but that caption's text
# used to be captured as footnote evidence. On PMID_20581215 "Table 2
# Pain scores ..., presented as median (inter-quartile range)" licensed
# the IQR reading of TABLE 1's "47 (21-65)" mean (range) cells, filing
# range bounds as quartiles - a correctness bug in what the Monte Carlo
# would then analyze. Since 2026-08-25 a new-caption stop feeds nothing
# to footnoteInfo, so the unlabeled interval is skipped for review.
nextCaptionPdf <- function(dir = tempdir()) {
  f  <- file.path(dir, "next-caption.pdf")
  vx <- c(300, 420)
  makeTablePdf(f, c(
    list(list(x = 72, y = 80, text = "Table 1 Baseline data", adj = 0)),
    rowCells(110, "", c("Control", "Treatment"), vx),
    rowCells(128, "", c("(n = 15)", "(n = 17)"), vx),
    rowCells(150, "Age (yr)",    c("47 (21-65)", "46 (22-65)"),   vx),
    rowCells(168, "Weight (kg)", c("63 ± 13", "68 ± 12"), vx),
    list(list(x = 72, y = 200,
              text = "Table 2 Pain scores, presented as median (inter-quartile range)",
              adj = 0)),
    rowCells(230, "15 min", c("2 (1-5)", "2 (0-5)"), vx)
  ))
}

test_that("the next caption's IQR wording cannot relabel this table's ranges", {
  res <- parseBaselineTableHeuristics(nextCaptionPdf(), trial = "T",
                                      quiet = TRUE)
  # Weight parses; Age's interval has no label anywhere in THIS table's
  # text, so it is skipped for hand review, not emitted as Q1/Q3
  expect_true("Weight" %in% res$data$ROW)
  expect_false(any(grepl("^Age", res$data$ROW)))
  expect_true(any(grepl("unlabeled interval", res$skipped$reason)))
  # and the pain-scores rows under Table 2 stayed out of the block
  expect_false(any(grepl("15 min", res$data$ROW, fixed = TRUE)))
})

# --------------------------------------------------------------------------
# 4. Springer's typographic spaces glue the caption numeral to its text
# --------------------------------------------------------------------------
# Springer sets "Table 1" + EN SPACE (U+2002) + THIN SPACE (U+2009) +
# caption, and poppler splits words only on ordinary spaces, so the token
# after "Table" was "1  Baseline" - not a numeral - and .ppCaptionAnchors()
# found nothing. The document's real Table 1 never became a candidate and
# the parser returned prose anchored on a cross-reference (Steve's
# ticagrelor article, Springer 10072_2022_6525, 2026-09-02). The fix splits
# such tokens at ingest, apportioning the word box by character count.
# Built with intToUtf8 so no editing tool can rewrite the escapes.
test_that("typographic spaces inside a token are split into words", {
  glued <- paste0("1", intToUtf8(0x2002), intToUtf8(0x2009), "Baseline")
  w <- data.frame(text = c("Table", glued, "criteria", "Character"),
                  x = c(51, 70, 111, 178), y = 56,
                  width = c(18, 38, 24, 33), stringsAsFactors = FALSE)
  expect_identical(nrow(.ppCaptionAnchors(w)), 0L)   # the defect
  s <- .ppSplitUnicodeSpaces(w)
  expect_identical(s$text, c("Table", "1", "Baseline", "criteria", "Character"))
  # the split words keep their order and share the original box
  expect_true(all(diff(s$x) > 0))
  expect_equal(s$x[3] + s$width[3], 70 + 38, tolerance = 1e-9)
  expect_identical(nrow(.ppCaptionAnchors(s)), 1L)
  # NBSP is a thousands separator in some journals and is left alone
  nb <- data.frame(text = paste0("1", intToUtf8(0xa0), "000"), x = 1, y = 1,
                   width = 20, stringsAsFactors = FALSE)
  expect_identical(.ppSplitUnicodeSpaces(nb)$text, nb$text)
})

# --------------------------------------------------------------------------
# 5. A side caption shares its line with the table's header row
# --------------------------------------------------------------------------
# Same article: the caption sits in a narrow margin column LEFT of a
# full-width table, level with its header, so the caption line read
# "Table 1 Baseline criteria of Character Ticagrelor arm Aspirin arm
# (n = 99) P-value". .ppParseBlock() starts on the line AFTER the caption,
# so the header - and arm 2's N - vanished, and all 15 n (%) rows were
# skipped for want of it. Geometry distilled from the real page.
sideCaptionLines <- function() {
  L <- function(y, text, x, width)
    data.frame(text = text, x = x, y = y, width = width,
               stringsAsFactors = FALSE)
  list(
    L(56, c("Table", "1", "Baseline", "criteria", "of",
            "Character", "Ticagrelor", "arm", "Aspirin", "arm", "(n", "=", "99)"),
      c(51, 70, 76, 111, 138, 178, 356, 394, 421, 449, 464, 472, 479),
      c(18, 4, 33, 24, 7, 33, 35, 13, 25, 13, 7, 5, 11)),
    L(65, "participants", 51, 40),
    L(69, c("(n", "=", "101)"), c(356, 364, 371), c(7, 5, 15)),
    L(87, c("Age,", "median", "(IQR)", "62", "(60-67)", "60.8", "(59-64)"),
      c(178, 196, 223, 356, 367, 421, 438), c(16, 25, 22, 9, 30, 15, 30)))
}

test_that("a side caption is split so the header row is read", {
  lines <- sideCaptionLines()
  s <- .ppSplitSideCaption(lines, 1L)
  expect_false(is.null(s))
  # the wrapped continuation joined the caption; the header became a line
  expect_identical(s$caption, "Table 1 Baseline criteria of participants")
  lt <- vapply(s$lines, .ppLineText, character(1))
  expect_identical(lt[1], "Table 1 Baseline criteria of")
  expect_identical(lt[2], "Character Ticagrelor arm Aspirin arm (n = 99)")
  expect_identical(lt[3], "(n = 101)")           # "participants" is gone
  expect_identical(length(s$lines), 4L)
})

test_that("a caption whose table runs UNDER it, left-edge aligned, is not split", {
  # BJA-style: "Table 1" then a wide gap then the caption text, and the
  # table body below starting at the same left edge. The first version
  # of the splitter saw only the gap, promoted "Patient characteristics
  # Control Treatment" to a header row, and cost arms and arm Ns on 13
  # corpus articles (before/after run, 2026-09-02).
  lines <- list(
    data.frame(text = c("Table", "1", "Patient", "characteristics"),
               x = c(60, 81, 120, 150), y = 100, width = c(19, 4, 28, 60),
               stringsAsFactors = FALSE),
    data.frame(text = c("Control", "Treatment"), x = c(250, 350), y = 118,
               width = c(30, 40), stringsAsFactors = FALSE),
    data.frame(text = c("(n", "=", "20)", "(n", "=", "22)"),
               x = c(250, 258, 264, 350, 358, 364), y = 130,
               width = c(7, 5, 12, 7, 5, 12), stringsAsFactors = FALSE),
    data.frame(text = c("Age", "45", "(12)", "46", "(11)"),
               x = c(60, 250, 264, 350, 364), y = 148,
               width = c(15, 10, 18, 10, 18), stringsAsFactors = FALSE),
    data.frame(text = c("Weight", "70", "(9)", "71", "(8)"),
               x = c(60, 250, 264, 350, 364), y = 166,
               width = c(28, 10, 14, 10, 14), stringsAsFactors = FALSE))
  expect_null(.ppSplitSideCaption(lines, 1L))
})

test_that("a foot-of-page caption beside the other column's prose is not split", {
  # A two-column page: the caption spans its whole (left) column and the
  # right column's prose shares the visual line. The leading run is far
  # wider than a margin column, so the line must be left alone - the
  # prose is not a header.
  lines <- list(
    data.frame(text = c("Table", "2", "Comparison", "of", "outcomes",
                        "between", "groups", "patients", "were", "randomly"),
               x = c(60, 81, 89, 140, 155, 195, 235, 320, 360, 385),
               y = 600, width = c(19, 4, 48, 12, 38, 36, 30, 36, 22, 40),
               stringsAsFactors = FALSE),
    data.frame(text = c("Outcome", "Group", "A", "Group", "B"),
               x = c(60, 150, 175, 220, 245), y = 615,
               width = c(35, 25, 6, 25, 6), stringsAsFactors = FALSE),
    data.frame(text = c("Pain", "3.2", "(1.1)", "3.4", "(1.2)"),
               x = c(60, 150, 165, 220, 235), y = 630,
               width = c(20, 12, 20, 12, 20), stringsAsFactors = FALSE))
  expect_null(.ppSplitSideCaption(lines, 1L))
})
