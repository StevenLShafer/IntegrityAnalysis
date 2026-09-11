# Codex, 2026-09-11. Exact law supplied by independent rational Python enumeration.
# The trial contains minimum-state rows and exactly one next-state row, hence
# P = q0^J + .5*J*q1*q0^(J-1). Integer state indices decide ties on actual draws.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
laws<-jsonlite::fromJSON(file.path(out,'multilevel-laws.json'),simplifyVector=FALSE)
ns<-asNamespace('IntegrityAnalysis')
trace('.iaTieCounts',where=ns,print=FALSE,tracer=quote({
  if(length(sims)>=1000 && all(sims>=0)) .GlobalEnv$.auditInputs[[length(.GlobalEnv$.auditInputs)+1L]]<-sims
}))
trace('P_Calc',where=ns,print=FALSE,exit=quote({
  .GlobalEnv$.auditFinal<-list(M=s,keyOf=keyOf,trialStat=trialStat)
}))
records<-list()
for(name in names(laws))for(mode in c('base','arms','categories','both','absent-column','zero-column','disjoint-names')){
  law<-laws[[name]];J<-law$J;p<-length(law$cols);k<-length(law$rows)
  rows<-lapply(seq_len(J),function(j){
    mat<-do.call(rbind,lapply(if(j==2)law[['next']] else law$minimum,unlist))
    mat<-matrix(as.numeric(mat),nrow=k)
    if(j==2 && mode %in% c('arms','both'))mat<-mat[rev(seq_len(k)),,drop=FALSE]
    if(j==2 && mode %in% c('categories','both'))mat<-mat[,c(2:p,1),drop=FALSE]
    d<-data.frame(TRIAL='T',ROW=sprintf('V%02d',j),N=rep(NA_real_,k),MEAN=NA_real_,SD=NA_real_)
    for(cn in paste0('CAT',seq_len(p)))d[[cn]]<-NA_real_
    d$SPARE<-NA_real_
    for(cn in unlist(lapply(seq_len(J),function(jj)paste0('C',jj,'X',seq_len(p)))))d[[cn]]<-NA_real_
    if(mode=='disjoint-names')for(cc in seq_len(p))d[[paste0('C',j,'X',cc)]]<-mat[,cc]
    else for(cc in seq_len(p))d[[paste0('CAT',cc)]]<-mat[,cc]
    if(j==2 && mode=='absent-column'){d$SPARE<-d$CAT1;d$CAT1<-NA_real_}
    if(j==2 && mode=='zero-column')d$SPARE<-0
    d
  })
  d<-do.call(rbind,rows);id<-paste0('multi-',name,'-',mode)
  f<-file.path(out,paste0('fixture-',id,'.csv'));write.csv(d,f,row.names=FALSE)
  .auditInputs<-list();rd<-.apiReadUpload(f,basename(f));a<-isolate(.apiAnalyze(rd$data,seed=42));stopifnot(a$ok)
  B<-.auditFinal$M;draws<-tail(.auditInputs,J);stopifnot(all(lengths(draws)==B))
  states<-vapply(law$states,function(s)s$statistic,numeric(1))
  cuts<-(head(states,-1)+tail(states,-1))/2
  codes<-do.call(cbind,lapply(draws,function(x)findInterval(x,cuts)))
  distance<-rowSums(codes);less<-sum(distance==0);equal<-sum(distance==1)
  kt<-.auditFinal$trialStat;stopifnot(length(unique(.auditFinal$keyOf))==1,
    kt$kG==less,kt$kE==equal)
  saveRDS(list(codes=codes,production=.auditFinal),file.path(out,paste0('draws-',id,'.rds')))
  write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  ci<-if(!nzchar(summary_row(a)$CI95))c(NA,NA) else as.numeric(strsplit(summary_row(a)$CI95,' to ')[[1]])
  records[[id]]<-cbind(data.frame(case=id,seed=42,exact=law$exact_trial,integer_midp=(less+.5*equal)/B,
    integer_less=less,integer_ties=equal,keys=length(unique(.auditFinal$keyOf)),
    reference_inside_displayed_CI=if(anyNA(ci))NA else law$exact_trial>=ci[1]&&law$exact_trial<=ci[2]),summary_row(a))
  write.csv(do.call(rbind,records),file.path(out,'multilevel-comparisons.csv'),row.names=FALSE)
  cat('DONE',id,'p',records[[id]]$p,'CI',records[[id]]$CI95,'M',B,'\n');flush.console()
}
untrace('.iaTieCounts',where=ns);untrace('P_Calc',where=ns)
writeLines('Complete',file.path(out,'multilevel-complete.txt'))
