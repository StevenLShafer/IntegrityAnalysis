# Security screen 2026-09-09-1532, the merged range ca8433c.
#
# The tenth screen in a row to find a real defect in the previous screen's
# fix, and this time in the fix itself: bounding the fail-safe search
# turned an O(search space) CPU burn into an O(arm N) ALLOCATION, and the
# retraction added the same day removed a warning by label wherever that
# label came from.
#
# F1 (HIGH): .ppArmVectorCount() allocated M + 1 doubles, M being about 1%
#   of the arm N, before the cap it exists to enforce - 1,074 MB and 1.3 s
#   for a header reading "(n = 2000000000)", to produce a number that was
#   then declined.
# F2 (HIGH): the non-partition branch builds prod(width) x L, and L - the
#   number of lines in the block - was bounded by nothing. 840 MB at 300
#   levels, all of it to say no.
# F3 (MEDIUM): the retraction was a setdiff on labels, and two blocks in
#   one table share labels as a matter of course (an ASA class and an NYHA
#   class both print I / II / III). One block declining cancelled the
#   other's fail-safe warning while its reconstructed counts were still
#   analysed.
# F4 (LOW): case-folding the raw CSV header bytes raised on a Latin-1
#   export, so the API refused an honest file with the wrong reason.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-09.
# Every assertion was checked to FAIL on ca8433c.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

br <- function(pct, N) list(lo = ceiling((pct - 0.5) / 100 * N),
                            hi = floor((pct + 0.5) / 100 * N))

peak <- function(expr) {
  gc(reset = TRUE, full = TRUE)
  t <- system.time(force(expr))[["elapsed"]]
  list(t = t, mb = sum(gc(full = TRUE)[, 6]))
}

# --------------------------------------------------------------- F1 ----

test_that("the count for two levels is a closed form, and it is the right one", {
  # Every partition block the parser builds has two levels - a binary
  # "n (%)" row whose complement this code constructs. The count is an
  # interval overlap and needs no convolution; it must agree exactly with
  # enumerating the vectors.
  set.seed(3)
  for (i in 1:150) {
    lo <- sample(0:20, 2, replace = TRUE)
    hi <- lo + sample(0:8, 2, replace = TRUE)
    N  <- sample(seq(sum(lo), sum(hi)), 1)
    v <- .ppArmVectors(as.integer(lo), as.integer(hi), N, TRUE, 1e9)
    expect_equal(.ppArmVectorCount(as.integer(lo), as.integer(hi), N, TRUE),
                 as.numeric(if (is.null(v)) 0 else nrow(v)))
  }
})

test_that("the convolution declares a ceiling instead of allocating past it", {
  # three levels with an enormous slack: over the ceiling the count says
  # "more than any cap" rather than reserving the coefficients to find out
  lo <- c(0L, 0L, 0L)
  hi <- as.integer(c(2e6, 2e6, 2e6))
  n <- .ppArmVectorCount(lo, hi, 3e6, TRUE)
  expect_false(is.finite(n))
  expect_null(.ppArmVectors(lo, hi, 3e6, TRUE, .ppTableEnumMax))
})

test_that("an arm above the analysis ceiling is refused before any work", {
  # 1,074 MB and 1.33 s on ca8433c; the row could never have been analysed
  # anyway, because validateData() rejects the trial above .iaMaxArmN.
  N <- 2e9
  b <- br(47, N)
  LO <- rbind(c(b$lo, N - b$hi), c(b$lo, N - b$hi))
  HI <- rbind(c(b$hi, N - b$lo), c(b$hi, N - b$lo))
  r <- peak(res <- .ppFailsafeTableFill(LO, HI, matrix(NA_integer_, 2, 2),
                                        c(N, N), partition = TRUE))
  expect_false(isTRUE(res$resolved))
  expect_match(res$reason, "above the .* the analysis accepts")
  expect_lt(r$t, 2)
  # and an arm the analysis DOES accept is still reconstructed
  N2 <- 5000; b2 <- br(47, N2)
  res2 <- .ppFailsafeTableFill(
    rbind(c(b2$lo, N2 - b2$hi), c(b2$lo, N2 - b2$hi)),
    rbind(c(b2$hi, N2 - b2$lo), c(b2$hi, N2 - b2$lo)),
    matrix(NA_integer_, 2, 2), c(N2, N2), partition = TRUE)
  expect_true(isTRUE(res2$resolved))
})

