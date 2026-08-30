# validateEndToEnd.R - does the PARSER move the verdict?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-27 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction, as item 3 of "what have I not asked that I should    #
# have asked today".                                                       #
#                                                                          #
# THE GAP. The headline agreement - r = 0.9930 across 5,080 trials -       #
# comes from validateCarlisle2017.R, which reads Carlisle's One Sheet:     #
# his HAND-CURATED numbers. It never calls parseBaselineTable (grep the    #
# file; the count is zero). So it validates the MONTE CARLO, with the      #
# parser entirely out of the loop.                                         #
#                                                                          #
# Every real use runs PDF -> parser -> verdict.                            #
#                                                                          #
# There IS an end-to-end run - runMassTest.R over corpus/TEST - but        #
# buildTestSet.R defines that set as PDFs which (a) fully parse, (b) have  #
# a Carlisle PMID, and (c) are VALUE-VERIFIED against his One Sheet. It    #
# is selected ON THE OUTCOME BEING MEASURED. Sixty-one articles, chosen    #
# because their parse already matched. That cannot detect parse-induced    #
# error; it excludes it by construction.                                   #
#                                                                          #
# WHAT THIS MEASURES INSTEAD. Every parsed PDF that maps to a Carlisle     #
# trial with a validated p - 457 articles, no value filter, parse errors   #
# included - run through the real pipeline, compared against Carlisle's    #
# stored p on the log scale (Steve's specification: "0.0001 is as far      #
# from 0.001 as the latter is from 0.01").                                 #
#                                                                          #
# THE CONTRAST IS THE POINT. results.csv already holds the CURATED error   #
# (ours vs carlisle, starting from his numbers). This run gives the        #
# PARSED error (ours vs carlisle, starting from the PDF). The difference   #
# between those two distributions is the parser's contribution, isolated.  #
#                                                                          #
# And the SIGN matters more than the spread. A parser that adds symmetric  #
# noise degrades precision. A parser that shifts p systematically DOWNWARD #
# manufactures alarm - false accusations - and one that shifts it upward   #
# hides fraud. Those are different failures and only a signed statistic    #
# separates them, so both are reported.                                    #
#                                                                          #
# HOLDOUT AWARE. corpus/Holdout.csv splits development from holdout; the   #
# report breaks results down both ways, because a parser tuned on the      #
# development half may well look better there.                             #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/validateEndToEnd.R [maxFiles]                           #
#   Resumable: one checkpoint per PDF under the work directory, so a       #
#   crash costs at most one article and a rerun skips finished work.       #
############################################################################

suppressMessages(library(openxlsx))
root    <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
workDir <- Sys.getenv("E2E_WORKDIR", file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "e2e_work_cont"))
outCsv  <- file.path(root, "corpus", "EndToEndValidation.csv")
dir.create(workDir, showWarnings = FALSE, recursive = TRUE)

args <- commandArgs(trailingOnly = TRUE)
maxFiles <- if (length(args) >= 1) as.integer(args[1]) else 0L

# The engine must come from an INSTALLED library, never load_all of the
# live tree: the 2026-08-25 Carlisle certification was contaminated by
# parse children absorbing mid-run edits (AGENTS.md, corpus README).
# SNAPSHOT LIBRARY, named explicitly (2026-08-29), same discipline as
# measureMisparse. INTEGRITY_SNAPSHOT_LIB points at a library built by
# `R CMD INSTALL --library=<dir> .` from a known commit. Without it the
# run silently uses whatever is on .libPaths(), which is how a STALE
# build produced the corroboration figure for two days.
#
# READ IT BEFORE THE CHECK BELOW. The check has to look in the library
# the run will actually load from (fixed 2026-08-29): with no lib.loc,
# requireNamespace() searches only the default .libPaths(), so on a
# machine where the package is installed ONLY in the snapshot library -
# the recommended setup - this refused to start; and on a machine that
# also had a copy on the default path it passed by finding THAT one,
# which is the stale-build hazard the paragraph above warns about.
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
# PUT IT ON .libPaths(), not just lib.loc (fixed 2026-08-29). Two things
# depend on it being there, and lib.loc reaches neither:
#
#   1. The check below, which must ask about the library this run will
#      actually load from - not "is some copy installed anywhere".
#   2. THE SUBPROCESS CHILDREN. parseBaselineTableFiles() hands each
#      child the PARENT'S .libPaths(); with the snapshot library absent
#      from it, every child failed to load the package and returned
#      NULL, and the run reported "parsed: 0" with no error anywhere.
#
# Both symptoms were invisible on a machine that also had a copy on the
# default path - which is exactly the stale-build hazard described
# above, silently doing the work the snapshot library was meant to do.
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
if (!nzchar(libDir)) libDir <- NULL
if (!requireNamespace("IntegrityAnalysis", quietly = TRUE,
                      lib.loc = libDir))
  stop("IntegrityAnalysis is not installed in ",
       if (is.null(libDir)) "THIS R's library path" else libDir,
       " - install it there first (R CMD INSTALL --library=<dir> .)",
       call. = FALSE)
