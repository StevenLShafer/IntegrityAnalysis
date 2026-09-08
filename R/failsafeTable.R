# failsafeTable.R - choosing the counts behind a printed percentage.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-08 by Claude Code (model Claude Opus 5, Anthropic) at    #
# Steve Shafer's direction, replacing the rule in .ppFailsafeCounts()      #
# (R/armNRecovery.R). Steve, 2026-09-08: "I lean towards testing all       #
# possible combinations in these ambiguous cases, and simply defaulting to #
# giving the authors the benefit of the doubt ('best case')", and then:    #
# "we have decided to go with best case, with worst case only appearing if #
# it straddles 0.01."                                                      #
# Status: unit-tested by tests/testthat/test-failsafe-table.R.             #
############################################################################
#
# WHY THE OLD RULE HAD TO GO, measured before this was written.
#
# When an arm is large enough that several counts share a printed
# percentage, something has to choose. The rule until now maximised, for
# each category LEVEL on its own table line, that level's statistic
# against its own complement. Three things were wrong with it.
#
#   1. It optimised the wrong statistic. P_Calc does not score a level
#      against its complement. It scores the WHOLE arms-by-levels table
#      with both margins fixed (R/P_Calc.R:1231-1263, r2dtable). The old
#      objective was a different quantity.
#
#   2. Levels were chosen independently, so the counts need not sum to
#      the arm. Three levels printed 33 / 33 / 34 % across two arms of
#      200 rebuilt as arm totals of 203 and 197 - a table that cannot
#      exist. (The 2026-09-08 independent audit, F2, reported the same
#      arithmetic.)
#
#   3. Worst of all, it ran BACKWARDS. For a level, the maximising
#      choice is the high count in one arm and the low count in another,
#      and the enumeration reaches the same orientation first every
#      time. Applied level by level, that scales one arm up and the
#      other down UNIFORMLY, so the two arms end in identical
#      proportions - the most homogeneous table there is. Measured
#      chi-square of the table the engine actually scores:
#
#        3 levels 33/33/34, arms of 200      old rule 0.000, range 0.000-0.061
#        4 levels 25 each, arms of 200       old rule 0.000, range 0.000-0.160
#        3 levels 33/33/34, three arms 200   old rule 0.000, range 0.000-0.090
#        4 levels 10/20/30/40, arms of 300   old rule 0.032, range 0.000-0.139
#
#      In p terms for the first of those, the admissible readings run
#      from 0.0041 to 0.0482 and the old rule returned 0.0041. The
#      guarantee stated in seven user-facing places - "the row can look
#      less alike than the truth, never more" - was false in the
#      direction that makes an honest paper look fabricated.
#
# WHAT THIS DOES INSTEAD. It enumerates whole TABLES: every assignment of
# counts in which each cell lies inside the bracket its printed
# percentage allows and, where the levels are exhaustive, each arm's
# counts sum to that arm's N. Each candidate is scored with the p the
# engine itself would compute. The BEST CASE - the largest p, the
# reading most favourable to the authors - is the one analysed. The
# smallest p is carried alongside it so the app can say when the choice
# mattered.
#
# WHY MAXIMISING THE STATISTIC IS NOT ENOUGH, also measured. A p is the
# statistic judged against the fixed-margin null, and one of those
# margins is the level total - the very thing being chosen. Raising a
# count moves the statistic AND the null it is measured against. Over 72
# three-level rows with unequal arms, the statistic-maximising table was
# not the p-maximising table in 44 of them, worst case p = 0.0148 chosen
# against 0.0247 available. So the p is computed, not approximated.
#
# WHAT MAKES IT AFFORDABLE. The null depends only on the margins. With
# the levels constrained to sum to N the arm margin is pinned, so only
# the level totals vary, and WITHIN one level-total group the mid-p is a
# non-decreasing function of the statistic - same null, same ordering.
# Only the largest-statistic table in a group can be that group's best,
# and only the smallest-statistic table can be its worst. So the number
# of simulations is the number of distinct level totals, not the number
# of tables: 19 rather than 49 for three levels across two arms of 200,
# 85 rather than 361 for four levels, 381 rather than 2,601 for five.

