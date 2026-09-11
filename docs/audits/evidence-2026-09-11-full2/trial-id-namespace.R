# Independent fourth-pass audit, Codex, 2026-09-11.
# A digest-width collision is not needed: a short literal identifier can
# equal the display spelling generated from an unrelated long identifier.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
long<-paste0(paste(rep('Synthetic identity ',12),collapse=''),'A')
short<-.wideTrialId(long)
stopifnot(nchar(long,type='bytes')>200,nchar(short,type='bytes')<=200,long!=short,
          identical(.wideTrialId(long),.wideTrialId(short)))
ids<-c(long,short)
write.csv(data.frame(input=ids,bytes=nchar(ids,type='bytes'),output=vapply(ids,.wideTrialId,character(1))),
  file.path(out,'trial-id-namespace-identities.csv'),row.names=FALSE)
records<-list()
for(mode in c('wide','template','short-control','same-id-control')) {
  use<-switch(mode,'short-control'=c('Synthetic trial A','Synthetic trial B'),
    'same-id-control'=c(long,long),ids)
  id<-paste0('trial-id-namespace-',mode);f<-file.path(out,paste0('fixture-',id,'.csv'))
  if(mode=='template'){
    d<-data.frame(TRIAL=rep(use,each=2),ROW='Age',N=30,MEAN=rep(c(50,50.5),2),SD=10,
      ROUND_MEAN=1,ROUND_DISPERSION=1,ROUND_OBSERVATION=1)
    write.csv(d,f,row.names=FALSE)
  }else writeLines(unlist(lapply(use,function(x)c(paste0('Trial: ',x),
    'Variable,Arm A (n=30),Arm B (n=30)',
    '"Age, mean (SD)","50.0 (10.0)","50.5 (10.0)"'))),f)
  rd<-.apiReadUpload(f,basename(f));stopifnot(rd$ok)
  a<-isolate(.apiAnalyze(rd$data,seed=42));stopifnot(a$ok)
  write.csv(rd$data,file.path(out,paste0('parsed-',id,'.csv')),row.names=FALSE)
  write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  s<-a$results[a$results$KIND %in% 'summary',,drop=FALSE]
  records[[mode]]<-data.frame(mode=mode,seed=42,expected_trials=length(unique(use)),
    parsed_trials=length(unique(rd$data$TRIAL)),analyzed_trials=a$trials,
    overallP=a$overallP,overall_CI='not displayed',trial_p=paste(s$P,collapse=';'),
    displayed_trial_CI=paste(s$CI95,collapse=';'),
    actual_M=paste(unique(a$results$M[!is.na(a$results$M)]),collapse=';'),
    reader_flags=paste(rd$flags,collapse=';'),analysis_flags=paste(a$flags,collapse=';'))
  write.csv(do.call(rbind,records),file.path(out,'trial-id-namespace-comparisons.csv'),row.names=FALSE)
  cat('DONE',mode,'trials',a$trials,'p',a$overallP,'\n');flush.console()
}
writeLines('Complete',file.path(out,'trial-id-namespace-complete.txt'))
