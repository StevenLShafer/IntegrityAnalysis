# tStatsByVariable.R - which baseline variables carry the dispersion?
#
############################################################################
# Provenance                                                               #
# Written 2026-08-30 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's question: "does AGE still show excess towards P -> 1 with       #
# Barnett's approach?"                                                     #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# THE QUESTION. Our own per-row screen found age alarming at 9.3% of rows  #
# where sex was clean at 4.8%, with 42% of age's upper tail sitting on the #
# p-value cap. That is either a property of how ages are reported and      #
# analysed, or a property of the trials. Barnett's method is the           #
# independent read.                                                        #
#                                                                          #
# WHY THIS IS POOLED RATHER THAN PER TRIAL. Barnett's model is a           #
# TRIAL-level test: it asks whether one table's t-statistics are too       #
# spread out, and it needs several of them to say anything. A single       #
# variable contributes one row, so a two-arm trial gives ONE t-statistic   #
# for age - nothing to estimate a spread from. The variable-level question #
# therefore has to be asked of the t-statistics pooled ACROSS trials.      #
#                                                                          #
# That pooling is exactly valid here and it is worth saying why. Under     #
# honest randomisation each t is a draw from a t-distribution with its own #
# degrees of freedom, INDEPENDENTLY of every other trial. Correlation      #
# between rows lives WITHIN a trial, not between trials, so it does not    #
# touch this comparison - which makes the pooled test cleaner than the     #
# trial-level one, not dirtier.                                            #
#                                                                          #
# ROBUSTNESS IS NOT OPTIONAL. A single mis-entered row can produce a       #
# t-statistic of 200 and move a variance by itself. Every scale below is   #
# therefore reported twice: the plain standard deviation, and a median-    #
# absolute-deviation scale that a handful of wild values cannot move. When #
# the two disagree the finding is a few bad rows; when they agree it is    #
# the distribution.                                                        #
#                                                                          #
# Usage:                                                                   #
#   Rscript corpus/tStatsByVariable.R [outDir] [nTrials]                   #
############################################################################

args    <- commandArgs(trailingOnly = TRUE)
outDir  <- if (length(args) >= 1) args[1] else
  file.path(Sys.getenv("INTEGRITY_WORK", "C:/temp"), "ctgov_corpus")
nTrials <- if (length(args) >= 2) as.integer(args[2]) else 0L

root <- Sys.getenv("INTEGRITY_ROOT", "C:/dev/IntegrityAnalysis")
libDir <- Sys.getenv("INTEGRITY_SNAPSHOT_LIB", "")
if (nzchar(libDir)) .libPaths(c(libDir, .libPaths()))
suppressWarnings(suppressPackageStartupMessages({
  library(IntegrityAnalysis)
}))
source(file.path(root, "corpus", "parallelHelper.R"))

# Same patterns as multiVar.R, so the two analyses cut the corpus the
# same way and their numbers can be set side by side.
TARGETS <- list(
  list(lab = "age (continuous)",    pat = "^age,? ?continuous$"),
  list(lab = "weight",              pat = "^(body )?weight"),
  list(lab = "BMI",                 pat = "body mass index|^bmi"),
  list(lab = "height",              pat = "^height"),
  list(lab = "blood pressure",      pat = "systolic|diastolic"),
  list(lab = "SEX (categorical)",   pat = "^sex|^gender"),
  list(lab = "race",                pat = "^race"),
  list(lab = "ethnicity",           pat = "^ethnicity"),
  list(lab = "region of enrolment", pat = "^region of enrol"))

classify <- function(row) {
  # Strip the per-block namespace prefix added during the reshape.
  r <- tolower(trimws(sub("^[NK][|]", "", row)))
  for (t in TARGETS) if (grepl(t$pat, r)) return(t$lab)
  "other"
}

cont <- utils::read.csv(file.path(outDir, "baselineContinuous.csv"),
                        stringsAsFactors = FALSE)
cats <- utils::read.csv(file.path(outDir, "baselineCategorical.csv"),
                        stringsAsFactors = FALSE)
trials <- sort(unique(c(cont$TRIAL, cats$TRIAL)))
if (nTrials > 0) trials <- utils::head(trials, nTrials)
contBy <- split(cont, cont$TRIAL)
catsBy <- split(cats, cats$TRIAL)
rm(cont, cats); invisible(gc())
cat("building t-statistics for", length(trials), "trials\n")

