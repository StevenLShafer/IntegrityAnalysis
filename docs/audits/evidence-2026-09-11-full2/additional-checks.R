# Re-executed for the fourth full audit at 7c6583f, Codex, 2026-09-11.
# Re-executed against the final brief commit, Codex, 2026-09-11.
# References, invariances, and reproducibility metadata for the full audit.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
lock <- jsonlite::fromJSON(file.path(src,'renv.lock'),simplifyVector=FALSE)
vers <- read.csv(file.path(out,'dependency-versions.csv'))
vv <- lapply(intersect(vers$package,names(lock$Packages)),function(p) {
  have <- as.character(packageVersion(p));want <- lock$Packages[[p]]$Version
  data.frame(package=p,installed=have,locked=want,matches=package_version(have)==package_version(want))
})
write.csv(do.call(rbind,vv),file.path(out,'lockfile-comparison.csv'),row.names=FALSE)
writeLines(c(R.version.string,paste('Platform:',R.version$platform),paste('Locale:',Sys.getlocale()),
  paste('RNG:',paste(RNGkind(),collapse=', ')),
  'Audited commit: 6db32ee0ea8333870709e52af7ff109299c08da4',
  'Source: isolated detached git worktree; shared checkout and dependencies unchanged.'),file.path(out,'runtime.txt'))
# Recheck the one F-reference miss over additional independent seeded batches.
# A single nominal 95% interval miss is not evidence of systematic bias.
d <- read.csv(file.path(out,'fixture-F-unequal.csv'))
v <- sum((d$N-1)*d$SD^2)/(sum(d$N)-2)
ref <- pf(diff(d$MEAN)^2/(v*sum(1/d$N)),1,sum(d$N)-2)
rr <- lapply(42:61,function(s) {
  r <- run_engine(d,seed=s)
  data.frame(seed=s,p=as.numeric(r$P[1]),CI95=r$CI95[1],M=as.numeric(r$M[1]),reference=ref)
})
write.csv(do.call(rbind,rr),file.path(out,'F-unequal-replications.csv'),row.names=FALSE)
# Translate by a whole grid step, and change units by powers of ten with
# every rounding column changed accordingly. This preserves the experiment.
base <- data.frame(TRIAL='Audit',ROW='X',N=c(30,37),MEAN=c(2.3,2.4),SD=c(3.0,3.1),
  ROUND_MEAN=1,ROUND_OBSERVATION=1,ROUND_DISPERSION=1)
med <- base;med$SD <- NA_real_;med$Q1 <- c(1,1.1);med$Q3 <- c(4.0,4.2)
invar <- list()
for(kind in c('continuous','median')) for(transform in c('base','translated','units')) {
  x <- if(kind=='continuous')base else med
  if(transform=='translated') for(cn in intersect(c('MEAN','Q1','Q3'),names(x))) x[[cn]] <- x[[cn]]+1000
  if(transform=='units') {
    for(cn in intersect(c('MEAN','SD','Q1','Q3'),names(x))) x[[cn]] <- x[[cn]]*.001
    for(cn in c('ROUND_MEAN','ROUND_OBSERVATION','ROUND_DISPERSION')) x[[cn]] <- x[[cn]]+3
  }
  id <- paste(kind,transform,sep='-')
  write.csv(x,file.path(out,paste0('fixture-invariance-',id,'.csv')),row.names=FALSE)
  r <- run_engine(x,seed=42)
  invar[[id]] <- data.frame(kind=kind,transform=transform,p=r$P[1],CI95=r$CI95[1],M=r$M[1])
}
write.csv(do.call(rbind,invar),file.path(out,'invariances.csv'),row.names=FALSE)
# sumz checked independently by integrating the normal density and solving
# its CDF, so the reference does not call pnorm or qnorm.
normal_cdf <- function(z) integrate(function(x)exp(-x*x/2)/sqrt(2*pi),-Inf,z,rel.tol=1e-12)$value
normal_quantile <- function(p) uniroot(function(z)normal_cdf(z)-p,c(-10,10),tol=1e-11)$root
pv <- list(c(.5,.5),c(.02,.03,.04),c(.0001,.2,.9),c(.01,.99))
ss <- lapply(pv,function(p) {
  z <- sum(vapply(1-p,normal_quantile,numeric(1)))/sqrt(length(p))
  ref <- 1-normal_cdf(z)
  data.frame(input=paste(p,collapse=';'),engine=sumz(p)$p,reference=ref,error=sumz(p)$p-ref)
})
write.csv(do.call(rbind,ss),file.path(out,'sumz-quadrature.csv'),row.names=FALSE)
writeLines('Additional checks complete.',file.path(out,'additional-checks-complete.txt'))