suppressWarnings(suppressPackageStartupMessages({
  if (is.null(libDir)) library(IntegrityAnalysis)
  else library(IntegrityAnalysis, lib.loc = libDir)
  library(shiny); library(openxlsx)
  library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))
cat("engine: version",
    as.character(utils::packageVersion("IntegrityAnalysis",
                                       lib.loc = libDir)),
    " commit ",
    tryCatch({ s <- IntegrityAnalysis::buildCommit()
               if (is.na(s)) "unknown" else substr(s, 1, 8) },
             error = function(e) "unknown"), "\n")
options(ECHO_OUTPUT_COMMENTS = NA)

## ---- build the eligible set --------------------------------------------
w <- read.xlsx(file.path(root, "Carlisle Data with PMIDs and DOIs.xlsx"),
               sheet = "All Data")
w$TRIAL <- paste(w$Journal, w$trial)
val <- read.csv(file.path(root, ".NewCarlisle", "validation2017",
                          "results.csv"), stringsAsFactors = FALSE)
val <- merge(val, w[, c("TRIAL", "PMID")], by = "TRIAL", all.x = TRUE)
val <- val[!is.na(val$PMID), ]

map <- read.csv(file.path(root, "corpus", "pmid_map.csv"),
                stringsAsFactors = FALSE)
po  <- read.csv(file.path(root, "corpus", "ParseOutcomes.csv"),
                stringsAsFactors = FALSE)
po$PMID <- ifelse(is.na(po$PMID) | !nzchar(as.character(po$PMID)),
                  map$PMID[match(po$PDF, map$PDF)], po$PMID)
parsed <- po[po$OUTCOME == "successfully parsed" & !is.na(po$PMID), ]

elig <- merge(parsed[, c("PDF", "PMID")],
              val[, c("PMID", "ours", "carlisle", "TRIAL")], by = "PMID")
elig <- elig[!duplicated(elig$PDF), ]

hp <- file.path(root, "corpus", "Holdout.csv")
if (file.exists(hp)) {
  h <- read.csv(hp, stringsAsFactors = FALSE)
  elig$SET <- h$SET[match(elig$PDF, h$PDF)]
} else elig$SET <- NA_character_

cat("eligible:", nrow(elig), "PDFs (corpus/TEST has 61, value-filtered)\n")
if (maxFiles > 0) elig <- utils::head(elig, maxFiles)

## ---- run the real pipeline, one checkpoint per PDF ---------------------
# PARALLEL since 2026-08-28. This loop was sequential, using one core of
# sixteen; per-PDF checkpointing already made the work independent, so
# the only thing missing was a cluster. Worker count is physical cores
# minus two (Steve's rule) - see corpus/parallelHelper.R for why
# physical rather than logical, and for the RNG handling.
source(file.path(root, "corpus", "parallelHelper.R"))
pdfRoot <- Sys.getenv("INTEGRITY_CORPUS", "C:/temp/journals")

oneFile <- function(i) {
  ck <- file.path(workDir, paste0(gsub("[^A-Za-z0-9]", "_", elig$PDF[i]),
                                  ".rds"))
  if (file.exists(ck)) return("cached")
  path <- file.path(pdfRoot, elig$PDF[i])
  rec <- list(PDF = elig$PDF[i], PMID = elig$PMID[i], TRIAL = elig$TRIAL[i],
              SET = elig$SET[i], curated = elig$ours[i],
              carlisle = elig$carlisle[i], parsedP = NA_real_,
              status = "not attempted")
  if (!file.exists(path)) {
    rec$status <- "pdf missing"
  } else {
    r <- tryCatch({
      # parseBaselineTableFiles returns ONE ROW PER FILE with a `result`
      # LIST COLUMN holding the ParsePDFTable - not a $data frame. The
      # first version of this script assumed $data, got NULL for every
      # file, and reported "parse produced nothing" three times out of
      # three. A uniform failure across every input is the signature of a
      # harness bug, not a parser finding, and it would have been easy to
      # write up as one.
      pr <- parseBaselineTableFiles(path, quiet = TRUE)
      tab <- if (is.data.frame(pr) && "result" %in% names(pr) &&
                 length(pr$result)) pr$result[[1]] else NULL
      d <- if (!is.null(tab) && is.list(tab) && !is.null(tab$data))
             tab$data else NULL
      if (is.null(d) || !nrow(d)) list(status = "parse produced nothing")
      else {
        # validateData and P_Calc are INTERNAL - the package exports
        # the parse entry points and run_app, not the analysis pipeline.
        # library() alone does not make them visible.
        v <- IntegrityAnalysis:::validateData(d)
        if (isTRUE(v$FAIL)) list(status = "validation failed")
        else {
          # SCOPE MATCH, and it is not optional. Carlisle's stored p
          # covers CONTINUOUS variables only. runMassTest.R has a
          # "continuous" mode for exactly this reason (Steve,
          # 2026-08-18) - categorical lines are those with NA MEAN, and
          # they are dropped with the category columns so the two sides
          # measure the same thing.
          #
          # The first full run of this script did NOT do that, and its
          # correlation of 0.36 was therefore part parser error and part
          # apples-to-oranges. Reporting that number as "the parser's
          # contribution" would have overstated the damage, in a
          # direction that happens to look like diligence.
          DATA <- v$DATA[!is.na(v$DATA$MEAN), , drop = FALSE]
          OUT <- NULL
          # No return() here: this block is a tryCatch EXPRESSION, not a
          # function body, so return() threw "no function to return
          # from" on 17 articles - a harness error that looked like a
          # parse status in the report.
          if (nrow(DATA))
            for (tr in unique(DATA$TRIAL))
              OUT <- rbind(OUT, IntegrityAnalysis:::P_Calc(
                              tr, DATA, NULL, 100000))
          s <- if (is.null(OUT)) OUT else
                 OUT[!is.na(OUT$ROW) & OUT$ROW == "Summary", , drop = FALSE]
          if (is.null(s)) s <- data.frame(P = numeric(0))
          p <- suppressWarnings(as.numeric(s$P))
          p <- p[is.finite(p)]
          if (!length(p)) list(status = "no summary p")
          else list(status = "ok", p = p[1])
        }
      }
    }, error = function(e) list(status = paste("error:",
                                  substr(conditionMessage(e), 1, 60))))
    rec$status <- r$status
    if (identical(r$status, "ok")) rec$parsedP <- r$p
  }
  saveRDS(rec, ck)
  rec$status
}

t0 <- Sys.time()
invisible(iaParallel(seq_len(nrow(elig)), oneFile,
                     export = c("elig", "workDir", "pdfRoot"),
                     libDir = libDir))
cat("pipeline pass took",
    round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
    "min
")

## ---- assemble and report ------------------------------------------------
recs <- lapply(list.files(workDir, pattern = "[.]rds$", full.names = TRUE),
               readRDS)
res <- do.call(rbind, lapply(recs, function(x)
  data.frame(x[c("PDF","PMID","TRIAL","SET","curated","carlisle",
                 "parsedP","status")], stringsAsFactors = FALSE)))
# IDENTITY STAYS LOCAL (2026-08-29). Every row of this table joins a
# trial to a baseline-homogeneity p-value. Published with identifiers -
# as it was, 457 rows in a public repository - that is an implicit
# accusation with no opportunity to reply, which is exactly what Steve
# argued should have been withdrawn from Carlisle's 2017 paper. The
# validation statistics need PAIRED values, not identities, so the
# public copy carries a pseudonym and loses nothing.
#
# The cross-reference lives under .NewCarlisle/ (gitignored) so that an
# investigator who asks "which trial is IA-...?" can be told - and heard.
source(file.path(root, "corpus", "pseudonymize.R"))
idDir <- iaIdDir(root)
dir.create(idDir, recursive = TRUE, showWarnings = FALSE)
write.csv(res, file.path(idDir, "EndToEndValidation_identified.csv"),
          row.names = FALSE)
write.csv(iaDeidentify(res, idFrom = "PMID"), outCsv, row.names = FALSE)
cat("\nwritten:", outCsv, "  rows:", nrow(res), " (pseudonymous)\n")
cat("identified copy + cross-reference:", idDir, "\n\n")

ok <- res[res$status == "ok" & is.finite(res$parsedP) &
          is.finite(res$carlisle) & res$parsedP > 0 & res$carlisle > 0, ]
cat("pipeline reached a p for", nrow(ok), "of", nrow(res), "\n")
cat("status breakdown:\n"); print(sort(table(res$status), decreasing = TRUE))
if (!nrow(ok)) { cat("\nnothing to compare yet\n"); quit(status = 0) }

lg <- function(x) log10(x)
dParsed  <- lg(ok$parsedP)  - lg(ok$carlisle)   # PDF  -> verdict
dCurated <- lg(ok$curated)  - lg(ok$carlisle)   # numbers -> verdict

say <- function(lab, d) cat(sprintf(
  "  %-28s n=%4d  median %+0.4f  IQR [%+0.3f, %+0.3f]  |median| %0.4f\n",
  lab, length(d), stats::median(d), stats::quantile(d, .25),
  stats::quantile(d, .75), stats::median(abs(d))))

cat("\n--- log10 difference from Carlisle's stored p ---\n")
cat("(negative = OUR p is SMALLER = more alarming than Carlisle)\n\n")
say("from Carlisle's numbers",  dCurated)
say("from the PDF (parsed)",    dParsed)
cat("\n  the gap between those two rows IS the parser's contribution\n")

cat("\n--- is the parser's error CENTRED, or biased? ---\n")
wt <- suppressWarnings(stats::wilcox.test(dParsed, mu = 0))
cat(sprintf("  signed median: %+0.4f   Wilcoxon p = %.3g\n",
            stats::median(dParsed), wt$p.value))
cat("  a signed median near zero means parse error is noise;\n")
cat("  a negative one means parsing MANUFACTURES ALARM,\n")
cat("  a positive one means it HIDES it.\n")

if (any(!is.na(ok$SET))) {
  cat("\n--- development vs holdout ---\n")
  for (s in c("development", "holdout")) {
    d <- dParsed[which(ok$SET == s)]
    if (length(d)) say(s, d)
  }
}
cat("\n--- agreement ---\n")
cat(sprintf("  correlation of log10 p, parsed vs Carlisle: %.4f\n",
            stats::cor(lg(ok$parsedP), lg(ok$carlisle))))
cat(sprintf("  ...from Carlisle's own numbers            : %.4f\n",
            stats::cor(lg(ok$curated), lg(ok$carlisle))))
cat("\nALARM CONCORDANCE at p < 0.01 (what an editor acts on):\n")
aC <- ok$carlisle < 0.01; aP <- ok$parsedP < 0.01
cat(sprintf("  agree %d/%d (%.1f%%)   parser alarms Carlisle did not: %d",
            sum(aC == aP), nrow(ok), 100*mean(aC == aP), sum(aP & !aC)))
cat(sprintf("   missed: %d\n", sum(aC & !aP)))
cat("  (the first of those two is a false accusation; the second is a\n")
cat("   missed detection - they are not equally bad)\n")
