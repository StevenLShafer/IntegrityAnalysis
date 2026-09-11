# Codex, 2026-09-11. Independent invariance: transpose leaves Pearson's
# statistic and its fixed-margin allocation probabilities unchanged.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
records<-list()
for(J in c(9,14))for(where in c('none','extreme','ordinary','all'))for(seed in c(42,43,44)){
  bad<-if(J==9)3 else 7
  d<-data.frame(TRIAL='T',ROW=rep(sprintf('V%02d',1:J),each=2),N=NA_real_,MEAN=NA_real_,SD=NA_real_,YES=1,NO=99)
  ii<-(bad-1)*2+1:2;d$YES[ii]<-c(0,2);d$NO[ii]<-c(100,98)
  trans<-switch(where,none=integer(),extreme=bad,ordinary=1,all=1:J)
  for(j in trans){ii<-(j-1)*2+1:2;tab<-t(as.matrix(d[ii,c('YES','NO')]));d[ii,c('YES','NO')]<-tab}
  id<-paste0('transpose-J',J,'-',where,'-s',seed)
  f<-file.path(out,paste0('fixture-',id,'.csv'));write.csv(d,f,row.names=FALSE)
  rd<-.apiReadUpload(f,basename(f));a<-isolate(.apiAnalyze(rd$data,seed=seed))
  saveRDS(a,file.path(out,paste0('result-',id,'.rds')))
  if(!is.null(a$results))write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  q<-100/199;ex<-q^J+.5*J*(1-q)*q^(J-1)
  records[[id]]<-cbind(data.frame(case=id,seed=seed,J=J,transpose=where,exact=ex),summary_row(a))
  write.csv(do.call(rbind,records),file.path(out,'transpose-comparisons.csv'),row.names=FALSE)
  cat('DONE',id,records[[id]]$p,records[[id]]$CI95,'M',records[[id]]$M,'\n');flush.console()
}
writeLines('Complete',file.path(out,'transpose-complete.txt'))
