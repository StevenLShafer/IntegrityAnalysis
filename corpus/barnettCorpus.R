# barnettCorpus.R - run Barnett's dispersion test over the whole
# ClinicalTrials.gov baseline corpus, and set its answer beside ours.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's direction: "we can also run this on the clinicaltrials.gov      #
# table, and see if the distributions match our distributions. That will   #
# distinguish analysis failures from randomization or trial level          #
# failures."                                                               #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHY THIS COMPARISON IS WORTH RUNNING, and why this corpus in particular. #
#                                                                          #
# Our screen of these 47,813 registry trials shows a pile-up of trial      #
# p-values against 1. Three explanations were on the table and no amount   #
# of staring at our own output could separate them:                        #
#                                                                          #
#   (a) the trials really are over-dispersed - arms further apart than     #
#       randomisation predicts, which is what allocation subversion by an  #
#       investigator would look like;                                      #
#   (b) our p-value machinery manufactures the pile-up - a rounding        #
#       artefact, the p >= 1 cap, a metalog fit, a mis-specified null;     #
#   (c) the registry data are shaped in a way that breaks the assumption   #
#       rather than the trial.                                             #
#                                                                          #
# Barnett's test separates (a) from (b) because it is a DIFFERENT KIND OF  #
# INSTRUMENT applied to the SAME NUMBERS. Ours tests the shape of a whole  #
# distribution; his tests one moment of it - the variance of the           #
# t-statistics. His own simulation study is the point: a distribution-     #
# shape test fires on skew, on categorical data and on rounding, none of   #
# which is fraud, while a variance test does not.                          #
#                                                                          #
# So the two are diagnostic together:                                      #
#                                                                          #
#   both flag over-dispersion   -> the spread really is wrong. (a).        #
#   ours flags, his does not    -> the anomaly is in the SHAPE of our      #
#                                  p-value distribution, not in the        #
#                                  spread of the data. (b) or (c).         #
#   his flags, ours does not    -> we are missing real dispersion; worth   #
#                                  knowing before anyone trusts a null     #
#                                  result from this app.                   #
#                                                                          #
# AND WHY THIS CORPUS. Registry baseline tables are TYPED, not parsed.     #
# Every number was entered into a structured field by the sponsor and      #
# retrieved through an API. No PDF, no column detection, no decimal        #
# recovered from a glyph. That removes our own parser from the loop        #
# entirely, so a disagreement here cannot be blamed on misparsing - which  #
# is precisely what makes the registry the right place to calibrate.       #
#                                                                          #
# IDENTIFIERS. The per-trial output is keyed by NCT and stays in the work  #
# directory, which is outside the repository. Nothing keyed to a real      #
# trial is committed; the committed artefact is the aggregate report, and  #
# anything per-trial that ever needs publishing goes through              #
# corpus/pseudonymize.R first, as the registry analysis frame does.        #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/barnettCorpus.R [outDir] [maxTrials]                    #
#     outDir     default <INTEGRITY_WORK>/ctgov_corpus                     #
#     maxTrials  0 = all (default); a small number for a smoke test        #
#     --report-only   rebuild the comparison from an existing barnett.csv  #
#                                                                          #
# OUTPUT                                                                   #
#   barnett.csv       one row per trial: nStat, pDispersed, epsilon, ...   #
#   barnettReport.txt the comparison against our screen                    #
############################################################################

args   <- commandArgs(trailingOnly = TRUE)
# Strip the flag FIRST. Left in place it would be taken as the
# positional outDir and the run would die on the missing baseline
# files before ever reaching the branch. (CodeRabbit, PR #125.)
reportOnly <- "--report-only" %in% args
args   <- args[args != "--report-only"]
outDir <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
maxN   <- if (length(args) >= 2) suppressWarnings(as.integer(args[2])) else 0L
if (is.na(maxN)) maxN <- 0L

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")

# The snapshot library, not the live tree - see the note in
# corpus/parallelHelper.R and AGENTS.md. A batch run that picks up a
# half-edited working copy produces numbers nobody can reproduce.
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
if (!requireNamespace("IntegrityAnalysis", quietly = TRUE))
  stop("IntegrityAnalysis is not installed in ",
       if (nzchar(libDir)) libDir else "THIS R's library path", call. = FALSE)
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis)
}))
cat("engine: version",
    as.character(utils::packageVersion("IntegrityAnalysis")), "\n")
source(file.path(root, "corpus", "parallelHelper.R"))

contPath <- file.path(outDir, "baselineContinuous.csv")
catPath  <- file.path(outDir, "baselineCategorical.csv")
outCsv   <- file.path(outDir, "barnett.csv")
repTxt   <- file.path(outDir, "barnettReport.txt")
stopifnot(file.exists(contPath), file.exists(catPath))

