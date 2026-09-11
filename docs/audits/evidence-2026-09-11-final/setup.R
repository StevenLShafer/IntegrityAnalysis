# Run --vanilla against an existing dependency library, copied without modification.
librarySource <- Sys.getenv('INTEGRITY_AUDIT_LIBRARY_SOURCE')
stopifnot(nzchar(librarySource), dir.exists(librarySource))
.libPaths(c(librarySource, .Library))
scratch <- Sys.getenv('INTEGRITY_AUDIT_SCRATCH'); out <- Sys.getenv('INTEGRITY_AUDIT_OUTPUT')
stopifnot(nzchar(scratch), nzchar(out))
reuse <- identical(Sys.getenv('INTEGRITY_AUDIT_REUSE_LIBRARY'), 'true')
dst <- file.path(scratch, 'library'); dir.create(dst, recursive = TRUE, showWarnings = FALSE)
d <- read.dcf(file.path(scratch, 'source/DESCRIPTION'))
splitdeps <- function(x) {
  x <- trimws(gsub('\\s*\\([^)]*\\)', '', unlist(strsplit(x, ','))))
  setdiff(x[nzchar(x) & !is.na(x)], 'R')
}
todo <- unique(c(splitdeps(d[1, 'Imports']), 'pkgload', 'testthat', 'plumber'))
done <- character(); versions <- data.frame(package = character(), version = character())
while (length(todo)) {
  p <- todo[1]; todo <- todo[-1]
  if (p %in% done) next
  done <- c(done, p); loc <- find.package(p); pd <- read.dcf(file.path(loc, 'DESCRIPTION'))
  for (k in intersect(c('Imports', 'Depends', 'LinkingTo'), colnames(pd)))
    todo <- unique(c(todo, splitdeps(pd[1, k])))
  if (!reuse && !startsWith(tolower(loc), tolower(R.home())))
    stopifnot(file.copy(loc, dst, recursive = TRUE, overwrite = TRUE))
  versions <- rbind(versions, data.frame(package = p, version = pd[1, 'Version']))
}
write.csv(versions, file.path(out, 'dependency-versions.csv'), row.names = FALSE)
lock <- jsonlite::fromJSON(file.path(scratch,'source/renv.lock'), simplifyVector=FALSE)$Packages
matched <- do.call(rbind,lapply(intersect(versions$package,names(lock)),function(p)
  data.frame(package=p,installed=as.character(packageVersion(p)),locked=lock[[p]]$Version,
             matches=package_version(as.character(packageVersion(p)))==package_version(lock[[p]]$Version))))
write.csv(matched,file.path(out,'lockfile-comparison.csv'),row.names=FALSE)
stopifnot(all(matched$matches))
writeLines(c(R.version.string, paste('Packages inventoried:', nrow(versions)),
  paste('Reused existing private dependency snapshot:',reuse), paste('Locked versions matched:',nrow(matched))), file.path(out, 'setup-result.txt'))
cat('Private dependency closure ready:', nrow(versions), 'packages;',nrow(matched),'lock matches\n')
