# test-one-cohort-pre-post-table.R - a table headed by exactly one
# before/after pair over two columns is one cohort's before-and-after, not
# two arms: the block is refused and the document's baseline table is read
# instead (ISSUES.md issue 155, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 1 AJ1 (CJA 2000, PMID 10730740, canine    #
# landiolol): Table I "Pre-intoxication / Post-intoxication" scored as two #
# arms with no N ahead of the paper's Table II.                             #
############################################################################

pm <- "\u00b1"

prePostPdf <- function(file = file.path(tempdir(), "prePost.pdf")) {
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  vx <- c(330, 420)
  row2 <- function(y, label, a, b) list(w(60, y, label), w(vx[1], y, a), w(vx[2], y, b))
  vy <- c(240, 330, 420)
  row3 <- function(y, label, cells) c(list(w(60, y, label)), lapply(1:3, function(k) w(vy[k], y, cells[k])))
  cells <- c(
    list(w(60, 60, "TABLE I Hemodynamic changes after theophylline intoxication")),
    list(w(vx[1], 84, "Pre-intoxication"), w(vx[2], 84, "Post-intoxication")),
    row2(106, "HR (bpm)", paste("129", pm, "21"), paste("193", pm, "27*")),
    row2(122, "SBP (mmHg)", paste("139", pm, "25"), paste("121", pm, "25*")),
    row2(138, "DBP (mmHg)", paste("98", pm, "16"), paste("75", pm, "15*")),
    row2(154, "MBP (mmHg)", paste("114", pm, "18"), paste("94", pm, "17*")),
    row2(170, "CVP (mmHg)", paste("1.7", pm, "0.9"), paste("1.9", pm, "0.7")),
    row2(186, "MPAP (mmHg)", paste("13", pm, "4"), paste("13", pm, "3")),
    row2(202, "PAOP (mmHg)", paste("5", pm, "2"), paste("6", pm, "2")),
    row2(218, "CO (L/min)", paste("2.4", pm, "0.5"), paste("2.0", pm, "0.4*")),
    row2(234, "SVR (dyn)", paste("3810", pm, "620"), paste("3120", pm, "540*")),
    row2(250, "PVR (dyn)", paste("290", pm, "80"), paste("310", pm, "90")),
    list(w(60, 272, "Values are mean"), w(140, 272, paste(pm, "SD."))),
    list(w(60, 330, "TABLE II Variables after treatment and cessation of landiolol")),
    list(w(vy[1], 354, "Landiolol 1"), w(vy[2], 354, "Landiolol 10"), w(vy[3], 354, "Landiolol 100")),
    row3(390, "Weight (kg)", c(paste("12.1", pm, "1.4"), paste("11.8", pm, "1.6"), paste("12.4", pm, "1.2"))),
    row3(406, "Age (mo)", c(paste("14", pm, "3"), paste("15", pm, "4"), paste("14", pm, "3"))),
    list(w(60, 430, "Values are mean"), w(140, 430, paste(pm, "SD."))))
  makeTablePdf(file, cells)
}

test_that("a one-cohort pre/post table is refused and the document's baseline table is read instead", {
  r <- parseBaselineTableHeuristics(prePostPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_false(any(grepl("^HR|^SBP|^MBP|^CVP|^SVR|^PVR", r$data$ROW)))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Weight", cont$ROW)], c(12.1, 11.8, 12.4))
})
