# Trace only to copy simulated statistics; preserve all production outputs.
# Rank the reference trial by its integer number of minimum-state rows.
source('docs/audits/evidence-2026-09-10-full/common.R')
ns <- asNamespace('IntegrityAnalysis')
trace('.iaTieRank',where=ns,print=FALSE,tracer=quote({
  .GlobalEnv$.auditRankInputs[[length(.GlobalEnv$.auditRankInputs)+1L]] <- x
}))
trace('P_Calc',where=ns,print=FALSE,exit=quote({
  .GlobalEnv$.auditFinalSums <- list(M=s,zObs=zObs,sumZ=sumZ,rowStat=rowStat)
}))
ans <- list()
for(spec in list(c(9,3),c(14,7))) {
  J <- spec[1]; bad <- spec[2]
  id <- paste0('ordinary-N100-J',J,'-bad',bad)
  .auditRankInputs <- list()
  f <- file.path(out,paste0('fixture-',id,'.csv'))
  rd <- .apiReadUpload(f,basename(f))
  a <- shiny::isolate(.apiAnalyze(rd$data,seed=42));stopifnot(a$ok)
  rr <- tail(.auditRankInputs,J)
  B <- .auditFinalSums$M;stopifnot(all(lengths(rr)==B))
  good <- do.call(cbind,lapply(rr,function(x) as.integer(x==0)))
  G <- rowSums(good)
  referenceLess <- sum(G>J-1);referenceTies <- sum(G==J-1)
  engineGreater <- sum(.auditFinalSums$sumZ>.auditFinalSums$zObs)
  engineTies <- sum(.auditFinalSums$sumZ==.auditFinalSums$zObs)
  tie <- G==J-1
  # Categorize genuine reference ties by the production comparison.
  eqAbove <- sum(.auditFinalSums$sumZ[tie]>.auditFinalSums$zObs)
  eqEqual <- sum(.auditFinalSums$sumZ[tie]==.auditFinalSums$zObs)
  eqBelow <- sum(.auditFinalSums$sumZ[tie]<.auditFinalSums$zObs)
  saveRDS(list(good=good,production=.auditFinalSums),file.path(out,paste0('same-draw-',id,'.rds')))
  cp <- function(k1,k2) c(if(k1==0)0 else qbeta(.025,k1,B-k1+1),
    if(k1+k2==B)1 else qbeta(.975,k1+k2+1,B-k1-k2))
  engineCI <- cp(engineGreater,engineTies)
  refCI <- cp(referenceLess,referenceTies)
  q <- 100/199
  ans[[id]] <- data.frame(J=J,bad=bad,M=B,engine_p=(engineGreater+engineTies/2)/B,
    engine_CI_lower=engineCI[1],engine_CI_upper=engineCI[2],
    integer_reference_p=(referenceLess+referenceTies/2)/B,
    integer_CI_lower=refCI[1],integer_CI_upper=refCI[2],
    exact_p=q^J+.5*J*(1-q)*q^(J-1),
    all_good=referenceLess,genuine_ties=referenceTies,
    ties_counted_greater=eqAbove,ties_counted_equal=eqEqual,ties_counted_below=eqBelow)
  write.csv(do.call(rbind,ans),file.path(out,'same-draw-combination.csv'),row.names=FALSE)
  cat('DONE',id,'\n');flush.console()
}
untrace('.iaTieRank',where=ns);untrace('P_Calc',where=ns)
writeLines('Same-draw integer comparison complete.',file.path(out,'same-draw-combination-complete.txt'))
