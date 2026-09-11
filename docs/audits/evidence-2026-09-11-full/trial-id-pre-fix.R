# Before-fix control: run only against the earlier audited 7fd6545 tree.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
f<-file.path(out,'fixture-trial-id-201-delta-0.5.csv')
r<-.apiReadUpload(f,basename(f));a<-isolate(.apiAnalyze(r$data,seed=42));stopifnot(a$ok)
write.csv(a$results,file.path(out,'trial-id-before-fix-results.csv'),row.names=FALSE)
write.csv(data.frame(commit='7fd654589ddbbaa5bf03e96aad2aecbca9576bb7',trials=a$trials,overallP=a$overallP,
  trial_p=paste(a$results$P[a$results$KIND %in% 'summary'],collapse=';'),
  displayed_trial_CI=paste(a$results$CI95[a$results$KIND %in% 'summary'],collapse=';'),
  actual_M=paste(unique(a$results$M[!is.na(a$results$M)]),collapse=';')),
  file.path(out,'trial-id-before-fix-summary.csv'),row.names=FALSE)
writeLines('Complete',file.path(out,'trial-id-pre-fix-complete.txt'))
