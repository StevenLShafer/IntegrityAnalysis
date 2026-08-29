# parallelHelper.R - run a corpus pass across cores instead of one.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-28 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request, after a machine benchmark found the real bottleneck    #
# was not the CPU but the fact that NOTHING here was parallel.             #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# THE FINDING THAT PROMPTED IT. Steve asked whether to move work to a      #
# spare machine, reasoning that it depends on raw CPU speed. It does -     #
# for the CPU-bound passes. But a grep for mclapply / parLapply /          #
# %dopar% / makeCluster over corpus/ and R/ returned NOTHING: every        #
# corpus run - the 457-file end-to-end validation, the 93,834-table        #
# PubTables scan, the 5,080-trial Carlisle validation - used ONE core of   #
# SIXTEEN. A second machine at 1.3x single-core speed buys 1.3x; using     #
# the cores already present buys ~6.8x.                                    #
#                                                                          #
# WORKER COUNT: physical cores minus two (Steve: "leave 2 cores open for   #
# other stuff (e.g., this interface)"). PHYSICAL, not logical - the Monte  #
# Carlo is floating-point heavy and hyperthreading gives it very little,   #
# while oversubscription makes the machine unpleasant to use. Override     #
# with INTEGRITY_WORKERS for a machine with a different shape.             #
#                                                                          #
# TWO THINGS THIS GETS RIGHT THAT NAIVE PARALLELISM GETS WRONG:            #
#                                                                          #
# 1. RNG. Independent workers drawing from the default generator would     #
#    produce correlated or irreproducible streams. clusterSetRNGStream     #
#    gives each worker a separate L'Ecuyer substream from one seed, so a   #
#    parallel run is reproducible AND the workers are independent. The     #
#    p-values will NOT match a previous sequential run - a different       #
#    stream is a different simulation - but they are reproducible from     #
#    the seed, which sequential runs of these scripts were not: none of    #
#    validateEndToEnd, measureMisparse or buildParseOutcomes ever set a    #
#    seed at all.                                                          #
#                                                                          #
# 2. NO load_all IN WORKERS. Workers load the INSTALLED package. The       #
#    2026-08-25 Carlisle certification was contaminated by parse children  #
#    absorbing mid-run edits from a live tree; sixteen workers reading a   #
#    tree being edited would be that lesson multiplied.                    #
#                                                                          #
# Usage:                                                                   #
#   source("corpus/parallelHelper.R")                                      #
#   res <- iaParallel(items, function(x) { ... }, seed = 1)                #
#                                                                          #
# The worker function must be SELF-CONTAINED: it runs in a fresh R         #
# session with only the package attached and whatever `export` names it.   #
############################################################################

# Physical cores, asking the KERNEL rather than trusting R.
#
# Added 2026-08-29. parallel::detectCores(logical = FALSE) is not
# reliable everywhere: on the Ubuntu 26.04 compute node (Ryzen 7 4800U)
# it returns 16 for a CPU the kernel reports as 8 physical cores with 8
# hyperthreads - verified against both `lscpu -p=Core,Socket` and
# /proc/cpuinfo's "cpu cores" field. Believing R there would have
# started 14 workers on 8 cores: nearly 2x oversubscription, and the
# exact opposite of the headroom rule below. The failure is silent -
# the run completes, just slower and with the machine unusable - so
# nothing would have pointed at the cause.
#
# Order of preference: /proc/cpuinfo (authoritative on Linux, no
# subprocess), then R's guess, then a conservative 2.
.iaPhysicalCores <- function() {
  if (file.exists("/proc/cpuinfo")) {
    n <- tryCatch({
      info    <- readLines("/proc/cpuinfo", warn = FALSE)
      perPkg  <- as.integer(sub(".*:[[:space:]]*", "",
                                grep("^cpu cores", info, value = TRUE)))
      sockets <- unique(sub(".*:[[:space:]]*", "",
                            grep("^physical id", info, value = TRUE)))
      if (length(perPkg) && !anyNA(perPkg))
        perPkg[1] * max(1L, length(sockets)) else NA_integer_
    }, error = function(e) NA_integer_)
    if (!is.na(n) && n >= 1L) return(as.integer(n))
  }
  phys <- tryCatch(parallel::detectCores(logical = FALSE),
                   error = function(e) NA_integer_)
  if (is.na(phys) || phys < 1L) 2L else as.integer(phys)
}

