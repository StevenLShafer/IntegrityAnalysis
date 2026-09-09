# Targeted regression checks, current tree. GPT-6 (Codex), 2026-09-09 brief.
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
od<-'docs/audits/evidence-2026-09-09';sink(file.path(od,'verification.txt'),split=TRUE)
all<-list()
for(f in c('test-failsafe-table.R','test-text-precision.R','test-screen-2026-09-08.R','test-sd-rounding-draw.R','test-tie-criterion.R','test-known-answer.R')) {
 cat('FILE',f,'\n')
 r<-testthat::test_file(file.path('tests/testthat',f),reporter='summary');all[[f]]<-as.data.frame(r)
 saveRDS(all,file.path(od,'verification.rds'))
}
cat('COUNTS\n');for(n in names(all)){d<-all[[n]];print(data.frame(file=n,passed=sum(d$passed),failed=sum(d$failed),errors=sum(d$error),skipped=sum(d$skipped)))}
sink()
