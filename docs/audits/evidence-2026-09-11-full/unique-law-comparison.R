# Re-executed for the third full audit at 6db32ee, Codex, 2026-09-11.
# Fixed-stage and adaptive comparisons with the previous audited implementation.
# Run twice, with SOURCE and COMPARISON_TAG supplied externally for the old tree.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
tag <- Sys.getenv('INTEGRITY_AUDIT_COMPARISON_TAG');stopifnot(tag %in% c('old','target'))
continuous <- data.frame(TRIAL='T',ROW=rep(c('A','B'),each=2),N=c(30,31,100,125),
  MEAN=c(20,20.3,0,.0008),SD=c(2,2.1,1,1),ROUND_MEAN=c(1,1,6,6),
  ROUND_DISPERSION=3,ROUND_OBSERVATION=c(1,1,6,6))
median <- data.frame(TRIAL='T',ROW=rep(c('A','B'),each=2),N=c(10,10,11,14),
  MEAN=c(10,10.05,10,10.15),SD=NA_real_,Q1=8,Q3=c(12,12,13,13),
  ROUND_MEAN=2,ROUND_DISPERSION=2,ROUND_OBSERVATION=2)
category <- data.frame(TRIAL='T',ROW=rep(c('A','B','C'),each=2),N=NA_real_,MEAN=NA_real_,SD=NA_real_,
  YES=c(1,1,1,2,3,1),NO=c(1,1,2,5,3,6))
shared <- data.frame(TRIAL='T',ROW=rep(sprintf('V%02d',1:9),each=2),
  N=NA_real_,MEAN=NA_real_,SD=NA_real_,YES=c(0,2,rep(1,16)),NO=c(100,98,rep(99,16)))
cases <- list(continuous=continuous,median=median,category=category,shared=shared)
for(id in names(cases)) for(m in c(1000,100000)) {
  d <- cases[[id]];stem <- paste0('comparison-',id,'-m',m)
  if(tag=='target')write.csv(d,file.path(out,paste0('fixture-',stem,'.csv')),row.names=FALSE)
  r <- run_engine(d,seed=42,m=m)
  saveRDS(r,file.path(out,paste0(stem,'-',tag,'.rds')))
  write.csv(r,file.path(out,paste0(stem,'-',tag,'.csv')),row.names=FALSE)
  cat('DONE',tag,id,m,'\n');flush.console()
}
writeLines('Complete',file.path(out,paste0('unique-law-',tag,'-complete.txt')))
