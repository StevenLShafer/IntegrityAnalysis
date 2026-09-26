# armNRecovery.R - recover missing treatment-arm sizes deterministically.
#
############################################################################
# Provenance                                                               #
# Written 2026-08-21 by Claude Code (model: Claude Fable 5) at Steve       #
# Shafer's request, after running all 654 A&A RCT submissions through the  #
# deterministic engine and through the AI engine separately and comparing: #
# the single largest deterministic deficit was the arm N. 583 skipped      #
# n (%) rows across the corpus were blocked ONLY on an unknown arm N, and  #
# the arm-N sets agreed with the AI reading on just 255 of 453 co-parsed   #
# files - while the Ns were nearly always printed somewhere: in the very   #
# n (%) cells being skipped, in the randomization sentence of the Methods, #
# or in the CONSORT flow labels.                                           #
#                                                                          #
# Everything here is deterministic - no AI service is called. Every        #
# recovered N is traceable: either to printed cells of the table itself    #
# (the count and its percentage bracket the arm size), or to a quoted      #
# sentence of the document, which is recorded and surfaced by              #
# reviewFlags() so a human can verify it against the CONSORT diagram.      #
# Status: run and verified by tests/testthat/test-armn-recovery.R and a    #
# full re-run of the 654-submission corpus.                                #
############################################################################

# --------------------------------------------------------------------------
# Source 1: the table's own n (%) cells
# --------------------------------------------------------------------------
# A printed cell "13 (68.4%)" pins the arm size tightly: the true proportion
# lies within half a printed unit of 68.4%, so N = 13/p can only be an
# integer in [13/0.6845, 13/0.6835] = {19}. One cell with a one-decimal
# percentage is usually conclusive; several cells of the same arm intersect
# to a unique N even at zero decimals. This uses nothing but the printed
# table, so it is the most trustworthy recovery and is tried first.

# Feasible arm sizes for one printed "count (pct%)" cell. `dec` is the
# number of printed decimals of the percentage - it decides the bracket
# width, exactly as ROUND_MEAN does for the Monte Carlo.
.ppNFromCountPct <- function(count, pct, dec) {
  if (is.na(count) || is.na(pct) || count <= 0 || pct <= 0 || pct > 100)
    return(integer(0))
  if (is.na(dec)) dec <- 0L
  half <- 0.5 * 10^(-dec)
  lo <- (pct - half) / 100
  hi <- (pct + half) / 100
  if (lo <= 0) return(integer(0))
  # IN DOUBLES, AND REFUSED BEFORE as.integer() (security screen
  # 2026-09-10-0858, F1). A cell printing "25000000 (0.01%)" implies an arm
  # of about 1.7e11; as.integer() of that is NA with a warning, and the
  # comparison below then raised "missing value where TRUE/FALSE needed".
  # On the JATS route the block parser's tryCatch swallowed the error and
  # the WHOLE document failed to parse with a message naming no cell; on
  # the PDF route the child returned the raw R error. Verified end to end
  # on ae37f0e with "30000 (0.001%)" as well. An implied arm size above
  # .iaMaxArmN can never be analysed - validateData() refuses the trial -
  # so the same rule applies here: the cell yields no arm size, the arm's
  # N stays unknown, and the rest of the table is read as it always was.
  nLoD <- ceiling(count / hi - 1e-9)
  nHiD <- floor(count / lo + 1e-9)
  # THE COUNT ITSELF IS PART OF THE LOWER BOUND (screen 2026-09-10-0923,
  # F2). The ceiling added by screen 0858 capped the upper bound and gated
  # only nLoD, so a count of 5,010 at 100% - lower bound 4,985, under the
  # ceiling - returned the DESCENDING sequence 5,010..5,000, ten of its
  # eleven values above the ceiling the comment said could never be
  # returned, and .ppDeriveArmN() then derived N = 5,000 for an arm whose
  # own printed count is 5,010. A derived arm size is at least the count,
  # so the count is folded into the lower bound before the gate, and an
  # empty range is empty rather than reversed.
  nLoD <- max(nLoD, ceiling(count))
  if (!is.finite(nLoD) || !is.finite(nHiD) || nLoD > .iaMaxArmN)
    return(integer(0))
  nHiD <- min(nHiD, .iaMaxArmN)
  if (nHiD < nLoD) return(integer(0))
  seq.int(as.integer(nLoD), as.integer(nHiD))
}

# Intersect the feasible sets of several cells belonging to one arm.
# Returns the arm size only when exactly ONE integer survives; anything
# looser stays NA rather than guessed - and a CONTRADICTION (a cell with
# valid inputs but no feasible N at all, or two cells with disjoint sets)
# refuses outright, because it means these are not really n (%) cells and
# nothing about this arm should be inferred from them.
.ppDeriveArmN <- function(counts, pcts, decs) {
  feas <- NULL
  for (i in seq_along(counts)) {
    valid <- !is.na(counts[i]) && !is.na(pcts[i]) &&
             counts[i] > 0 && pcts[i] > 0 && pcts[i] <= 100
    if (!valid) next                     # degenerate cell: no evidence
    s <- .ppNFromCountPct(counts[i], pcts[i], decs[i])
    if (length(s) == 0) return(NA_integer_)   # contradiction: refuse
    if (length(s) > 400) next            # too loose to narrow anything
    feas <- if (is.null(feas)) s else intersect(feas, s)
    if (length(feas) == 0) return(NA_integer_)  # disjoint cells: refuse
  }
  if (!is.null(feas) && length(feas) == 1) feas else NA_integer_
}