cat("reading the corpus\n")
cont <- utils::read.csv(contPath, stringsAsFactors = FALSE)
cats <- utils::read.csv(catPath,  stringsAsFactors = FALSE)
cat("  continuous rows :", nrow(cont), "\n")
cat("  categorical cells:", nrow(cats), "\n")

trials <- sort(unique(c(cont$TRIAL, cats$TRIAL)))
if (maxN > 0) trials <- utils::head(trials, maxN)
cat("  trials           :", length(trials), "\n")

# Split ONCE. split() on a 932,000-row frame is a few seconds; doing the
# equivalent subset inside the per-trial loop would be 47,813 full scans
# of both frames, which is the difference between minutes and hours.
contBy <- split(cont, cont$TRIAL)
catsBy <- split(cats, cats$TRIAL)
rm(cont, cats); invisible(gc())

#' One trial: reshape into the app's validated shape, then test.
#'
#' The reshape matters. barnettTStats() is the tested path, and the whole
#' point of routing through it is that the corpus and the app cannot drift
#' apart in how they build a t-statistic. So the categorical long form is
#' pivoted back to the app's wide arm-by-category layout rather than
#' having its t-statistics computed here by a second implementation.
oneTrial <- function(nct) {
  cn <- contBy[[nct]]
  ct <- catsBy[[nct]]
  parts <- list(); categoryNames <- character(0)

  if (!is.null(cn) && nrow(cn)) {
    d <- data.frame(TRIAL = nct, ROW = paste0("N|", cn$ROW), N = cn$N, MEAN = cn$MEAN,
                    SD = cn$SD, SE = cn$SE, Q1 = cn$Q1, Q3 = cn$Q3,
                    ROUND_MEAN = cn$ROUND_MEAN,
                    ROUND_DISPERSION = cn$ROUND_DISPERSION,
                    ROUND_OBSERVATION = cn$ROUND_OBSERVATION,
                    stringsAsFactors = FALSE)
    parts$cont <- d
  }

  if (!is.null(ct) && nrow(ct)) {
    # Category names are the full registry paths and can be long; they are
    # only column labels here, so uniqueness is all that is required.
    lev <- unique(ct$CATEGORY)
    categoryNames <- paste0("C", seq_along(lev))
    names(categoryNames) <- lev
    key <- paste(ct$ROW, ct$ARM, sep = "\r")
    ord <- !duplicated(key)
    # NAMESPACE THE TITLES PER BLOCK. barnettTStats() groups by ROW,
    # so a trial that uses one title for BOTH a continuous and a
    # categorical measure would merge them into a single group, the
    # group would be classified categorical, the continuous arms
    # would contribute all-zero counts, and the whole group would be
    # dropped with nothing recording the loss. Measured at 36 of
    # 67,758 trial-title keys (0.053%) in the registry corpus - rare
    # enough not to move any aggregate, common enough to be wrong.
    # (CodeRabbit, PR #125.)
    w <- data.frame(TRIAL = nct, ROW = paste0("K|", ct$ROW[ord]),
                    N = NA_real_, MEAN = NA_real_, SD = NA_real_,
                    SE = NA_real_, Q1 = NA_real_, Q3 = NA_real_,
                    ROUND_MEAN = NA_real_, ROUND_DISPERSION = NA_real_,
                    ROUND_OBSERVATION = NA_real_,
                    stringsAsFactors = FALSE)
    for (nm in categoryNames) w[[nm]] <- NA_real_
    idx <- match(key, key[ord])
    for (i in seq_len(nrow(ct)))
      w[idx[i], categoryNames[[ct$CATEGORY[i]]]] <- ct$COUNT[i]
    parts$cat <- w
  }

  if (!length(parts)) return(NULL)
  # rbind needs matching columns; the continuous block has no category
  # columns and vice versa.
  allCols <- unique(unlist(lapply(parts, names)))
  parts <- lapply(parts, function(p) {
    for (nm in setdiff(allCols, names(p))) p[[nm]] <- NA_real_
    p[, allCols, drop = FALSE]
  })
  DATA <- do.call(rbind, parts)

  ts <- barnettTStats(DATA, CategoryNames = unname(categoryNames))
  r  <- barnettDispersion(ts)

  # THE SAME TEST ON EACH HALF OF THE EVIDENCE, separately. Barnett names
  # correlated summary statistics as the one way his method produces
  # false positives, and the registry's categorical rows are one place
  # correlation lives: a three-level category is one multinomial split
  # into three binomials that the model then treats as independent.
  #
  # WHAT THIS SPLIT DOES AND DOES NOT SHOW. It shows whether a signal is
  # SPECIFIC to the categorical approximation. It does NOT give a
  # correlation-free control, and an earlier version of this comment
  # wrongly claimed it did. barnettTStats() emits every arm PAIR, so in a
  # three-arm trial the continuous t-statistics for A-B, A-C and B-C
  # share arms and are correlated too (CodeRabbit, PR #125). The
  # continuous half is less correlated, not uncorrelated.
  #
  # The honest baseline comes from corpus/correlationNull.R instead,
  # which simulates trials carrying the real geometry - all-pairs
  # comparisons included - and so prices in exactly this correlation.
  # Read the two together; neither is sufficient alone.
  rc <- barnettDispersion(ts[ts$statistic == "continuous", , drop = FALSE])
  rk <- barnettDispersion(ts[ts$statistic == "categorical", , drop = FALSE])

  data.frame(TRIAL = nct,
             nStat   = r$nStat,
             nCont   = sum(ts$statistic == "continuous"),
             nCat    = sum(ts$statistic == "categorical"),
             nZeroSd = sum(ts$zeroSd),
             pDispersed = r$pDispersed,
             epsilon = r$epsilon,
             gamma   = r$gamma,
             direction = r$direction,
             multiplier = r$multiplier,
             pCont   = rc$pDispersed, epsCont = rc$epsilon,
             pCat    = rk$pDispersed, epsCat  = rk$epsilon,
             stringsAsFactors = FALSE)
}

