# Barnett's dispersion test (R/dispersionTest.R).
#
# The interesting assertions here are not "does it run" but "is it the
# same posterior the reference sampler draws from". Three independent
# yardsticks, in increasing order of authority:
#   1. a second quadrature on a 16x finer grid  - rules out grid error
#   2. stats::integrate() over the model written out afresh, from the
#      BUGS code rather than from the functions under test - rules out an
#      error in the quadrature machinery
#   3. nimble running Barnett's own model file, when nimble is installed
#      - rules out an error in our reading of his model
# Only (3) can catch a misunderstanding of the method, and only (3) needs
# a package we deliberately do not depend on, so it skips when absent.

# The model, written out again from bugs_model.txt rather than from
# R/dispersionTest.R, so that a mistake in one does not excuse the other.
refPosterior <- function(t, df, prior = 0.5, slabVar = 10) {
  ll <- function(e) sum(stats::dt(t * exp(e / 2), df = df, log = TRUE)) +
                    length(t) * e / 2
  f  <- function(e) vapply(e, function(x)
    exp(ll(x) - ll(0)) * stats::dnorm(x, 0, sqrt(slabVar)), numeric(1))
  m1 <- stats::integrate(f, -80, 80, subdivisions = 4000L,
                         rel.tol = 1e-12)$value
  list(p = prior * m1 / (prior * m1 + (1 - prior)),
       eps = stats::integrate(function(e) e * f(e), -80, 80,
                              subdivisions = 4000L, rel.tol = 1e-12)$value / m1)
}

test_that("the quadrature has converged: 513 points equals 8,193", {
  set.seed(4)
  for (scale in c(0.2, 0.6, 1, 2, 6)) {
    d <- data.frame(t = stats::rt(14, 99) * scale, df = 99)
    a <- barnettDispersion(d)
    b <- barnettDispersion(d, points = 8193L)
    expect_equal(a$pDispersed, b$pDispersed, tolerance = 1e-9)
    expect_equal(a$epsilon,    b$epsilon,    tolerance = 1e-9)
  }
})

test_that("it matches an independent integration of the same model", {
  set.seed(11)
  for (scale in c(0.25, 0.5, 1, 1, 3, 8)) {
    d <- data.frame(t = stats::rt(10, 199) * scale, df = 199)
    a <- barnettDispersion(d)
    r <- refPosterior(d$t, d$df)
    expect_equal(a$pDispersed, r$p,   tolerance = 1e-8)
    expect_equal(a$epsilon,    r$eps, tolerance = 1e-8)
  }
})

test_that("epsilon recovers a known dispersion multiplier", {
  # Scaling every t by s multiplies the variance by s^2, so the
  # precision multiplier gamma is 1 / s^2 and epsilon is -2 log(s).
  # Averaged over replicates the estimator should land there.
  set.seed(99)
  for (s in c(0.5, 0.8, 1.5, 2)) {
    e <- vapply(1:150, function(i)
      barnettDispersion(data.frame(t = stats::rt(40, 199) * s,
                                   df = 199))$epsilon, numeric(1))
    expect_equal(mean(e), -2 * log(s), tolerance = 0.15)
  }
})

test_that("honest tables are almost never flagged, tight ones are", {
  set.seed(2026)
  honest <- vapply(1:300, function(i)
    barnettDispersion(data.frame(t = stats::rt(20, 199),
                                 df = 199))$pDispersed, numeric(1))
  tight <- vapply(1:100, function(i)
    barnettDispersion(data.frame(t = stats::rt(20, 199) * 0.4,
                                 df = 199))$pDispersed, numeric(1))
  expect_lt(mean(honest > 0.95), 0.03)
  expect_gt(mean(tight  > 0.95), 0.80)
})

test_that("direction is reported the right way round", {
  set.seed(5)
  under <- barnettDispersion(data.frame(t = stats::rt(30, 199) * 0.3, df = 199))
  over  <- barnettDispersion(data.frame(t = stats::rt(30, 199) * 3,   df = 199))
  expect_identical(under$direction, "under-dispersed")
  expect_gt(under$epsilon, 0)
  expect_gt(under$gamma, 1)          # precision multiplied UP
  expect_identical(over$direction, "over-dispersed")
  expect_lt(over$epsilon, 0)
  expect_lt(over$gamma, 1)
})

