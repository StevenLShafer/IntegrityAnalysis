# Uninstrumented route reproduction, including actual adaptive stopping.
source('docs/audits/evidence-2026-09-10-full/common.R')
records <- list()
for(J in c(15,23)) for(b in if(J==15) 1:15 else c(1,4,15)) {
  d <- do.call(rbind,lapply(seq_len(J),function(j)
    data.frame(TRIAL='Audit',ROW=sprintf('V%02d',j),N=NA_real_,MEAN=NA_real_,SD=NA_real_,
      CAT1=if(j==b)c(0,2) else c(1,1),CAT2=if(j==b)c(2,0) else c(1,1))))
  id <- paste0('verified-J',J,'-bad',b)
  f <- file.path(out,paste0('fixture-',id,'.csv'))
  write.csv(d,f,row.names=FALSE,na='')
  rd <- .apiReadUpload(f,basename(f)); stopifnot(rd$ok)
  a <- shiny::isolate(.apiAnalyze(rd$data,seed=42)); stopifnot(a$ok)
  r <- a$results
  write.csv(r,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  s <- r[which(r$KIND=='summary'),]
  ref <- (2/3)^J * (1+J/4)
  records[[id]] <- data.frame(J=J,bad_position=b,seed=42,ceiling=100000,
    M=max(as.numeric(r$M),na.rm=TRUE),p=s$P,CI95=s$CI95,reference=ref,
    at_001_disagrees=(as.numeric(s$P)<.01)!=(ref<.01))
  write.csv(do.call(rbind,records),file.path(out,'verified-combination-routes.csv'),row.names=FALSE)
  cat('DONE',id,'p',s$P,'CI',s$CI95,'M',records[[id]]$M,'\n');flush.console()
}
writeLines('Uninstrumented route verification complete.',file.path(out,'verify-combination-complete.txt'))
