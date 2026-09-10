# Re-execute every test file named in the full audit brief, plus related
# engine, full-pipeline, API, and output contract tests. Checkpoint per file.
source('docs/audits/evidence-2026-09-10-full/common.R')
files <- c('pcalc-direct', 'sd-rounding-draw', 'sd-interval-cells',
 'validate-rounding', 'known-answer', 'tie-criterion', 'summary-kind',
 'median-iqr', 'quartile-draw', 'quartile-precision', 'numeric-resolution',
 'screen-2026-09-08', 'failsafe-table', 'screen-2026-09-09',
 'screen-2026-09-09-1532', 'text-precision', 'audit-2026-09-09-f6',
 'audit-2026-09-10-f1', 'audit-2026-09-10-f3', 'screen-2026-09-10-1143',
 'audit-2026-09-10-f4', 'screen-2026-09-10-1119', 'api-structural-issues',
 'screen-2026-09-10-1222', 'adaptive-m', 'seed-and-ranges',
 'input-contract', 'app-pipeline', 'api-service', 'api-flags',
 'degenerate-categories', 'results-workbook', 'dispersion',
 'screen-2026-09-10-0536', 'screen-2026-09-10-0633', 'screen-2026-09-10-0734',
 'screen-2026-09-10-0815', 'screen-2026-09-10-0858', 'screen-2026-09-10-0923')
for (nm in files) {
  dest <- file.path(out, paste0('regression-', nm, '.csv'))
  if (file.exists(dest)) next
  cat('START', nm, '\n'); flush.console()
  env <- new.env(parent = globalenv())
  for (f in list.files(file.path(src, 'tests/testthat'), '^helper.*[.]R$', full.names = TRUE))
    sys.source(f, envir = env)
  tm <- system.time({
    ans <- testthat::test_file(file.path(src, 'tests/testthat', paste0('test-', nm, '.R')),
                              env = env, reporter = 'silent')
  })
  rows <- lapply(ans, function(a) {
    rr <- a$results
    types <- vapply(rr, function(z) class(z)[1], character(1))
    msgs <- vapply(rr, function(z) if (inherits(z, c('expectation_skip', 'expectation_failure', 'expectation_error')))
      clean_message(conditionMessage(z)) else '', character(1))
    data.frame(file = paste0('test-', nm, '.R'), test = a$test,
      passed = sum(types == 'expectation_success'), failed = sum(types == 'expectation_failure'),
      errors = sum(types == 'expectation_error'), skipped = sum(types == 'expectation_skip'),
      warnings = sum(types == 'expectation_warning'), details = paste(msgs[nzchar(msgs)], collapse = ' | '))
  })
  tab <- do.call(rbind, rows)
  write.csv(tab, dest, row.names = FALSE)
  cat('DONE', nm, 'seconds', tm[['elapsed']], 'passed', sum(tab$passed),
      'failed', sum(tab$failed), 'errors', sum(tab$errors), 'skipped', sum(tab$skipped), '\n')
  flush.console()
}
writeLines('Completed all requested regression files.', file.path(out, 'regressions-complete.txt'))
