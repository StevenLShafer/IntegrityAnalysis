# Independent three-category selection oracle and seed study; GPT-6 (Codex).
suppressPackageStartupMessages(pkgload::load_all())
od<-'docs/audits/evidence-2026-09-09';unequal<-'unequal'%in%commandArgs(TRUE)
tag<-if(unequal)'three-unequal' else 'three';Ns<-if(unequal)c(200,300) else c(200,200)
lo<-t(vapply(Ns,function(n)ceiling(n*(c(34,32,34)-.5)/100),numeric(3)))
hi<-t(vapply(Ns,function(n)floor(n*(c(34,32,34)+.5)/100),numeric(3)))
v<-as.matrix(expand.grid(67:69,63:65,67:69));v<-v[rowSums(v)==200,]
v2<-as.matrix(expand.grid(Map(seq.int,lo[2,],hi[2,])));v2<-v2[rowSums(v2)==Ns[2],]
tabs<-list();pp<-numeric(0)
for(i in 1:nrow(v))for(j in 1:nrow(v2)) {
 tab<-rbind(v[i,],v2[j,]);C<-colSums(tab);R<-200;G<-sum(Ns);W<-prod(C)/C
 z<-expand.grid(x1=0:C[1],x2=0:C[2]);z$x3<-R-z$x1-z$x2
 z<-as.matrix(z[z$x3>=0 & z$x3<=C[3],]);ss<-rowSums(sweep(sweep(G*z,2,R*C,'-')^2,2,W,'*'))
 so<-sum((G*tab[1,]-R*C)^2*W)
 pr<-exp(rowSums(sapply(1:3,function(k)lchoose(C[k],z[,k])))-lchoose(G,R))
 pp<-c(pp,sum(pr[ss<so])+.5*sum(pr[ss==so]));tabs[[length(tabs)+1L]]<-tab
}
oracle<-list(tables=tabs,p=pp);saveRDS(oracle,file.path(od,paste0(tag,'-oracle.rds')))
cat('Exact three-level best/worst:',max(pp),min(pp),'\n')
for(seed in 1:60) {
 f<-file.path(od,sprintf('%s-seed-%03d.rds',tag,seed));if(file.exists(f))next
 start<-proc.time()[3];set.seed(seed);calls<-list()
 sel<-.ppFailsafeTableFill;env<-new.env(parent=environment(sel));environment(sel)<-env
 env$.ppTableP<-function(tab,reps){p<-.ppTableP(tab,reps);calls[[length(calls)+1L]]<<-list(tab=tab,reps=reps,p=p);p}
 r<-sel(lo,hi,matrix(NA_integer_,2,3),Ns)
 matches<-which(vapply(tabs,function(t)all(t==r$counts),logical(1)));actual<-pp[matches[1]]
 scored<-Filter(function(x)all(x$tab==r$counts),calls);lastBudget<-tail(vapply(scored,function(x)x$reps,numeric(1)),1)
 ans<-list(seed=seed,trueBest=max(pp),trueWorst=min(pp),selectedTrue=actual,shortfall=max(pp)-actual,
   pBest=r$pBest,pWorst=r$pWorst,straddles=r$straddles,budget=lastBudget,counts=r$counts,seconds=proc.time()[3]-start)
 saveRDS(ans,f);cat('seed',seed,'shortfall',ans$shortfall,'budget',lastBudget,'elapsed',ans$seconds,'\n');flush.console()
}
a<-lapply(1:60,function(s)readRDS(file.path(od,sprintf('%s-seed-%03d.rds',tag,s))))
sink(file.path(od,paste0('noise-',tag,'.txt')),split=TRUE)
tab<-do.call(rbind,lapply(a,function(x)as.data.frame(x[setdiff(names(x),'counts')])));print(tab)
cat('Shortfall distribution:\n');print(quantile(tab$shortfall,c(0,.25,.5,.75,.9,.95,1)))
cat('Winners at coarse budget:',sum(tab$budget==2000),'of',nrow(tab),'; suboptimal:',sum(tab$shortfall>1e-12),'; missed straddles:',sum(!tab$straddles),'\n')
saveRDS(tab,file.path(od,paste0('noise-',tag,'.rds')));sink()
