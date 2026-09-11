# Independent fourth-pass audit, Codex, 2026-09-11; no production mutations.
# Change individual means/medians while preserving their weighted mean.
# These individual values do not otherwise enter the selected simulations.
source(file.path(Sys.getenv('INTEGRITY_AUDIT_OUTPUT'),'common.R'))
ns <- asNamespace('IntegrityAnalysis')
trace('.iaTieCounts',where=ns,print=FALSE,tracer=quote({
  if(length(sims)>=1000 && all(sims>=0))
    .GlobalEnv$.auditInputs[[length(.GlobalEnv$.auditInputs)+1L]] <- sims
}))
trace('P_Calc',where=ns,print=FALSE,exit=quote({
  .GlobalEnv$.auditFinal <- list(M=s,keyOf=keyOf,trialStat=trialStat,
    obs=vapply(rows,function(r)r$sim$obs,numeric(1)))
  .GlobalEnv$.auditGenerators <- lapply(rows,function(r)r$sim$simulate)
}))
records <- list()
spec <- rbind(expand.grid(kind=c('continuous','direct'),J=c(5,7),seed=42), expand.grid(kind='median',J=c(6,7,8,9),seed=42:43))
for(ii in seq_len(nrow(spec))) {
  kind<-as.character(spec$kind[ii]);J<-spec$J[ii];seed<-spec$seed[ii]
  id <- paste0('symmetric-refined-',kind,'-J',J,'-s',seed)
  d <- data.frame(TRIAL='T',ROW=rep(sprintf('V%02d',1:J),each=2),N=30,
    MEAN=0,SD=6,ROUND_MEAN=0,ROUND_DISPERSION=1,ROUND_OBSERVATION=0)
  if(kind=='direct'){d$N<-100;d$SD<-10}
  if(kind=='median'){d$N<-9;d$SD<-NA_real_;d$Q1<--1;d$Q3<-1}
  d$MEAN[5:6] <- c(-1,1)
  f <- file.path(out,paste0('fixture-',id,'.csv'));write.csv(d,f,row.names=FALSE)
  .auditInputs<-list();rd<-.apiReadUpload(f,basename(f))
  a<-isolate(.apiAnalyze(rd$data,seed=seed));stopifnot(a$ok)
  B<-.auditFinal$M;raw<-tail(.auditInputs,J);stopifnot(all(lengths(raw)==B))
  # With equal arm sizes and integer printed values, 2*statistic is
  # exactly the squared integer difference of the two printed values.
  codes<-lapply(raw,function(x)round(2*x));obs<-round(2*.auditFinal$obs)
  stopifnot(all(obs==c(0,0,4,rep(0,J-3))))
  pool<-unlist(codes);L<-length(pool)
  probs<-(rank(pool,ties.method='average')-.5)/L
  floor_ref<-function(p)pmin(pmax(p,1/(L+1)),.9999)
  scores<-rowSums(matrix(qnorm(floor_ref(probs),lower.tail=FALSE),B,J))
  op<-vapply(obs,function(o)(sum(pool<o)+.5*sum(pool==o))/L,numeric(1))
  observed<-sum(qnorm(floor_ref(op),lower.tail=FALSE))
  eq<-abs(scores-observed)<=1e-10*pmax(abs(scores),abs(observed))
  strict<-sum(scores>observed & !eq);ties<-sum(eq)
  # Every permutation of the observed states is a mathematical trial tie,
  # regardless of the estimated common mapping (provided it is common).
  mat<-do.call(cbind,codes)
  genuine<-rowSums(mat==0)==J-1 & rowSums(mat==4)==1
  # Reset both generators to the same stream. Individual printed means
  # differ, but all actual draws must agree under the unchanged null.
  draws<-lapply(c(1,3),function(i){set.seed(9173);dqset.seed(9173);.auditGenerators[[i]](1000)})
  stopifnot(identical(draws[[1]],draws[[2]]))
  write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
  cp<-c(if(strict==0)0 else qbeta(.025,strict,B-strict+1),
        if(strict+ties==B)1 else qbeta(.975,strict+ties+1,B-strict-ties))
  records[[id]]<-cbind(data.frame(case=id,kind=kind,J=J,seed=seed,
    keys=length(unique(.auditFinal$keyOf)),same_seed_null_draws_identical=TRUE,
    reference_strict=strict,reference_ties=ties,reference_midp=(strict+.5*ties)/B,
    reference_count_CI_lower=cp[1],reference_count_CI_upper=cp[2],
    observed_pattern_ties=sum(genuine),engine_strict=.auditFinal$trialStat$kG,
    engine_ties=.auditFinal$trialStat$kE),summary_row(a))
  saveRDS(list(integer_draws=codes,production=.auditFinal,reference_observed=observed,
    reference_strict=strict,reference_ties=ties),file.path(out,paste0('draws-',id,'.rds')))
  write.csv(do.call(rbind,records),file.path(out,'symmetric-refined-comparisons.csv'),row.names=FALSE)
  cat('DONE',id,'M',B,'p',summary_row(a)$p,'reference',(strict+.5*ties)/B,'\n');flush.console()
}
untrace('.iaTieCounts',where=ns);untrace('P_Calc',where=ns)
writeLines('Complete',file.path(out,'symmetric-refined-complete.txt'))