# The reverse bracket, for percent-block category tables (2026-08-21): given
# the arm size, which count was printed as `pct`%? The printed rounding
# brackets it - count/N must round to pct at `dec` decimals - and the count
# is accepted only when exactly ONE integer lies in the bracket. "47%" of
# n = 40 pins 19; "47%" of n = 702 spans 327..333 and is refused, because a
# fraud screen must not analyze approximated counts as if they were printed.
.ppCountFromPct <- function(pct, dec, N) {
  b <- .ppCountBracket(pct, dec, N)
  if (anyNA(b) || b[1] != b[2]) return(NA_integer_)
  b[1]
}

# The bracket itself: the smallest and largest integer counts whose
# proportion of N rounds to `pct` at `dec` decimals (2026-09-07, for the
# fail-safe fill - see parseBaselineTableHeuristics.R). NA, NA when the
# inputs cannot be bracketed.
.ppCountBracket <- function(pct, dec, N) {
  if (is.na(pct) || is.na(N) || N <= 0 || pct < 0 || pct > 100)
    return(c(NA_integer_, NA_integer_))
  if (is.na(dec)) dec <- 0L
  # IN DOUBLES, AND REFUSED BEFORE as.integer() - the same cure
  # .ppNFromCountPct() received from screen 2026-09-10-0858, which the next
  # screen (0923, F1) found this sibling still needed. A header cell
  # "(n=2147000000)" arrives intact through as.integer(); a "100%" cell
  # then made as.integer(floor(N * 1.005)) NA with a warning, the
  # comparison raised, and on the JATS route the whole document failed
  # with a message naming no cell. An arm above .iaMaxArmN can never be
  # analysed, so it yields no bracket at any percentage, and the row is
  # skipped rather than the document lost.
  if (!is.finite(N) || N > .iaMaxArmN) return(c(NA_integer_, NA_integer_))
  half <- 0.5 * 10^(-dec)
  cLoD <- max(ceiling(N * (pct - half) / 100 - 1e-9), 0)
  cHiD <- min(floor(N * (pct + half) / 100 + 1e-9), N)
  if (!is.finite(cLoD) || !is.finite(cHiD) || cHiD < cLoD)
    return(c(NA_integer_, NA_integer_))
  c(as.integer(cLoD), as.integer(cHiD))
}

# THE PERCENTAGE FILL LIVES IN R/failsafeTable.R.
#
# What stood here until 2026-09-09 was .ppFailsafeCounts(), with
# .ppRowStat(), .ppFailsafeExact and .ppFailsafeSweeps: the rule that
# chose each category LEVEL on its own table line by maximising that
# level's statistic against its own complement. It is deleted rather
# than kept, because while it existed it could still be reached - when
# the whole-table search could not run, the caller silently fell back to
# it, and the independent audit of 2026-09-09 (F1) found a page that
# then read p < 0.0001 where a valid reading of the same percentages
# gives 0.59.
#
# Its three defects are recorded in docs/method-history.md under
# 2026-09-08, and R/failsafeTable.R carries the measurements. The
# bracket itself, .ppCountBracket(), is still here and still used: which
# counts a printed percentage allows is arithmetic, and that part was
# never in doubt.

