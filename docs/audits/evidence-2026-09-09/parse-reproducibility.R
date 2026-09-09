# Independent audit, GPT-6 (Codex), 2026-09-09 brief, executed 2026-09-08.
# Same synthetic PDF, two pre-parse RNG states; analysis seed is reset to 42.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od <- 'docs/audits/evidence-2026-09-09'
sink(file.path(od,'parse-reproducibility.txt'),split=TRUE)
source('tests/testthat/helper-syntheticPdf.R')
f <- file.path(od,'selection-noise.pdf'); vx <- c(300,420)
cells <- c(list(list(x=72,y=80,text='Table 1. Baseline patient characteristics',adj=0)),
  rowCells(110,'',c('Control','Treatment'),vx),
  rowCells(128,'',c('(n = 5000)','(n = 5000)'),vx),
  rowCells(150,'Age (yr)',c('45.3 (12.1)','46.1 (11.8)'),vx),
  rowCells(180,'Sex, %',c('',''),vx),
  rowCells(205,'Male',c('50','50'),vx,labelX=82),
  rowCells(225,'Female',c('50','50'),vx,labelX=82))
makeTablePdf(f,cells)
for (s in c(1,3)) {
  cat('Pre-parse seed:',s,'\n');set.seed(s);dqset.seed(s)
  r <- parseBaselineTableHeuristics(f,pctApprox=TRUE,quiet=TRUE)
  print(r$data); print(r$derivedCells)
  saveRDS(r,file.path(od,paste0('parse-seed-',s,'.rds')))
  d <- r$data[r$data$ROW=='Sex, %',];d$TRIAL <- 'T'
  v <- shiny::isolate(validateData(d));cat('Validation failed:',v$FAIL,'\n')
  set.seed(42);dqset.seed(42)
  if(!v$FAIL) print(shiny::isolate(P_Calc('T',v$DATA,v$CategoryNames,100000)))
}
sink()
