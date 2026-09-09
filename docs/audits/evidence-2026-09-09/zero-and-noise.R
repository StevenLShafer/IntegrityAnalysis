# Synthetic invariants and selection uncertainty. GPT-6 (Codex), 2026-09-09 brief.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od<-'docs/audits/evidence-2026-09-09'
if(!length(commandArgs(TRUE)) || 'zero'%in%commandArgs(TRUE)) {
 sink(file.path(od,'zero-extended.txt'),split=TRUE)
 for(n in c(20,30,40,100,101))for(mu in c(1,2.3))for(dec in c(6,14)) {
  d<-data.frame(TRIAL='T',ROW='X',N=rep(n,2),MEAN=mu,SD=3,ROUND_MEAN=dec,ROUND_OBSERVATION=0,ROUND_DISPERSION=3)
  v<-shiny::isolate(validateData(d));if(v$FAIL)next
  set.seed(42);dqset.seed(42);x<-suppressWarnings(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,100000)))
  print(data.frame(N=n,mean=mu,d=dec,x[1,c('P','CI95','M')]))
 }
 sink()
}
if(!length(commandArgs(TRUE)) || 'noise'%in%commandArgs(TRUE)) {
 # Binary table oracle: vectorized exact hypergeometric mid-p, no engine helper.
 ep<-function(a,c,N) {
  C<-a+c;G<-2*N;dist<-abs(G*a-N*C);lo<-(N*C-dist)/G;hi<-(N*C+dist)/G
  first<-floor(lo+1e-9)+1;last<-ceiling(hi-1e-9)-1
  p<-ifelse(last>=first,phyper(last,C,G-C,N)-phyper(first-1,C,G-C,N),0)
  p+.5*dhyper(round(lo),C,G-C,N)+.5*ifelse(hi!=lo,dhyper(round(hi),C,G-C,N),0)
 }
 large<-'large'%in%commandArgs(TRUE);tag<-if(large)'large' else 'selection';nseed<-if(large)30L else 60L
 N<-if(large)5000 else 400
 lo<-if(large)matrix(2475L,2,2) else matrix(c(158,238),2,2,byrow=TRUE)
 hi<-lo+if(large)50L else 4L
 z<-expand.grid(a=lo[1,1]:hi[1,1],c=lo[2,1]:hi[2,1]);true<-ep(z$a,z$c,N);pMax<-max(true);pMin<-min(true)
 saveRDS(list(N=N,lo=lo,hi=hi,candidates=z,p=true),file.path(od,paste0(tag,'-oracle.rds')))
 # Per seed checkpoints; rerunning resumes. Selection budgets are unmodified.
 for(seed in seq_len(nseed)) {
  f<-file.path(od,sprintf('%s-seed-%03d.rds',tag,seed));if(file.exists(f))next
  start<-proc.time()[3];set.seed(seed)
  # Trace which budgets actually scored the chosen table, without changing RNG.
  orig<-.ppFailsafeTableFill;env<-new.env(parent=environment(orig));environment(orig)<-env
  calls<-list();env$.ppTableP<-function(tab,reps){p<-.ppTableP(tab,reps);calls[[length(calls)+1L]]<<-list(tab=tab,reps=reps,p=p);p}
  r<-orig(lo,hi,matrix(NA_integer_,2,2),c(N,N));actual<-ep(r$counts[1,1],r$counts[2,1],N)
  scored<-Filter(function(x)isTRUE(all.equal(unname(x$tab),unname(r$counts),check.attributes=FALSE)),calls)
  lastBudget<-tail(vapply(scored,function(x)x$reps,numeric(1)),1)
  ans<-list(seed=seed,trueBest=pMax,trueWorst=pMin,selectedTrue=actual,shortfall=pMax-actual,
   pBest=r$pBest,pWorst=r$pWorst,straddles=r$straddles,budget=lastBudget,counts=r$counts,seconds=proc.time()[3]-start)
  saveRDS(ans,f);cat('seed',seed,'shortfall',ans$shortfall,'budget',lastBudget,'elapsed',ans$seconds,'\n');flush.console()
 }
 a<-lapply(seq_len(nseed),function(s)readRDS(file.path(od,sprintf('%s-seed-%03d.rds',tag,s))))
 sink(file.path(od,paste0(tag,'-noise.txt')),split=TRUE)
 cat('Arm N',N,'; exact best/worst:',pMax,pMin,'\n')
 tab<-do.call(rbind,lapply(a,function(x)as.data.frame(x[setdiff(names(x),'counts')])));print(tab)
 cat('Shortfall distribution:\n');print(quantile(tab$shortfall,c(0,.25,.5,.75,.9,.95,1)))
 cat('Winners retaining only coarse scoring:',sum(tab$budget==2000),'of',nrow(tab),'\n')
 saveRDS(tab,file.path(od,paste0(tag,'-noise.rds')));sink()
}
