# parseRepeatedMeasures.R - the repeated-measures layout: arms as ROWS under
# a Group column, timepoints as COLUMNS, and only the Baseline column wanted.
#
# NOT the template's "long categorical layout" (LEVEL/CATEGORY columns,
# .iaLongToWide(), tests/testthat/test-long-layout.R). That is an input FORMAT
# for counts; this is a printed TABLE SHAPE the PDF engine has to recognise.
# The two were briefly confused in naming on 2026-09-24; hence the rename.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-24 by Claude Code (model Claude Fable 5.1) at Steve       #
# Shafer's direction, implementing docs/audits/                             #
# 2026-09-24-repeated-measures-parse-finding-cowork.md (ISSUES.md 34).      #
#                                                                          #
# THE TABLE THAT MOTIVATED IT. PMID 11375852 (Fujii et al., Anesth Analg    #
# 2001;92:1590-3, retracted; reference 10 of Carlisle, Dexter, Pandit,      #
# Shafer & Yentis, Anaesthesia 2015;70:848-858), Table 1 "Hemodynamic      #
# Data", as poppler lays it out:                                            #
#                                                                          #
#     Variable    Group   Baseline    [after midazolam]                     #
#     HR (bpm)      1     141 +/- 15   142 +/- 17                           #
#                   2     143 +/- 10   133 +/- 10*+                         #
#                   3     140 +/- 12   123 +/- 10*++                        #
#     MAP (mm Hg)   1     130 +/- 15   131 +/- 17                           #
#     ...                                                                  #
#                                                                          #
# THE ARMS ARE ROWS. The engine's whole model is arms-as-columns: it        #
# clusters value tokens into columns, names each column an arm, and reads  #
# one row per variable. On this layout it found two "arms" (the Baseline   #
# and after-drug COLUMNS), took each variable's three Group rows as three  #
# variables ("HR", "Unnamed", "Unnamed 2"), and so returned 36 rows for a   #
# table holding 18 baseline values - with every after-drug value filed as  #
# baseline data. The finding that named this defect assumed the opposite   #
# geometry (a wide table with follow-up columns appended); the geometry    #
# does not matter to the consequence, which is the same either way:        #
#                                                                          #
#   POST-TREATMENT VALUES ARE NOT RANDOM SAMPLES OF ONE POPULATION. They    #
#   are a drug effect, and a test for unexpected HOMOGENEITY fed those      #
#   rows can return a small p that has nothing to do with data integrity.  #
#   That is the worst failure this program offers: a confident verdict on  #
#   rows that are not baseline characteristics, with nothing flagged.      #
#                                                                          #
# So this reader takes the Baseline column ONLY, one row per (variable,    #
# group), names the arms from the table's own "(Group k)" legend, and       #
# leaves N to be recovered from the document text - which for animal       #
# studies is where it lives ("divided into three groups of eight each").   #
#                                                                          #
# WHERE IT SITS. .ppParseBlock() tries this first, immediately after it     #
# has classified the block's lines and before it clusters columns. It       #
# returns NULL unless the layout is UNAMBIGUOUSLY this one - a header line  #
# naming both a Group column and a Baseline column, and data rows whose    #
# group index runs 1..k beneath each variable - and on NULL the existing    #
# path runs exactly as before. Nothing else in the engine changes shape.   #
#                                                                          #
# Status: verified on the motivating PDF (18 rows, three named arms,       #
# N = 8 from the Methods, no after-drug value) and on the synthetic         #
# regression in tests/testthat/test-repeated-measures-layout.R; the corpus measurements  #
# are recorded in ISSUES.md issue 34.                                       #
############################################################################

# The words that head the two columns this layout is recognised by. Kept
# deliberately narrow: "Group"/"Arm" and "Baseline"/"Pre"/"Before". A
# looser vocabulary would start matching wide tables that merely mention
# the word, and the wide reader is the one that must not move.
.ppLongGroupWord    <- "(?i)^(group|arm)s?$"
# "Pre-fatigue" (Fujii 1994, PMID 8055614, issue 76): the column before the
# intervention may be named for what follows it; a closed list of such
# words, not any "pre-" word, so that "Prednisolone" heads no column
.ppLongBaselineWord <- paste0("(?i)^(baseline|pre|pretreatment|before|basal|",
                              "pre[-\u2013\u2212]?(fatigue|op|operative|treatment|drug|induction|infusion|",
                              "dose|study|intervention|exercise|stimulation))$")
