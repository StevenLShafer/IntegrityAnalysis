# Security screens 2026-09-08-2100 and 2026-09-09-0721.
#
# 2100 F1 / 0721 F1 (HIGH): the fail-safe table search had no bound on
#   its dominant cost. Two halves are tested here - the enumeration,
#   which decided a block was too large by building it, and the exact
#   count that now decides it beforehand.
# 2100 F5 (LOW): the reported best and worst p ranged over all groups
#   after only six had been re-run at the larger budget, so both were
#   taken across a mixture of estimates whose FLOORS differ tenfold.
# 2100 F6 / 0721 F4: decShown() took the larger of two decimal counts and
#   .ppDecimals() has no cap, so a text cell carried 401 decimals past the
#   |precision| <= 20 clamp that .iaDecimals() caps itself for.
# 0721 F3 (MEDIUM): the CSV value columns were held as text by a
#   case-SENSITIVE name test, while the alias normaliser upper-cases the
#   headers afterwards - so "Mean" lost its digits and "MEAN" did not.
# 0721 F5 (LOW): the same loop indexed by name, and a blank header is the
#   name "" under check.names = FALSE, which errored.
# 0721 F6 (LOW): the UNRESOLVED hover note hard-coded one reason.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-09,
# with the fixes in R/failsafeTable.R, R/validateData.R, R/app_globals.R
# and R/parseBaselineTableHeuristics.R. Every assertion below was checked
# to FAIL on 65e2a04, the code the screens read.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny)
}))

vd <- function(d) shiny::isolate(validateData(d))

# ---------------------------------------------------------- 2100 F1 ----

# An independent enumerator, deliberately not the package's: the count
# under test must be checked against something that does not share its
# arithmetic (the discipline test-failsafe-table.R sets out).
naiveCount <- function(lo, hi, N, partition) {
  g <- expand.grid(lapply(seq_along(lo), function(j) lo[j]:hi[j]))
  if (!partition) return(nrow(g))
  sum(rowSums(g) == N)
}

test_that("the vector count is exact, and agrees with enumerating them", {
  set.seed(4)
  for (i in 1:120) {
    L  <- sample(2:4, 1)
    lo <- sample(0:6, L, replace = TRUE)
    hi <- lo + sample(0:4, L, replace = TRUE)
    for (partition in c(FALSE, TRUE)) {
      N <- if (partition) sample(seq(sum(lo), sum(hi)), 1) else NA_real_
      want <- naiveCount(lo, hi, N, partition)
      expect_equal(.ppArmVectorCount(as.integer(lo), as.integer(hi), N, partition),
                   as.numeric(want))
      v <- .ppArmVectors(as.integer(lo), as.integer(hi), N, partition, 1e9)
      expect_equal(if (is.null(v)) 0 else nrow(v), want)
    }
  }
})

test_that("a block past the bound declines without enumerating it", {
  # three levels printed 33/33/34 of an arm of 500,000. On the code the
  # screen read this returned NULL after 153 s, having built 200,001
  # vectors to find out that there were too many.
  lo <- as.integer(ceiling((c(33, 33, 34) - 0.5) / 100 * 500000))
  hi <- as.integer(floor((c(33, 33, 34) + 0.5) / 100 * 500000))
  t <- system.time(
    v <- .ppArmVectors(lo, hi, 500000, TRUE, .ppTableEnumMax))[["elapsed"]]
  expect_null(v)
  # a generous budget: the point is that the cost is no longer
  # proportional to the search space. Measured at well under 0.05 s; 5 s
  # still fails the code this replaces by two orders of magnitude.
  expect_lt(t, 5)
})

test_that("a block inside the bound is enumerated completely, and quickly", {
  # 188,251 vectors - inside the cap, so this block is ANALYSED, not
  # declined. It took 19.9 s to build before this change and 0.6 s after,
  # the same vectors: the innermost loop was searching for a value the
  # constraint already determines, and testing it with all.equal().
  lo <- as.integer(ceiling((c(33, 33, 34) - 0.5) / 100 * 50000))
  hi <- as.integer(floor((c(33, 33, 34) + 0.5) / 100 * 50000))
  n <- .ppArmVectorCount(lo, hi, 50000, TRUE)
  t <- system.time(v <- .ppArmVectors(lo, hi, 50000, TRUE, .ppTableEnumMax))[["elapsed"]]
  expect_equal(nrow(v), as.integer(n))
  expect_equal(nrow(v), 188251L)
  expect_true(all(rowSums(v) == 50000))          # every one meets the constraint
  expect_equal(anyDuplicated(v), 0L)             # and none is repeated
  expect_lt(t, 8)
})

