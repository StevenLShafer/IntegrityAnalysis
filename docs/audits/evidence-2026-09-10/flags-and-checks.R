# Scope D route checks and audit baseline verification, Codex 2026-09-10.
source('C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10/common.R')
source('tests/testthat/helper-syntheticJats.R');source('tests/testthat/helper-syntheticDocx.R')
unit('flags-routes',{
 rows<-list(c('N','1200','1200'),c('Age','50.1 (10.0)','50.2 (10.0)'),
  c('ASA status, %','',''),c('I','33','33'),c('II','33','33'),c('III','34','34'),
  c('Weight','70.1 (10.0)','70.2 (10.0)'),c('NYHA class, %','',''),
  c('I','33.3','33.3'),c('II','33.3','33.3'),c('III','33.4','33.4'))
 h<-c('Characteristic','Control','Treatment')
 jf<-file.path(od,'flags.xml');makeJatsArticle(jf,list(list(caption='Baseline characteristics',rows=c(list(h),rows),foot='Values are mean (SD) or percentages.')))
 df<-file.path(od,'flags.docx');makeTableDocx(df,h,do.call(rbind,rows),caption='Table 1. Baseline characteristics',footnote='Values are mean (SD) or percentages.')
 for(ext in c('xml','docx')) {
  reader<-if(ext=='xml')parseBaselineTableJats else parseBaselineTableDocx
  r<-reader(file.path(od,paste0('flags.',ext)),trial='Audit',quiet=TRUE,pctApprox=TRUE)
  cat(ext,'\n');print(r$data);print(r[c('approxCounts','approxStraddle','approxUnresolved')]);print(reviewFlags(r));print(r$derivedCells)
  a<-.apiAnalyze(r$data,seed=42);print(a)
  saveRDS(list(parsed=r,analysis=a),file.path(od,paste0('flags-',ext,'.rds')))
 }
})
unit('baseline-checks',{
 for(f in c('test-audit-2026-09-09-f6.R','test-failsafe-table.R','test-text-precision.R')) {
  cat('FILE',f,'\n');x<-testthat::test_file(file.path('tests/testthat',f),reporter='summary');saveRDS(x,file.path(od,paste0(f,'.results.rds')))
 }
 source('tools/securityCheck.R')
})
unit('version-audit',{
 lock<-jsonlite::fromJSON('renv.lock',simplifyVector=FALSE)$Packages
 rows<-lapply(names(lock),function(p){a<-tryCatch(as.character(packageVersion(p)),error=function(e)NA_character_);data.frame(package=p,installed=a,locked=lock[[p]]$Version,matches=if(is.na(a))NA else package_version(a)==package_version(lock[[p]]$Version))})
 z<-do.call(rbind,rows);write.csv(z,file.path(od,'versions.csv'),row.names=FALSE)
 print(z[is.na(z$matches)|!z$matches,]);cat('Absent packages are outside copied runtime closure; no loaded version differs if all nonmissing matches are TRUE.\n')
 print(warnings())
})
