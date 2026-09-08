# Independent statistical audit, GPT-6 (Codex), 2026-09-08.
# Synthetic inputs and independent arithmetic; no application edits.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
outdir <- 'docs/audits/evidence-2026-09-08'
sink(file.path(outdir,'probes.txt'),split=TRUE)
cat(R.version.string,'\n')
calc <- function(d,m=100000,seed=42,validate=TRUE) {
 set.seed(seed);dqset.seed(seed)
 v<-shiny::isolate(validateData(d));cat('validation failure:',v$FAIL,'\n')
 if(v$FAIL){print(v$issues);return(invisible(v))}
 x<-suppressWarnings(shiny::isolate(P_Calc('T',if(validate)v$DATA else d,v$CategoryNames,m)))
 print(x);invisible(x)
}
cat('\nZERO ROW REFUSAL\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(10,10),MEAN=0,SD=0,ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=0)
calc(d);d$MEAN<-1;calc(d)
cat('\nZERO SNAP TRANSLATION\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(10,10),MEAN=c(0,.00001),SD=.0001,ROUND_MEAN=5,ROUND_OBSERVATION=5,ROUND_DISPERSION=5)
calc(d);d$MEAN<-1e9+d$MEAN;calc(d)
cat('\nZERO SNAP UNIT SCALING\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(10,10),MEAN=c(0,.1),SD=1,ROUND_MEAN=1,ROUND_OBSERVATION=1,ROUND_DISPERSION=1)
calc(d);d$MEAN<-d$MEAN*1e-13;d$SD<-d$SD*1e-13;d[c('ROUND_MEAN','ROUND_OBSERVATION','ROUND_DISPERSION')]<-14;calc(d)
cat('\nGRID SD BOUND\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(1000,1000),MEAN=c(200,201),SD=250,ROUND_MEAN=0,ROUND_OBSERVATION=-3,ROUND_DISPERSION=0)
cat('Independent sharp minimum SD for mean 200, h1000, N1000:',1000*sqrt(1000*.2*.8/999),'\n')
calc(d)
cat('\nQUANTILE PERCENT BRACKET\n')
print(.ppCountBracket(49,0,200));cat('Those endpoints print as:',round(100*c(97,99)/200),'\n')
cat('\nBARNETT DISPERSION EXAMPLE\n')
d<-data.frame(TRIAL='T',ROW=rep(c('A','B','C'),each=2),N=100,MEAN=c(50,52,100,104,20,21),SD=10,ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=14)
a<-barnettTStats(d);print(a);print(barnettDispersion(a))
d$SD<-rep(c(2,14),3);b<-barnettTStats(d);print(b);print(barnettDispersion(b));cat('t statistics identical:',identical(a,b),'\n')
sink()
