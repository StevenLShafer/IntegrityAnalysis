# Codex, 2026-09-11. Trial identity across the newly clipped journal-CSV marker.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
records<-list()
for(size in c(199,200,201,240))for(delta in c(0,.1,.2,.5)){
  prefix<-substr(paste(rep('Synthetic baseline comparison ',20),collapse=''),1,size-1)
  ids<-paste0(prefix,c('A','B'))
  make<-function(ids){unlist(lapply(ids,function(id)c(paste0('Trial: ',id),
    'Variable,Arm A (n=30),Arm B (n=30)',
    sprintf('"Age, mean (SD)","50.0 (10.0)","%.1f (10.0)"',50+delta))))}
  id<-paste0('trial-id-',size,'-delta-',delta)
  f<-file.path(out,paste0('fixture-',id,'.csv'));writeLines(make(ids),f)
  rd<-.apiReadUpload(f,basename(f));stopifnot(rd$ok)
  a<-isolate(.apiAnalyze(rd$data,seed=42));stopifnot(a$ok)
  write.csv(rd$data,file.path(out,paste0('parsed-',id,'.csv')),row.names=FALSE)
  write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  saveRDS(a,file.path(out,paste0('result-',id,'.rds')))
  s<-a$results[a$results$KIND %in% 'summary',,drop=FALSE]
  records[[id]]<-data.frame(case=id,id_length=size,delta=delta,read_trials=length(unique(rd$data$TRIAL)),
    analyzed_trials=a$trials,overallP=a$overallP,summary_p=paste(s$P,collapse=';'),
    displayed_CI=paste(s$CI95,collapse=';'),actual_M=paste(unique(a$results$M[!is.na(a$results$M)]),collapse=';'),
    flags=paste(rd$flags,collapse=';'))
  write.csv(do.call(rbind,records),file.path(out,'trial-id-comparisons.csv'),row.names=FALSE)
  cat('DONE',id,'trials',a$trials,'p',a$overallP,'\n');flush.console()
}
writeLines('Complete',file.path(out,'trial-id-complete.txt'))
