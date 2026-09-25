# tokenize.R - turning one line of a table into numeric "cells".
#
############################################################################
# Provenance                                                               #
# Ported 2026-08-15 by Claude Code (model: Claude Opus 5, Anthropic) from  #
# parseCovariateTable.R in the Integrity-Analysis repository (drafted      #
# 2026-08-14 by Claude Code, model Claude Fable 5). Logic unchanged; only  #
# the `.pcv` -> `.pp` rename and the file split.                          #
# Deterministic: no AI service is called here.                            #
# Status: run and verified by tests/testthat/test-tokenize.R.             #
############################################################################
#
# A line is stored as a data frame of words (text, x, width).  We join the
# words with single spaces, remember where each word starts in the joined
# string, and scan the joined string with one master regular expression.
# Matching on the joined string (rather than word by word) makes the
# tokenizer indifferent to how poppler happened to split the cell:
# "45.3 \u00b1 12.1", "45.3\u00b112.1", and "45.3 \u00b112.1" all match the same
# pattern.
#
# Token types, tried in priority order (first alternative wins in PCRE):
#   meanSD    45.3 \u00b1 12.1   |  45.3 +/- 12.1  |  45.3 \u2022 12.1 (OCR bullet)
#   medianRng 45 [30-60]    |  45 [30, 60] |  45 (30 to 60)
#             -> Q1/Q3 when the text says IQR, else skipped (issue 18)
#   nPct      15 (60%)      |  15 (60.0 %)
#   numParen  45.3 (12.1)   -> mean (SD) or n (%) - disambiguated later
#   fraction  15/10         |  12/8/5      (sex, ASA class, ...)
#   pctOnly   60%                                             -> unusable
#   plain     45.3          (category counts; header n's)
#
# The (?<![A-Za-z0-9_.]) guard keeps digits inside words like "SpO2" or
# "CO2" from starting a token.

# A printed number, allowing more than one separator group so that a
# thousands-separated value ("4,335" or "1,234.5") is captured whole rather
# than split into "4" and ",335".
.ppNUM <- "[<>]?-?\\d+(?:[.,\u00b7]\\d+)*"

.ppTokenRegex <- local({
  NUM <- .ppNUM
  paste0(
    # A HYPHENATED CODE IS ONE WORD (2026-09-25, ISSUES.md issue 104; Kilic
    # 2023, Cukurova Med J, the corpus session's batch 25 AD1): the spinal
    # levels "L2-3", "L3-4", "L4-5" head three rows of counts, and the "3"
    # after the hyphen started a token - the first guard looks only at the
    # character before the digit, and that is the hyphen. The label was
    # cut to "L2", the "3" fed a phantom arm column at the label's x, and
    # "L2-3 12(57.1) 12(57.1)" read as a continuous row. A digit run whose
    # hyphen (or dash) follows a letter or digit is part of that word. A
    # range in a cell ("31-57") is untouched: the interval alternative
    # takes it whole from its first number.
    "(?<![A-Za-z0-9_.])(?<![A-Za-z0-9][-\u2013\u2212])(?:",
    # the BULLET (U+2022) is what a scanned CJA page's plus-minus becomes
    # in its OCR text layer ("56.7 \u2022 6.9", CJA 1995 and 1997, ISSUES.md
    # issue 45); a bullet between two numbers means nothing else
    # A BRACKETED RANGE MAY FOLLOW (2026-09-25, ISSUES.md issue 63; Fujii
    # 1998, PMID 9649986): "48.4 \u00b1 7.6 [33-63]" is a mean +/- SD with
    # the range appended, and "48.4 +7.6[33-63]" - the plus-minus set as a
    # plain "+" - can be nothing else once the range follows. Without the
    # range a "+" stays two numbers (the announced rules in the block
    # walker decide those). The range's numbers are num3/num4 to the
    # extractor and are ignored for a meanSD token.
    # U+2AFE is what the text layer of Fujii's canine tables (Anesth Analg
    # 2003, PMID 12933396 and its siblings) reports for the plus-minus
    # glyph of their font (2026-09-25, ISSUES.md issue 88)
    # A SIGN WHOSE SD IS LOST MUST NOT REACH THE NEXT CELL (2026-09-26,
    # ISSUES.md issue 118; CJA 1998, PMID 9350368, the corpus session's
    # batch 27 AF1): the scan's Age line reads "62 <pm> 61 <pm> 62 <pm> 9
    # 61 <pm> 11" - the first two SDs are absent from the text layer - and
    # the pattern below took "62 <pm> 61" for a cell, the next cell's mean
    # as this cell's SD, and scored p < 0.0001 on it. An SD that is itself
    # followed by a sign glyph is the next cell's mean: the lookahead
    # refuses it, and the two signs without an SD leave two bare numbers,
    # which the walker skips, and two cells, which it reads.
    "(?<meanSD>",    NUM, "\\s*(?:(?:\u00b1|\\+/-|\\+-|\u2022|\u2afe)\\s*", NUM,
                     "(?!\\s*(?:\u00b1|\\+/-|\\+-|\u2022|\u2afe))",
                     "(?:\\s*\\[\\s*", NUM, "\\s*(?:\u2013|\u2212|-|to)\\s*", NUM, "\\s*\\])?",
                     "|\\+\\s*", NUM, "\\s*\\[\\s*", NUM, "\\s*(?:\u2013|\u2212|-|to)\\s*", NUM, "\\s*\\]))",
    # interval separator: hyphen, en/em dash, Unicode minus (U+2212 - what
    # PDF fonts often use for "-"), the word "to" (ranges as journals
    # print them), plus comma/semicolon - the "median [Q1, Q3]" form
    # (issue 18); the comma cannot be mistaken for a thousands separator
    # because NUM only absorbs a comma when digits follow it immediately
    "|(?<medianRng>", NUM, "\\s*[\\[(]\\s*", NUM,
                     "\\s*(?:\u2013|\u2014|\u2212|-|to|[,;])\\s*", NUM, "\\s*[\\])])",
    # (.ppMedianParts below re-parses a matched medianRng token into its
    # three numbers; keep the two patterns in sync)
    "|(?<nPct>",     NUM, "\\s*\\(\\s*", NUM, "\\s*%\\s*\\))",
    "|(?<numParen>", NUM, "\\s*\\(\\s*", NUM, "\\s*\\))",
    "|(?<fraction>", "\\d+(?:\\s*/\\s*\\d+)+)",
    "|(?<pctOnly>",  NUM, "\\s*%)",
    "|(?<plain>",    NUM, ")",
    ")(?![A-Za-z0-9])"
  )
})

