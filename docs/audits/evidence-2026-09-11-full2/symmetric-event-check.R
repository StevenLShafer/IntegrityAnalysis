# Codex, 2026-09-11: independently classify actual trials by integer events.
# In these reference laws c(1) < c(4) < 2*c(1), with c a Stouffer score
# cost. Only all-zero or one unit-difference trials are strictly ahead;
# exactly one two-unit difference is tied. No tolerance is used here.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
files<-list.files(out,'^draws-symmetric-refined-.*[.]rds$',full.names=TRUE)
records<-list()
for(f in files){
  x<-readRDS(f);mat<-do.call(cbind,x$integer_draws);J<-ncol(mat);B<-nrow(mat)
  n0<-rowSums(mat==0);n1<-rowSums(mat==1);n4<-rowSums(mat==4)
  strict<-sum(n0==J | (n0==J-1 & n1==1));ties<-sum(n0==J-1 & n4==1)
  stopifnot(strict==x$reference_strict,ties==x$reference_ties)
  records[[basename(f)]]<-data.frame(case=sub('^draws-|[.]rds$','',basename(f)),
    J=J,M=B,integer_strict=strict,integer_ties=ties,p=(strict+.5*ties)/B,
    matches_pooled_rank_reference=TRUE)
}
write.csv(do.call(rbind,records),file.path(out,'symmetric-integer-events.csv'),row.names=FALSE)
# Additional equal-law key counterexamples: equal N, equal precisions,
# pooled dispersion inputs exchanged independently of the observed means.
a<-data.frame(N=c(30,30),MEAN=c(-1,1),SD=c(5,7),
  ROUND_MEAN=0,ROUND_DISPERSION=1,ROUND_OBSERVATION=0)
b<-a;b$SD<-rev(b$SD)
m<-a;m$N<-9;m$SD<-NA_real_;m$Q1<-c(-2,-1);m$Q3<-c(1,2)
n<-m;n$Q1<-rev(n$Q1);n$Q3<-rev(n$Q3)
write.csv(data.frame(case=c('equal-N SD pairing','equal-N quartile pairing'),
  key_equal=c(identical(.iaNullKey('continuous',a),.iaNullKey('continuous',b)),
              identical(.iaNullKey('median',m),.iaNullKey('median',n))),
  law_equal_by='Permutation of independent equally weighted dispersion-interval draws'),
  file.path(out,'symmetric-dispersion-key-checks.csv'),row.names=FALSE)
saveRDS(list(continuous=list(a=a,b=b),median=list(a=m,b=n)),
  file.path(out,'symmetric-dispersion-key-fixtures.rds'))
writeLines(c(R.version.string,paste('Locale:',Sys.getlocale()),
  paste('Base RNG:',paste(RNGkind(),collapse='; ')),
  paste('dqrng:',as.character(packageVersion('dqrng'))),
  'Target: 7c6583f7190ce581ab157b8f931ef5f39eba3789',
  'No restored or updated packages; read-only private dependency snapshot.'),file.path(out,'runtime.txt'))
writeLines('Complete; all integer-event counts agree.',file.path(out,'symmetric-event-complete.txt'))