# --------------------------------------------------------------------------
# Source 2: the document text (CONSORT labels, randomization sentences)
# --------------------------------------------------------------------------
# Candidate (context, n) pairs from every "n = 137" in the document. The
# context decides whether the mention is an allocation ("allocated to the
# ketamine group (n = 24)") or something else entirely - above all a
# sample-size calculation ("n = 25 per group would provide 80% power"),
# which states a HYPOTHETICAL n that must never be taken for a real one.
.ppArmNCandidatesFromText <- function(txt) {
  empty <- data.frame(n = integer(0), context = character(0),
                      near = character(0), pos = integer(0),
                      stringsAsFactors = FALSE)
  if (!length(txt)) return(empty)
  j <- .ppSquish(paste(txt, collapse = " "))
  # "(n:50 each)" - a colon for the equals sign (issue 89; PMIDs 9861126, 9924225)
  m <- gregexpr("(?i)\\bn\\s*[=:]\\s*\\d[\\d,]*", j, perl = TRUE)[[1]]
  noN  <- m[1] == -1L   # no "n = k" at all: the "included N" statements below may still speak (issue 154)
  lens <- attr(m, "match.length")
  out <- lapply(seq_along(m), function(k) {
    hit <- substr(j, m[k], m[k] + lens[k] - 1)
    n   <- suppressWarnings(as.integer(gsub("[^0-9]", "", hit)))
    # The near window must not reach back past the PREVIOUS mention:
    # "...ketamine group (n = 24) or the saline group (n = 26)" packs two
    # mentions into one sentence, and a window that crosses the first one
    # makes the second carry both arm names.
    nearFrom <- max(1, m[k] - 45,
                    if (k > 1) m[k - 1] + lens[k - 1] + 1 else 1)
    data.frame(n = n,
               # wide context: is this an allocation mention at all?
               context = substr(j, max(1, m[k] - 90), m[k] + lens[k] + 12),
               # near context: whose mention is it, and is it a sample-size
               # calculation? The label sits immediately left of "(n = X)".
               near = substr(j, nearFrom, m[k] + lens[k] + 12),
               # the text BEFORE the mention alone: in a packed list
               # "Group Ia (n = 5), Group Ib (n = 7)" the near window's
               # tail reaches the NEXT arm's label, and Ib then matched
               # both mentions (CodeRabbit on PR #343)
               before = substr(j, nearFrom, max(nearFrom, m[k] - 1)),
               pos = m[k], stringsAsFactors = FALSE)
  })
  out <- if (noN) data.frame(n = integer(0), context = character(0), near = character(0),
                             before = character(0), pos = integer(0), stringsAsFactors = FALSE)
         else do.call(rbind, out)
  # A NUMBER THE LAYER HAS BROKEN IS NO SIZE (2026-09-27, ISSUES.md issue
  # 144; Anesth Analg 2005, PMID 15978307): the caption's "(N = 120)" comes
  # through as "(N = 1 20)", "N = 1" matched the arm names, and every arm
  # took an N of 1 - a trial of 120 scored on four patients. A size whose
  # digits are followed by a space and more digits is a broken number: it
  # is dropped, not read as its first part.
  hitLen <- if (nrow(out)) attr(regexpr("(?i)\\bn\\s*[=:]\\s*\\d[\\d,]*", substring(j, out$pos), perl = TRUE), "match.length") else integer(0)
  broken <- if (nrow(out)) grepl("^\\s[0-9]", substring(j, out$pos + hitLen, out$pos + hitLen + 1), perl = TRUE) else logical(0)
  out <- out[!is.na(out$n) & out$n > 0 & !broken, , drop = FALSE]
  # "GROUP 1 (LACTOFERRIN GROUP): INCLUDED 100 PREGNANT WOMEN" (2026-09-26,
  # ISSUES.md issue 154; Rezk 2016, J Matern Fetal Neonatal Med, the
  # Loadsman corpus): a group's size stated as a sentence about the group
  # - "included", "comprised", "consisted of", "contained" and then the
  # count with its noun - carries no "n =" and the ladder never saw it.
  # Each such statement is a candidate with the words before it (the
  # group's name) as its context, matched to the arm names as an "(n =
  # k)" mention is.
  # (the count is followed by its noun, or by an adjective of the people -
  # "included 100 pregnant" - since a two-column page's text may break the
  # sentence after the adjective; "included 100 mL" matches neither)
  mi <- gregexpr(paste0("(?i)\\b(?:included|comprised|comprising|consisted of|consisting of|contained|enrolled)\\s+",
                        "([0-9]{1,4})\\s+(?:(?:pregnant|healthy|adult|consecutive|elderly|female|male)\\b",
                        "|(?:women|men|patients|subjects|participants|children|infants|volunteers|parturients|dogs|rats)\\b)"),
                 j, perl = TRUE)[[1]]
  if (mi[1] != -1) {
    lensI <- attr(mi, "match.length")
    inc <- do.call(rbind, lapply(seq_along(mi), function(k) {
      hit <- substr(j, mi[k], mi[k] + lensI[k] - 1)
      n   <- suppressWarnings(as.integer(regmatches(hit, regexpr("[0-9]{1,4}", hit))))
      nearFrom <- max(1, mi[k] - 60)
      data.frame(n = n, context = substr(j, max(1, mi[k] - 90), mi[k] + lensI[k] + 12),
                 near = substr(j, nearFrom, mi[k] + lensI[k] + 12),
                 before = substr(j, nearFrom, max(nearFrom, mi[k] - 1)),
                 pos = mi[k], stringsAsFactors = FALSE)
    }))
    inc <- inc[!is.na(inc$n) & inc$n > 0, , drop = FALSE]
    out <- rbind(out, inc)
  }

  alloc <- grepl(paste0("(?i)allocat|assign|randomi[sz]|\\bgroup\\b|",
                        "\\barm\\b|receiv|analy[sz]ed|completed|enrol"),
                 out$context, perl = TRUE)
  # A sample-size calculation states a HYPOTHETICAL n ("n = 25 per group
  # would provide 80% power") that must never be taken for a real arm
  # size. Judged on the NEAR window: the calculation vocabulary sits right
  # beside its n, while a power sentence two lines earlier is no reason to
  # discard a genuine allocation mention.
  power <- grepl(paste0("(?i)power|sample\\s+size|per\\s+group|required|",
                        "detect|dropout|attrition|calculat|hypothes"),
                 out$near, perl = TRUE)
  out[alloc & !power, , drop = FALSE]
}

