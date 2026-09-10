# Independent 2x2 hypergeometric oracle; no package helpers are used.
# Codex, 2026-09-10. Integer determinants decide all within-null ties.
od <- 'C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10'
exact2 <- function(a,b,c,d) {
 r <- a+b; cc <- a+c; n <- a+b+c+d
 if(min(r,n-r,cc,n-cc)<=0)return(NA_real_)
 x <- max(0,r-(n-cc)):min(r,cc)
 delta <- abs(n*x-r*cc); obs <- abs(n*a-r*cc)
 w <- dhyper(x,cc,n-cc,r)
 sum(w[delta<obs])+.5*sum(w[delta==obs])
}
bracket <- function(p,n) c(max(0,ceiling(n*(p-.5)/100-1e-8)),min(n,floor(n*(p+.5)/100+1e-8)))
shape <- function(N,pct,partition) {
 bb <- lapply(1:4,function(j)bracket(pct[j],rep(N,each=2)[j]))
 if(partition) {
  g <- expand.grid(a=bb[[1]][1]:bb[[1]][2],c=bb[[3]][1]:bb[[3]][2])
  g$b <- N[1]-g$a;g$d <- N[2]-g$c;g<-g[,c('a','b','c','d')]
 } else {
  if(prod(sapply(bb,function(b)diff(b)+1))>50000)return(NULL)
  g <- expand.grid(lapply(bb,function(b)b[1]:b[2]));names(g)<-c('a','b','c','d')
 }
 with(g, {
  n <- a+b+c+d;r<-a+b;cc<-a+c
  g$stat <- n*(a*d-b*c)^2/(r*(n-r)*cc*(n-cc))
  g$key <- paste(r,n-r,cc,n-cc,sep=',')
 }) -> junk
 # assignments inside with are local; make explicit for a reproducible frame
 n<-rowSums(g);r<-g$a+g$b;cc<-g$a+g$c
 g$stat<-n*(g$a*g$d-g$b*g$c)^2/(r*(n-r)*cc*(n-cc))
 g$key<-paste(r,n-r,cc,n-cc,sep=',')
 g<-g[is.finite(g$stat),];if(nrow(g)<51)return(NULL)
 h<-g[order(g$key,g$stat),]
 hi<-h[!duplicated(h$key,fromLast=TRUE),];lo<-h[!duplicated(h$key),]
 hi<-hi[order(-hi$stat),];lo<-lo[order(lo$stat),]
 hi$p<-mapply(exact2,hi$a,hi$b,hi$c,hi$d)
 lo$p<-mapply(exact2,lo$a,lo$b,lo$c,lo$d)
 list(N=N,pct=pct,partition=partition,hi=hi,lo=lo,nTables=nrow(g),
  summary=data.frame(N1=N[1],N2=N[2],p1=pct[1],p2=pct[2],p3=pct[3],p4=pct[4],partition=partition,
   n=nrow(g),groups=nrow(hi),maxRank=which.max(hi$p),minRank=which.min(lo$p),
   best=max(hi$p),best50=max(head(hi$p,50)),worst=min(lo$p),worst50=min(head(lo$p,50))))
}
if(Sys.getenv('AUDIT_ORACLE_ONLY')!='1') {
 set.seed(912731)
 plans<-list()
 for(N in list(c(200,5000),c(300,5000),c(500,5000),c(1000,5000),c(5000,5000),c(700,700),c(300,1000))) {
  for(p in c(0,1,2,5,10,25,50))for(q in unique(pmax(0,c(p-1,p,p+1))))
   plans[[length(plans)+1]]<-list(N=N,pct=c(p,100-p,q,100-q),partition=TRUE)
 }
 for(k in 1:90) {
  N<-sample(c(200,300,500,700,1000,2000,5000),2,replace=TRUE)
  p<-sample(c(0,1,2,3,5,10,25,50),2,replace=TRUE)
  pct<-c(p,pmax(0,p+sample(-2:2,2,replace=TRUE)))
  plans[[length(plans)+1]]<-list(N=N,pct=pct,partition=FALSE)
 }
 for(i in seq_along(plans)) {
  f<-file.path(od,sprintf('rank-%03d.rds',i));if(file.exists(f))next
  t<-proc.time()[3];a<-do.call(shape,plans[[i]]);saveRDS(a,f)
  if(!is.null(a)){a$summary$id<-i;write.table(a$summary,file.path(od,'rank-search.csv'),append=file.exists(file.path(od,'rank-search.csv')),col.names=!file.exists(file.path(od,'rank-search.csv')),row.names=FALSE,sep=',')}
  cat(i,'elapsed',proc.time()[3]-t,if(!is.null(a))paste('maxRank',a$summary$maxRank,'gap',a$summary$best-a$summary$best50,'minGap',a$summary$worst50-a$summary$worst),'\n');flush.console()
 }
}
