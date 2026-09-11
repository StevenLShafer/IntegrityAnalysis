# Codex, 2026-09-11. Same two trials with full IDs in a template, plus
# independent normal quadrature for the documented across-trial combination.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
prefix<-substr(paste(rep('Synthetic baseline comparison ',20),collapse=''),1,200)
ids<-paste0(prefix,c('A','B'))
d<-data.frame(TRIAL=rep(ids,each=2),ROW='Age',N=30,MEAN=rep(c(50,50.5),2),SD=10,
  ROUND_MEAN=1,ROUND_DISPERSION=1,ROUND_OBSERVATION=1)
f<-file.path(out,'fixture-trial-id-template-201.csv');write.csv(d,f,row.names=FALSE)
r<-.apiReadUpload(f,basename(f));a<-isolate(.apiAnalyze(r$data,seed=42));stopifnot(a$ok,a$trials==2)
write.csv(a$results,file.path(out,'result-trial-id-template-201.csv'),row.names=FALSE)
ps<-as.numeric(a$results$P[a$results$KIND %in% 'summary'])
cdf<-function(z)integrate(function(x)exp(-x*x/2)/sqrt(2*pi),-Inf,z,rel.tol=1e-12)$value
quant<-function(p)uniroot(function(z)cdf(z)-p,c(-10,10),tol=1e-11)$root
ref<-cdf(sum(vapply(ps,quant,numeric(1)))/sqrt(length(ps)))
write.csv(data.frame(trials=a$trials,overallP=a$overallP,quadrature=ref,
  trial_p=paste(ps,collapse=';'),displayed_trial_CI=paste(a$results$CI95[a$results$KIND %in% 'summary'],collapse=';'),
  actual_M=paste(unique(a$results$M[!is.na(a$results$M)]),collapse=';')),
  file.path(out,'trial-id-reference.csv'),row.names=FALSE)
writeLines('Complete',file.path(out,'trial-id-reference-complete.txt'))
