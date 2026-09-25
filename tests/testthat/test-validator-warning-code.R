# test-validator-warning-code.R - a warning that lets the validator pass:
# an SD larger than its mean, a degenerate variable, a duplicated row are
# filed as issues with the code "warning", painted and reported, without
# failing the table (ISSUES.md issue 79, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) to Steve       #
# Shafer's direction of 2026-09-25: "implement a warning that allows the   #
# validator to pass ... A warning will allow comparisons to be made        #
# against ground truth, while also highlighting to validating software as #
# well as human reviewers where there may be problems that need further   #
# scrutiny." The Corpus session had struggled to tell why some studies    #
# failed to parse when a suspect row failed the whole table.              #
############################################################################

suspectTable <- function() data.frame(
  TRIAL = "T",
  ROW  = c("Age", "Age", "Dose", "Dose", "Dup", "Dup", "Flat", "Flat", "Weight", "Weight"),
  N    = 20L,
  MEAN = c(40, 41, 5, 6, 40, 41, 7, 7, 70, 72),
  SD   = c(8, 9, 12, 13, 8, 9, 0, 0, 10, 11),
  ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)

test_that(".iaRowWarnings() names the three shapes and nothing else", {
  w <- .iaRowWarnings(suspectTable())
  expect_true(all(w$code == "warning"))
  expect_setequal(w$row[w$col == "SD"], c(3L, 4L))                     # Dose: SD > mean
  expect_true(all(grepl("SD larger than the mean", w$note[w$col == "SD"])))
  flat <- w[w$row %in% 7:8, ]
  expect_true(all(grepl("no dispersion", flat$note)))
  dup <- w[w$row %in% 1:2, ]
  expect_true(all(grepl("identical N, mean and SD to \"Dup\"", dup$note)))
  expect_true(all(grepl("identical N, mean and SD to \"Age\"", w$note[w$row %in% 5:6])))
  expect_false(any(w$row %in% 9:10))                                     # Weight is clean
  clean <- suspectTable()[9:10, ]
  expect_null(.iaRowWarnings(clean))
  # a negative mean is not judged against its SD (a change score)
  neg <- data.frame(TRIAL = "T", ROW = "Delta", N = 20L, MEAN = c(-3, -2), SD = c(5, 6),
                    ROUND_MEAN = 0, ROUND_OBSERVATION = 0, stringsAsFactors = FALSE)
  expect_null(.iaRowWarnings(neg))
})

test_that("validateData() passes the table and files the warnings; the analysis runs", {
  v <- validateData(suspectTable())
  expect_false(isTRUE(v$FAIL))
  w <- v$issues[v$issues$code == "warning", ]
  expect_identical(nrow(w), 8L)
  expect_true(all(c("row", "col", "code", "note") %in% names(w)))
  expect_identical(nrow(v$DATA), 10L)         # nothing excluded
  # the same table without the suspect rows files no warning at all
  v2 <- validateData(suspectTable()[9:10, ])
  expect_false(isTRUE(v2$FAIL))
  expect_true(is.null(v2$issues) || !any(v2$issues$code == "warning"))
})

test_that("the service returns the warnings beside a successful analysis", {
  # the Monte Carlo's matrix operations come from Rfast, which the app and
  # the service attach at start-up (app_run.R, runApiService()); a bare
  # .apiAnalyze() in a test attaches it here
  withr::local_package("Rfast")
  quiet <- function(expr) { utils::capture.output(r <- suppressMessages(expr)); r }
  a <- quiet(.apiAnalyze(suspectTable(), seed = 7))
  expect_true(isTRUE(a$ok))
  expect_identical(length(a$warnings), 8L)
  expect_identical(a$warnings[[1]]$code, "warning")
  expect_true(all(vapply(a$warnings, function(x) is.character(x$note) && nzchar(x$note), logical(1))))
  b <- quiet(.apiAnalyze(suspectTable()[9:10, ], seed = 7))
  expect_true(isTRUE(b$ok))
  expect_identical(length(b$warnings), 0L)
})

test_that("the app paints and explains the warning code", {
  src <- paste(readLines(system.file("../R/app_server.R", package = "IntegrityAnalysis"), warn = FALSE), collapse = "\n")
  skip_if(!nzchar(src))
  expect_true(grepl("code === 'warning'", src, fixed = TRUE))
  expect_true(grepl("entry(\"#e9d8ff\", \"warning\"", src, fixed = TRUE))
})
