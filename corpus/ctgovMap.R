# ctgovMap.R - the ONE definition of how a ClinicalTrials.gov baseline
# module becomes IntegrityAnalysis template rows.
#
############################################################################
# Provenance                                                               #
# Extracted 2026-08-29 by Claude Code (model Claude Opus 5) from           #
# corpus/ctgovScreen.R when corpus/buildCtgovCorpus.R needed the same      #
# mapping. LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.      #
#                                                                          #
# WHY EXTRACTED RATHER THAN COPIED. Earlier the same day, a throwaway      #
# Python approximation of two of rctFilterPatterns.R's patterns disagreed  #
# with the real classifyRct() on 2 of 40 packages - because it reproduced  #
# the patterns but not the logic around them. A second implementation of   #
# this mapping would drift the same way, and this corpus is intended to    #
# be defensible in a publication: every row in it must be traceable to     #
# one function, not to whichever script happened to produce it.            #
#                                                                          #
# Sourced by ctgovScreen.R (screens trials) and buildCtgovCorpus.R         #
# (stores the whole registry).                                            #
############################################################################

## ---- design filter -------------------------------------------------------
# WHY A FILTER IS NEEDED AT ALL, measured rather than assumed. An
# unfiltered run of 1,338 trials produced a p-value distribution that was
# uniform in the lower tail and middle but piled up near 1:
#
#   arms   n     p<0.05   p>0.95        (5% expected in each)
#   2      929    4.6%      8.8%
#   4+     218    4.6%     21.1%   <- median 0.685
#
# The cause, found by reading one of the worst cases (NCT03542149): it is
# a DOSE-ESCALATION study whose "arms" are Cohort 1 Groups A-D, Cohort 2
# Groups A-B, Cohort 3 Groups A-B, with 2 to 6 subjects each. Those
# cohorts were enrolled SEQUENTIALLY and were never randomized against
# one another - randomization happens within a cohort. Carlisle's method
# assumes every compared group came from ONE allocation, so comparing
# across cohorts guarantees more between-group variation than
# randomization predicts, and p goes to 1. Not fraud, and not a coding
# error: the wrong trials in the sample.
#
# NOTE WHAT DOES NOT CATCH IT. That study is labelled
# `interventionModel: PARALLEL` and `allocation: RANDOMIZED`. The
# structural design fields alone are not sufficient, which is why the
# group titles are inspected too.
#
# Set INTEGRITY_CTG_NOFILTER=1 to disable, which is how the before/after
# contrast above was produced.
ctgDesignVeto <- function(st) {
  dm <- tryCatch(st$protocolSection$designModule, error = function(e) NULL)
  di <- dm$designInfo %||% list()
  im <- toupper(di$interventionModel %||% "")
  # CROSSOVER compares periods, not independent arms; FACTORIAL,
  # SEQUENTIAL and SINGLE_GROUP are not one two-way allocation either.
  if (nzchar(im) && im != "PARALLEL")
    return(paste0("design: ", tolower(im)))
  ph <- unlist(dm$phases %||% list())
  if (any(toupper(ph) == "PHASE1"))
    return("phase 1 (dose escalation risk)")
  bm <- tryCatch(st$resultsSection$baselineCharacteristicsModule,
                 error = function(e) NULL)
  gt <- paste(vapply(bm$groups %||% list(), function(g) g$title %||% "", ""),
              collapse = " | ")
  # The direct signature of the failure above: groups named as cohorts,
  # parts or stages are enrolment strata, not co-randomized arms.
  if (grepl("(?i)\\bcohort\\b|dose[- ]escalat|\\bpart [0-9A-C]\\b|\\bstage [0-9]\\b",
            gt, perl = TRUE))
    return("groups are cohorts/parts, not co-randomized arms")
  ttl <- tryCatch(st$protocolSection$identificationModule$briefTitle %||% "",
                  error = function(e) "")
  # Cluster randomization inflates between-arm variation by design: the
  # unit of allocation is a clinic or village, not a patient, so arm
  # means differ more than individual randomization predicts. The
  # registry has no structured field for it, so the title is all there is.
  if (grepl("(?i)cluster[- ]?random", paste(ttl, gt), perl = TRUE))
    return("cluster randomized")
  NA_character_
}