test_that("numerically identical arms are found, not lost off the grid", {
  # Every t is zero, so the log likelihood rises linearly in epsilon and
  # the mode sits at n * slabVar / 2 - far outside any fixed search
  # window. This is the strongest under-dispersion the model can see and
  # the mode search must be able to reach it.
  r <- barnettDispersion(data.frame(t = rep(0, 12), df = 199))
  expect_equal(r$pDispersed, 1, tolerance = 1e-9)
  expect_equal(r$epsilon, 12 * 10 / 2, tolerance = 1e-6)
  expect_identical(r$direction, "under-dispersed")
})

test_that("too few statistics is a refusal, not a number", {
  expect_equal(barnettDispersion(data.frame(t = 1.2, df = 99))$nStat, 1L)
  expect_true(is.na(barnettDispersion(data.frame(t = 1.2, df = 99))$pDispersed))
  expect_equal(barnettDispersion(data.frame(t = numeric(0),
                                            df = numeric(0)))$nStat, 0L)
})

# ---- t-statistic construction --------------------------------------------

test_that("continuous t-statistics equal the pooled two-sample t", {
  d <- data.frame(TRIAL = "T", ROW = "Age",
                  N = c(50, 48), MEAN = c(61.2, 59.8), SD = c(10.1, 11.4),
                  SE = NA_real_, ROUND_MEAN = 1, ROUND_DISPERSION = 1,
                  ROUND_OBSERVATION = 1, stringsAsFactors = FALSE)
  ts <- barnettTStats(d, CategoryNames = character(0))
  n1 <- 50; n2 <- 48; s1 <- 10.1; s2 <- 11.4
  se <- sqrt((1 / n1 + 1 / n2) *
             ((n1 - 1) * s1^2 + (n2 - 1) * s2^2) / (n1 + n2 - 2))
  expect_equal(nrow(ts), 1L)
  expect_equal(ts$t, (61.2 - 59.8) / se)
  expect_equal(ts$df, n1 + n2 - 1)      # the model's df, per the reference
  expect_false(ts$zeroSd)
})

test_that("all pairs of arms are compared", {
  d <- data.frame(TRIAL = "T", ROW = "Age",
                  N = c(40, 41, 39), MEAN = c(60, 61, 59),
                  SD = c(10, 10, 10), SE = NA_real_, ROUND_MEAN = 1,
                  ROUND_DISPERSION = 1, ROUND_OBSERVATION = 1,
                  stringsAsFactors = FALSE)
  ts <- barnettTStats(d, CategoryNames = character(0))
  expect_equal(nrow(ts), 3L)            # A-B, A-C, B-C
  expect_equal(paste(ts$arm1, ts$arm2), c("1 2", "1 3", "2 3"))
})

test_that("a two-level category contributes one statistic, not two", {
  # Male and female counts give perfectly anti-correlated t-statistics.
  # Counting both would tell the model it has twice the evidence.
  d <- data.frame(TRIAL = "T", ROW = "Sex", N = NA_real_, MEAN = NA_real_,
                  SD = NA_real_, SE = NA_real_, ROUND_MEAN = NA_real_,
                  ROUND_DISPERSION = NA_real_, ROUND_OBSERVATION = NA_real_,
                  Male = c(22, 25), Female = c(28, 23),
                  stringsAsFactors = FALSE)
  ts <- barnettTStats(d, CategoryNames = c("Male", "Female"))
  expect_equal(nrow(ts), 1L)
  expect_identical(ts$statistic, "categorical")
  expect_identical(ts$level, "Male")
  expect_equal(ts$df, 50 + 48 - 1)      # arm totals, not a reported N
})

test_that("a three-level category keeps every level", {
  d <- data.frame(TRIAL = "T", ROW = "Income", N = NA_real_, MEAN = NA_real_,
                  SD = NA_real_, SE = NA_real_, ROUND_MEAN = NA_real_,
                  ROUND_DISPERSION = NA_real_, ROUND_OBSERVATION = NA_real_,
                  Low = c(10, 12), Mid = c(20, 18), High = c(20, 20),
                  stringsAsFactors = FALSE)
  ts <- barnettTStats(d, CategoryNames = c("Low", "Mid", "High"))
  expect_equal(nrow(ts), 3L)
  expect_setequal(ts$level, c("Low", "Mid", "High"))
})