# A stated randomized/enrolled total, used to confirm a positional
# assignment. Returns every such total found (papers restate it).
.ppRandomizedTotals <- function(txt) {
  j <- .ppSquish(paste(txt, collapse = " "))
  pats <- c(paste0("(?i)(\\d[\\d,]*)\\s+(patients|subjects|participants|",
                   "children|women|men|volunteers|adults)?\\s*(were\\s+)?",
                   "(randomi[sz]ed|enrolled|recruited|included)"),
            "(?i)randomi[sz]ed\\s+(\\d[\\d,]*)",
            # the CONSORT flow's own box, "Randomized (n=90)" (issue 50)
            "(?i)randomi[sz]ed\\s*\\(\\s*n\\s*=\\s*(\\d[\\d,]*)\\s*\\)",
            "(?i)total\\s+of\\s+(\\d[\\d,]*)")
  tot <- integer(0)
  for (p in pats) {
    m <- gregexpr(p, j, perl = TRUE)[[1]]
    if (m[1] == -1) next
    lens <- attr(m, "match.length")
    for (k in seq_along(m)) {
      hit    <- substr(j, m[k], m[k] + lens[k] - 1)
      digits <- regmatches(hit, gregexpr("[0-9][0-9,]*", hit))[[1]][1]
      v <- suppressWarnings(as.integer(gsub(",", "", digits)))
      if (!is.na(v)) tot <- c(tot, v)
    }
  }
  unique(tot)
}

