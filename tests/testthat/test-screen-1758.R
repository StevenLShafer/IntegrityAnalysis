# Security screen 2026-09-07-1758, all four findings.
#
# F1 (HIGH): a precision column says what grid a printed number sits on,
# and the engine turns that grid into an interval. Nothing bounded the
# grid against the number, so one cell of a supplied spreadsheet
# (ROUND_DISPERSION = -5) multiplied the null's spread by 100,000 and
# drove an honest row to the reportable floor - a manufactured accusation.
# F2 (MEDIUM): the fail-safe enumeration cost 59 ms per row at twelve
# ambiguous arms, an arm count a hostile document chooses.
# F3 (MEDIUM): the refused table lines travelled unbounded in the reply
# and unbounded into the app's grid.
# F4 (LOW): a flag that is not valid UTF-8 raised, turning a 200 into 500.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-07.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

runRow <- function(D, m = 2000, seed = 11) {
  set.seed(seed); dqrng::dqset.seed(seed)
  r <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, m)))
  r[which(r$ROW == "X")[1], ]
}
medRow <- function(rd) data.frame(
  TRIAL = "T", ROW = "X", N = c(40, 40), MEAN = c(50, 52), SD = NA_real_,
  Q1 = c(45, 47), Q3 = c(55, 57), ROUND_MEAN = 0, ROUND_OBSERVATION = 0,
  ROUND_DISPERSION = rd, stringsAsFactors = FALSE)
sdRow <- function(rd) data.frame(
  TRIAL = "T", ROW = "X", N = c(40, 40), MEAN = c(50, 52), SD = c(10, 10),
  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, ROUND_DISPERSION = rd,
  stringsAsFactors = FALSE)

test_that("F1: a stated precision the printed values do not sit on is refused, in both branches", {
  # honest, and analyzed
  expect_false(grepl("stated precision", runRow(medRow(0))$P))
  expect_false(grepl("stated precision", runRow(sdRow(0))$P))
  # the lever the screen measured: at -5 the median row read p = 0.0049
  # and at -10 or below 9.999e-05, the floor of the reportable range
  for (rd in c(-1, -2, -3, -5, -10, -20))
    expect_match(runRow(medRow(rd))$P, "stated precision")
  # the SD row's 10 IS on a grid of ten, so that one is a reading of a
  # page and stays analyzed - and its p barely moves, which is what an
  # honest coarse precision should do (0.624 at 0, 0.629 at -1). Every
  # coarser claim, where 10 is not on the grid, is refused: the screen
  # measured 0.037 at -3 and the reportable floor at -20.
  expect_false(grepl("stated precision", runRow(sdRow(-1))$P))
  for (rd in c(-2, -3, -5, -10, -20))
    expect_match(runRow(sdRow(rd))$P, "stated precision")
})

test_that("F1: a coarse precision the values DO sit on is analyzed, not refused", {
  # quartiles honestly reported to the nearest ten: 40 and 60 are on a
  # grid of 10, so the row is a reading of a page and is simulated
  D <- data.frame(TRIAL = "T", ROW = "X", N = c(40, 40), MEAN = c(50, 50),
                  SD = NA_real_, Q1 = c(40, 40), Q3 = c(60, 60),
                  ROUND_MEAN = -1, ROUND_OBSERVATION = 0, ROUND_DISPERSION = -1,
                  stringsAsFactors = FALSE)
  row <- runRow(D)
  expect_false(grepl("stated precision", row$P))
  expect_true(is.finite(suppressWarnings(as.numeric(sub("^<", "", row$P)))))
  # and the case the quartile draw exists for - a variable whose spread is
  # smaller than one printed unit - is still analyzed
  narrow <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(5, 5.1),
                       SD = NA_real_, Q1 = c(5, 5), Q3 = c(5, 5),
                       ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 0,
                       stringsAsFactors = FALSE)
  expect_false(grepl("stated precision", runRow(narrow)$P))
})

