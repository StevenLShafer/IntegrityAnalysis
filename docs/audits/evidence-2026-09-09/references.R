# Independent conditional probabilities and selector-margin audit; GPT-6.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od<-'docs/audits/evidence-2026-09-09';sink(file.path(od,'references.txt'),split=TRUE)
# Exact probabilities inside the observed Pearson ellipsoid for equal arms.
# Enumerate four integer deviations; the fifth is fixed by their zero sum.
# Multiplying scores by a common denominator makes ties integer comparisons.
exact5<-function(E,obsdev) {
 N<-sum(E);w<-prod(E)/E
 # Rescale integer weights by their GCD, keeping scores below 2^53.
 gcd<-function(a,b){while(b!=0){q<-a%%b;a<-b;b<-q};a}
 w<-w/Reduce(gcd,w);sObs<-sum(w*obsdev^2)
 maxd<-floor(sqrt(sObs/w));lt<-eq<-0
 z<-expand.grid(d3=(-maxd[3]):maxd[3],d4=(-maxd[4]):maxd[4])
 base<-sum(lchoose(2*E,E))-lchoose(2*N,N)
 for(d1 in (-maxd[1]):maxd[1])for(d2 in (-maxd[2]):maxd[2]) {
  d5<--d1-d2-z$d3-z$d4
  ss<-w[1]*d1^2+w[2]*d2^2+w[3]*z$d3^2+w[4]*z$d4^2+w[5]*d5^2
  keep<-ss<=sObs & abs(d5)<=maxd[5]
  if(!any(keep))next
  dd<-cbind(d1,d2,z$d3[keep],z$d4[keep],d5[keep])
  logp<-rep(base,nrow(dd))
  for(j in 1:5)logp<-logp+lchoose(2*E[j],E[j]+dd[,j])-lchoose(2*E[j],E[j])
  pr<-exp(logp);lt<-lt+sum(pr[ss[keep]<sObs]);eq<-eq+sum(pr[ss[keep]==sObs])
 }
 c(X2=sum(2*obsdev^2/E),less=lt,equal=eq,mid=lt+.5*eq)
}
cat('CAP COUNTEREXAMPLE EXACT ANSWERS\n')
print(c(reconstructed=.5*exp(5*lchoose(1600,820)-lchoose(8000,4100))))
print(exact5(rep(800,5),c(20,20,-20,-20,0)))
cat('PARTITION COUNTEREXAMPLE EXACT ANSWERS\n')
print(c(reconstructed=.5*exp(sum(lchoose(2*c(245,245,245,265),c(245,245,245,265)))-lchoose(2000,1000))))
print(exact5(c(240,240,240,260,20),c(-5,5,-5,5,0)))
# Exact binary mid-p, vectorized over candidate tables, from the conditional
# hypergeometric law and integer distance to its expectation.
exact22<-function(a,b,c,d) {
 r<-a+b;C<-a+c;G<-a+b+c+d
 dist<-abs(G*a-r*C);lo<-(r*C-dist)/G;hi<-(r*C+dist)/G
 first<-floor(lo+1e-9)+1;last<-ceiling(hi-1e-9)-1
 p<-ifelse(last>=first,phyper(last,C,G-C,r)-phyper(first-1,C,G-C,r),0)
 p<-p+.5*ifelse(abs(lo-round(lo))<1e-9,dhyper(round(lo),C,G-C,r),0)
 p<-p+.5*ifelse(hi!=lo & abs(hi-round(hi))<1e-9,dhyper(round(hi),C,G-C,r),0)
 p[r==0 | r==G | C==0 | C==G]<-NA_real_;p
}
cat('NONEXHAUSTIVE GROUPING SEARCH\n')
best<-list(gap=0);cases<-0
for(N in c(200,300,500))for(p1 in c(0,2,4,10))for(p2 in c(0,2,4,10))for(q1 in c(0,2,4,10))for(q2 in c(0,2,4,10)) {
 pc<-c(p1,p2,q1,q2);lo<-pmax(0,ceiling(N*(pc-.5)/100));hi<-floor(N*(pc+.5)/100)
 z<-expand.grid(Map(seq.int,lo,hi));names(z)<-c('a','b','c','d')
 a<-z$a;b<-z$b;c<-z$c;d<-z$d;G<-a+b+c+d
 stat<-G*(a*d-b*c)^2/((a+b)*(c+d)*(a+c)*(b+d));ps<-exact22(a,b,c,d)
 use<-is.finite(stat)&is.finite(ps);z<-z[use,];stat<-stat[use];ps<-ps[use]
 if(!nrow(z))next
 groups<-split(seq_len(nrow(z)),paste(z$a+z$c,z$b+z$d,sep=','))
 picked<-vapply(groups,function(i)i[which.max(stat[i])],integer(1))
 gap<-max(ps)-max(ps[picked]);cases<-cases+1
 if(gap>best$gap+1e-12)best<-list(gap=gap,N=N,pct=pc,lo=lo,hi=hi,
  trueBest=z[which.max(ps),],trueP=max(ps),groupBest=z[picked[which.max(ps[picked])],],groupP=max(ps[picked]))
}
print(list(cases=cases,worst=best));saveRDS(best,file.path(od,'nonexhaustive.rds'))
sink()
