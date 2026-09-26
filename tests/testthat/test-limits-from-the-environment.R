# test-limits-from-the-environment.R - a local copy raises the arm cap and
# the app's draw budget by environment variable; unset, the deployed
# defaults hold (ISSUES.md issue 174).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) at Steve's     #
# request: "I'm happy to have my local computer take as long as           #
# necessary. I just don't want shinyapps.io to spend hours on something   #
# that takes the app offline."                                             #
############################################################################
skip_if_not_installed("callr")

# the arm cap is fixed when the package loads, so it is read in a child R
# that loads the package as this process did (from source when the tests
# run from the repository, else the installed package)
root <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = FALSE)
capInChild <- function(envValue) {
  env <- callr::rcmd_safe_env()
  if (!is.null(envValue)) env <- c(env, INTEGRITY_MAX_ARM_N = envValue)
  callr::r(function(root) {
    if (file.exists(file.path(root, "DESCRIPTION"))) {
      suppressPackageStartupMessages(pkgload::load_all(root, quiet = TRUE))
    } else {
      suppressPackageStartupMessages(library(IntegrityAnalysis))
    }
    ns <- asNamespace("IntegrityAnalysis")
    d <- data.frame(TRIAL = 1, ROW = "Age", N = c(6000, 6000), MEAN = c(54.1, 53.8),
                    SD = c(9.2, 8.9), ROUND_MEAN = 1, ROUND_OBSERVATION = 1,
                    stringsAsFactors = FALSE)
    v <- get("validateData", ns)(d)
    list(cap = get(".iaMaxArmN", ns), apiCap = get(".apiMaxN", ns), fail = v$FAIL)
  }, args = list(root = root), env = env, timeout = 600)
}

test_that("unset, the arm cap is 5,000 and an arm of 6,000 is refused; set, both surfaces follow it", {
  d0 <- capInChild(NULL)
  expect_identical(d0$cap, 5000L)
  expect_identical(d0$apiCap, 5000L)
  expect_true(d0$fail)
  d1 <- capInChild("20000")
  expect_identical(d1$cap, 20000L)
  expect_identical(d1$apiCap, 20000L)          # the API's copy is taken from the same constant
  expect_false(d1$fail)
  # nonsense and too-small values fall back; a huge one is clamped
  expect_identical(capInChild("abc")$cap, 5000L)
  expect_identical(capInChild("1")$cap, 5000L)
  expect_identical(capInChild("1e12")$cap, 10000000L)
})

test_that("the app's draw budget reads the environment, and the option wins over it", {
  withr::local_options(IntegrityAnalysis.appDrawBudget = NULL)
  withr::local_envvar(INTEGRITY_APP_DRAW_BUDGET = NA)
  expect_identical(.iaAppDrawBudget(), 10 * .apiMaxDrawBudget)
  withr::local_envvar(INTEGRITY_APP_DRAW_BUDGET = "5e12")
  expect_identical(.iaAppDrawBudget(), 5e12)
  withr::local_options(IntegrityAnalysis.appDrawBudget = 1e6)
  expect_identical(.iaAppDrawBudget(), 1e6)
  withr::local_options(IntegrityAnalysis.appDrawBudget = NULL)
  withr::local_envvar(INTEGRITY_APP_DRAW_BUDGET = "nonsense")
  expect_identical(.iaAppDrawBudget(), 10 * .apiMaxDrawBudget)
})
