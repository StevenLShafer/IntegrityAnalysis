# Independent statistical audit of 9d5ef88, GPT-6 (Codex), 2026-09-09 brief.
# Synthetic fixtures only. Each unit persists output; application code unchanged.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od<-'docs/audits/evidence-2026-09-09'
dir.create(od,recursive=TRUE,showWarnings=FALSE)
unit<-function(name,expr) {
 if(length(commandArgs(TRUE)) && !name %in% commandArgs(TRUE))return(invisible(NULL))
 sink(file.path(od,paste0(name,'.txt')),split=TRUE)
 cat(name,'started',format(Sys.time()),'\n');t<-proc.time()[3]
 tryCatch(force(expr),error=function(e)cat('ERROR:',conditionMessage(e),'\n'))
 cat('elapsed',proc.time()[3]-t,'seconds\n');sink()
}
run<-function(d,m=100000,seed=42) {
 set.seed(seed);dqset.seed(seed);v<-shiny::isolate(validateData(d))
 cat('validation failed:',v$FAIL,'\n');if(v$FAIL){print(v$issues);return(v)}
 x<-shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,m));print(x);invisible(x)
}
unit('zero-floor',{
 for(nn in list(c(100,100),c(100,200),c(100,300))) for(dec in c(6,14)) {
  d<-data.frame(TRIAL='T',ROW='X',N=nn,MEAN=0,SD=3,
    ROUND_MEAN=dec,ROUND_OBSERVATION=0,ROUND_DISPERSION=3)
  cat('N',nn,'mean precision',dec,'\n');run(d)
 }
})
unit('selector-ties',{
 tab<-rbind(c(1,1),c(1,1),c(1,5))
 # Enumerate the first column with fixed row totals 2,2,6 and total 3.
 # Integer-scaled Pearson scores avoid floating-point equality entirely.
 z<-expand.grid(x1=0:2,x2=0:2);z$x3<-3-z$x1-z$x2
 z<-as.matrix(z[z$x3>=0 & z$x3<=6,]);rr<-c(2,2,6)
 sc<-rowSums(sweep(sweep(10*z,2,3*rr,'-')^2,2,24/rr,'*'))
 obs<-sum((10*tab[,1]-3*rr)^2*(24/rr))
 pr<-exp(rowSums(sapply(1:3,function(j)lchoose(rr[j],z[,j])))-lchoose(10,3))
 cat('Independent exact mid-p:',sum(pr[sc<obs])+.5*sum(pr[sc==obs]),'\n')
 set.seed(42);cat('Selector:\n');print(.ppTableP(tab,100000))
 d<-data.frame(TRIAL='T',ROW='X',N=NA_real_,MEAN=NA_real_,SD=NA_real_,A=tab[,1],B=tab[,2]);run(d)
})
unit('text-roundtrip',{
 d<-data.frame(TRIAL='T',ROW='X',N=c(100,100),MEAN=c('50.000','50.000'),SD=c('3.00','3.00'),ROUND_OBSERVATION=0)
 run(d)
 cf<-file.path(od,'text-precision.csv');write.csv(d,cf,row.names=FALSE,na='')
 xf<-file.path(od,'text-precision.xlsx');openxlsx::write.xlsx(d,xf,keepNA=FALSE)
 for(f in c(cf,xf)) {
  r<-.apiReadUpload(f,basename(f));print(r[c('ok','engine')]);print(r$data);r$data$TRIAL<-'T';run(r$data)
 }
 d<-data.frame(TRIAL='T',ROW='X',N=c(100,100),MEAN=50,SD=3,ROUND_MEAN=-1,ROUND_OBSERVATION=0,ROUND_DISPERSION=0)
 cat('Negative precision after new validator:\n');run(d)
 cat('Helper text spellings:\n');print(sapply(c('50.000','5.000e1','0.05000e3','1.230e-2'),.ppDecimals))
})
unit('per-arm-cap',{
 source('tests/testthat/helper-syntheticPdf.R')
 f<-file.path(od,'five-category-cap.pdf');vx<-c(300,420)
 cells<-c(list(list(x=72,y=80,text='Table 1. Baseline patient characteristics',adj=0)),
  rowCells(110,'',c('Control','Treatment'),vx),rowCells(128,'',c('(n = 4000)','(n = 4000)'),vx),
  rowCells(150,'Age (yr)',c('45.3 (12.1)','46.1 (11.8)'),vx),
  rowCells(180,'Race, %',c('',''),vx))
 for(j in 1:5)cells<-c(cells,rowCells(185+20*j,c('Asian','White','Black','Hispanic','Other')[j],c('20','20'),vx,labelX=82))
 makeTablePdf(f,cells);set.seed(42)
 r<-parseBaselineTableHeuristics(f,pctApprox=TRUE,quiet=TRUE);print(r$data)
 print(r[c('approxCounts','approxBounded','approxStraddle')]);print(r$derivedCells)
 saveRDS(r,file.path(od,'five-category-cap.rds'))
 r$data$TRIAL<-'T';run(r$data[r$data$ROW=='Race, %',])
 # A feasible table attaining far greater heterogeneity: all percentages print 20.
 e<-data.frame(TRIAL='T',ROW='Category, %',N=NA_real_,MEAN=NA_real_,SD=NA_real_)
 e<-e[rep(1,2),];for(j in 1:5)e[[paste0('Level ',LETTERS[j])]]<-c(800+c(20,20,-20,-20,0)[j],800-c(20,20,-20,-20,0)[j])
 print(e);run(e)
})
unit('bounded-dimensions',{
 # Stop BEFORE expand.grid allocates, preserving all preceding selector logic.
 # This is an instrumented copy, not a mutation of the package.
 f<-.ppFailsafeTableFill;ee<-new.env(parent=environment(f));environment(f)<-ee
 ee$expand.grid<-function(...) {
  sizes<-vapply(list(...)[[1]],length,integer(1))
  cat('Selected arm-vector counts:',sizes,'; proposed tables:',prod(as.numeric(sizes)),'\n')
  stop('audit allocation intercept')
 }
 for(a in c(18,32)) {
  cat('Arms',a,'\n');set.seed(42)
  tryCatch(f(matrix(99L,a,2),matrix(101L,a,2),matrix(NA_integer_,a,2),rep(200,a)),error=function(e)cat(conditionMessage(e),'\n'))
 }
})
unit('metadata',{cat('Execution date',format(Sys.time()),'\n');print(sessionInfo())})
