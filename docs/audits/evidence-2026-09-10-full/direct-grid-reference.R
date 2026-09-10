# Independent full-observation reference for the large-arm grid correction.
# Integer sample sums decide equality; no floating SSD or engine helper.
source('docs/audits/evidence-2026-09-10-full/common.R')
d <- data.frame(TRIAL='Audit',ROW='Mean-grid',N=c(100,100),MEAN=c(0,0),SD=c(3,3),
  ROUND_MEAN=6,ROUND_OBSERVATION=0,ROUND_DISPERSION=3)
write.csv(d,file.path(out,'fixture-direct-mean-grid.csv'),row.names=FALSE)
engine <- run_engine(d,seed=42)
write.csv(engine,file.path(out,'result-direct-mean-grid.csv'),row.names=FALSE)
set.seed(1927)
B <- 100000L;k <- 0L
for(first in seq(1,B,by=1000)) {
  ch <- min(1000,B-first+1)
  v <- (runif(ch,2.9995,3.0005)^2+runif(ch,2.9995,3.0005)^2)/2
  sigma <- sqrt(v*198/rchisq(ch,198))
  mu <- rnorm(ch,0,sigma/10)
  s1 <- rowSums(round(matrix(rnorm(ch*100),ch)*sigma+mu))
  s2 <- rowSums(round(matrix(rnorm(ch*100),ch)*sigma+mu))
  k <- k+sum(s1==s2)
}
write.csv(data.frame(engine_seed=42,engine_p=engine$P[1],engine_CI=engine$CI95[1],M=engine$M[1],
  reference_seed=1927,reference_B=B,integer_ties=k,reference_midp=k/(2*B),
  reference_lower=0,reference_upper=qbeta(.975,k+1,B-k)),
  file.path(out,'direct-grid-reference.csv'),row.names=FALSE)
writeLines('Full-observation grid reference completed.',file.path(out,'direct-grid-reference-complete.txt'))
