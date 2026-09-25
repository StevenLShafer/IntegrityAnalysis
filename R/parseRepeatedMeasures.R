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

# THE ROW'S LABEL, AND THE HEADING ABOVE ITS BLOCK (2026-09-25, ISSUES.md
# issue 91; Fujii 2003, PMID 12933396, the corpus session's batch 23).
# Two things went wrong with the names of this layout's rows.
#   - The label used to be the text before the row's FIRST TOKEN. On
#     "20-Hz stimulation I 15.9 +/- 1.5" the tokenizer reads the "20" of
#     "20-Hz" as a plain number, so the label was empty and the row was
#     "Unnamed". The label is now the text before the first token that
#     sits in or beyond the Group column (the group index, or the value):
#     a number inside the label's own words is part of the label.
#   - A variable can be printed as a HEADING on a line of its own above
#     its group rows - "Pdi (cm H2O)" over "20-Hz stimulation" / "100-Hz
#     stimulation", each with its I / II / III rows - and the reader
#     skipped label-only lines altogether. The most recent short heading
#     (five words or fewer) is kept, and it names the rows beneath it:
#     alone when a row has no label of its own ("HR (bpm)" over "I 142
#     +/- 11"), and as a prefix when the row's label starts with a digit
#     and cannot stand alone ("Pdi: 20-Hz stimulation"). A row whose
#     label is a name in itself ("HR (bpm)") keeps it, as the wide reader
#     keeps a continuous row's label under a category heading.
.ppLongRowLabel <- function(d, t, xGroup, tol, gLabel, heading) {
  joined <- paste(d$text, collapse = " ")
  inCol  <- which(t$mid >= xGroup - tol)
  cut    <- if (length(inCol)) min(t$start[inCol]) else min(t$start)
  lbl <- .ppSquish(substr(joined, 1, cut - 1L))
  if (!is.na(gLabel)) lbl <- sub(paste0("\\s*", gLabel, "\\s*$"), "", lbl, perl = TRUE)
  lbl <- .ppCleanLabel(lbl)
  if (!is.na(heading)) {
    h <- .ppCleanLabel(heading)
    if (nzchar(h)) {
      if (!nzchar(lbl)) lbl <- h
      else if (grepl("^[0-9]", lbl)) lbl <- paste0(h, ": ", lbl)
    }
  }
  lbl
}

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
  # THE GROUP COLUMN WITHOUT A HEADER WORD (2026-09-25, ISSUES.md issue 95;
  # Fujii, Anesth Analg 1999;89:1557, PMID 10589648, and 10475325,
  # 11004073, 11573601, 10958102 - the corpus session's batch 24 AC1).
  # These pages print the layout with the group column unheaded: the
  # header line is "Baseline 60 min" or "Variable Baseline Fatigued", and
  # the roman numerals I / II / III stand beneath it in a column of their
  # own with no word above them. The gate above wanted both words, so
  # the reader stood aside and the wide reader took the two timepoints
  # for two arms and each group row for a variable - "I", "II", "III",
  # "I 2" ... thirty-six rows with N nowhere. When a header line names a
  # Baseline column but no Group column, the group column is found from
  # the labels themselves: group words (a roman numeral, a capital letter
  # or two, or a small integer) stacked at one x position on four or
  # more lines beneath the header, left of the Baseline column. The
  # run-of-1..k rule and the "most data lines fit" rule below still
  # decide whether this is the layout; a wide table whose level rows
  # happen to stack "I", "II", "III" once fails them as before.
  if (is.na(hdr)) {
    for (i in span) {
      if (kind[i] == "stop") break
      d <- lines[[i]]
      bi <- which(grepl(.ppLongBaselineWord, d$text, perl = TRUE))
      if (!length(bi)) next
      xb <- d$x[bi[1]] + d$width[bi[1]] / 2
      gx <- numeric(0); gl <- integer(0)
      for (j in seq(i + 1L, lastData)) {
        if (j > length(lines) || kind[j] == "stop") break
        w <- lines[[j]]; wm <- w$x + w$width / 2
        isG <- (grepl(.ppLongGroupLabel, w$text, perl = TRUE) |
                  grepl("^([1-9]|1[0-2])$", w$text, perl = TRUE)) & wm < xb - 15
        if (any(isG)) { gx <- c(gx, wm[isG]); gl <- c(gl, rep(j, sum(isG))) }
      }
      if (length(gx) < 4L) next
      o <- order(gx); cl <- cumsum(c(1L, diff(gx[o]) > 10))
      best <- NULL
      for (k in split(seq_along(o), cl)) {
        nl <- length(unique(gl[o][k]))
        if (nl >= 4L && (is.null(best) || nl > best$nl)) best <- list(nl = nl, x = mean(gx[o][k]))
      }
      if (is.null(best)) next
      hdr <- i; xGroup <- best$x; xBase <- xb
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
  romanMode <- FALSE           # roman numerals are their own index (issue 88)
  prevIdx   <- NA_integer_     # the last group index seen, for a lost label (issue 88)
  # the largest roman numeral under the Group column anywhere in the block
  # bounds a lost label's index: a gap is filled, the run is never extended
  kRoman <- 0L
  for (i in seq(hdr + 1L, lastData)) {
    d  <- lines[[i]]; wm <- d$x + d$width / 2
    rw <- d$text[abs(wm - xGroup) <= tol & grepl("^(I{1,3}|IV|V|VI{1,3})$", d$text, perl = TRUE)]
    if (length(rw)) kRoman <- max(kRoman, as.integer(utils::as.roman(rw)))
  }
  heading <- NA_character_     # the variable printed above its group rows (issue 91)
  for (i in seq(hdr + 1L, lastData)) {
    if (kind[i] == "stop") break
    if (kind[i] != "data") {
      if (kind[i] == "label") {
        ht <- .ppSquish(paste(lines[[i]]$text, collapse = " "))
        if (nzchar(ht) && length(strsplit(ht, " ", fixed = TRUE)[[1]]) <= 5L) heading <- ht
      }
      next
    }
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
        if (grepl("^(I{1,3}|IV|V|VI{1,3})$", gLabel, perl = TRUE)) {
          # A ROMAN NUMERAL IS ITS OWN INDEX (2026-09-25, ISSUES.md issue
          # 88; Fujii's canine tables, PMID 12933396): "I", "II", "III"
          # under Group name groups 1, 2, 3 whatever order they appear
          # in, so a lost "II" leaves a gap the run rule can see and the
          # arms are named Group I..III
          gIdx <- as.integer(utils::as.roman(gLabel)); romanMode <- TRUE
        } else {
          if (!gLabel %in% letterSeen) letterSeen <- c(letterSeen, gLabel)
          gIdx <- match(gLabel, letterSeen)
        }
      } else if (romanMode && kRoman >= 2L &&
                 any(t$type %in% c("meanSD", "numParen") & abs(t$mid - xBase) <= tol) &&
                 sum(wm < xGroup - tol) <= 5L) {
        # THE LABEL THE TEXT LAYER LOST (issue 88): on those pages the
        # middle group's "II" is missing from the text layer, and its
        # row is a value line between the I and III rows. It is the next
        # group.
        # ... AND WHOLE BLOCKS OF THEM (2026-09-25, issue 95; PMIDs
        # 10475325, 11004073, 10958102, the corpus session's batch 24
        # AC1): on these pages only the FIRST variable's rows keep their
        # numerals; every later block - "MAP (mm Hg)" over three or four
        # value rows - lost all of them. A value row with no group word
        # continues the run when the run is open (the next index), and
        # starts a new one at I when the previous run is complete or none
        # has begun. Only a row with a value under the Baseline column is
        # indexed this way - a stray line of digits (a subscript set on a
        # line of its own) is not - and only a row whose label is at most
        # five words: a sentence of the Results with a number in it, in a
        # full-width block that runs past the table, is prose, not a
        # group row. The 1..k run rule and the most-lines-fit rule below
        # still judge the whole.
        nxt <- if (!is.na(prevIdx) && prevIdx + 1L <= kRoman) prevIdx + 1L
               else if (is.na(prevIdx) || prevIdx == kRoman) 1L
               else NA_integer_
        if (!is.na(nxt)) { gIdx <- nxt; gLabel <- as.character(utils::as.roman(gIdx)) }
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
    prevIdx  <- gIdx
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
      rowsFound[[length(rowsFound) + 1L]] <-
        list(i = i, g = gIdx, tok = NULL,
             label = .ppLongRowLabel(lines[[i]], t, xGroup, tol, gLabel, heading))
      next
    }
    v <- v[which.min(abs(t$mid[v] - xBase))]
    # the row's label is whatever precedes its first token; blank on the
    # second and later group rows of a variable, which inherit the last one
    lbl <- .ppLongRowLabel(lines[[i]], t, xGroup, tol, gLabel, heading)
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
  # roman groups are named by their numerals, gaps and all (issue 88)
  if (romanMode) letterSeen <- as.character(utils::as.roman(seq_len(k)))

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
      # "Group I = no study drug" - the "=" is U+2AFD in the font of Fujii's
      # canine tables (issue 88), and "Group" may precede the letter
      m  <- regmatches(legend, regexpr(paste0("(?<![A-Za-z])(?:Group\\s+)?", L, "\\s*[=\u2afd]\\s*([A-Za-z][A-Za-z -]{1,30}?)(?=\\s*(?:[,;.]|$))"),
                                       legend, perl = TRUE))
      nm <- if (length(m) && nzchar(m)) .ppSquish(sub("^(?:Group\\s+)?[A-Za-z]{1,3}\\s*[=\u2afd]\\s*", "", m, perl = TRUE)) else ""
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
