# Re-executed for the fourth full audit at 7c6583f, Codex, 2026-09-11.
# Codex, 2026-09-11. Base-R independent arithmetic; no production ranking helper.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
# For any fixed observed support point, the raw empirical mid-CDF is a sample
# mean of I(X<t)+.5 I(X=t). Pooling iid draws preserves its expectation exactly.
# Here X is the homogeneous state of the binary N=100 construction.
q <- 100/199;M <- 1000;G <- 9;set.seed(615)
k <- matrix(rbinom(20000*G,M,q),20000,G)
r <- data.frame(mapping=c('own','pooled'),exact_midp=q/2,
  empirical_mean=c(mean(k[,1]/(2*M)),mean(rowSums(k)/(2*M*G))),
  sd_of_mapping=c(sd(k[,1]/(2*M)),sd(rowSums(k)/(2*M*G))),
  predicted_sd=c(sqrt(q*(1-q)/(4*M)),sqrt(q*(1-q)/(4*M*G))),
  independent_repetitions=20000,M=M,G=G,seed=615)
write.csv(r,file.path(out,'pool-expectation.csv'),row.names=FALSE)
# Exact finite-binomial coverage of CP intervals after the existing independent
# fresh-batch stopping rule in an untied single-row null. This quantifies the
# documented optional-stopping limitation; it is not a new finding.
stages <- c(1000,10000,100000);bound <- c(.1,.01,0)
cp <- lapply(stages,function(n){k<-0:n;data.frame(k=k,
  lo=ifelse(k==0,0,qbeta(.025,pmax(k,1),n-k+1)),
  hi=ifelse(k==n,1,qbeta(.975,k+1,pmax(n-k,1))))})
coverage <- lapply(c(.0001,.001,.009,.0095,.01,.0105,.011,.095,.1,.105,.11,.5),function(p){
  reach<-1;covered<-expectedN<-0
  for(j in 1:3){n<-stages[j];z<-cp[[j]];pr<-dbinom(z$k,n,p);stop<-z$k/n>=bound[j]
    covered<-covered+reach*sum(pr[stop & z$lo<=p & z$hi>=p])
    expectedN<-expectedN+reach*n
    reach<-reach*sum(pr[!stop])}
  data.frame(true_p=p,coverage=covered,expected_total_generated=expectedN)
})
write.csv(do.call(rbind,coverage),file.path(out,'staged-interval-coverage.csv'),row.names=FALSE)
d <- read.csv(file.path(out,'F-unequal-replications.csv'))
B <- sum(d$M);ref<-d$reference[1];se<-sd(d$p)/sqrt(nrow(d));mu<-mean(d$p)
write.csv(data.frame(runs=nrow(d),M=B,mean_p=mu,reference=ref,
  replicate_mean_t95_lower=mu-qt(.975,nrow(d)-1)*se,
  replicate_mean_t95_upper=mu+qt(.975,nrow(d)-1)*se,
  reported_intervals_missing_reference=sum(vapply(d$CI95,function(s){z<-as.numeric(strsplit(s,' to ',fixed=TRUE)[[1]]);ref<z[1]||ref>z[2]},logical(1)))),
  file.path(out,'F-unequal-replication-summary.csv'),row.names=FALSE)
writeLines('Complete',file.path(out,'analytic-checks-complete.txt'))
