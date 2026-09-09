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

# THE ENUMERATION BOUND, and what happens at it (independent audit
# 2026-09-09, F1 and F8, and Steve Shafer's decision of the same day:
# "Skip").
#
# The guarantee this function exists to keep is that the counts analysed
# are the reading of the page MOST FAVOURABLE to the authors. That can
# only be checked by scoring every admissible reading. The first version
# tried to keep the guarantee everywhere by sampling when the set grew
# too large, and the audit showed what that bought: a bounded search on
# an eight-arm page missed a valid reading worth 0.094 in p, the fallback
# proposed 2^32 tables on a 32-arm page because it capped each arm and
# then multiplied, and when one ARM alone overflowed the search returned
# "complete" with no p and the caller silently kept the counts the old
# per-level rule had written - the very rule this replaced, restored
# without a flag, on a page that then read p < 0.0001 where a valid
# reading gives 0.59.
#
# So the search is complete or it does not happen. Above this many
# candidate tables the block is UNRESOLVED: the ambiguous cells go back
# to blank, the row is named, and an editor supplies the counts. A row
# the instrument declines to read is honest; a row it reads with a
# guarantee it cannot keep is not. This is rare - one manuscript in 558
# of the local corpus triggers the fill at all - and the rows it drops
# are the large multi-arm tables where a reconstruction deserves least
# trust.
.ppTableEnumMax <- 200000L

# Replicates used to CHOOSE between candidates, staged for the same
# reason the engine stages: a first pass ranks every distinct margin
# pair, and only the contenders at each end are re-run. This is not the p
# the app reports - P_Calc runs its own staged scheme on the chosen
# counts - it only has to rank.
.ppTableSelectReps <- 2000L
.ppTableRefineReps <- 20000L
.ppTableRefineTop  <- 6L

# The threshold at which the spread between the best and the worst
# reading is worth telling the editor about (Steve, 2026-09-08: "worst
# case only appearing if it straddles 0.01"). 0.05 is deliberately NOT
# here: it has no meaning in this instrument.
.ppTableStraddle <- 0.01

# EXTRACTION IS DETERMINISTIC (audit 2026-09-09, F9). Scoring a candidate
# simulates a null, so without this the counts a document yields would
# depend on whatever random state the caller happened to be in - and both
# guides promise the same document gives the same numbers. The analysis
# seed is set later and separately by the caller; this one belongs to the
# reader and must not move with it.
.ppTableSeed <- 20260909L

