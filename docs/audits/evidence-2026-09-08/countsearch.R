# Exact independent hypergeometric calculation for binary two-arm rows.
# This formula is derived from the conditional law X|total successes,
# not from P_Calc or its statistic implementation.
suppressPackageStartupMessages(pkgload::load_all())
outdir<-'docs/audits/evidence-2026-09-08'
mid2<-function(a,b,n1,n2) {
 s<-a+b;nt<-n1+n2
 if(s==0||s==nt)return(NA_real_)
 ad<-abs(nt*a-n1*s);left<-(n1*s-ad)/nt;right<-(n1*s+ad)/nt
 li<-floor(left+1e-9)+1;hi<-ceiling(right-1e-9)-1
 below<-if(hi>=li)phyper(hi,s,nt-s,n1)-phyper(li-1,s,nt-s,n1) else 0
 edges<-unique(c(left,right));edges<-round(edges[abs(edges-round(edges))<1e-9])
 below+.5*sum(dhyper(edges,s,nt-s,n1))
}
best<-NULL;delta<-0;cases<-0
for(n1 in c(101,150,200,333,501,1001))for(n2 in c(101,150,200,333,501,1001))for(p1 in c(0:5,45:55,95:100))for(p2 in c(0:5,45:55,95:100)) {
 ns<-c(n1,n2);pcts<-c(p1,p2)
 bs<-mapply(.ppCountBracket,pcts,0,ns)
 if(anyNA(bs))next
 lo<-bs[1,];hi<-bs[2,];cnt<-ifelse(lo==hi,lo,NA)
 if(!anyNA(cnt))next
 chosen<-.ppFailsafeCounts(lo,hi,cnt,ns)
 pc<-mid2(chosen[1],chosen[2],n1,n2);if(is.na(pc))next
 gg<-expand.grid(seq(lo[1],hi[1]),seq(lo[2],hi[2]))
 pp<-mapply(mid2,gg[,1],gg[,2],MoreArgs=list(n1=n1,n2=n2))
 cases<-cases+1
 if(any(is.finite(pp))&&max(pp,na.rm=TRUE)-pc>delta+1e-12) {
  j<-which.max(pp);delta<-pp[j]-pc
  best<-list(N=ns,percent=pcts,lo=lo,hi=hi,chosen=chosen,chosenP=pc,alternative=unlist(gg[j,]),alternativeP=pp[j],chosenStat=.ppRowStat(chosen,ns),alternativeStat=.ppRowStat(unlist(gg[j,]),ns))
 }
}
capture.output(list(cases=cases,worst=best),file=file.path(outdir,'countsearch.txt'))
saveRDS(best,file.path(outdir,'countsearch.rds'))
