# Codex, 2026-09-11. Three-arm canonical keys and integer-lattice references
# through CSV upload and analysis, including full, direct and median branches.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
ns<-asNamespace('IntegrityAnalysis')
trace('.iaTieCounts',where=ns,print=FALSE,tracer=quote({
  if(length(sims)>=1000 && all(sims>=0)) .GlobalEnv$.auditInputs[[length(.GlobalEnv$.auditInputs)+1L]]<-sims
}))
trace('P_Calc',where=ns,print=FALSE,exit=quote({
  .GlobalEnv$.auditFinal<-list(M=s,keyOf=keyOf,trialStat=trialStat,
    obs=vapply(rows,function(r)r$sim$obs,numeric(1)))
}))
perms<-list(1:3,c(1,3,2),c(2,1,3),c(2,3,1),c(3,1,2),3:1)
records<-list();keyRecords<-list()
for(kind in c('continuous','direct','median')){
  a<-data.frame(TRIAL='T',ROW='A',N=c(20,30,40),MEAN=c(50,50.1,50.2),SD=c(2,2.2,2.4),
    ROUND_MEAN=1,ROUND_DISPERSION=1,ROUND_OBSERVATION=1)
  if(kind=='direct')a$N<-c(100,125,150)
  if(kind=='median'){a$N<-c(9,11,13);a$MEAN<-c(10,10.1,10.2);a$SD<-NA_real_;
    a$Q1<-c(8,8.1,8.2);a$Q3<-c(12,12.1,12.2)}
  branch<-if(kind=='median')'median' else 'continuous'
  key<-.iaNullKey(branch,a)
  for(i in seq_along(perms))keyRecords[[paste(kind,i)]]<-data.frame(branch=kind,check=paste0('permutation-',i),
    passed=identical(key,.iaNullKey(branch,a[perms[[i]],])))
  fields<-if(kind=='median')c('N','MEAN','Q1','Q3','ROUND_MEAN','ROUND_DISPERSION','ROUND_OBSERVATION') else
    c('N','MEAN','SD','ROUND_MEAN','ROUND_DISPERSION','ROUND_OBSERVATION')
  for(cn in fields)for(i in 1:3){b<-a;b[[cn]][i]<-b[[cn]][i]+1
    keyRecords[[paste(kind,cn,i)]]<-data.frame(branch=kind,check=paste(cn,'arm',i),
      passed=!identical(key,.iaNullKey(branch,b)))}
  b<-a[3:1,];b$ROW<-'B';d<-rbind(a,b);id<-paste0('arm-key-',kind)
  f<-file.path(out,paste0('fixture-',id,'.csv'));write.csv(d,f,row.names=FALSE)
  .auditInputs<-list();rd<-.apiReadUpload(f,basename(f));z<-isolate(.apiAnalyze(rd$data,seed=42));stopifnot(z$ok)
  B<-.auditFinal$M;raw<-tail(.auditInputs,2);stopifnot(all(lengths(raw)==B))
  # Every printed mean/median has step .1, so this recovers the exact
  # numerator sum (Ntotal * integer_value - weighted_integer_sum)^2.
  multiplier<-sum(a$N)^2*100
  codes<-lapply(raw,function(x)round(x*multiplier));obs<-round(.auditFinal$obs*multiplier)
  pool<-unlist(codes);L<-length(pool);prob<-(rank(pool,ties.method='average')-.5)/L
  clamp<-function(p)pmin(pmax(p,1/(L+1)),.9999)
  score<-rowSums(matrix(qnorm(clamp(prob),lower.tail=FALSE),B,2))
  op<-vapply(obs,function(o)(sum(pool<o)+.5*sum(pool==o))/L,numeric(1))
  observed<-sum(qnorm(clamp(op),lower.tail=FALSE))
  eq<-abs(score-observed)<=1e-10*pmax(abs(score),abs(observed))
  less<-sum(score>observed & !eq);equal<-sum(eq)
  stopifnot(length(unique(.auditFinal$keyOf))==1,less==.auditFinal$trialStat$kG,equal==.auditFinal$trialStat$kE)
  write.csv(z$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  records[[kind]]<-cbind(data.frame(branch=kind,keys=1,integer_less=less,integer_ties=equal,
    integer_midp=(less+.5*equal)/B),summary_row(z))
  saveRDS(list(integer_draws=codes,production=.auditFinal),file.path(out,paste0('draws-',id,'.rds')))
  write.csv(do.call(rbind,records),file.path(out,'arm-key-comparisons.csv'),row.names=FALSE)
  cat('DONE',kind,'M',B,'\n');flush.console()
}
k<-do.call(rbind,keyRecords);stopifnot(all(k$passed))
write.csv(k,file.path(out,'arm-key-property-checks.csv'),row.names=FALSE)
untrace('.iaTieCounts',where=ns);untrace('P_Calc',where=ns)
writeLines('Complete',file.path(out,'arm-key-complete.txt'))
