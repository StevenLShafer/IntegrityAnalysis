# Re-executed for the fourth full audit at 7c6583f, Codex, 2026-09-11.
# Codex, 2026-09-11. Additional executable contract and reference evidence.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
for(f in list.files(file.path(src,'tests/testthat'),'^helper.*[.]R$',full.names=TRUE))source(f)
parsed <- list(found=TRUE,notes='',arms=list(list(name='A',n=90L),list(name='B',n=91L)),
  continuous=list(),categorical=list(list(label='Category',categories=list('N','MEAN','SD'),
    values=list(list(arm='A',counts=list(30L,50L,10L)),list(arm='B',counts=list(30L,51L,10L))))))
reply <- list(stop_reason='end_turn',content=list(list(type='text',
  text=as.character(jsonlite::toJSON(parsed,auto_unbox=TRUE)))))
jsonlite::write_json(parsed,file.path(out,'fixture-AI-reserved-levels.json'),auto_unbox=TRUE,pretty=TRUE)
pdf <- syntheticPdfMeanSD()
r <- testthat::with_mocked_bindings(
  parseBaselineTableAI(pdf,trial='T',apiKey='LOCAL-MOCK-ONLY',quiet=TRUE),
  .ppClaudePost=function(body,apiKey,timeout=300)reply,.package='IntegrityAnalysis')
a <- isolate(.apiAnalyze(r$data,seed=42));stopifnot(a$ok)
write.csv(r$data,file.path(out,'AI-converted-template.csv'),row.names=FALSE)
write.csv(a$results,file.path(out,'AI-category-results.csv'),row.names=FALSE)
# Enumerate the transposed 2x3 table as a 3x2 table, from allocation counts.
tab <- t(rbind(c(30,50,10),c(30,51,10)));n<-rowSums(tab);C<-sum(tab[,1]);total<-sum(n)
x<-as.matrix(expand.grid(lapply(n,function(ni)0:ni)));x<-x[rowSums(x)==C,,drop=FALSE]
E<-n*C/total
stat<-rowSums(sweep(x,2,E,'-')^2*matrix(rep(1/E+1/(n-E),each=nrow(x)),nrow(x)))
pr<-exp(rowSums(sapply(seq_along(n),function(j)lchoose(n[j],x[,j])))-lchoose(total,C))
obs<-sum((tab[,1]-E)^2*(1/E+1/(n-E)));stat<-round(stat,11);obs<-round(obs,11)
ref<-sum(pr[stat<obs])+.5*sum(pr[stat==obs]);stopifnot(abs(sum(pr)-1)<1e-12)
write.csv(cbind(data.frame(seed=42,exact_midp=ref),summary_row(a)),file.path(out,'AI-exact-reference.csv'),row.names=FALSE)
# The default selector enumerates free cell brackets; a partition is explicit.
lo<-matrix(49L,2,2);hi<-matrix(51L,2,2);cnt<-matrix(NA_integer_,2,2)
free<-.ppFailsafeTableFill(lo,hi,cnt,c(100,100))
part<-.ppFailsafeTableFill(lo,hi,cnt,c(100,100),partition=TRUE)
stopifnot(free$resolved,part$resolved,free$nTables==81,part$nTables==9)
write.csv(data.frame(mode=c('default free','explicit partition'),tables=c(free$nTables,part$nTables),
  independently_expected=c(3^4,3^2)),file.path(out,'nonpartition-count.csv'),row.names=FALSE)
# The pool guard tests the planned maximum, before any draws: exactly 100 rows
# at ceiling 100,000 are accepted; 101 are refused. High-statistic rows need
# only the first stage here; this checks the boundary, not peak memory at it.
boundary<-list()
for(J in c(100,101)){
  d<-data.frame(TRIAL='T',ROW=rep(sprintf('V%03d',1:J),each=2),N=NA_real_,MEAN=NA_real_,SD=NA_real_,
    YES=rep(c(0,2),J),NO=rep(c(2,0),J))
  write.csv(d,file.path(out,paste0('fixture-pool-boundary-',J,'.csv')),row.names=FALSE)
  tm<-system.time(b<-isolate(.apiAnalyze(d,seed=42)))
  boundary[[as.character(J)]]<-data.frame(rows=J,planned_held_draws=J*100000,ok=b$ok,
    stage=if(is.null(b$stage))'' else b$stage,seconds=tm[['elapsed']],
    actual_M=if(b$ok)paste(unique(b$results$M[!is.na(b$results$M)]),collapse=';') else '',
    reason=if(!b$ok)paste(b$issues$note,collapse=';') else '')
}
stopifnot(boundary[['100']]$ok,!boundary[['101']]$ok,boundary[['101']]$stage=='analysis')
write.csv(do.call(rbind,boundary),file.path(out,'pool-boundary.csv'),row.names=FALSE)
ans<-list()
for(id in c('continuous','median','category','shared'))for(m in c(1000,100000)){
  stem<-paste0('comparison-',id,'-m',m)
  old<-readRDS(file.path(out,paste0(stem,'-old.rds')));new<-readRDS(file.path(out,paste0(stem,'-target.rds')))
  get<-function(x,field)as.character(x[[field]][which(x$KIND=='summary')[1]])
  ans[[stem]]<-data.frame(case=id,ceiling=m,identical_entire_output=identical(old,new),
    old_M=paste(unique(old$M[!is.na(old$M)]),collapse=';'),new_M=paste(unique(new$M[!is.na(new$M)]),collapse=';'),
    old_p=get(old,'P'),old_CI=get(old,'CI95'),new_p=get(new,'P'),new_CI=get(new,'CI95'))
}
write.csv(do.call(rbind,ans),file.path(out,'old-target-comparison.csv'),row.names=FALSE)
writeLines('Complete',file.path(out,'supplemental-complete.txt'))