# A group LABEL under the Group column that is not a number: a capital
# letter or two ("C", "N", "A", "B"), or a roman numeral (issue 76). The
# labels are numbered in the order they first appear, and the run rule
# of step 3 applies to the numbers.
.ppLongGroupLabel <- "^([A-Z]{1,2}|I{1,3}|IV|V|VI{1,3})$"

.ppParseRepeatedMeasures <- function(lines, lineTexts, kind, tokensByLine, capIdx,
                              lastData, trial, roundObsDelta,
                              footnoteInfo = character(0),
                              textCands = NULL, textTotals = NULL,
                              textGroupN = NULL) {
  if (capIdx >= lastData) return(NULL)
  span <- seq(capIdx + 1L, lastData)

  ## ---- 1. the sub-column header: one line naming Group AND Baseline ------
  # Searched by TEXT rather than by the block's line classification,
  # because on the motivating page the header line also carries the
  # legend's "(Group 3)" and so tokenises as data.
  hdr <- NA_integer_; xGroup <- NA_real_; xBase <- NA_real_
  for (i in span) {
    if (kind[i] == "stop") break
    d <- lines[[i]]
    w <- d$text
    gi <- which(grepl(.ppLongGroupWord, w, perl = TRUE))
    bi <- which(grepl(.ppLongBaselineWord, w, perl = TRUE))
    if (length(gi) && length(bi)) {
      gi <- gi[1]; bi <- bi[bi > gi][1]
      if (is.na(bi)) next
      hdr    <- i
      xGroup <- d$x[gi] + d$width[gi] / 2
      xBase  <- d$x[bi] + d$width[bi] / 2
      break
    }
  }
  if (is.na(hdr) || !(xBase > xGroup)) return(NULL)
  tol <- max(15, 0.5 * (xBase - xGroup))
  # THE BASELINE COLUMN IS BOUNDED ON THE RIGHT BY THE NEXT HEADER, not only
  # by the tolerance (CodeRabbit on PR #330, 2026-09-24). The tolerance is
  # half the Group-to-Baseline distance, and the after-treatment column can
  # sit closer to Baseline than that: Group at 200, Baseline at 340, an
  # after-drug cell at 390 is within 70 of Baseline. On a row whose Baseline
  # cell is missing that after-drug value would have been read AS baseline -
  # the exact contamination this reader exists to stop. So a value is taken
  # only when Baseline is the NEAREST of the header line's column centres to
  # it: the after column's own header word (or the "(Group k)" legend that
  # stands over it, as on the motivating page) claims its cells.
  hx <- lines[[hdr]]$x + lines[[hdr]]$width / 2

  ## ---- 2. the data lines: a small integer under Group, a value under Baseline
  rowsFound <- list()
  nDataSeen <- 0L
  unmatched <- list()      # data lines this reader could not use (reported)
  groupSeq  <- integer(0)  # every group index seen, value or no value
  letterSeen <- character(0)   # letter labels in order of first appearance (issue 76)
  for (i in seq(hdr + 1L, lastData)) {
    if (kind[i] == "stop") break
    if (kind[i] != "data") next
    nDataSeen <- nDataSeen + 1L
    t <- tokensByLine[[i]]
    if (is.null(t) || nrow(t) == 0) next
    g <- which(t$type == "plain" & !is.na(t$num1) & t$num1 == round(t$num1) &
                 t$num1 >= 1 & t$num1 <= 12 & abs(t$mid - xGroup) <= tol)
    gLabel <- NA_character_
    if (!length(g)) {
      # a LETTER under the Group column ("HR C 146 +/- 9" / "(bpm) N 142
      # +/- 10", PMID 8055614, issue 76): a word, not a token
      d  <- lines[[i]]
      wm <- d$x + d$width / 2
      lw <- which(abs(wm - xGroup) <= tol & grepl(.ppLongGroupLabel, d$text, perl = TRUE))
      if (length(lw)) {
        gLabel <- d$text[lw[which.min(abs(wm[lw] - xGroup))]]
        if (!gLabel %in% letterSeen) letterSeen <- c(letterSeen, gLabel)
        gIdx <- match(gLabel, letterSeen)
      }
    } else {
      g <- g[which.min(abs(t$mid[g] - xGroup))]
      gIdx <- as.integer(t$num1[g])
    }
    if (!length(g) && is.na(gLabel)) {
      unmatched[[length(unmatched) + 1L]] <-
        list(i = i, reason = "no group index under the Group column")
      next
    }
    groupSeq <- c(groupSeq, gIdx)
    nearestIsBase <- vapply(t$mid, function(x) which.min(abs(hx - x)), integer(1)) ==
      which.min(abs(hx - xBase))
    v <- which(t$type %in% c("meanSD", "numParen") & abs(t$mid - xBase) <= tol &
                 nearestIsBase)
    if (!length(v)) {
      # A group row with nothing usable under Baseline. It still counts as
      # that group's row for the 1..k run below - a blank cell is part of the
      # layout, not evidence against it - but nothing is read from it, and it
      # is reported. Before this, one blank cell made the run 1,3 and the
      # whole layout fell to the wide reader, which then filed the row's
      # after-drug value as baseline: the failure the reader exists to stop.
      unmatched[[length(unmatched) + 1L]] <- list(
        i = i, reason = paste0("no mean \u00b1 SD or n (%) value under the ",
                               "Baseline column beside group ", gIdx))
      # the row still names (or continues) its variable for the emit step:
      # without this, RAP's C row lost to a fused "5+2" left RAP's N row to
      # be filed under the variable above it (PMID 8055614, issue 76)
      lblNV <- .ppSquish(substr(paste(lines[[i]]$text, collapse = " "), 1, min(t$start) - 1))
      if (!is.na(gLabel)) lblNV <- sub(paste0("\\s*", gLabel, "\\s*$"), "", lblNV, perl = TRUE)
      rowsFound[[length(rowsFound) + 1L]] <-
        list(i = i, g = gIdx, label = .ppCleanLabel(lblNV), tok = NULL)
      next
    }
    v <- v[which.min(abs(t$mid[v] - xBase))]
    # the row's label is whatever precedes its first token; blank on the
    # second and later group rows of a variable, which inherit the last one
    lbl <- .ppSquish(substr(paste(lines[[i]]$text, collapse = " "), 1, min(t$start) - 1))
    if (!is.na(gLabel)) lbl <- sub(paste0("\\s*", gLabel, "\\s*$"), "", lbl, perl = TRUE)
    lbl <- .ppCleanLabel(lbl)
    rowsFound[[length(rowsFound) + 1L]] <-
      list(i = i, g = gIdx, label = lbl, tok = t[v, , drop = FALSE])
  }
  nWithValue <- sum(vapply(rowsFound, function(r) !is.null(r$tok), logical(1)))
  if (nWithValue < 4L) return(NULL)
  # Most data lines of the block must fit the pattern, or this is a wide
  # table that happens to use the word "Group" - leave it to the wide reader.
  if (nWithValue < 0.6 * nDataSeen) return(NULL)

  ## ---- 3. the group index must run 1..k beneath each variable ------------
  # Checked over EVERY group row, including those with no usable value, so
  # that a blank cell does not break the run.
  g <- groupSeq
  if (min(g) != 1L || max(g) < 2L) return(NULL)
  runStart <- which(g == 1L)
  runEnd   <- c(runStart[-1] - 1L, length(g))
  for (r in seq_along(runStart)) {
    seg <- g[runStart[r]:runEnd[r]]
    if (!identical(seg, seq_len(length(seg)))) return(NULL)
  }
  k <- max(g)

  ## ---- 4. arm names, from the stacked "(Group k)" legend above the header
  # Manuscripts print the legend as a stack - "No study drug" / "(Group 1)" /
  # "Sedative dose" / "of midazolam" / "(Group 2)" - so the words BEFORE each
  # "(Group k)" line, since the previous one, are that arm's name. The line
  # carrying "(Group k)" is not itself read for name words: on the
  # motivating page it is the column header ("Variable Group Baseline").
  armName <- paste("Group", seq_len(k))
  buf <- character(0)
  for (i in seq(capIdx + 1L, hdr)) {
    txt <- lineTexts[i]
    m <- regmatches(txt, regexpr("(?i)\\(\\s*group\\s*(\\d{1,2})\\s*\\)", txt, perl = TRUE))
    if (length(m) && nzchar(m)) {
      kk <- as.integer(gsub("\\D", "", m))
      nm <- .ppSquish(paste(buf, collapse = " "))
      if (kk >= 1 && kk <= k && nzchar(nm))
        armName[kk] <- paste0(nm, " (Group ", kk, ")")
      buf <- character(0)
      next
    }
    if (grepl("(?i)^(table|tab\\.?)\\s", txt, perl = TRUE)) next
    w <- lines[[i]]$text
    w <- w[!grepl("(?i)^(variable|characteristic|parameter|group|arm|baseline)s?$", w, perl = TRUE)]
    buf <- c(buf, w)
  }

  # LETTER GROUPS ARE NAMED BY THE LEGEND (issue 76): "C = control, N =
  # nicardipine" in the table's footnote, or in the lines beneath the
  # block; without a legend the arm is "Group C".
  if (length(letterSeen)) {
    below  <- if (lastData < length(lineTexts))
      lineTexts[seq(lastData + 1L, min(lastData + 10L, length(lineTexts)))] else character(0)
    legend <- paste(c(footnoteInfo, below), collapse = " ")
    for (kk in seq_len(k)) {
      L  <- letterSeen[kk]
      if (is.na(L)) next
      m  <- regmatches(legend, regexpr(paste0("(?<![A-Za-z])", L, "\\s*=\\s*([A-Za-z][A-Za-z -]{1,30}?)(?=\\s*(?:[,;.]|$))"),
                                       legend, perl = TRUE))
      nm <- if (length(m) && nzchar(m)) .ppSquish(sub("^[A-Za-z]{1,2}\\s*=\\s*", "", m)) else ""
      armName[kk] <- if (nzchar(nm)) paste0(nm, " (Group ", L, ")") else paste("Group", L)
    }
  }

  ## ---- 5. arm N: not in the table; from the document text if stated ------
  armN      <- rep(NA_integer_, k)
  armSource <- rep(NA_character_, k)
  # .ppGroupNFor() gives the size only when every "into k groups of n"
  # statement for THIS arm count agrees; a pilot of eight and a study of
  # ten leave N missing rather than guessed.
  stated <- .ppGroupNFor(textGroupN, k)
  if (!is.na(stated$n)) {
    armN[]      <- stated$n
    armSource[] <- paste0("document text (\"...", stated$snippet, "...\")")
  }
  if (any(is.na(armN)) && !is.null(textCands) && nrow(textCands) > 0) {
    fill  <- .ppFillArmNFromText(armN, armName, textCands,
                                 if (is.null(textTotals)) integer(0) else textTotals)
    newly <- is.na(armN) & !is.na(fill$N)
    armN[newly]      <- fill$N[newly]
    armSource[newly] <- fill$source[newly]
  }
  # a letter group's size is often stated as "(Group C, n = 10)" in the
  # text (issue 76): a size mention whose preceding words END with "Group
  # C" is that arm's, when every such mention agrees
  if (length(letterSeen) && any(is.na(armN)) && !is.null(textCands) && nrow(textCands) > 0 &&
      !is.null(textCands$before)) {
    for (kk in which(is.na(armN))) {
      L <- letterSeen[kk]
      if (is.na(L)) next
      hit <- grepl(paste0("(?i)\\bgroup\\s+", L, "\\s*[,;:]?\\s*\\(?\\s*$"), textCands$before, perl = TRUE)
      ns  <- unique(textCands$n[hit])
      if (length(ns) == 1L) {
        armN[kk]      <- as.integer(ns)
        armSource[kk] <- paste0("document text (\"Group ", L, ", n = ", ns, "\")")
      }
    }
  }

  ## ---- 6. SD or SE: the same footnote rule the wide path uses -------------
  footTxt <- paste(footnoteInfo, collapse = " ")
  footSaysSE <- grepl("(?i)\\bs\\.?e\\.?m\\.?\\b|\\bs\\.?e\\.?\\b|standard\\s+error",
                      footTxt, perl = TRUE)
  footSaysSD <- grepl("(?i)\\bs\\.?d\\.?\\b|standard\\s+deviation", footTxt, perl = TRUE)
  isSE <- footSaysSE && !footSaysSD
  dispersionBasis <- if (footSaysSE && !footSaysSD) "se (stated)"
                     else if (footSaysSD && !footSaysSE) "sd (stated)"
                     else if (footSaysSE && footSaysSD) "mixed (per row)"
                     else "sd (assumed - table does not say)"

  ## ---- 7. emit one template line per (variable, group) -------------------
  cols <- .ppBaseColumns()
  out  <- list()
  usedRowNames <- character(0)
  current <- NA_character_
  for (r in rowsFound) {
    if (r$g == 1L) {
      nm <- if (nzchar(r$label)) r$label else "Unnamed"
      current <- .ppUniqueName(nm, usedRowNames)
      usedRowNames <- c(usedRowNames, current)
    } else if (is.na(current)) {
      next
    }
    t <- r$tok
    if (is.null(t)) next          # a group row with no usable value (reported in skipped)
    line <- stats::setNames(as.list(rep(NA, length(cols))), cols)
    line$TRIAL <- trial
    line$ROW   <- current
    line$N     <- armN[r$g]
    line$MEAN  <- t$num1
    line$SD    <- if (isSE) NA_real_ else t$num2
    line$SE    <- if (isSE) t$num2 else NA_real_
    line$ROUND_MEAN        <- t$dec1
    line$ROUND_DISPERSION  <- t$dec2
    line$ROUND_OBSERVATION <- t$dec1 + roundObsDelta
    out[[length(out) + 1L]] <- line
  }
  if (!length(out)) return(NULL)
  DATA <- do.call(rbind, lapply(out, function(l)
    as.data.frame(l, check.names = FALSE, stringsAsFactors = FALSE)))

  # A DATA LINE THIS READER DID NOT USE IS REPORTED, NOT DROPPED (CodeRabbit
  # on PR #330, 2026-09-24). The 60% rule above accepts the layout when most
  # lines fit; the rest - a median [IQR] row, a row whose Baseline cell is
  # blank - would otherwise vanish with nothing in `skipped` to say so, and
  # the review flags would tell the user every line was read. Each is listed
  # with the line's text, the way the wide reader lists its refusals; the
  # score's hard-skip penalty then applies to this reading as to any other.
  skipped <- data.frame(label = character(0), reason = character(0),
                        text = character(0), stringsAsFactors = FALSE)
  if (length(unmatched)) {
    skipped <- data.frame(
      label  = vapply(unmatched, function(u) {
        t <- tokensByLine[[u$i]]
        .ppCleanLabel(.ppSquish(substr(paste(lines[[u$i]]$text, collapse = " "),
                                       1, min(t$start) - 1)))
      }, character(1)),
      reason = paste0("repeated-measures layout: ",
                      vapply(unmatched, `[[`, character(1), "reason")),
      text   = vapply(unmatched, function(u) .ppSquish(lineTexts[u$i]), character(1)),
      stringsAsFactors = FALSE)
  }

  list(data       = DATA,
       arms       = data.frame(arm = armName, N = armN, stringsAsFactors = FALSE),
       armNSource = armSource,
       derivedCounts    = character(0),
       approxCounts     = character(0),
       approxStraddle   = character(0),
       approxUnresolved = character(0),
       derivedCells     = NULL,
       clusters   = k,
       skipped    = skipped,
       dispersion = dispersionBasis,
       layout     = "repeated-measures")
}
