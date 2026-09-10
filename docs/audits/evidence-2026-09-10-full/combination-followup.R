# Diagnose the discrete-combination disagreement without changing engine output.
# All rows have identical fixed margins. An exit trace only records the final
# Monte Carlo counts/sums; it does not replace any arithmetic or random draw.
source('docs/audits/evidence-2026-09-10-full/common.R')
ns <- asNamespace('IntegrityAnalysis')
trace('P_Calc', where=ns, print=FALSE, exit=quote({
  assign('.auditCombination', list(M=s, sumZ=sumZ, zObs=zObs, rowStat=rowStat), envir=.GlobalEnv)
}))
make_combination <- function(J, bad=1) do.call(rbind,lapply(seq_len(J),function(j)
  data.frame(TRIAL='Audit', ROW=sprintf('V%02d',j), N=NA_real_, MEAN=NA_real_, SD=NA_real_,
             CAT1=if(j %in% bad)c(0,2) else c(1,1),
             CAT2=if(j %in% bad)c(2,0) else c(1,1))))
rows <- list()
for(J in c(15,23)) {
  d <- make_combination(J)
  for(seed in c(42,43,44)) {
    # CSV -> API reader -> API analysis -> validation -> P_Calc.
    id <- paste0('combination-J',J,'-seed',seed)
    path <- file.path(out,paste0('fixture-',id,'.csv'))
    write.csv(d,path,row.names=FALSE,na='')
    rd <- .apiReadUpload(path,basename(path)); stopifnot(rd$ok)
    a <- shiny::isolate(.apiAnalyze(rd$data,seed=seed)); stopifnot(a$ok)
    write.csv(a$results,file.path(out,paste0('result-',id,'.csv')),row.names=FALSE)
    capture <- .auditCombination
    saveRDS(capture,file.path(out,paste0('capture-',id,'.rds')))
    M <- capture$M
    kGood <- vapply(seq_len(J),function(i) if(i==1) capture$rowStat[[i]]$kLess else
      capture$rowStat[[i]]$kEq,numeric(1))
    # Engine's own empirical row score mapping; summation in the same row order.
    zGood <- qnorm((kGood/2)/M,lower.tail=FALSE)
    zBad <- qnorm((kGood+(M-kGood)/2)/M,lower.tail=FALSE)
    theoretical <- (2/3)^J + .5*J*(1/3)*(2/3)^(J-1)
    for(b in seq_len(J)) {
      zz <- 0
      for(i in seq_len(J)) zz <- zz + if(i==b) zBad[i] else zGood[i]
      kg <- sum(capture$sumZ>zz); ke <- sum(capture$sumZ==zz)
      lo <- if(kg==0) 0 else qbeta(.025,kg,M-kg+1)
      hi <- if(kg+ke==M) 1 else qbeta(.975,kg+ke+1,M-kg-ke)
      rows[[length(rows)+1]] <- data.frame(J=J,seed=seed,bad_position=b,M=M,
        p=(kg+ke/2)/M,kGreater=kg,kEqual=ke,MC_lower=lo,MC_upper=hi,
        exact_population_midp=theoretical,reference_outside=theoretical<lo||theoretical>hi,
        at_001_disagrees=((kg+ke/2)/M<.01)!=(theoretical<.01))
    }
    write.csv(do.call(rbind,rows),file.path(out,'combination-position-reference.csv'),row.names=FALSE)
    cat('DONE J',J,'seed',seed,'M',M,'reported',a$results$P[which(a$results$KIND=='summary')],
        'CI',a$results$CI95[which(a$results$KIND=='summary')], '\n');flush.console()
  }
}
untrace('P_Calc',where=ns)
writeLines('Combination diagnostic complete.',file.path(out,'combination-followup-complete.txt'))
