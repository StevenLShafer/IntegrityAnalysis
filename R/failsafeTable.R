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
# HOW MANY OF THE DISTINCT NULLS ARE SCORED AT ALL (security screens
# 2026-09-08-2100 F1 and 2026-09-09-0721 F1; Steve Shafer's decision,
# 2026-09-09). Scoring EVERY distinct margin pair was the dominant cost
# of this file and, on merged main, of parsing at all: an entirely
# ordinary Table 1 - two arms of 700, a three-level "ASA physical status,
# %" row printing 25/42/33 and 28/39/33 - produced 20,449 distinct nulls
# and took 190 s end to end, past the 60 s subprocess timeout, so the
# document did not parse slowly, it FAILED TO PARSE. The author of the
# manuscript under investigation chose that by printing a category as
# percentages.
#
# The groups are therefore RANKED BY THEIR STATISTIC and only this many
# scored at each end. The ranking is free, deterministic, and not a
# heuristic in disguise: the p here is the LEFT tail - the probability a
# replicate is at least as homogeneous as the printed table - so within
# one null it increases with the statistic, and pchisq(stat, df) is the
# asymptotic form of exactly that quantity, which for a shared df orders
# the groups by the statistic itself.
#
# MEASURED against the exhaustive pass on nine shapes (the evidence sits
# in the adjudication of these screens). Every partition = TRUE shape
# chose IDENTICAL counts. Every disagreement was a partition = FALSE
# shape, and every one of them chose a LARGER p than the exhaustive pass:
#
#   25/42/33, arms of 700   exhaustive 0.09517   ranked 0.1013
#   10/20/70, arms of 500   exhaustive 0.1331    ranked 0.1363
#   20/30/50, arms of 300   exhaustive 0.03583   ranked 0.03617
#   33/33/34, three arms    exhaustive 0.00135   ranked 0.001575
#
# That direction is not luck. Ranking thousands of noisy 2,000-replicate
# estimates and refining the best six selects on upward noise, and the
# refinement then takes it back - the winner's curse - so the reported
# best case was biased LOW, which in this instrument is the ACCUSING
# direction and the one the whole fail-safe exists to avoid. A noiseless
# ranking cannot have that bias. Fifty is well past the top-six coverage
# measured over 77 further shapes (rank 1 in 46, within six in 72).
.ppTableRankMax <- 50L

# AND A BOUND ON THE MEMORY THE COLUMN-WISE PASS ASKS FOR. .ppTableEnumMax
# bounds the number of candidate READINGS; the working set is that times
# the arms times the levels, and neither of those is bounded - the arm
# count is however many numeric columns the page has, and the level count
# however many lines the category block has. prod(sizes) stays inside the
# cap when 29 arms contribute one reading each and one arm contributes
# 200,000, so a .docx with thirty columns and ten levels would have asked
# for about half a gigabyte in one allocation. That is the shape screen
# 2026-09-08-2100 found in the old sampling fallback (F3, "2^arms"), and
# it must not come back through the fix for F1. Five million cells is
# about 40 MB per copy, and the ordinary block this all exists for -
# 117,649 readings, two arms, three levels - needs 705,894.
.ppTableCellMax <- 5e6
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
# HOW MANY VECTORS THERE ARE, WITHOUT BUILDING ONE (security screen
# 2026-09-08-2100, F1). .ppArmVectors() below decides that a block cannot
# be enumerated by enumerating it until it passes the cap, so the DECLINE
# - the honest outcome, and the common one on a hostile page - was the
# most expensive thing this file did: measured on merged main at
# 65e2a04, one two-arm three-level row cost 28 s at N = 50,000, 53 s at
# N = 200,000 and 153 s at N = 500,000, every second of it spent
# producing an answer that was then thrown away. A ten-kilobyte document
# with a handful of such rows is a parse-budget denial of service, and a
# denial of ANALYSIS: past the 60 s child timeout the manuscript fails to
# parse at all, so an author can make their own paper unreadable to the
# screen with an ordinary-looking Table 1.
#
# The count is exact and costs nothing. Without the partition constraint
# the cells are independent and the count is the product of the widths -
# which .ppArmVectors() already checked. With it, the count is the number
# of integer vectors in the boxes that sum to N: a one-dimensional
# convolution of the levels' indicator polynomials, done with a running
# sum in O(levels x N) arithmetic. Doubles overflow to Inf on the huge
# cases, which is the correct comparison against any finite cap.
# HOW MUCH THE COUNT ITSELF MAY ALLOCATE (security screen 2026-09-09-1532,
# F1). The convolution below is O(levels x M) in TIME and allocates M + 1
# doubles, where M is the slack the brackets leave - about 1% of the arm N
# for a printed percentage. The parser applies no plausibility ceiling to
# an arm N it reads off a page, so a header reading "(n = 2000000000)" put
# 1 GB through this function to produce a number that was then compared
# against a 200,000 cap and thrown away. The fix for the previous screen's
# F1 had converted an O(search space) CPU burn into an O(arm N)
# allocation; the decline path was still the most expensive thing here.
# A million coefficients is about 8 MB and is far past any real table.
.ppArmVectorDpMax <- 1e6