# The medianRng token's internal structure, with capture groups: median,
# lower bound, upper bound. Kept in sync with the medianRng alternative of
# .ppTokenRegex above; used by .ppTokenizeLine because a bare number grep
# over "127 [98-160]" would read the separator dash as a minus sign.
.ppMedianParts <- local({
  NUM <- .ppNUM
  paste0("(", NUM, ")\\s*[\\[(]\\s*(", NUM,
         ")\\s*(?:\u2013|\u2014|\u2212|-|to|[,;])\\s*(", NUM, ")\\s*[\\])]")
})

# Tokenize one line.  `line` is a data frame with columns text, x, width
# (one row per word, already sorted by x).  Returns a data frame with one
# row per token: type, text, the numbers it contains (num1, num2 =
# first/second number, e.g. mean and SD), decimals of num1, and the token's
# x extent (x0, x1, mid) recovered from the word coordinates.
# `first = TRUE` returns the FIRST token only, from one regexpr() match:
# the journal-style reader classifies a cell by its first token and
# discarded the rest, but paid for every one (security screen
# 2026-09-10-1856, F1: a 2,000-character cell of "1 1 1 ..." is a
# thousand tokens, a data frame each, 0.84 s a cell - and a workbook of
# 49,900 such cells, within every other bound, was eleven hours). One
# match is one scan of the cell whatever it contains.
.ppTokenizeLine <- function(line, first = FALSE) {
  joined    <- paste(line$text, collapse = " ")
  wordStart <- cumsum(c(1, nchar(line$text) + 1))[seq_len(nrow(line))]
  wordEnd   <- wordStart + nchar(line$text) - 1

  m <- if (first) regexpr(.ppTokenRegex, joined, perl = TRUE)
       else gregexpr(.ppTokenRegex, joined, perl = TRUE)[[1]]
  if (m[1] == -1) {
    return(data.frame(type = character(0), text = character(0),
                      num1 = numeric(0), num2 = numeric(0),
                      num3 = numeric(0),
                      dec1 = integer(0), dec2 = integer(0),
                      dec3 = integer(0),
                      x0 = numeric(0), x1 = numeric(0),
                      mid = numeric(0), start = integer(0),
                      stringsAsFactors = FALSE))
  }

  starts <- as.integer(m)
  lens   <- attr(m, "match.length")
  # Which named group matched, per token
  capStarts <- attr(m, "capture.start")   # matrix tokens x groups
  capNames  <- attr(m, "capture.names")

  tokens <- lapply(seq_along(starts), function(i) {
    tokText <- substr(joined, starts[i], starts[i] + lens[i] - 1)
    type    <- capNames[capStarts[i, ] > 0][1]
    nums    <- if (type == "medianRng") {
      # structured extraction: a bare .ppNUM grep over "127 [98-160]"
      # reads the separator dash as 160's minus sign; the capture groups
      # keep separator and sign apart
      mm <- regmatches(tokText,
                       regexec(.ppMedianParts, tokText, perl = TRUE))[[1]]
      mm[2:4]
    } else regmatches(tokText, gregexpr(.ppNUM, tokText, perl = TRUE))[[1]]
    # Map character positions back to words to recover x coordinates
    wFirst  <- which(wordEnd   >= starts[i])[1]
    wLast   <- rev(which(wordStart <= starts[i] + lens[i] - 1))[1]
    x0      <- line$x[wFirst]
    x1      <- line$x[wLast] + line$width[wLast]
    data.frame(type = type, text = tokText,
               num1 = if (length(nums) >= 1) .ppAsNumeric(nums[1]) else NA_real_,
               num2 = if (length(nums) >= 2) .ppAsNumeric(nums[2]) else NA_real_,
               # The THIRD number exists only in a medianRng token -
               # "127 [98, 160]" is median, Q1, Q3 - and is what lets the
               # engine emit quartiles instead of skipping the row (issue 18).
               num3 = if (length(nums) >= 3) .ppAsNumeric(nums[3]) else NA_real_,
               dec1 = if (length(nums) >= 1) .ppDecimals(nums[1]) else NA_integer_,
               # Decimals of the SECOND number too: when a table prints a
               # standard error rather than a standard deviation, the printed
               # granularity of that value is data in its own right, and it is
               # not recoverable from the mean's.
               dec2 = if (length(nums) >= 2) .ppDecimals(nums[2]) else NA_integer_,
               dec3 = if (length(nums) >= 3) .ppDecimals(nums[3]) else NA_integer_,
               x0 = x0, x1 = x1, mid = (x0 + x1) / 2,
               start = starts[i],
               stringsAsFactors = FALSE)
  })
  do.call(rbind, tokens)
}
