# Independent audit environment snapshot, Codex, 2026-09-10.
root <- 'C:/dev/IntegrityAnalysis'
src <- '<the project renv library>'   # machine-local path redacted at commit (2026-09-10); it is the renv library the README's Recreate section names
dst <- file.path(root, '.audit-2026-09-10/library')
dir.create(dst, recursive=TRUE, showWarnings=FALSE)
.libPaths(c(src,'<the user R 4.5 library>',.libPaths()))   # redacted at commit, as above
d <- read.dcf(file.path(root,'.audit-2026-09-10/source/DESCRIPTION'))
splitdeps <- function(x) {
 x <- unlist(strsplit(x,',')); x <- trimws(gsub('\\s*\\([^)]*\\)', '', x))
 setdiff(x[nzchar(x) & !is.na(x)], 'R')
}
todo <- unique(c(splitdeps(d[1,'Imports']), 'shiny','dqrng','foreach','Rfast','MBESS','pkgload','testthat'))
done <- character()
while(length(todo)) {
 p <- todo[1]; todo <- todo[-1]; if(p %in% done) next
 done <- c(done,p); loc <- find.package(p)
 pd <- read.dcf(file.path(loc,'DESCRIPTION'))
 for(k in intersect(c('Imports','Depends','LinkingTo'),colnames(pd))) todo <- unique(c(todo,splitdeps(pd[1,k])))
 if(!startsWith(tolower(loc),tolower(R.home()))) {
   stopifnot(file.copy(loc,dst,recursive=TRUE,overwrite=TRUE))
 }
}
writeLines(done,file.path(root,'docs/audits/evidence-2026-09-10/library-packages.txt'))
cat('Copied dependency closure:',length(done),'packages\n')
