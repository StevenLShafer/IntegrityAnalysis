# Re-executed for the fourth full audit at 7c6583f, Codex, 2026-09-11.
# Independent final statistical audit, Codex, 2026-09-11.
# Execution locations are supplied by the launcher; no machine paths in evidence.
scratch <- Sys.getenv('INTEGRITY_AUDIT_SCRATCH')
out <- Sys.getenv('INTEGRITY_AUDIT_OUTPUT')
stopifnot(nzchar(scratch), nzchar(out))
src <- Sys.getenv('INTEGRITY_AUDIT_SOURCE', file.path(scratch, 'source'))
librarySource <- Sys.getenv('INTEGRITY_AUDIT_LIBRARY_SOURCE')
stopifnot(nzchar(librarySource), dir.exists(librarySource))
.libPaths(c(librarySource, .Library))
Sys.unsetenv(c('ANTHROPIC_API_KEY', 'INTEGRITY_CHILD_APIKEY', 'INTEGRITY_TATR_PYTHON'))
Sys.setenv(NOT_CRAN = 'true')
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(dqrng); library(foreach); library(Rfast); library(MBESS)
  pkgload::load_all(src, quiet = TRUE)
}))
options(ECHO_OUTPUT_COMMENTS = FALSE, width = 120)
run_engine <- function(d, seed = 42, m = 100000, cats = NULL, validated = TRUE) {
  set.seed(seed); dqrng::dqset.seed(seed)
  shiny::isolate({
    if (validated) {
      v <- validateData(d)
      if (isTRUE(v$FAIL)) stop('Validation refused the fixture')
      P_Calc(unique(d$TRIAL)[1], v$DATA, v$CategoryNames, m, excluded = v$Excluded)
    } else P_Calc(unique(d$TRIAL)[1], d, cats, m)
  })
}
clean_message <- function(x) {
  for (p in c(scratch, out, normalizePath(tempdir(), winslash = '/', mustWork = FALSE)))
    x <- gsub(p, '<audit-location>', x, fixed = TRUE)
  gsub('[A-Za-z]:[/\\\\][^\n\r\t]*', '<local-path>', x)
}
summary_row <- function(a) {
  s <- a$results[a$results$KIND %in% 'summary', , drop = FALSE]
  data.frame(ok = isTRUE(a$ok), p = if (nrow(s)) as.character(s$P[1]) else NA_character_,
    CI95 = if (nrow(s)) as.character(s$CI95[1]) else NA_character_,
    M = if (!is.null(a$results)) paste(unique(a$results$M[a$results$KIND %in% 'variable' & !is.na(a$results$M)]), collapse = ';') else '',
    note = if (nrow(s)) as.character(s$NOTE[1]) else '')
}
