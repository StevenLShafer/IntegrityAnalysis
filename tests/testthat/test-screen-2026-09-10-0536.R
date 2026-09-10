# Security screen 2026-09-10-0536, the merged range 1b7f626.
#
# Three of the four findings are incomplete fixes from the day before, and
# the F2 one is the sharpest lesson in the set: the test written with that
# fix stopped at the function it patched, so it could not see that the
# reported symptom still reproduced one call later.
#
# F1 (HIGH): the cell budget added by screen 1532 bounds ONE arm. The fill
#   builds an arm at a time and retains each, then computes prod(sizes) and
#   declines - so nothing charged the sum. 60 arm columns of a 91 KB JATS
#   document cost 1,636 MB, all of it to compute a number that is Inf.
# F2 (LOW): the Latin-1 fix sanitised a local copy; the frame kept the raw
#   bytes and .iaNormalizeNames() raised on them one call later. The value
#   path and the Shiny spelling were not covered at all.
# F3 (LOW): "the N at each extreme were scored" was given nScored, which
#   counts the UNION of both ends - so the sentence overstated how much of
#   the page was searched, by up to twice.
# F4 (LOW): the widened tripwire matched the loop HEADER line, so a braced
#   body walked past it.
#
# PROVENANCE: written by Claude Code (model Claude Opus 5), 2026-09-10.
# Every assertion was checked to FAIL on 1b7f626.
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

peak <- function(expr) {
  gc(reset = TRUE, full = TRUE)
  t <- system.time(force(expr))[["elapsed"]]
  list(t = t, mb = sum(gc(full = TRUE)[, 6]))
}

# --------------------------------------------------------------- F1 ----

# the screen's own construction: arms at exactly .iaMaxArmN, three integer
# percentage levels (each bracket 51 wide, so prod(width) = 132,651 sits
# inside .ppTableEnumMax) and 34 more levels pinned at two decimals, which
# have width 1 and are free under a product cap. Per arm that is 4,908,087
# cells - just inside the per-arm budget - so every arm passes on its own.
wideBlock <- function(arms, N = 5000) {
  pct  <- c(25, 42, 33)
  lo3  <- ceiling((pct - 0.5) / 100 * N); hi3 <- floor((pct + 0.5) / 100 * N)
  pin  <- rep(as.integer(0.01 * N), 34)          # 1.00% of N, pinned
  lo   <- matrix(rep(c(lo3, pin), each = arms), nrow = arms)
  hi   <- matrix(rep(c(hi3, pin), each = arms), nrow = arms)
  list(lo = lo, hi = hi,
       cnt = matrix(NA_integer_, arms, length(pct) + 34L),
       N = rep(N, arms))
}

test_that("the cell budget bounds the block, not each arm on its own", {
  d <- wideBlock(60)
  r <- peak(res <- .ppFailsafeTableFill(d$lo, d$hi, d$cnt, d$N,
                                        partition = FALSE))
  expect_false(isTRUE(res$resolved))
  # 1,636 MB and 9.4 s on 1b7f626, every byte of it to compute a product
  # that is Inf. The decline itself was always correct; its cost was not.
  expect_lt(r$t, 2)
})

test_that("a block that fits is still read, and the answer is unchanged", {
  br <- function(pct, N) list(lo = ceiling((pct - 0.5) / 100 * N),
                              hi = floor((pct + 0.5) / 100 * N))
  b <- br(c(25, 42, 33), 700)
  res <- .ppFailsafeTableFill(rbind(b$lo, b$lo), rbind(b$hi, b$hi),
                              matrix(NA_integer_, 2, 3), c(700, 700),
                              partition = FALSE)
  expect_true(isTRUE(res$resolved))
  expect_equal(res$nTables, 117649L)
  expect_equal(res$pBest, 0.1013, tolerance = 1e-3)
})

# --------------------------------------------------------------- F2 ----

latin1Csv <- function(header = "Größe", trial = "T") {
  p <- tempfile(fileext = ".csv")
  txt <- paste0("TRIAL,ROW,N,", header, ",MEAN,SD\n",
                trial, ",X,40,1,50.0,10.0\n",
                trial, ",X,40,1,51.0,10.0\n")
  con <- file(p, open = "wb")
  writeBin(iconv(txt, from = "UTF-8", to = "latin1", toRaw = TRUE)[[1]], con)
  close(con)
  p
}

test_that("a Latin-1 CSV survives the NEXT call, not just this one", {
  # THE POINT OF THIS TEST. The previous one stopped at
  # .iaReadCsvKeepingText() and passed while the symptom still reproduced,
  # because .iaNormalizeNames() folds the same bytes one call later.
  p <- latin1Csv()
  expect_error(d <- .iaReadCsvKeepingText(p, check.names = FALSE), NA)
  expect_error(n <- .iaNormalizeNames(d), NA)
  expect_true("MEAN" %in% names(n))
  expect_true(is.character(d[["MEAN"]]))
  unlink(p)
})

test_that("undecodable bytes in a VALUE cell are handled too", {
  # a trial named in Latin-1: the earlier fix did not touch the value path,
  # where trimws() folds every character column
  p <- latin1Csv(header = "EXTRA", trial = "Größe")
  expect_error(d <- .iaReadCsvKeepingText(p, check.names = FALSE), NA)
  expect_error(.iaNormalizeNames(d), NA)
  expect_equal(nrow(d), 2L)
  unlink(p)
})

test_that("the Shiny spelling is covered as well as the API's", {
  # app_server.R calls this WITHOUT check.names = FALSE, so read.csv's own
  # make.names() used to raise before any of our code ran
  p <- latin1Csv()
  expect_error(d <- .iaReadCsvKeepingText(p), NA)
  expect_equal(nrow(d), 2L)
  # and the default spelling still gives syntactic names, as read.csv would
  expect_identical(names(d), make.names(names(d), unique = TRUE))
  unlink(p)
})

test_that("an ordinary ASCII CSV is unchanged by all of this", {
  p <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD",
               "T,X,40,50.000,10.0",
               "T,X,40,51.000,10.0"), p)
  d <- .iaReadCsvKeepingText(p, check.names = FALSE)
  expect_true(is.character(d[["MEAN"]]))
  v <- shiny::isolate(validateData(d))
  expect_equal(v$DATA$ROUND_MEAN, c(3, 3))
  unlink(p)
})

# --------------------------------------------------------------- F3 ----

test_that("the hover sentence counts one extreme, which is what it says", {
  # nScored is the union of both ends - 51, 68, 81, even 100 where 50 are
  # scored at each - so using it made "the N at each extreme" overstate the
  # search by up to twice.
  br <- function(pct, N) list(lo = ceiling((pct - 0.5) / 100 * N),
                              hi = floor((pct + 0.5) / 100 * N))
  b <- br(c(25, 42, 33), 700)
  res <- .ppFailsafeTableFill(rbind(b$lo, b$lo), rbind(b$hi, b$hi),
                              matrix(NA_integer_, 2, 3), c(700, 700),
                              partition = FALSE)
  perEnd <- min(res$nNulls, .ppTableRankMax)
  expect_equal(perEnd, 50)
  expect_gt(res$nScored, perEnd)          # the union really is larger...
  expect_lte(res$nScored, 2L * .ppTableRankMax)
})