## ---- map a baseline module onto the template ----------------------------
# Decimal places as PRINTED. The whole method rests on rounding simulated
# values exactly as the source rounded its own, and the registry stores
# these as strings, so the printed precision is recoverable rather than
# inferred.
# LENGTH-SAFE. Registry measurements routinely omit `value`, `spread`,
# `lowerLimit` or `upperLimit` for some arms, and JSON absence arrives as
# NULL. as.numeric(NULL) is numeric(0), and assigning that into a vector
# slot fails with "replacement has length zero" - which killed 17 of the
# first 25 studies tried. Return NA instead and let the completeness
# checks below decide whether the measure is usable.
decOf <- function(s) {
  if (is.null(s) || !length(s)) return(NA_integer_)
  s <- as.character(s)[1]
  if (is.na(s) || !grepl("[.]", s)) return(0L)
  nchar(sub("^[^.]*[.]", "", s))
}
numOf <- function(s) {
  if (is.null(s) || !length(s)) return(NA_real_)
  suppressWarnings(as.numeric(as.character(s)[1]))
}

ctgToTemplate <- function(st) {
  id <- tryCatch(st$protocolSection$identificationModule$nctId,
                 error = function(e) NA_character_)
  bm <- tryCatch(st$resultsSection$baselineCharacteristicsModule,
                 error = function(e) NULL)
  if (is.null(bm) || !length(bm$groups) || !length(bm$measures))
    return(list(trial = id, data = NULL, why = "no baseline module"))

  gid   <- vapply(bm$groups, function(g) g$id %||% "", "")
  gtitle <- vapply(bm$groups, function(g) g$title %||% "", "")

  # Arm sizes, and the Total detection that must not be skipped.
  n <- stats::setNames(rep(NA_real_, length(gid)), gid)
  if (length(bm$denoms)) {
    for (cnt in bm$denoms[[1]]$counts %||% list()) {
      g <- cnt$groupId
      if (is.null(g) || !(g %in% gid)) next   # never widen n by accident
      v <- numOf(cnt$value); if (!is.na(v)) n[[g]] <- v
    }
  }
  isTotal <- grepl("^\\s*total\\s*$", gtitle, ignore.case = TRUE)
  # Arithmetic check as well as the title: a group whose N equals the sum
  # of all the others is a total however it is labelled.
  for (k in seq_along(gid)) {
    others <- n[-k]
    if (!isTotal[k] && !is.na(n[k]) && all(!is.na(others)) && length(others) > 1 &&
        isTRUE(all.equal(unname(n[k]), sum(others)))) isTotal[k] <- TRUE
  }
  keep <- gid[!isTotal]
  if (length(gid) < 2)
    return(list(trial = id, data = NULL, why = "only one baseline group"))
  if (length(keep) < 2)
    return(list(trial = id, data = NULL, why = "all but one group looked like a Total"))

  rows <- list(); cats <- character(0)
  for (m in bm$measures) {
    title <- m$title %||% ""
    ptype <- toupper(m$paramType %||% "")
    dtype <- toupper(m$dispersionType %||% "")
    classes <- m$classes %||% list()
    if (!length(classes)) next

    if (ptype %in% c("MEAN", "MEDIAN")) {
      # One value per arm; take the first class/category (a continuous
      # measure that is broken into classes is a stratified table, not a
      # single row, and is skipped rather than flattened).
      cat1 <- (classes[[1]]$categories %||% list())
      if (length(cat1) != 1) next
      ms <- cat1[[1]]$measurements %||% list()
      val <- stats::setNames(rep(NA_real_, length(keep)), keep)
      spr <- val; lo <- val; hi <- val; dm <- val; ds <- val
      for (x in ms) {
        g <- x$groupId
        if (is.null(g) || !(g %in% keep)) next
        val[[g]] <- numOf(x$value);      dm[[g]] <- decOf(x$value)
        spr[[g]] <- numOf(x$spread);     ds[[g]] <- decOf(x$spread)
        lo[[g]]  <- numOf(x$lowerLimit); hi[[g]] <- numOf(x$upperLimit)
      }
      if (any(is.na(val)) || any(is.na(n[keep])) || any(is.na(dm))) next
      if (ptype == "MEAN" && dtype %in% c("STANDARD_DEVIATION", "STANDARD_ERROR")) {
        if (any(is.na(spr))) next
        d <- data.frame(TRIAL = id, ROW = title, N = unname(n[keep]),
                        MEAN = unname(val), SD = NA_real_, SE = NA_real_,
                        Q1 = NA_real_, Q3 = NA_real_,
                        ROUND_MEAN = unname(dm), ROUND_DISPERSION = unname(ds),
                        ROUND_OBSERVATION = unname(dm),
                        stringsAsFactors = FALSE)
        if (dtype == "STANDARD_DEVIATION") d$SD <- unname(spr) else d$SE <- unname(spr)
        rows[[length(rows) + 1]] <- d
      } else if (ptype == "MEDIAN" &&
                 dtype %in% c("INTER_QUARTILE_RANGE", "INTERQUARTILE_RANGE")) {
        if (any(is.na(lo)) || any(is.na(hi))) next
        rows[[length(rows) + 1]] <- data.frame(
          TRIAL = id, ROW = title, N = unname(n[keep]), MEAN = unname(val),
          SD = NA_real_, SE = NA_real_, Q1 = unname(lo), Q3 = unname(hi),
          ROUND_MEAN = unname(dm), ROUND_DISPERSION = NA_real_,
          ROUND_OBSERVATION = unname(dm), stringsAsFactors = FALSE)
      }
      next
    }

    if (ptype %in% c("COUNT_OF_PARTICIPANTS", "NUMBER")) {
      cat1 <- (classes[[1]]$categories %||% list())
      if (length(cat1) < 2) next            # nothing to cross-tabulate
      lvl <- vapply(cat1, function(c) c$title %||% "", "")
      if (any(!nzchar(lvl)) || anyDuplicated(lvl)) next
      counts <- matrix(NA_real_, nrow = length(keep), ncol = length(cat1),
                       dimnames = list(keep, lvl))
      for (j in seq_along(cat1))
        for (x in (cat1[[j]]$measurements %||% list()))
          if (!is.null(x$groupId) && x$groupId %in% keep)
            counts[x$groupId, j] <- numOf(x$value)
      if (any(is.na(counts))) next
      colnames(counts) <- paste(title, lvl, sep = ": ")
      d <- data.frame(TRIAL = id, ROW = title, N = NA_real_, MEAN = NA_real_,
                      SD = NA_real_, SE = NA_real_, Q1 = NA_real_, Q3 = NA_real_,
                      ROUND_MEAN = NA_real_, ROUND_DISPERSION = NA_real_,
                      ROUND_OBSERVATION = NA_real_, stringsAsFactors = FALSE)
      d <- cbind(d, as.data.frame(counts, check.names = FALSE))
      cats <- union(cats, colnames(counts))
      rows[[length(rows) + 1]] <- d
    }
  }
  if (!length(rows)) return(list(trial = id, data = NULL, why = "no usable measures"))

  allCols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(d) {
    for (cc in setdiff(allCols, names(d))) d[[cc]] <- NA_real_
    d[, allCols, drop = FALSE]
  })
  list(trial = id, data = do.call(rbind, rows), cats = cats, why = NA_character_)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