# The enumeration bound. A hostile document chooses the arm count, the
# level count and the arm sizes, and the admissible set grows in all
# three: three levels across two arms of 5,000 admits 3,806,401 tables.
# Above this many candidates the search is bounded instead of complete,
# and the caller is told, because a guarantee that quietly stops holding
# is worse than one that says when it stops.
.ppTableEnumMax <- 200000L

# Candidates drawn when the enumeration is bounded: every arm's extreme
# vectors (which is what the old rule considered, and the best case is
# often among them) plus a random sample of admissible ones.
.ppTableSampleMax <- 20000L

# Replicates used to CHOOSE between candidates. This is not the p the
# app reports - once the counts are chosen, P_Calc runs its own staged
# scheme on them, so there is exactly one source for the reported
# number. This budget only has to rank candidates.
#
# STAGED, for the same reason the engine stages: a first pass at
# .ppTableSelectReps ranks every distinct null, and only the handful of
# contenders at each end are re-run at .ppTableRefineReps. Without the
# second pass the ranking is decided by Monte Carlo noise - at 2,000
# replicates the standard error of a p near 0.05 is about 0.005, which
# is larger than the gap between neighbouring candidates - and the
# "best case" the app promises the authors would be the luckiest draw
# rather than the largest p.
.ppTableSelectReps <- 2000L
.ppTableRefineReps <- 20000L
.ppTableRefineTop  <- 6L

# The threshold at which the spread between the best and worst readings
# is worth telling the editor about (Steve, 2026-09-08: "worst case only
# appearing if it straddles 0.01"). 0.05 is deliberately NOT here: it
# has no meaning in this instrument.
.ppTableStraddle <- 0.01

#' Every count vector for one arm consistent with its brackets
#'
#' @param lo,hi integer vectors, one per level, the bracket ends; a
#'   pinned level has lo == hi.
#' @param N the arm size, or NA when it is unknown.
#' @param exhaustive TRUE when the levels partition the arm, so the
#'   counts must sum to N; FALSE when they need only fit inside it.
#' @param cap stop and return NULL beyond this many vectors.
#' @return integer matrix, one row per admissible vector, or NULL.
#' @noRd
.ppArmVectors <- function(lo, hi, N, exhaustive, cap) {
  L <- length(lo)
  if (L == 0) return(NULL)
  width <- as.numeric(hi) - as.numeric(lo) + 1
  if (any(!is.finite(width) | width < 1)) return(NULL)
  if (prod(width) > cap && !exhaustive) return(NULL)
  out <- vector("list", 0L)
  cur <- integer(L)
  # depth-first with the sum pruned at both ends: without the pruning an
  # exhaustive block of five levels at N = 5,000 would build the whole
  # product before discarding almost all of it
  suffixLo <- rev(cumsum(rev(as.numeric(lo))))
  suffixHi <- rev(cumsum(rev(as.numeric(hi))))
  target <- if (exhaustive) as.numeric(N) else NA_real_
  rec <- function(j, used) {
    if (length(out) > cap) return(invisible(NULL))
    if (j > L) {
      if (!exhaustive || isTRUE(all.equal(used, target)))
        out[[length(out) + 1L]] <<- cur
      return(invisible(NULL))
    }
    restLo <- if (j < L) suffixLo[j + 1L] else 0
    restHi <- if (j < L) suffixHi[j + 1L] else 0
    for (v in lo[j]:hi[j]) {
      if (exhaustive) {
        # what is left after this cell must still be reachable
        left <- target - used - v
        if (left < restLo || left > restHi) next
      } else if (is.finite(N) && used + v > N) next
      cur[j] <<- v
      rec(j + 1L, used + v)
      if (length(out) > cap) return(invisible(NULL))
    }
    invisible(NULL)
  }
  rec(1L, 0)
  if (!length(out) || length(out) > cap) return(NULL)
  matrix(unlist(out), ncol = L, byrow = TRUE)
}

