# Security screen 2026-09-07-2101, which screened the fix for screen 2000.
#
# F1 (HIGH): the dispersion bound used the weakest form of the theorem -
# alpha replaced by its minimum feasible value 1/sqrt(N) - leaving a factor
# of sqrt(N)/2 of headroom exactly at the attacker's operating point, a
# printed mean near a half-grid point. Honest three-arm tables of 1,000
# read 0.414 and 0.00235, or the reportable floor, at ROUND_OBSERVATION -3.
# F2 (HIGH): the fine-precision Note only fired more than two decimals past
# the printed digits, and the row was already at the floor at two.
# F3 (MEDIUM): the "linear" skip-registry loop was still quadratic - a list
# name lookup is a linear search, and the payload grew one insert at a time.
# F4 (LOW-MEDIUM): the wide-sheet cap was applied per trial BLOCK, and a
# sheet may hold thousands of blocks.
# F5 (MEDIUM): the bound refused ordinarily printed honest rows, because a
# blank ROUND_OBSERVATION defaults to ROUND_MEAN - a guess - and a refused
# row left the trial silently.
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
arms <- function(means, N, sd, rm, ro)
  data.frame(TRIAL = "T", ROW = "X", N = rep(N, length(means)), MEAN = means,
             SD = rep(sd, length(means)), ROUND_MEAN = rm, ROUND_OBSERVATION = ro,
             ROUND_DISPERSION = 0, stringsAsFactors = FALSE)

test_that("F1: the sharp bound refuses what the weak one let through", {
  # every row here is arithmetically impossible at ROUND_OBSERVATION -3: a
  # mean of 500 on a grid of 1,000 forces SD >= 500, and the previous
  # bound asked only for 1000/sqrt(1000) = 31.6
  expect_false(grepl("stated precision", runRow(arms(c(500, 501, 499), 1000, 40, 0, 0))$P))
  for (D in list(arms(c(500, 501, 499), 1000, 40, 0, -3),
                 arms(c(500, 500, 500), 1000, 40, 0, -3),
                 arms(c(500, 500, 500), 1000, 100, 0, -3),
                 arms(c(500, 501), 1000, 40, 0, -3),
                 arms(c(500, 500, 500), 1000, 1, 0, -3)))
    expect_match(runRow(D)$P, "stated precision")
})

test_that("F1: alpha is the mean's own lattice offset, over its printed interval", {
  # mean 500 printed to no decimals, observation grid 1000: the interval
  # [499.5, 500.5] holds no multiple of 1000, and its nearest offset is
  # 0.4995 - so the bound is 499.5, not 31.6
  expect_false(.iaSdReachesGrid(40, 0, -3, 0, 1000, 500))
  expect_false(.iaSdReachesGrid(100, 0, -3, 0, 1000, 500))
  # a mean ON the grid: alpha is zero and only the 1/sqrt(N) floor remains
  expect_true(.iaSdReachesGrid(40, 0, -3, 0, 1000, 1000))
  # ...and where the printed interval spans a grid point, nothing is refused
  expect_true(.iaSdReachesGrid(40, 0, -3, -3, 1000, 500))
})

test_that("F5: the bound applies only where a COARSER observation grid is stated", {
  # A blank ROUND_OBSERVATION defaults to ROUND_MEAN, which is a guess -
  # "a mean printed to d decimals means the observations lie on a grid of
  # 10^-d" - false for any continuous variable whose mean prints without
  # decimals. These honest rows, with no precision columns supplied at
  # all, were refused by the previous version.
  D <- data.frame(TRIAL = "T", ROW = "X", N = c(8, 8), MEAN = c(2, 2.1),
                  SD = c(0.2, 0.2), stringsAsFactors = FALSE)
  expect_false(grepl("stated precision", runRow(D)$P))
  D2 <- data.frame(TRIAL = "T", ROW = "X", N = c(50, 50), MEAN = c(7, 7),
                   SD = c(0.1, 0.12), stringsAsFactors = FALSE)
  expect_false(grepl("stated precision", runRow(D2)$P))
  # the helper: equal grids exempt, a coarser stated grid judged
  expect_true(.iaSdReachesGrid(0.2, 1, 0, 0, 8, 2))     # hObs == hVal
  expect_false(.iaSdReachesGrid(0.2, 1, -1, 0, 8, 2))   # a stated coarser grid
})