# --------------------------------------------------------------- F2 ----

test_that("levels are not free: the grid is bounded by cells, not by rows", {
  # one wide level and the rest pinned keeps prod(width) inside the
  # 200,000 cap while L runs away. 840 MB at 300 levels on ca8433c.
  wide <- function(L) list(lo = c(0L, rep(1L, L - 1L)),
                           hi = c(199999L, rep(1L, L - 1L)))
  for (L in c(60, 300)) {
    g <- wide(L)
    r <- peak(v <- .ppArmVectors(g$lo, g$hi, NA_real_, FALSE, .ppTableEnumMax))
    expect_null(v, info = paste(L, "levels"))
    expect_lt(r$t, 2)
  }
  # ...and a long block that FITS the budget is still built, because a
  # ten-level category on a few hundred patients is an ordinary table
  for (L in c(10, 25)) {
    g <- wide(L)
    v <- .ppArmVectors(g$lo, g$hi, NA_real_, FALSE, .ppTableEnumMax)
    expect_equal(nrow(v), 200000L, info = paste(L, "levels"))
  }
})

# --------------------------------------------------------------- F4 ----

test_that("a Latin-1 CSV header is read, not refused", {
  p <- tempfile(fileext = ".csv")
  con <- file(p, open = "wb")
  writeBin(iconv(paste0("TRIAL,ROW,N,Größe,MEAN,SD\n",
                        "T,X,40,1,50.0,10.0\n",
                        "T,X,40,1,51.0,10.0\n"),
                 from = "UTF-8", to = "latin1", toRaw = TRUE)[[1]], con)
  close(con)
  expect_error(d <- .iaReadCsvKeepingText(p, check.names = FALSE), NA)
  expect_equal(nrow(d), 2L)
  # the value columns still keep their digits
  expect_true(is.character(d[["MEAN"]]))
  unlink(p)
})

# ------------------------------------------------- F3, end to end ----

test_that("one declined block does not cancel another block's warning", {
  skip_if_not(file.exists(test_path("helper-syntheticJats.R")))
  # Two category blocks that share a level label. The first resolves and
  # its counts ARE reconstructed; the second reports only one arm, so it
  # declines. On ca8433c the decline removed the shared label from the
  # fail-safe list, and the first block's counts were analysed with no
  # warning at all - a false negative in the direction that favours the
  # author, triggered by content the author writes.
  jats <- function(rows) {
    f <- tempfile(fileext = ".xml")
    makeJatsArticle(f, list(list(caption = "Baseline characteristics",
                                 rows = rows)))
    suppressWarnings(parseBaselineTableJats(f, trial = "T", quiet = TRUE,
                                            pctApprox = TRUE))
  }
  base <- list(
    c("", "Control (n = 702)", "Treatment (n = 695)"),
    c("Age", "60", "61"),
    c("ASA class, %", "", ""),
    c("I", "47", "44"),
    c("II", "53", "56"))

  # the control: one block, reconstructed and flagged
  one <- jats(base)
  expect_setequal(one$approxCounts, c("I", "II"))
  expect_length(one$approxUnresolved, 0L)

  # now a second block sharing both level labels, reporting only one arm,
  # so it declines. On ca8433c approxCounts came back EMPTY while the
  # first block's counts (333/369 and 303/392) were still analysed.
  two <- jats(c(base, list(c("NYHA class, %", "", ""),
                           c("I", "31", ""),
                           c("II", "69", ""))))
  expect_setequal(two$approxCounts, c("I", "II"))       # the claim survives
  expect_true(length(two$approxUnresolved) > 0)         # and the decline is said
  expect_true("NYHA class, %" %in% names(two$approxUnresolved))
  # the surviving block really is still reconstructed, which is why the
  # warning has to survive with it
  asa <- two$data[two$data$ROW == "ASA class, %", , drop = FALSE]
  expect_equal(nrow(asa), 2L)
  expect_true(all(!is.na(asa$I)))
})
