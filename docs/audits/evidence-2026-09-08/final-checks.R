# Independent audit arithmetic, GPT-6 (Codex), 2026-09-08; synthetic only.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
sink('docs/audits/evidence-2026-09-08/final-checks.txt',split=TRUE)
cat('EXACT TWO BY THREE CONDITIONAL ENUMERATION\n')
exact23<-function(tab) {
 C<-colSums(tab);R<-sum(tab[1,]);G<-sum(C)
 z<-expand.grid(x1=0:C[1],x2=0:C[2]);z$x3<-R-z$x1-z$x2
 z<-as.matrix(z[z$x3>=0 & z$x3<=C[3],])
 # Integer scores: multiply Pearson by the common denominator.
 # All intermediate integers in these fixtures are below 2^53.
 W<-prod(C)/C
 score<-function(x)sum((G*x-R*C)^2*W)
 ss<-apply(z,1,score);so<-score(tab[1,])
 pr<-exp(rowSums(sapply(1:3,function(j)lchoose(C[j],z[,j])))-lchoose(G,R))
 c(tables=nrow(z),mass=sum(pr),X2=so/(prod(C)*R*(G-R)),
   less=sum(pr[ss<so]),equal=sum(pr[ss==so]),mid=sum(pr[ss<so])+.5*sum(pr[ss==so]))
}
print(exact23(rbind(c(69,65,69),c(67,63,67))))
print(exact23(rbind(c(69,63,68),c(67,65,68))))
cat('EXHAUSTIVE SD MINIMUM CHECK\n')
for(n in 2:7) {
 x<-as.matrix(expand.grid(rep(list(0:3),n)))
 mu<-rowMeans(x); vv<-rowSums((x-mu)^2)/(n-1)
 frac<-mu-floor(mu);bound<-n*frac*(1-frac)/(n-1)
 # Formula is attained for each reachable mean and never exceeded downward.
 stopifnot(all(vv>=bound-1e-12))
 bySum<-split(seq_len(nrow(x)),rowSums(x))
 stopifnot(all(vapply(bySum,function(i)abs(min(vv[i])-bound[i[1]])<1e-12,logical(1))))
 cat('n',n,': all',nrow(x),'ordered samples satisfy and attain the sharp bound\n')
}
cat('REFERENCE MONTE CARLO STANDARD ERROR\n')
p<-.1737645;secondMoment<-(88028+171473/4)/1e6
cat('SE',sqrt((secondMoment-p*p)/1e6),'\n')
run<-function(d,validate=TRUE) {
 set.seed(42);dqset.seed(42)
 v<-shiny::isolate(validateData(d));print(v$FAIL);print(v$DATA)
 if(!v$FAIL)print(shiny::isolate(P_Calc('T',if(validate)v$DATA else d,v$CategoryNames,100000)))
}
cat('MIXED SUPPLIED AND INFERRED MEAN PRECISION\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(10,10),MEAN=1,SD=1,ROUND_MEAN=c(4,NA),ROUND_DISPERSION=1)
run(d,FALSE);run(d,TRUE)
cat('SUPPLIED PRECISION BUMP\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(10,10),MEAN=c(1.1,1.2),SD=1,ROUND_MEAN=0,ROUND_OBSERVATION=1,ROUND_DISPERSION=1)
run(d,FALSE);run(d,TRUE)
cat('FRACTIONAL PRECISION\n')
d<-data.frame(TRIAL='T',ROW='X',N=c(100,100),MEAN=c(50,52),SD=10,ROUND_MEAN=0,ROUND_OBSERVATION=-.5,ROUND_DISPERSION=0)
run(d,TRUE)
cat('Requested h',10^.5,'; R rounds c(1,2,3,4) to',round(1:4,-.5),'\n')
cat('P_CALC HELP AVAILABILITY\n')
print('P_Calc' %in% getNamespaceExports('IntegrityAnalysis'))
cat('Source man/P_Calc.Rd exists:',file.exists('man/P_Calc.Rd'),'\n')
cat('SESSION METADATA\n');print(sessionInfo())
sink()
