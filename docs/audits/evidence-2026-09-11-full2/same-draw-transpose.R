# Re-executed for the fourth full audit at 7c6583f, Codex, 2026-09-11.
# Codex, 2026-09-11. Copy statistics without changing draws or calculations.
# The reference ranks a trial by its INTEGER number of homogeneous tables.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'), 'common.R'))
ns <- asNamespace('IntegrityAnalysis')
trace('.iaTieCounts',where=ns,print=FALSE,tracer=quote({
  if (length(sims)>=1000 && all(sims>=0))
    .GlobalEnv$.auditInputs[[length(.GlobalEnv$.auditInputs)+1L]] <- sims
}))
trace('P_Calc',where=ns,print=FALSE,exit=quote({
  .GlobalEnv$.auditFinal <- list(M=s,zObs=zObs,sumZ=sumZ,trialStat=trialStat,
    keyOf=keyOf,shared=shared,rowStat=rowStat)
}))
ans <- list()
for(J in c(9,14)) for(tag in c('none','extreme')) {
  id <- paste0('transpose-J',J,'-',tag,'-s42')
  .auditInputs <- list()
  f <- file.path(out,paste0('fixture-',id,'.csv'))
  rd <- .apiReadUpload(f,basename(f))
  a <- isolate(.apiAnalyze(rd$data,seed=42));stopifnot(a$ok)
  rr <- tail(.auditInputs,J);B <- .auditFinal$M
  stopifnot(all(lengths(rr)==B),identical(a$results,readRDS(file.path(out,paste0('result-',id,'.rds')))$results))
  good <- do.call(cbind,lapply(rr,function(x)as.integer(x==0)))
  G <- rowSums(good);less <- sum(G>J-1);ties <- sum(G==J-1)
  delta <- .auditFinal$sumZ-.auditFinal$zObs
  eq <- abs(delta)<=1e-10*pmax(abs(.auditFinal$sumZ),abs(.auditFinal$zObs))
  actual <- .auditFinal$trialStat
  cp <- function(k1,k2)c(if(k1==0)0 else qbeta(.025,k1,B-k1+1),
    if(k1+k2==B)1 else qbeta(.975,k1+k2+1,B-k1-k2))
  refCI <- cp(less,ties);diagCI <- cp(actual$kG,actual$kE)
  q <- 100/199
  ans[[id]] <- cbind(data.frame(case=id,J=J,seed=42,actual_M=B,number_of_keys=length(unique(.auditFinal$keyOf)),
    shared_rows=sum(.auditFinal$shared),exact_p=q^J+.5*J*(1-q)*q^(J-1),
    integer_reference_p=(less+ties/2)/B,integer_CI_lower=refCI[1],integer_CI_upper=refCI[2],
    engine_diagnostic_CI_lower=diagCI[1],engine_diagnostic_CI_upper=diagCI[2],
    all_homogeneous=less,genuine_ties=ties,
    genuine_ties_counted_greater=sum(G==J-1 & delta>0 & !eq),
    genuine_ties_counted_equal=sum(G==J-1 & eq),
    genuine_ties_counted_below=sum(G==J-1 & delta<0 & !eq)),summary_row(a))
  saveRDS(list(good=good,production=.auditFinal),file.path(out,paste0('same-draw-',id,'.rds')))
  write.csv(do.call(rbind,ans),file.path(out,'same-draw-transpose.csv'),row.names=FALSE)
  cat('DONE',id,'keys',length(unique(.auditFinal$keyOf)),'ties',ties,'\n');flush.console()
}
untrace('.iaTieCounts',where=ns);untrace('P_Calc',where=ns)
writeLines('Complete',file.path(out,'same-draw-transpose-complete.txt'))