# Fill the missing entries of `armN` from the text candidates.
#
# Assignment ladder, strictest first:
#   1. NAME MATCH - a candidate whose context contains a distinctive word
#      of the arm's name. All matching candidates must agree on one n.
#   2. ELIMINATION - every arm but one was name-matched and exactly one
#      distinct candidate value is left over.
#   3. POSITION, CONFIRMED BY THE TOTAL - no names matched at all, but the
#      number of allocation candidates equals the number of arms AND their
#      sum equals a stated randomized total. Document order is taken as
#      column order; that assumption is why the total confirmation is
#      mandatory, why any already-known arm N must agree with its
#      positional candidate, and why reviewFlags() reports the sentence.
#
# Returns list(N = the completed vector, source = per-arm character).
# `namesOnly = TRUE` stops after the arm-name match (issue 87): when some
# arms already print an N, a mention that NAMES a missing arm is safe to
# take, while the positional rules below - which assume every arm is
# unknown - are not.
.ppFillArmNFromText <- function(armN, armName, cand, totals, namesOnly = FALSE) {
  source <- rep(NA_character_, length(armN))
  if (nrow(cand) == 0 || !any(is.na(armN)))
    return(list(N = armN, source = source))
  snip <- function(ctx) paste0("\"...", .ppSquish(substr(ctx, 1, 100)), "...\"")

  stop_words <- c("group", "groups", "arm", "arms", "the", "and", "with",
                  "patients", "study", "control")
  # A distinctive word is three letters or more - or a ROMAN GROUP TAG
  # ("Ia", "IIb", "IV": Fujii's canine papers name their arms "Group Ia
  # (n = 5) ... Group IIb (n = 8)", issue 42), which is short but is the
  # whole of the arm's name once "Group" is set aside. A tag is matched
  # whole (\bia\b), so "Group I" does not claim "Group Ia"'s mention.
  isTag <- function(w) grepl("^[ivx]{1,3}[a-d]?$", w) & nchar(w) >= 2
  armWords <- lapply(armName, function(nm) {
    if (is.na(nm)) return(character(0))
    w <- tolower(unlist(strsplit(gsub("[^A-Za-z ]", " ", nm), "\\s+")))
    setdiff(w[nchar(w) >= 3 | isTag(w)], stop_words)
  })

  used <- rep(FALSE, nrow(cand))
  # 1. name match - against the NEAR window only, because the arm's label
  # sits immediately left of its "(n = X)", while a 90-character context
  # regularly spans the other arm's mention too ("...the ketamine group
  # (n = 24) or the saline group (n = 26)"). And within the near window,
  # the text BEFORE the mention decides when it names any arm at all:
  # the window's short tail exists for "(n = 24) received ketamine", but
  # in a packed list "Group Ia (n = 5), Group Ib (n = 7)" it reaches the
  # next arm's label, and Ib matched both mentions and got nothing
  # (CodeRabbit on PR #343). The tail is consulted only for a mention
  # whose preceding text names no arm.
  if (is.null(cand$before)) cand$before <- cand$near
  namesIn <- function(ctx) {
    lc <- tolower(ctx)
    which(vapply(armWords, function(ws)
      length(ws) > 0 && any(vapply(ws, function(w)
        grepl(paste0("\\b", w, if (isTag(w)) "\\b" else ""), lc, perl = TRUE),
        logical(1))), logical(1)))
  }
  armsOf <- lapply(seq_len(nrow(cand)), function(c) {
    a <- namesIn(cand$before[c])
    if (length(a)) a else namesIn(cand$near[c])
  })
  for (k in which(is.na(armN))) {
    if (length(armWords[[k]]) == 0) next
    hits <- which(vapply(armsOf, function(a) k %in% a, logical(1)))
    if (length(hits) == 0) next
    ns <- unique(cand$n[hits])
    # WHEN THE STATEMENTS ABOUT ONE ARM DISAGREE (2026-09-26, ISSUES.md issue
    # 154; Rezk 2016): the CONSORT diagram allocates "Lactoferrin (n=110)"
    # and the Methods say "Group 1 (Lactoferrin group): included 100
    # pregnant women" - the table's population. A statement of the
    # analysed, included or completed group outranks one of allocation,
    # randomisation or assignment; the arm takes it when it is the one size
    # left (a loss-to-follow-up count nearby does not disqualify it).
    if (length(ns) > 1L) {
      keepC <- grepl("(?i)analy[sz]ed|included|completed|comprised|consisted", cand$near[hits], perl = TRUE) &
        !grepl("(?i)allocat|randomi[sz]ed|assigned", cand$near[hits], perl = TRUE)
      if (any(keepC) && length(unique(cand$n[hits][keepC])) == 1L) {
        hits <- hits[keepC]; ns <- unique(cand$n[hits])
      }
    }
    if (length(ns) == 1) {
      armN[k]  <- ns
      source[k] <- paste0("document text (arm name matched): ",
                          snip(cand$near[hits[1]]))
      used[hits] <- TRUE
    }
  }
  if (namesOnly) return(list(N = armN, source = source))   # issue 87
  # 2. elimination - requires the leftover to actually correspond: exactly
  # one open arm AND exactly one unused mention. Two unused mentions of
  # "n = 20" over one open arm means the mentions belong to the two arms
  # already known, not to the leftover cluster (measured failure mode).
  open <- which(is.na(armN))
  if (length(open) == 1 && sum(!used) == 1) {
    armN[open] <- cand$n[!used]
    source[open] <- paste0("document text (only unassigned mention): ",
                           snip(cand$context[which(!used)[1]]))
  }
  # 3. position, confirmed by the stated total
  open <- which(is.na(armN))
  if (length(open) > 0 && !any(!is.na(source))) {
    firstMention <- cand[!duplicated(cand$pos), , drop = FALSE]
    # A CONSORT flow states more sizes than the arms: "Assessed for
    # eligibility (n=109) ... Excluded (n=19) ... Randomized (n=90) ...
    # Analyzed (n=30) Analyzed (n=30) Analyzed (n=30)" (RezkJMFNM2014,
    # corpus batch 5, K1; arms named "Group 1/2/3", which no name match
    # can place). When the mentions outnumber the arms, those that state
    # a randomized TOTAL, or sit in the flow's screening vocabulary, are
    # not arm sizes; what remains is tried by position as before, still
    # confirmed by the total (issue 50).
    if (nrow(firstMention) > length(armN)) {
      screening <- grepl("(?i)eligib|assessed|screened|excluded|approached|enrol|declined|refused|lost|withdr|discontinu",
                         firstMention$near, perl = TRUE)
      isTotal   <- firstMention$n %in% totals
      keep      <- !screening & !isTotal
      if (sum(keep) == length(armN)) firstMention <- firstMention[keep, , drop = FALSE]
      else if (sum(keep) > length(armN)) {
        # every remaining mention states ONE size, restated table after
        # table ("N = 30" under each arm of Tables 1-4 as well as the
        # flow's "Analyzed (n=30)"), and k of them make the stated total:
        # that size is every arm's
        left <- firstMention[keep, , drop = FALSE]
        n1   <- unique(left$n)
        if (length(n1) == 1L && length(totals) > 0 && (length(armN) * n1) %in% totals) {
          for (k in open) {
            armN[k]   <- n1
            source[k] <- paste0("document text (every per-arm mention states n = ", n1,
                                ", and ", length(armN), " x ", n1, " is the stated total of ",
                                length(armN) * n1, "): ", snip(left$context[1]))
          }
          open <- integer(0)
        }
      }
    }
    if (nrow(firstMention) == length(armN) &&
        length(totals) > 0 && sum(firstMention$n) %in% totals) {
      agree <- TRUE
      for (k in seq_along(armN))
        if (!is.na(armN[k]) && armN[k] != firstMention$n[k]) agree <- FALSE
      if (agree) {
        for (k in open) {
          armN[k]  <- firstMention$n[k]
          source[k] <- paste0("document text (by position; the ",
                              sum(firstMention$n),
                              " total confirms the set, not the order): ",
                              snip(firstMention$context[k]))
        }
      }
    }
  }
  list(N = armN, source = source)
}

