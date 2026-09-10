# Make compact, path-free summaries and preserve sanitized console evidence.
source('docs/audits/evidence-2026-09-10-full/common.R')
ff <- list.files(out,'^regression-.*[.]csv$',full.names=TRUE)
ff <- ff[basename(ff)!='regression-summary.csv']
alltests <- do.call(rbind,lapply(ff,read.csv,stringsAsFactors=FALSE))
counts <- aggregate(alltests[c('passed','failed','errors','skipped','warnings')],
                    list(file=alltests$file),sum)
write.csv(counts,file.path(out,'regression-summary.csv'),row.names=FALSE)
write.csv(alltests[alltests$skipped>0|alltests$failed>0|alltests$errors>0,],
          file.path(out,'skips-and-failures.csv'),row.names=FALSE)
for(f in list.files(scratch,'[.](stdout|stderr)[.]txt$',full.names=TRUE)) {
  txt <- readLines(f,warn=FALSE)
  writeLines(clean_message(txt),file.path(out,basename(f)))
}
p <- read.csv(file.path(out,'F-unequal-replications.csv'))
m <- mean(p$p);se <- sd(p$p)/sqrt(nrow(p))
write.csv(data.frame(n_batches=nrow(p),mean_p=m,MC_lower=m-qt(.975,nrow(p)-1)*se,
                    MC_upper=m+qt(.975,nrow(p)-1)*se,reference=p$reference[1]),
          file.path(out,'F-unequal-aggregate.csv'),row.names=FALSE)
ver <- read.csv(file.path(out,'lockfile-comparison.csv'))
writeLines(c(paste('Regression files:',nrow(counts)),paste('Test blocks:',nrow(alltests)),
  paste('Passed assertions:',sum(counts$passed)),paste('Failures:',sum(counts$failed)),
  paste('Errors:',sum(counts$errors)),paste('Skips:',sum(counts$skipped)),
  paste('Locked dependencies compared:',nrow(ver)),paste('Version mismatches:',sum(!ver$matches))),
  file.path(out,'verification-summary.txt'))