# How many workers this machine should use.
#
# The minus-two rule is Steve's, and it is about a machine someone is
# SITTING AT. On a headless node nobody is competing for those cores,
# so set INTEGRITY_WORKERS to the full physical count there.
iaWorkers <- function() {
  env <- suppressWarnings(as.integer(Sys.getenv("INTEGRITY_WORKERS", "")))
  if (!is.na(env) && env > 0) return(env)
  max(1L, .iaPhysicalCores() - 2L)   # leave two for the desktop
}

# Run fn over items across a cluster. Returns a list in item order.
#
# checkpointed work: fn should write its own per-item artifact and return
# something small. That keeps the parent's memory flat and means a killed
# run resumes exactly as the sequential versions already do.
# libDir: the library workers load `packages` from. Defaults to the
# PARENT'S OWN path for the package, so a parent running from a snapshot
# library cannot end up with workers running a different build. Getting
# this wrong is silent: the run completes, the numbers are wrong, and
# nothing says which engine produced them.
iaParallel <- function(items, fn, export = character(0), seed = 1L,
                       packages = "IntegrityAnalysis", quiet = FALSE,
                       libDir = NULL) {
  n <- iaWorkers()
  if (n <= 1 || length(items) < 2) {
    if (!quiet) cat("running sequentially (", n, " worker)\n", sep = "")
    return(lapply(items, fn))
  }
  n <- min(n, length(items))
  if (!quiet)
    cat("parallel: ", n, " workers over ", length(items), " items\n", sep = "")

  cl <- parallel::makeCluster(n)
  on.exit(parallel::stopCluster(cl), add = TRUE)

  # Reproducible, independent substreams - see the header.
  parallel::clusterSetRNGStream(cl, seed)

  # Workers attach the INSTALLED package, never the live tree.
  if (is.null(libDir) && "IntegrityAnalysis" %in% packages) {
    f <- find.package("IntegrityAnalysis", quiet = TRUE)
    if (length(f)) libDir <- dirname(f[1])
  }
  parallel::clusterExport(cl, c("packages", "libDir"), envir = environment())
  parallel::clusterEvalQ(cl, {
    # PUT libDir ON THE WORKER'S .libPaths(), not just lib.loc
    # (2026-08-29). lib.loc affects only that one library() call. It
    # does NOT make the library visible to anything the worker itself
    # spawns - and these workers spawn GRANDCHILDREN:
    # parseBaselineTableFiles() runs one subprocess per PDF and hands
    # each the WORKER's .libPaths(). Without this line every
    # grandchild failed to load IntegrityAnalysis, returned NULL, and
    # measureMisparse reported "parsed: 0" over 1,110 files with no
    # error anywhere - while the same script on 12 files (one batch,
    # so the SEQUENTIAL path) parsed 11 of them correctly.
    #
    # That asymmetry is the tell, and it is worth remembering: a smoke
    # test small enough to stay sequential does not exercise this at
    # all. Test the parallel path with more items than `batch`.
    if (!is.null(libDir)) .libPaths(c(libDir, .libPaths()))
    for (p in packages)
      suppressWarnings(suppressPackageStartupMessages(
        if (is.null(libDir)) library(p, character.only = TRUE)
        else library(p, character.only = TRUE, lib.loc = libDir)))
    # shiny FIRST and non-negotiably: validateData() calls isolate(),
    # which is Shiny's. Omitting it made every worker fail with
    # 'could not find function "isolate"' on exactly the files that
    # succeeded sequentially - a 3x speedup that produced 0 results
    # instead of 33. The parent process had shiny attached, so the
    # sequential path never noticed the dependency.
    suppressWarnings(suppressPackageStartupMessages({
      library(shiny); library(foreach); library(MBESS)
      library(Rfast); library(dqrng); library(openxlsx)
    }))
    options(ECHO_OUTPUT_COMMENTS = NA)
    NULL
  })
  if (length(export))
    parallel::clusterExport(cl, export, envir = parent.frame())

  # LOAD BALANCING matters here: parse times vary by an order of
  # magnitude across PDFs, so a static split leaves workers idle while
  # one grinds through a pathological file. parLapplyLB hands out work
  # one item at a time.
  parallel::parLapplyLB(cl, items, fn)
}