#' Every count vector for one arm consistent with its brackets
#'
#' @param lo,hi integer vectors, one per level, the bracket ends; a
#'   pinned level has lo == hi.
#' @param N the arm size, or NA when it is unknown.
#' @param partition TRUE only when the levels are known to divide the arm
#'   because this code CONSTRUCTED the complement, so the counts must sum
#'   to N. It is never inferred from the printed percentages: whether a
#'   set of categories exhausts an arm is a statement about what the
#'   categories mean, and arithmetic cannot establish it (audit
#'   2026-09-09, F2).
#' @param cap stop and return NULL beyond this many vectors.
#' @return integer matrix, one row per admissible vector, or NULL.
#' @noRd
.ppArmVectors <- function(lo, hi, N, partition, cap) {
  L <- length(lo)
  if (L == 0) return(NULL)
  width <- as.numeric(hi) - as.numeric(lo) + 1
  if (any(!is.finite(width) | width < 1)) return(NULL)
  if (!partition) {
    # no cross-level constraint at all: the cells are independent, so the
    # count is known before anything is built
    if (prod(width) > cap) return(NULL)
    g <- as.matrix(expand.grid(lapply(seq_len(L), function(j) lo[j]:hi[j])))
    dimnames(g) <- NULL
    return(matrix(as.integer(g), ncol = L))
  }
  out <- vector("list", 0L)
  cur <- integer(L)
  suffixLo <- rev(cumsum(rev(as.numeric(lo))))
  suffixHi <- rev(cumsum(rev(as.numeric(hi))))
  target <- as.numeric(N)
  if (!is.finite(target)) return(NULL)
  rec <- function(j, used) {
    if (length(out) > cap) return(invisible(NULL))
    if (j > L) {
      if (isTRUE(all.equal(used, target))) out[[length(out) + 1L]] <<- cur
      return(invisible(NULL))
    }
    restLo <- if (j < L) suffixLo[j + 1L] else 0
    restHi <- if (j < L) suffixHi[j + 1L] else 0
    for (v in lo[j]:hi[j]) {
      left <- target - used - v
      if (left < restLo || left > restHi) next
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

# THE ENGINE'S OWN STATISTIC, on the engine's own table. P_Calc drops
# every level no arm reports before computing anything (R/P_Calc.R, the
# categorical branch), and refuses a table with fewer than two levels
# left or an empty arm. A selector that scored a different table from the
# one the engine will score is choosing against the wrong objective
# (audit 2026-09-09, F7).
.ppTableReduce <- function(tab) {
  keep <- colSums(tab) > 0
  if (sum(keep) < 2) return(NULL)
  out <- tab[, keep, drop = FALSE]
  if (any(rowSums(out) == 0)) return(NULL)
  out
}

.ppTableStat <- function(tab) {
  t2 <- .ppTableReduce(tab)
  if (is.null(t2)) return(NA_real_)
  E <- outer(rowSums(t2), colSums(t2)) / sum(t2)
  if (any(!is.finite(E)) || any(E <= 0)) return(NA_real_)
  sum((t2 - E)^2 / E)
}

# ...and the engine's own probability. Three things were different and
# all three are now shared: ties are counted by .iaTieCounts()'s relative
# criterion rather than by literal floating equality, the mid-p is
# (kLess + kEq/2)/m, and the floor is .floorP(). On rbind(c(1,1), c(1,1),
# c(1,5)) the old helper returned 0.0998 where the exact answer is 0.35.
.ppTableP <- function(tab, reps) {
  t2 <- .ppTableReduce(tab)
  if (is.null(t2)) return(NA_real_)
  r <- rowSums(t2); cc <- colSums(t2)
  E <- outer(r, cc) / sum(r)
  obs <- sum((t2 - E)^2 / E)
  sims <- vapply(r2dtable(reps, r, cc), function(x) sum((x - E)^2 / E),
                 numeric(1))
  kk <- .iaTieCounts(sims, obs)
  .floorP((kk[["kLess"]] + kk[["kEq"]] / 2) / reps, reps)
}

#' Choose the counts behind a block of printed percentages
#'
#' @param lo,hi integer matrices, arms x levels, the bracket ends. NA
#'   marks a cell that is not in play.
#' @param cnt integer matrix, arms x levels, counts already pinned; NA
#'   where the percentage left more than one possibility.
#' @param N numeric, one arm size per row of the matrices.
#' @param partition TRUE only where this code constructed the complement.
#' @param reps replicates used to rank candidates.
#' @return a list: `resolved` (FALSE when the page could not be read
#'   completely, in which case `counts` is unchanged and `reason` says
#'   why), `counts`, `pBest`, `pWorst`, `nTables`, `nNulls` and
#'   `straddles`.
#' @noRd
.ppFailsafeTableFill <- function(lo, hi, cnt, N, partition = FALSE,
                                 reps = .ppTableSelectReps) {
  out <- function(resolved, reason, counts = cnt, pBest = NA_real_,
                  pWorst = NA_real_, nTables = 0L, nNulls = 0L,
                  straddles = FALSE)
    list(resolved = resolved, reason = reason, counts = counts,
         pBest = pBest, pWorst = pWorst, nTables = nTables,
         nNulls = nNulls, straddles = straddles)

  if (!is.matrix(cnt) || !nrow(cnt) || ncol(cnt) < 2)
    return(out(TRUE, "nothing ambiguous"))
  amb <- is.na(cnt) & !is.na(lo) & !is.na(hi)
  if (!any(amb)) return(out(TRUE, "nothing ambiguous"))
  keep <- which(is.finite(N) & N > 0 & rowSums(!is.na(cnt) | amb) == ncol(cnt))
  if (length(keep) < 2)
    return(out(FALSE, "fewer than two arms report this variable"))

  # the reader's own random state, so the same document always yields the
  # same counts whatever the caller was doing (F9)
  oldSeed <- if (exists(".Random.seed", envir = globalenv()))
               get(".Random.seed", envir = globalenv()) else NULL
  on.exit({
    if (is.null(oldSeed)) suppressWarnings(rm(".Random.seed", envir = globalenv()))
    else assign(".Random.seed", oldSeed, envir = globalenv())
  }, add = TRUE)
  set.seed(.ppTableSeed)

  vecs <- vector("list", length(keep))
  for (k in seq_along(keep)) {
    i <- keep[k]
    l <- ifelse(amb[i, ], lo[i, ], cnt[i, ])
    h <- ifelse(amb[i, ], hi[i, ], cnt[i, ])
    if (anyNA(l) || anyNA(h))
      return(out(FALSE, "a cell has no bracket"))
    v <- .ppArmVectors(as.integer(l), as.integer(h), N[i], partition,
                       .ppTableEnumMax)
    if (is.null(v) || !nrow(v))
      return(out(FALSE, sprintf(
        "one arm alone allows more readings than can be enumerated (over %s)",
        format(.ppTableEnumMax, big.mark = ","))))
    vecs[[k]] <- v
  }
  sizes <- vapply(vecs, nrow, integer(1))
  total <- prod(as.numeric(sizes))
  if (!is.finite(total) || total > .ppTableEnumMax)
    return(out(FALSE, sprintf(
      "the page allows about %s readings, more than can be enumerated (over %s)",
      if (!is.finite(total) || total >= 1e7)
        format(signif(total, 3), scientific = TRUE)
      else format(signif(total, 3), big.mark = ",", scientific = FALSE),
      format(.ppTableEnumMax, big.mark = ","))))

  # Group by BOTH margins (audit 2026-09-09, F7). The monotonicity that
  # lets a group be represented by its extreme tables - same null, so the
  # mid-p cannot decrease with the statistic - holds only when the null
  # is the same, and the null is fixed by both margins. Without the
  # partition constraint the arm totals vary too, so keying on the level
  # totals alone would prune across different nulls.
  best <- new.env(hash = TRUE, parent = emptyenv())
  idx <- integer(length(vecs))
  for (r in seq_len(as.integer(total))) {
    # decode r into one choice per arm without materialising the grid
    rest <- r - 1L
    for (k in seq_along(vecs)) {
      idx[k] <- (rest %% sizes[k]) + 1L
      rest <- rest %/% sizes[k]
    }
    tab <- do.call(rbind, Map(function(m, i) m[i, ], vecs, idx))
    st <- .ppTableStat(tab)
    if (!is.finite(st)) next
    key <- paste(c(rowSums(tab), -1L, colSums(tab)), collapse = ",")
    e <- best[[key]]
    if (is.null(e)) best[[key]] <- list(hiT = tab, hiS = st, loT = tab, loS = st)
    else {
      if (st > e$hiS) { e$hiT <- tab; e$hiS <- st }
      if (st < e$loS) { e$loT <- tab; e$loS <- st }
      best[[key]] <- e
    }
  }
  keys <- ls(best)
  if (!length(keys))
    return(out(FALSE, "no reading of this page gives a table the engine can score"))

  up <- vapply(keys, function(k) .ppTableP(best[[k]]$hiT, reps), numeric(1))
  dn <- vapply(keys, function(k) {
    e <- best[[k]]
    if (identical(e$hiS, e$loS)) NA_real_ else .ppTableP(e$loT, reps)
  }, numeric(1))
  dn[is.na(dn)] <- up[is.na(dn)]
  if (!any(is.finite(up)))
    return(out(FALSE, "no reading of this page could be scored"))

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
  chosen <- best[[keys[wBest]]]$hiT
  pBest <- up[wBest]
  pWorst <- suppressWarnings(min(dn, na.rm = TRUE))
  if (!is.finite(pWorst)) pWorst <- pBest

  filled <- cnt
  for (k in seq_along(keep)) filled[keep[k], ] <- chosen[k, ]
  out(TRUE, "enumerated completely", counts = filled, pBest = pBest,
      pWorst = pWorst, nTables = as.integer(min(total, .Machine$integer.max)),
      nNulls = length(keys),
      straddles = is.finite(pBest) && is.finite(pWorst) &&
                  pWorst < .ppTableStraddle && pBest >= .ppTableStraddle)
}
