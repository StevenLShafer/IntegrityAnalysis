# Re-executed for the third full audit at 6db32ee, Codex, 2026-09-11.
# Re-executed against the final brief commit, Codex, 2026-09-11.
# Independent scalar-quantile implementation of the documented metalog null.
# Codex, 2026-09-10. Uses base R RNG/order statistics, not engine helpers.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
reference_median <- function(d, B=100000, seed=9173) {
  set.seed(seed)
  n <- d$N; w <- n/sum(n); mu <- sum(w*d$MEAN)
  h <- 10^-d$ROUND_DISPERSION
  fit <- function(q1,q3) {
    scale <- (q3-q1)/(2*log(3))
    skew <- 2*(q1+q3-2*mu)/log(3)
    list(scale=scale,skew=pmax(-1.66*scale,pmin(1.66*scale,skew)))
  }
  quantile_draw <- function(B,n,loc,scale,skew) {
    u <- matrix(runif(B*n,1e-12,1-1e-12),B,n)
    loc+(scale+skew*(u-.5))*qlogis(u)
  }
  observed <- sum((d$MEAN-sum(w*d$MEAN))^2)
  less <- equal <- 0
  for(first in seq(1,B,by=1000)) {
    b <- min(1000,B-first+1); q1 <- q3 <- numeric(b)
    for(i in seq_along(n)) {
      x <- runif(b,d$Q1[i]-h[i]/2,d$Q1[i]+h[i]/2)
      y <- runif(b,d$Q3[i]-h[i]/2,d$Q3[i]+h[i]/2)
      q1 <- q1+w[i]*pmin(x,y);q3 <- q3+w[i]*pmax(x,y)
    }
    f <- fit(q1,q3)
    aq <- pmax(f$scale,.01*min(h)/(2*log(3)))
    cq <- pmax(-1.66*aq,pmin(1.66*aq,f$skew))
    bq1 <- bq3 <- numeric(b)
    for(i in seq_along(n)) {
      x <- round(quantile_draw(b,n[i],mu,aq,cq),d$ROUND_OBSERVATION[i])
      qq <- apply(x,1,quantile,probs=c(.25,.75),type=7,names=FALSE)
      bq1 <- bq1+w[i]*round(qq[1,],d$ROUND_DISPERSION[i])
      bq3 <- bq3+w[i]*round(qq[2,],d$ROUND_DISPERSION[i])
    }
    boot <- pmax((bq3-bq1)/(2*log(3)),min(h)/(2*log(3)))
    ar <- aq^2/boot; cr <- pmax(-1.66*ar,pmin(1.66*ar,cq))
    mr <- rnorm(b,mu,2*ar/sqrt(mean(n)))
    med <- matrix(NA_real_,b,length(n))
    for(i in seq_along(n)) {
      x <- round(quantile_draw(b,n[i],mr,ar,cr),d$ROUND_OBSERVATION[i])
      med[,i] <- round(apply(x,1,median),d$ROUND_MEAN[i])
    }
    med <- med-med[,1]
    center <- drop(med%*%w)
    stat <- rowSums((med-center)^2)
    tie <- abs(stat-observed)<=1e-10*pmax(abs(stat),abs(observed))
    less <- less+sum(stat<observed & !tie); equal <- equal+sum(tie)
  }
  c(p=(less+equal/2)/B,B=B,less=less,equal=equal,
    lower=if(less==0)0 else qbeta(.025,less,B-less+1),
    upper=if(less+equal==B)1 else qbeta(.975,less+equal+1,B-less-equal))
}
cases <- list(
 symmetric=data.frame(TRIAL='Audit',ROW='Median',N=c(10,10),MEAN=c(10,10.05),SD=NA_real_,Q1=8,Q3=12,
   ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=2),
 asymmetric=data.frame(TRIAL='Audit',ROW='Median',N=c(11,14),MEAN=c(10,10.15),SD=NA_real_,Q1=8,Q3=13,
   ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=2),
 clipped=data.frame(TRIAL='Audit',ROW='Median',N=c(9,13),MEAN=c(10,10.1),SD=NA_real_,Q1=10,Q3=15,
   ROUND_MEAN=1,ROUND_OBSERVATION=1,ROUND_DISPERSION=1))
ans <- list()
for(id in names(cases)) {
  d <- cases[[id]]
  write.csv(d,file.path(out,paste0('fixture-median-',id,'.csv')),row.names=FALSE)
  r <- run_engine(d,seed=42); ref <- reference_median(d)
  write.csv(r,file.path(out,paste0('result-median-',id,'.csv')),row.names=FALSE)
  ans[[id]] <- data.frame(case=id,engine_seed=42,engine_p=r$P[1],engine_CI=r$CI95[1],
    actual_M=r$M[1],reference_seed=9173,as.list(ref),check.names=FALSE)
  write.csv(do.call(rbind,ans),file.path(out,'median-reference-comparisons.csv'),row.names=FALSE)
  cat('DONE',id,'engine',r$P[1],'CI',r$CI95[1],'ref',ref['p'],'\n');flush.console()
}
writeLines('Independent median reference completed.',file.path(out,'median-reference-complete.txt'))