test_that("medians are excluded, as the paper requires", {
  d <- data.frame(TRIAL = "T", ROW = "LOS", N = c(50, 48),
                  MEAN = c(5, 6), SD = NA_real_, SE = NA_real_,
                  Q1 = c(3, 4), Q3 = c(8, 9), ROUND_MEAN = 0,
                  ROUND_DISPERSION = NA_real_, ROUND_OBSERVATION = 0,
                  stringsAsFactors = FALSE)
  expect_equal(nrow(barnettTStats(d, CategoryNames = character(0))), 0L)
})

test_that("a zero SD is flagged rather than silently patched", {
  d <- data.frame(TRIAL = "T", ROW = "Age", N = c(50, 48),
                  MEAN = c(60, 60), SD = c(0, 0), SE = NA_real_,
                  ROUND_MEAN = 0, ROUND_DISPERSION = 0,
                  ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  ts <- barnettTStats(d, CategoryNames = character(0))
  expect_true(ts$zeroSd)
  expect_equal(ts$t, 0)                 # identical means, so t is zero
})

test_that("it runs end to end on a validated frame", {
  d <- rbind(
    data.frame(TRIAL = "T", ROW = "Age", N = c(50, 48),
               MEAN = c(61.2, 59.8), SD = c(10.1, 11.4)),
    data.frame(TRIAL = "T", ROW = "Weight", N = c(50, 48),
               MEAN = c(78.4, 79.1), SD = c(14.2, 13.6)),
    data.frame(TRIAL = "T", ROW = "BMI", N = c(50, 48),
               MEAN = c(27.1, 26.8), SD = c(4.4, 4.9)))
  d$SE <- NA_real_; d$ROUND_MEAN <- 1; d$ROUND_DISPERSION <- 1
  d$ROUND_OBSERVATION <- 1
  ts <- barnettTStats(d, CategoryNames = character(0))
  r  <- barnettDispersion(ts)
  expect_equal(nrow(ts), 3L)
  expect_equal(r$nStat, 3L)
  expect_true(r$pDispersed >= 0 && r$pDispersed <= 1)
})

# ---- against the reference sampler ---------------------------------------

test_that("the quadrature agrees with nimble running Barnett's model", {
  skip_on_cran()
  skip_if_not_installed("nimble")
  # bugs_model.txt from github.com/agbarnett/baseline, transcribed
  # verbatim. `mdiff` and `inv.sem2` are supplied so that mdiff/sem is
  # exactly the t we pass to our own function - the two implementations
  # see identical data.
  code <- nimble::nimbleCode({
    for (i in 1:N) {
      mdiff[i] ~ dt(0, tau[i], df[i])
      tau[i] <- inv.sem2[i] * inv.var
    }
    log(inv.var) <- mu.var[pick]
    pick <- var.flag + 1
    var.flag ~ dbern(p_prior)
    mu.var[1] <- 0
    mu.var[2] ~ dnorm(0, 0.1)
  })
  set.seed(3)
  for (scale in c(0.4, 1, 2.5)) {
    tt <- stats::rt(15, 199) * scale
    ours <- barnettDispersion(data.frame(t = tt, df = 199))
    # sem fixed at 1 makes mdiff numerically equal to t.
    samp <- nimble::nimbleMCMC(
      code = code,
      constants = list(N = length(tt), p_prior = 0.5),
      data = list(mdiff = tt, inv.sem2 = rep(1, length(tt)),
                  df = rep(199, length(tt))),
      inits = list(mu.var = c(NA, 0.1), var.flag = 0),
      setSeed = 816, thin = 3, niter = 120000, nburnin = 60000,
      progressBar = FALSE)
    pMcmc <- mean(samp[, "var.flag"])
    # 20,000 kept draws: the standard error on a probability is at most
    # 0.0035, so 4 standard errors is 0.014 plus a little slack.
    expect_equal(ours$pDispersed, pMcmc, tolerance = 0.02)
    # The chain's mu.var[2] is the MIXTURE (prior when the switch is
    # off), which is what our `multiplier` column reproduces.
    expect_equal(log(ours$multiplier), mean(samp[, "mu.var[2]"]),
                 tolerance = 0.15)
  }
})
