# parseBaselineTableHeuristics.R - the deterministic extraction engine.
#
############################################################################
# Provenance                                                               #
# Ported 2026-08-15 by Claude Code (model: Claude Opus 5, Anthropic) from  #
# parseCovariateTable() in the Integrity-Analysis repository, drafted      #
# 2026-08-14 by Claude Code (model: Claude Fable 5) at Steve Shafer's      #
# request. The cell-level parsing logic is unchanged from that draft.      #
#                                                                          #
# Revised the same day, after runs against samples drawn from the corpus   #
# of 1,865 real journal PDFs in C:/temp/journals (5 articles, then 60,     #
# then a 250-article random sample - NOT the whole corpus) showed that the #
# original table-finding stage failed on most of them. Two defects, both   #
# fatal on real articles and both invisible against the synthetic          #
# fixtures:                                                                #
#                                                                          #
#   1. Journals are typeset in two columns, and a table usually sits in    #
#      one of them with body prose beside it. Clustering words into lines  #
#      by y across the whole page glued each table row onto a sentence of  #
#      prose, so the parser saw neither a caption nor a table. Lines are   #
#      now built inside one typographic column at a time                   #
#      (.ppPageBands() in pageLayout.R).                                   #
#   2. The caption was located with a regex over the joined line text and  #
#      only matched Arabic numerals, so "TABLE I Demographic data" - the   #
#      house style of Anaesthesia and CJA - never matched. Captions are    #
#      now found as adjacent words, Roman or Arabic                        #
#      (.ppCaptionAnchors()).                                              #
#                                                                          #
# Consequently the engine no longer picks one page by vocabulary and hopes #
# the table is on it. It enumerates every captioned table in the document, #
# scores each caption for baseline-ness, parses the most promising ones,   #
# and keeps whichever parse comes out best (.ppParseScore()).              #
#                                                                          #
# This file makes NO calls to any AI service. All table recognition is     #
# word-coordinate heuristics and regular expressions over the text layer   #
# extracted by pdftools (poppler), so the same PDF always gives the same   #
# answer and every number can be traced back to a printed cell.           #
#                                                                          #
# A third defect was found the same way and fixed here: a placebo arm       #
# headed "P" was being discarded as a p-value column, which also corrupted  #
# every row label in that table, since the label is everything left of the  #
# first surviving cell.                                                     #
#                                                                          #
# Status: run and verified against the synthetic PDFs in                   #
# tests/testthat/helper-syntheticPdf.R, the regression fixtures in         #
# tests/testthat/test-real-layouts.R, and a 250-article random sample of   #
# the corpus in C:/temp/journals, scored against Carlisle's hand-extracted #
# values. On that sample 70% of articles yield a table and 45% of the      #
# known mean/SD pairs are recovered exactly (see README "Validation").     #
# That is a drafting aid, not a substitute for reading the table: review   #
# every parsed value against the printed table before analyzing a          #
# submission.                                                              #
#                                                                          #
# Revised 2026-08-20 by Claude Code (model: Claude Fable 5) at Steve       #
# Shafer's request, after screening 654 RCT submissions from the A&A       #
# manuscript corpus (C:/Temp/AA) showed that SUBMITTED MANUSCRIPTS -       #
# the input the deployed app actually receives - defeated the engine in    #
# ways journal typography never does: margin line-number rails, legend     #
# sentences between the caption and the table, captions on a different     #
# page than their table, tables running over page breaks, and the gutter   #
# detector splitting a wide Word table into a labels band and a values     #
# band. Each repair is marked "2026-08-20" in place, and every layout is   #
# pinned as a synthetic fixture in test-manuscript-layouts.R. Run and      #
# verified against the 60-submission random sample and a 150-article      #
# corpus regression sample (see the PR for the measured numbers).          #
############################################################################

# How good is a candidate parse? Used to choose between the tables in a
# document, and between a column-segmented and a full-width reading of the
# same page. Rewards arms with a known N and variables actually extracted;
# penalises lines the parser had to skip.
#
# The three terms added 2026-08-20 (measured on the A&A submitted-manuscript
# corpus) steer the choice toward the reading that kept labels and values
# together. On a manuscript table the gutter detector can split the TABLE
# itself - labels in one band, values in the other - and the values-only
# band parses into nameless rows that used to outscore the full-width
# reading. Demographic vocabulary in the row labels is direct evidence of a
# baseline table; "Unnamed" rows and implausibly many arms are evidence of a
# mangled one.
# The caption score of a parse result, 0 when it has no caption - the
# comparison tatr = "always" makes between two engines' winners.
.ppCaptionScoreOf <- function(caption) {
  if (is.null(caption) || length(caption) != 1L || is.na(caption) || !nzchar(caption))
    return(0)
  s <- .ppCaptionScore(caption)
  if (is.finite(s)) s else 0
}

.ppParseScore <- function(res) {
  if (is.null(res) || inherits(res, "error") || nrow(res$data) == 0) return(-Inf)
  # AN UNNAMED ROW IS NOT A VARIABLE (2026-09-24, issue 34). "Unnamed k" is
  # what the block parser calls a value it found with no label. Counting
  # such rows as continuous variables, at +2 each against a -1 penalty
  # below, let a misread of PMID 11375852 - two arms, twelve Unnamed rows -
  # score 24 and beat every honest reading of the same page (a correct
  # 6-variable parse scores 14). The penalty stays; the credit goes.
  # The penalty is counted over ALL row names, not the named ones -
  # `allRows` below has the Unnamed rows filtered out, so counting them
  # there is always zero (CodeRabbit on PR #330, 2026-09-24: the first
  # version did exactly that, and lost the penalty while removing the credit).
  named    <- !grepl("^Unnamed", res$data$ROW)
  nUnnamed <- sum(grepl("^Unnamed", unique(res$data$ROW)))
  contRows <- unique(res$data$ROW[!is.na(res$data$MEAN) & named])
  nCont    <- length(contRows)
  allRows  <- unique(res$data$ROW[named])
  nCat     <- length(setdiff(allRows, contRows))
  demo <- sum(grepl(paste0("(?i)\\bage\\b|\\bsex\\b|gender|\\bmale\\b|female|",
                           "weight|height|\\bbmi\\b|body\\s+mass|\\basa\\b"),
                    allRows, perl = TRUE))
  clusters <- if (is.null(res$clusters)) nrow(res$arms) else res$clusters
  # An arm N printed in the table is strong evidence this really is the
  # table; a RECOVERED N (n (%) derivation or document text) is worth
  # NOTHING here, deliberately: recovery text applies to every candidate
  # of the document, and any score credit for it lets recovery decide
  # WHICH table wins - it flipped one corpus file from Table 1 to a
  # results table whose clusters happened to match the document's numbers
  # (2026-08-21). Recovered Ns still reach the output; they just carry no
  # weight in choosing between candidate tables.
  headerN <- if (is.null(res$armNSource)) !is.na(res$arms$N) else
    !is.na(res$arms$N) & is.na(res$armNSource)
  # A row refused by the unique-count bracket ("47%" of n = 702) is a
  # CORRECT reading of a percent table, not evidence of a mangled parse -
  # penalising it like a parse error flipped candidate selection on two
  # corpus files (2026-08-21). Only the other skips count against a parse.
  hardSkips <- sum(!grepl("unique count", res$skipped$reason, fixed = TRUE))
  3 * sum(headerN) +
    2 * nCont + nCat +
    2 * (nrow(res$arms) >= 2) +
    2 * min(demo, 3) -
    2 * hardSkips -
    nUnnamed -
    max(0, clusters - 6)
}

