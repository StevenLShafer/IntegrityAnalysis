# Independent audit, GPT-6, 2026-09-07; synthetic finite inputs only.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
outdir<-'docs/audits/evidence-2026-09-07'
sink(file.path(outdir,'edgechecks.txt'),split=TRUE)
cat('ORDER AFTER UNEQUAL PRINTING\n')
xs<-list(c(4.5,4.8,4.99,5.6,6),c(4.4,4.7,5.01,5.5,6.2))
print(lapply(xs,quantile,probs=c(.25,.5,.75)))
d<-data.frame(TRIAL='T',ROW='X',N=5,MEAN=vapply(xs,median,0.),SD=NA_real_,Q1=round(vapply(xs,quantile,0.,probs=.25)),Q3=round(vapply(xs,quantile,0.,probs=.75)),ROUND_MEAN=2,ROUND_OBSERVATION=2,ROUND_DISPERSION=0)
print(d);v<-shiny::isolate(validateData(d));print(v$FAIL);print(v$issues)
cat('UNIQUE PERCENT BRACKET\n');print(.ppCountFromPct(50,0,5000))
cat('NORMALIZED LOCKFILE VERSION CHECK\n')
lock<-jsonlite::fromJSON('renv.lock',simplifyVector=FALSE)$Packages
diffs<-lapply(names(lock),function(p){v<-tryCatch(packageVersion(p),error=function(e)NULL);if(is.null(v)||v!=package_version(lock[[p]]$Version))data.frame(package=p,locked=lock[[p]]$Version,installed=if(is.null(v))NA_character_ else as.character(v))})
print(do.call(rbind,diffs))
cat('NUMERICAL EDGES\n')
for(mu in c(0,1e6,1e11))for(s in c(1e-6,1,1e6))for(dp in c(0,6,20)) {
 d<-data.frame(TRIAL='T',ROW='X',N=c(100,101),MEAN=mu,SD=s,ROUND_MEAN=dp,ROUND_OBSERVATION=dp,ROUND_DISPERSION=6)
 v<-shiny::isolate(validateData(d));set.seed(42);dqset.seed(42)
 a<-tryCatch(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,1000)),error=function(e)conditionMessage(e))
 cat('mu',mu,'sd',s,'digits',dp,'FAIL',v$FAIL,'result',if(is.character(a)) a else a$P[1],'\n')
}
sink()
