# test-long-layout-letter-groups.R - the repeated-measures layout with
# LETTER group labels under the Group column, a "Pre-<word>" baseline
# column, and arm names from the footnote legend (ISSUES.md issue 76,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 17 finding W1 (Fujii 1994, Can J Anaesth, PMID    #
# 8055614; Table I "Variable | Group | Pre-fatigue | Fatigue", groups C and #
# N of 10, the legend "C = control, N = nicardipine" in the footnote).      #
# The reader of issue 34 wanted integer indices and a "Baseline" column,   #
# so the layout fell to the wide reader, which took the two timepoints    #
# for two arms and the group rows for separate variables.                 #
############################################################################

letterLongPdf <- function(file = file.path(tempdir(), "letterLong.pdf")) {
  vx <- c(230, 330, 450)   # Group, Pre-fatigue, Fatigue
  row <- function(y, label, g, pre, fat) c(
    if (nzchar(label)) list(list(x = 60, y = y, text = label, adj = 0)) else list(),
    list(list(x = vx[1], y = y, text = g, adj = 0.5),
         list(x = vx[2], y = y, text = pre, adj = 0.5),
         list(x = vx[3], y = y, text = fat, adj = 0.5)))
  cells <- c(
    list(list(x = 60, y = 60, text = "Patients were allocated to a control group (Group C, n = 10) or a nicardipine group (Group N, n = 10).", adj = 0)),
    list(list(x = 60, y = 90, text = "TABLE I Haemodynamic data and changes", adj = 0)),
    list(list(x = 60, y = 108, text = "Variable", adj = 0),
         list(x = vx[1], y = 108, text = "Group", adj = 0.5),
         list(x = vx[2], y = 108, text = "Pre-fatigue", adj = 0.5),
         list(x = vx[3], y = 108, text = "Fatigue", adj = 0.5)),
    row(126, "HR", "C", "146 ± 9", "145 ± 11"),
    row(138, "(bpm)", "N", "142 ± 10", "147 ± 10"),
    row(156, "MAP", "C", "121 ± 14", "122 ± 17"),
    row(168, "(mmHg)", "N", "121 ± 14", "86 ± 15"),
    row(186, "RAP", "C", "5 ± 2", "5 ± 2"),
    row(198, "(mmHg)", "N", "5 ± 2", "5 ± 1"),
    row(216, "PCWP", "C", "8 ± 2", "8 ± 2"),
    row(228, "(mmHg)", "N", "9 ± 2", "8 ± 2"),
    list(list(x = 60, y = 250, text = "All values are expressed as mean ± SD. HR = heart rate, MAP = mean arterial", adj = 0),
         list(x = 60, y = 262, text = "pressure, RAP = right atrial pressure, C = control, N = nicardipine.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("letter groups under Group with a Pre-fatigue column read as the arms, named by the legend", {
  r <- parseBaselineTableHeuristics(letterLongPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$arm, c("control (Group C)", "nicardipine (Group N)"))
  expect_identical(r$arms$N, c(10L, 10L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_setequal(unique(cont$ROW), c("HR", "MAP", "RAP", "PCWP"))
  expect_identical(cont$MEAN[cont$ROW == "HR"], c(146, 142))     # the Pre-fatigue column only
  expect_identical(cont$SD[cont$ROW == "MAP"], c(14, 14))
  expect_identical(cont$MEAN[cont$ROW == "PCWP"], c(8, 9))
  expect_false(any(grepl("bpm|mmHg", r$data$ROW)))                # the unit line is not a variable
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
