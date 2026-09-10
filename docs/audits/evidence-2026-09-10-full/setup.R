# Independent full audit, Codex, 2026-09-10. Run from the repository root
# with project startup enabled, so renv selects its recorded library.
# Copies dependencies into private scratch; does not install/update any package.
root <- getwd()
scratch <- file.path(root, '.audit-2026-09-10-full')
out <- file.path(root, 'docs/audits/evidence-2026-09-10-full')
dst <- file.path(scratch, 'library')
dir.create(dst, recursive = TRUE, showWarnings = FALSE)
d <- read.dcf(file.path(scratch, 'source/DESCRIPTION'))
splitdeps <- function(x) {
  x <- trimws(gsub('\\s*\\([^)]*\\)', '', unlist(strsplit(x, ','))))
  setdiff(x[nzchar(x) & !is.na(x)], 'R')
}
todo <- unique(c(splitdeps(d[1, 'Imports']), 'pkgload', 'testthat', 'plumber'))
done <- character()
versions <- data.frame(package = character(), version = character())
while (length(todo)) {
  p <- todo[1]; todo <- todo[-1]
  if (p %in% done) next
  done <- c(done, p)
  loc <- find.package(p)
  pd <- read.dcf(file.path(loc, 'DESCRIPTION'))
  for (k in intersect(c('Imports', 'Depends', 'LinkingTo'), colnames(pd)))
    todo <- unique(c(todo, splitdeps(pd[1, k])))
  if (!startsWith(tolower(loc), tolower(R.home()))) {
    stopifnot(file.copy(loc, dst, recursive = TRUE, overwrite = TRUE))
  }
  versions <- rbind(versions, data.frame(package = p, version = pd[1, 'Version']))
}
write.csv(versions, file.path(out, 'dependency-versions.csv'), row.names = FALSE)
writeLines(c(R.version.string, paste('Packages copied:', nrow(versions))),
           file.path(out, 'setup-result.txt'))
cat('Private dependency closure ready:', nrow(versions), 'packages\n')
