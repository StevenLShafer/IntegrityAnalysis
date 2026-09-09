# Independent finite-distribution calculation for the row/trial proxy.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od<-'docs/audits/evidence-2026-09-09';sink(file.path(od,'trial-proxy.txt'),split=TRUE)
law<-function(r1,r2,C) {
 G<-r1+r2;x<-max(0,C-r2):min(r1,C);prob<-dhyper(x,C,G-C,r1)
 score<-abs(G*x-r1*C) # exact integer distance, same ordering as Pearson
 mid<-vapply(score,function(s)sum(prob[score<s])+.5*sum(prob[score==s]),numeric(1))
 list(x=x,pr=prob,mid=mid,z=qnorm(pmax(1e-300,pmin(mid,1-1e-15)),lower.tail=FALSE))
}
combine<-function(A,ia,B,ib) {
 z<-outer(A$z,B$z,'+');w<-outer(A$pr,B$pr,'*');o<-A$z[ia]+B$z[ib]
 sum(w[z>o+1e-12])+.5*sum(w[abs(z-o)<=1e-12])
}
AA<-lapply(3:5,function(k)law(200,2000,k))
gap<-0;best<-NULL
for(n1 in 2:20)for(n2 in 2:20)for(C in 1:(n1+n2-1)) {
 B<-law(n1,n2,C)
 for(ib in seq_along(B$x)) {
  ps<-vapply(AA,function(A)combine(A,1,B,ib),numeric(1))
  g<-max(ps)-ps[1]
  if(g>gap+1e-12){gap<-g;best<-list(n1=n1,n2=n2,C=C,obs=B$x[ib],rowP=vapply(AA,function(A)A$mid[1],numeric(1)),trialP=ps,Bp=B$mid[ib],gap=g)}
 }
}
print(best);saveRDS(best,file.path(od,'trial-proxy.rds'))
if(!is.null(best)) for(k in c(3,2+which.max(best$trialP))) {
 d<-data.frame(TRIAL='T',ROW=rep(c('A','B'),each=2),N=NA_real_,MEAN=NA_real_,SD=NA_real_,
  Event=c(0,k,best$obs,best$C-best$obs),Other=c(200,2000-k,best$n1-best$obs,best$n2-best$C+best$obs))
 print(d);set.seed(42);dqset.seed(42);v<-shiny::isolate(validateData(d));print(v$FAIL)
 x<-shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,100000));print(x)
 # Diagnostic full-batch copy: ONLY the stage assignment is changed. The
 # package and application are untouched. This isolates the proxy from
 # sampling-driven ordering changes in the default 1,000-replicate batch.
 rewrite<-function(x) {
  if(is.call(x)&&identical(x[[1]],as.name('<-'))&&identical(x[[2]],as.name('stages')))return(quote(stages<-m))
  if(is.call(x))return(as.call(lapply(as.list(x),rewrite)))
  x
 }
 f<-P_Calc;body(f)<-rewrite(body(f));set.seed(42);dqset.seed(42)
 cat('Diagnostic single 100,000-replicate batch, not default staging:\n')
 print(shiny::isolate(f('T',v$DATA,v$CategoryNames,100000)))
}
sink()
