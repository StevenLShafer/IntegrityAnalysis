# Independent audit follow-up, GPT-6 (Codex), 2026-09-08; synthetic only.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
outdir<-'docs/audits/evidence-2026-09-08'
sink(file.path(outdir,'followup.txt'),split=TRUE)
calc<-function(d,cats=NULL,m=100000) {
 set.seed(42);dqset.seed(42);v<-shiny::isolate(validateData(d));cat('FAIL',v$FAIL,'\n')
 if(v$FAIL){print(v$issues);return(v)}
 x<-shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,m));print(x);invisible(x)
}
cat('INDEPENDENT COUNT ANSWERS\n')
for(count in c(1,5)) {
 d<-data.frame(TRIAL='T',ROW='X',N=NA_real_,MEAN=NA_real_,SD=NA_real_,Event=c(0,count),Other=c(101,1001-count))
 # All events in the larger arm minimize Pearson for these margins.
 cat('Count',count,'independent p',.5*exp(lchoose(1001,count)-lchoose(1102,count)),'\n')
 calc(d)
}
cat('INDEPENDENT NORMAL INTEGRATION AND SIMULATION\n')
# Fine printing reference: conditional normal contrast with pooled sample
# SD uncertainty, integrated over both printed SD intervals by quadrature.
nodes<-seq(.95,1.05,length.out=301)
vv<-outer(nodes^2,nodes^2,'+')/2
pref<-mean(2*pt(.1/sqrt(vv*.2),df=18)-1)
cat('Unrounded t-mixture reference, Riemann quadrature:',pref,'\n')
# Full rounded model reference, independent implementation. Two samples
# per replicate; print individual observations and the mean to one decimal.
set.seed(19371);B<-1000000L;less<-equal<-0L
for(chunk in 1:20) {
 k<-B/20;v<-(runif(k,.95,1.05)^2+runif(k,.95,1.05)^2)/2
 sigma<-sqrt(18*v/rchisq(k,18));mu<-.05+sigma*rnorm(k)/sqrt(10)
 arms<-lapply(1:2,function(j){z<-matrix(rnorm(k*10),nrow=k);round(rowMeans(round(z*sigma+mu,1)),1)})
 # Printed means are integer tenths. Compare their integer difference,
 # never a small floating-point sum of squares or the engine's tie helper.
 delta<-abs(round(10*arms[[1]])-round(10*arms[[2]]))
 less<-less+sum(delta<1);equal<-equal+sum(delta==1)
}
cat('Rounded-model reference:',(less+equal/2)/B,'counts',less,equal,'B',B,'\n')
cat('TYPE-8 QUARTILES OF AN HONEST INTEGER SAMPLE\n')
print(quantile(0:6,c(.25,.5,.75),type=8));print(quantile(0:6,c(.25,.5,.75),type=7))
cat('TIE GROUP CONSISTENCY\n')
s<-c(1,1+9e-11,1+18e-11);print(.iaTieRank(s));print(.iaTieCounts(s,s[1]));print((.iaTieRank(s)[1]-.5)/3)
cat('MULTICATEGORY PERCENTAGE FIXTURE\n')
source('tests/testthat/helper-syntheticPdf.R')
f<-file.path(outdir,'synthetic-three-category.pdf');vx<-c(300,420)
cells<-c(list(list(x=72,y=80,text='Table 1. Baseline patient characteristics',adj=0)),
 rowCells(110,'',c('Control','Treatment'),vx),rowCells(128,'',c('(n = 200)','(n = 200)'),vx),
 rowCells(150,'Age (yr)',c('45.3 +/- 12.1','46.1 +/- 11.8'),vx),
 rowCells(180,'Race, %',c('',''),vx),rowCells(200,'Asian',c('34','34'),vx,labelX=82),
 rowCells(220,'White',c('32','32'),vx,labelX=82),rowCells(240,'Black',c('34','34'),vx,labelX=82))
makeTablePdf(f,cells)
r<-parseBaselineTableHeuristics(f,pctApprox=TRUE,quiet=TRUE)
print(r$data);print(r$arms);print(r$derivedCells)
saveRDS(r,file.path(outdir,'synthetic-three-category.rds'))
if(all(c('Asian','White','Black')%in%names(r$data))) {
 rr<-r$data[r$data$ROW=='Race, %',];print(rowSums(rr[c('Asian','White','Black')]))
 rr$TRIAL<-'T'
 calc(rr)
 # A jointly admissible original table, with N=200 in both arms.
 rr$Asian<-c(69,67);rr$White<-c(63,65);rr$Black<-c(68,68)
 cat('Feasible original counts, all percentages round to the same page:\n')
 print(rr);print(round(100*as.matrix(rr[c('Asian','White','Black')])/200))
 calc(rr)
}
cat('REFUSAL NOTE IN RESULTS WORKBOOK\n')
d<-data.frame(TRIAL='T',ROW=c('Zero','Zero','Other','Other'),N=10,MEAN=c(0,0,1,1.1),SD=c(0,0,1,1),ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=0)
v<-shiny::isolate(validateData(d));set.seed(42);dqset.seed(42)
x<-shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,1000));print(x[x$KIND=='summary'&!is.na(x$KIND),])
wf<-file.path(outdir,'synthetic-partial-results.xlsx');writeResultsWorkbook(x,v$DATA,v$CategoryNames,wf)
print(openxlsx::read.xlsx(wf,sheet='Summary'))
cat('SELECTED CURRENT TESTS\n')
for(f in c('test-known-answer.R','test-tie-criterion.R','test-numeric-resolution.R','test-quartile-precision.R','test-quartile-draw.R','test-pcalc-direct.R','test-pct-failsafe.R')) testthat::test_file(file.path('tests/testthat',f),reporter='summary')
sink()
