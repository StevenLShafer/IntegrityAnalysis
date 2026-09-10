# Verify delivery consistency; these checks do not modify the engine.
root <- getwd()
out <- file.path(root,'docs/audits/evidence-2026-09-10-full')
.libPaths(c(file.path(root,'.audit-2026-09-10-full/library'),.libPaths()))
for(f in list.files(out,'[.]R$',full.names=TRUE)) parse(f,encoding='UTF-8')
pattern <- '(?<![A-Za-z])[A-Za-z]:[/\\\\]'
textfiles <- list.files(out,'[.](R|md|csv|txt|json)$',full.names=TRUE)
bad <- character()
for(f in textfiles) {
  txt <- readLines(f,warn=FALSE,encoding='UTF-8')
  if(any(grepl(pattern,txt,perl=TRUE,useBytes=TRUE)))bad <- c(bad,basename(f))
}
has_path <- function(x) {
  if(is.environment(x))return(TRUE)
  if(is.character(x))return(any(grepl(pattern,x,perl=TRUE,useBytes=TRUE),na.rm=TRUE))
  if(is.list(x))return(any(vapply(x,has_path,logical(1))))
  FALSE
}
for(f in list.files(out,'[.]rds$',full.names=TRUE))
  if(has_path(readRDS(f)))bad <- c(bad,basename(f))
stopifnot(!length(bad))
for(doc in c(file.path(root,'docs/audits/2026-09-10-full-independent-statistical-audit-chatgpt.md'),
             file.path(out,'README.md'))) {
  txt <- paste(readLines(doc,warn=FALSE),collapse='\n')
  links <- regmatches(txt,gregexpr('\\]\\([^)]*\\)',txt,perl=TRUE))[[1]]
  for(link in links) {
    target <- substr(link,3,nchar(link)-1)
    if(grepl('^https?://',target))next
    stopifnot(file.exists(file.path(dirname(doc),sub('#.*$','',target))))
  }
}
sumry <- read.csv(file.path(out,'regression-summary.csv'))
stopifnot(sum(sumry$passed)==1631,sum(sumry$failed)==0,sum(sumry$errors)==0)
dr <- read.csv(file.path(out,'same-draw-combination.csv'))
stopifnot(all(abs(dr$engine_p-c(.003285,.00013))<1e-12),
          all(dr$exact_p>dr$engine_CI_upper),
          all(dr$ties_counted_equal+dr$ties_counted_below+dr$ties_counted_greater==dr$genuine_ties))
body <- jsonlite::fromJSON(file.path(out,'http-http-duplicate.json'),simplifyVector=FALSE)
stopifnot(identical(body$issues[[1]]$row,'NA'))
b <- jsonlite::fromJSON(file.path(out,'http-all-excluded-trial.json'),simplifyVector=FALSE)
r <- read.csv(text=b$resultsCsv)
stopifnot(!('B'%in%r$TRIAL),'B'%in%names(b$journalTables),grepl('"B"',b$templateCsv,fixed=TRUE))
for(id in c('ordinary-N100-J9-bad3','ordinary-N100-J14-bad7')) {
  b <- jsonlite::fromJSON(file.path(out,paste0('http-',id,'.json')),simplifyVector=FALSE)
  r <- read.csv(text=b$resultsCsv)
  expected <- if(grepl('J9',id)) .003285 else .00013
  stopifnot(as.numeric(r$P[which(r$KIND=='summary')])==expected)
}
writeLines(c('All evidence scripts parse; report and evidence README local links resolve.',
 'No machine-local paths or serialized R environments found in evidence.',
 'Regression totals agree with the report.',
 'Same-draw reference counts reconcile.',
 'Both numerical fixtures reproduce in actual HTTP resultsCsv.',
 'Entirely excluded trial and structural JSON defect reproduce in HTTP.'),
 file.path(out,'artifact-checks.txt'))
