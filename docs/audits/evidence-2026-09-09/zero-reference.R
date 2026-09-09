# Reference simulation compares integer sample totals, never a floating SSE.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od<-'docs/audits/evidence-2026-09-09';sink(file.path(od,'zero-reference.txt'),split=TRUE)
set.seed(19371);B<-1000000;eq<-0;lost<-0;N<-30;mu<-2.3;grid<-1e-14
raw<-c(rep(3,9),rep(6,8),rep(-2,8),rep(2,5))
print(list(honestGridSample=raw,mean=mean(raw),sd=sd(raw),printedSD=round(sd(raw),3)))
for(chunk in 1:20) {
 b<-B/20;sd1<-runif(b,3.0065,3.0075);sd2<-runif(b,3.0065,3.0075)
 sig<-sqrt(58*(sd1^2+sd2^2)/2/rchisq(b,58));location<-rnorm(b,mu,sig/sqrt(N))
 sums<-sapply(1:2,function(j)rowSums(round(matrix(rnorm(b*N),nrow=b)*sig+location)))
 tie<-sums[,1]==sums[,2];eq<-eq+sum(tie)
 # Diagnose the engine's centering on the same independently drawn samples.
 means<-round(sums/N,14);dd<-means-mu;center<-drop(dd%*%rep(N,2))/(2*N)
 s<-rowSums((dd-center)^2);lost<-lost+sum(tie&s>1e-12*grid^2)
}
p<-eq/(2*B);se<-sqrt((.25*eq/B-p^2)/B)
print(list(B=B,seed=19371,exactIntegerTies=eq,referenceMidP=p,SE=se,normal95=p+c(-1,1)*1.96*se,lostTies=lost,
  midPWithEngineSnap=(eq-lost)/(2*B)))
for(dec in c(6,14)) {
 d<-data.frame(TRIAL='T',ROW='X',N=rep(30,2),MEAN=2.3,SD=3.007,
  ROUND_MEAN=dec,ROUND_OBSERVATION=0,ROUND_DISPERSION=3)
 set.seed(42);dqset.seed(42);v<-shiny::isolate(validateData(d));cat('Precision',dec,'\n')
 print(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,100000)))
}
# Verify the previous audit's units/origin fixes on their original inputs.
for(kind in c('original','scaled','translated')) {
 d<-data.frame(TRIAL='T',ROW='X',N=c(10,10),MEAN=c(0,.1),SD=1,
  ROUND_MEAN=1,ROUND_OBSERVATION=1,ROUND_DISPERSION=1)
 if(kind=='scaled'){d$MEAN<-d$MEAN*1e-13;d$SD<-d$SD*1e-13;d[c('ROUND_MEAN','ROUND_OBSERVATION','ROUND_DISPERSION')]<-14}
 if(kind=='translated')d$MEAN<-d$MEAN+1000
 set.seed(42);dqset.seed(42);v<-shiny::isolate(validateData(d));cat(kind,'\n');print(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,100000)))
}
sink()