.ppArmVectorCount <- function(lo, hi, N, partition) {
  L <- length(lo)
  if (L == 0) return(0)
  w <- as.numeric(hi) - as.numeric(lo) + 1
  if (any(!is.finite(w) | w < 1)) return(0)
  if (!partition) return(prod(w))
  target <- as.numeric(N)
  if (!is.finite(target)) return(0)
  M <- target - sum(as.numeric(lo))
  if (M < 0 || M > sum(w - 1)) return(0)
  # TWO LEVELS NEED NO CONVOLUTION AT ALL, and two levels is every
  # partition block the parser can currently build: a binary "n (%)" row,
  # whose complement column this code constructs itself. The admissible
  # first-level counts are the overlap of its own bracket with what the
  # second level's bracket leaves of N, so the count is the length of an
  # interval. Exact, constant time, no allocation.
  if (L == 2L) {
    loEnd <- max(as.numeric(lo[1]), target - as.numeric(hi[2]))
    hiEnd <- min(as.numeric(hi[1]), target - as.numeric(lo[2]))
    return(max(0, hiEnd - loEnd + 1))
  }
  # Past two levels the convolution is the honest way to count, but it is
  # bounded: over the ceiling this returns Inf, which the caller reads as
  # "more than any cap" and declines, rather than allocating to find out.
  if (M > .ppArmVectorDpMax) return(Inf)
  M <- as.integer(M)
  f <- c(1, numeric(M))                    # coefficients of z^0 .. z^M
  for (j in seq_len(L)) {
    wj <- as.integer(w[j] - 1)             # this level contributes z^0..z^wj
    if (wj == 0) next                      # a pinned level multiplies by 1
    cs <- cumsum(f)
    f <- cs - c(numeric(min(wj + 1L, M + 1L)), cs)[seq_len(M + 1L)]
  }
  f[M + 1L]
}

