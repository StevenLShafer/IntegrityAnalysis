# Re-executed for the fourth full audit at 7c6583f, Codex, 2026-09-11.
# Codex, 2026-09-11. Aggregate executed checks and check serialized evidence.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
f<-list.files(out,'^regression-.*[.]csv$',full.names=TRUE)
f<-f[!basename(f) %in% c('regression-summary.csv','regression-totals.csv','regression-exceptions.csv')]
z<-do.call(rbind,lapply(f,read.csv))
tab<-aggregate(cbind(passed,failed,errors,skipped,warnings)~file,z,sum)
write.csv(tab,file.path(out,'regression-summary.csv'),row.names=FALSE)
write.csv(z[z$skipped>0|z$failed>0|z$errors>0,],file.path(out,'regression-exceptions.csv'),row.names=FALSE)
write.csv(data.frame(files=length(f),test_blocks=nrow(z),as.list(colSums(z[,c('passed','failed','errors','skipped','warnings')]))),
  file.path(out,'regression-totals.csv'),row.names=FALSE)
# RDS objects contain numeric arrays / synthetic result fields only. Refuse
# environment/function objects and Windows paths, including in attributes.
scanObject<-function(x){
  if(is.environment(x)||is.function(x))stop('Unexpected executable object in evidence')
  if(is.character(x)&&any(grepl('[A-Za-z]:[/\\\\]',x)))stop('Local path in serialized evidence')
  if(is.list(x))for(y in x)scanObject(y)
  for(y in attributes(x))scanObject(y)
}
ff<-list.files(out,'[.]rds$',full.names=TRUE)
for(f in ff)scanObject(readRDS(f))
writeLines(paste('Checked',length(ff),'RDS files: no functions, environments, or Windows paths.'),
  file.path(out,'serialized-evidence-check.txt'))