# ---------------------------------------------------------- 2100 F5 ----

test_that("a worst case on the floor is the REFINED floor, and says so", {
  N  <- c(200, 200)
  lo <- rbind(c(95L, 95L), c(95L, 95L))
  hi <- rbind(c(105L, 105L), c(105L, 105L))
  cnt <- matrix(NA_integer_, 2, 2)
  res <- .ppFailsafeTableFill(lo, hi, cnt, N, partition = TRUE)
  skip_if_not(isTRUE(res$resolved))
  if (isTRUE(res$worstAtFloor)) {
    # THE differential assertion: the floor reported is the refine
    # budget's, 1/20001. The code the screen read minimised over
    # unrefined estimates too, whose floor is 1/2001 - a tenfold
    # different number, shown to an editor as an estimate.
    expect_equal(res$pWorst, 1 / (.ppTableRefineReps + 1))
    expect_false(isTRUE(all.equal(res$pWorst, 1 / (.ppTableSelectReps + 1))))
  }
  # and whatever it is, it is never below the refined floor
  expect_gte(res$pWorst, 1 / (.ppTableRefineReps + 1))
  expect_gte(res$pBest, res$pWorst)
})

# ------------------------------------------------- 2100 F6 / 0721 F4 ----

test_that("a text cell cannot carry a precision past the clamp", {
  # 401 decimals in one cell. Before the cap, ROUND_MEAN became 401,
  # 10^-401 underflowed to exactly 0, .iaOnStatedGrid() computed x/0, and
  # P_Calc failed on "missing value where TRUE/FALSE needed" - the whole
  # trial dropped with an internal error instead of a named refusal.
  wide <- paste0("0.", paste(rep("0", 400), collapse = ""), "1")
  d <- data.frame(TRIAL = "T", ROW = "X", N = c(10, 10),
                  MEAN = c(wide, "2"), SD = c("1", "1"),
                  stringsAsFactors = FALSE)
  v <- vd(d)
  expect_true(all(abs(v$DATA$ROUND_MEAN) <= 20))
  expect_true(all(is.finite(10^(-v$DATA$ROUND_MEAN))))
  expect_true(all(10^(-v$DATA$ROUND_MEAN) > 0))
})

# ---------------------------------------------------------- 0721 F3 ----

test_that("the CSV keeps its digits whatever case the header is written in", {
  for (hdr in c("MEAN", "Mean", "mean", " Mean ")) {
    p <- tempfile(fileext = ".csv")
    writeLines(c(paste0("TRIAL,ROW,N,", hdr, ",SD"),
                 "T,X,40,50.000,10.0",
                 "T,X,40,51.000,10.0"), p)
    d <- .iaReadCsvKeepingText(p)
    nm <- toupper(trimws(names(d)))
    expect_true(is.character(d[[which(nm == "MEAN")]]),
                info = paste("header", hdr))
    v <- vd(d)
    expect_equal(v$DATA$ROUND_MEAN, c(3, 3), info = paste("header", hdr))
    unlink(p)
  }
})

# ---------------------------------------------------------- 0721 F5 ----

test_that("a CSV with a blank column header is read, not refused", {
  p <- tempfile(fileext = ".csv")
  # the unnamed index column a spreadsheet export leaves in front
  writeLines(c(",TRIAL,ROW,N,MEAN,SD",
               "1,T,X,40,50.0,10.0",
               "2,T,X,40,51.0,10.0"), p)
  # check.names = FALSE is the API route's spelling, which is where it
  # errored: d[[""]] is NULL, so the assignment had zero rows.
  expect_error(d <- .iaReadCsvKeepingText(p, check.names = FALSE), NA)
  expect_equal(nrow(d), 2L)
  expect_true(is.character(d[["MEAN"]]))
  unlink(p)
})