.ppArmVectors <- function(lo, hi, N, partition, cap) {
  L <- length(lo)
  if (L == 0) return(NULL)
  width <- as.numeric(hi) - as.numeric(lo) + 1
  if (any(!is.finite(width) | width < 1)) return(NULL)
  # count first, build second (F1): the cap is now decided before any
  # vector exists, so an unenumerable block declines in milliseconds
  n <- .ppArmVectorCount(lo, hi, N, partition)
  if (!is.finite(n) || n <= 0 || n > cap) return(NULL)
  if (!partition) {
    # no cross-level constraint at all: the cells are independent, so the
    # count is known before anything is built
    if (prod(width) > cap) return(NULL)
    # ...but the GRID is prod(width) x L, and L - the number of lines in
    # the category block - is bounded only by the uploaded table (security
    # screen 2026-09-09-1532, F2). A level printed as an explicit count has
    # width 1 and does not raise the product, so levels come free: measured
    # at prod(width) = 200,000, 10 levels cost 154 MB and 300 levels 1,096
    # MB, all of it spent to answer "no". expand.grid() + as.matrix() +
    # matrix() makes about three copies, so the budget is charged here
    # rather than at the candidate grid, which is checked much later.
    # The budget is the CELLS, and .ppTableCellMax is 5 million of them -
    # about 40 MB, or 120 MB across the three copies expand.grid(),
    # as.matrix() and matrix() make. Charging the copies to the cap as
    # well was the first thing written here and it was too strict: it
    # declined a ten-level category at 200,000 readings, which is 2
    # million cells and 16 MB, and a ten-level category on a few hundred
    # patients is an ordinary table. The rule is a memory bound, not a
    # dislike of long blocks.
    if (prod(width) * L > .ppTableCellMax) return(NULL)
    g <- as.matrix(expand.grid(lapply(seq_len(L), function(j) lo[j]:hi[j])))
    dimnames(g) <- NULL
    return(matrix(as.integer(g), ncol = L))
  }
  # THE LIST IS PRE-SIZED, because the count above is exact (F1). It used
  # to grow one element at a time with out[[length(out) + 1L]] <<- cur,
  # which re-allocates: 188,251 vectors - an ordinary three-level row at
  # N = 50,000, inside the cap and therefore ANALYSED, not declined - took
  # 19.2 s to build on merged main and 0.6 s here, the same vectors in the
  # same order. Indexed assignment into a list of known length does not
  # reallocate, so the cost is now proportional to the answer.
  out <- vector("list", as.integer(n))
  pos <- 0L
  cur <- integer(L)
  suffixLo <- rev(cumsum(rev(as.numeric(lo))))
  suffixHi <- rev(cumsum(rev(as.numeric(hi))))
  target <- as.numeric(N)
  if (!is.finite(target)) return(NULL)
  # THE LAST LEVEL IS NOT SEARCHED (F1). Its value is determined by the
  # others - the counts sum to N - so the innermost loop was walking the
  # whole bracket to accept exactly one value, and testing each with
  # all.equal(), whose tolerance machinery costs far more than the
  # arithmetic it guards. That single line was the 19.2 s: the same row at
  # N = 50,000 enumerates its 188,251 vectors in 0.6 s once the last level
  # is computed instead of searched. The equality is exact rather than
  # approximate because every quantity here is a sum of integers held in a
  # double, which is exact to 2^53 - far above the .iaMaxArmN ceiling.
  rec <- function(j, used) {
    if (j == L) {
      v <- target - used
      if (v >= lo[L] && v <= hi[L]) {
        cur[L] <<- as.integer(v)
        pos <<- pos + 1L
        out[[pos]] <<- cur
      }
      return(invisible(NULL))
    }
    restLo <- suffixLo[j + 1L]
    restHi <- suffixHi[j + 1L]
    for (v in lo[j]:hi[j]) {
      left <- target - used - v
      if (left < restLo || left > restHi) next
      cur[j] <<- v
      rec(j + 1L, used + v)
    }
    invisible(NULL)
  }
  if (L == 1L) {
    if (target >= lo[1L] && target <= hi[1L]) { pos <- 1L; out[[1L]] <- as.integer(target) }
  } else rec(1L, 0)
  # the count and the walk must agree; if they ever did not, the block is
  # declined rather than analysed on a partial enumeration
  if (pos != as.integer(n)) return(NULL)
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
# WHAT THE SCORING MAY COST IN TIME (security screen 2026-09-10-0734,
# F1). The gate of screen 0633 bounded the CELLS a table has, and its log
# entry said that bounded the time. Measured, it did not: r2dtable() pays
# a setup proportional to the GRAND TOTAL on every call, and the per-table
# draw is proportional to the cells, so with the rank cap fixing the
# number of calls at about 112 and the tables at about 440,000, the time
# is close to
#
#   1.0e-7 s x tables x cells   +   3.5e-7 s x calls x grand total
#
# on this machine - and a 125-arm binary block at 5,000 per arm, 250
# cells and a grand total of 625,000, passed the cell gate and took 54 s
# to RESOLVE, inside the 60 s child timeout with nothing left for the
# rest of the document. Both terms are bounded here, from that model:
# at most 100 cells (about 4.6 s of draws at the worst) and a grand total
# of at most 125,000 (about 4.9 s of setup), so the largest admitted
# block scores in under ten seconds rather than fifty. What that
# excludes is not an RCT baseline table: four arms by twenty-five levels
# is admitted, five by twenty-five is not, and twenty-five arms of 5,000
# is the grand-total line.
.ppTableScoreCells <- 100L
.ppTableScoreTotal <- 125000

# THE NULL IS DRAWN IN CHUNKS SIZED BY THE TABLE (security screens
# 2026-09-10-0633 F1 and -0734 F1). r2dtable() returns a LIST of reps
# integer matrices, arms x levels, all at once: 20,000 x 200 x 37 x 4
# bytes is about 590 MB in a single call, and the table's dimensions are
# whatever the page has. Drawing in chunks bounds the peak at chunk x
# cells. The result is RNG-identical: r2dtable draws one table at a time
# from the stream, so k chunks of c tables give the same tables as one
# call of k*c - the engine's categorical branch verified exactly that in
# the 2026-08-28 screen and relies on it.
#
# The chunk is SIZED BY THE CELLS, not fixed (screen 0734). A fixed
# chunk of 500 turned one call of 20,000 into forty, and r2dtable()
# allocates and fills a log-factorial table of length equal to the grand
# total on EVERY call before it draws anything - so at a grand total of
# 625,000 the forty calls cost 2.24 s where one cost 1.26 s, and the
# largest admitted block went from 34 s to 54 s. This is the engine's own
# idiom (R/P_Calc.R, the categorical branch): at or under 250 cells, the
# most the scoring gate admits, 1e7 / cells is at least 40,000, so a
# refinement of 20,000 replicates is ONE call again, and the memory
# bound is exactly the engine's.
.ppTableDrawCells <- 1e7

.ppTableP <- function(tab, reps) {
  t2 <- .ppTableReduce(tab)
  if (is.null(t2)) return(NA_real_)
  r <- rowSums(t2); cc <- colSums(t2)
  E <- outer(r, cc) / sum(r)
  obs <- sum((t2 - E)^2 / E)
  sims <- numeric(reps)
  done <- 0L
  chunk <- max(1L, as.integer(floor(.ppTableDrawCells / max(1, length(t2)))))
  while (done < reps) {
    ch <- min(chunk, reps - done)
    sims[done + seq_len(ch)] <- vapply(r2dtable(ch, r, cc),
                                       function(x) sum((x - E)^2 / E),
                                       numeric(1))
    done <- done + ch
  }
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
#'   why), `counts`, `pBest`, `pWorst`, `worstAtFloor` (TRUE when the
#'   worst case is the Monte Carlo floor rather than an estimate),
#'   `nTables`, `nNulls`, `nScored` (how many of those nulls were
#'   simulated) and `straddles`.
#' @noRd
.ppFailsafeTableFill <- function(lo, hi, cnt, N, partition = FALSE,
                                 reps = .ppTableSelectReps) {
  out <- function(resolved, reason, counts = cnt, pBest = NA_real_,
                  pWorst = NA_real_, nTables = 0L, nNulls = 0L,
                  straddles = FALSE, worstAtFloor = FALSE, nScored = 0L)
    list(resolved = resolved, reason = reason, counts = counts,
         pBest = pBest, pWorst = pWorst, nTables = nTables,
         nNulls = nNulls, nScored = nScored, straddles = straddles,
         worstAtFloor = worstAtFloor)

  if (!is.matrix(cnt) || !nrow(cnt) || ncol(cnt) < 2)
    return(out(TRUE, "nothing ambiguous"))
  amb <- is.na(cnt) & !is.na(lo) & !is.na(hi)
  if (!any(amb)) return(out(TRUE, "nothing ambiguous"))
  keep <- which(is.finite(N) & N > 0 & rowSums(!is.na(cnt) | amb) == ncol(cnt))
  if (length(keep) < 2)
    return(out(FALSE, "fewer than two arms report this variable"))
  # DEFENCE IN DEPTH: an arm the analysis will never accept is not worth
  # reconstructing (security screen 2026-09-09-1532, F1). .iaMaxArmN is
  # the app's own editorial ceiling and validateData() rejects the trial
  # above it, so every byte spent rebuilding counts for an arm of two
  # billion was spent before the row could possibly be analysed. The
  # parser applies no ceiling of its own to an arm N read off a page, so
  # this is where the two meet.
  if (any(N[keep] > .iaMaxArmN))
    return(out(FALSE, sprintf(
      "an arm of %s is above the %s the analysis accepts",
      format(max(N[keep]), big.mark = ", ", scientific = FALSE, trim = TRUE),
      format(.iaMaxArmN, big.mark = ","))))

  # THE SCORING COST IS CHARGED BEFORE ANYTHING IS BUILT (security screen
  # 2026-09-10-0633, F1). Every gate above bounds how many candidate
  # tables EXIST. A block with every level printed as a count has width 1
  # everywhere, so one percentage cell admitting two counts gives exactly
  # two candidates at any size - and passes every one of those gates at
  # 200 arms by 37 levels. The scoring then simulates each candidate's
  # null with r2dtable over the whole arms-by-levels table, so its cost is
  # the table's DIMENSIONS times the replicates, which nothing had
  # charged. Measured on 2260045 with two candidates: 60 x 37 took 41 s
  # and 491 MB, 200 x 37 took 148 s and 1,008 MB - inside the 60 s child
  # timeout for the first refinement call, so the timeout did not stop the
  # allocation, and the child has no memory ceiling (ISSUES 32).
  #
  # The bound is cells x refine replicates against the cell budget: 250
  # cells per table at 20,000 replicates, which admits any block an RCT
  # baseline table prints (ten arms by twenty levels is 200) and refuses
  # the shape above. Chunked drawing in .ppTableP() bounds the memory
  # independently; this bounds the time.
  # It depends only on the dimensions and the arm sizes, all known here, so
  # it sits before the enumeration rather than after it: a block it refuses
  # used to spend up to 3 s enumerating and scoring candidates first
  # (screen 2026-09-10-0734).
  # THE QUANTITY r2dtable() PAYS FOR IS THE SUM OF THE TABLE, NOT THE SUM
  # OF THE ARM SIZES (security screen 2026-09-10-0815, F1 and F2). The
  # gate below measured sum(N[keep]) and called it the grand total. Two
  # things reach the scored table that N does not bound: a level printed
  # as a COUNT arrives from the page with no ceiling at all, and on the
  # percentage route the levels need not sum to N, so a block of 25
  # levels each printing "100.00" has a table sum of 25 x N. Measured
  # through the JATS reader on 24a8177: two arms of 5,000 with two count
  # levels printing 25,000,000 and one ambiguous percentage - six cells,
  # a "grand total" of 10,000, admitted - took 95 s and 892 MB and was
  # killed at the child's timeout; four arms by 25 levels pinned at N took
  # 27 s where this file claimed under ten.
  #
  # The analysis engine already refuses exactly this, one function later:
  # validateData() rejects a category line whose counts total more than
  # .iaMaxArmN, "because r2dtable on a billion patients asked for 134
  # million TB". Every cost above was spent on a row that would then have
  # been refused. So the same rule is applied HERE, before anything is
  # built, on the cells AS THEY WILL BE SCORED - the bracket's top where a
  # cell is ambiguous, the printed count where it is pinned - and the
  # grand total the time bound uses is the sum of those row totals.
  # ...except where the levels PARTITION the arm. There the scored table's
  # row total is exactly N by construction, and summing the bracket TOPS
  # overstates it: a binary "n (%)" row at the arm ceiling has tops of
  # 2,375 and 2,675 against an N of 5,000, and the first form of this
  # rule refused it - an honest row thrown out, which is the failure the
  # full suite caught before it shipped (test-screen-2026-09-09-1532.R).
  rowTotal <- if (isTRUE(partition)) as.numeric(N[keep]) else
    vapply(keep, function(i)
      sum(as.numeric(ifelse(amb[i, ], hi[i, ], cnt[i, ])), na.rm = TRUE), numeric(1))
  if (any(!is.finite(rowTotal)) || any(rowTotal > .iaMaxArmN))
    return(out(FALSE, sprintf(paste(
      "the counts total more than %s in at least one arm, which the",
      "analysis would refuse"), format(.iaMaxArmN, big.mark = ","))))
  cells <- as.numeric(length(keep)) * ncol(cnt)
  grandTotal <- sum(rowTotal)
  if (cells * .ppTableRefineReps > .ppTableCellMax || cells > .ppTableScoreCells ||
      grandTotal > .ppTableScoreTotal)
    return(out(FALSE, sprintf(paste(
      "this block is too large to score: %d arms by %d levels over a table",
      "total of %s is more than the simulation can carry in the time it has"),
      nrow(cnt), ncol(cnt), format(grandTotal, big.mark = ","))))


  # the reader's own random state, so the same document always yields the
  # same counts whatever the caller was doing (F9)
  oldSeed <- if (exists(".Random.seed", envir = globalenv()))
               get(".Random.seed", envir = globalenv()) else NULL
  on.exit({
    if (is.null(oldSeed)) suppressWarnings(rm(".Random.seed", envir = globalenv()))
    else assign(".Random.seed", oldSeed, envir = globalenv())
  }, add = TRUE)
  set.seed(.ppTableSeed)

  # COUNT EVERY ARM BEFORE BUILDING ANY (security screen 2026-09-10-0536,
  # F1) - the same "count first, build second" move .ppArmVectors() already
  # makes one level down, which this loop was defeating one level up.
  #
  # The cell budget added by screen 1532 bounds ONE arm's enumeration. This
  # loop built an arm at a time and RETAINED each in `vecs`, and only then
  # computed prod(sizes) and declined, so nothing charged the sum. The arm
  # count is the number of numeric columns the uploaded table has, and the
  # readers admit up to .ppMaxTableCols (200). A JATS table of arms at
  # exactly .iaMaxArmN, with three integer-percentage levels and 34 more
  # pinned at two decimals - width 1, free under a product cap - puts each
  # arm at 132,651 x 37 = 4.9M cells, just inside the per-arm budget, and
  # then multiplies it by the arm count:
  #
  #    30 arm columns (46 KB of XML)     855 MB    4.8 s   then declined
  #    60 arm columns (91 KB of XML)   1,636 MB    9.4 s   then declined
  #
  # Every byte of it to compute prod(sizes), which is Inf past a couple of
  # arms and is thrown away. The subprocess timeout does not stop it: the
  # 200-column ceiling the readers already allow extrapolates to about 5 GB
  # peak in roughly 31 s, and the parse child still has no memory ceiling
  # (ISSUES 32), so on a 1 GB instance that is the container's OOM rather
  # than a decline.
  #
  # The counts are cheap: a product of widths without the partition
  # constraint, constant time for the two-level partition case, and bounded
  # by .ppArmVectorDpMax past that. On the 60-arm case prod() is Inf and the
  # block declines in microseconds.
  bracket <- vector("list", length(keep))
  counts  <- numeric(length(keep))
  for (k in seq_along(keep)) {
    i <- keep[k]
    l <- ifelse(amb[i, ], lo[i, ], cnt[i, ])
    h <- ifelse(amb[i, ], hi[i, ], cnt[i, ])
    if (anyNA(l) || anyNA(h))
      return(out(FALSE, "a cell has no bracket"))
    bracket[[k]] <- list(l = as.integer(l), h = as.integer(h), N = N[i])
    counts[k] <- .ppArmVectorCount(as.integer(l), as.integer(h), N[i], partition)
    if (!is.finite(counts[k]) || counts[k] <= 0 || counts[k] > .ppTableEnumMax)
      return(out(FALSE, sprintf(
        "one arm alone allows more readings than can be enumerated (over %s)",
        format(.ppTableEnumMax, big.mark = ","))))
  }
  total <- prod(counts)
  if (!is.finite(total) || total > .ppTableEnumMax)
    return(out(FALSE, sprintf(
      "the page allows about %s readings, more than can be enumerated (over %s)",
      if (!is.finite(total) || total >= 1e7)
        format(signif(total, 3), scientific = TRUE)
      else format(signif(total, 3), big.mark = ",", scientific = FALSE),
      format(.ppTableEnumMax, big.mark = ","))))
  # ...and the cell budget bounds the BLOCK, not each arm on its own. The
  # per-arm check inside .ppArmVectors() stays as defence in depth.
  if (sum(counts) * ncol(cnt) > .ppTableCellMax)
    return(out(FALSE, sprintf(
      "this block is too wide to read: %s arm(s) of readings across %d levels is more than can be held at once",
      format(length(keep), big.mark = ","), ncol(cnt))))

  vecs <- vector("list", length(keep))
  for (k in seq_along(keep)) {
    b <- bracket[[k]]
    v <- .ppArmVectors(b$l, b$h, b$N, partition, .ppTableEnumMax)
    if (is.null(v) || !nrow(v))
      return(out(FALSE, sprintf(
        "one arm alone allows more readings than can be enumerated (over %s)",
        format(.ppTableEnumMax, big.mark = ","))))
    vecs[[k]] <- v
  }
  sizes <- vapply(vecs, nrow, integer(1))

  # Group by BOTH margins (audit 2026-09-09, F7). The monotonicity that
  # lets a group be represented by its extreme tables - same null, so the
  # mid-p cannot decrease with the statistic - holds only when the null
  # is the same, and the null is fixed by both margins. Without the
  # partition constraint the arm totals vary too, so keying on the level
  # totals alone would prune across different nulls.
  #
  # DONE IN WHOLE COLUMNS, not one candidate at a time (security screens
  # 2026-09-08-2100 and 2026-09-09-0721, F1). The loop this replaces
  # rebuilt a matrix, called .ppTableStat() and pasted a key per
  # candidate: 87 microseconds each, which is 10.2 s on the 117,649
  # readings of an ordinary two-arm three-level percentage block, before
  # a single null had been simulated. That cost alone does not fit the
  # 60 s parse budget once a document has several such rows.
  #
  # The statistic is the same quantity, rearranged so it can be computed
  # for every candidate at once. With row totals r, column totals c and
  # grand total n, E = r c / n, and
  #
  #   sum (T - E)^2 / E  =  n * ( sum T^2 / (r c)  -  1 )
  #
  # which is exact, not an approximation - and every term on the right is
  # a column operation over the candidate grid. The degenerate cases
  # .ppTableStat() handles by reducing the table first are kept: a level
  # no arm reports contributes nothing and is dropped from the count of
  # surviving levels, fewer than two survivors is NA, and an empty arm is
  # NA. .ppTableStat() remains the single definition of the statistic and
  # this is pinned against it candidate by candidate in the tests.
  ncand <- as.integer(total)
  nArm <- length(vecs)
  nLev <- ncol(vecs[[1]])
  if (as.numeric(ncand) * nArm * nLev > .ppTableCellMax)
    return(out(FALSE, sprintf(paste(
      "this block is too wide to read: %s readings across %d arms and %d",
      "levels is more than can be held at once"),
      format(ncand, big.mark = ","), nArm, nLev)))
  # the choice each candidate makes in each arm, decoded in whole columns
  pick <- matrix(0L, ncand, nArm)
  repEach <- 1L
  for (k in seq_len(nArm)) {
    pick[, k] <- rep(rep(seq_len(sizes[k]), each = repEach),
                     length.out = ncand)
    repEach <- repEach * sizes[k]
  }
  # T for every candidate, one matrix per arm; then the two margins
  Tm <- lapply(seq_len(nArm), function(k) vecs[[k]][pick[, k], , drop = FALSE])
  R <- vapply(Tm, function(m) rowSums(m), numeric(ncand))
  dim(R) <- c(ncand, nArm)
  C <- Reduce(`+`, Tm)
  n <- rowSums(R)
  # sum T^2 / (r c), with a level no arm reports contributing nothing
  acc <- numeric(ncand)
  for (k in seq_len(nArm)) {
    q <- Tm[[k]]^2 / (R[, k] * C)
    q[!is.finite(q)] <- 0            # c == 0 (empty level) or r == 0 (empty arm)
    acc <- acc + rowSums(q)
  }
  st <- n * (acc - 1)
  # the refusals .ppTableReduce() makes: fewer than two levels any arm
  # reports, or an arm reporting nothing at all
  st[rowSums(C > 0) < 2L] <- NA_real_
  st[rowSums(R == 0) > 0L] <- NA_real_
  st[!is.finite(st)] <- NA_real_
  ok <- which(!is.na(st))
  if (!length(ok))
    return(out(FALSE, "no reading of this page gives a table the engine can score"))

  # the group each candidate belongs to, and the extreme candidate at
  # each end of each group - both in one pass, by ordering rather than by
  # a per-group call
  key <- do.call(paste, c(as.data.frame(cbind(R[ok, , drop = FALSE],
                                              C[ok, , drop = FALSE])),
                          sep = ","))
  f <- factor(key)
  ordr <- order(f, st[ok])
  fo <- f[ordr]
  loCand <- ok[ordr[!duplicated(fo)]]                    # smallest statistic
  hiCand <- ok[ordr[!duplicated(fo, fromLast = TRUE)]]   # largest statistic
  keys <- levels(f)
  hiS <- st[hiCand]
  loS <- st[loCand]
  # a candidate's table, rebuilt only for the few that are scored
  tabOf <- function(cand)
    do.call(rbind, lapply(seq_len(nArm),
                          function(k) vecs[[k]][pick[cand, k], ]))
  if (!length(keys))
    return(out(FALSE, "no reading of this page gives a table the engine can score"))

  # ONLY THE EXTREMES ARE SCORED (.ppTableRankMax, above). The best case
  # can only be the least alike readings and the worst case only the most
  # alike, so the groups are ordered by the statistic - free and exact -
  # and the simulation is spent at the two ends instead of uniformly over
  # thousands of groups that cannot win either way.
  candUp <- utils::head(order(hiS, decreasing = TRUE, na.last = NA),
                        .ppTableRankMax)
  candDn <- utils::head(order(loS, na.last = NA), .ppTableRankMax)
  up <- rep(NA_real_, length(keys))
  dn <- rep(NA_real_, length(keys))
  for (i in candUp) up[i] <- .ppTableP(tabOf(hiCand[i]), reps)
  for (i in candDn) dn[i] <- .ppTableP(tabOf(loCand[i]), reps)
  if (!any(is.finite(up)))
    return(out(FALSE, "no reading of this page could be scored"))

  topUp <- utils::head(order(up, decreasing = TRUE, na.last = NA),
                       .ppTableRefineTop)
  topDn <- utils::head(order(dn, na.last = NA), .ppTableRefineTop)
  for (i in topUp) up[i] <- .ppTableP(tabOf(hiCand[i]), .ppTableRefineReps)
  for (i in topDn) dn[i] <- .ppTableP(tabOf(loCand[i]), .ppTableRefineReps)

  # EVERY REPORTED NUMBER COMES FROM THE REFINED SET (security screen
  # 2026-09-08-2100, F5). Both of these used to range over ALL groups
  # after only .ppTableRefineTop of them had been re-run at the larger
  # budget, so the answer was a max (and a min) over a mixture of
  # 2,000-replicate and 20,000-replicate estimates whose FLOORS differ
  # tenfold - 1/2001 against 1/20001. Two consequences, both measured on
  # the screen's own cases: `pWorst` came back as exactly 0.5/2001 and
  # 2/2001, i.e. the ranking pass's resolution rather than an estimate of
  # anything, and a minimum over thousands of noisy estimates is biased
  # low; and `which.max(up)` could return a group that was never refined,
  # so the counts ANALYSED could be chosen on the coarse pass while the p
  # beside them came from the fine one. Restricting both to the refined
  # indices is also strictly closer to the engine's own staged scheme,
  # which never compares across budgets.
  wBest <- if (length(topUp)) topUp[which.max(up[topUp])] else which.max(up)
  chosen <- tabOf(hiCand[wBest])
  pBest <- up[wBest]
  pWorst <- suppressWarnings(min(if (length(topDn)) dn[topDn] else dn,
                                 na.rm = TRUE))
  if (!is.finite(pWorst)) pWorst <- pBest
  # ...and when it lands on the floor it is reported as the inequality it
  # is. .floorP() returns 1/(m + 1) for anything below it, so a worst case
  # AT that value means "no replicate in 20,000 was this homogeneous",
  # not "p = 5e-05".
  worstAtFloor <- is.finite(pWorst) && pWorst <= 1 / (.ppTableRefineReps + 1)

  filled <- cnt
  for (k in seq_along(keep)) filled[keep[k], ] <- chosen[k, ]
  out(TRUE, "enumerated completely", counts = filled, pBest = pBest,
      pWorst = pWorst, worstAtFloor = worstAtFloor,
      nTables = as.integer(min(total, .Machine$integer.max)),
      nNulls = length(keys),
      nScored = as.integer(length(unique(c(candUp, candDn)))),
      straddles = is.finite(pBest) && is.finite(pWorst) &&
                  pWorst < .ppTableStraddle && pBest >= .ppTableStraddle)
}
