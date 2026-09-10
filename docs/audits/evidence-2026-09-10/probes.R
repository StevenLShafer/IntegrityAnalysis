# Audit integration probes; source snapshot is immutable ae37f0e.
source('C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10/common.R')
unit('metadata',{
 cat('Audited commit: ae37f0ee06d017d742049b7ab56ba79f2e39c99d\n')
 print(sessionInfo());print(.libPaths())
 lock<-jsonlite::fromJSON('renv.lock',simplifyVector=FALSE)$Packages
 mism<-lapply(names(lock),function(p){v<-tryCatch(as.character(packageVersion(p)),error=function(e)'not in runtime closure');if(v!=lock[[p]]$Version)c(package=p,installed=v,locked=lock[[p]]$Version)})
 print(Filter(Negate(is.null),mism))
})
source('tests/testthat/helper-syntheticJats.R')
unit('rank-integration',{
 for(id in c(183,147,153,181)) {
  ref<-readRDS(file.path(od,sprintf('rank-%03d.rds',id)))
  Ns<-ref$N;pct<-matrix(ref$pct,2,byrow=TRUE)
  lo<-ceiling((pct-.5)*Ns/100-1e-8);lo[lo<0]<-0
  hi<-floor((pct+.5)*Ns/100+1e-8)
  cnt<-matrix(NA_integer_,2,2)
  z<-.ppFailsafeTableFill(lo,hi,cnt,Ns,FALSE)
  cat('\nCASE',id,'\n');print(ref$summary,digits=13);print(z)
  cat('Exact best and best of first 50:\n');print(ref$hi[c(which.max(ref$hi$p),which.max(head(ref$hi$p,50))),],digits=13)
  cat('Exact worst and worst of first 50:\n');print(ref$lo[c(which.min(ref$lo$p),which.min(head(ref$lo$p,50))),],digits=13)
  f<-file.path(od,paste0('rank-case-',id,'.xml'))
  makeJatsArticle(f,list(list(caption='Baseline characteristics',rows=list(
   c('',paste0('Control (n = ',Ns[1],')'),paste0('Treatment (n = ',Ns[2],')')),
   c('Age, mean (SD)','50.1 (10.0)','50.2 (10.0)'),
   c('Category, %','',''),c('Level A',pct[1,1],pct[2,1]),c('Level B',pct[1,2],pct[2,2])))))
  parsed<-parseBaselineTableJats(f,trial='Audit',quiet=TRUE,pctApprox=TRUE)
  print(parsed$data);print(reviewFlags(parsed));print(parsed$derivedCells)
  print(run(catframe(z$counts)))
  best<-ref$hi[which.max(ref$hi$p),];worst<-ref$lo[which.min(ref$lo$p),]
  cat('Exact-max candidate through engine:\n');run(catframe(matrix(as.numeric(best[1,1:4]),2,byrow=TRUE)))
  cat('Exact-min candidate through engine:\n');run(catframe(matrix(as.numeric(worst[1,1:4]),2,byrow=TRUE)))
  saveRDS(list(ref=ref,fill=z,parsed=parsed),file.path(od,paste0('integration-',id,'.rds')))
 }
})
unit('zero-snap',{
 # Functional copy overriding ONLY zero snapping, not observation generation.
 ee<-new.env(parent=environment(P_Calc));ee$.iaZeroSnapTol<-function(...)0
 nosnap<-P_Calc;environment(nosnap)<-ee
 cases<-list(
  continuous=data.frame(TRIAL='Audit',ROW='X',N=c(30,30),MEAN=2.3,SD=3.007,ROUND_MEAN=14,ROUND_OBSERVATION=0,ROUND_DISPERSION=3),
  median=data.frame(TRIAL='Audit',ROW='X',N=c(31,31),MEAN=2.5,SD=NA_real_,Q1=.4,Q3=4.6,ROUND_MEAN=14,ROUND_OBSERVATION=1,ROUND_DISPERSION=1),
  unequal=data.frame(TRIAL='Audit',ROW='X',N=c(100,101,177),MEAN=c(.12,.13,.11),SD=3,ROUND_MEAN=2,ROUND_OBSERVATION=0,ROUND_DISPERSION=2))
 for(nm in names(cases)) {
  d<-cases[[nm]];v<-shiny::isolate(validateData(d));cat(nm,'\n')
  set.seed(42);dqset.seed(42);a<-shiny::isolate(P_Calc('Audit',v$DATA,v$CategoryNames,100000))
  set.seed(42);dqset.seed(42);b<-shiny::isolate(nosnap('Audit',v$DATA,v$CategoryNames,100000))
  print(a);cat('bit-identical without snap:',identical(a,b),'\n')
 }
 for(delta in c(1e3,1e5,1e7)) {
  # The observed range term in the tolerance can swamp the simulated range.
  a<-data.frame(TRIAL='Audit',ROW='Very different',N=c(100,100),MEAN=c(0,delta),SD=1,ROUND_MEAN=4,ROUND_OBSERVATION=4,ROUND_DISPERSION=3)
  b<-data.frame(TRIAL='Audit',ROW='Very similar',N=c(100,100),MEAN=0,SD=1,ROUND_MEAN=4,ROUND_OBSERVATION=4,ROUND_DISPERSION=3)
  d<-rbind(a,b);v<-shiny::isolate(validateData(d));cat('delta',delta,'\n')
  set.seed(42);dqset.seed(42);x<-shiny::isolate(P_Calc('Audit',v$DATA,v$CategoryNames,100000))
  set.seed(42);dqset.seed(42);y<-shiny::isolate(nosnap('Audit',v$DATA,v$CategoryNames,100000))
  print(x);cat('No-snap diagnostic:\n');print(y)
  saveRDS(list(data=d,production=x,nosnap=y),file.path(od,paste0('snap-',delta,'.rds')))
 }
})
unit('precision',{
 base<-data.frame(TRIAL='Audit',ROW='X',N=c(100,100),MEAN=c('50.000','50.000'),SD=c('3.00','3.00'),ROUND_MEAN=c(NA,2),ROUND_OBSERVATION=0,ROUND_DISPERSION=c(NA,1))
 for(kind in c('mixed','lowercase','scientific','coarse')) {
  d<-base
  if(kind=='lowercase')names(d)<-tolower(names(d))
  if(kind=='scientific'){d$MEAN<-'5.0000e1';d$SD<-'3.00e0'}
  if(kind=='coarse'){d$MEAN<-'50';d$SD<-'30';d$ROUND_MEAN<-c(-1,NA);d$ROUND_DISPERSION<-0;d$N<-100}
  f<-file.path(od,paste0('precision-',kind,'.csv'));write.csv(d,f,row.names=FALSE,na='')
  rd<-.apiReadUpload(f,basename(f));cat('\n',kind,'read',rd$ok,'\n');print(rd$data)
  a<-.apiAnalyze(rd$data,seed=42);print(a)
  tf<-file.path(od,paste0('roundtrip-',kind,'.csv'));writeLines(a$templateCsv,tf,useBytes=TRUE)
  r2<-.apiReadUpload(tf,basename(tf));b<-.apiAnalyze(r2$data,seed=42)
  cat('second analysis identical:',identical(a,b),'\n');print(b)
  saveRDS(list(first=a,second=b),file.path(od,paste0('precision-',kind,'.rds')))
 }
})
unit('gates-and-chunks',{
 for(arms in 4:5) {
  lo<-matrix(19L,arms,25);hi<-lo;hi[1,1]<-20L
  r<-.ppFailsafeTableFill(lo,hi,matrix(NA_integer_,arms,25),rep(500,arms),FALSE)
  cat('arms',arms,'\n');print(r[c('resolved','reason','nTables','nNulls','nScored')])
 }
 for(tab in list(rbind(c(1,1),c(1,5),c(2,4)),matrix(c(9,11,10,10,8,12,10,10,9,11,12,8),3))) {
  set.seed(761);one<-r2dtable(1234,rowSums(tab),colSums(tab));s1<-.Random.seed
  set.seed(761);chunks<-c(r2dtable(17,rowSums(tab),colSums(tab)),r2dtable(503,rowSums(tab),colSums(tab)),r2dtable(714,rowSums(tab),colSums(tab)))
  cat('chunked tables and RNG state identical:',identical(one,chunks),identical(s1,.Random.seed),'\n')
 }
 # At the arm ceiling honest exhaustive percentages can overstate the upper
 # envelope even though feasible candidates total N; the nonpartition gate declines.
 lo<-matrix(c(1248,2098,1648),2,3,byrow=TRUE);hi<-lo+4L
 cat('N=5000, one-decimal percentages 25.0/42.0/33.0; upper totals',rowSums(hi),'\n')
 r<-.ppFailsafeTableFill(lo,hi,matrix(NA_integer_,2,3),c(5000,5000),FALSE);print(r)
})
