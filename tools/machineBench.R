# machineBench.R - is another computer worth using, and for what?
suppressWarnings(suppressPackageStartupMessages({
  library(dqrng); library(Rfast)
}))
tm <- function(e){t0<-Sys.time();force(e);as.numeric(difftime(Sys.time(),t0,units="secs"))}
cat("=========== IntegrityAnalysis machine benchmark ===========\n")
si <- Sys.info()
cat("host    :", si[["nodename"]], "\n")
cat("R       :", R.version.string, "\n")
# PHYSICAL CORES: ask the kernel, not R. detectCores(logical = FALSE)
# returns 16 on the Ubuntu compute node for a CPU with 8 physical cores
# (verified against lscpu and /proc/cpuinfo), which inflated this
# script's own "~13.6x if parallel" projection to nearly double the
# truth. corpus/parallelHelper.R carries the one implementation; source
# it when it is reachable rather than keeping a second copy in step.
# Run as `Rscript tools/machineBench.R` from the repo root, so the
# relative path holds; the fallback keeps this script standalone if it
# is ever copied to a bare machine to size it up.
nph <- "corpus/parallelHelper.R"
if (file.exists(nph)) source(nph, local = TRUE)
nc <- if (exists(".iaPhysicalCores")) .iaPhysicalCores() else
        parallel::detectCores(logical = FALSE)
nl <- parallel::detectCores(logical = TRUE)
cat("cores   :", nc, "physical /", nl, "logical\n\n")

# 1. MONTE CARLO - the P_Calc inner loop, one chunk
N <- 500; ch <- 10000; COLS <- 2; Nvec <- c(N,N); Ntot <- sum(Nvec)
dqset.seed(1); set.seed(1)
meansim <- dqrnorm(ch, 60, 1)
t_mc <- tm({
  MC <- matrix(NA_real_, ch, COLS)
  for (i in 1:COLS)
    MC[,i] <- round(rowmeans(round(
      matrix(rnorm(Nvec[i]*ch, rep(meansim, Nvec[i]), 10), nrow=ch), 1)), 1)
  Nmat <- matrix(Nvec, ch, COLS, byrow=TRUE)
  rowsums((MC - rowsums(MC*Nmat)/Ntot)^2)
})
draws <- ch * Ntot
cat(sprintf("1. Monte Carlo loop  : %6.2f s   %.2e draws/sec\n", t_mc, draws/t_mc))

# 2. GENERAL CPU - integer/FP mix, no RNG, no memory pressure
t_cpu <- tm({ x <- 0; for (i in 1:3e6) x <- x + sqrt(i) %% 7 })
cat(sprintf("2. scalar loop       : %6.2f s   (interpreter speed)\n", t_cpu))

# 3. MEMORY BANDWIDTH - the round() half of the Monte Carlo is this
M <- matrix(rnorm(5e6), nrow=1000)
t_mem <- tm(round(M, 1))
cat(sprintf("3. round() 5e6 cells : %6.2f s   %.2e cells/sec\n", t_mem, 5e6/t_mem))

# 4. DISK - corpus runs read thousands of PDFs
tmpf <- tempfile(); v <- as.raw(runif(2e6, 0, 255))
t_w <- tm(writeBin(v, tmpf)); t_r <- tm(readBin(tmpf, "raw", 2e6)); unlink(tmpf)
cat(sprintf("4. disk 2 MB w/r     : %6.3f / %6.3f s\n", t_w, t_r))

cat("\n--- what this machine could do IF the work were parallel ---\n")
cat(sprintf("  one corpus pass, sequential : 1 core  of %d\n", nl))
cat(sprintf("  same work at %d-way          : ~%.1fx faster\n", nc, nc*0.85))
cat("\nCompare machines on line 1 (Monte Carlo) and the core count.\n")
cat("Line 1 x cores is the number that matters for batch work.\n")