# Parse one prepared block of lines, starting at the caption line `capIdx`.
# This is the original engine, steps 3-10, with page selection and the
# two-column hack lifted out: by the time it is called, `lines` already
# contains only the lines of one typographic column.
.ppParseBlock <- function(lines, lineTexts, capIdx, trial, parenIsSD,
                          roundObsDelta, say,
                          textCands = NULL, textTotals = NULL,
                          pctApprox = FALSE, textGroupN = NULL) {

  # Footnote / end-of-table patterns. Checked BEFORE tokenizing, because a
  # footnote like "Values are mean +/- SD" itself contains a mean+/-SD-shaped
  # token.
  stopPattern <- paste0(
    "(?i)^(values|data|results|numbers|figures)\\s+(are|were)",
    "|presented\\s+as|expressed\\s+as|given\\s+as|shown\\s+as",
    "|^abbreviations?|^definition\\s+of",
    "|^(figure|fig\\.)\\s*\\d",
    # a footnote marker followed by its text, with or without a space:
    # "*No significant between-group differences were found." (Fujii
    # 2006, PMID 16982288, issue 55) ran on into the block and the prose
    # beneath it seeded a phantom column
    "|^(\\*|\u2020|\u2021|\u00a7)\\s*[A-Za-z]")
  footnoteInfo <- character(0)   # kept to help disambiguate "a (b)" cells

  # A SCANNED PAGE'S PLUS-MINUS SOUP IS REPAIRED FIRST (2026-09-25,
  # ISSUES.md issue 65; PMID 7954995): ":i:", "-t-", "-I-", "4-" between
  # two numbers, at an x where other lines set a genuine plus-minus, are
  # the sign - see .ppRepairPlusMinusGlyphs() in utils.R. The lines and
  # their texts are replaced so that every rule below sees the sign.
  rep <- .ppRepairPlusMinusGlyphs(lines, capIdx)
  if (rep$repaired > 0L) {
    lines <- rep$lines
    lineTexts <- vapply(lines, .ppLineText, character(1))
    say("Read ", rep$repaired, " OCR glyph(s) between two numbers as the plus-minus ",
        "sign, by the column where the block's other rows set it.")
  }

  # Walk the lines after the caption; classify each one.
  #   header - contains "n = 25"-style arm sizes
  #   data   - has at least one numeric token
  #   label  - no numbers: a category header, an arm name, or prose
  # The block ends at a footnote, another table caption, or sustained prose.
  tokensByLine <- vector("list", length(lines))
  kind         <- rep("pre", length(lines))
  blankRun     <- 0
  seenData     <- FALSE
  if (capIdx >= length(lines)) return(NULL)
  for (i in seq(capIdx + 1, length(lines))) {
    txt <- lineTexts[i]
    newCaption <- .ppCaptionStart(txt)
    if (grepl(stopPattern, txt, perl = TRUE) || newCaption) {
      # FIX (2026-08-25): BEFORE the first data line, a footnote-shaped
      # line is the caption's own continuation, not the table's end. Long
      # captions wrap, and the wrapped text is exactly what the stop
      # pattern hunts - "Table 1 Patient characteristics ..., / presented
      # as mean ( SD ) or number." (PMID_20581215). Stopping there killed
      # the block at its first line, the genuine Table 1 scored -Inf, and
      # a results table won the document instead. Treated as a label the
      # line still feeds footnoteInfo, so its "mean ( SD )" notation
      # keeps informing the "a (b)" disambiguation below. A NEW caption
      # still ends the block even before data: the table under THIS
      # caption evidently has no body at all.
      if (!seenData && !newCaption) {
        kind[i] <- "label"
        footnoteInfo <- c(footnoteInfo, txt)
        next
      }
      kind[i] <- "stop"
      # FIX (2026-08-25): a new caption's text belongs to the NEXT table,
      # not this one. Captured as footnote evidence, "Table 2 Pain scores
      # ..., presented as median (inter-quartile range)" on the same page
      # licensed the IQR reading of THIS table's "47 (21-65)" mean
      # (range) cells, filing range bounds as quartiles (PMID_20581215).
      # Only a genuine footnote feeds the notation evidence.
      if (!newCaption) {
        footnoteInfo <- c(footnoteInfo, txt)
        extra <- seq(i + 1, min(i + 4, length(lines)))
        footnoteInfo <- c(footnoteInfo, lineTexts[extra])
      }
      break
    }
    if (grepl("(?i)\\(?\\s*n\\s*=\\s*\\d+", txt, perl = TRUE)) {
      kind[i] <- "header"
      next
    }
    toks <- .ppTokenizeLine(lines[[i]])
    tokensByLine[[i]] <- toks
    if (nrow(toks) > 0) {
      kind[i] <- "data"
      blankRun <- 0
      seenData <- TRUE
    } else {
      kind[i] <- "label"
      blankRun <- blankRun + 1
      # A long numberless line inside a column is prose, not a row label -
      # but only once data has begun. Before the first data line, the
      # numberless lines are the caption's own legend sentences ("Values
      # are represented as mean - SD or numbers (percentages)."), which
      # manuscripts print between the caption and the table body; stopping
      # on them cost whole tables (2026-08-20, A&A submission corpus).
      if (seenData) {
        if (nrow(lines[[i]]) > 8 || blankRun >= 3) {
          kind[i] <- "stop"
          break
        }
      } else if (blankRun >= 6) {
        kind[i] <- "stop"
        break
      }
    }
  }

  # Some Word-converted manuscripts print the plus-minus sign as a plain
  # hyphen: the caption says "mean - SD" and the cells read "40.79-11.97",
  # which the tokenizer sees as a number followed by a negative number
  # inside one word. When the block itself announces that notation, such
  # contiguous pairs are re-read as mean +/- SD - but only on lines with at
  # least TWO pairs, so a lone "(0-100 scale)" annotation cannot fabricate
  # a baseline value (2026-08-20; compare the BJA plus-minus-as-dash repair
  # in utils.R, which is this defect in the opposite direction).
  dashSD <- any(grepl("(?i)mean\\s*[-\u2013\u2212]+\\s*s\\.?d\\b",
                      lineTexts, perl = TRUE))
  if (dashSD) for (i in which(kind == "data")) {
    t <- tokensByLine[[i]]
    if (is.null(t) || nrow(t) < 2) next
    j <- seq_len(nrow(t) - 1)
    pair <- j[t$type[j] == "plain" & t$type[j + 1] == "plain" &
              t$start[j + 1] == t$start[j] + nchar(t$text[j]) &
              !is.na(t$num1[j]) & t$num1[j] >= 0 &
              !is.na(t$num1[j + 1]) & t$num1[j + 1] < 0]
    if (length(pair) < 2) next
    t$type[pair] <- "meanSD"
    t$text[pair] <- paste0(t$text[pair], t$text[pair + 1])
    t$num2[pair] <- -t$num1[pair + 1]
    t$dec2[pair] <- t$dec1[pair + 1]
    t$x1[pair]   <- t$x1[pair + 1]
    t$mid[pair]  <- (t$x0[pair] + t$x1[pair]) / 2
    tokensByLine[[i]] <- t[-(pair + 1), , drop = FALSE]
  }
  # TWO MORE ANNOUNCED NOTATIONS (2026-09-25, ISSUES.md issue 45, both from
  # the Loadsman corpus's Saitoh papers):
  #
  # (a) "mean + SD": a scanned page's OCR text layer sets the plus-minus
  #     as a plain plus - the caption reads "(Number or mean + SD)" and the
  #     cells "45.5 + 11.4" (CJA 1995;42:1096). The tokenizer reads two
  #     plain numbers with nothing between them; when the block announces
  #     the notation, a pair of non-negative plain tokens whose only
  #     separator in the printed line is a "+" is one mean +/- SD cell.
  # (b) "mean2SD": Acta 1997's font maps the plus-minus glyph to the digit
  #     2, so the legend says "Values are number or mean2SD." and a cell
  #     reads "49.527.9" - ONE token to the tokenizer, 49.5 fused to 7.9
  #     across the glyph. Announced by a legend with a digit between "mean"
  #     and "SD", a token holding two decimal points is split at an
  #     occurrence of that digit where both halves are decimal numbers
  #     with the same number of decimals ("49.5|27.9" and "49.52|7.9" are
  #     both readable; only the first has equal decimals). A token that
  #     allows exactly one such split is read as mean +/- SD; anything
  #     ambiguous, or an integer cell ("5729"), is left as it was.
  # Both need at least two repaired cells on the line, as the dash rule
  # does, so that a lone annotation cannot fabricate a baseline value.
  # The "+" pair is also read on a line that ALREADY holds two mean +/- SD
  # cells, announced or not: "45.6 • 8.2  47.7 + 7.7  48.0 • 7.1" (CJA
  # 1997;44:390, the OCR of one cell's glyph differing from its neighbours')
  # cannot be anything but a fourth such cell, and left as two plain
  # numbers it seeded a phantom column and cost the table an arm.
  plusSD <- any(grepl("(?i)mean\\s*\\+\\s*s\\.?d\\b", lineTexts, perl = TRUE))
  for (i in which(kind == "data")) {
    t <- tokensByLine[[i]]
    if (is.null(t) || nrow(t) < 2) next
    if (!plusSD && sum(t$type == "meanSD") < 2) next
    joined <- paste(lines[[i]]$text, collapse = " ")
    j <- seq_len(nrow(t) - 1)
    between <- vapply(j, function(k)
      .ppSquish(substr(joined, t$start[k] + nchar(t$text[k]), t$start[k + 1] - 1)),
      character(1))
    pair <- j[t$type[j] == "plain" & t$type[j + 1] == "plain" & between == "+" &
              !is.na(t$num1[j]) & t$num1[j] >= 0 &
              !is.na(t$num1[j + 1]) & t$num1[j + 1] >= 0]
    pair <- pair[!(pair - 1) %in% pair]          # a token joins one pair only
    if (length(pair) < (if (plusSD) 2 else 1)) next
    t$type[pair] <- "meanSD"
    t$text[pair] <- paste(t$text[pair], "+", t$text[pair + 1])
    t$num2[pair] <- t$num1[pair + 1]
    t$dec2[pair] <- t$dec1[pair + 1]
    t$x1[pair]   <- t$x1[pair + 1]
    t$mid[pair]  <- (t$x0[pair] + t$x1[pair]) / 2
    tokensByLine[[i]] <- t[-(pair + 1), , drop = FALSE]
  }
  digitSD <- regmatches(lineTexts, regexpr("(?i)mean\\s*([0-9])\\s*s\\.?d\\b", lineTexts, perl = TRUE))
  digitSD <- unique(gsub("[^0-9]", "", digitSD))
  # (c) The digit as a token of its own: "Values are mean 6 sd." and the
  #     cells "141 6 9  139 6 10  141 6 7" (Fujii 1999, PMID 10475325, the
  #     Symbol-font plus-minus set as the digit 6; the corpus session's N1,
  #     issue 59). Three plain tokens in a row whose middle one is the
  #     announced digit are one mean +/- SD cell - at least two such
  #     triples on the line, as the other announced notations require.
  if (length(digitSD) == 1L) for (i in which(kind == "data")) {
    t <- tokensByLine[[i]]
    if (is.null(t) || nrow(t) < 3L) next
    j <- seq_len(nrow(t) - 2L)
    triple <- j[t$type[j] == "plain" & t$type[j + 1L] == "plain" & t$type[j + 2L] == "plain" &
                t$text[j + 1L] == digitSD & !is.na(t$num1[j]) & !is.na(t$num1[j + 2L]) &
                t$num1[j] >= 0 & t$num1[j + 2L] >= 0]
    # a token joins one triple only, left to right
    keepT <- logical(0); last <- -Inf
    for (q in triple) { if (q > last + 2L) { keepT <- c(keepT, TRUE); last <- q } else keepT <- c(keepT, FALSE) }
    triple <- triple[keepT]
    if (length(triple) < 2L) next
    t$type[triple] <- "meanSD"
    t$text[triple] <- paste(t$text[triple], .ppPLUSMINUS, t$text[triple + 2L])
    t$num2[triple] <- t$num1[triple + 2L]
    t$dec2[triple] <- t$dec1[triple + 2L]
    t$x1[triple]   <- t$x1[triple + 2L]
    t$mid[triple]  <- (t$x0[triple] + t$x1[triple]) / 2
    tokensByLine[[i]] <- t[-c(triple + 1L, triple + 2L), , drop = FALSE]
  }
  if (length(digitSD) == 1L) for (i in which(kind == "data")) {
    t <- tokensByLine[[i]]
    if (is.null(t) || nrow(t) == 0) next
    fused <- which(t$type == "plain" & grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", t$text))
    if (length(fused) < 2) next
    split <- lapply(t$text[fused], function(txt) {
      at <- gregexpr(digitSD, txt, fixed = TRUE)[[1]]
      ok <- list()
      for (p in at) {
        a <- substr(txt, 1, p - 1); b <- substr(txt, p + 1, nchar(txt))
        if (grepl("^[0-9]+\\.[0-9]+$", a) && grepl("^[0-9]+\\.[0-9]+$", b) &&
            .ppDecimals(a) == .ppDecimals(b)) ok[[length(ok) + 1]] <- c(a, b)
      }
      if (length(ok) == 1L) ok[[1]] else NULL
    })
    good <- fused[!vapply(split, is.null, logical(1))]
    if (length(good) < 2) next
    for (k in seq_along(fused)) {
      if (is.null(split[[k]])) next
      f <- fused[k]
      t$type[f] <- "meanSD"
      t$num1[f] <- .ppAsNumeric(split[[k]][1]); t$num2[f] <- .ppAsNumeric(split[[k]][2])
      t$dec1[f] <- .ppDecimals(split[[k]][1]);  t$dec2[f] <- .ppDecimals(split[[k]][2])
      t$text[f] <- paste(split[[k]][1], "\u00b1", split[[k]][2])
    }
    tokensByLine[[i]] <- t
  }
  # ---- Manuscript-genre repairs (2026-08-20) -------------------------------
  # Both patterns below were found on the A&A submitted-manuscript corpus;
  # journal typography rarely produces either. See test-manuscript-layouts.R.
  #
  # (1) "Race, %   <0.001": a category header whose only numeric content is
  #     p-value-shaped. Classified as data, it never becomes the category
  #     header, so every child row beneath it is skipped as a bare number.
  #     Reclassify it as a label line; its p-value goes with it.
  for (i in which(kind == "data")) {
    toks <- tokensByLine[[i]]
    lbl  <- .ppSquish(substr(paste(lines[[i]]$text, collapse = " "),
                             1, min(toks$start) - 1))
    if (nchar(lbl) >= 4 &&
        all(toks$type == "plain" & !is.na(toks$num1) & abs(toks$num1) < 1)) {
      kind[i] <- "label"
      lineTexts[i] <- lbl                 # the header text, minus its p-value
      tokensByLine[[i]] <- toks[0, , drop = FALSE]
    }
  }
  # (2) A numeric line ABOVE the (n = ...) header row - quintile bounds, a
  #     year range, dose levels - is not data. Left as data, its tokens seed
  #     the column clustering with x positions that belong to no arm, and
  #     the arm count explodes. Reclassified as a label, its words can still
  #     contribute to the arm names.
  headerAt <- which(kind == "header")
  if (length(headerAt) > 0 && headerAt[1] - capIdx <= 8) {
    early <- which(kind == "data")
    early <- early[early < headerAt[1]]
    if (length(early) <= 3)
      for (i in early) {
        kind[i] <- "label"
        tokensByLine[[i]] <- tokensByLine[[i]][0, , drop = FALSE]
      }
  }
  # (2b) "Group 1 Group 2 Group 3 Group 4" (CJA 1997;44:390, issue 45): arm
  #     names that end in ordinals are a data line to the tokenizer - the
  #     label "Group" with the values 1, 2, 3, 4 - so the line was skipped
  #     as a bare number and the arms had no names. A line whose numbers
  #     are exactly 1..k in order, each preceded by the same word, is the
  #     arm-name line; reclassified as a label, its words name the arms.
  #     The line may go on after the last ordinal - "Group 1 Group 2 Group 3
  #     ANOVA test p value" (RezkJMFNM2014, corpus batch 5, K1) heads its
  #     statistic columns on the same line - so only the run of "word
  #     number" pairs is required, and whatever follows the last number
  #     is left to name the columns beyond the arms (issue 50).
  #     And a line whose label is the word "Group" (or Arm, Treatment) and
  #     whose values are the arms' NAMES - "Group 60 50 40 30 20
  #     Volunteers", the stimulating currents of CJA 1995;42:992 (corpus
  #     batch 5, K2; issue 56) - is the arm-name line too, when it stands
  #     above the first line that holds a value cell; its numbers name the
  #     arms as printed and the words after them name the rest.
  firstValue <- suppressWarnings(min(which(vapply(tokensByLine, function(t)
    !is.null(t) && any(t$type %in% c("meanSD", "numParen", "nPct", "fraction", "medianRng")), logical(1)))))
  for (i in which(kind == "data")) {
    toks <- tokensByLine[[i]]
    if (nrow(toks) < 2 || !all(toks$type == "plain")) next
    lbl <- .ppSquish(substr(paste(lines[[i]]$text, collapse = " "), 1, min(toks$start) - 1))
    if (grepl("(?i)^(groups?|arms?|treatments?)$", lbl, perl = TRUE) && i < firstValue &&
        all(!is.na(toks$num1) & toks$num1 == round(toks$num1) & toks$num1 >= 0)) {
      kind[i] <- "label"
      tokensByLine[[i]] <- toks[0, , drop = FALSE]
      next
    }
    if (!identical(as.numeric(toks$num1), as.numeric(seq_len(nrow(toks))))) next
    words <- lines[[i]]$text
    isNum <- grepl("^[0-9]+$", words)
    if (sum(isNum) != nrow(toks)) next
    numAt <- which(isNum)
    if (any(numAt < 2L) || !all(numAt == seq(numAt[1], by = 2L, length.out = length(numAt)))) next
    wordAt <- numAt - 1L                                   # the word before each number
    if (length(unique(tolower(words[wordAt]))) != 1L) next
    if (numAt[1] != 2L) next                               # the run starts the line
    kind[i] <- "label"
    tokensByLine[[i]] <- toks[0, , drop = FALSE]
  }
  # (3) "Body mass index, kg/m 2": a superscript unit exponent set as its
  #     own word turns a variable heading into a "data" line with one bare
  #     token, so it never becomes the category header, and the Mean /
  #     Median rows beneath it lose their variable name (vocacapsaicin
  #     corpus, 2026-08-22). A single small integer sitting right after a
  #     short unit word at the line's end is an exponent, not a value.
  for (i in which(kind == "data")) {
    toks <- tokensByLine[[i]]
    if (nrow(toks) != 1 || toks$type[1] != "plain") next
    if (is.na(toks$num1[1]) || !toks$num1[1] %in% c(2, 3)) next
    if (grepl("(?i)[a-z]{1,3}\\s*[23]\\s*[)\\]]?\\s*$", lineTexts[i],
              perl = TRUE) &&
        nchar(.ppSquish(sub("[23]\\s*[)\\]]?\\s*$", "", lineTexts[i]))) >= 4) {
      kind[i] <- "label"
      tokensByLine[[i]] <- toks[0, , drop = FALSE]
    }
  }

  dataIdx <- which(kind == "data")
  if (length(dataIdx) == 0) return(NULL)
  firstData <- dataIdx[1]
  lastData  <- dataIdx[length(dataIdx)]

  # ---- The repeated-measures layout is tried first (issue 34) ------------
  # Arms as rows under a Group column, timepoints as columns, only the
  # Baseline column wanted. The reader returns NULL unless the layout is
  # unambiguous, and on NULL everything below runs exactly as before. It
  # sits here, after the lines are classified and before the columns are
  # clustered, because clustering is the step that misreads this layout:
  # it takes the two timepoint columns for two arms and each variable's
  # group rows for separate variables. See R/parseRepeatedMeasures.R.
  longRes <- .ppParseRepeatedMeasures(lines, lineTexts, kind, tokensByLine, capIdx,
                               lastData, trial, roundObsDelta,
                               footnoteInfo = footnoteInfo,
                               textCands = textCands, textTotals = textTotals,
                               textGroupN = textGroupN)
  if (!is.null(longRes)) {
    say("  repeated-measures layout: ", nrow(longRes$arms), " arm(s) as",
        " rows under a Group column; Baseline column read, other timepoints",
        " ignored.")
    return(longRes)
  }

  # ---- LEVELS ACROSS THE LINE (2026-09-25, ISSUES.md issue 49) --------------
  # A categorical variable printed as ONE line with its levels named after
  # the label's colon and every arm's counts side by side: "Age (years):
  # 20-30 31-40  78 (47.6%) 86 (52.4%)  70 (43.75%) 90 (56.25%)  74 (45.7%)
  # 88 (54.3%)" (RezkHiF2020, the rotated table of issue 38; three such
  # rows). Six n (%) cells on a three-arm table seeded six columns, the
  # continuous rows' three cells fell into three of them, and the report
  # carried three phantom arms holding category counts. The signature is
  # exact: the arm count k is printed in the header ("(n = 164)" three
  # times), the line holds m x k n (%) cells for an integer m >= 2, and
  # the text between the colon and the first cell names exactly m levels.
  # Such a line's cells feed no column: they are set aside here, and the
  # block walker emits the row from them, arm by arm in printed order
  # (cell i belongs to arm ceiling(i / m), level (i - 1) mod m + 1).
  spreadRows <- list()
  kHeader <- 0L
  for (h in which(kind == "header")) {
    if (h >= firstData) break
    kHeader <- max(kHeader, length(gregexpr("(?i)n\\s*=\\s*\\d", lineTexts[h], perl = TRUE)[[1]]))
    if (kHeader > 0L) break
  }
  if (kHeader >= 2L) for (i in dataIdx) {
    t <- tokensByLine[[i]]
    if (nrow(t) < 2L * kHeader) next
    np <- which(t$type == "nPct")
    if (length(np) < 2L * kHeader || length(np) %% kHeader != 0L) next
    if (!identical(np, seq(np[1], np[1] + length(np) - 1L))) next   # one contiguous run
    if (any(t$type[seq_len(np[1] - 1L)] != "plain")) next            # only level parts before it
    trailing <- if (max(np) < nrow(t)) t[seq(max(np) + 1L, nrow(t)), , drop = FALSE] else t[0, ]
    if (any(trailing$type != "plain")) next                          # p-values at most
    m <- length(np) %/% kHeader
    if (m < 2L) next
    joined <- paste(lines[[i]]$text, collapse = " ")
    head   <- substr(joined, 1, t$start[np[1]] - 1L)
    colon  <- regexpr(":", head, fixed = TRUE)
    if (colon < 1L) next
    levels <- .ppSpreadLevels(substr(head, colon + 1L, nchar(head)))
    if (length(levels) != m) next
    spreadRows[[as.character(i)]] <- list(
      label  = .ppCleanLabel(substr(head, 1, colon - 1L)),
      levels = levels, m = m, k = kHeader,
      counts = t$num1[np], pcts = t$num2[np])
    tokensByLine[[i]] <- t[0, , drop = FALSE]
    say("  \"", .ppSquish(substr(head, 1, colon - 1L)), "\": ", m, " levels across the line for ",
        kHeader, " arms (", length(np), " cells) - read arm by arm.")
  }
  allToks <- do.call(rbind, tokensByLine[dataIdx])
  if (is.null(allToks) || nrow(allToks) == 0) return(NULL)

  # ---- Column clustering --------------------------------------------------
  cols    <- .ppClusterColumns(allToks$mid)

  # A COLUMN FED ONLY BY LABEL-LESS LINES IS NOT AN ARM COLUMN (2026-09-25,
  # ISSUES.md issue 46; CJA 1995;42:1096, a scanned page). Beneath that
  # Table I the OCR of a figure's axis - "30", "20", "10" down the left,
  # "15 20 25 30 35 40" along the bottom - runs on inside the block: the
  # lines carry numbers and no label, so they are data to the classifier,
  # and their x positions seeded three columns no table cell ever used.
  # The arm count went to five, the fence that keeps prose out of the arm
  # names (below) widened with it, and a footnote sentence named the arms.
  # A real column is fed by a line that names its row: header Ns aside,
  # every cell of a table sits on a labelled line. Columns fed only by
  # label-less lines are dropped, with their tokens; what remains of a
  # label-less line is judged by the block walker as before.
  labelled <- unlist(lapply(dataIdx, function(i) {
    t <- tokensByLine[[i]]
    if (nrow(t) == 0) return(logical(0))
    lbl <- .ppSquish(substr(paste(lines[[i]]$text, collapse = " "), 1, min(t$start) - 1))
    rep(nchar(lbl) > 0, nrow(t))
  }))
  if (cols$n > 1 && length(labelled) == nrow(allToks) && any(labelled)) {
    colOf <- cols$assign(allToks$mid)
    fed   <- vapply(seq_len(cols$n), function(k) any(labelled[colOf == k]), logical(1))
    if (!all(fed)) {
      say("  ", sum(!fed), " column(s) fed only by lines without a row label ",
          "dropped - not arm columns.")
      for (i in dataIdx) {
        t <- tokensByLine[[i]]
        if (nrow(t) == 0) next
        gone <- t[!fed[cols$assign(t$mid)], , drop = FALSE]
        if (nrow(gone) == 0) next
        # the dropped tokens' WORDS leave the line too, and the line is
        # tokenized afresh: kept in the text, "15 20 25" became the label
        # of the tokens that stayed, and a level called "15 20 25"
        L <- lines[[i]]
        wMid <- L$x + L$width / 2
        inGone <- vapply(wMid, function(m) any(m >= gone$x0 - 1 & m <= gone$x1 + 1), logical(1))
        L <- L[!inGone, , drop = FALSE]
        if (nrow(L) == 0) { kind[i] <- "junk"; tokensByLine[[i]] <- t[0, , drop = FALSE]; next }
        lines[[i]]        <- L
        lineTexts[i]      <- .ppLineText(L)
        tokensByLine[[i]] <- .ppTokenizeLine(L)
        if (nrow(tokensByLine[[i]]) == 0) kind[i] <- "junk"
      }
      allToks <- do.call(rbind, tokensByLine[dataIdx])
      if (is.null(allToks) || nrow(allToks) == 0) return(NULL)
      cols <- .ppClusterColumns(allToks$mid)
    }
  }

  # A STRATUM LINE (issue 55): a labelled "(n = k)" line after the first
  # header line - "Young patients (n = 75) (n = 25) (n = 25) (n = 25)" under
  # the column header's "(n = 50)" - is not the header, wherever it sits:
  # the first one often stands ABOVE the first data row. Marked here so
  # the header reads its arm sizes from the column header alone, and the
  # block walker opens the stratum when it reaches the line.
  # The FIRST size line is a stratum too when it states ONE size under a
  # population label and the arm names stand on a line of their own
  # above it: "Variable Placebo Metoclopramide ..." / "Younger patients
  # (20-40y) [n = 60]" / "n 20 20 20" (Fujii & Shiga 2006, PMID 17163298,
  # corpus batch 8, N2). Taken for the column header, that line gave every
  # arm the stratum's 60 and the first stratum's rows went unprefixed.
  # A "[" before the size is cut like a "(".
  hdrAll <- which(kind == "header"); hdrAll <- hdrAll[hdrAll > capIdx]
  for (h in hdrAll) {
    m1 <- regexpr("(?i)[(\\[]?\\s*n\\s*=\\s*\\d", lineTexts[h], perl = TRUE)
    if (m1 < 1) next
    nSizes <- length(gregexpr("(?i)n\\s*=\\s*\\d", lineTexts[h], perl = TRUE)[[1]])
    lead <- .ppSquish(sub("[(\\[]\\s*$", "", substr(lineTexts[h], 1, m1 - 1)))
    isLabel <- nchar(gsub("[^A-Za-z]", "", lead)) >= 3 &&
      !grepl("(?i)^(number|no\\.?|n|patients|subjects|participants)(\\s+of\\s+(patients|subjects|participants))?$",
             lead, perl = TRUE)
    if (!isLabel) next
    if (h != hdrAll[1]) { kind[h] <- "stratum"; next }
    # the first size line: a stratum only when it names a population and
    # states a single size, with the arm names elsewhere
    if (nSizes == 1L &&
        grepl("(?i)patients|subjects|participants|women|men|children|infants|adults|elderly|younger|older|\\d+\\s*[-–]\\s*\\d+\\s*y",
              lead, perl = TRUE))
      kind[h] <- "stratum"
  }

  # ---- Header: arm names and arm N ----------------------------------------
  headerIdx <- which(kind %in% c("header", "label"))
  headerIdx <- headerIdx[headerIdx > capIdx & headerIdx < firstData]
  # When a real header line exists, the label lines before it are the
  # caption's legend sentences, not arm names - manuscripts print those
  # between the caption and the table (2026-08-20). EXCEPT the one line
  # immediately above it: submission tables stack the header as an
  # arm-NAMES row over an N row ("0.05 mg/mL" / "N=36"), so that line
  # is the names (vocacapsaicin corpus, 2026-08-22). A legend sentence
  # in that position is fenced out by its word count - prose runs far
  # longer than one name per column.
  # ... and only the header lines ABOVE the first data row: a row-level
  # "(n = k)" line inside the block (issue 47) or a stratum's size line is
  # not the column header (CodeRabbit on PR #363)
  headerAt <- which(kind == "header"); headerAt <- headerAt[headerAt < firstData]
  if (length(headerAt) > 0) {
    nameRow <- headerAt[1] - 1L
    keepNameRow <- nameRow %in% headerIdx &&
      nrow(lines[[nameRow]]) <= cols$n * 3 + 2
    headerIdx <- headerIdx[headerIdx >= headerAt[1] |
                             (keepNameRow & headerIdx == nameRow)]
  }
  # The same fence for EVERY label line that would name the arms (issue
  # 46): with no "(n = k)" header on the page at all, the footnote
  # sentence "were no differences in number of patients, age, sex, height,
  # or body weight", set between caption and header on the OCR of CJA
  # 1995;42:1096, named the arms "were no", "differences in", ... A line
  # of more words than the columns could carry three apiece is prose.
  headerIdx <- headerIdx[vapply(headerIdx, function(i)
    kind[i] == "header" || nrow(lines[[i]]) <= cols$n * 3 + 2, logical(1))]
  armN    <- rep(NA_integer_, cols$n)
  armName <- rep(NA_character_, cols$n)

  # Arm N first, by character position: "(n= 19)" splits into two words, so
  # per-column word bucketing can lose the digits. Matching the joined line
  # and mapping the match back to word x positions - the tokenizer's own
  # technique - is robust to how poppler split the cell (2026-08-20).
  # The words of every "(n = k)" match, per header line, so the arm-name
  # assembly below can leave them out (2026-09-25, issue 37): a "24)"
  # that poppler set nearer the NEXT column's centre used to open that
  # arm's name ("24) PECS group (n = 24").
  nSpanWords <- list()
  for (i in intersect(headerAt, seq(capIdx + 1, length(lines)))) {
    d <- lines[[i]]
    joined    <- paste(d$text, collapse = " ")
    wordStart <- cumsum(c(1, nchar(d$text) + 1))[seq_len(nrow(d))]
    wordEnd   <- wordStart + nchar(d$text) - 1
    m <- gregexpr("(?i)n\\s*=\\s*\\d[\\d,]*", joined, perl = TRUE)[[1]]
    if (m[1] == -1) next
    # "(n = k)" ANNOTATES THE NAME TO ITS LEFT (2026-09-25, issue 37;
    # Kulturoglu 2024 JA). "RIB group (n=24)  PECS group (n=24)  Control
    # group (n=24)", left-aligned over columns whose numbers are narrower
    # than the headings: each "(n=24)" sits to the RIGHT of its arm's name,
    # and its midpoint falls nearer the NEXT column's centre - arm 1's N
    # went to arm 2, arm 2's to arm 3, arm 3's to the p-value column, and
    # arm 3 had no N, so the table failed validation. The word before the
    # match - the last word of the name - is the arm the count belongs
    # to, so the column is read from that word's centre; the midpoint
    # rule remains for a match with no word before it (a header that is
    # only "(n = 24)").
    spans <- integer(0)
    for (k in seq_along(m)) {
      s <- m[k]; e <- s + attr(m, "match.length")[k] - 1
      wFirst <- which(wordEnd >= s)[1]
      wLast  <- rev(which(wordStart <= e))[1]
      thisSpan <- seq(wFirst, wLast)
      # a detached "(" before the match and ")" after it are the count's
      # too (CodeRabbit on PR #340: "Control ( n = 15 )" set as separate
      # words used to leave "( )" in the name), for EVERY match
      if (wFirst > 1L && grepl("^\\($", d$text[wFirst - 1L]))
        thisSpan <- c(wFirst - 1L, thisSpan)
      if (wLast < nrow(d) && grepl("^\\)$", d$text[wLast + 1L]))
        thisSpan <- c(thisSpan, wLast + 1L)
      wPrev  <- min(thisSpan) - 1L
      xRef   <- if (wPrev >= 1L && !(wPrev %in% spans))
        d$x[wPrev] + d$width[wPrev] / 2
      else (d$x[wFirst] + d$x[wLast] + d$width[wLast]) / 2
      spans  <- c(spans, thisSpan)
      colk   <- cols$assign(xRef)
      nval   <- suppressWarnings(as.integer(gsub("\\D", "", substr(joined, s, e))))
      if (!is.na(nval) && is.na(armN[colk])) armN[colk] <- nval
    }
    nSpanWords[[as.character(i)]] <- unique(spans)
  }
  # A word that carries the count is not dropped from the arm's name; the
  # COUNT TEXT is removed from it (CodeRabbit on PR #340: "Control(n=15)"
  # set as one word must keep "Control"). A word that was nothing but
  # count - "(n", "=", "24)" - becomes empty and contributes nothing.
  stripCount <- function(x) .ppSquish(gsub("(?i)\\(?\\s*n\\b|=|[0-9][0-9,]*\\)?|^[()]$",
                                           "", x, perl = TRUE))
  for (i in headerIdx) {
    d    <- lines[[i]]
    wMid <- d$x + d$width / 2
    wCol <- cols$assign(wMid)
    # Only words near a column centre belong to it, so a row-label header
    # such as "Characteristic" is not swept into the first arm.
    near <- abs(cols$centers[wCol] - wMid) <
              (if (cols$n > 1) min(diff(sort(cols$centers))) * 0.75 else 100)
    inSpan <- seq_len(nrow(d)) %in% nSpanWords[[as.character(i)]]
    wordText <- d$text
    wordText[inSpan] <- vapply(d$text[inSpan], stripCount, character(1))
    for (k in seq_len(cols$n)) {
      wtxt <- paste(wordText[near & wCol == k & nzchar(wordText)], collapse = " ")
      if (nchar(wtxt) == 0) next
      nMatch <- regmatches(wtxt, regexpr("(?i)n\\s*=\\s*(\\d+)", wtxt, perl = TRUE))
      if (length(nMatch) > 0 && is.na(armN[k]))
        armN[k] <- as.integer(sub("\\D+", "", nMatch))
      nameTxt <- .ppSquish(gsub("(?i)\\(?\\s*n\\s*=\\s*\\d+\\s*\\)?", "", wtxt, perl = TRUE))
      if (nchar(nameTxt) > 0)
        armName[k] <- .ppSquish(paste(ifelse(is.na(armName[k]), "", armName[k]), nameTxt))
    }
  }

  # The N row's label: "n", "N", "No.", "Number", or "Number of patients"
  # and its kin. A bare "Number" (CJA 1996;43:362, "Number 15 15 15 15")
  # was not matched, the line was skipped as a bare number, and an arm
  # whose name the text ladder could not place stayed without N (ISSUES.md
  # issue 48, 2026-09-25). The nouns cover the animal papers too.
  nRowPattern <- paste0("(?i)^(n|no\\.?|number|",
                        "(no\\.?|number)\\s+of\\s+(patients|subjects|cases|",
                        "participants|animals|dogs|rats|rabbits|pigs|",
                        "women|men|children|infants|volunteers))$")

  # The column header's own printed sizes, remembered here - before the n (%)
  # and document-text recovery below - for the arms table of a table with
  # strata (issue 55; CodeRabbit on PR #363: saved after recovery, a
  # recovered size outranked the stratum's printed one).
  armNHeader <- armN

  # ---- Drop a p-value column ----------------------------------------------
  # A column header of a bare "P" is ambiguous: it is the usual heading of a
  # p-value column, but it is also how trials abbreviate a placebo arm. Only
  # "P value" (spelled out) is taken as conclusive on the header alone;
  # a bare "P" must also have cells that look like p-values, or a real
  # treatment arm gets discarded - which corrupts the neighbouring row label
  # as well, since the label is everything left of the first surviving cell.
  pCol <- integer(0)
  if (cols$n >= 2) {
    for (k in seq_len(cols$n)) {
      hdr  <- armName[k]
      toks <- allToks[cols$assign(allToks$mid) == k, ]
      pExplicit <- !is.na(hdr) && grepl("(?i)p[-\u2013 ]?values?|significance",
                                        hdr, perl = TRUE)
      pMaybe    <- !is.na(hdr) && grepl("^[Pp][.:]?$", .ppSquish(hdr))
      cellsLikeP <- nrow(toks) > 0 &&
        mean(toks$type %in% c("plain", "pctOnly") & !is.na(toks$num1) &
               toks$num1 < 1) > 0.5 &&
        is.na(armN[k])
      if (pExplicit || (pMaybe && cellsLikeP) || cellsLikeP)
        pCol <- c(pCol, k)
    }
  }

  # ---- Drop a Total / Overall column --------------------------------------
  # Many Table 1s close with a column summing the arms ("Total  N=147").
  # It is not a treatment arm: its values are arithmetic consequences of
  # the others, and analyzing it as an independent sample would corrupt
  # the Monte Carlo (the "arms" would be guaranteed too similar).
  # Identified by its header name alone - conservative exact matches, so
  # a real arm can never be discarded by a fuzzy pattern (vocacapsaicin
  # corpus, 2026-08-22).
  totCol <- integer(0)
  for (k in seq_len(cols$n)) {
    hdr <- armName[k]
    if (!is.na(hdr) &&
        grepl(paste0("(?i)^(total|overall|all\\s+(patients|subjects|",
                     "participants)|entire\\s+cohort)$"),
              .ppSquish(hdr), perl = TRUE)) {
      totCol <- c(totCol, k)
      say("  column \"", .ppSquish(hdr), "\" dropped - a totals column,",
          " not a treatment arm.")
    }
  }

  arms  <- setdiff(seq_len(cols$n), c(pCol, totCol))
  nArms <- length(arms)
  if (nArms == 0) return(NULL)

  # ---- Recover missing arm N (2026-08-21) ----------------------------------
  # The single largest deficit found by comparing this engine against an
  # AI-only run of the 654-submission corpus: 583 skipped rows were blocked
  # ONLY on an unknown arm N. Two deterministic sources, table first:
  #
  # (a) The arm's own printed n (%) cells. "13 (68.4%)" pins the arm size
  #     to the integers consistent with the printed rounding - usually
  #     exactly one. Traceable entirely to cells on the page.
  # Recovery only runs when NO data-bearing cluster has an N yet. Measured
  # on the 654-submission corpus, every genuine recovery was of a table
  # with no printed arm sizes anywhere; when the real arms already carried
  # header Ns, recovery only decorated stray clusters (a "%" subcolumn, an
  # escaped p column, an "All" column) with phantom arm sizes.
  armNSource <- rep(NA_character_, cols$n)
  dataArms   <- intersect(arms, unique(cols$assign(allToks$mid)))
  # Eligibility is decided ONCE, before either source runs: a table whose
  # header printed no arm size at all. The n (%) derivation may then fill
  # some arms and the text the rest.
  recoveryEligible <- length(dataArms) > 0 && all(is.na(armN[dataArms]))
  if (recoveryEligible) {
    for (k in dataArms) {
      kt <- allToks[cols$assign(allToks$mid) == k & allToks$type == "nPct", ,
                    drop = FALSE]
      if (nrow(kt) == 0) next
      n <- .ppDeriveArmN(kt$num1, kt$num2, kt$dec2)
      if (!is.na(n)) {
        armN[k] <- n
        armNSource[k] <- sprintf(
          "derived from %d printed n (%%) cell(s) of this arm", nrow(kt))
        say("  arm ", k, ": N = ", n, " ", armNSource[k], ".")
      }
    }
    # (a2) The arm's printed FRACTION cells (2026-09-25, ISSUES.md issue 41;
    #     CJA 2003;50:342, whose only statement of the arm sizes is "Sex
    #     (female/male) 6/9" in every arm). The parts of a sex or ASA
    #     fraction sum to the arm: when every fraction cell of the arm
    #     sums to one and the same value, that value is its N. Two
    #     fraction rows that disagree ("6/9" and "5/8") leave N unknown -
    #     one of them is not the whole arm, and the text cannot say which.
    #     The same gate as (a): only a table that printed no arm size.
    for (k in dataArms) {
      if (!is.na(armN[k])) next
      kt <- allToks[cols$assign(allToks$mid) == k & allToks$type == "fraction", ,
                    drop = FALSE]
      if (nrow(kt) == 0) next
      sums <- vapply(strsplit(gsub("\\s", "", kt$text), "/"), function(p)
        sum(suppressWarnings(as.integer(p))), numeric(1))
      if (any(is.na(sums)) || length(unique(sums)) != 1L || sums[1] < 1) next
      armN[k] <- as.integer(sums[1])
      armNSource[k] <- sprintf(
        "derived from %d printed a/b fraction cell(s) of this arm (the parts sum to the arm)",
        nrow(kt))
      say("  arm ", k, ": N = ", armN[k], " ", armNSource[k], ".")
    }
  }
  # (b) The document text - the randomization sentence of the Methods, the
  #     abstract, or a CONSORT flow label with a text layer. Candidates and
  #     stated totals are extracted once per document by the caller; the
  #     assignment ladder (name match, elimination, position confirmed by
  #     the stated total) and its safeguards live in armNRecovery.R. Every
  #     N taken this way carries its source sentence, and reviewFlags()
  #     tells the reviewer to verify it against the CONSORT diagram.
  #     The same no-known-N gate applies, for the same measured reason.
  #     The ladder sees only the arms that carry VALUE cells (mean +/- SD,
  #     mean (SD), n (%), a fraction, a median): a statistic column - the
  #     "ANOVA test" F values beside RezkJMFNM2014's three groups (corpus
  #     batch 5, K1) - clusters as a column too, and counted as a fourth
  #     arm it made "3 x 30 = 90" unreachable. It gets no N here, and an
  #     arm with neither N nor a cell is dropped at assembly (issue 50).
  valueArms <- intersect(dataArms, unique(cols$assign(
    allToks$mid[allToks$type %in% c("meanSD", "numParen", "nPct", "fraction", "medianRng")])))
  if (length(valueArms) == 0) valueArms <- dataArms
  if (recoveryEligible && any(is.na(armN[valueArms])) &&
      !is.null(textCands) && nrow(textCands) > 0) {
    fill <- .ppFillArmNFromText(armN[valueArms], armName[valueArms], textCands,
                                if (is.null(textTotals)) integer(0)
                                else textTotals)
    newly <- is.na(armN[valueArms]) & !is.na(fill$N)
    armN[valueArms] <- fill$N
    armNSource[valueArms][newly] <- fill$source[newly]
    for (k in which(newly))
      say("  arm ", valueArms[k], ": N = ", fill$N[k], " from ",
          fill$source[k])
  }

  # ---- How to read "a (b)" cells ------------------------------------------
  footTxt <- paste(footnoteInfo, collapse = " ")
  footSaysMeanSD <- grepl("(?i)mean\\s*[(\u00b1]\\s*(sd|standard deviation)",
                          footTxt, perl = TRUE)
  # A footnote reading "Data are numbers (%)" settles the question that
  # "20 (66.7)" otherwise leaves open. Without this the cell defaulted to
  # mean-and-SD, turning a count and a percentage into a baseline statistic -
  # 20 patients, 66.7% of them, became a mean of 20 with an SD of 66.7.
  footSaysPercent <- grepl(
    paste0("(?i)(numbers?|counts?|figures?)\\s*\\(\\s*%",
           "|\\bn\\s*\\(\\s*%\\s*\\)",
           "|number\\s*\\(\\s*per\\s*cent"),
    footTxt, perl = TRUE)

  # Is the dispersion a standard deviation or a standard error? Papers print
  # one or the other and say which, usually in a footnote and sometimes in the
  # row label. Getting this wrong is not a rounding-level error: at n = 15 an
  # SE is roughly a quarter of the SD, so filing one as the other is out by a
  # factor of four. When the table says nothing the value goes in SD, which is
  # the overwhelming convention, and the assumption is recorded rather than
  # hidden - see the `dispersion` element of the returned object.
  seWord <- paste0("(?i)\\bs\\.?e\\.?m\\.?\\b|\\bs\\.?e\\.?\\b",
                   "|standard\\s+error")
  footSaysSE <- grepl(seWord, footTxt, perl = TRUE)
  footSaysSD <- grepl("(?i)\\bs\\.?d\\.?\\b|standard\\s+deviation", footTxt,
                      perl = TRUE)
  dispersionBasis <- if (footSaysSE && !footSaysSD) "se (stated)"
                     else if (footSaysSD && !footSaysSE) "sd (stated)"
                     else if (footSaysSE && footSaysSD) "mixed (per row)"
                     else "sd (assumed - table does not say)"
  tableHasPlusMinus <- any(allToks$type == "meanSD")
  continuousKeyword <- paste0(
    "(?i)age|weight|height|bmi|body\\s+mass|duration|time|pressure|rate|",
    "score|hemoglobin|haemoglobin|creatinine|glucose|albumin|dose|volume|",
    "length|circumference|temperature|count|level")

  # ---- Walk the data lines and build output rows --------------------------
  outRows      <- list()
  skipped      <- list()
  catHeader    <- NA_character_
  catHeaderPct <- FALSE        # did the category header announce percentages?
  catHeaderNPct <- FALSE       # ... or "N (%)" cells (counts with percents)?
  catColumns   <- character(0)
  usedRowNames <- character(0)
  pctDerived   <- character(0) # rows whose counts were derived from percents
  rowNLines    <- character(0) # rows whose N came from their own "(n = k)" line (issue 47)
  stratumStarts <- list()      # where each stratum begins in outRows, and its name (issue 55)
  pctApproxRows <- character(0) # rows using the opt-in approximation
  # THE BRACKETS BEHIND EVERY AMBIGUOUS PERCENTAGE (2026-09-08). The
  # counts a printed percentage allows are decided for the whole
  # arms-by-levels block at once, and a block is only complete after
  # this loop has walked every one of its lines. So each line records
  # its brackets here, keyed by the block and the level column, and the
  # choice is made below, once, against the statistic P_Calc actually
  # scores. See R/failsafeTable.R for why the per-line rule it replaced
  # was not merely imprecise but backwards.
  pctBrackets  <- list()       # [[blockKey]][[column]] = list(lo, hi, pct)
  # the row names the per-line pass claimed for each block, so that a
  # block the joint pass declines can take its own claim back (F2), and
  # which blocks did decline (screen 2026-09-09-1532, F3)
  pctApproxByBlock <- list()   # [[blockKey]] = character vector of names
  pctDeclinedBlocks <- character(0)
  pctStraddle  <- character(0) # blocks where the choice crosses p = 0.01
  pctUnresolved <- character(0) # ... and where no reading could be certified,
                                # named by the reason; their cells go blank
  derivedCells <- list()       # (ROW, COL, KIND, NOTE) for the app grid
  addDerived <- function(rowName, colName, kind, note)
    derivedCells[[length(derivedCells) + 1]] <<-
      data.frame(ROW = rowName, COL = colName, KIND = kind,
                 NOTE = note, stringsAsFactors = FALSE)

  addSkip <- function(label, reason, txt)
    skipped[[length(skipped) + 1]] <<-
      data.frame(label = label, reason = reason, text = txt,
                 stringsAsFactors = FALSE)

  # label-kind lines already absorbed into the row ABOVE them as the
  # wrapped second line of its label (see the data branch below)
  consumedLabel <- integer(0)
  catHeaderAt   <- NA_integer_   # the line the open heading was read from (issue 68)

  # ---- THE HEADING ABOVE THE FIRST DATA LINE (issue 44, 2026-09-25) ----
  # The loop below starts at the first data line, so a variable printed
  # as a heading line with its statistics on legend-labelled lines
  # beneath - "Age, y" / "Mean +/- SD 46 +/- 8 ..." / "Range 33-57 ..."
  # (Fujii 2002, PMID 12182258, whose every variable is set this way) -
  # lost the name of its FIRST variable: the "Mean +/- SD" line went out
  # under that legend as its name, while "Height, cm", whose heading lies
  # inside the loop, was named correctly by the statRow rule below. The
  # label lines directly above the first data line are read here for a
  # heading, with the label branch's own test and two of their own: the
  # line must lie LEFT of the first value column (an arm-name line
  # without "(n = k)" is a label line too, and sits over the columns),
  # and it must not be the caption's legend sentence ("Values are mean +/-
  # SD or number (%)"), which manuscripts print between caption and body.
  if (cols$n > 0 && firstData > capIdx + 1L) {
    pre <- integer(0)
    j   <- firstData - 1L
    while (j > capIdx && kind[j] == "label") { pre <- c(j, pre); j <- j - 1L }
    for (j in pre) {
      lbl <- .ppCleanLabel(lineTexts[j])
      L   <- lines[[j]]
      if (nchar(gsub("[^[:alnum:]]", "", lbl)) <= 1L || nrow(L) > 6) next
      if (max(L$x + L$width) >= min(cols$centers) - 20) next
      if (grepl(paste0("(?i)\\b(values?|data|results?|numbers?)\\s+(are|were|is)\\b|",
                       "\\bexpressed\\b|\\bpresented\\b|\\bshown\\b"),
                lineTexts[j], perl = TRUE)) next
      catHeader     <- lbl
      catHeaderNPct <- grepl("(?i)\\b(no?|n)\\.?\\s*\\(\\s*%\\s*\\)",
                             lineTexts[j], perl = TRUE)
      catHeaderPct  <- !catHeaderNPct &&
        (grepl("%", lineTexts[j], fixed = TRUE) ||
           grepl("(?i)\\bpercent", lineTexts[j], perl = TRUE))
    }
  }

  loopStart <- min(c(firstData, which(kind == "stratum")))   # a stratum may open above the first row
  for (i in seq(loopStart, lastData)) {
    if (kind[i] == "label") {
      if (i %in% consumedLabel) next
      lbl <- .ppCleanLabel(lineTexts[i])
      # A line of ONE letter or glyph names nothing - a level "I" whose
      # counts went missing, a stray watermark letter the strippers
      # let through - and must not replace the open heading (issue 44).
      if (nchar(gsub("[^[:alnum:]]", "", lbl)) <= 1L) next
      # A "|" is a ruled border as OCR reads it, never a word of a heading:
      # "i I | I I t" (the axis of a figure under a scanned table, CJA
      # 1995;42:1096) opened a heading and the ticks beneath became its
      # levels (issue 46).
      if (grepl("|", lbl, fixed = TRUE)) next
      # A FOOTNOTE never opens a heading: a label line that begins with a
      # footnote marker (*, dagger, double dagger, section sign) is the
      # table's note, and on Fujii 2006 (PMID 16982288, issue 55) "*No
      # significant between-group differences were found." became a
      # category heading for the stray numbers beneath it.
      if (grepl("^[*\u2020\u2021\u00a7]", lbl, perl = TRUE)) next
      # A journal watermark ("Downloaded from http://...") or copyright
      # rail interleaves with the table's own lines on some published
      # PDFs; taken as a label line it OVERWRITES the open block header
      # mid-block, orphaning the remaining children (vocacapsaicin
      # corpus, 2026-08-22: Race lost Black and Other to it).
      if (grepl("(?i)https?://|www\\.|downloaded\\s+from|copyright|©",
                lineTexts[i], perl = TRUE))
        next
      if (nchar(lbl) > 0 && nrow(lines[[i]]) <= 6) {
        catHeader <- lbl
        catHeaderAt <- i
        # "Race, N (%)": the children below are counts-with-percents -
        # levels of ONE category variable, whatever shape their cells
        # take ("12 (33)", "12(33%)", a bare "0"). Checked BEFORE the
        # bare-% test, which would otherwise shadow it (vocacapsaicin
        # corpus, 2026-08-22).
        catHeaderNPct <- grepl("(?i)\\b(no?|n)\\.?\\s*\\(\\s*%\\s*\\)",
                               lineTexts[i], perl = TRUE)
        # "Race, %" / "ASA status, %": the children below are percentages
        catHeaderPct <- !catHeaderNPct &&
          (grepl("%", lineTexts[i], fixed = TRUE) ||
             grepl("(?i)\\bpercent", lineTexts[i], perl = TRUE))
      }
      next
    }
    # A ROW'S OWN "(n = k)" LINE (2026-09-25, ISSUES.md issue 47; the corpus
    # session on Fujii 2002, PMID 12182258). "Last menstrual cycle, d*  15
    # ± 4  16 ± 3  16 ± 2  16 ± 3" is followed by "(n = 12) (n = 13) (n =
    # 12) (n = 12)" under its cells, and the footnote says why ("*N = 49.
    # Patients who had experienced menopause were excluded"): that row
    # was measured on fewer patients than the arm. The line is a header
    # kind to the classifier and was skipped, so the row went out with the
    # arm's N of 20 - and the hybrid merge, seeing the model's row with
    # the printed 12/13/12/12, kept both and double-counted the variable.
    # A "(n = k)" line directly under a continuous row, with each count
    # under one of the row's cells, is that row's N, arm by arm.
    # ... and a LABELLED "(n = k)" line is a STRATUM HEADER (2026-09-25,
    # ISSUES.md issue 55; the corpus session's M1, Fujii & Nakayama 2006,
    # PMID 16982288): "Young patients (n = 75) (n = 25) (n = 25) (n = 25)"
    # and, half-way down, "Older patients (n = 75) (n = 25) (n = 25) (n =
    # 25)", each followed by the same variables; the column header says
    # (n = 50). The rows beneath a stratum line carry that line's arm
    # sizes, and the stratum's name prefixes their names ("Young patients:
    # Age, y"), so the two strata are two sets of variables rather than
    # one set read twice with " 2" suffixes. A bare line - no label before
    # its first "(n =" - is the row above's own n (issue 47), as before.
    if ((kind[i] == "header" && i > firstData) || kind[i] == "stratum") {
      d      <- lines[[i]]
      joined <- paste(d$text, collapse = " ")
      wordStart <- cumsum(c(1, nchar(d$text) + 1))[seq_len(nrow(d))]
      wordEnd   <- wordStart + nchar(d$text) - 1
      m <- gregexpr("(?i)n\\s*=\\s*\\d[\\d,]*", joined, perl = TRUE)[[1]]
      if (m[1] != -1) {
        lead <- .ppSquish(sub("[(\\[]\\s*$", "", substr(joined, 1, m[1] - 1)))
        # the per-arm sizes on the line; a match left of the first arm column
        # (a stratum's own total, "(n = 75)") is not an arm's
        gapHalf <- if (cols$n > 1) min(diff(sort(cols$centers))) / 2 else 100
        nOf <- rep(NA_integer_, nArms)
        for (q in seq_along(m)) {
          s0 <- m[q]; e0 <- s0 + attr(m, "match.length")[q] - 1
          wFirst <- which(wordEnd >= s0)[1]; wLast <- rev(which(wordStart <= e0))[1]
          xMid <- (d$x[wFirst] + d$x[wLast] + d$width[wLast]) / 2
          if (xMid < min(cols$centers[arms]) - gapHalf) next
          j    <- match(cols$assign(xMid), arms)
          nval <- suppressWarnings(as.integer(gsub("\\D", "", substr(joined, s0, e0))))
          if (!is.na(j) && !is.na(nval)) nOf[j] <- nval
        }
        isStratum <- nchar(gsub("[^A-Za-z]", "", lead)) >= 3 &&
          !grepl("(?i)^(number|no\\.?|n|patients|subjects|participants)(\\s+of\\s+(patients|subjects|participants))?$",
                 lead, perl = TRUE)
        # a stratum line's SOLE size is the stratum's total ("Younger
        # patients [n = 60]"), never an arm's, wherever it sits on the line
        # (CodeRabbit on PR #363)
        if (isStratum && length(m) == 1L) nOf[] <- NA_integer_
        if (isStratum) {
          stratumStarts[[length(stratumStarts) + 1]] <- list(at = length(outRows), name = lead)
          for (j in which(!is.na(nOf))) armN[arms[j]] <- nOf[j]
          catHeader <- NA_character_; catHeaderPct <- FALSE; catHeaderNPct <- FALSE
          say("  stratum \"", lead, "\": arm N = ",
              paste(ifelse(is.na(nOf), "?", nOf), collapse = "/"), " for the rows beneath.")
        } else if (length(outRows) > 0 &&
                   identical(outRows[[length(outRows)]]$type, "continuous")) {
          last <- outRows[[length(outRows)]]
          set  <- integer(0)
          for (j in which(!is.na(nOf))) {
            if (is.null(last$perArm[[j]])) next
            last$perArm[[j]]$N <- nOf[j]
            set <- c(set, j)
          }
          if (length(set)) {
            outRows[[length(outRows)]] <- last
            rowNLines <- c(rowNLines, last$row)
            say("  row \"", last$row, "\": its own (n = k) line gives N = ",
                paste(vapply(last$perArm[set], function(v) as.character(v$N), character(1)),
                      collapse = "/"), " for arm(s) ", paste(set, collapse = ","),
                " (the printed row-level n).")
          }
        }
      }
      next
    }
    if (kind[i] == "data" && !is.null(spreadRows[[as.character(i)]])) {
      sp <- spreadRows[[as.character(i)]]
      if (sp$k != nArms) {
        addSkip(sp$label, paste0("levels across the line for ", sp$k, " arms, but ",
                                 nArms, " arm column(s) were read - enter by hand"),
                lineTexts[i])
        next
      }
      levelCols <- character(0)
      for (lv in sp$levels) {
        nm <- .ppUniqueName(.iaLevelColumnName(sp$label, lv), c(catColumns, levelCols))
        levelCols <- c(levelCols, nm)
      }
      catColumns <- unique(c(catColumns, levelCols))
      rowName <- .ppUniqueName(if (nchar(sp$label) > 0) sp$label else "Category", usedRowNames)
      usedRowNames <- c(usedRowNames, rowName)
      perArm <- lapply(seq_len(nArms), function(j) {
        idx <- (j - 1L) * sp$m + seq_len(sp$m)
        stats::setNames(as.list(as.integer(sp$counts[idx])), levelCols)
      })
      outRows[[length(outRows) + 1]] <-
        list(row = rowName, type = "category", perArm = perArm,
             key = paste0("__spread__", rowName))
      catHeader <- NA_character_; catHeaderPct <- FALSE; catHeaderNPct <- FALSE
      next
    }
    if (kind[i] != "data") next
    toks <- tokensByLine[[i]]
    toks$col <- cols$assign(toks$mid)
    toks <- toks[toks$col %in% arms, , drop = FALSE]
    if (nrow(toks) == 0) next
    joined   <- paste(lines[[i]]$text, collapse = " ")
    rawLabel <- substr(joined, 1, min(toks$start) - 1)
    # A ROW LABEL ON THE LINE ABOVE ITS VALUES (2026-09-25, ISSUES.md issue
    # 68; Rezk 2015, Clin Exp Obstet Gynecol, Loadsman corpus - the corpus
    # session's batch 14 S1). In a narrow first column the name wraps to
    # two lines and the typesetter centres the cells on the pair:
    # "Duration of active phase" / "5.25 +/- 0.86  5.31 +/- 0.85" /
    # "(hours)". The values' line carries no label at all, so the row went
    # out as "Unnamed" and the name above it opened a category heading
    # that nothing used. A value line with NO label directly beneath the
    # line that opened the heading takes that line as its name - a level
    # of a category always carries its own label, so a label-less value
    # line under a heading is the heading's own wrapped name, never a
    # level. The unit line beneath is then absorbed by the continuation
    # rule below, as any wrapped second line is.
    if (!nzchar(.ppSquish(rawLabel)) && !is.na(catHeaderAt) && catHeaderAt == i - 1L &&
        !is.na(catHeader) && i - 1L > capIdx) {
      rawLabel <- lineTexts[i - 1L]
      say("  Row label \"", .ppSquish(rawLabel), "\" taken from the line above its values.")
      catHeader <- NA_character_; catHeaderPct <- FALSE; catHeaderNPct <- FALSE
      catHeaderAt <- NA_integer_
    }
    # A ROW LABEL THAT WRAPS ONTO THE NEXT LINE (2026-09-24, Loadsman
    # corpus, Polat 2015 DA). "Amount of intraoperative  561.67 +/- ..."
    # with "fluid (ml)" on the line beneath, "Infusion duration of
    # study" over "drug (min)": the second line carries no value, so it
    # is a label-kind line, and the row went out as "Amount of
    # intraoperative" - a truncated name that the AI merge then could
    # not match to its own "Amount of intraoperative fluid" by label
    # (the value signature caught it; the name was still wrong). The
    # continuation is recognised by its typography, not its words: it
    # begins with a lower-case letter or a bracketed unit, and journals
    # capitalise the first line of a variable's name. A line that starts
    # with a capital is the NEXT variable's heading or a block header
    # and is left alone. The absorbed line is skipped by the label
    # branch above, so it cannot also become the open block header.
    # (the last data row's continuation lies just BEYOND lastData, so the
    # look-ahead runs to the end of the classified lines, not the block)
    # A lower-case CATEGORY HEADER ("sex, n (%)" in a manuscript that
    # does not capitalise) would pass the typography test and be eaten,
    # orphaning its indented children into skipped bare numbers
    # (CodeRabbit on PR #336). A header has children; a continuation does
    # not: when the line after the candidate is a data line whose label
    # starts to the RIGHT of the candidate's first word - indented under
    # it - the candidate is a header and is left to the label branch.
    if (i < length(kind) && kind[i + 1] == "label") {
      nxt <- .ppSquish(lineTexts[i + 1])
      xNext  <- lines[[i + 1]]$x[1]
      xChild <- if (i + 2L <= length(kind) && kind[i + 2L] == "data")
        lines[[i + 2L]]$x[1] else NA_real_
      indentedChild <- !is.na(xChild) && !is.na(xNext) && xChild > xNext + 4
      if (!indentedChild &&
          grepl("^[a-z(]", nxt, perl = TRUE) && nchar(nxt) <= 40 &&
          !grepl("[0-9]", gsub("\\([^)]*\\)", "", nxt))) {
        rawLabel <- paste(rawLabel, nxt)
        consumedLabel <- c(consumedLabel, i + 1L)
      }
    }
    label    <- .ppCleanLabel(rawLabel)
    txt      <- lineTexts[i]

    armTok <- lapply(arms, function(k) {
      t <- toks[toks$col == k, , drop = FALSE]
      if (nrow(t) > 0) t[1, ] else NULL
    })
    types <- vapply(armTok, function(t) if (is.null(t)) NA_character_ else t$type,
                    character(1))
    mainType <- names(sort(table(types), decreasing = TRUE))[1]

    if (grepl(nRowPattern, label, perl = TRUE) && identical(mainType, "plain")) {
      for (j in seq_len(nArms))
        if (!is.null(armTok[[j]])) {
          armN[arms[j]] <- as.integer(armTok[[j]]$num1)
          # a PRINTED N outranks one recovered from n (%) cells or the
          # document text, and its provenance goes with it: the source
          # is cleared so the report and the parse score treat the arm
          # as printed (CodeRabbit on PR #351)
          armNSource[arms[j]] <- NA_character_
        }
      next
    }
    if (is.na(mainType)) next

    if (mainType == "medianRng") {
      # ---- Median with a bracketed interval (issue 18) --------------------
      # The app has accepted median/Q1/Q3 rows since issue 12 (metalog
      # null), so a "median [IQR]" row is DATA now, not a skip - the old
      # unconditional skip here predated that. But the interval's meaning
      # comes from the TEXT, never from the numbers: an IQR and a min-max
      # range both straddle the median, so they are numerically
      # indistinguishable, and feeding a range into the quartile-matched
      # metalog would be a correctness bug in a fraud-screening verdict.
      # Evidence is tiered: the row's own label outranks the table-level
      # text (caption + footnote), because one table can print IQR rows
      # and range rows side by side; ambiguity at both tiers skips.
      iqrPat <- "(?i)\\biqr\\b|inter-?quartile|quartile|\\bq1\\b|25th"
      rngPat <- paste0("(?i)\\brange\\b|min(imum)?\\s*[-–—]\\s*max",
                       "|\\bmin\\b\\s*[,/]?\\s*\\bmax\\b")
      # "interquartile RANGE" is an IQR statement, not a range statement -
      # remove the IQR phrases before testing for "range", or the common
      # footnote "median [interquartile range]" reads as both and skips
      dropIQR <- function(x) gsub("(?i)inter-?\\s?quartile\\s+range", "",
                                  x, perl = TRUE)
      capTxt <- if (capIdx >= 1) lineTexts[capIdx] else ""
      docTxt <- paste(c(capTxt, footnoteInfo), collapse = " ")
      rowIQR <- grepl(iqrPat, rawLabel, perl = TRUE)
      rowRng <- grepl(rngPat, dropIQR(rawLabel), perl = TRUE)
      docIQR <- grepl(iqrPat, docTxt, perl = TRUE)
      docRng <- grepl(rngPat, dropIQR(docTxt), perl = TRUE)
      verdict <- if (rowIQR && !rowRng)      "iqr"
                 else if (rowRng && !rowIQR) "range"
                 else if (rowIQR && rowRng)  "ambiguous"
                 else if (docIQR && !docRng) "iqr"
                 else if (docRng && !docIQR) "range"
                 else                        "ambiguous"
      if (verdict == "range") {
        addSkip(label, paste("median [range] - the analysis needs quartiles",
                             "(Q1/Q3), not the range"), txt)
        next
      }
      if (verdict == "ambiguous") {
        addSkip(label, paste("median with an unlabeled interval - if it is",
                             "an IQR, enter median/Q1/Q3 by hand"), txt)
        next
      }
      # verdict "iqr": emit median as MEAN plus Q1/Q3 (validateData()
      # reinterprets MEAN as the median when Q1/Q3 are filled). A cell
      # whose median falls outside its own interval is misread or
      # misprinted - refuse the row rather than emit it.
      bad <- vapply(armTok, function(t)
        !is.null(t) && t$type == "medianRng" && !is.na(t$num3) &&
          (t$num2 > t$num1 || t$num3 < t$num1), logical(1))
      if (any(bad)) {
        addSkip(label, "median outside its own [Q1, Q3] - check the cells",
                txt)
        next
      }
      # the tag itself often survives label cleaning ("Stay, median (IQR)"
      # loses only "(IQR)" to .ppCleanLabel) - strip the leftover
      medLabel <- .ppSquish(sub("(?i)[,;]?\\s*median\\s*([\\[(][^\\])]*[\\])])?\\s*$",
                                "", label, perl = TRUE))
      rowName <- .ppUniqueName(if (nchar(medLabel) > 0) medLabel
                               else if (nchar(label) > 0) label else "Unnamed",
                               usedRowNames)
      usedRowNames <- c(usedRowNames, rowName)
      catHeader <- NA_character_
      catHeaderPct <- FALSE
      perArm <- lapply(seq_len(nArms), function(j) {
        t <- armTok[[j]]
        if (is.null(t) || t$type != "medianRng" || is.na(t$num3)) return(NULL)
        list(N = armN[arms[j]], MEAN = t$num1, Q1 = t$num2, Q3 = t$num3,
             SD = NA_real_, SE = NA_real_,
             ROUND_MEAN = t$dec1,
             ROUND_DISPERSION = NA_integer_,
             ROUND_OBSERVATION = t$dec1 + roundObsDelta)
      })
      outRows[[length(outRows) + 1]] <-
        list(row = rowName, type = "median", perArm = perArm)
      next
    }
    # ---- Percent-block conversion (2026-08-21) ----------------------------
    # Three genres tabulate categorical data as bare percentages, found by
    # the AI comparison over the 654-submission corpus (~800 rows skipped):
    #   "Male 55%"                  - pctOnly cells
    #   "Race, %" then "Caucasian 47" - plain children under a % header
    #   "Gender (Male), % 47 44"    - a plain row whose own label says %
    # With a known arm N the printed percentage pins the count to the
    # integers consistent with its rounding (.ppCountFromPct); a cell is
    # converted ONLY when that bracket holds exactly one integer, so "47%"
    # of n = 40 becomes 19 while "47%" of n = 702 stays unconverted - a
    # fraud screen must not analyze approximated counts as printed ones.
    # Every converted row is recorded and reported by reviewFlags().
    rowSaysPct <- grepl("%", rawLabel, fixed = TRUE) ||
      grepl("(?i)\\bpercent", rawLabel, perl = TRUE)
    pctGenre <- mainType == "pctOnly" ||
      (mainType == "plain" &&
         ((!is.na(catHeader) && catHeaderPct) || rowSaysPct))
    pendingDerive <- NULL
    if (pctGenre) {
      present <- !vapply(armTok, is.null, logical(1))
      cnts   <- rep(NA_integer_, nArms)
      approx <- rep(FALSE, nArms)
      notes  <- rep(NA_character_, nArms)
      # THE FAIL-SAFE FILL (Steve's decision, 2026-09-07, after the GPT-6
      # audit's finding F3). For an arm above 100 (or above 1,000 at one
      # printed decimal) several counts share a printed percentage, and the
      # earlier approximation took the middle one - so two honest arms whose
      # percentages happened to round the same were rebuilt with IDENTICAL
      # proportions, an agreement the real counts never had: by exact
      # enumeration 38% of honest 5,000-per-arm pairs fell below p = 0.01.
      # An ambiguous cell is settled AFTER this loop, for the whole
      # arms-by-levels block at once, by .ppFailsafeTableFill() in
      # R/failsafeTable.R: every reading the page allows is enumerated
      # and scored with the engine's own statistic and null, and the one
      # with the LARGEST p is analysed - the best case for the authors.
      # Where the readings cannot all be enumerated the block is left
      # UNRESOLVED and its cells go blank, because a reading that cannot
      # be shown to be the best case is not one (Steve Shafer,
      # 2026-09-09: "Skip"). Either way the cell is painted its own
      # colour with the note below, so the editor sees a decision about
      # incomplete data rather than a datum, and the API's response flags
      # name the rows. Exact brackets (one integer) are untouched.
      lo <- rep(NA_integer_, nArms); hi <- rep(NA_integer_, nArms)
      # the PERCENTAGE each arm printed, kept here because the loop
      # below overwrites armTok[[j]]$num1 with the count it chose, and
      # the note built after that would otherwise quote the count where
      # it means to quote the percentage
      pctSeen <- rep(NA_real_, nArms)
      for (j in which(present)) {
        t <- armTok[[j]]
        if (!t$type %in% c("pctOnly", "plain")) next
        N <- armN[arms[j]]
        pctSeen[j] <- suppressWarnings(as.numeric(t$num1))
        b <- .ppCountBracket(t$num1, t$dec1, N)
        if (anyNA(b)) next
        if (b[1] == b[2]) {
          cnts[j]  <- b[1]
          notes[j] <- sprintf("%s%% of N=%d -> %d (uniquely pinned)",
                              format(t$num1), N, cnts[j])
        } else if (isTRUE(pctApprox)) {
          lo[j] <- b[1]; hi[j] <- b[2]; approx[j] <- TRUE
        }
      }
      if (any(approx)) {
        Ns  <- armN[arms]
        amb1 <- which(approx & is.na(cnts))
        # NOT A CHOICE YET. The counts that reach the analysis are
        # settled for the whole block after this loop; see the comment
        # above and R/failsafeTable.R.
        # A DETERMINISTIC PLACEHOLDER, not a choice. The counts that
        # reach the analysis are settled for the whole arms-by-levels
        # block after this loop, where the sibling levels are known;
        # this only has to be something so the line flows through the
        # emit below, and it is always either replaced there or blanked.
        # It used to be .ppFailsafeCounts(), the per-level rule - and
        # when the joint pass could not run, that rule's answer silently
        # became the analysis (audit 2026-09-09, F1). The low end of the
        # bracket carries no claim and cannot be mistaken for one.
        cnts[amb1] <- lo[amb1]
        for (j in which(approx))
          notes[j] <- sprintf(
            "FAIL-SAFE: %s%% of N=%d fits %d..%d; %d taken - the reading of the page that leaves the arms least alike",
            format(armTok[[j]]$num1), as.integer(Ns[j]), lo[j], hi[j], cnts[j])
      }
      if (any(present) && !any(is.na(cnts[present]))) {
        for (j in which(present)) {
          armTok[[j]]$num1 <- cnts[j]
          armTok[[j]]$type <- "plain"
        }
        # The "%" in the label described the notation just converted
        # away; drop it so the category column is named "Diabetes", not
        # "Diabetes, %".
        label <- .ppCleanLabel(sub(
          "(?i)\\s*[,;]?\\s*\\(?\\s*(%|percent(age)?s?)\\s*\\)?\\s*$",
          "", label, perl = TRUE))
        shown <- if (nchar(label) > 0) label else catHeader
        if (any(approx[present])) pctApproxRows <- c(pctApproxRows, shown)
        else                      pctDerived    <- c(pctDerived, shown)
        # Remembered until the branch below knows the column names it
        # created; consumed there into $derivedCells for the app grid.
        pendingDerive <- list(
          kind = if (any(approx[present])) "failsafe" else "unique",
          # the name this line contributed to pctApproxRows above (F2)
          shown = shown,
          note = paste(notes[present][!is.na(notes[present])],
                       collapse = "; "),
          # the bracket ends and the printed percentage, per arm, NA
          # where this arm's cell was pinned or absent; consumed with
          # the note below and settled jointly after the loop
          lo = lo, hi = hi,
          pct = pctSeen)
        # Children of a category header accumulate into its row as counts;
        # a standalone percent row is a binary category with a complement,
        # exactly like a printed "n (%)" cell.
        mainType <- if (!is.na(catHeader)) "plain" else "nPct"
      } else {
        addSkip(if (nchar(label) > 0) label else txt,
                paste("percent only - needs the arm N, and the printed",
                      "percent must pin a unique count (or pctApprox =",
                      "TRUE); enter by hand"), txt)
        next
      }
    }

    if (mainType == "numParen") {
      labelSaysPct    <- grepl("(?i)\\(%\\)|percent", rawLabel, perl = TRUE)
      # A wrapped row label can leave its "N (%)" tag on the NEXT line
      # ("Nonsteroidal anti-inflammatory  4 (11) ..." with "drugs,
      # N (%)" beneath it): the continuation is a label-kind line, and
      # its tag is this row's notation evidence (vocacapsaicin corpus,
      # 2026-08-22).
      nextLabelPct <- i < length(kind) && kind[i + 1] == "label" &&
        grepl("(?i)\\b(no?|n)\\.?\\s*\\(\\s*%\\s*\\)", lineTexts[i + 1],
              perl = TRUE)
      labelContinuous <- grepl(continuousKeyword, label, perl = TRUE)
      # THE NUMBERS THEMSELVES CAN SAY "n (%)" (2026-09-24, Loadsman
      # corpus, Akkaya 2015 EJA). A table of counts and percentages with
      # no "%" anywhere - no "(%)" in a label, no "n (%)" header, a
      # footnote silent on notation - reads "18 (90)" as a mean of 18
      # with an SD of 90, and 31 of that paper's 48 rows went to the
      # engine as continuous variables whose SD exceeded their mean. But
      # a count with its percentage has a signature no mean (SD) pair
      # has: the second number IS the first, as a percentage of the
      # arm's N, at the printed precision, in every arm. Two cells of
      # one row agreeing on that by chance would need a genuine SD to
      # equal 100 x mean / N to the printed decimal in each arm - so
      # when every cell of the row that has a value satisfies it, at
      # least two do, and at least one count is nonzero, the row is
      # counts. Only whole, in-range first numbers qualify; an arm with
      # no N cannot vouch and disqualifies the row from this rule (the
      # vocabulary rules below still apply). Checked ahead of the label
      # rules because it is evidence from the cells, not from the words.
      #
      # HOW MUCH EVIDENCE IS ENOUGH (misparse measurement, 2026-09-24).
      # At integer precision the identity is loose - any SD within 0.5
      # of 100 x mean / N passes - and two arms that print the same
      # values are one check, not two: "Age 43 (15)" in arms of 280 and
      # 279 (100 x 43 / 280 = 15.4) read as counts and lost a genuine
      # mean (SD) row (PMID 16792606). So the cells are counted as
      # DISTINCT (count, bracket, N) tuples, and the row needs three of
      # them at integer precision, two when the bracketed number carries
      # a decimal (a tolerance of 0.05 is ten times as sharp). A
      # two-arm integer table with no "%" anywhere is left to the
      # vocabulary rules and, if it is mostly SD > MEAN, to the review
      # flag; Akkaya's twelve arms pass with room to spare.
      cellsSayPct <- local({
        sig <- character(0); nz <- 0L; minDec <- Inf
        for (j in seq_len(nArms)) {
          t <- armTok[[j]]
          if (is.null(t) || !identical(t$type, "numParen")) next
          Nj <- armN[arms[j]]
          if (is.na(Nj) || Nj <= 0 || is.na(t$num1) || is.na(t$num2) ||
              t$num1 %% 1 != 0 || t$num1 < 0 || t$num1 > Nj) return(FALSE)
          dec2 <- if (is.na(t$dec2)) 0 else t$dec2
          tol <- 0.5 * 10^-dec2 + 1e-9
          if (abs(t$num2 - 100 * t$num1 / Nj) > tol) return(FALSE)
          sig <- c(sig, paste(t$num1, t$num2, Nj))
          minDec <- min(minDec, dec2)
          if (t$num1 > 0) nz <- nz + 1L
        }
        need <- if (is.finite(minDec) && minDec >= 1) 2L else 3L
        length(unique(sig)) >= need && nz >= 1L
      })
      decision <-
        if (parenIsSD == "sd") "sd"
        else if (parenIsSD == "percent") "percent"
        else if (cellsSayPct) "percent"
        else if (labelSaysPct || nextLabelPct) "percent"
        # Under an open "N (%)" block header ("Race, N (%)"), an "a (b)"
        # child is a count and its percentage, whatever the footnote says
        # about means - the block header is CLOSER evidence than the
        # table-level footnote. Without this, "White 12 (33)" became a
        # mean of 12 with an SD of 33 because the footnote also said
        # "mean (SD)" (vocacapsaicin corpus, 2026-08-22).
        else if (!is.na(catHeader) && catHeaderNPct) "percent"
        else if (labelContinuous || footSaysMeanSD) "sd"
        else if (tableHasPlusMinus) "percent"
        else if (footSaysPercent) "percent"
        else "sd"
      mainType <- if (decision == "sd") "meanSD" else "nPct"
      if (parenIsSD == "auto" && cellsSayPct)
        say("  \"", label, "\": read \"a (b)\" as n (%) - in every arm the ",
            "bracketed number is the first as a percentage of the arm N.")
      else if (parenIsSD == "auto" && !labelSaysPct && !labelContinuous)
        say("  \"", label, "\": read \"a (b)\" as ",
            if (decision == "sd") "mean (SD)" else "n (%)",
            " - check, or set parenIsSD.")
    }

    # Children of an "N (%)" block header are the levels of ONE category
    # variable: accumulate them as counts under that header (the plain
    # branch below) rather than emitting a separate binary category -
    # with a double-counting complement - per level. A row announcing
    # its OWN "n (%)" in its label is a standalone binary variable even
    # while a block is open.
    if (mainType == "nPct" && !is.na(catHeader) && catHeaderNPct &&
        !grepl("(?i)\\(\\s*%\\s*\\)|percent", rawLabel, perl = TRUE))
      mainType <- "plain"

    if (mainType == "meanSD") {
      # A trailing stat tag on a NAMED variable - "Age (years)-Mean
      # (SD)", "Weight, mean" - is notation, not name: strip it so this
      # path names rows the way the wide-spreadsheet parser does
      # ("Age (years)", not "Age (years)-Mean"). The tag must FOLLOW a
      # separator, so a label that IS the tag ("Mean", for the statRow
      # rule below) and one that merely starts with the word ("Mean
      # age (SD), yr" - the published vocacapsaicin wording) are both
      # untouched. .ppCleanLabel has already removed a trailing "(SD)"
      # parenthetical; the plus-minus alternative covers "mean +/- SD"
      # it leaves behind (2026-08-25).
      label <- .ppSquish(sub(
        paste0("(?i)[\\s,;\u2013\u2014-]+mean",
               "(\\s*\\(\\s*sd\\s*\\)|\\s*\u00b1\\s*sd)?\\s*$"),
        "", label, perl = TRUE))
      # A first-arm cell the tokenizer could not read - "20l +/- 40", the
      # digit 1 set as a letter l (PMID 12182258) - leaves its unread
      # half in the label: "Duration of anesthesia, min 20l +/-". The
      # trailing "<word> +/-" is not part of any name; the arm's value is
      # lost either way, and the row keeps its readable arms (issue 44).
      label <- .ppSquish(sub("\\s+\\S+\\s*\u00b1\\s*$", "", label, perl = TRUE))
      # A row labelled just "Mean" / "Mean (SD)" is a summary-statistic
      # line under a variable heading ("Weight (kg)" sits on the line
      # above): the variable's name is that heading, and the heading
      # stays OPEN for the Median line that customarily follows
      # (vocacapsaicin corpus, 2026-08-22).
      statRow <- !is.na(catHeader) &&
        grepl("(?i)^mean\\b", label, perl = TRUE)
      rowName <- .ppUniqueName(
        if (statRow) catHeader
        else if (nchar(label) > 0) label else "Unnamed", usedRowNames)
      usedRowNames <- c(usedRowNames, rowName)
      if (!statRow) {
        catHeader <- NA_character_
        catHeaderPct <- FALSE
        catHeaderNPct <- FALSE
      }
      # A row label may override the table-level footnote: "Age, mean (SEM)"
      rowSaysSE <- grepl(seWord, rawLabel, perl = TRUE)
      rowSaysSD <- grepl("(?i)\\bs\\.?d\\.?\\b|standard\\s+deviation",
                         rawLabel, perl = TRUE)
      isSE <- if (rowSaysSE && !rowSaysSD) TRUE
              else if (rowSaysSD) FALSE
              else footSaysSE && !footSaysSD

      perArm <- lapply(seq_len(nArms), function(j) {
        t <- armTok[[j]]
        if (is.null(t) || !t$type %in% c("meanSD", "numParen")) return(NULL)
        list(N = armN[arms[j]], MEAN = t$num1,
             SD = if (isSE) NA_real_ else t$num2,
             SE = if (isSE) t$num2 else NA_real_,
             ROUND_MEAN = t$dec1,
             ROUND_DISPERSION = t$dec2,
             ROUND_OBSERVATION = t$dec1 + roundObsDelta)
      })
      outRows[[length(outRows) + 1]] <-
        list(row = rowName, type = "continuous", perArm = perArm)

    } else if (mainType == "fraction") {
      catHeader <- NA_character_
      catHeaderPct <- FALSE
      catHeaderNPct <- FALSE
      nParts <- max(vapply(armTok, function(t)
        if (is.null(t)) 0L else length(strsplit(t$text, "/")[[1]]), integer(1)))
      partNames <- NULL
      m <- regmatches(rawLabel, regexpr("\\(([^()]*/[^()]*)\\)", rawLabel))
      if (length(m) > 0) {
        partNames <- strsplit(gsub("[()]", "", m), "\\s*/\\s*")[[1]]
        label <- .ppCleanLabel(sub("\\(([^()]*/[^()]*)\\)", "", rawLabel))
      } else {
        m2 <- regmatches(rawLabel,
                         regexpr("[A-Za-z]+(\\s*/\\s*[A-Za-z]+)+\\s*[,:]?\\s*$",
                                 rawLabel))
        if (length(m2) > 0) {
          partNames <- strsplit(.ppSquish(m2), "\\s*/\\s*")[[1]]
          label <- .ppCleanLabel(sub("[A-Za-z]+(\\s*/\\s*[A-Za-z]+)+\\s*[,:]?\\s*$",
                                     "", rawLabel))
        }
      }
      if (is.null(partNames) || length(partNames) != nParts) {
        if (nParts == 2 && grepl("(?i)sex|gender", label, perl = TRUE))
          partNames <- c("Male", "Female")
        else
          partNames <- paste(label, seq_len(nParts))
      }
      if (grepl("(?i)sex|gender", label, perl = TRUE) && length(partNames) == 2) {
        partNames[toupper(partNames) %in% c("M", "MALE")]   <- "Male"
        partNames[toupper(partNames) %in% c("F", "FEMALE")] <- "Female"
      }
      partNames <- ifelse(nchar(partNames) <= 3 & !partNames %in% c("Male", "Female"),
                          paste(label, partNames), partNames)
      # never a spelling the normaliser reads as a header (.iaSafeColumnName)
      partNames <- vapply(.iaSafeColumnName(partNames), .ppUniqueName, character(1),
                          existing = setdiff(catColumns, partNames))
      catColumns <- unique(c(catColumns, partNames))
      rowName <- .ppUniqueName(if (nchar(label) > 0) label else "Category",
                               usedRowNames)
      usedRowNames <- c(usedRowNames, rowName)
      perArm <- lapply(seq_len(nArms), function(j) {
        t <- armTok[[j]]
        if (is.null(t) || t$type != "fraction") return(NULL)
        counts <- as.integer(strsplit(gsub("\\s", "", t$text), "/")[[1]])
        stats::setNames(as.list(counts), partNames[seq_along(counts)])
      })
      outRows[[length(outRows) + 1]] <-
        list(row = rowName, type = "category", perArm = perArm)

    } else if (mainType == "nPct") {
      # The variable's name: the row label; failing that, an open block
      # header (a bare "N (%)" label under "NSAID use" names the NSAID
      # variable, not "Category"); failing both, "Category".
      # the variable's printed name is the ROW label as printed; only the
      # COLUMN spelling is sanitised (.iaSafeColumnName), so the row still
      # matches what the model calls it in the hybrid merge (CodeRabbit on
      # PR #336)
      varName <- if (nchar(label) > 0) label
        else if (!is.na(catHeader)) catHeader else "Category"
      catName <- .ppUniqueName(.iaSafeColumnName(varName), catColumns)
      catHeader <- NA_character_
      catHeaderPct <- FALSE
      catHeaderNPct <- FALSE
      complementName <- .ppUniqueName(paste("Not", catName),
                                      c(catColumns, catName))
      # The N requirement is ROW-LOCAL: only the arms this row actually
      # has cells in need a known N for the complement. Requiring an N
      # for every cluster let one stray cluster (a superscript exponent,
      # a watermark) veto every n (%) row in the table (vocacapsaicin
      # corpus, 2026-08-22).
      present <- !vapply(armTok, is.null, logical(1))
      haveN <- any(present) && all(!is.na(armN[arms[present]]))
      catColumns <- unique(c(catColumns, catName, if (haveN) complementName))
      rowName <- .ppUniqueName(varName, usedRowNames)
      usedRowNames <- c(usedRowNames, rowName)
      if (haveN)
        say("  \"", label, "\": binary n (%) row - complement column \"",
            complementName, "\" computed as arm N minus the count.")
      else
        addSkip(label, paste("n (%) with unknown arm N - complement category",
                             "cannot be computed; edit by hand"), txt)
      perArm <- lapply(seq_len(nArms), function(j) {
        t <- armTok[[j]]
        if (is.null(t)) return(NULL)
        # a mixed row may print a bare count in one arm ("0") among the
        # n (%) cells; a non-integer bare cell is not a count
        if (t$type == "plain" &&
            (is.na(t$num1) || t$num1 != round(t$num1))) return(NULL)
        cnt <- as.integer(t$num1)
        out <- stats::setNames(list(cnt), catName)
        if (haveN) out[[complementName]] <- armN[arms[j]] - cnt
        out
      })
      # A binary "n (%)" row is a two-level table in its own right, and
      # its counts are chosen the same way (2026-09-08). The complement
      # is not free: it is the arm N minus the count, so its bracket is
      # the count's bracket reflected, and the sum-to-N constraint below
      # ties the pair together. Recording it under a key of its own
      # keeps it out of any category BLOCK, which merges by header.
      npctKey <- paste0("__npct__", rowName)
      if (!is.null(pendingDerive)) {
        addDerived(rowName, catName, pendingDerive$kind, pendingDerive$note)
        if (haveN)
          addDerived(rowName, complementName, pendingDerive$kind,
                     "complement: arm N minus the derived count")
        if (identical(pendingDerive$kind, "failsafe") && haveN &&
            !is.null(pendingDerive$lo)) {
          armSize <- armN[arms]
          pctBrackets[[npctKey]] <- list()
          pctApproxByBlock[[npctKey]] <-
            unique(c(pctApproxByBlock[[npctKey]], pendingDerive$shown))
          pctBrackets[[npctKey]][[catName]] <-
            list(lo = pendingDerive$lo, hi = pendingDerive$hi,
                 pct = pendingDerive$pct)
          pctBrackets[[npctKey]][[complementName]] <-
            list(lo = as.integer(armSize - pendingDerive$hi),
                 hi = as.integer(armSize - pendingDerive$lo),
                 pct = 100 - pendingDerive$pct)
        }
      }
      outRows[[length(outRows) + 1]] <-
        list(row = rowName, type = "category", perArm = perArm, key = npctKey)

    } else if (mainType == "plain") {
      # "Median  71.9  82.3 ..." is a summary statistic, not counts, and
      # without quartiles it is unusable either way. Skipped with its own
      # reason, and the variable heading above it stays OPEN - the next
      # line may be the same variable's Mean or IQR (vocacapsaicin
      # corpus, 2026-08-22).
      if (grepl("(?i)^median\\b", label, perl = TRUE)) {
        addSkip(if (nchar(label) > 0 && is.na(catHeader)) label
                else paste(c(catHeader[!is.na(catHeader)], label),
                           collapse = " "),
                paste("median without quartiles - enter median/Q1/Q3 by",
                      "hand if an IQR is printed"), txt)
        next
      }
      # "Range 33-57 34-63 ..." under a variable heading is the spread of
      # the "Mean +/- SD" line above it, not the counts of a level (issue
      # 44): taken as counts it became a category row named "<heading> 2"
      # with the range's endpoints as its cells. Skipped with its reason;
      # the heading stays open for the variable's remaining lines.
      if (grepl("(?i)^(range|min(imum)?\\s*[-\u2013/]\\s*max(imum)?)$", label, perl = TRUE)) {
        addSkip(paste(c(catHeader[!is.na(catHeader)], label), collapse = " "),
                "range without mean or SD - the analysis needs mean and SD", txt)
        next
      }
      if (!is.na(catHeader)) {
        # as.integer() would silently truncate a stray "71.9" into a
        # count of 71 - any non-integer cell refuses the whole row
        nonInt <- vapply(armTok, function(t)
          !is.null(t) && !is.na(t$num1) && t$num1 != round(t$num1),
          logical(1))
        if (any(nonInt)) {
          addSkip(if (nchar(label) > 0) label else catHeader,
                  paste("non-integer values under a category heading -",
                        "not counts; enter by hand"), txt)
          next
        }
        # A level has a name. Counts on a line with no label under a
        # heading were filed as a level called "Category" - on the OCR of
        # CJA 1995;42:1096 the figure axis under the table ("30", "20",
        # "10") became three levels of a heading "Sr" (issue 46). Skipped
        # with the heading named, so a reviewer can look at the page.
        if (nchar(label) == 0) {
          addSkip(catHeader, paste("bare numbers under the heading with no level",
                                   "name - not a level; enter by hand if the page",
                                   "names one"), txt)
          next
        }
        # ... and an UNREADABLE name is not a level either: ". T" (what an
        # axis tick line leaves once its numbers are dropped) or the
        # fifty-character OCR of the next table's caption. A level name is
        # a word or a band: letters make up at least half of what it
        # prints, or it has none ("<65", "0-1", a numeric ASA class) or is
        # a roman numeral ("I", "IIb"); and it is forty characters or
        # fewer (issue 46).
        if (.ppUnreadableLevel(label)) {
          addSkip(paste(catHeader, label),
                  "unreadable level name (OCR noise) - enter by hand if the page names one",
                  txt)
          next
        }
        catName <- .ppUniqueName(.iaSafeColumnName(label), catColumns)
        catColumns <- unique(c(catColumns, catName))
        key <- paste0("__cat__", catHeader)
        existing <- which(vapply(outRows, function(r) identical(r$key, key),
                                 logical(1)))
        counts <- lapply(seq_len(nArms), function(j) {
          t <- armTok[[j]]
          if (is.null(t)) NULL else stats::setNames(list(as.integer(t$num1)), catName)
        })
        if (length(existing) == 0) {
          rowName <- .ppUniqueName(catHeader, usedRowNames)
          usedRowNames <- c(usedRowNames, rowName)
          outRows[[length(outRows) + 1]] <-
            list(row = rowName, type = "category", perArm = counts, key = key)
        } else {
          e <- existing[1]
          rowName <- outRows[[e]]$row
          for (j in seq_len(nArms))
            if (!is.null(counts[[j]]))
              outRows[[e]]$perArm[[j]] <- c(outRows[[e]]$perArm[[j]], counts[[j]])
        }
        if (!is.null(pendingDerive)) {
          addDerived(rowName, catName, pendingDerive$kind, pendingDerive$note)
          if (identical(pendingDerive$kind, "failsafe") &&
              !is.null(pendingDerive$lo)) {
            if (is.null(pctBrackets[[key]])) pctBrackets[[key]] <- list()
            pctApproxByBlock[[key]] <-
              unique(c(pctApproxByBlock[[key]], pendingDerive$shown))
            pctBrackets[[key]][[catName]] <-
              list(lo = pendingDerive$lo, hi = pendingDerive$hi,
                   pct = pendingDerive$pct)
          }
        }
      } else {
        addSkip(label, "bare number with no category header and no SD - not usable",
                txt)
      }
    }
  }

  # The rows of a stratum carry its name (issue 55). A name .ppUniqueName()
  # had to suffix because an earlier stratum already used it ("Age, y 2")
  # takes its base back: the prefix now tells the two apart.
  if (length(stratumStarts) && length(outRows)) {
    earlier <- character(0)
    bounds  <- c(vapply(stratumStarts, function(s) s$at, integer(1)), length(outRows))
    if (bounds[1] > 0) earlier <- vapply(outRows[seq_len(bounds[1])], function(r) r$row, character(1))
    for (k in seq_along(stratumStarts)) {
      idx <- seq_len(length(outRows))
      idx <- idx[idx > bounds[k] & idx <= bounds[k + 1]]
      for (r in idx) {
        nm   <- outRows[[r]]$row
        base <- sub("\\s+\\d+$", "", nm)
        if (base != nm && base %in% earlier) nm <- base
        outRows[[r]]$row <- paste0(stratumStarts[[k]]$name, ": ", nm)
      }
      earlier <- c(earlier, vapply(outRows[idx], function(r) sub("\\s+\\d+$", "", sub("^.*?: ", "", r$row)), character(1)))
    }
  }
  if (length(outRows) == 0) return(NULL)

  # ---- THE JOINT FAIL-SAFE FILL -------------------------------------------
  # Every level of the variable is now known, so the counts behind its
  # printed percentages can be chosen the way P_Calc will read them: as
  # one arms-by-levels table, with each arm's counts summing to that
  # arm's N. .ppFailsafeTableFill() enumerates the admissible tables,
  # scores each with the engine's own statistic and null, and returns
  # the BEST CASE - the largest p, the reading most favourable to the
  # authors (Steve Shafer's decision, 2026-09-08). The smallest p comes
  # back beside it, and when the two fall on opposite sides of p = 0.01
  # the block is named so the app and the flags can say that the choice
  # decided the answer.
  #
  # Until this pass existed the levels were chosen one line at a time,
  # each maximising its own statistic against its own complement. That
  # drove every level the same way in the same arm, which left the arms
  # in identical proportions - the most homogeneous reading, not the
  # least - and let an arm of 200 be rebuilt as 203. R/failsafeTable.R
  # carries the measurements.
  if (length(pctBrackets)) {
    Ns <- armN[arms]
    for (bk in names(pctBrackets)) {
      e <- which(vapply(outRows, function(r) identical(r$key, bk), logical(1)))
      if (!length(e)) next
      e <- e[1]
      # every level of the block, not only the ambiguous ones: a level
      # printed as a count constrains the arm total just as much
      cols <- unique(unlist(lapply(outRows[[e]]$perArm, names)))
      if (length(cols) < 2) next
      lo <- hi <- cnt <- matrix(NA_integer_, nArms, length(cols),
                                dimnames = list(NULL, cols))
      for (j in seq_len(nArms)) {
        v <- outRows[[e]]$perArm[[j]]
        if (is.null(v)) next
        for (k in seq_along(cols))
          if (!is.null(v[[cols[k]]])) cnt[j, k] <- as.integer(v[[cols[k]]])
      }
      b <- pctBrackets[[bk]]
      for (k in seq_along(cols)) {
        bb <- b[[cols[k]]]
        if (is.null(bb)) next
        lo[, k] <- as.integer(bb$lo); hi[, k] <- as.integer(bb$hi)
        # the per-line rule already wrote a count into these cells; drop
        # it, so the joint pass chooses them rather than inheriting a
        # choice made against the wrong statistic
        cnt[!is.na(bb$lo), k] <- NA_integer_
      }
      amb <- is.na(cnt) & !is.na(lo) & !is.na(hi)
      if (!any(amb)) next
      lo[!amb] <- cnt[!amb]; hi[!amb] <- cnt[!amb]
      usable <- which(is.finite(Ns) & Ns > 0 &
                      rowSums(is.na(lo) | is.na(hi)) == 0)
      rowName <- outRows[[e]]$row
      # DO THE LEVELS DIVIDE THE ARM? Only where this code built the
      # complement itself - a binary "n (%)" row, whose other column IS
      # the arm N minus the count. It is never inferred from the printed
      # percentages (independent audit 2026-09-09, F2). The old test
      # asked whether the bracket midpoints summed to within 2% of N,
      # which treats arithmetic as evidence about what the categories
      # MEAN: a page printing 24/24/24/26 and the footnote "Other
      # categories omitted" was rebuilt as a complete partition summing
      # to N in both arms, and read p = 0.00003 where the honest reading
      # with the omitted category gives 0.064. The reverse error was
      # there too - honest counts summing to N but printing 97% were
      # called non-exhaustive. Without the constraint the admissible set
      # is larger and more rows go unresolved, which is the trade Steve
      # Shafer chose: a reading we cannot certify is worse than no
      # reading.
      partition <- startsWith(bk, "__npct__")
      res <- if (length(usable) < 2)
               list(resolved = FALSE,
                    reason = "fewer than two arms report this variable")
             else .ppFailsafeTableFill(lo[usable, , drop = FALSE],
                                       hi[usable, , drop = FALSE],
                                       cnt[usable, , drop = FALSE],
                                       Ns[usable], partition = partition)
      if (!isTRUE(res$resolved)) {
        # UNRESOLVED: put the ambiguous cells back to blank rather than
        # leave a count nothing stands behind. The engine refuses a
        # category row with a missing cell by name, and every refusal is
        # counted on the Summary's "k of n rows analysed" line, so the
        # editor sees the gap and can type the counts in.
        for (j in seq_len(nArms))
          for (k in seq_along(cols))
            if (amb[j, k] && !is.null(outRows[[e]]$perArm[[j]]) &&
                !is.null(outRows[[e]]$perArm[[j]][[cols[k]]]))
              outRows[[e]]$perArm[[j]][[cols[k]]] <- NA_integer_
        pctUnresolved <- c(pctUnresolved,
                           stats::setNames(res$reason, rowName))
        # AND THE FAIL-SAFE CLAIM IS RETRACTED (security screen
        # 2026-09-09-0721, F2). The per-line pass records every ambiguous
        # row in pctApproxRows before this joint pass runs, and nothing
        # took it back out - so a document whose block could not be
        # enumerated produced BOTH "the reading with the LARGEST p was
        # taken, giving the authors the benefit of the doubt" and "could
        # NOT be read as counts and are left blank", about the same block,
        # in the same response. The first is false: those cells are NA and
        # the row is not analysed.
        #
        # It is NOT `rowName` that has to be removed. The per-line pass
        # appends the LEVEL's own label - "I", "II", "III" - while this
        # pass names the block by its header, "ASA physical status", so
        # a setdiff on rowName would have removed nothing and left the
        # false flag standing. The names are therefore carried per block,
        # beside the brackets that key it.
        #
        # AND THE RETRACTION IS RECORDED, NOT APPLIED HERE (security
        # screen 2026-09-09-1532, F3). Subtracting this block's labels
        # from the shared list removed them WHEREVER THEY CAME FROM, and
        # two blocks in one table share labels as a matter of course -
        # an ASA class and an NYHA class both print I / II / III. One
        # block declining then silently cancelled the other block's
        # fail-safe warning while its reconstructed counts were still
        # analysed: the false claim this branch exists to retract, turned
        # into a false NEGATIVE in the same direction that favours the
        # author. Which blocks declined is remembered, and the surviving
        # claims are worked out once, at the end.
        pctDeclinedBlocks <- c(pctDeclinedBlocks, bk)
        addSkip(rowName, paste("percentages could not be read as counts -",
                               res$reason,
                               "- enter the printed counts by hand"), "")
        for (k in seq_along(cols)) {
          hit <- vapply(derivedCells, function(d)
            isTRUE(unname(d$ROW) == unname(rowName)) &&
            isTRUE(unname(d$COL) == unname(cols[k])) &&
            isTRUE(unname(d$KIND) == "failsafe"), logical(1))
          # ONE REASON, THE REAL ONE (security screen 2026-09-09-0721, F6).
          # The first %s was the literal "the page allows more readings
          # than can be enumerated", and .ppFailsafeTableFill() returns
          # five other reasons - a cell with no bracket, one arm alone
          # over the bound, fewer than two arms reporting, more distinct
          # nulls than can be scored, no scorable reading at all. For
          # every one of those the editor's note asserted an enumeration
          # overflow that had not happened and then contradicted itself
          # with the true reason in the same sentence.
          for (h in which(hit)) derivedCells[[h]]$NOTE <- sprintf(
            paste("UNRESOLVED: %s. The printed percentages fit several",
                  "counts here, so no reading can be shown to be the best",
                  "case for the authors. The cell is left blank and the",
                  "row is not analysed; enter the printed counts to",
                  "analyse it."),
            res$reason)
        }
        next
      }
      for (u in seq_along(usable)) {
        j <- usable[u]
        for (k in seq_along(cols)) {
          if (!amb[j, k] || is.na(res$counts[u, k])) next
          outRows[[e]]$perArm[[j]][[cols[k]]] <- as.integer(res$counts[u, k])
        }
      }
      if (isTRUE(res$straddles)) pctStraddle <- c(pctStraddle, rowName)
      # WHERE THE CHOSEN COUNTS DO NOT ADD UP TO THE ARM, say so. Since
      # exhaustivity is no longer inferred (audit 2026-09-09, F2), the
      # search is free to take a reading whose levels total more or less
      # than N - which is right when the page never said the categories
      # were exhaustive, and wrong if they were. The editor is the one
      # who can tell by looking at the table, so the totals are put in
      # front of them rather than silently accepted or silently refused.
      armTotal <- rowSums(res$counts, na.rm = TRUE)
      offBy <- which(abs(armTotal - Ns[usable]) > 0.5)
      totalNote <- if (length(offBy))
        sprintf(paste(". These counts total %s for arm(s) of N = %s: the",
                      "page does not say whether these categories are",
                      "exhaustive, so readings that do not add up to the",
                      "arm are admitted. If they ARE exhaustive, the",
                      "printed counts settle it"),
                paste(armTotal[offBy], collapse = "/"),
                paste(as.integer(Ns[usable][offBy]), collapse = "/"))
      else ""
      # the hover note now says what was actually done
      for (k in seq_along(cols)) {
        bb <- b[[cols[k]]]
        if (is.null(bb)) next
        txtNote <- character(0)
        for (u in seq_along(usable)) {
          j <- usable[u]
          if (!amb[j, k]) next
          txtNote <- c(txtNote, sprintf(
            "%s%% of N=%d fits %d..%d; %d taken",
            format(bb$pct[j]), as.integer(Ns[j]),
            as.integer(bb$lo[j]), as.integer(bb$hi[j]),
            as.integer(res$counts[u, k])))
        }
        if (!length(txtNote)) next
        # WHAT THIS SENTENCE MAY CLAIM (security screens 2026-09-08-2100
        # and 2026-09-09-0721, F1). Every reading is still ENUMERATED -
        # that half is exact - but they are no longer all SCORED: the
        # readings are ordered by how alike the arms are, and the
        # simulation is spent at the two ends, because a middling reading
        # can be neither the best case nor the worst. Saying "scored"
        # of all of them would be the same kind of false guarantee the
        # 2026-09-09 audit removed from the trial-p claim.
        tail <- sprintf(
          paste("FAIL-SAFE (best case): %s. All %s readings this page",
                "allows were enumerated, and the %s at each extreme were",
                "scored; the one analysed is the one with the LARGEST p,",
                "so the arms are given every benefit of the doubt.",
                "Best case p ~ %.3g; worst case p %s%s"),
          paste(txtNote, collapse = "; "),
          format(res$nTables, big.mark = ","),
          # PER END, because that is what "at each extreme" says (security
          # screen 2026-09-10-0536, F3). The previous screen's observation
          # was that this number was recomputed here rather than taken from
          # the fill; taking res$nScored instead was wrong in the other
          # direction, because nScored counts the union of BOTH ends - 51,
          # 68, 81, even 100 where 50 are scored at each - so the sentence
          # overstated how much of the page had been searched, by up to
          # twice. The engine spends min(nNulls, .ppTableRankMax) at each
          # end, and that expression is right in both regimes: below the
          # cap the two ends are the same full set.
          format(min(res$nNulls, .ppTableRankMax), big.mark = ","),
          res$pBest,
          # an inequality when the worst case is the Monte Carlo floor
          # rather than an estimate (security screen 2026-09-08-2100, F5)
          sprintf(if (isTRUE(res$worstAtFloor)) "< %.3g" else "~ %.3g",
                  res$pWorst),
          paste0(if (isTRUE(res$straddles))
                   " - the choice moves this row across p = 0.01" else "",
                 totalNote))
        # compared by VALUE, not identical(): .ppUniqueName() returns a
        # named character, and identical() counts the name, so the
        # match silently found nothing and the hover note kept
        # describing a choice that was no longer the one made
        hit <- vapply(derivedCells, function(d)
          isTRUE(unname(d$ROW) == unname(rowName)) &&
          isTRUE(unname(d$COL) == unname(cols[k])) &&
          isTRUE(unname(d$KIND) == "failsafe"), logical(1))
        for (h in which(hit)) derivedCells[[h]]$NOTE <- tail
      }
    }
  }

  # ---- Assemble the template-format data frame ----------------------------
  # Q1/Q3 appear only when a median row was actually emitted (issue 18):
  # they are not part of the .ppBaseColumns() contract, and adding two
  # always-empty columns to every parse would clutter the app grid - the
  # AI path (.ppAiToTemplate) and the hybrid merge index by
  # .ppBaseColumns() and tolerate extras, but not missing base columns.
  anyMedian <- any(vapply(outRows, function(r)
    identical(r$type, "median"), logical(1)))
  allCols <- c(.ppBaseColumns(), if (anyMedian) c("Q1", "Q3"), catColumns)
  rows <- list()
  for (r in outRows) {
    for (j in seq_len(nArms)) {
      v <- r$perArm[[j]]
      if (is.null(v)) next
      line <- stats::setNames(as.list(rep(NA, length(allCols))), allCols)
      line$TRIAL <- trial
      line$ROW   <- r$row
      if (r$type == "continuous") {
        line$N <- v$N; line$MEAN <- v$MEAN
        line$SD <- v$SD; line$SE <- v$SE
        line$ROUND_MEAN <- v$ROUND_MEAN
        line$ROUND_DISPERSION <- v$ROUND_DISPERSION
        line$ROUND_OBSERVATION <- v$ROUND_OBSERVATION
      } else {
        for (nm in names(v)) line[[nm]] <- v[[nm]]
      }
      rows[[length(rows) + 1]] <- line
    }
  }
  DATA <- do.call(rbind, lapply(rows, function(l)
    as.data.frame(l, check.names = FALSE, stringsAsFactors = FALSE)))

  skippedDf <- if (length(skipped) > 0) do.call(rbind, skipped) else
    data.frame(label = character(0), reason = character(0), text = character(0))

  # An "arm" that received neither an N nor a single data cell is not an
  # arm - it is a label-column word swept into the clustering (wide
  # manuscript tables put header text far left of the first value column).
  # Drop it from the report; no data line ever referenced it. The raw
  # cluster count is kept for the parse score, where an implausible number
  # of clusters is evidence of a mangled reading (2026-08-20).
  used <- vapply(seq_len(nArms), function(j)
    any(vapply(outRows, function(r)
      length(r$perArm) >= j && !is.null(r$perArm[[j]]), logical(1))),
    logical(1))
  # ... and an arm that has an N but neither a name nor a single data
  # cell is a phantom too (issue 48): once "Number 15 15 15 15" was read
  # as the N row, a fifth cluster on CJA 1996;43:362 - no header word, no
  # cell - carried an N alone and appeared in the report as an arm.
  keep <- used | (!is.na(armN[arms]) & !is.na(armName[arms]))
  if (!any(keep)) keep <- rep(TRUE, nArms)

  list(data       = DATA,
       arms       = data.frame(arm = armName[arms][keep],
                               # with strata the column header's sizes, where it printed
                               # any; else what the walk found (an N row inside a stratum)
                               N = (if (length(stratumStarts)) ifelse(is.na(armNHeader), armN, armNHeader) else armN)[arms][keep],
                               stringsAsFactors = FALSE),
       armNSource = armNSource[arms][keep],
       # the lines of THIS block, caption to last data row: what the page
       # prints inside the chosen table (issue 61 - the merge's outcome
       # refusal must not touch a row printed in the table itself)
       blockText  = lineTexts[seq(capIdx, lastData)],
       derivedCounts = unique(pctDerived),
       # A NAME SURVIVES IF ANY BLOCK STILL CLAIMS IT (screen
       # 2026-09-09-1532, F3): the labels of blocks that declined are
       # dropped only where no surviving block, and no line that never
       # entered the joint pass, claims the same label.
       approxCounts  = local({
         claimed  <- unique(unlist(pctApproxByBlock, use.names = FALSE))
         surviving <- unique(unlist(
           pctApproxByBlock[setdiff(names(pctApproxByBlock), pctDeclinedBlocks)],
           use.names = FALSE))
         outside  <- setdiff(pctApproxRows, claimed)
         unique(c(outside, surviving))
       }),
       # rows where the best and the worst admissible readings fall on
       # opposite sides of p = 0.01, and rows whose admissible set was
       # too large to enumerate completely (2026-09-08)
       approxStraddle = unique(pctStraddle),
       approxUnresolved = pctUnresolved,
       derivedCells  = if (length(derivedCells)) do.call(rbind, derivedCells)
                       else NULL,
       clusters   = nArms,
       skipped    = skippedDf,
       dispersion = dispersionBasis)
}

#' Parse a baseline table with the deterministic engine only
#'
#' Reads the baseline characteristics table out of `pdfFile` using word
#' coordinates and regular expressions. No AI service is contacted, so the
#' result is reproducible and every value can be traced to a printed cell.
#' [parseBaselineTable()] wraps this function and adds the optional AI
#' fallback; call this one directly when you need a purely deterministic
#' answer.
#'
#' How it works, in order:
#'
#' 1. `pdftools::pdf_data()` gives every word on every page with its x/y
#'    position (points, origin top-left).
#' 2. Each page is split into its typographic columns by finding the vertical
#'    gutters that few text lines write into. This matters: journals are set
#'    in two columns, and a table usually sits in one of them with body prose
#'    beside it, so lines have to be built inside a column rather than across
#'    the page.
#' 3. Every captioned table in the document is located by finding the word
#'    "Table" (or "TABLE", or "Tab.") followed by a numeral, Arabic or Roman.
#'    Each caption is scored for how much it sounds like a baseline table.
#' 4. The most promising candidates are parsed and the best result is kept.
#'    Within a candidate: words are clustered into lines by y, numeric cells
#'    are recognized by regular expression (mean +/- SD, mean (SD), n (%),
#'    n/m fractions such as sex 15/10, median \[IQR\], plain counts), cell
#'    x-midpoints are clustered into treatment-arm columns, a p-value column
#'    is detected and dropped, arm names and N are read from the header lines,
#'    and rows are expanded to one output line per arm.
#'
#' Anything the parser could not use is reported in `$skipped` rather than
#' silently dropped.
#'
#' @param pdfFile Path to the article or submission PDF. The PDF must have a
#'   text layer; a scanned image must be run through OCR first (for example
#'   `pdftools::pdf_ocr_text()`).
#' @param trial Value for the TRIAL column. Defaults to the PDF file name.
#' @param pages Integer vector of pages to search. `NULL` (default) searches
#'   the whole document.
#' @param layout `"auto"` (default) tries both a column-segmented and a
#'   full-width reading of each candidate page and keeps whichever parses
#'   better; `"columns"` forces column segmentation; `"single"` forces
#'   full-width, which is right for a table that spans the page.
#' @param parenIsSD How to read "a (b)" cells that carry no percent sign:
#'   `"auto"` decides from the footnotes ("mean (SD)"), the row label
#'   ("n (%)"), and continuous-variable keywords (age, weight, ...);
#'   `"sd"` always reads mean (SD); `"percent"` always reads n (%).
#' @param roundObsDelta ROUND_OBSERVATION is set to ROUND_MEAN +
#'   `roundObsDelta`. Observations are often recorded with one more digit than
#'   the reported mean, hence the default of 1. Set to 0 to make them equal.
#' @param maxCandidates How many captioned tables to attempt before giving up.
#'   Candidates are tried in order of caption score.
#' @param ocr Read the pages with OCR instead of the text layer, for scanned
#'   articles that have no text layer at all. Needs the `tesseract` package.
#'   Everything downstream is unchanged — OCR word boxes are converted to the
#'   same coordinates `pdftools::pdf_data()` reports — but the characters
#'   themselves are now fallible, so treat the result with more suspicion than
#'   a text-layer parse.
#' @param ocrDpi Rendering resolution for OCR. Higher is slower and not
#'   necessarily better; 300 is a reasonable default for journal scans.
#' @param pctApprox Opt in to APPROXIMATE percent conversion. Percent-block
#'   cells are normally converted to counts only when the printed percentage
#'   and the arm N pin exactly one integer; with `pctApprox = TRUE`, cells
#'   the bracket cannot pin fall back to `round(N x pct / 100)`. Every such
#'   value is recorded in `$approxCounts` and `$derivedCells` and reported
#'   by [reviewFlags()] - it is a computed approximation (off by up to half
#'   a printed unit of N/100), not a printed datum. Default `FALSE`.
#' @param quiet Suppress the progress and summary messages.
#'
#' @return An object of class `ParsePDFTable`: a list with
#'   \describe{
#'     \item{data}{data frame in Integrity-Analysis template layout - TRIAL,
#'       ROW, N, MEAN, SD, ROUND_MEAN, ROUND_OBSERVATION, then one column per
#'       category.}
#'     \item{arms}{data frame of arm names and arm N read from the header.}
#'     \item{skipped}{data frame of table lines that could not be used, with
#'       the reason. Review these by hand.}
#'     \item{provenance}{one row per output line recording which engine
#'       produced it - `"heuristic"` throughout, for this function.}
#'     \item{pages}{the page the table was found on.}
#'     \item{caption}{the table caption line, as read.}
#'     \item{engine}{`"heuristic"`.}
#'   }
#'
#' @seealso [parseBaselineTable()] for the hybrid entry point,
#'   [writeIntegrityTemplate()] to write the result to a spreadsheet.
#' @export
parseBaselineTableHeuristics <- function(pdfFile,
                                         trial         = tools::file_path_sans_ext(basename(pdfFile)),
                                         pages         = NULL,
                                         layout        = c("auto", "columns", "single"),
                                         parenIsSD     = c("auto", "sd", "percent"),
                                         roundObsDelta = 1,
                                         maxCandidates = 6,
                                         ocr           = FALSE,
                                         ocrDpi        = 300,
                                         pctApprox     = FALSE,
                                         quiet         = FALSE)
{
  layout    <- match.arg(layout)
  parenIsSD <- match.arg(parenIsSD)
  # A Word manuscript takes its own route (issue 19): the parameter keeps
  # its historical name `pdfFile` for API stability, and dispatch happens
  # HERE - inside the exported function - so parseOne.R and every other
  # caller need no change. `pages`, `layout`, and `ocr` have no meaning
  # for a .docx and are ignored.
  if (grepl("[.]docx$", pdfFile, ignore.case = TRUE))
    return(parseBaselineTableDocx(pdfFile, trial = trial,
                                  parenIsSD = parenIsSD,
                                  roundObsDelta = roundObsDelta,
                                  maxCandidates = maxCandidates,
                                  pctApprox = pctApprox, quiet = quiet))
  # JATS XML (issue 29). Same reasoning as the .docx branch above: the
  # dispatch lives inside the exported function, so inst/scripts/parseOne.R
  # and every other caller need no change.
  if (grepl("[.]xml$", pdfFile, ignore.case = TRUE))
    return(parseBaselineTableJats(pdfFile, trial = trial,
                                  parenIsSD = parenIsSD,
                                  roundObsDelta = roundObsDelta,
                                  maxCandidates = maxCandidates,
                                  pctApprox = pctApprox, quiet = quiet))
  # A table IMAGE (jpg/png/tif; Steve, 2026-09-02) is a scanned page
  # without the page: tesseract word boxes into this same engine, "ocr"
  # provenance, cyan in the app. The header preflight runs FIRST - the
  # file is hostile input, and no decoder touches it until its declared
  # size and page count are known to be sane (see utils.R).
  isImage <- .ppIsImageFile(pdfFile)
  if (isImage) {
    ok <- .ppImageOK(pdfFile)
    if (!isTRUE(ok))
      stop("Refused to read ", basename(pdfFile), ": ", attr(ok, "reason"),
           ".", call. = FALSE)
    ocr <- TRUE
    # A picture IS the table (Steve, 2026-09-03: "pasted screenshots can
    # be presumed to have captured the table"). A pasted screenshot of the
    # ticagrelor table was being split down its own middle: with no
    # "Table 1" caption in the picture, the page-layout detector took the
    # white gap between the row labels and the numbers for a two-column
    # journal gutter, and the left half (labels plus one arm) outscored
    # the whole. So an image is read full width only - a screenshot of a
    # two-column page is not what the picture route is for.
    layout <- "single"
  }
  if (!requireNamespace("pdftools", quietly = TRUE))
    stop("Package 'pdftools' is required: install.packages('pdftools')")
  say <- function(...) if (!quiet) message(...)

  allPages <- if (isImage) .ppImageData(pdfFile)
              else if (isTRUE(ocr)) .ppOcrPagesAt(pdfFile, ocrDpi, pages)
              else .ppPdfData(pdfFile)
  # A TABLE PRINTED SIDEWAYS becomes an extra, upright page (2026-09-25,
  # issue 38, .ppRotatedBlock in pageLayout.R): pageSource maps every
  # page index back to the real page it came from - the first nReal are
  # themselves - for the report and for the model's page image. Done
  # BEFORE the rail stripper, which would otherwise remove the table.
  nReal      <- length(allPages)
  pageSource <- seq_len(nReal)
  if (!isImage && !isTRUE(ocr) && nReal > 0) {
    pageH <- tryCatch(pdftools::pdf_pagesize(pdfFile)$height, error = function(e) NULL)
    if (!is.null(pageH) && length(pageH) == nReal)
      for (p in seq_len(nReal)) {
        rb <- .ppRotatedBlock(allPages[[p]], pageH[p])
        if (!is.null(rb)) {
          allPages[[length(allPages) + 1L]] <- rb
          pageSource <- c(pageSource, p)
          say("Page ", p, " carries a table printed sideways (", nrow(rb),
              " words): read as an upright page.")
        }
      }
  }
  # Submitted manuscripts number every line down the left margin; strip the
  # rail before anything downstream sees it (2026-08-20, see pageLayout.R).
  allPages <- lapply(allPages, .ppStripLineNumberRail)
  # Published PDFs carry a rotated "Downloaded from ..." watermark rail
  # whose fragments interleave with the table's lines (2026-08-22, see
  # pageLayout.R).
  allPages <- lapply(allPages, .ppStripStretchedGlyphs)   # issue 44
  allPages <- lapply(allPages, .ppStripRotatedText)
  # Arm-N recovery candidates are document-level constants: the "(n = 24)"
  # mentions with allocation-flavoured context, and the stated randomized
  # totals that confirm a positional assignment. Extracted once here, used
  # by every candidate parse (2026-08-21, see armNRecovery.R).
  fullText   <- if (isTRUE(ocr)) character(0) else
    tryCatch(.ppPdfText(pdfFile), error = function(e) character(0))
  textCands  <- .ppArmNCandidatesFromText(fullText)
  textTotals <- .ppRandomizedTotals(fullText)
  textGroupN <- .ppGroupsOfN(fullText)          # "three groups of eight each"
  nWords   <- sum(vapply(allPages, nrow, integer(1)))
  if (length(allPages) == 0 || nWords == 0)
    stop("No text layer found in ", pdfFile,
         if (isTRUE(ocr)) " (OCR produced no words either)."
         else " - it is a scanned image. Re-run with ocr = TRUE.")
  pageIdx <- if (is.null(pages)) seq_along(allPages) else
    intersect(pages, seq_len(nReal))
  # a requested real page brings its sideways-table page along
  if (!is.null(pages))
    pageIdx <- c(pageIdx, which(seq_along(pageSource) > nReal & pageSource %in% pageIdx))
  if (length(pageIdx) == 0)
    stop("No such page in ", pdfFile, ".")

  # ---- Enumerate candidate tables ----------------------------------------
  modes <- switch(layout,
                  auto    = c("columns", "single"),
                  columns = "columns",
                  single  = "single")

  cand <- list()
  # Look-ahead bookkeeping (2026-08-20): a caption with no data beneath it -
  # at the foot of a page, or on a caption-list page, both customary in
  # submitted manuscripts - announces a table that lives on the NEXT page
  # with no caption of its own. Such pages are recorded here and turned into
  # full-width candidates below, each carrying its caption's score.
  lookScore   <- list()
  lookCaption <- list()
  for (p in pageIdx) {
    w <- allPages[[p]]
    if (is.null(w) || nrow(w) == 0) next
    for (mode in modes) {
      bands <- if (mode == "columns") .ppPageBands(w)
               else data.frame(x0 = -Inf, x1 = Inf)
      if (mode == "columns" && nrow(bands) == 1 && "single" %in% modes) next
      for (b in seq_len(nrow(bands))) {
        bw <- .ppWordsInBand(w, bands[b, ])
        # The 4-word floor only serves the look-ahead: a caption-list page
        # can be a handful of words, and its anchors must still be seen.
        # Parseable candidates keep the original 10-word / 3-line floor.
        if (nrow(bw) < 4) next
        lines <- .ppBuildLines(bw)
        if (length(lines) < 1) next
        lineTexts <- vapply(lines, .ppLineText, character(1))
        anchors <- .ppCaptionAnchors(bw)
        if (nrow(anchors) == 0) next
        for (a in seq_len(nrow(anchors))) {
          # Which line holds this caption?
          li <- which.min(vapply(lines,
                                 function(L) min(abs(L$y - anchors$y[a])),
                                 numeric(1)))
          # A side caption (Springer's margin column, level with the
          # table's header row) is split here so that the header becomes
          # the block's first line instead of vanishing into the caption
          # text; see .ppSplitSideCaption(). The split is local to this
          # candidate - other anchors in the band see the original lines.
          cLines <- lines
          cTexts <- lineTexts
          cCap   <- lineTexts[li]
          side <- .ppSplitSideCaption(lines, li)
          if (!is.null(side)) {
            cLines <- side$lines
            cTexts <- vapply(cLines, .ppLineText, character(1))
            cCap   <- side$caption
            cTexts[li] <- cCap
          }
          # A caption whose anchor line is the bare "Table 1", its title
          # set on the line beneath ("Patient characteristics in the two
          # groups", Acta 1997, issue 45): scored on the anchor line
          # alone, "Table 1" is worth nothing and a results table with
          # any vocabulary at all outranks it. The numberless line below
          # is the caption's continuation and joins it for scoring and
          # for the report; the block itself starts where it did.
          if (grepl("^\\s*(?i:table|tab\\.?)\\s+(S?[0-9]{1,2}|[IVXLivxl]{1,4})[.:]?\\s*$",
                    cCap, perl = TRUE) &&
              li < length(cTexts) && !grepl("[0-9]", cTexts[li + 1L]))
            cCap <- .ppSquish(paste(cCap, cTexts[li + 1L]))
          # A "Table N" inside a sentence is worth trying only as a last
          # resort, so it is penalised rather than dropped.
          cs <- .ppCaptionScore(cCap) -
            if (isTRUE(anchors$startsBlock[a])) 0 else 5
          if (nrow(bw) >= 10 && length(cLines) >= 3)
            cand[[length(cand) + 1]] <- list(
              page = p, mode = mode, band = b, lines = cLines,
              lineTexts = cTexts, capIdx = li,
              caption = cCap, capScore = cs)
          if (isTRUE(anchors$startsBlock[a]) && p < nReal) {   # only a real page has a next page
            # Fewer than two data-looking lines (two or more printed
            # numbers) below the caption: the table is not on this page.
            below <- if (li < length(cTexts))
              cTexts[seq(li + 1, length(cTexts))] else character(0)
            dataish <- sum(vapply(below, function(t)
              sum(gregexpr("[0-9]+", t)[[1]] > 0) >= 2, logical(1)))
            key <- as.character(p + 1)
            prev <- if (is.null(lookScore[[key]])) -Inf else lookScore[[key]]
            if (dataish < 2 && cs > prev) {
              lookScore[[key]]   <- cs
              lookCaption[[key]] <- cCap
            }
          }
        }
      }
    }
  }

  # Materialise the look-ahead candidates: the page after a data-less
  # caption, read full width from its top (capIdx = 0 starts .ppParseBlock()
  # at the first line).
  for (key in names(lookScore)) {
    p2 <- as.integer(key)
    w2 <- allPages[[p2]]
    if (is.null(w2) || nrow(w2) < 10) next
    lines2 <- .ppBuildLines(w2)
    if (length(lines2) < 2) next
    cand[[length(cand) + 1]] <- list(
      page = p2, mode = "single", band = 1, lines = lines2,
      lineTexts = vapply(lines2, .ppLineText, character(1)),
      capIdx = 0L, caption = lookCaption[[key]], capScore = lookScore[[key]])
  }

  # No caption anywhere: fall back to reading pages from the top. When the
  # caller named the pages (the pages argument - a user aiming the parser,
  # or the OCR rescue aiming at a document's image-only pages), try EVERY
  # named page: a scanned Table 1 often carries no caption in its picture,
  # and the vocabulary scorer can prefer a flow-diagram page over the
  # table itself (found live 2026-08-26 on medRxiv 10.1101/19007195, where
  # page 17's CONSORT diagram outscored the actual table on page 19).
  # Unrestricted parses keep the old single-best-page behaviour - reading
  # every page of a 30-page document from the top would be candidate soup.
  if (length(cand) == 0) {
    tryPages <- if (!is.null(pages)) pageIdx else {
      scores <- vapply(allPages[pageIdx], .ppScorePage, numeric(1))
      pageIdx[which.max(scores)]
    }
    say("No table caption found; reading page(s) ",
        paste(tryPages, collapse = ","), " from the top",
        if (is.null(pages)) " (highest baseline-vocabulary score)." else
          " (the pages requested).")
    for (p in tryPages) {
      for (mode in modes) {
        bands <- if (mode == "columns") .ppPageBands(allPages[[p]])
                 else data.frame(x0 = -Inf, x1 = Inf)
        for (b in seq_len(nrow(bands))) {
          bw <- .ppWordsInBand(allPages[[p]], bands[b, ])
          if (nrow(bw) < 10) next
          lines <- .ppBuildLines(bw)
          if (length(lines) < 3) next
          # capIdx = 1 treats the page's first line as the caption, so
          # the header scan starts at line 2. For a PICTURE of a table
          # the first line IS the header (there is nothing above it), and
          # with capIdx = 1 the screenshot's "Aspirin arm (n=99)" was
          # never scanned: arm 2 got no N and fifteen "n (%)" rows were
          # skipped for it (2026-09-03). The look-ahead candidates above
          # already start at 0 for the same reason.
          cand[[length(cand) + 1]] <- list(
            page = p, mode = mode, band = b, lines = lines,
            lineTexts = vapply(lines, .ppLineText, character(1)),
            capIdx = if (isImage) 0L else 1L, caption = NA_character_,
            capScore = 0)
        }
      }
    }
  }
  if (length(cand) == 0)
    stop("No table caption and no parseable page were found in ", pdfFile,
         " (", nWords, " words of text). Try the `pages` argument.")

  # What the caption says outranks how big the table is. A results table can
  # be much larger than the baseline table and would otherwise win on parse
  # score alone, which is how "Table 3 Pain scores" got returned in place of
  # "Table 1 Patient characteristics". So: if any caption clearly announces a
  # baseline table, only those candidates are considered, and the parse score
  # merely breaks ties among them.
  # A CAPTION THAT NAMES TWO TABLES IS TWO TABLES - WHEN A SPLIT READING
  # EXISTS (2026-09-24/25, issue 35). On a two-column page the full-width
  # candidate joins the two columns' caption lines into one: "TABLE I
  # Baseline characteristics TABLE III Treatment outcomes". Its block
  # mixes the two tables' rows, and when that block yields one more
  # usable row than the single-column reading it wins on score - PMID
  # 16738291 filed Table III's outcome values under Age and Height once
  # the wrapped-label rule made one of its lines usable. The caption
  # vocabulary cannot see the straddle (the joined caption still says
  # "Baseline"); the second anchor can. The straddle is docked below what
  # its single-column twin earns, so the split reading wins.
  #
  # ONLY when that twin exists. An unconditional dock (the first version)
  # moved two corpus files the wrong way: on PMID 15681941 the page is a
  # single full-width layout with Table 1 beside Table 3 and no column
  # split, so the straddle was the only reading holding Table 1 and an
  # outcome table won; on PMID 12193491 the second anchor was prose that
  # ran onto the caption line ("... (Table II)"). So: a candidate whose
  # caption names two or more tables is set aside only if a TWIN exists -
  # another candidate on the same page whose caption BEGINS with the same
  # first table and names no other (a prose candidate "... presented in
  # table 1. The CSF ..." is not a twin: its anchor is mid-sentence, and
  # it has no rows). And "set aside" rather than "docked": the halves
  # are on the page, so the whole is read only if nothing else parses. A
  # fixed dock was not enough - four phantom arms each with a printed N
  # out-score two real ones by more than any caption bonus - and the
  # straddle's rows are two tables' rows, which no score should prefer.
  cand <- .ppSetAsideStraddles(cand)
  capScores <- vapply(cand, function(x) x$capScore, numeric(1))
  pageOf    <- vapply(cand, function(x) x$page, numeric(1))
  isStrong  <- capScores >= 3
  # Strong captions are *preferred*, not exclusive: many tables carry a bland
  # caption, and several strong-looking ones turn out to be unparseable, so
  # the weaker candidates still have to be tried rather than abandoned.
  ord  <- c(order(-capScores, pageOf)[isStrong[order(-capScores, pageOf)]],
            order(-capScores, pageOf)[!isStrong[order(-capScores, pageOf)]])
  cand <- cand[ord]
  strongOrdered <- isStrong[ord]

  tried <- 0L
  best <- NULL; bestScore <- -Inf; bestCand <- NULL; bestStrong <- FALSE
  # A straddle (see .ppSetAsideStraddles) is parsed like any candidate but
  # DEFERRED: it competes only if its twin - the single-table reading of
  # the same first table on the same page - yields no usable rows. Twins
  # that parse are recorded by page and anchor as the loop goes.
  deferred   <- list()
  twinParsed <- character(0)
  for (i in seq_along(cand)) {
    cc <- cand[[i]]
    if (tried >= maxCandidates && bestScore > -Inf) break
    tried <- tried + 1L
    # Narrate each candidate's fate (2026-08-25). Errors used to vanish
    # into a silent NULL, so a document whose every candidate failed
    # reported only "No usable baseline table" with no way to see WHY
    # each table was rejected. The label identifies the candidate the
    # way the winner is announced below: page, layout, caption snippet.
    whoIs <- paste0("Candidate ", i, "/", length(cand), " (page ", pageSource[cc$page],
                    if (cc$page > nReal) " sideways" else "",
                    ", ", if (cc$mode == "columns")
                      paste0("column ", cc$band) else "full width",
                    if (!is.na(cc$caption))
                      paste0(", \"", substr(.ppSquish(cc$caption), 1, 50), "\"")
                    else "", ")")
    res <- tryCatch(
      .ppParseBlock(cc$lines, cc$lineTexts, cc$capIdx, trial, parenIsSD,
                    roundObsDelta, function(...) invisible(NULL),
                    textCands = textCands, textTotals = textTotals,
                    pctApprox = pctApprox, textGroupN = textGroupN),
      error = function(e) e)
    if (inherits(res, "error")) {
      say(whoIs, ": parse error - ", conditionMessage(res))
      res <- NULL
    }
    sc <- .ppParseScore(res)
    if (!is.finite(sc)) {
      say(whoIs, ": no usable rows.")
      next
    }
    say(whoIs, ": ", length(unique(res$data$ROW)), " variable(s) x ",
        nrow(res$arms), " arm(s), ", nrow(res$skipped), " skipped, score ",
        sc, " + caption ", 2 * cc$capScore,
        if (!is.null(cc$straddleTwin)) " - straddles two tables; deferred" else "", ".")
    sc <- sc + 2 * cc$capScore
    tk <- .ppTwinKey(cc)
    if (!is.na(tk)) twinParsed <- c(twinParsed, tk)
    if (!is.null(cc$straddleTwin)) {
      deferred[[length(deferred) + 1L]] <-
        list(res = res, sc = sc, cc = cc, strong = strongOrdered[i],
             key = paste(cc$page, cc$straddleTwin))
      next
    }
    # A table whose caption announces baseline data beats any table whose
    # caption does not, however large the latter is. Only within one class
    # does the parse score decide.
    better <- if (strongOrdered[i] != bestStrong) strongOrdered[i] else
      sc > bestScore
    if (better) {
      bestScore  <- sc; best <- res; bestCand <- cc
      bestStrong <- strongOrdered[i]
    }
  }
  # Deferred straddles: admitted only when their twin produced nothing
  # usable (PMID 20608923: the "Table 1" column reading has no rows, the
  # straddle holds Height and Weight, and without this an outcome table
  # won); excluded when the twin parsed (PMIDs 16738291 and 16179044:
  # the straddle's four phantom arms would out-score the real two).
  for (dfr in deferred) {
    if (dfr$key %in% twinParsed) {
      say("Straddle \"", substr(.ppSquish(dfr$cc$caption), 1, 50),
          "\" excluded: its single-table twin parsed.")
      next
    }
    better <- if (dfr$strong != bestStrong) dfr$strong else dfr$sc > bestScore
    if (better) {
      bestScore <- dfr$sc; best <- dfr$res; bestCand <- dfr$cc
      bestStrong <- dfr$strong
    }
  }

  if (is.null(best))
    stop("No usable baseline table could be parsed from ", pdfFile,
         ". Try the `pages` or `layout` argument, or ai = \"always\".")

  # ---- Continuation onto following pages (2026-08-20) ----------------------
  # Manuscript tables regularly run over the page break, with no repeated
  # caption on the continuation page; the parse used to end at the bottom of
  # the caption's page and silently lose the rest. A following page is
  # appended when it opens with data-looking lines and no caption of its
  # own, and the extension is kept only if the parse score improves - a page
  # of prose adds skipped lines and lowers it.
  # Only a full-width winner is extended: appending full-width lines to a
  # column band would mix two different readings of the page, and journal
  # two-column tables repeat their caption when they continue anyway.
  bestPages <- pageSource[bestCand$page]
  if (bestCand$mode == "single" && bestCand$page <= nReal) {   # a sideways table has no next page
    extLines <- bestCand$lines
    extTexts <- bestCand$lineTexts
    p2 <- bestCand$page
    while (p2 < nReal) {
      p2 <- p2 + 1
      w2 <- allPages[[p2]]
      if (is.null(w2) || nrow(w2) < 10) break
      lines2 <- .ppBuildLines(w2)
      if (length(lines2) < 2) break
      lt2   <- vapply(lines2, .ppLineText, character(1))
      head6 <- utils::head(lt2, 6)
      nNum  <- vapply(head6, function(t)
        sum(gregexpr("[0-9]+", t)[[1]] > 0), integer(1))
      if (sum(nNum >= 2) < 2) break
      if (any(.ppCaptionStart(utils::head(lt2, 3)))) break
      resExt <- tryCatch(
        .ppParseBlock(c(extLines, lines2), c(extTexts, lt2), bestCand$capIdx,
                      trial, parenIsSD, roundObsDelta,
                      function(...) invisible(NULL),
                      textCands = textCands, textTotals = textTotals,
                      pctApprox = pctApprox, textGroupN = textGroupN),
        error = function(e) NULL)
      if (.ppParseScore(resExt) <= .ppParseScore(best)) break
      best      <- resExt
      extLines  <- c(extLines, lines2)
      extTexts  <- c(extTexts, lt2)
      bestPages <- c(bestPages, p2)
    }
  }

  say("Table on page ", pageSource[bestCand$page],
      if (bestCand$page > nReal) " (printed sideways; read upright)" else "",
      if (bestCand$mode == "columns")
        paste0(" (column ", bestCand$band, ")") else " (full width)",
      if (!is.na(bestCand$caption))
        paste0(": \"", substr(bestCand$caption, 1, 60), "\"") else "")
  say("Parsed ", length(unique(best$data$ROW)), " variable(s) x ",
      nrow(best$arms), " arm(s) = ", nrow(best$data), " template lines.")
  if (nrow(best$skipped) > 0) {
    say("SKIPPED ", nrow(best$skipped), " line(s) - review these by hand:")
    for (s in seq_len(nrow(best$skipped)))
      say("  - ", best$skipped$label[s], ": ", best$skipped$reason[s])
  }

  # Under ocr = TRUE every word box came from tesseract, not from the
  # PDF's own text layer, so every row inherits OCR's digit-misread risk
  # (3/8, 1/7). The distinct provenance drives the app's whole-table
  # cyan shading and its verify-every-cell note (issue 22, tier 2).
  eng <- if (isTRUE(ocr)) "heuristic-ocr" else "heuristic"
  structure(
    list(data       = best$data,
         arms       = best$arms,
         skipped    = best$skipped,
         provenance = data.frame(ROW = best$data$ROW,
                                 ENGINE = rep(if (isTRUE(ocr)) "ocr"
                                              else "heuristic",
                                              nrow(best$data)),
                                 stringsAsFactors = FALSE),
         pages      = bestPages,
         caption    = bestCand$caption,
         trial      = trial,
         layout     = bestCand$mode,
         dispersion = best$dispersion,
         armNSource = best$armNSource,
         blockText  = best$blockText,
         derivedCounts = best$derivedCounts,
         approxCounts  = best$approxCounts,
         approxStraddle = best$approxStraddle,
         approxUnresolved = best$approxUnresolved,
         derivedCells  = best$derivedCells,
         engine     = eng),
    class = "ParsePDFTable")
}
