# Audit completion: request-handler routes, deterministic oracle substitution,
# and straddle propagation. No source edits to the engine. Codex 2026-09-10.
source('C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10/common.R')
source('tests/testthat/helper-syntheticJats.R');source('tests/testthat/helper-syntheticDocx.R')
unit('oracle-through-selector',{
 Sys.setenv(AUDIT_ORACLE_ONLY='1');source(file.path(od,'rank-search.R'))
 for(id in c(183,153)) {
  z<-readRDS(file.path(od,sprintf('rank-%03d.rds',id)));Ns<-z$N;pct<-matrix(z$pct,2,byrow=TRUE)
  lo<-pmax(ceiling((pct-.5)*Ns/100-1e-8),0);hi<-floor((pct+.5)*Ns/100+1e-8)
  e<-new.env(parent=environment(.ppFailsafeTableFill))
  e$.ppTableP<-function(tab,reps)exact2(tab[1,1],tab[1,2],tab[2,1],tab[2,2])
  f<-.ppFailsafeTableFill;environment(f)<-e
  a<-f(lo,hi,matrix(NA_integer_,2,2),Ns,FALSE)
  e$.ppTableRankMax<-1e9
  b<-f(lo,hi,matrix(NA_integer_,2,2),Ns,FALSE)
  cat('CASE',id,'ranked exact / exhaustive exact\n');print(a);print(b)
  stopifnot(abs(a$pBest-z$summary$best50)<1e-12,abs(b$pBest-z$summary$best)<1e-12)
  saveRDS(list(ranked=a,exhaustive=b),file.path(od,paste0('oracle-selector-',id,'.rds')))
 }
})
unit('straddle-routes',{
 h<-c('Characteristic','Control','Treatment')
 rows<-list(c('N','200','200'),c('Age','50.1 (10.0)','50.2 (10.0)'),c('ASA status, %','',''),c('I','33','33'),c('II','33','33'),c('III','34','34'))
 jf<-file.path(od,'straddle.xml');makeJatsArticle(jf,list(list(caption='Baseline characteristics',rows=c(list(h),rows),foot='Values are mean (SD) or percentages.')))
 df<-file.path(od,'straddle.docx');makeTableDocx(df,h,do.call(rbind,rows),caption='Table 1. Baseline characteristics',footnote='Values are mean (SD) or percentages.')
 for(ext in c('xml','docx')) {
  reader<-if(ext=='xml')parseBaselineTableJats else parseBaselineTableDocx
  r<-reader(file.path(od,paste0('straddle.',ext)),trial='Audit',quiet=TRUE,pctApprox=TRUE)
  cat(ext,'\n');print(r[c('approxCounts','approxStraddle','approxUnresolved')]);print(reviewFlags(r))
  saveRDS(r,file.path(od,paste0('straddle-',ext,'.rds')))
 }
})
unit('document-api-handlers',{
 ast<-parse('inst/api/plumber.R')
 funs<-lapply(Filter(function(x)is.call(x)&&identical(x[[1]],as.name('function')),as.list(ast)),eval)
 upload<-Filter(function(f)'file'%in%names(formals(f)),funs)
 request<-function(f,path,seed=NULL) {
  req<-new.env();res<-new.env();file<-setNames(list(readBin(path,'raw',n=file.info(path)$size)),basename(path))
  if(is.null(seed))f(req,res,file)else f(req,res,file,seed=seed)
 }
 for(stem in c('flags','straddle','page-183')) {
  f<-file.path(od,paste0(stem,'.xml'));a<-request(upload[[1]],f);b<-request(upload[[2]],f,42)
  cat(stem,'parse\n');print(a);cat('direct analysis\n');print(b)
  if(isTRUE(a$ok)) {
   tf<-file.path(od,paste0('parsed-',stem,'.csv'));writeLines(a$templateCsv,tf,useBytes=TRUE)
   c<-request(upload[[2]],tf,42);cat('roundtrip analysis\n');print(c)
  } else c<-NULL
  saveRDS(list(parse=a,analyze=b,roundtrip=c),file.path(od,paste0('document-handler-',stem,'.rds')))
 }
})