# The engine's own statistic for a candidate table (R/P_Calc.R:1230).
.ppTableStat <- function(tab) {
  E <- outer(rowSums(tab), colSums(tab)) / sum(tab)
  if (any(!is.finite(E)) || any(E <= 0)) return(NA_real_)
  sum((tab - E)^2 / E)
}

# The engine's own p for a candidate: the LOWER mid-p tail of that
# statistic under fixed margins, which is the one-sided direction toward
# homogeneity the whole instrument is built on (R/P_Calc.R:1217-1219).
.ppTableP <- function(tab, reps) {
  r <- rowSums(tab); cc <- colSums(tab)
  cc <- cc[cc > 0]
  if (length(cc) < 2 || any(r == 0)) return(NA_real_)
  E <- outer(r, cc) / sum(r)
  obs <- sum((tab[, colSums(tab) > 0, drop = FALSE] - E)^2 / E)
  sims <- vapply(r2dtable(reps, r, cc), function(s) sum((s - E)^2 / E),
                 numeric(1))
  # mid-p, and the floor the engine uses everywhere: never zero
  (sum(sims < obs) + 0.5 * sum(sims == obs) + 0.5) / (reps + 1)
}

#' Choose the counts behind a block of printed percentages
#'
#' @param lo,hi integer matrices, arms x levels, the bracket ends. NA
#'   marks a cell that is not in play.
#' @param cnt integer matrix, arms x levels, counts already pinned; NA
#'   where the percentage left more than one possibility.
#' @param N numeric, one arm size per row of the matrices.
#' @param exhaustive TRUE when the levels partition the arm.
#' @param reps replicates used to rank candidates.
#' @return a list: `counts` (the best-case table), `pBest`, `pWorst`,
#'   `nTables`, `nNulls`, `complete` (FALSE when the search was bounded
#'   rather than exhaustive), and `straddles` (TRUE when best and worst
#'   fall on opposite sides of .ppTableStraddle).
#' @noRd
.ppFailsafeTableFill <- function(lo, hi, cnt, N, exhaustive = TRUE,
                                 reps = .ppTableSelectReps) {
  none <- list(counts = cnt, pBest = NA_real_, pWorst = NA_real_,
               nTables = 0L, nNulls = 0L, complete = TRUE, straddles = FALSE)
  if (!is.matrix(cnt) || !nrow(cnt) || ncol(cnt) < 2) return(none)
  amb <- is.na(cnt) & !is.na(lo) & !is.na(hi)
  if (!any(amb)) return(none)
  keep <- which(is.finite(N) & N > 0 & rowSums(!is.na(cnt) | amb) == ncol(cnt))
  if (length(keep) < 2) return(none)

  # per arm, the vectors it could have printed
  vecs <- vector("list", length(keep))
  for (k in seq_along(keep)) {
    i <- keep[k]
    l <- ifelse(amb[i, ], lo[i, ], cnt[i, ])
    h <- ifelse(amb[i, ], hi[i, ], cnt[i, ])
    if (anyNA(l) || anyNA(h)) return(none)
    v <- .ppArmVectors(as.integer(l), as.integer(h), N[i], exhaustive,
                       .ppTableEnumMax)
    if (is.null(v) || !nrow(v)) return(none)
    vecs[[k]] <- v
  }
  sizes <- vapply(vecs, nrow, integer(1))
  total <- prod(as.numeric(sizes))
  complete <- TRUE
  if (total > .ppTableEnumMax) {
    # BOUNDED, and it says so. Each arm keeps its extreme vectors (the
    # ones the old rule would have considered) plus a random sample, so
    # the search still spans the corners it used to reach.
    complete <- FALSE
    per <- max(2L, as.integer(floor(.ppTableSampleMax^(1/length(vecs)))))
    for (k in seq_along(vecs)) {
      v <- vecs[[k]]
      if (nrow(v) <= per) next
      ord <- order(rowSums(abs(v - rep(colMeans(v), each = nrow(v)))),
                   decreasing = TRUE)
      pick <- unique(c(ord[seq_len(min(per %/% 2L, nrow(v)))],
                       sample.int(nrow(v), min(per, nrow(v)))))
      vecs[[k]] <- v[pick[seq_len(min(per, length(pick)))], , drop = FALSE]
    }
    sizes <- vapply(vecs, nrow, integer(1))
    total <- prod(as.numeric(sizes))
  }

  # Group the candidates by their LEVEL TOTALS. Within a group the null
  # is identical, so the mid-p is monotone in the statistic and only the
  # extreme-statistic tables can win or lose.
  idx <- expand.grid(lapply(sizes, seq_len))
  best <- new.env(hash = TRUE, parent = emptyenv())
  for (r in seq_len(nrow(idx))) {
    tab <- do.call(rbind, Map(function(m, i) m[i, ], vecs, as.integer(idx[r, ])))
    s <- .ppTableStat(tab)
    if (!is.finite(s)) next
    key <- paste(colSums(tab), collapse = ",")
    e <- best[[key]]
    if (is.null(e)) best[[key]] <- list(hiT = tab, hiS = s, loT = tab, loS = s)
    else {
      if (s > e$hiS) { e$hiT <- tab; e$hiS <- s }
      if (s < e$loS) { e$loT <- tab; e$loS <- s }
      best[[key]] <- e
    }
  }
  keys <- ls(best)
  if (!length(keys)) return(none)

  # Pass 1: rank every distinct null cheaply.
  up <- vapply(keys, function(k) .ppTableP(best[[k]]$hiT, reps), numeric(1))
  dn <- vapply(keys, function(k) {
    e <- best[[k]]
    if (identical(e$hiS, e$loS)) NA_real_ else .ppTableP(e$loT, reps)
  }, numeric(1))
  dn[is.na(dn)] <- up[is.na(dn)]
  if (!any(is.finite(up))) return(none)

  # Pass 2: the contenders at each end, re-run with ten times the
  # replicates. Without this the winner is the luckiest draw rather than
  # the largest p - the ranking gap between neighbouring candidates is
  # routinely smaller than pass 1's own standard error.
  topUp <- utils::head(order(up, decreasing = TRUE, na.last = NA),
                       .ppTableRefineTop)
  topDn <- utils::head(order(dn, na.last = NA), .ppTableRefineTop)
  for (i in topUp) up[i] <- .ppTableP(best[[keys[i]]]$hiT, .ppTableRefineReps)
  for (i in topDn) {
    e <- best[[keys[i]]]
    dn[i] <- .ppTableP(if (identical(e$hiS, e$loS)) e$hiT else e$loT,
                       .ppTableRefineReps)
  }

  wBest <- which.max(up)
  pBest <- up[wBest]; chosen <- best[[keys[wBest]]]$hiT
  pWorst <- suppressWarnings(min(dn, na.rm = TRUE))
  if (!is.finite(pWorst)) pWorst <- pBest
  if (is.null(chosen)) return(none)

  out <- cnt
  for (k in seq_along(keep)) out[keep[k], ] <- chosen[k, ]
  list(counts = out, pBest = pBest, pWorst = pWorst,
       nTables = as.integer(min(total, .Machine$integer.max)),
       nNulls = length(keys), complete = complete,
       straddles = is.finite(pBest) && is.finite(pWorst) &&
                   pWorst < .ppTableStraddle && pBest >= .ppTableStraddle)
}
