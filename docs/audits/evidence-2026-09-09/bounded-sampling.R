# Independent bounded-sampler audit, GPT-6, 2026-09-09 brief.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od <- 'docs/audits/evidence-2026-09-09'
sink(file.path(od,'bounded-sampling.txt'),split=TRUE)
source('tests/testthat/helper-syntheticPdf.R')
f <- file.path(od,'eight-arm-bounded.pdf');vx <- seq(300,1000,100)
cells <- c(list(list(x=72,y=80,text='Table 1. Baseline patient characteristics',adj=0)),
 rowCells(110,'',paste('Arm',LETTERS[1:8]),vx),
 rowCells(128,'',rep('(n = 5000)',8),vx),
 rowCells(150,'Age (yr)',rep('45.3 (12.1)',8),vx),
 rowCells(180,'Sex, %',rep('',8),vx),
 rowCells(205,'Male',rep('50',8),vx,labelX=82),
 rowCells(225,'Female',rep('50',8),vx,labelX=82))
grDevices::pdf(f,width=16,height=11,encoding='WinAnsi.enc')
par(mar=c(0,0,0,0),xaxs='i',yaxs='i');plot.new();plot.window(xlim=c(0,1152),ylim=c(0,792))
for(cell in cells)text(cell$x,792-cell$y,cell$text,adj=c(cell$adj,1),cex=.85)
dev.off();set.seed(42);dqset.seed(42)
r <- parseBaselineTableHeuristics(f,pctApprox=TRUE,quiet=TRUE)
print(r$data);print(r[c('approxBounded','approxStraddle')]);print(r$derivedCells)
saveRDS(r,file.path(od,'eight-arm-bounded.rds'));flush.console()
d <- r$data[r$data$ROW=='Sex, %',];stopifnot(nrow(d)==8)
selected <- as.matrix(d[,c('Male','Female')]);storage.mode(selected)<-'numeric'
alternative <- cbind(c(rep(2475,4),rep(2525,4)),c(rep(2525,4),rep(2475,4)))
# Independent sequential hypergeometric sampler of fixed margins; integer
# distance scores because every arm N is 5000. No engine/helper statistic.
reference <- function(tab,seed) {
 set.seed(seed);B<-200000;C<-sum(tab[,1]);obs<-sum((8*tab[,1]-C)^2)
 rem<-rep(C,B);z<-matrix(0,B,8)
 for(j in 1:7){z[,j]<-rhyper(B,rem,(9-j)*5000-rem,5000);rem<-rem-z[,j]}
 z[,8]<-rem;ss<-rowSums((8*z-C)^2);v<-(ss<obs)+.5*(ss==obs)
 p<-mean(v);se<-sd(v)/sqrt(B)
 list(B=B,seed=seed,midP=p,SE=se,normal95=p+c(-1,1)*1.96*se,less=sum(ss<obs),equal=sum(ss==obs))
}
for(nm in c('selected','alternative')) {
 cat(nm,'\n');tab<-get(nm);print(tab)
 print(reference(tab,if(nm=='selected')8821 else 8822))
 dd<-data.frame(TRIAL='T',ROW='Sex',N=NA_real_,MEAN=NA_real_,SD=NA_real_,Male=tab[,1],Female=tab[,2])
 set.seed(42);dqset.seed(42);v<-shiny::isolate(validateData(dd));print(v$FAIL)
 if(!v$FAIL)print(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,100000)))
 flush.console()
}
sink()
