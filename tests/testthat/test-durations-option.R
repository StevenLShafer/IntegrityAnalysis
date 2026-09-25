# test-durations-option.R - the durations class and the `durations` option:
# post-randomisation quantities a baseline table prints are kept by default
# and flagged, excluded on request, and never refused as outcomes (ISSUES.md
# issue 74, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) to Steve       #
# Shafer's decision of 2026-09-25: whether a duration of surgery or of      #
# anaesthesia belongs in a baseline table is a trial-by-trial judgement    #
# (randomised at induction it is measured after the intervention;          #
# randomised after surgery it precedes it), so the default is to include   #
# and flag, with "exclude" as an API and URL argument and a radio button   #
# in the app. The corpus session's batch 15b U1 measured the alternative:  #
# the refusal on the model-only routes had removed 58 printed duration     #
# variables from 28 Carlisle trials.                                       #
############################################################################

test_that(".ppDurationLabel() names the class and nothing else", {
  yes <- c("Duration of surgery (min)", "Duration of anaesthesia (min)", "Anesthesia time (min)",
           "Operative time", "Length of surgery", "Estimated blood loss (ml)", "Blood loss (mL)",
           "I-D interval (min)", "U-D interval (min)", "Intraoperative fluids (ml)",
           "Fluid replacement (ml)", "Crystalloid administered (ml)")
  no  <- c("Age (yr)", "Duration of diabetes (yr)", "Duration of labour before enrolment (h)",
           "QT interval (ms)", "Weight (kg)", "Time to first analgesic request",
           "Duration of active phase (hours)")
  expect_true(all(.ppDurationLabel(yes)))
  expect_false(any(.ppDurationLabel(no)))
})

test_that("a duration is never an outcome without a block, and is the table's row with one", {
  labs <- c("Duration of surgery (min)", "Time to first analgesic", "QT interval (ms)", "Age")
  expect_identical(.ppOutcomeLabel(labs, NULL), c(FALSE, TRUE, FALSE, FALSE))
  # with the chosen table's block: a duration printed there is spared, one
  # brought in from another table is refused as that table's row
  blk <- c("Table 1", "Age 30 (5)", "Duration of surgery (min) 84 (26)")
  expect_identical(.ppOutcomeLabel(c("Duration of surgery (min)", "Duration of anaesthesia (min)"), blk),
                   c(FALSE, TRUE))
})

fakeTable <- function() {
  data <- data.frame(TRIAL = "T", ROW = c("Age", "Age", "Duration of surgery", "Duration of surgery", "Weight", "Weight"),
                     N = 20L, MEAN = c(30, 31, 84, 86, 70, 71), SD = c(5, 6, 26, 25, 9, 8),
                     stringsAsFactors = FALSE)
  structure(list(data = data, arms = data.frame(arm = c("A", "B"), N = 20L),
                 skipped = data.frame(label = character(0), reason = character(0), text = character(0)),
                 provenance = data.frame(ROW = data$ROW, ENGINE = "heuristic", stringsAsFactors = FALSE),
                 flags = character(0), engine = "heuristic"), class = "ParsePDFTable")
}

test_that(".ppApplyDurations() keeps and flags by default, excludes on request", {
  kept <- .ppApplyDurations(fakeTable(), "include")
  expect_identical(nrow(kept$data), 6L)
  expect_true(any(grepl("post-randomisation quantities", kept$flags)))
  expect_true(any(grepl("Duration of surgery", kept$flags)))
  gone <- .ppApplyDurations(fakeTable(), "exclude")
  expect_identical(unique(gone$data$ROW), c("Age", "Weight"))
  expect_identical(gone$skipped$label, "Duration of surgery")
  expect_true(grepl("durations option", gone$skipped$reason))
  expect_false("Duration of surgery" %in% gone$provenance$ROW)
  expect_true(any(grepl("excluded by the durations option", gone$flags)))
  # a table with no such row is returned as it was
  plain <- fakeTable(); plain$data <- plain$data[plain$data$ROW != "Duration of surgery", ]
  expect_identical(.ppApplyDurations(plain, "exclude")$flags, character(0))
})