# ---------------------------------------------------------- 0721 F6 ----

test_that("the unresolved note gives the reason that actually applied", {
  # "a cell has no bracket" - not an enumeration overflow. The note used
  # to assert the overflow and then contradict itself with the truth.
  N  <- c(200, 200)
  lo <- rbind(c(95L, NA_integer_), c(95L, 95L))
  hi <- rbind(c(105L, NA_integer_), c(105L, 105L))
  cnt <- matrix(NA_integer_, 2, 2)
  res <- .ppFailsafeTableFill(lo, hi, cnt, N, partition = TRUE)
  expect_false(isTRUE(res$resolved))
  expect_false(grepl("more readings than can be enumerated", res$reason,
                     fixed = TRUE))
})

# ------------------------------------------- 2100 F1 / 0721 F1, selection ----

# the block that made an ordinary manuscript unparseable: two arms of 700
# and a three-level category printed as percentages
adversarial <- function(Ns = c(700, 700), pct = c(25, 42, 33)) {
  lo <- t(vapply(Ns, function(N) ceiling((pct - 0.5) / 100 * N),
                 numeric(length(pct))))
  hi <- t(vapply(Ns, function(N) floor((pct + 0.5) / 100 * N),
                 numeric(length(pct))))
  list(lo = lo, hi = hi,
       cnt = matrix(NA_integer_, length(Ns), length(pct)), N = Ns)
}

test_that("the statistic computed in whole columns is the engine's own", {
  # the rearrangement n * (sum T^2/(r c) - 1) is exact, so it must agree
  # with .ppTableStat() - the single definition - candidate by candidate,
  # including the degenerate tables .ppTableStat() refuses.
  set.seed(11)
  d <- adversarial(c(60, 60), c(20, 30, 50))
  res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N, partition = FALSE)
  expect_true(isTRUE(res$resolved))
  # the chosen table is scored by the engine's own statistic and is a
  # genuine reading of the page: every cell inside its printed bracket
  expect_true(is.finite(.ppTableStat(res$counts)))
  for (j in seq_len(nrow(res$counts)))
    expect_true(all(res$counts[j, ] >= d$lo[j, ] & res$counts[j, ] <= d$hi[j, ]))
})

test_that("an ordinary percentage block is analysed inside the parse budget", {
  # MEASURED on 65e2a04, the code the screens read: 117,649 readings,
  # 20,449 distinct nulls, 233.5 s in the selection alone and 190 s for
  # the whole parse - past the 60 s subprocess timeout, so the manuscript
  # failed to parse at all. Here: about 1.6 s.
  d <- adversarial()
  t <- system.time(
    res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N,
                                partition = FALSE))[["elapsed"]]
  expect_true(isTRUE(res$resolved))
  # every reading is still enumerated - that half is exact
  expect_equal(res$nTables, 117649L)
  expect_gt(res$nNulls, 20000L)
  # but only the extremes are scored, and that is what bounds the cost
  expect_lte(res$nScored, 2L * .ppTableRankMax)
  # a budget with room for a slow machine; the code this replaces needs
  # two orders of magnitude more than this
  expect_lt(t, 20)
})

test_that("the cost does not grow with the number of distinct nulls", {
  # the property the bound exists for: nNulls moves by an order of
  # magnitude and the work does not follow it
  small <- adversarial(c(300, 300), c(20, 30, 50))
  big   <- adversarial(c(700, 700), c(25, 42, 33))
  ts <- system.time(rs <- .ppFailsafeTableFill(small$lo, small$hi, small$cnt,
                                               small$N, partition = FALSE))[["elapsed"]]
  tb <- system.time(rb <- .ppFailsafeTableFill(big$lo, big$hi, big$cnt,
                                               big$N, partition = FALSE))[["elapsed"]]
  expect_gt(rb$nNulls / rs$nNulls, 10)          # the search space grows
  expect_lte(rs$nScored, 2L * .ppTableRankMax)  # the simulation does not
  expect_lte(rb$nScored, 2L * .ppTableRankMax)
  # and the time follows the enumeration, not the null count
  expect_lt(tb, 20)
})
