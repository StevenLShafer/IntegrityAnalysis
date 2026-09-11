# Focused replay to record the three warnings emitted by the raw-gzip fixture.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
env<-new.env(parent=globalenv())
for(f in list.files(file.path(src,'tests/testthat'),'^helper.*[.]R$',full.names=TRUE))sys.source(f,env)
ans<-testthat::test_file(file.path(src,'tests/testthat/test-screen-2026-09-10-2100-raw.R'),env=env,reporter='silent')
rows<-list()
for(a in ans)for(r in a$results)if(inherits(r,'expectation_warning'))
  rows[[length(rows)+1]]<-data.frame(test=a$test,message=clean_message(conditionMessage(r)))
write.csv(do.call(rbind,rows),file.path(out,'warning-details.csv'),row.names=FALSE)