# ---------------------------------------------------------------------------
# "divided into three groups of eight each" - the group size as animal
# studies state it (2026-09-24, ISSUES.md issue 34).
# ---------------------------------------------------------------------------
# The two readers above want "n = 8" or "24 dogs were randomized". A
# laboratory paper says neither: PMID 11375852 gives its group size only as
# "Twenty-four mongrel dogs ... were divided into three groups of eight
# each", and with no N in the table the whole trial failed validation.
# This reads that one sentence shape and nothing looser. It returns the
# COUNT of groups as well as the size, so the caller can refuse the value
# when it does not match the number of arms actually read from the table -
# a stated "three groups of eight" is evidence for three arms, not for
# whatever the parser happened to find.
#
# EVERY such statement is returned, not the first (CodeRabbit on PR #330,
# 2026-09-24). A Methods section can state a pilot "divided into three
# groups of eight" and then the analysed animals "divided into three
# groups of ten"; taking the first match would hand the three-arm table
# N = 8 with nothing to catch it, because validation only asks that N be
# present. So the result is one entry per DISTINCT (groups, n) statement,
# and .ppParseRepeatedMeasures() applies a size only when the statements
# for its arm count agree on one - otherwise N stays missing, which the
# review flags say out loud.
.ppNumberWord <- function(w) {
  w <- tolower(w)
  words <- c(one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
             seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11,
             twelve = 12, fifteen = 15, sixteen = 16, twenty = 20,
             thirty = 30, forty = 40, fifty = 50, sixty = 60, eighty = 80,
             hundred = 100)
  if (grepl("^[0-9]+$", w)) return(as.integer(w))
  if (w %in% names(words)) return(as.integer(words[[w]]))
  NA_integer_
}