durationPdf <- function(file = file.path(tempdir(), "durations.pdf")) {
  vx <- c(300, 420)
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(100, "", c("Placebo (n = 30)", "Drug (n = 30)"), vx),
    rowCells(118, "Age (yr)", c("46 ± 8", "47 ± 9"), vx),
    rowCells(136, "Weight (kg)", c("70 ± 9", "71 ± 8"), vx),
    rowCells(154, "Duration of surgery (min)", c("84 ± 26", "86 ± 25"), vx),
    rowCells(172, "Duration of anaesthesia (min)", c("111 ± 30", "110 ± 31"), vx),
    list(list(x = 60, y = 202, text = "Values are mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("parseBaselineTable(): the default keeps printed durations with a flag; 'exclude' drops them", {
  r <- parseBaselineTable(durationPdf(), ai = "never", tatr = "never", quiet = TRUE)
  expect_setequal(unique(r$data$ROW[!is.na(r$data$MEAN)]),
                  c("Age", "Weight", "Duration of surgery", "Duration of anaesthesia"))
  expect_true(any(grepl("post-randomisation quantities", r$flags)))
  x <- parseBaselineTable(durationPdf(), ai = "never", tatr = "never", quiet = TRUE, durations = "exclude")
  expect_setequal(unique(x$data$ROW[!is.na(x$data$MEAN)]), c("Age", "Weight"))
  expect_setequal(x$skipped$label, c("Duration of surgery", "Duration of anaesthesia"))
  expect_error(parseBaselineTable(durationPdf(), ai = "never", durations = "maybe"))
})

test_that("the batch reader forwards the option to its subprocess, as the API needs", {
  skip_on_cran()
  res <- parseBaselineTableFiles(durationPdf(), ai = "never", quiet = TRUE, timeout = 120,
                                 durations = "exclude")
  r <- res$result[[1]]
  expect_false(is.null(r))
  expect_setequal(unique(r$data$ROW[!is.na(r$data$MEAN)]), c("Age", "Weight"))
  expect_true("Duration of surgery" %in% r$skipped$label)
})

test_that(".iaQueryDurations() reads the page's address in any case, and ignores anything else", {
  expect_identical(.iaQueryDurations(list(SEED = "5", Durations = "Exclude")), "exclude")
  expect_identical(.iaQueryDurations(list(durations = " include ")), "include")
  expect_null(.iaQueryDurations(list(durations = "no")))
  expect_null(.iaQueryDurations(list(seed = "5")))
  expect_null(.iaQueryDurations(list()))
  expect_null(.iaQueryDurations(NULL))
})

test_that("the app's Exclude durations blanks the duration rows' values and Include restores them", {
  shiny::testServer(app_server, {
    session$setInputs(blank = 1)
    d0 <- reactiveData()
    d0$TRIAL[1:4] <- "T"
    d0$ROW[1:4]   <- c("Age", "Age", "Duration of surgery", "Duration of surgery")
    d0$N[1:4]     <- 20
    d0$MEAN[1:4]  <- c(30, 31, 84, 86)
    d0$SD[1:4]    <- c(5, 6, 26, 25)
    reactiveData(d0)
    durationsFound(TRUE)
    session$setInputs(durations = "exclude")
    d1 <- reactiveData()
    dur <- d1$ROW %in% "Duration of surgery"     # the blank rows' ROW is NA
    expect_true(all(is.na(d1$MEAN[dur])))
    expect_identical(d1$ROW[3:4], c("Duration of surgery", "Duration of surgery"))   # the names stay
    expect_identical(d1$MEAN[d1$ROW %in% "Age"], c(30, 31))
    session$setInputs(durations = "include")
    d2 <- reactiveData()
    expect_identical(d2$MEAN[d2$ROW %in% "Duration of surgery"], c(84, 86))
    expect_identical(d2$SD[d2$ROW %in% "Duration of surgery"], c(26, 25))
  })
})

test_that(".apiDurationsArg() reads the request's option", {
  expect_identical(.apiDurationsArg(NULL), list(ok = TRUE, value = "include", sent = FALSE))
  expect_identical(.apiDurationsArg("")$value, "include")
  expect_identical(.apiDurationsArg(" Exclude ")$value, "exclude")
  expect_true(.apiDurationsArg("include")$sent)
  expect_false(.apiDurationsArg("no")$ok)
  expect_match(.apiDurationsArg(list())$reason, "form part")
})