oneTrial <- function(nct) {
  cn <- contBy[[nct]]; ct <- catsBy[[nct]]
  parts <- list(); categoryNames <- character(0)
  if (!is.null(cn) && nrow(cn))
    parts$cont <- data.frame(TRIAL = nct, ROW = paste0("N|", cn$ROW), N = cn$N,
      MEAN = cn$MEAN, SD = cn$SD, SE = cn$SE, Q1 = cn$Q1, Q3 = cn$Q3,
      ROUND_MEAN = cn$ROUND_MEAN, ROUND_DISPERSION = cn$ROUND_DISPERSION,
      ROUND_OBSERVATION = cn$ROUND_OBSERVATION, stringsAsFactors = FALSE)
  if (!is.null(ct) && nrow(ct)) {
    lev <- unique(ct$CATEGORY)
    categoryNames <- paste0("C", seq_along(lev)); names(categoryNames) <- lev
    key <- paste(ct$ROW, ct$ARM, sep = "\r"); ord <- !duplicated(key)
    # NAMESPACE THE TITLES PER BLOCK. barnettTStats() groups by ROW,
    # so a trial that uses one title for BOTH a continuous and a
    # categorical measure would merge them into a single group, the
    # group would be classified categorical, the continuous arms
    # would contribute all-zero counts, and the whole group would be
    # dropped with nothing recording the loss. Measured at 36 of
    # 67,758 trial-title keys (0.053%) in the registry corpus - rare
    # enough not to move any aggregate, common enough to be wrong.
    # (CodeRabbit, PR #125.)
    w <- data.frame(TRIAL = nct, ROW = paste0("K|", ct$ROW[ord]), N = NA_real_,
      MEAN = NA_real_, SD = NA_real_, SE = NA_real_, Q1 = NA_real_,
      Q3 = NA_real_, ROUND_MEAN = NA_real_, ROUND_DISPERSION = NA_real_,
      ROUND_OBSERVATION = NA_real_, stringsAsFactors = FALSE)
    for (nm in categoryNames) w[[nm]] <- NA_real_
    idx <- match(key, key[ord])
    for (i in seq_len(nrow(ct)))
      w[idx[i], categoryNames[[ct$CATEGORY[i]]]] <- ct$COUNT[i]
    parts$cat <- w
  }
  if (!length(parts)) return(NULL)
  allCols <- unique(unlist(lapply(parts, names)))
  parts <- lapply(parts, function(p) {
    for (nm in setdiff(allCols, names(p))) p[[nm]] <- NA_real_
    p[, allCols, drop = FALSE]
  })
  ts <- barnettTStats(do.call(rbind, parts),
                      CategoryNames = unname(categoryNames))
  if (!nrow(ts)) return(NULL)
  ts[, c("TRIAL", "ROW", "statistic", "t", "df", "size")]
}

ts <- iaParallel(trials, function(nct)
        tryCatch(oneTrial(nct), error = function(e) NULL),
      export = c("contBy", "catsBy", "oneTrial"))
ts <- do.call(rbind, Filter(Negate(is.null), ts))
ts$VAR <- vapply(ts$ROW, classify, character(1))
utils::write.csv(ts, file.path(outDir, "tStatsByVariable.csv"),
                 row.names = FALSE)
cat("  t-statistics:", nrow(ts), "\n\n")

## ---- the null, for the same degrees of freedom ---------------------------
# Not a constant. The expected spread of a t-statistic depends on its
# degrees of freedom, and the variables differ in typical trial size, so
# each variable gets its OWN null drawn at its OWN degrees of freedom.
set.seed(20260830)

scales <- function(x) {
  c(sd = stats::sd(x),
    mad = stats::mad(x),                 # already scaled to a normal SD
    hi95 = 100 * mean(abs(x) > 1.959964),
    hi99 = 100 * mean(abs(x) > 2.575829))
}

cat("Pooled t-statistics by variable. Under honest randomisation every\n")
cat("column below matches its null row. SD > 1 is OVER-dispersion (arms\n")
cat("further apart than randomisation predicts); SD < 1 is under.\n\n")
cat(sprintf("%-22s %8s %7s %7s %7s %7s\n",
            "variable", "n", "SD", "robust", "%>1.96", "%>2.58"))
for (lab in c(vapply(TARGETS, function(t) t$lab, ""), "other")) {
  s <- ts[ts$VAR == lab, ]
  if (nrow(s) < 200) next
  o <- scales(s$t)
  n <- scales(stats::rt(nrow(s), df = s$df))
  cat(sprintf("%-22s %8d %7.3f %7.3f %7.2f %7.2f\n",
              lab, nrow(s), o["sd"], o["mad"], o["hi95"], o["hi99"]))
  cat(sprintf("%-22s %8s %7.3f %7.3f %7.2f %7.2f   <- null\n",
              "", "", n["sd"], n["mad"], n["hi95"], n["hi99"]))
}
cat("\nwritten:", file.path(outDir, "tStatsByVariable.csv"), "\n")
