# Independent exact-null invariance: relabeling a binary level leaves its law unchanged.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
make <- function(J, bad, flipped = integer()) {
  d <- data.frame(TRIAL='T', ROW=rep(sprintf('V%02d',seq_len(J)),each=2),
                  N=NA_real_,MEAN=NA_real_,SD=NA_real_,YES=1,NO=99)
  ii <- (bad-1)*2+1:2; d$YES[ii]<-c(0,2);d$NO[ii]<-c(100,98)
  for(j in flipped){ii<-(j-1)*2+1:2;old<-d$YES[ii];d$YES[ii]<-d$NO[ii];d$NO[ii]<-old}
  d
}
spec <- list(list(J=9,bad=3,flip=integer(),tag='baseline'),
             list(J=9,bad=3,flip=3,tag='flip-extreme'),
             list(J=9,bad=3,flip=1,tag='flip-ordinary'),
             list(J=9,bad=3,flip=seq(1,9,2),tag='flip-odd'),
             list(J=9,bad=3,flip=1:9,tag='flip-all'),
             list(J=14,bad=7,flip=integer(),tag='baseline'),
             list(J=14,bad=7,flip=7,tag='flip-extreme'),
             list(J=14,bad=7,flip=1,tag='flip-ordinary'))
dest <- file.path(out,'permutation-results.csv')
for (s in spec) for(seed in c(42,43,44)) {
  id<-paste0('J',s$J,'-',s$tag,'-seed',seed)
  if(file.exists(file.path(out,paste0('result-',id,'.rds'))))next
  d<-make(s$J,s$bad,s$flip);f<-file.path(out,paste0('fixture-',id,'.csv'))
  write.csv(d,f,row.names=FALSE)
  tm<-system.time({rd<-.apiReadUpload(f,basename(f));a<-isolate(.apiAnalyze(rd$data,seed=seed))})
  saveRDS(a,file.path(out,paste0('result-',id,'.rds')))
  if(!is.null(a$results))write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  q<-100/199;ref<-q^s$J+.5*s$J*(1-q)*q^(s$J-1)
  r<-cbind(data.frame(id=id,J=s$J,seed=seed,flipped=paste(s$flip,collapse=';'),exact=ref,seconds=tm[['elapsed']]),summary_row(a))
  write.table(r,dest,sep=',',row.names=FALSE,col.names=!file.exists(dest),append=file.exists(dest))
  cat(id,r$p,r$CI95,'M',r$M,'exact',format(ref,digits=12),'\n');flush.console()
}
writeLines('Complete',file.path(out,'permutation-complete.txt'))
