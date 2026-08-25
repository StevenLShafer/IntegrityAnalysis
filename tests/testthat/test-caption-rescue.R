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
