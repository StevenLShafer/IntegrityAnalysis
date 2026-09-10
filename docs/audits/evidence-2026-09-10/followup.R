# Follow-up probes of actual parser and API handler paths, Codex 2026-09-10.
source('C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10/common.R')
source('tests/testthat/helper-syntheticJats.R');source('tests/testthat/helper-syntheticDocx.R')
unit('three-row-snap',{
 e<-new.env(parent=environment(P_Calc));e$.iaZeroSnapTol<-function(...)0
 noSnap<-P_Calc;environment(noSnap)<-e
 for(delta in c(1000,1e7)) {
  d<-data.frame(TRIAL='Audit',ROW=rep(c('X','Y','Z'),each=2),N=100,MEAN=c(0,delta,0,0,0,0),SD=1,
   ROUND_MEAN=4,ROUND_OBSERVATION=4,ROUND_DISPERSION=3)
  write.csv(d,file.path(od,paste0('three-row-',delta,'.csv')),row.names=FALSE)
  v<-shiny::isolate(validateData(d));cat('delta',delta,'\n')
  set.seed(42);dqset.seed(42);a<-shiny::isolate(P_Calc('Audit',v$DATA,v$CategoryNames,100000));print(a)
  set.seed(42);dqset.seed(42);b<-shiny::isolate(noSnap('Audit',v$DATA,v$CategoryNames,100000));print(b)
  saveRDS(list(data=d,production=a,nosnap=b),file.path(od,paste0('three-row-',delta,'.rds')))
 }
})
unit('parser-cases',{
 for(id in c(183,147,153)) {
  ref<-readRDS(file.path(od,sprintf('rank-%03d.rds',id)));Ns<-ref$N;pct<-matrix(ref$pct,2,byrow=TRUE)
  rows<-list(c('N',Ns[1],Ns[2]),c('Age','50.1 (10.0)','50.2 (10.0)'),c('Race, %','',''),c('White',pct[1,1],pct[2,1]),c('Black',pct[1,2],pct[2,2]))
  headers<-c('Characteristic','Control','Treatment')
  jf<-file.path(od,paste0('page-',id,'.xml'));makeJatsArticle(jf,list(list(caption='Baseline characteristics',rows=c(list(headers),rows),foot='Values are mean (SD) or percentages. Other race categories omitted.')))
  j<-parseBaselineTableJats(jf,trial='Audit',quiet=TRUE,pctApprox=TRUE)
  df<-file.path(od,paste0('page-',id,'.docx'));makeTableDocx(df,headers,do.call(rbind,rows),caption='Table 1. Baseline characteristics',footnote='Values are mean (SD) or percentages. Other race categories omitted.')
  w<-parseBaselineTableDocx(df,trial='Audit',quiet=TRUE,pctApprox=TRUE)
  cat('CASE',id,'JATS\n');print(j$data);print(reviewFlags(j));print(j$derivedCells)
  cat('DOCX\n');print(w$data);print(reviewFlags(w))
  if(any(grepl('Race',j$data$ROW)))run(j$data[grepl('Race',j$data$ROW),])
  saveRDS(list(jats=j,docx=w),file.path(od,paste0('page-',id,'.rds')))
 }
})
unit('actual-api-handlers',{
 # Evaluate ONLY the endpoint function expressions from the audited file.
 # HTTP server, auth, and multipart decoding are not exercised here.
 ast<-parse('inst/api/plumber.R')
 funs<-lapply(Filter(function(x)is.call(x)&&identical(x[[1]],as.name('function')),as.list(ast)),eval)
 upload<-Filter(function(f)'file'%in%names(formals(f)),funs)
 parseHandler<-upload[[1]];analyzeHandler<-upload[[2]]
 request<-function(f,path,seed=NULL) {
  req<-new.env();res<-new.env();file<-setNames(list(readBin(path,'raw',n=file.info(path)$size)),basename(path))
  if(is.null(seed))f(req,res,file)else f(req,res,file,seed=seed)
 }
 for(kind in c('mixed','lowercase','scientific','coarse')) {
  f<-file.path(od,paste0('precision-',kind,'.csv'))
  p<-request(parseHandler,f);cat('\nPARSE',kind,'\n');print(p)
  tf<-file.path(od,paste0('handler-roundtrip-',kind,'.csv'));writeLines(p$templateCsv,tf,useBytes=TRUE)
  a<-request(analyzeHandler,f,42);b<-request(analyzeHandler,tf,42)
  cat('direct analyze\n');print(a);cat('parse -> templateCsv -> analyze\n');print(b)
  saveRDS(list(parse=p,direct=a,roundtrip=b),file.path(od,paste0('handler-',kind,'.rds')))
 }
})