.ppGroupsOfN <- function(txt) {
  if (!length(txt)) return(NULL)
  j <- .ppSquish(paste(txt, collapse = " "))
  pat <- paste0("(?i)\\b(divided|allocated|assigned|randomi[sz]ed|separated|",
                # "allocated to one of four groups of 15 patients each" (issue
                # 94; PMID 9613269): "to one of" as well as "into"
                "split)\\b[^.;]{0,60}?\\b(?:into|to\\s+one\\s+of)\\s+([a-z0-9-]+)\\s+",
                "(?:equal\\s+)?groups?\\s+of\\s+",
                # A RUNNING HEAD INSIDE THE SENTENCE (2026-09-25, ISSUES.md issue
                # 103; Fujii, PMID 11004073, the corpus session's batch 25 AD8):
                # pdf_text() interleaves a two-column page's running head into
                # the Methods, "divided into three groups of Methods D 10 each",
                # and the size read as "Methods". Up to three stray words may
                # stand between "of" and the size WHEN "each" follows the size -
                # the anchor that makes the number the group size and not a
                # dose or a duration further along the sentence.
                "(?:(?:[A-Za-z]+\\s+){1,3}(?=[0-9]+\\s+each\\b))?([a-z0-9]+)",
                "(?:\\s+(?:each|animals?|dogs?|rats?|pigs?|rabbits?|",
                "patients?|subjects?|participants?))?")
  found <- list(groups = integer(0), n = integer(0), snippet = character(0))
  add <- function(groups, n, snippet) {
    # one entry per distinct statement; a sentence repeated verbatim in the
    # Abstract and the Methods is one statement, not two
    if (paste(groups, n) %in% paste(found$groups, found$n)) return(invisible())   # NA groups too (issue 89)
    found$groups  <<- c(found$groups, groups)
    found$n       <<- c(found$n, n)
    found$snippet <<- c(found$snippet, snippet)
  }
  m <- gregexpr(pat, j, perl = TRUE)[[1]]
  if (m[1] != -1) {
    for (h in seq_along(m)) {
      hit <- substr(j, m[h], m[h] + attr(m, "match.length")[h] - 1L)
      parts <- regmatches(hit, regexec(pat, hit, perl = TRUE))[[1]]
      groups <- .ppNumberWord(parts[3])
      n      <- .ppNumberWord(parts[4])
      if (!is.na(groups) && !is.na(n) && groups >= 2 && n >= 1)
        add(groups, n, .ppSquish(substr(j, max(1, m[h] - 30),
                                        m[h] + attr(m, "match.length")[h] + 10)))
    }
  }
  # THE SENTENCE IS OFTEN CUT AT A LINE BREAK, AND THE OTHER COLUMN FILLS THE
  # GAP. poppler emits each physical line of a two-column page as the left
  # segment followed by the right segment, so PMID 11375852 arrives as
  #     "...divided into three groups of   stimulation did not change."
  #     "eight each: Group 1 received ...  Pdi and Edi for each stimulus"
  # - the size on the NEXT line, with a fragment of the Results between.
  # Joining the page into one string cannot see that. So, per page, the
  # sentence is also accepted when "into <k> groups of" ends one line's left
  # segment and "<n> each" begins the next line: exact at a line boundary
  # and nothing looser, because a window that skipped over text would take
  # numbers from the wrong sentence.
  for (page in txt) {
    ln <- strsplit(page, "\n", fixed = TRUE)[[1]]
    if (length(ln) < 2) next
    for (i in seq_len(length(ln) - 1L)) {
      a <- regmatches(ln[i], regexec("(?i)\\binto\\s+([a-z0-9-]+)\\s+(?:equal\\s+)?groups?\\s+of\\s*(?:\\s{2,}|$)",
                                     ln[i], perl = TRUE))[[1]]
      if (length(a) < 2) next
      b <- regmatches(ln[i + 1], regexec("^\\s*([a-z0-9]+)\\s+each\\b", ln[i + 1], perl = TRUE))[[1]]
      if (length(b) < 2) next
      groups <- .ppNumberWord(a[2]); n <- .ppNumberWord(b[2])
      if (is.na(groups) || is.na(n) || groups < 2 || n < 1) next
      # the snippet is the LEFT segment of each line only - cut at the run of
      # spaces that separates the columns - so the flag the user reads does
      # not quote half a sentence from the other column
      # Cut at the double-space FIRST, then squish: .ppSquish collapses all
      # runs of whitespace to one space, so squishing first would leave
      # nothing to cut at and quote both columns (the first version did).
      left <- function(s) .ppSquish(sub("\\s{2,}.*$", "", sub("^\\s+", "", s)))
      add(groups, n, .ppSquish(paste(left(ln[i]), left(ln[i + 1]))))
    }
  }
  # THREE MORE SHAPES (2026-09-25, ISSUES.md issue 89; the corpus session's
  # batch 22 spec of size-stating sentences from the 48 missing-N Carlisle
  # trials). A window of the sentence that mentions sample size, power or
  # sufficiency is a power statement, not an allocation ("60 patients per
  # group would be sufficient", PMID 10357343), and is refused.
  powerRe <- "(?i)sufficient|power|sample\\s+size|detect|required|calculat"
  window  <- function(a, b) .ppSquish(substr(j, max(1, a - 60), min(nchar(j), b + 60)))
  # (a) "one of three groups (n:50 each)" / "into four groups (n = 25 for each)"
  pa <- paste0("(?i)\\b(?:one\\s+of|into)\\s+([a-z0-9-]+)\\s+(?:equal\\s+)?groups?\\s*",
               "\\(\\s*n\\s*[=:]\\s*(\\d+)\\s*(?:each|per\\s+group|for\\s+each|in\\s+each)?\\s*\\)")
  m <- gregexpr(pa, j, perl = TRUE)[[1]]
  if (m[1] != -1) for (h in seq_along(m)) {
    a <- m[h]; b <- a + attr(m, "match.length")[h] - 1L
    parts <- regmatches(substr(j, a, b), regexec(pa, substr(j, a, b), perl = TRUE))[[1]]
    groups <- .ppNumberWord(parts[2]); n <- as.integer(parts[3])
    if (!is.na(groups) && groups >= 2 && !is.na(n) && n >= 1 && !grepl(powerRe, window(a, b), perl = TRUE))
      add(groups, n, window(a, b))
  }
  # (b) a total divided by the group count: "150 female patients were
  #     allocated randomly to one of three groups" - n = 150 / 3 when whole
  pb <- paste0("(?i)\\b(\\d{2,4}|[a-z]+)\\s+(?:[a-z-]+\\s+){0,2}",
               "(?:patients|subjects|participants|women|men|children|infants|volunteers|adults|dogs|rats|pigs|rabbits)",
               "\\b[^.;]{0,120}?\\b(?:one\\s+of|into|to)\\s+([a-z0-9-]+)\\s+(?:equal\\s+)?(?:treatment\\s+|study\\s+)?groups\\b")
  m <- gregexpr(pb, j, perl = TRUE)[[1]]
  if (m[1] != -1) for (h in seq_along(m)) {
    a <- m[h]; b <- a + attr(m, "match.length")[h] - 1L
    parts <- regmatches(substr(j, a, b), regexec(pb, substr(j, a, b), perl = TRUE))[[1]]
    total <- .ppNumberWord(parts[2]); groups <- .ppNumberWord(parts[3])
    if (is.na(total) || is.na(groups) || groups < 2 || total < 2 * groups) next
    if (total %% groups != 0 || grepl(powerRe, window(a, b), perl = TRUE)) next
    add(groups, total %/% groups, window(a, b))
  }
  # (c) the size on a sentence of its own: "Twenty patients were randomly
  #     assigned to each treatment group" - the group count unstated (NA)
  pc <- paste0("(?i)\\b(\\d{1,4}|[a-z]+)\\s+(?:[a-z-]+\\s+){0,2}",
               "(?:patients|subjects|participants|women|men|children|infants|volunteers|adults|dogs|rats|pigs|rabbits)",
               "\\s+(?:were|was)\\s+(?:randomly\\s+)?(?:assigned|allocated|randomi[sz]ed|enrolled|studied)\\s+",
               "(?:to|in)\\s+each\\s+(?:treatment\\s+|study\\s+)?group\\b")
  m <- gregexpr(pc, j, perl = TRUE)[[1]]
  if (m[1] != -1) for (h in seq_along(m)) {
    a <- m[h]; b <- a + attr(m, "match.length")[h] - 1L
    parts <- regmatches(substr(j, a, b), regexec(pc, substr(j, a, b), perl = TRUE))[[1]]
    n <- .ppNumberWord(parts[2])
    if (!is.na(n) && n >= 1 && !grepl(powerRe, window(a, b), perl = TRUE))
      add(NA_integer_, n, window(a, b))
  }
  # (d) "(n = 20 of each)" / "(n = 20 in each group)" / "(n = 20 per group)"
  #     (2026-09-25, ISSUES.md issue 99; PMIDs 9717598, 9836028, the corpus
  #     session's batch 24, the four partial-arm CJA scans): the size of
  #     every arm in one parenthesis after the arms are named - "diltiazem
  #     or saline (n = 20 of each)" - with the group count unstated, as in
  #     (c). The bare "(n = 20)" beside one arm's name stays with the
  #     arm-name match of .ppFillArmNFromText(); only a parenthesis that
  #     says "each" or "per group" speaks for every arm.
  # ... AND THE CAPTION'S OR FOOTNOTE'S SPELLINGS OF IT (2026-09-26, ISSUES.md
  # issue 150; the corpus session's batch 31: Clin Ther 2014, PMID
  # 24672087, "(n = 20 patients per group)"; Clin Ther 2004, PMID 15336470,
  # "(n = 20 patients per study group)"; Clin Ther 2003, PMID 14749148,
  # "(N = 100; n = 25 in each group)"; A&A 1998, PMID 9768766, the footnote
  # "n = 60 per group."; A&A 1997, PMID 9322479, "n = 45in each group" with
  # the space lost). Four arms' or five arms' every cell read and no arm
  # had an N, because the statement carried a noun ("patients"), a
  # qualifier ("study group", "treatment group"), a semicolon before it in
  # the caption's bracket, or no bracket at all. The bracket is optional
  # on either side now, the noun and the qualifier are allowed, and the
  # space between the number and "in each" may be missing; the power
  # calculation guard applies as before.
  pd <- paste0("(?i)\\(?\\s*n\\s*[=:]\\s*(\\d{1,4})\\s*",
               "(?:(?:patients|subjects|participants|women|men|children|infants|animals|dogs|rats)\\s+)?",
               "(?:(?:of|in|for)\\s+each(?:\\s+(?:study|treatment)?\\s*(?:group|arm))?|",
               "per\\s+(?:(?:study|treatment)\\s+)?(?:group|arm)|each)\\s*\\)?")
  m <- gregexpr(pd, j, perl = TRUE)[[1]]
  if (m[1] != -1) for (h in seq_along(m)) {
    a <- m[h]; b <- a + attr(m, "match.length")[h] - 1L
    parts <- regmatches(substr(j, a, b), regexec(pd, substr(j, a, b), perl = TRUE))[[1]]
    n <- as.integer(parts[2])
    # a parenthesis that follows "one of three groups" belongs to shape (a),
    # which names the group count; it is not also a count-less statement
    owned <- grepl("(?i)\\b(?:one\\s+of|into)\\s+[a-z0-9-]+\\s+(?:equal\\s+)?groups?\\s*$",
                   substr(j, max(1, a - 40), a - 1), perl = TRUE)
    if (!owned && !is.na(n) && n >= 1 && !grepl(powerRe, window(a, b), perl = TRUE))
      add(NA_integer_, n, window(a, b))
  }
  if (!length(found$groups)) return(NULL)
  found
}

