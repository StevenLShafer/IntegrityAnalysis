# Independent audit follow-up, GPT-6, 2026-09-07; synthetic inputs only.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
outdir <- 'docs/audits/evidence-2026-09-07'
sink(file.path(outdir,'followup.txt'),split=TRUE)
calc<-function(d,m=100000,validate=TRUE) {
 set.seed(42);dqset.seed(42)
 v<-suppressWarnings(shiny::isolate(validateData(d)))
 cat('FAIL=',v$FAIL,'\n')
 if(v$FAIL) {print(v$issues);return(NULL)}
 x<-suppressWarnings(shiny::isolate(P_Calc('T',if(validate)v$DATA else d,v$CategoryNames,m)))
 print(x);invisible(x)
}
cat('CATEGORICAL COMBINATION\n')
d<-data.frame(TRIAL='T',ROW=rep(paste0('V',1:5),each=3),N=NA_real_,MEAN=NA_real_,SD=NA_real_,A=rep(c(1,1,1),5),B=rep(c(1,1,5),5))
calc(d)
cat('Exact intended trial mid-p:',.5*.7^5,'\n')
cat('SINGLE ROW LABEL COLLISION\n')
d<-data.frame(TRIAL='T',ROW='X',N=6,MEAN=c(77,78),SD=30,ROUND_MEAN=0,ROUND_OBSERVATION=0)
for(label in c('X','Summary')) {
 d$ROW<-label
 a<-suppressWarnings(shiny::isolate(.apiAnalyze(d,seed=42)))
 cat('label=',label,'ok=',a$ok,'overallP=',a$overallP,'\n');cat(a$resultsCsv,'\n')
}
cat('MIXED SD PRECISION DIRECT CALL\n')
d<-data.frame(TRIAL='T',ROW='X',N=30,MEAN=c(2.3,2.3),SD=c(1,1.1),ROUND_MEAN=1,ROUND_OBSERVATION=1,ROUND_DISPERSION=c(2,NA))
calc(d,validate=FALSE);calc(d)
cat('QUARTILE PRECISION\n')
d<-data.frame(TRIAL='T',ROW='X',N=20,MEAN=c(2.30,2.31),SD=NA_real_,Q1=1,Q3=4,ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=0)
a<-calc(d);d$ROUND_DISPERSION<-2;b<-calc(d)
cat('Quartile rounding change identical output:',identical(a,b),'\n')
cat('DISPERSION BLINDNESS\n')
d<-data.frame(TRIAL='T',ROW='X',N=100,MEAN=c(50,52),SD=10,ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=15)
a<-calc(d);d$SD<-c(0,sqrt(200));b<-calc(d)
cat('P identical:',identical(a$P,b$P),'\n')
cat('PERCENTAGE ROUNDING EXACT NULL ENUMERATION\n')
N<-5000;cnt<-0:N;mass<-dbinom(cnt,N,.5)
rec<-round(N*round(100*cnt/N)/100)
pm<-tapply(mass,rec,sum);vals<-as.numeric(names(pm));pm<-as.numeric(pm)
f<-function(a,b) {
 s<-a+b
 if(s==0||s==2*N)return(NA_real_)
 l<-min(a,b);u<-max(a,b)
 if(l==u)return(.5*dhyper(l,s,2*N-s,N))
 phyper(u-1,s,2*N-s,N)-phyper(l,s,2*N-s,N)+.5*(dhyper(l,s,2*N-s,N)+dhyper(u,s,2*N-s,N))
}
p<-outer(vals,vals,Vectorize(f));prob<-outer(pm,pm)
cat('N=',N,'false alarm <.05:',sum(prob[p<.05],na.rm=TRUE),' <.01:',sum(prob[p<.01],na.rm=TRUE),'\n')
cat('Reconstructed identical count row exact mid-p:',f(2500,2500),'\n')
calc(data.frame(TRIAL='T',ROW='Cat',N=NA_real_,MEAN=NA_real_,SD=NA_real_,A=c(2500,2500),B=c(2500,2500)))
cat('LOCKFILE VERSION COMPARISON\n')
lock<-jsonlite::fromJSON('renv.lock',simplifyVector=FALSE)$Packages
diffs<-lapply(names(lock),function(p){v<-tryCatch(as.character(packageVersion(p)),error=function(e)NA_character_);if(is.na(v)||v!=lock[[p]]$Version)data.frame(package=p,locked=lock[[p]]$Version,installed=v)})
print(do.call(rbind,diffs))
cat('TARGETED TESTS\n')
for(f in c('test-input-contract.R','test-validate-rounding.R','test-pcalc-direct.R','test-sd-rounding-draw.R','test-median-iqr.R','test-degenerate-categories.R','test-adaptive-m.R')) testthat::test_file(file.path('tests/testthat',f),reporter='summary')
sink()
