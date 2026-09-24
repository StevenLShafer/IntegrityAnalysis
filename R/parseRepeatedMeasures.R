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
.ppLongBaselineWord <- "(?i)^(baseline|pre|pretreatment|before|basal)$"

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

  ## ---- 2. the data lines: a small integer under Group, a value under Baseline
  rowsFound <- list()
  nDataSeen <- 0L
  for (i in seq(hdr + 1L, lastData)) {
    if (kind[i] == "stop") break
    if (kind[i] != "data") next
    nDataSeen <- nDataSeen + 1L
    t <- tokensByLine[[i]]
    if (is.null(t) || nrow(t) == 0) next
    g <- which(t$type == "plain" & !is.na(t$num1) & t$num1 == round(t$num1) &
                 t$num1 >= 1 & t$num1 <= 12 & abs(t$mid - xGroup) <= tol)
    v <- which(t$type %in% c("meanSD", "numParen") & abs(t$mid - xBase) <= tol)
    if (!length(g) || !length(v)) next
    g <- g[which.min(abs(t$mid[g] - xGroup))]
    v <- v[which.min(abs(t$mid[v] - xBase))]
    # the row's label is whatever precedes its first token; blank on the
    # second and later group rows of a variable, which inherit the last one
    lbl <- .ppCleanLabel(.ppSquish(substr(paste(lines[[i]]$text, collapse = " "),
                                         1, min(t$start) - 1)))
    rowsFound[[length(rowsFound) + 1L]] <-
      list(i = i, g = as.integer(t$num1[g]), label = lbl, tok = t[v, , drop = FALSE])
  }
  if (length(rowsFound) < 4L) return(NULL)
  # Most data lines of the block must fit the pattern, or this is a wide
  # table that happens to use the word "Group" - leave it to the wide reader.
  if (length(rowsFound) < 0.6 * nDataSeen) return(NULL)

  ## ---- 3. the group index must run 1..k beneath each variable ------------
  g <- vapply(rowsFound, `[[`, integer(1), "g")
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

  ## ---- 5. arm N: not in the table; from the document text if stated ------
  armN      <- rep(NA_integer_, k)
  armSource <- rep(NA_character_, k)
  if (!is.null(textGroupN) && isTRUE(textGroupN$groups == k) &&
      isTRUE(textGroupN$n > 0)) {
    armN[]      <- as.integer(textGroupN$n)
    armSource[] <- paste0("document text (\"...", textGroupN$snippet, "...\")")
  }
  if (any(is.na(armN)) && !is.null(textCands) && nrow(textCands) > 0) {
    fill  <- .ppFillArmNFromText(armN, armName, textCands,
                                 if (is.null(textTotals)) integer(0) else textTotals)
    newly <- is.na(armN) & !is.na(fill$N)
    armN[newly]      <- fill$N[newly]
    armSource[newly] <- fill$source[newly]
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

  list(data       = DATA,
       arms       = data.frame(arm = armName, N = armN, stringsAsFactors = FALSE),
       armNSource = armSource,
       derivedCounts    = character(0),
       approxCounts     = character(0),
       approxStraddle   = character(0),
       approxUnresolved = character(0),
       derivedCells     = NULL,
       clusters   = k,
       skipped    = data.frame(label = character(0), reason = character(0),
                               text = character(0), stringsAsFactors = FALSE),
       dispersion = dispersionBasis,
       layout     = "repeated-measures")
}