# Arm sizes for a table that printed none, from the document text alone
# (issue 42, 2026-09-25). The two sources the block parser and the
# repeated-measures reader already use, in the same order: a "divided
# into k groups of n" statement for exactly this many arms, then the
# "(n = k)" mentions matched to the arm names (.ppFillArmNFromText's
# ladder). Written for the model route: when the deterministic engine
# fails and the model transcribes the table, its arms came back with no
# N on nine of the eleven Carlisle-168 trials that failed validation
# (corpus batch 4b) - Fujii's canine papers, whose sizes are in the
# Methods and nowhere in the table - and nothing ran the ladder over
# them. Every N found carries its sentence, for the CONSORT flag.
.ppArmNFromDocument <- function(armName, txt) {
  k      <- length(armName)
  armN   <- rep(NA_integer_, k)
  source <- rep(NA_character_, k)
  if (k == 0 || !length(txt)) return(list(N = armN, source = source))
  stated <- .ppGroupNFor(.ppGroupsOfN(txt), k)
  if (!is.na(stated$n)) {
    armN[]   <- stated$n
    source[] <- paste0("document text (\"...", stated$snippet, "...\")")
  }
  if (any(is.na(armN))) {
    cand <- .ppArmNCandidatesFromText(txt)
    if (nrow(cand) > 0) {
      fill  <- .ppFillArmNFromText(armN, armName, cand, .ppRandomizedTotals(txt))
      newly <- is.na(armN) & !is.na(fill$N)
      armN[newly]   <- fill$N[newly]
      source[newly] <- fill$source[newly]
    }
  }
  list(N = armN, source = source)
}

# The one group size the document states for a table of k arms, or NA.
# Statements naming a different number of groups are not about this table
# and are ignored; two statements for k arms that disagree on the size make
# the size unknowable from the text, and NA is the honest answer.
.ppGroupNFor <- function(textGroupN, k) {
  if (is.null(textGroupN)) return(list(n = NA_integer_, snippet = NA_character_))
  sel <- which(!is.na(textGroupN$groups) & textGroupN$groups == k & textGroupN$n > 0)
  # "Twenty patients were assigned to each treatment group" names no
  # group count (issue 89): such a statement serves any k, after the
  # statements that name this k
  if (!length(sel)) sel <- which(is.na(textGroupN$groups) & textGroupN$n > 0)
  if (!length(sel) || length(unique(textGroupN$n[sel])) != 1L)
    return(list(n = NA_integer_, snippet = NA_character_))
  list(n = as.integer(textGroupN$n[sel[1]]), snippet = textGroupN$snippet[sel[1]])
}
