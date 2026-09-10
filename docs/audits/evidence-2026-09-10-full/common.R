# Independent full audit harness, Codex, 2026-09-10.
# Run from the repository root. Paths are constructed, never embedded.
root <- getwd()
scratch <- file.path(root, '.audit-2026-09-10-full')
src <- file.path(scratch, 'source')
out <- file.path(root, 'docs/audits/evidence-2026-09-10-full')
.libPaths(c(file.path(scratch, 'library'), .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(dqrng); library(foreach); library(Rfast); library(MBESS)
  pkgload::load_all(src, quiet = TRUE)
}))
options(width = 120)
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
  x <- gsub(normalizePath(root, winslash = '/', mustWork = TRUE), '<audit-root>', x, fixed = TRUE)
  x <- gsub(root, '<audit-root>', x, fixed = TRUE)
  x <- gsub('[A-Za-z]:[/\\\\][^\n\r\t]*', '<local-path>', x)
  x
}
