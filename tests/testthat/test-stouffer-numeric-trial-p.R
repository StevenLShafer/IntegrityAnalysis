# test-stouffer-numeric-trial-p.R - the P across trials is combined from
# the numeric trial p, not from its display (ISSUES.md issue 78,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) to Steve       #
# Shafer's direction of 2026-09-25 ("use the actual number, not the        #
# displayed number, for the P across trials"). The Summary line's P is a  #
# display - four figures, or "<0.0001" when the Monte Carlo bound licenses #
# it - and both Stouffer combinations (the workbook's Summary sheet, the   #
# API's overallP) read that display back through .trialPNumeric(), so a   #
# trial at 0.000003 entered as 0.0001: conservative, and most so for the  #
# trials a fraud screen cares about.                                       #
############################################################################

resultsFrame <- function(withNum = TRUE) {
  r <- data.frame(TRIAL = c("A", NA, "B", NA), ROW = c("Age", "Summary", "Age", "Summary"),
                  P = c("0.3", "<0.0001", "0.4", "0.5"), CI95 = "", M = NA_real_, NOTE = "",
                  KIND = c("variable", "summary", "variable", "summary"),
                  stringsAsFactors = FALSE)
  if (withNum) r$.PNUM <- c(0.3, 1e-6, 0.4, 0.5)
  r
}

test_that(".iaOverallP() combines the numbers, and falls back on the display without them", {
  ov <- .iaOverallP(resultsFrame())
  expect_identical(ov$p, c(1e-6, 0.5))
  expect_identical(ov$ok, c(TRUE, TRUE))
  expect_equal(ov$overall, sumz(c(1e-6, 0.5))$p)
  old <- .iaOverallP(resultsFrame(withNum = FALSE))
  expect_identical(old$p, c(1e-4, 0.5))
  expect_equal(old$overall, sumz(c(1e-4, 0.5))$p)
  expect_true(ov$overall < old$overall)     # the display had made the study p larger
  # a summary with a numeric p of NA (a hand-typed P) still combines from the display
  mixed <- resultsFrame(); mixed$.PNUM[2] <- NA_real_
  expect_identical(.iaOverallP(mixed)$p, c(1e-4, 0.5))
  # one trial: nothing to combine
  expect_true(is.na(.iaOverallP(resultsFrame()[1:2, ])$overall))
})

test_that("the API's CSV and the workbook's Test Results sheet do not carry the internal column", {
  hdr <- strsplit(.apiResultsCsv(resultsFrame()), "\n")[[1]][1]
  expect_false(grepl("PNUM", hdr, fixed = TRUE))
  expect_true(grepl("KIND", hdr, fixed = TRUE))
})

test_that("P_Calc's Summary line carries the numeric trial p, at or below its display", {
  mk <- function(lab) data.frame(TRIAL = "T", ROW = lab, N = 6, MEAN = c(77, 78), SD = c(30, 30),
                                 ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  quiet <- function(expr) { utils::capture.output(r <- suppressMessages(expr)); r }
  dqrng::dqset.seed(1); set.seed(1)
  x <- quiet(suppressWarnings(shiny::isolate(P_Calc("T", rbind(mk("Age"), mk("Weight")), NULL, 1000))))
  s <- x[!is.na(x$KIND) & x$KIND == "summary", ]
  expect_identical(nrow(s), 1L)
  expect_true(is.numeric(s$.PNUM) && !is.na(s$.PNUM))
  shown <- .trialPNumeric(s$P)
  expect_true(s$.PNUM <= shown * 1.0005 + 1e-12)     # the display is rounded or floored, never smaller
})
