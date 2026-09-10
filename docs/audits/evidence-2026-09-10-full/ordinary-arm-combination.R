# The same exact discrete reference with ordinary arm sizes, using only counts.
source('docs/audits/evidence-2026-09-10-full/common.R')
ans <- list()
for(J in c(9,14)) for(b in 1:J) {
  N <- 100L
  d <- do.call(rbind,lapply(1:J,function(j)
    data.frame(TRIAL='Audit',ROW=sprintf('V%02d',j),N=NA_real_,MEAN=NA_real_,SD=NA_real_,
      YES=if(j==b)c(0,2) else c(1,1),NO=if(j==b)c(N,N-2) else c(N-1,N-1))))
  id <- paste0('ordinary-N',N,'-J',J,'-bad',b)
  f <- file.path(out,paste0('fixture-',id,'.csv'))
  write.csv(d,f,row.names=FALSE,na='')
  rd <- .apiReadUpload(f,basename(f));stopifnot(rd$ok)
  a <- shiny::isolate(.apiAnalyze(rd$data,seed=42));stopifnot(a$ok)
  r <- a$results;s <- r[which(r$KIND=='summary'),]
  write.csv(r,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  q <- N/(2*N-1)
  ref <- q^J+.5*J*(1-q)*q^(J-1)
  ans[[id]] <- data.frame(N=N,J=J,bad_position=b,seed=42,M=max(as.numeric(r$M),na.rm=TRUE),
    p=s$P,CI95=s$CI95,exact_midp=ref,
    at_001_disagrees=(as.numeric(s$P)<.01)!=(ref<.01))
  write.csv(do.call(rbind,ans),file.path(out,'ordinary-combination-routes.csv'),row.names=FALSE)
  cat('DONE',id,'p',s$P,'CI',s$CI95,'M',ans[[id]]$M,'\n');flush.console()
}
writeLines('Ordinary-arm categorical routes complete.',file.path(out,'ordinary-combination-complete.txt'))
