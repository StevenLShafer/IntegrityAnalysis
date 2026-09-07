# Independent synthetic audit, GPT-6, 2026-09-07. No engine edits.
suppressPackageStartupMessages({library(shiny); library(dqrng); library(foreach); library(Rfast); library(MBESS); pkgload::load_all()})
outdir <- 'docs/audits/evidence-2026-09-07'
sink(file.path(outdir, 'probes.txt'), split=TRUE)
print(R.version.string)
print(sapply(c('dqrng','Rfast','MBESS','shiny'), function(p) as.character(packageVersion(p))))
run <- function(d, cats=NULL, m=10000) {
  set.seed(42); dqset.seed(42)
  v <- suppressWarnings(shiny::isolate(validateData(d)))
  cat('validation FAIL:',v$FAIL,'\n')
  if(v$FAIL) return(v$issues)
  print(v$DATA)
  ans <- tryCatch(suppressWarnings(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,m))),error=function(e) conditionMessage(e))
  print(ans); invisible(ans)
}
cat('\nTIED CONTINUOUS ROWS\n')
for(k in c(2,3,4,5,7,10)) for(mu in c(.1,1.1,54.1)) {
 cat('k=',k,'mu=',mu,'\n')
 d<-data.frame(TRIAL='T',ROW='X',N=rep(20,k),MEAN=mu,SD=.001,ROUND_MEAN=1,ROUND_OBSERVATION=4,ROUND_DISPERSION=5)
 run(d,m=1000)
}
cat('\nEXACT 2X2 SEARCH\n')
worst<-NULL; delta<-0
for(n1 in 2:20) for(n2 in 2:20) for(c1 in seq_len(n1+n2-1)) {
 a<-seq(max(0,c1-n2), min(n1,c1)); pr<-dhyper(a,c1,n1+n2-c1,n1)
 tabs<-lapply(a,function(x) matrix(c(x,c1-x,n1-x,n2-c1+x),2))
 E<-outer(c(n1,n2),c(c1,n1+n2-c1))/(n1+n2)
 st<-vapply(tabs,function(t)sum((t-E)^2/E),0.)
 key<-((n1+n2)*a-n1*c1)^2
 for(i in seq_along(a)) {
  exact<-sum(pr[key<key[i]])+.5*sum(pr[key==key[i]])
  actual<-sum(pr[st<st[i]])+.5*sum(pr[st==st[i]])
  if(abs(actual-exact)>delta+1e-12) {delta<-abs(actual-exact);worst<-list(n1=n1,n2=n2,c1=c1,a=a[i],exact=exact,actual=actual,table=tabs[[i]],support=data.frame(a,pr,key,st=sprintf('%.17g',st)))}
 }
}
print(worst)
cat('No 2x2 discrepancy at searched margins; now 3x2\n')
for(n1 in 2:8) for(n2 in 2:8) for(n3 in 2:8) {
 ns<-c(n1,n2,n3); total<-sum(ns)
 grid<-as.matrix(expand.grid(0:n1,0:n2,0:n3)); totals<-rowSums(grid)
 for(c1 in seq_len(total-1)) {
  aa<-grid[totals==c1,,drop=FALSE]
  pr<-apply(aa,1,function(a)exp(sum(lchoose(ns,a))-lchoose(total,c1)))
  E<-outer(ns,c(c1,total-c1))/total
  st<-apply(aa,1,function(a)sum((cbind(a,ns-a)-E)^2/E))
  key<-rowSums(sweep(aa^2,2,prod(ns)/ns,'*'))
  for(i in seq_len(nrow(aa))) {
   exact<-sum(pr[key<key[i]])+.5*sum(pr[key==key[i]])
   actual<-sum(pr[st<st[i]])+.5*sum(pr[st==st[i]])
   if(abs(actual-exact)>delta+1e-12) {delta<-abs(actual-exact);worst<-list(ns=ns,c1=c1,a=aa[i,],exact=exact,actual=actual,table=cbind(aa[i,],ns-aa[i,]),support=data.frame(aa,pr,key,st=sprintf('%.17g',st)))}
  }
 }
}
print(worst)
saveRDS(worst,file.path(outdir,'categorical-worst.rds'))
if(!is.null(worst)) {
 t<-worst$table
 run(data.frame(TRIAL='T',ROW='Cat',N=NA_real_,MEAN=NA_real_,SD=NA_real_,A=t[,1],B=t[,2]),m=100000)
}
cat('\nDIRECT SD DEFAULTS\n')
print(.iaSdInterval(c(1,1.1),c(2,NA)))
cat('\nKNOWN ANSWERS\n')
testthat::test_file('tests/testthat/test-known-answer.R', reporter='summary')
sink()
