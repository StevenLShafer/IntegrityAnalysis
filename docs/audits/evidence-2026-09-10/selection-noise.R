# Independent exact sampling-law experiment, Codex 2026-09-10.
# Each score is a sum of iid variables taking 0, 1/2, 1 with known exact
# hypergeometric probabilities. Binomial decompositions sample that law,
# without calling r2dtable or any IntegrityAnalysis helper.
od<-'C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10'
law<-function(v) {
 a<-v[1];b<-v[2];c<-v[3];d<-v[4];r<-a+b;cc<-a+c;n<-sum(v)
 x<-max(0,r-(n-cc)):min(r,cc);delta<-abs(n*x-r*cc);obs<-abs(n*a-r*cc);w<-dhyper(x,cc,n-cc,r)
 c(less=sum(w[delta<obs]),eq=sum(w[delta==obs]))
}
draw<-function(L,B) {
 eq<-rbinom(nrow(L),B,L[,2]);less<-rbinom(nrow(L),B-eq,ifelse(L[,2]>=1,0,L[,1]/(1-L[,2])))
 pmin(.9999,pmax(1/(B+1),(less+eq/2)/B))
}
set.seed(998173)
for(id in c(183,153,181)) {
 z<-readRDS(file.path(od,sprintf('rank-%03d.rds',id)));hi<-z$hi
 L<-t(apply(hi[,1:4],1,law));truth<-L[,1]+L[,2]/2;B<-2000L
 out<-matrix(NA_real_,B,6,dimnames=list(NULL,c('allTruth','rankTruth','allEstimate','rankEstimate','allChosen','rankChosen')))
 for(i in 1:B) {
  coarse<-draw(L,2000)
  aa<-head(order(coarse,decreasing=TRUE),6);rr<-head(order(head(coarse,50),decreasing=TRUE),6)
  both<-union(aa,rr);fine<-rep(NA_real_,nrow(L));fine[both]<-draw(L[both,,drop=FALSE],20000)
  a<-aa[which.max(fine[aa])];r<-rr[which.max(fine[rr])]
  out[i,]<-c(truth[a],truth[r],fine[a],fine[r],a,r)
  if(i%%200==0){saveRDS(out[1:i,,drop=FALSE],file.path(od,paste0('selection-noise-',id,'.rds')));cat(id,i,'\n');flush.console()}
 }
 sink(file.path(od,paste0('selection-noise-',id,'.txt')),split=TRUE)
 ci<-function(v)c(mean=mean(v),low=mean(v)-1.96*sd(v)/sqrt(length(v)),high=mean(v)+1.96*sd(v)/sqrt(length(v)))
 cat('case',id,'independent selection repetitions',B,'exact best',max(truth),'best top50',max(head(truth,50)),'\n')
 print(rbind(allSelectedTruth=ci(out[,1]),rankSelectedTruth=ci(out[,2]),rankMinusAllTruth=ci(out[,2]-out[,1]),
  allEstimationBias=ci(out[,3]-out[,1]),rankEstimationBias=ci(out[,4]-out[,2]),
  allOracleRegret=ci(max(truth)-out[,1]),rankOracleRegret=ci(max(truth)-out[,2])),digits=12)
 sink()
}