# --report-only regenerates the comparison from an existing barnett.csv
# without recomputing it. The dispersion pass is deterministic and
# depends only on the baseline tables, while the screen it is compared
# against takes over an hour and lands later; separating them means the
# report can be refreshed the moment the screen finishes, instead of
# either waiting for both or recomputing what has not changed. Same
# reasoning as --map-only in buildCtgovCorpus.R.
if (reportOnly && file.exists(outCsv)) {
  cat("\n--report-only: reading", outCsv, "\n")
  res <- utils::read.csv(outCsv, stringsAsFactors = FALSE)
} else {
  cat("\nrunning the dispersion test\n")
  t0 <- Sys.time()
  # Return the ERROR, do not swallow it. A handler that maps every
  # failure to NULL makes a crashed trial indistinguishable from one with
  # no usable rows, and this session has already been bitten twice by
  # exactly that (a missing ::: recorded as a refusal, and 255 HTTP 400s
  # reported as "request failed"). (CodeRabbit, PR #125.)
  res <- iaParallel(trials, function(nct)
           tryCatch(oneTrial(nct),
                    error = function(e) conditionMessage(e)),
         export = c("contBy", "catsBy", "oneTrial"))
  bad <- vapply(res, is.character, logical(1))
  if (any(bad)) {
    tb <- sort(table(unlist(res[bad])), decreasing = TRUE)
    cat("  errors:", sum(bad), "trial(s)
")
    for (k in seq_len(min(5L, length(tb))))
      cat(sprintf("    %-58s %d
", substr(names(tb)[k], 1, 58), tb[k]))
  }
  empty <- vapply(res, is.null, logical(1))
  if (any(empty)) cat("  no usable rows:", sum(empty), "trial(s)
")
  res <- do.call(rbind, res[!bad & !empty])
  cat("  done in",
      round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
      "min;", nrow(res), "trials returned\n")
  utils::write.csv(res, outCsv, row.names = FALSE)
  cat("  written:", outCsv, "\n")
}

## ---- the comparison ------------------------------------------------------
con <- file(repTxt, open = "w", encoding = "UTF-8")
say <- function(...) { cat(..., "\n", sep = ""); cat(..., "\n", sep = "", file = con) }

say("================ BARNETT DISPERSION vs OUR SCREEN ================")
usable <- res[res$nStat >= 3 & is.finite(res$pDispersed), ]
say("trials with >= 3 t-statistics: ", nrow(usable), " of ", nrow(res))
say("  median statistics per trial: ", stats::median(usable$nStat))
say("  continuous / categorical   : ", sum(usable$nCont), " / ", sum(usable$nCat))
say("")
say("Barnett flag (his threshold is 0.95):")
flag <- usable$pDispersed > 0.95
say("  flagged                    : ", sum(flag),
    sprintf(" (%.1f%%)", 100 * mean(flag)))
say("    under-dispersed (too alike): ", sum(flag & usable$epsilon > 0),
    sprintf(" (%.1f%%)", 100 * mean(flag & usable$epsilon > 0)))
say("    over-dispersed (too apart) : ", sum(flag & usable$epsilon < 0),
    sprintf(" (%.1f%%)", 100 * mean(flag & usable$epsilon < 0)))
say("  his PubMed Central figures were 3.6% under, 18.3% over")
say("")
say("epsilon (positive = under-dispersed):")
qs <- stats::quantile(usable$epsilon, c(.05, .25, .5, .75, .95))
say(sprintf("  5%%/25%%/50%%/75%%/95%%: %+.3f %+.3f %+.3f %+.3f %+.3f",
            qs[1], qs[2], qs[3], qs[4], qs[5]))

scrPath <- file.path(outDir, "screened.csv")
if (file.exists(scrPath)) {
  scr <- utils::read.csv(scrPath, stringsAsFactors = FALSE)
  scr$P <- suppressWarnings(as.numeric(scr$P))
  m <- merge(usable, scr[, c("NCT", "P", "STATUS", "ARMS", "ROWS")],
             by.x = "TRIAL", by.y = "NCT")
  m <- m[is.finite(m$P), ]
  say("")
  say("--- joined to our screen: ", nrow(m), " trials with both answers ---")
  say("")
  say("THE QUESTION. Our trial p piles up against 1. If that pile-up is")
  say("real over-dispersion, Barnett's epsilon should be NEGATIVE there.")
  say("If his epsilon sits at zero, the pile-up is ours, not the trials'.")
  say("")
  say(sprintf("  %-22s %7s %9s %9s %9s", "our trial p", "n",
              "med eps", "%his flag", "%his over"))
  bands <- list(c(0, 0.01), c(0.01, 0.1), c(0.1, 0.5), c(0.5, 0.9),
                c(0.9, 0.99), c(0.99, 1.0001))
  for (b in bands) {
    s <- m[m$P >= b[1] & m$P < b[2], ]
    if (!nrow(s)) next
    say(sprintf("  [%.2f, %.2f)%-10s %7d %+9.3f %9.1f %9.1f",
                b[1], b[2], "", nrow(s), stats::median(s$epsilon),
                100 * mean(s$pDispersed > 0.95),
                100 * mean(s$pDispersed > 0.95 & s$epsilon < 0)))
  }
  say("")
  say("  Spearman correlation of our p with his epsilon: ",
      sprintf("%+.3f", stats::cor(m$P, m$epsilon, method = "spearman")))
  say("  (negative means our HIGH p goes with his over-dispersion,")
  say("   which is the two instruments agreeing)")
  say("")
  say("THE SAME QUESTION, asked of each half of the evidence separately.")
  say("Barnett names correlated statistics as the way his method produces")
  say("false positives, and the registry's categorical rows are where")
  say("correlation would live. If the pattern is only in the categorical")
  say("column it is an artefact of that approximation; if it is in the")
  say("continuous column too, it is a property of the trials.")
  say("")
  say(sprintf("  %-22s %7s %10s %10s %9s", "our trial p", "n",
              "med eps", "med contin", "med categ"))
  for (b in bands) {
    s <- m[m$P >= b[1] & m$P < b[2], ]
    if (!nrow(s)) next
    mc <- suppressWarnings(stats::median(s$epsCont, na.rm = TRUE))
    mk <- suppressWarnings(stats::median(s$epsCat,  na.rm = TRUE))
    say(sprintf("  [%.2f, %.2f)%-10s %7d %+10.3f %+10.3f %+9.3f",
                b[1], b[2], "", nrow(s), stats::median(s$epsilon),
                if (is.finite(mc)) mc else NA_real_,
                if (is.finite(mk)) mk else NA_real_))
  }
  ok <- is.finite(m$epsCont)
  if (sum(ok) > 30)
    say("\n  Spearman, continuous statistics only (n = ", sum(ok), "): ",
        sprintf("%+.3f", stats::cor(m$P[ok], m$epsCont[ok],
                                    method = "spearman")))
  ok <- is.finite(m$epsCat)
  if (sum(ok) > 30)
    say("  Spearman, categorical statistics only (n = ", sum(ok), "): ",
        sprintf("%+.3f", stats::cor(m$P[ok], m$epsCat[ok],
                                    method = "spearman")))
  say("")
  say("agreement on alarms:")
  ourAlarm <- m$P < 0.01
  hisAlarm <- m$pDispersed > 0.95 & m$epsilon > 0     # both = too alike
  say("  ours alarms (p < 0.01)     : ", sum(ourAlarm))
  say("  his under-dispersion flag  : ", sum(hisAlarm))
  say("  both                       : ", sum(ourAlarm & hisAlarm))
  say("  neither                    : ", sum(!ourAlarm & !hisAlarm))
}
close(con)
cat("\nwritten: ", repTxt, "\n", sep = "")
