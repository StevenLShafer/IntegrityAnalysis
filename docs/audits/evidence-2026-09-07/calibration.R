# Independent synthetic audit, GPT-6, 2026-09-07. Each full-size trial is
# saved immediately and the run resumes by case + index. Launch from repo root.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
outdir <- 'docs/audits/evidence-2026-09-07'
outfile<-file.path(outdir,'calibration.csv')
args<-commandArgs(TRUE);limit<-if(length(args))as.integer(args[1]) else 400L
done<-if(file.exists(outfile))read.csv(outfile) else data.frame(case=character(),index=integer())
for(case in c('bounded_beta','coarse_quartiles','six_arm_normal')) for(i in seq_len(limit)) {
 if(any(done$case==case & done$index==i))next
 set.seed(71000+i);dqset.seed(81000+i)
 if(case=='six_arm_normal') {
  ns<-c(3,5,10,30,100,300)
  xx<-lapply(ns,function(n)round(rnorm(n,5,1),4))
  d<-data.frame(TRIAL='T',ROW='X',N=ns,MEAN=round(vapply(xx,mean,0.),4),SD=round(vapply(xx,sd,0.),4),ROUND_MEAN=4,ROUND_OBSERVATION=4,ROUND_DISPERSION=4)
 } else {
  xx<-lapply(1:2,function(j)round(if(case=='bounded_beta')rbeta(30,.5,.5) else rnorm(30,5,.5),2))
  qp<-if(case=='bounded_beta')2 else 0
  d<-data.frame(TRIAL='T',ROW='X',N=30,MEAN=round(vapply(xx,median,0.),2),SD=NA_real_,Q1=round(vapply(xx,quantile,0.,probs=.25),qp),Q3=round(vapply(xx,quantile,0.,probs=.75),qp),ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=qp)
 }
 t<-proc.time()[3]
 v<-suppressWarnings(shiny::isolate(validateData(d)))
 if(v$FAIL) {p<-NA_real_;status<-'validation_refusal'} else {
  x<-suppressWarnings(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,1000)))
  p<-suppressWarnings(as.numeric(x$P[1]));status<-if(is.na(p)) x$P[1] else 'computed'
 }
 row<-data.frame(case=case,index=i,status=status,p=p,seconds=proc.time()[3]-t)
 write.table(row,outfile,sep=',',row.names=FALSE,col.names=!file.exists(outfile),append=file.exists(outfile))
}
dat<-read.csv(outfile)
res<-do.call(rbind,lapply(split(dat,dat$case),function(d) {
 p<-d$p[is.finite(d$p)];k<-sum(p<.05);ci<-if(length(p))binom.test(k,length(p))$conf.int else c(NA,NA)
 data.frame(case=d$case[1],trials=nrow(d),computed=length(p),refused=sum(!is.finite(d$p)),rate05=mean(p<.05),rate01=mean(p<.01),meanP=mean(p),lo05=ci[1],hi05=ci[2],seconds=sum(d$seconds))
}))
write.csv(res,file.path(outdir,'calibration-summary.csv'),row.names=FALSE);print(res)