test_that("F1: the grid test itself", {
  expect_true(.iaOnStatedGrid(c(45, 55), c(0, 0)))
  expect_true(.iaOnStatedGrid(c(40, 60), c(-1, -1)))     # on a grid of ten
  expect_false(.iaOnStatedGrid(c(45, 55), c(-1, -1)))    # not on a grid of ten
  expect_false(.iaOnStatedGrid(45, -20))                 # nor of 1e20
  expect_true(.iaOnStatedGrid(c(1e9 + 0.25), 2))         # screen 1459's shape
  expect_true(.iaOnStatedGrid(c(NA, NaN), c(0, NA)))     # nothing to judge
  expect_true(.iaOnStatedGrid(0, -20))                   # zero is on every grid
  # each column is judged against ITS OWN precision, never a finer one
  expect_false(.iaOnStatedGrid(c(45, 55), -1))
})

test_that("F2: the enumeration is bounded, and the ascent terminates", {
  expect_lte(.ppFailsafeExact, 8L)
  expect_true(is.numeric(.ppFailsafeSweeps) && .ppFailsafeSweeps >= 1)
  # a row of twelve ambiguous arms now takes the ascent, and still returns
  # an assignment at the ends of the brackets
  Ns <- rep(1000, 12)
  lo <- rep(495, 12); hi <- rep(505, 12); cnt <- rep(NA_real_, 12)
  t0 <- Sys.time()
  got <- .ppFailsafeCounts(lo, hi, cnt, Ns)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  expect_true(all(got %in% c(495, 505)))
  expect_lt(secs, 0.5)                      # 59 ms per row was the finding
  # and the ascent's answer is the exhaustive answer on this row: half low,
  # half high, which is the maximum for equal arms
  expect_equal(sum(got == 505), 6)
})

test_that("F3: the reply's list of unusable lines is bounded and scrubbed", {
  sk <- data.frame(label = paste("line", seq_len(500)),
                   reason = paste("reason", seq_len(500)),
                   stringsAsFactors = FALSE)
  out <- .apiSafeSkipped(sk, tempdir(), "u.pdf")
  expect_equal(length(out), .apiMaxSkipped + 1L)
  expect_match(out[[length(out)]]$label, "further line")
  expect_match(out[[length(out)]]$label, "300")
  # every entry up to the cap carries its own text: routing these through
  # .apiSafeFlags() would have spent that function's cap of 50 on them and
  # left entries 51 to 200 as NA (CodeRabbit on PR #219)
  expect_equal(out[[51]]$label, "line 51")
  expect_equal(out[[.apiMaxSkipped]]$label, paste("line", .apiMaxSkipped))
  expect_equal(out[[51]]$reason, "reason 51")
  expect_false(any(vapply(out, function(e) is.na(e$label), logical(1))))
  # a short list passes through whole
  short <- data.frame(label = "a line", reason = "a reason", stringsAsFactors = FALSE)
  expect_equal(length(.apiSafeSkipped(short, tempdir(), "u.pdf")), 1L)
  expect_equal(.apiSafeSkipped(NULL, tempdir(), "u.pdf"), list())
  # and the request's directory does not travel in a label
  work <- file.path(tempdir(), "apiWorkDir")
  leaky <- data.frame(label = paste0(work, "/upload.pdf"),
                      reason = "unreadable", stringsAsFactors = FALSE)
  expect_false(grepl(work, .apiSafeSkipped(leaky, work, "upload.pdf")[[1]]$label,
                     fixed = TRUE))
})

test_that("F4: a flag that is not valid UTF-8 is replaced, not raised on", {
  bad <- rawToChar(as.raw(c(0x41, 0xff, 0xfe, 0x42)))
  Encoding(bad) <- "UTF-8"
  out <- expect_silent(.apiSafeFlags(bad, tempdir(), "u.pdf"))
  expect_length(out, 1L)
  expect_match(out, "unreadable")
  # a valid neighbour in the same vector is untouched
  out2 <- .apiSafeFlags(c(bad, "an ordinary flag"), tempdir(), "u.pdf")
  expect_equal(out2[2], "an ordinary flag")
})

# the app half of F3 is pinned by test-screen-1907.R, which calls the
# capping function on a real three-column skipped frame. What stood here
# asserted only that the constant existed, and the code it claimed to pin
# raised on its first real input (screen 2026-09-07-1907, A1).
