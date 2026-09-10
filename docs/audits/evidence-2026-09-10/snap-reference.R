# Independently rank integer arm-distance steps on the engine's actual draws.
# This measures the zero-snap symptom without replacing the simulation model.
# Codex, 2026-09-10; diagnostic function copy only, audited files unchanged.
source('C:/dev/IntegrityAnalysis/docs/audits/evidence-2026-09-10/common.R')
unit('snap-reference',{
 d<-read.csv(file.path(od,'three-row-1e+07.csv'))
 v<-shiny::isolate(validateData(d));raw<-list()
 e<-new.env(parent=environment(P_Calc))
 e$rowsums<-function(x,...){s<-Rfast::rowsums(x,...);raw[[length(raw)+1]]<<-s;s}
 instrumented<-P_Calc;environment(instrumented)<-e
 set.seed(42);dqset.seed(42)
 prod<-shiny::isolate(instrumented('Audit',v$DATA,v$CategoryNames,100000));print(prod)
 final<-tail(raw,3);B<-length(final[[1]])
 # Equal arm Ns imply sum of squared deviations = (mean1-mean2)^2/2.
 # Printed means lie on the 1e-4 grid. Recover the integer distance; its
 # exact equality/order is an oracle independent of the zero-tolerance.
 steps<-lapply(final,function(x)round(sqrt(2*x)/1e-4))
 cat('raw first-row range',range(final[[1]]),'zero count',sum(final[[1]]==0),
   'distinct integer distances',length(unique(steps[[1]])),'snapped count',sum(final[[1]]<=100),'\n')
 obs<-c(1e11,0,0)
 floorp<-function(p)pmin(.9999,pmax(1/(B+1),p))
 pp<-mapply(function(x,o)floorp((sum(x<o)+.5*sum(x==o))/B),steps,obs)
 zobs<-sum(qnorm(pp,lower.tail=FALSE))
 ranks<-lapply(steps,function(x)(rank(x,ties.method='average')-.5)/B)
 zz<-Reduce('+',lapply(ranks,function(p)qnorm(floorp(p),lower.tail=FALSE)))
 k<-sum(zz>zobs);eq<-sum(zz==zobs)
 cp<-function(k,n)c(if(k==0)0 else qbeta(.025,k,n-k+1),if(k==n)1 else qbeta(.975,k+1,n-k))
 cat('actual M',B,'row mid-p',pp,'observed Stouffer',zobs,'\n')
 cat('Integer-distance reference trial p',(k+eq/2)/B,'k',k,'ties',eq,'CP',cp(k,B),'\n')
 # Recompute the observed production result from the integer ranks after
 # collapsing ONLY row X, as production does at zeroTol=100.
 zbad<-Reduce('+',lapply(ranks[-1],function(p)qnorm(floorp(p),lower.tail=FALSE)))
 kb<-sum(zbad>zobs);eb<-sum(zbad==zobs)
 cat('Collapsed-first-row trial p',(kb+eb/2)/B,'k',kb,'ties',eb,'CP',cp(kb,B),'\n')
 cat('These conditional CP intervals describe tail-count precision; the app does not display a trial CI above .001.\n')
 saveRDS(list(data=d,output=prod,raw=final,integerDistances=steps,rowP=pp,reference=c(k=k,eq=eq,B=B),collapsed=c(k=kb,eq=eb,B=B)),file.path(od,'snap-reference.rds'))
 # Verify the actual /analyze path accepts the unchanged CSV fixture.
 rd<-.apiReadUpload(file.path(od,'three-row-1e+07.csv'),'three-row.csv')
 print(.apiAnalyze(rd$data,seed=42)$results)
})
unit('parser-diagnostic',{
 calls<-list();be<-new.env(parent=environment(.ppParseBlock))
 be$.ppCountBracket<-function(pct,dec,N){out<-.ppCountBracket(pct,dec,N);print(list(pct=pct,dec=dec,N=N,out=out));out}
 b<-.ppParseBlock;environment(b)<-be
 pe<-new.env(parent=environment(parseBaselineTableJats));pe$.ppParseBlock<-b
 p<-parseBaselineTableJats;environment(p)<-pe
 r<-p(file.path(od,'page-183.xml'),trial='Audit',quiet=TRUE,pctApprox=TRUE)
 print(r$skipped)
})