test_that("F5: a trial whose rows were refused says so on the Summary line", {
  D <- rbind(
    data.frame(TRIAL = "T", ROW = "A", N = c(50, 50), MEAN = c(10, 10.1), SD = c(3, 3),
               ROUND_MEAN = 1, ROUND_OBSERVATION = -3, ROUND_DISPERSION = 0,
               stringsAsFactors = FALSE),
    data.frame(TRIAL = "T", ROW = "B", N = c(50, 50), MEAN = c(20, 20.2), SD = c(5, 5),
               ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 0,
               stringsAsFactors = FALSE),
    data.frame(TRIAL = "T", ROW = "C", N = c(50, 50), MEAN = c(30, 30.4), SD = c(6, 6),
               ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 0,
               stringsAsFactors = FALSE))
  set.seed(2); dqrng::dqset.seed(2)
  x <- suppressWarnings(shiny::isolate(P_Calc("T", D, NULL, 1000)))
  s <- x[which(x$KIND == "summary")[1], ]
  expect_match(s$NOTE, "2 of 3 rows analysed")
  # a complete trial says nothing
  D2 <- D; D2$ROUND_OBSERVATION <- 1
  set.seed(2); dqrng::dqset.seed(2)
  x2 <- suppressWarnings(shiny::isolate(P_Calc("T", D2, NULL, 1000)))
  expect_identical(x2$NOTE[which(x2$KIND == "summary")[1]], "")
})

test_that("F2: the Note fires at one decimal past the printed digits, where the alarm starts", {
  note <- function(rm) runRow(data.frame(
    TRIAL = "T", ROW = "X", N = rep(30, 3), MEAN = rep(0.5, 3), SD = rep(0.1, 3),
    ROUND_MEAN = rm, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 1,
    stringsAsFactors = FALSE))$NOTE
  expect_false(grepl("stated mean precision", note(1)))   # honest
  expect_match(note(2), "stated mean precision")          # was silent, and already alarming
  expect_match(note(3), "stated mean precision")
  expect_match(note(15), "stated mean precision")
  # ...and it says what it can see, not more: a spreadsheet stores "5.0"
  # as 5, so a precision past the surviving digits may be honest
  expect_match(note(3), "exceeds the digits these values carry")
  expect_match(note(3), "check it against the page")
})

test_that("I6: a median row's notes carry no dangling separator", {
  D <- data.frame(TRIAL = "T", ROW = "X", N = c(30, 30), MEAN = c(5, 5.1),
                  SD = NA_real_, Q1 = c(5, 5), Q3 = c(5, 6),
                  ROUND_MEAN = 1, ROUND_OBSERVATION = 1, ROUND_DISPERSION = 0,
                  stringsAsFactors = FALSE)
  n <- runRow(D)$NOTE
  expect_match(n, "printed quartiles do not separate")
  expect_false(grepl(";\\s*$", n))
  expect_false(grepl(";\\s*;", n))
})

test_that("F3: the skip payload is linear, not quadratic", {
  mk <- function(n) {
    d <- data.frame(TRIAL = rep("T", n), ROW = paste0("R", seq_len(n)),
                    N = NA_real_, MEAN = NA_real_, SD = NA_real_,
                    stringsAsFactors = FALSE)
    sk <- data.frame(TRIAL = rep("T", n), ROW = paste0("R", seq_len(n)),
                     reason = "unreadable", stringsAsFactors = FALSE)
    list(d = d, sk = sk)
  }
  cols <- c("N", "MEAN", "SD")
  small <- mk(2000); big <- mk(16000)
  t1 <- system.time(p1 <- .iaSkipPayload(small$d, small$sk, cols, 2L))[["elapsed"]]
  t2 <- system.time(p2 <- .iaSkipPayload(big$d, big$sk, cols, 2L))[["elapsed"]]
  expect_equal(length(p1$iss), 2000L)
  expect_equal(length(p2$iss), 16000L)
  expect_match(p2$note[[1]], "could not use it")
  # eight times the work must not cost anything like sixty-four times the
  # time; the quadratic versions took 0.09 s at 2,000 and 28.8 s at 40,000
  skip_on_cran()
  expect_lt(t2, 3)
  expect_lt(t2, max(0.5, t1 * 24))
})

test_that("F3: the payload marks only rows still without data, last entry winning", {
  d <- data.frame(TRIAL = "T", ROW = c("A", "B", "C"),
                  N = c(NA, 10, NA), MEAN = NA_real_, SD = NA_real_,
                  stringsAsFactors = FALSE)
  sk <- data.frame(TRIAL = "T", ROW = c("A", "C", "C"),
                   reason = c("first", "older", "newer"), stringsAsFactors = FALSE)
  pay <- .iaSkipPayload(d, sk, c("N", "MEAN", "SD"), 2L)
  expect_equal(sort(names(pay$iss)), sort(c("0|1", "2|1")))   # B has data: untouched
  expect_match(pay$note[["2|1"]], "newer")
})

test_that("F4: a file's unusable lines are capped across ALL its blocks", {
  blk <- function(n) data.frame(label = paste("l", seq_len(n)),
                                reason = "r", text = "t", stringsAsFactors = FALSE)
  blocks <- replicate(3300, blk(1), simplify = FALSE)
  out <- .iaCapSkippedFile(blocks)
  total <- sum(vapply(out, nrow, integer(1)))
  expect_lte(total, .iaMaxSkippedRows + 1L)
  expect_gt(total, 0)
  # a small file is untouched
  small <- list(blk(3), blk(4))
  expect_identical(.iaCapSkippedFile(small), small)
})
