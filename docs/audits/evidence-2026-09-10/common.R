# Independent statistical audit of ae37f0e, Codex, 2026-09-10.
# Only synthetic inputs. No modifications to audited package code.
root <- 'C:/dev/IntegrityAnalysis'
od <- file.path(root,'docs/audits/evidence-2026-09-10')
.libPaths(c(file.path(root,'.audit-2026-09-10/library'),.libPaths()))
setwd(file.path(root,'.audit-2026-09-10/source'))
suppressPackageStartupMessages({library(shiny);library(dqrng);library(foreach);library(Rfast);library(MBESS);pkgload::load_all()})
unit <- function(name,expr) {
 args <- commandArgs(TRUE)
 if(length(args) && !name %in% args)return(invisible(NULL))
 sink(file.path(od,paste0(name,'.txt')),split=TRUE)
 cat(name,format(Sys.time()),'\n');t <- proc.time()[3]
 tryCatch(force(expr),error=function(e) {cat('ERROR',conditionMessage(e),'\n');traceback()})
 cat('elapsed',proc.time()[3]-t,'seconds\n');sink()
}
run <- function(d,m=100000,seed=42) {
 set.seed(seed);dqset.seed(seed);v <- shiny::isolate(validateData(d))
 cat('validation failed:',v$FAIL,'\n')
 if(v$FAIL){print(v$issues);return(v)}
 z <- shiny::isolate(P_Calc('Audit',v$DATA,v$CategoryNames,m));print(z);invisible(z)
}
catframe <- function(tab) {
 d <- data.frame(TRIAL='Audit',ROW='Category',N=rep(NA_real_,nrow(tab)),MEAN=NA_real_,SD=NA_real_)
 for(j in seq_len(ncol(tab)))d[[paste0('C',j)]] <- tab[,j]
 d
}
