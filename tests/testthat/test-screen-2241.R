# Security screen 2026-09-07-2241, which screened the previous three
# merges and found the same class of thing four more times.
#
# F1 (MEDIUM-HIGH): the fine-precision Note - which screen 2000 adjudicated
# as the WHOLE remedy, disclosure having been chosen over refusal - was
# switched off by perturbing one arm's mean by a single unit in the last
# place, invisible to format(digits = 15), to .iaDecimals() and to the
# grid. The row still read the reportable floor, now silently.
# F2 (MEDIUM): every guard added this week points at the accusation
# direction. A precision stated COARSER than the printed digits drives p
# the other way and was neither refused nor disclosed.
# F3 (MEDIUM): the derived-cell payload loop was the quadratic the skip
# registry's had just been rewritten to remove, forty lines above it, over
# a registry with no cap at all (191.9 s for 100,000 painted keys).
# F4 (LOW): the skipped-line marker was recognised by a label prefix,
# which is the document's own text.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-08.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runRow <- function(D, m = 2000, seed = 1) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}
mk <- function(means, rm, ro = 1, rd = 1, N = 30, sd = 1)
  data.frame(TRIAL = "T", ROW = "X", N = rep(N, length(means)), MEAN = means,
             SD = rep(sd, length(means)), ROUND_MEAN = rm,
             ROUND_OBSERVATION = ro, ROUND_DISPERSION = rd,
             stringsAsFactors = FALSE)

test_that("F1: the fine-precision note survives a perturbation the engine cannot see", {
  # the note is the whole remedy for this shape, so a remedy the
  # manuscript can switch off is no remedy
  expect_false(grepl("stated mean precision", runRow(mk(c(0.5, 0.5, 0.5), 1))$NOTE))
  expect_match(runRow(mk(c(0.5, 0.5, 0.5), 15))$NOTE, "stated mean precision")
  ulp <- runRow(mk(c(0.5, 0.5 + 2^-52, 0.5), 15))
  expect_match(ulp$NOTE, "stated mean precision")
  # the engine's own view of these values is identical, which is the point
  expect_equal(.iaDecimals(0.5 + 2^-52), .iaDecimals(0.5))
  expect_identical(format(0.5 + 2^-52, digits = 15), format(0.5, digits = 15))
  # ...and means a printed unit apart still say nothing, as intended
  expect_false(grepl("stated mean precision", runRow(mk(c(0.5, 1.5, 2.5), 15))$NOTE))
})

test_that("F2: a precision stated COARSER than the printed digits is disclosed", {
  # the direction an author benefits from: p rises rather than falls, and
  # nothing refuses it because nothing about it is impossible
  alarm <- runRow(mk(c(50, 50, 50), 1, ro = 1, rd = 0, N = 100, sd = 30))
  quiet <- runRow(mk(c(50, 50, 50), -1, ro = 1, rd = 0, N = 100, sd = 30))
  expect_gt(as.numeric(sub("^<", "", quiet$P)), as.numeric(sub("^<", "", alarm$P)))
  expect_match(quiet$NOTE, "coarser than the digits")
  expect_false(grepl("coarser than the digits", alarm$NOTE))
  # the helper, on both columns
  expect_match(.iaCoarsePrecisionNote(50, -1, 1), "coarser")
  expect_match(.iaCoarsePrecisionNote(50, 1, -1), "coarser")
  expect_identical(.iaCoarsePrecisionNote(50, 0, 1), "")
  expect_identical(.iaCoarsePrecisionNote(50.25, 2, 2), "")
})

test_that("F3: the derived payload is linear and gives the same answer as the loop", {
  d <- data.frame(TRIAL = rep("T", 6), ROW = paste0("R", 1:6),
                  N = c(10, NA, 10, 10, 10, 10), MEAN = 1, SD = 1,
                  stringsAsFactors = FALSE)
  dv <- data.frame(TRIAL = "T", ROW = c("R1", "R2", "*"), COL = c("N", "N", "MEAN"),
                   KIND = c("derived", "failsafe", "ocr"),
                   note = c("a", "b", "c"), stringsAsFactors = FALSE)
  pay <- .iaDerivedPayload(d, dv)
  # R1's N is painted derived; R2's N is NA so it is not painted at all;
  # every row's MEAN is painted ocr by the "*" entry
  expect_equal(pay$iss[["0|2"]], "derived")
  expect_null(pay$iss[["1|2"]])
  expect_equal(pay$iss[["0|3"]], "ocr")
  expect_equal(pay$note[["0|3"]], "c")
  expect_equal(sum(unlist(pay$iss) == "ocr"), 6L)
  # and it is linear: 40,000 painted keys must not cost what 100,000 cost
  # the loop this replaced (191.9 s)
  skip_on_cran()
  big <- data.frame(TRIAL = rep("T", 4000), ROW = paste0("R", 1:4000),
                    N = 1, MEAN = 1, SD = 1, stringsAsFactors = FALSE)
  bigDv <- data.frame(TRIAL = "T", ROW = "*", COL = "*", KIND = "ocr",
                      note = "n", stringsAsFactors = FALSE)
  t <- system.time(p <- .iaDerivedPayload(big, bigDv))[["elapsed"]]
  expect_equal(length(p$iss), 4000L * 5L)
  expect_lt(t, 5)
})

test_that("F4: a marker row is recognised by its reason, not by the document's label", {
  blk <- function(n, lab = NULL) data.frame(
    label = if (is.null(lab)) paste("l", seq_len(n)) else lab,
    reason = "r", text = "t", stringsAsFactors = FALSE)
  # a sheet row labelled "... continued" must not be mistaken for a marker
  # the labelled row sits INSIDE the kept range, so what is tested is the
  # marker test itself and not the file budget
  blocks <- c(replicate(4, blk(1), simplify = FALSE),
              list(blk(1, "... continued")),
              replicate(250, blk(1), simplify = FALSE))
  out <- .iaCapSkippedFile(blocks)
  labs <- unlist(lapply(out, function(x) x$label))
  expect_true("... continued" %in% labs)
  expect_equal(sum(vapply(out, function(x) sum(.iaIsSkipMarker(x)), integer(1))), 1L)
  # the marker itself is still found
  expect_true(any(startsWith(labs, "... ") & labs != "... continued"))
})

test_that("both registries are capped for a session", {
  reg <- data.frame(TRIAL = "T", ROW = paste0("R", seq_len(9000)),
                    COL = "N", KIND = "derived", note = "n",
                    stringsAsFactors = FALSE)
  expect_equal(nrow(.iaCapRegistry(reg)), .iaMaxRegistryRows)
  small <- reg[1:5, , drop = FALSE]
  expect_identical(.iaCapRegistry(small), small)
})
