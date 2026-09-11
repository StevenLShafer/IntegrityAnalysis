# app_globals.R — constants shared by the UI and server.
#
# PROVENANCE: was global.R at the repository root until the package
# restructure (phase 1, 2026-08-16); in phase 2 (same date) sumz() and
# outputComments() moved to their own files (R/sumz.R, R/outputComments.R,
# bodies untouched), leaving only the Monte Carlo replication constant here.
# The library() calls that used to open global.R live in run_app()
# (app_run.R). History for the earlier cleanup passes (2026-08-14) is in
# git; the FIX rationale comments travel with the code they explain.

# m is the MAXIMUM replication count per row for the Monte Carlo
# simulation (the final stage of the adaptive scheme - see the header of
# R/P_Calc.R and docs/statistics.md). Rows simulate in stages
# 1,000 -> 10,000 -> m, escalating while the running mid-p is < 0.1 (to
# leave 1,000) and < 0.01 (to leave 10,000). Staging is per TRIAL, so a
# typical (unalarming) TRIAL costs 1,000 replicates a row - an
# unremarkable row in an alarming trial escalates with it - CHEAPER
# than the old flat 15,000 - while alarming rows get the precision that
# makes a "<0.0001" claim defensible (the 97.5% upper confidence bound
# must clear it, which needs ~30,000+ replicates at zero exceedances).
m <- 100000

############################################################################
# References                                                               #
# Carlisle JB. The analysis of 168 randomised controlled trials to test    #
# data integrity. Anaesthesia. 2012;67:521-537.                            #
#                                                                          #
# Carlisle JB, Dexter F, Pandit JJ, Shafer SL, Yentis SM. Calculating the  #
# probability of random sampling for continuous variables in submitted or  #
# published randomised controlled trials. Anaesthesia. 2015;70:848-58.     #
#                                                                          #
# Carlisle JB. Data fabrication and other reasons for non-random sampling  #
# in 5087 randomised, controlled trials in anaesthetic and general medical #
# journals. Anaesthesia. 2017;72:944-952                                   #
############################################################################

# The arm-size ceiling, shared by the app and the API so one number
# governs both and the documentation can state it as a property of
# IntegrityAnalysis rather than of one entry point (Steve, 2026-08-28).
#
# Two reasons, in his words: the Monte Carlo for a trial with more than
# 5,000 subjects in an arm is computationally expensive; and trials that
# large are "almost certainly funded by large companies or government
# entities" which "typically institute detailed auditing and review of
# manuscripts", so an independent fraud screen adds little.
#
# Enforcement is in validateData(), the gate BOTH surfaces run - the
# ceiling previously existed only in apiService.R, so the app had no
# limit and the documented claim would have been false for every web
# user. R/P_Calc.R remains callable directly for anyone with the
# computing horsepower and a reason.
.iaMaxArmN <- 5000L


# ---- ONE name normalizer, used by validateData AND the API gates -------
#
# WHY THIS EXISTS (2026-08-29). The /analyze size gates must read the
# frame validateData will actually see, or an attacker picks a column
# NAME that the gate does not recognise and the validator does. On
# 2026-08-28 that was fixed by adding .apiNormalizeNames to apiService.R
# - a SECOND implementation of rules that already lived here. It matched
# a subset, and the overnight screen found that every rule it missed was
# a bypass:
#
#   F1  label column named "ROWS" - validateData greps "ROW" and renames
#       it; the gate matched "ROW" exactly, so the categorical term was
#       skipped entirely. drawWork 1.9e10 -> 0, refused -> accepted,
#       and the table was analysed anyway. ~2 hours of CPU for a 180 KB
#       upload.
#   F2  NUMBER and N BOTH present - validateData renames NUMBER to N
#       UNCONDITIONALLY, producing two columns named N; R resolves $N to
#       the FIRST, which is the attacker's. The gate read N = 1 and
#       admitted a simulation of N = 5000. Scored 24x under budget for
#       work 208x over it.
#   F3  the MEASURE rename was copied WITHOUT validateData's coupled
#       GROUP/DECSD drops, so a legitimate Carlisle-2016 file the app
#       accepts got a 422 from the API with six bogus cell issues.
#
# Two implementations of one rule set is the defect. This is the rule
# set; both callers use it, so they cannot disagree.
#
# The validated frame with the rows validateData() left out put back, in
# the validator's order (trial, then row), for the template, the results
# workbook and the journal table - never for the engine (audit 2026-09-10
# F3). ONE restorer for the API and the app, so the two cannot differ
# (CodeRabbit on #250).
.iaWithExcluded <- function(DATA, rows, oneLinePerLabel = FALSE) {
  if (is.null(rows) || !nrow(rows)) return(DATA)
  # FOR THE JOURNAL TABLE, one blank line per label (screen 2026-09-10-1143,
  # F1): the table builder groups lines by ROW name, so 2,499 label-only
  # lines all named "A" became one variable with 2,499 arms and every
  # other line got 2,499 blank cells - 6.25 million cells, 28 s and 346 MB
  # through /analyze, 145 s for the app's workbook, from a 90 KB upload
  # that the engine never simulates. A label-only variable has no arms to
  # show, so one line per TRIAL and ROW loses nothing; the TEMPLATE keeps
  # every row, because that is the round trip.
  if (oneLinePerLabel)
    rows <- rows[!duplicated(rows[c("TRIAL", "ROW")]), , drop = FALSE]   # a two-column key,
                                          # not a pasted string (CodeRabbit on #258)
  d <- .ppRbindFill(DATA, rows)
  d[order(d$TRIAL, d$ROW), , drop = FALSE]
}

# THE JOURNAL TABLE'S SIZE, ESTIMATED BEFORE IT IS BUILT - width included
# (screen 2026-09-10-1143, F1). The estimate used to be the number of
# lines, on the argument that nrow(DATA) is variables x arms and so
# already carries the arm multiplicity. It does for an honest table; it
# does not for a table whose lines share a ROW name, because the builder
# makes one COLUMN per line sharing a name, and every other variable
# pays for that width in blank cells. So, per trial: the emitted lines
# (rows, plus one per category level that holds a count) times one plus
# the largest number of lines sharing a ROW name in that trial - which is
# the table's width. On an ordinary two-arm Table 1 of 40 lines that is
# 120; on the screen's probe, 12.5 million. Shared by the API's journal
# tables and the app's two downloads, which had no gate at all.
.iaMaxJournalCells <- 200000L
.iaJournalCells <- function(DATA, categoryNames = NULL) {
  if (is.null(DATA) || !nrow(DATA)) return(0)
  tr <- as.character(DATA$TRIAL); tr[is.na(tr)] <- ""
  rw <- as.character(DATA$ROW);   rw[is.na(rw)] <- ""
  have <- intersect(categoryNames, names(DATA))
  catRows <- if (length(have)) rowSums(!is.na(DATA[, have, drop = FALSE])) > 0
             else rep(FALSE, nrow(DATA))
  total <- 0
  for (i in split(seq_len(nrow(DATA)), tr)) {
    lines <- length(i) + sum(catRows[i]) * length(have)
    width <- max(table(rw[i]))
    total <- total + lines * (1 + width)
  }
  as.numeric(total)
}
.iaJournalOmittedNote <- function(cells) paste0(
  "the journal-style tables were omitted: this table would emit about ",
  format(cells, big.mark = ","), " cells, above the ",
  format(.iaMaxJournalCells, big.mark = ","),
  "-cell limit. The analysis itself is unaffected.")

# A CATEGORY LEVEL'S COLUMN NAME, safe against the normaliser (security
# audit 2026-09-10, S2; the rule .iaLongToWide has used for a typed long
# layout since 2026-09-05). A level whose upper-cased name is a base
# column, or contains a token the normaliser reads as a header, becomes
# "<variable> <level>" in lower case; any other level keeps its name.
.iaLevelColumnName <- function(row, level) {
  base <- c("TRIAL", "ROW", "N", "MEAN", "SD", "SE", "Q1", "Q3", "LEVEL",
            "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION")
  tokens <- "TRIAL|MEASURE|DECM|NUMBER|GROUP|ROW|MEAN|OBS|LEVEL|CATEGORY"
  nm <- toupper(trimws(level))
  if (nm %in% base || grepl(tokens, nm)) tolower(paste(row, level)) else level
}

# ORDER MATTERS and mirrors validateData's original sequence exactly:
# uppercase, TRIAL, MEASURE (with its drops), DECM, NUMBER, GROUP->ROW
# fallback, then the ROW grep. Changing the order changes which column
# wins when several match.
# THE TRIAL COLUMN, BY THE NORMALISER'S OWN RULE - any name containing
# TRIAL once upper-cased and trimmed - or NA when there is none. The
# API's upload reader used to test for the exact spelling "TRIAL" BEFORE
# normalising, so a lower-case `trial` header, which the user guide
# promises is accepted, got a SECOND trial column from the file name;
# the two then collapsed onto one name in validation and the file was
# refused with the duplicate-name message (independent audit
# 2026-09-10, F4 - reproduced through the actual /parse and /analyze
# handlers). One rule, used by the reader and by the normaliser below,
# so the two cannot disagree; the same lesson as the normaliser itself
# (two implementations of one rule set is the defect).
.iaTrialColumn <- function(DATA) {
  if (is.null(DATA) || is.null(names(DATA)) || !length(names(DATA)))
    return(NA_character_)
  i <- grep("TRIAL", toupper(trimws(names(DATA))))
  if (length(i)) names(DATA)[i[1]] else NA_character_
}

.iaNormalizeNames <- function(DATA) {
  if (is.null(DATA) || is.null(names(DATA)) || !length(names(DATA)))
    return(DATA)
  names(DATA) <- toupper(trimws(names(DATA)))

  nm <- names(DATA)
  i <- grep("TRIAL", nm)
  if (length(i)) names(DATA)[i[1]] <- "TRIAL"

  nm <- names(DATA)
  i <- grep("MEASURE", nm)
  if (length(i)) {
    names(DATA)[i[1]] <- "ROW"
    # COUPLED, not incidental: validateData drops these in the same
    # branch. Splitting them was F3.
    DATA$GROUP <- NULL
    DATA$DECSD <- NULL
  }

  nm <- names(DATA)
  i <- grep("DECM", nm)
  if (length(i)) names(DATA)[i[1]] <- "ROUND_MEAN"

  # UNCONDITIONAL, exactly as validateData does it. Renaming only when
  # no N exists was F2: it left two columns that both normalize to N.
  nm <- names(DATA)
  i <- grep("NUMBER", nm)
  if (length(i)) names(DATA)[i[1]] <- "N"

  nm <- names(DATA)
  if (!length(grep("ROW", nm))) {
    i <- grep("GROUP", nm)
    if (length(i)) names(DATA)[i[1]] <- "ROW"
  }

  # The grep that F1 turned on: ANY name containing ROW becomes ROW.
  nm <- names(DATA)
  i <- grep("ROW", nm)
  if (length(i)) names(DATA)[i[1]] <- "ROW"
  # The long categorical layout's column (2026-09-05): LEVEL, or its
  # alias CATEGORY, matched EXACTLY - a grep would swallow a category
  # column that happens to contain the word.
  nm <- names(DATA)
  i <- which(nm %in% c("LEVEL", "CATEGORY"))
  if (length(i)) names(DATA)[i[1]] <- "LEVEL"
  DATA
}

# The grid rows a file's UNUSABLE lines may add (security screen
# 2026-09-07-1758, F3): a page whose lines mostly fail to parse would
# otherwise put one row in the browser per refused line. Generous beside
# any real baseline table, and the count of the rest is shown.
.iaMaxSkippedRows <- 200L

# ...and the registries a SESSION may accumulate across uploads. Both grow
# by rbind on every file and neither shrinks, so a zip of 300 documents
# multiplies whatever one document yields; the derived registry had no
# bound at all, and it is the one that paints cells (security screen
# 2026-09-07-2241, finding F3). The ceilings are far above any real
# session - a baseline table registers a handful of derived cells - and
# what is dropped is only the PAINT and its hover note, never a number.
.iaMaxRegistryRows <- 5000L
# The kinds that WARN. These say the numbers beside them may not be the
# numbers on the page, so they are the last paint to drop, never the
# first: "derived" alone means the parser computed a cell arithmetically,
# which is ordinary.
.iaWarnKinds <- c("ocr", "ai", "failsafe", "recovered")
.iaCapRegistry <- function(reg, cap = .iaMaxRegistryRows) {
  if (is.null(reg) || nrow(reg) <= cap) return(reg)
  # BY PRIORITY, not by position (security screen 2026-09-08-0709, F3).
  # Keeping the head let an early file in a zip push a later table's OCR
  # warning out of the grid; keeping the tail, which was the fix for
  # that, let a LAST file yielding thousands of ordinary derived cells
  # evict the OCR warning of every earlier file. Both ends are reachable
  # through a zip, so swapping ends traded one exposure for the other.
  # Warning rows are kept while any ordinary derived row remains, and
  # registry order is preserved either way because .iaDerivedPayload()
  # resolves a shared cell last-entry-wins.
  n <- nrow(reg)
  kind <- if (!is.null(reg$KIND)) as.character(reg$KIND) else rep("derived", n)
  warn  <- which(kind %in% .iaWarnKinds)
  plain <- which(!(kind %in% .iaWarnKinds))
  keep <- if (length(warn) >= cap)
            utils::tail(warn, cap)
          else c(warn, utils::tail(plain, cap - length(warn)))
  out <- reg[sort(keep), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# A whole FILE's unusable lines, capped across its blocks. parseWideTable()
# returns one block per "Trial:" marker row and nothing caps the number of
# markers, so capping each block separately bounded 200 times the block
# count - a 10,000-row sheet of three-row blocks was unbounded in practice
# (screen 2026-09-07-2101, F4). One budget, spent in order; the block that
# exhausts it carries the marker and the rest contribute nothing.
.iaCapSkippedFile <- function(blocks, cap = .iaMaxSkippedRows) {
  budget  <- cap
  omitted <- 0L
  out <- lapply(blocks, function(sk) {
    if (is.null(sk) || !nrow(sk)) return(sk)
    if (budget <= 0) { omitted <<- omitted + nrow(sk); return(sk[0, , drop = FALSE]) }
    kept <- .iaCapSkipped(sk, budget)
    # .iaCapSkipped() marks its OWN truncation; what it cannot see is the
    # blocks after it, which the exhausted budget drops whole. Their count
    # is carried and reported below, so no unusable line ever disappears
    # without being counted (CodeRabbit on PR #222). The marker is counted
    # out by its reason, never by its label (screen 2241, F4).
    omitted <<- omitted + max(0L, nrow(sk) - sum(!.iaIsSkipMarker(kept)))
    budget  <<- max(0L, budget - nrow(kept))
    kept
  })
  if (omitted > 0) {
    last <- which(vapply(out, function(x) !is.null(x) && nrow(x) > 0, logical(1)))
    if (length(last)) {
      i  <- last[length(last)]
      mk <- out[[i]][1, , drop = FALSE]
      mk[] <- NA_character_
      mk$label  <- sprintf("... %d further unusable line(s) not shown", omitted)
      mk$reason <- .iaSkipMarkerReason
      out[[i]] <- rbind(out[[i]][!.iaIsSkipMarker(out[[i]]), , drop = FALSE], mk)
      rownames(out[[i]]) <- NULL
    }
  }
  out
}

# The grid payload for the DERIVED-cell registry: which cells paint which
# colour and what their hover note says. Same shape, same reason, and same
# measurements as .iaSkipPayload() below - this loop was left behind when
# that one was rewritten, forty lines above it in the same reactive, and a
# screen measured the replicated version at 7.8 s for 25,000 painted keys
# and 191.9 s for 100,000 (security screen 2026-09-07-2241, finding F3).
# The registry it walks has no cap and accumulates across uploads, so the
# cost is the editor's whole session.
#
# `dv` is the registry (TRIAL, ROW, COL, KIND, note; "*" in ROW or COL
# means every row of that trial, or every column). `d` is the grid frame.
# ONE KEY for a (TRIAL, ROW) pair (security screen 2026-09-08-0709, S1).
# Both fields are document text - a trial name is a file stem or a TRIAL
# cell, a row label is lifted off the page - and both registries matched
# grid rows against registry rows by pasting them with a carriage return
# between. A field carrying that separator made the decomposition
# ambiguous: TRIAL "A" with ROW "B<CR>C", and TRIAL "A<CR>B" with ROW
# "C", produce the same key, so one registry entry could claim a grid
# row it does not name and, in the wrong order, replace an OCR warning
# with a benign derived note. The screen could not construct a parser
# that emits a carriage return into those fields and neither could I, so
# this is the shape closed rather than a demonstrated exploit - but a
# user can type into the grid, and the fix costs nothing.
# Length-prefixing each field makes the encoding unambiguous whatever
# the content: no string can forge another string's key, because the
# byte counts have to match first.
# THE VALUE COLUMNS ARE READ AS TEXT (independent audit 2026-09-09, F5).
# read.csv() coerces "50.000" to the double 50 before the validator can
# count its trailing zeros, so the precision the spreadsheet route now
# preserves was still destroyed on the comma-separated one: the same
# table read 3 and 2 decimals as text and 0 and 0 as a CSV, and the p
# moved from 0.0047 to 0.35. Only the value columns are held as text -
# validateData() coerces those itself and reads their digits first,
# while N, the counts and every other column must stay numeric or
# is_category() stops seeing a count column. Reading them as text also
# stops a trial named "T" becoming the logical TRUE.
.iaReadCsvKeepingText <- function(path, ...) {
  # THE FILE IS DECODED BEFORE ANYTHING TOUCHES IT (security screen
  # 2026-09-10-0536, F2). The previous attempt at this substituted the
  # undecodable bytes into a LOCAL copy used only for the keepText test,
  # and left the frame carrying the raw bytes - so the very next call,
  # .iaNormalizeNames(), ran toupper() on them and raised exactly the
  # error the fix was written to avoid. The reported symptom - a
  # non-English Excel export refused with the wrong reason - still
  # reproduced, and the test could not see it because it stopped at this
  # function. Three routes had to be covered, not one:
  #
  #   * the HEADER, which .iaNormalizeNames() folds one call later;
  #   * the VALUES, which trimws() below folds - a trial named "Größe"
  #     raised there and the earlier fix did not touch the value path;
  #   * the Shiny route, which calls this WITHOUT check.names = FALSE, so
  #     read.csv()'s own make.names() raised before any of our code ran.
  #
  # So the read is always check.names = FALSE - the only spelling that
  # lets the raw bytes reach us intact - everything is decoded with
  # sub = "byte", and make.names() is applied afterwards when the caller
  # wanted it. Undecodable bytes become printable escapes, which means
  # such a column simply never matches a value-column name: the right
  # answer, since it is not one of them.
  dots <- list(...)
  wantCheckNames <- !identical(dots[["check.names"]], FALSE)
  dots[["check.names"]] <- FALSE
  con <- .iaCsvConnection(path); on.exit(close(con))   # raw: never inflated (screen 2100 F1)
  d <- do.call(utils::read.csv,
               c(list(con, colClasses = "character"), dots))
  san <- function(x) iconv(x, from = "", to = "UTF-8", sub = "byte")
  names(d) <- san(names(d))
  for (j in seq_along(d)) if (is.character(d[[j]])) d[[j]] <- san(d[[j]])
  if (wantCheckNames && ncol(d))
    names(d) <- make.names(names(d), unique = TRUE)
  keepText <- c("MEAN", "SD", "SE", "Q1", "Q3")
  # THE NAME IS NORMALISED HERE, AND THE COLUMNS ARE TAKEN BY POSITION
  # (security screen 2026-09-09-0721, F3 and F5). Two defects, one line.
  #
  # F3: the test was exact and case-sensitive, while .iaNormalizeNames()
  # upper-cases the headers AFTERWARDS - so a file headed "Mean", the
  # natural spelling and an accepted alias, was coerced to numeric on the
  # way in and its trailing zeros were gone before validateData() could
  # count them. Measured on one file with only the header varied:
  # "MEAN" gave ROUND_MEAN 3, "Mean" gave 0 - and a coarser grid is the
  # direction that RAISES p, which is the direction an author benefits
  # from. The .xlsx route was never affected, so the guarantee held on one
  # route and not the other while the guide promised both.
  #
  # F5: iterating by name broke on a blank header, which read.csv keeps as
  # "" under check.names = FALSE - the API's spelling. d[[""]] is NULL, so
  # the assignment failed and the caller's tryCatch turned a routine
  # spreadsheet export with an unnamed index column into "could not read
  # this as a template or journal-style table". By position it is also
  # correct for duplicated headers.
  # the names are already decoded on the frame above, so this fold is
  # safe (screen 2026-09-09-1532 F4, completed by 2026-09-10-0536 F2)
  nms <- toupper(trimws(names(d)))
  for (j in seq_along(d)) {
    if (nms[j] %in% keepText) next
    v <- trimws(d[[j]])
    blank <- is.na(v) | v == ""
    num <- suppressWarnings(as.numeric(v))
    # a column is numeric only if every non-blank cell reads as a number;
    # one stray word and it stays text, exactly as read.csv would have
    # left it, so the validator still paints that cell unreadable
    if (!length(v) || !all(blank | !is.na(num))) next
    num[blank] <- NA_real_
    d[[j]] <- num
  }
  d
}

.iaCellKey <- function(trial, row) {
  t <- as.character(trial); r <- as.character(row)
  t[is.na(t)] <- ""; r[is.na(r)] <- ""
  paste0(nchar(t, type = "bytes"), "\r", t, "\r",
         nchar(r, type = "bytes"), "\r", r)
}

.iaDerivedPayload <- function(d, dv, nameCols = names(d)) {
  empty <- list(iss = list(), note = list())
  if (is.null(dv) || !nrow(dv) || is.null(d) || !nrow(d)) return(empty)
  codeOf <- function(k) if (is.null(k) || is.na(k)) "derived"
    else if (k == "ocr") "ocr" else if (k == "failsafe") "failsafe" else "derived"
  trialD <- as.character(d$TRIAL); rowD <- as.character(d$ROW)
  keys <- character(0); codes <- character(0); notes <- character(0)
  # the registry position each painted cell came from, so that the entry
  # LATER in the registry wins a shared cell whichever kind it is - the
  # addressed entries are gathered before the whole-trial ones, and
  # without this an earlier "*" entry would overwrite a later addressed
  # one (CodeRabbit on PR #225)
  froms <- integer(0)

  addCells <- function(rows, i) {
    cis <- if (identical(dv$COL[i], "*")) seq_along(nameCols)
           else match(dv$COL[i], nameCols)
    cis <- cis[!is.na(cis)]
    for (ci in cis) {
      # paint only cells that carry a value - a green empty cell would
      # read as "this blank is fine", which is the opposite of true
      keep <- rows[!is.na(d[rows, ci])]
      if (!length(keep)) next
      keys  <<- c(keys,  paste0(keep - 1L, "|", ci - 1L))
      codes <<- c(codes, rep(codeOf(dv$KIND[i]), length(keep)))
      notes <<- c(notes, rep(dv$note[i], length(keep)))
      froms <<- c(froms, rep(i, length(keep)))
    }
  }

  # THE ADDRESSED ENTRIES, found by one match() rather than one scan of the
  # whole grid each (security screen 2026-09-07-2339, finding F3: the
  # previous rewrite removed the per-cell insert but kept the per-entry
  # scan, so the cost was still the product of the registry and the grid
  # and only the registry was capped). The LAST entry for a key wins, as
  # the per-cell overwrite did.
  addr <- which(dv$ROW != "*")
  if (length(addr)) {
    keyD <- .iaCellKey(trialD, rowD)
    keyR <- .iaCellKey(dv$TRIAL[addr], dv$ROW[addr])
    idx  <- length(addr) + 1L - match(keyD, rev(keyR))     # index into addr, or NA
    # one pass to group the grid rows by the entry that claims them; a
    # `which()` per group would be a scan of the grid per entry again
    # (CodeRabbit on PR #225)
    seen <- which(!is.na(idx))
    for (g in split(seen, idx[seen]))
      addCells(g, addr[idx[g[1]]])
  }

  # ...and the whole-trial entries, which are few - one per OCR-read or
  # arm-N-recovered file - and each addresses every row of its trial
  for (i in which(dv$ROW == "*")) {
    rows <- which(trialD == dv$TRIAL[i])
    if (length(rows)) addCells(rows, i)
  }

  if (!length(keys)) return(empty)
  # in REGISTRY order, so the last entry to name a cell wins it
  ord <- order(froms)
  keys <- keys[ord]; codes <- codes[ord]; notes <- notes[ord]
  keep <- !duplicated(keys, fromLast = TRUE)
  keys <- keys[keep]; codes <- codes[keep]; notes <- notes[keep]
  iss <- as.list(codes);  names(iss)  <- keys
  note <- as.list(notes); names(note) <- keys
  list(iss = iss, note = note)
}

# The grid payload for the skip registry: which rows carry the "unreadable"
# mark and its hover text. Two versions of this ran quadratically inside
# the upload observer - the first scanned the whole frame per registry
# entry, the second used a list-name lookup, which is a linear search
# because R hashes environments and not list names, and grew the payload
# one `[[<-` at a time (screens 2026-09-07-2000 F3 and -2101 F3, the
# second of which measured both and found the "linear" claim false). This
# is match() plus one bulk assignment, and it is a function so that a test
# can measure it.
.iaSkipPayload <- function(d, sk, dataCols, rowCol) {
  empty <- list(iss = list(), note = list())
  if (is.null(sk) || !nrow(sk) || is.null(d) || !nrow(d)) return(empty)
  keyD  <- .iaCellKey(d$TRIAL, d$ROW)
  keySk <- .iaCellKey(sk$TRIAL, sk$ROW)
  emptyRow <- if (length(dataCols))
    !Reduce(`|`, lapply(d[dataCols], function(v) !is.na(v))) else rep(TRUE, nrow(d))
  # the LAST registry entry for a key wins, which is what the per-entry
  # loop did by overwriting as it went
  idx <- length(keySk) + 1L - match(keyD, rev(keySk))
  hit <- emptyRow & !is.na(idx)
  if (!any(hit)) return(empty)
  keys <- paste0(which(hit) - 1L, "|", rowCol - 1L)
  iss  <- as.list(rep("unreadable", sum(hit)));  names(iss)  <- keys
  note <- as.list(paste0(
    "The PDF reader saw this table line but could not use it: ",
    sk$reason[idx[hit]]));                       names(note) <- keys
  list(iss = iss, note = note)
}

# ...and the capping itself, a function rather than a block inside the
# upload observer so that a test can call what the app calls (screen
# 2026-09-07-1907, A1). The marker row is built FROM the frame: the
# parser's skipped frame carries three columns (label, reason, text), and
# a two-column literal raised "undefined columns selected" on exactly the
# documents the cap exists for (screen 1907, F3).
# A marker row is recognised by its REASON, which the parser writes from
# its own vocabulary, never by its label, which is the document's own text
# (security screen 2026-09-07-2241, finding F4: a sheet with a row labelled
# "... continued" had that row filtered out of the frame and mis-counted).
.iaSkipMarkerReason <- "the list of unusable lines is capped"
.iaIsSkipMarker <- function(sk) {
  # vectorised over the frame's rows: `&&` would fold it to one value and
  # error on a frame of more than one row
  if (is.null(sk) || !nrow(sk) || is.null(sk$reason)) return(logical(0))
  !is.na(sk$reason) & sk$reason == .iaSkipMarkerReason
}

.iaCapSkipped <- function(skipped, cap = .iaMaxSkippedRows) {
  if (is.null(skipped) || !nrow(skipped) || nrow(skipped) <= cap) return(skipped)
  n <- nrow(skipped)
  out <- skipped[seq_len(cap), , drop = FALSE]
  mk <- skipped[1, , drop = FALSE]
  mk[] <- NA_character_
  mk$label  <- sprintf("... %d further unusable line(s) not shown", n - cap)
  mk$reason <- .iaSkipMarkerReason
  out <- rbind(out, mk)
  rownames(out) <- NULL
  out
}

# THE LONG CATEGORICAL LAYOUT (Steve, 2026-09-05: "would it be more
# logical on the input spreadsheet to use the column N for categorical
# variables ... As it is, the spreadsheet becomes quite wide when there
# are many categories"; and: "add the new format while retaining the old
# format so that both can be parsed"). A categorical variable may be
# entered one line per LEVEL per arm - ROW = the variable, LEVEL = the
# category, N = the count, MEAN and SD blank - instead of one line per
# arm with a column per level. This converts the long lines into the
# wide rows every downstream consumer expects (validateData's checks,
# P_Calc's category columns, the grid, the workbook), so the rest of the
# code sees one layout. Arms are the lines sharing TRIAL, ROW and LEVEL,
# in file order - the same rule as for continuous lines - so a file may
# list all of one arm's levels together or all arms of one level
# together. A level's count column is the level name in upper case; a
# name that collides with a base column ("N", "MEAN") is prefixed with
# the variable's. Lines without a LEVEL pass through untouched; a file
# without a LEVEL column is returned as it came.
.iaMaxLevelColumns <- 200L   # the wide table the long layout may build: .apiMaxCols

# THE TEMPLATE ROUTE'S CELLS ARE BOUNDED TOO (security screen
# 2026-09-10-2047, F2). The journal-style reader caps and clips its cells;
# the template reader - which the wide reader falls through to whenever it
# returns NULL - wrote every cell verbatim into the reply. An xlsx stores a
# repeated string once, so the inflation preflight passed; R's string cache
# kept the frame small, so the row and column gates passed; then the
# template CSV materialised rows x columns x length: a 130 KB workbook of
# 5,000 rows with one 30 KB text column came back as a 150 MB reply
# (611 MB peak), and 500 rows x 194 such columns ran write.csv for 325 s
# before failing on R's 2^31 byte limit. So a template frame is refused,
# on both routes, when any cell is longer than .ppMaxCellChars (2,000, the
# other readers' cap) or the text it holds exceeds .iaMaxTableTextBytes
# (20 MB - a baseline table is under one), before anything is written.
.iaMaxTableTextBytes <- 20000000L
.iaTableTextRefusal <- function(d) {
  if (is.null(d) || !nrow(d) || !ncol(d)) return(NULL)
  # the column NAMES are cells too - header cells on the template route,
  # copied into every issue that names the column (screen 2149, F2)
  nn <- nchar(names(d), type = "bytes"); nn[is.na(nn)] <- 0L
  if (any(nn > .ppMaxCellChars))
    return(sprintf("a column name of %d characters; the limit is %d", max(nn), .ppMaxCellChars))
  chr <- vapply(d, function(x) is.character(x) || is.factor(x), logical(1))
  if (!any(chr)) return(NULL)
  total <- 0
  for (j in which(chr)) {
    n <- nchar(as.character(d[[j]]), type = "bytes")
    n[is.na(n)] <- 0L
    if (any(n > .ppMaxCellChars))
      return(sprintf(paste("a cell of %d characters in column '%s'; the limit is %d -",
                           "a baseline table's cells are numbers and short labels"),
                     max(n), substr(names(d)[j], 1, 60), .ppMaxCellChars))
    total <- total + sum(n)
    if (total > .iaMaxTableTextBytes)
      return(sprintf(paste("the table holds more than %d MB of text; the limit is %d MB -",
                           "a baseline table holds well under one"),
                     round(total / 1e6), .iaMaxTableTextBytes %/% 1000000L))
  }
  NULL
}
.iaLongToWide <- function(DATA) {
  if (is.null(DATA) || !("LEVEL" %in% names(DATA)) || !("ROW" %in% names(DATA)))
    return(DATA)
  # A FRAME WITH A DUPLICATED HEADER IS RETURNED AS IT CAME (security
  # screen 2026-09-10-1554, F1). The build below selects columns BY NAME
  # (W[, names(DATA)]), and R resolves a duplicated name to its first
  # column, so a long-layout file with the header N twice came out as N
  # and N.1 - the second N's values dropped from the counts, the frame
  # passing the duplicate-name refusal that runs after this conversion,
  # and the sheet analysed with a column silently chosen. Left untouched,
  # the frame reaches that refusal with both headers in place and is
  # refused structurally, the template carrying the sheet as received
  # (the guarantee of the 2026-08-29 F2 fix and of the 2026-09-10 S1
  # fix: refuse rather than pick).
  if (length(.iaDuplicateNames(DATA))) return(DATA)
  lv <- trimws(as.character(DATA$LEVEL))
  isLevel <- !is.na(lv) & nzchar(lv)
  if (!any(isLevel)) { DATA$LEVEL <- NULL; return(DATA) }
  if (!("TRIAL" %in% names(DATA))) DATA$TRIAL <- 1
  base <- c("TRIAL", "ROW", "N", "MEAN", "SD", "SE", "Q1", "Q3", "LEVEL",
            "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION")
  key <- paste(DATA$TRIAL, DATA$ROW, sep = "\r")
  levelKeys <- unique(key[isLevel])
  # the count column for each (variable, level): the level in upper case,
  # like a wide file's headers - unless that would be a base column or
  # would contain one of the substrings the normaliser and validateData
  # grep for (a level "Obstetric" would be taken for an OBSERVATION
  # rounding column; "Brown" for ROW), in which case the variable's name
  # and the level, in lower case, which no upper-case grep can match
  tokens <- "TRIAL|MEASURE|DECM|NUMBER|GROUP|ROW|MEAN|OBS|LEVEL|CATEGORY"
  colOf <- function(row, level) {
    nm <- toupper(level)
    if (nm %in% base || grepl(tokens, nm)) nm <- tolower(paste(row, level))
    nm
  }
  # THE GATE COMES FIRST (security screen 2026-09-06-1749, F1). The
  # previous build assigned one data.frame cell at a time - keys x new
  # columns `[[<-` calls, an n x n frame, thousands of one-row rbinds -
  # and was cubic in time and quadratic in memory: a 100 KB CSV of 1,000
  # all-distinct (ROW, LEVEL) lines took 91 s and 219 MB, and 5,000 lines
  # (the API's row limit) extrapolated to three hours on the single
  # plumber thread, before any downstream gate had seen the frame. The
  # wide table's width is known from the raw lines alone, so it is
  # counted and refused BEFORE anything is built: a real categorical
  # variable has a handful of levels, and a file whose long lines would
  # need more count columns than the API admits (.iaMaxLevelColumns, the
  # same 200 as .apiMaxCols) is not a baseline table. The build itself is
  # then one indexed matrix and one rbind, linear in the lines.
  li <- which(isLevel)
  cn <- vapply(li, function(i) colOf(DATA$ROW[i], lv[i]), character(1))
  newCols <- unique(cn)
  if (length(newCols) > .iaMaxLevelColumns)
    stop(sprintf(paste("the long layout would need %d count columns (one per",
                       "distinct level); the limit is %d - a baseline table's",
                       "categorical variables have a handful of levels each"),
                 length(newCols), .iaMaxLevelColumns))
  # the arm of each level line: its position among the lines of the same
  # (variable, level), in file order - the same rule as before
  arm <- stats::ave(seq_along(li), paste(key[li], lv[li], sep = "\r"), FUN = seq_along)
  # one wide row per (variable, arm), carrying the variable's first line
  # (its TRIAL, ROW, any extra columns) with the measurement columns blank
  keyFirst <- tapply(li, key[li], min)
  nArms    <- tapply(arm, key[li], max)
  keys     <- names(keyFirst)[order(keyFirst)]
  keyFirst <- keyFirst[keys]; nArms <- nArms[keys]
  W <- DATA[rep(keyFirst, nArms), , drop = FALSE]
  wideKey <- rep(keys, nArms)
  wideArm <- unlist(lapply(nArms, seq_len), use.names = FALSE)
  W$N <- NA_real_; W$LEVEL <- NA
  for (cc in intersect(c("MEAN", "SD", "SE", "Q1", "Q3", "ROUND_MEAN", "ROUND_DISPERSION", "ROUND_OBSERVATION"), names(W)))
    W[[cc]] <- NA
  # the counts, placed by (wide row, count column) in one indexed
  # assignment; a later line for the same cell wins, as the loop did
  M <- matrix(NA_real_, nrow(W), length(newCols), dimnames = list(NULL, newCols))
  ri <- match(paste(key[li], arm, sep = "\r"), paste(wideKey, wideArm, sep = "\r"))
  M[cbind(ri, match(cn, newCols))] <- suppressWarnings(as.numeric(DATA$N[li]))
  # every count column exists on every row, NA where a variable does not use it
  for (j in seq_along(newCols)) {
    if (!(newCols[j] %in% names(DATA))) DATA[[newCols[j]]] <- NA_real_
    W[[newCols[j]]] <- M[, j]
  }
  # rebuild in file order: continuous lines as they are, each variable's
  # wide rows where its first line stood, arms in order
  cont <- DATA[!isLevel, , drop = FALSE]
  pos  <- c(which(!isLevel), keyFirst[wideKey] + wideArm / (max(wideArm) + 1))
  out  <- rbind(cont, W[, names(DATA), drop = FALSE])
  out  <- out[order(pos), , drop = FALSE]
  rownames(out) <- NULL
  out$LEVEL <- NULL
  # the columns this layout created are categories by construction; the
  # attribute lets validateData accept them even when every row of the
  # file is categorical and no count column has an NA to prove it by
  attr(out, "iaLevelColumns") <- newCols
  out
}

# THE MONTE CARLO SEED (Steve, 2026-09-05, answering an outside review
# that saw the same table land on both sides of 0.05 across runs: "The
# Monte Carlo results should not return identical results unless the
# seed is fixed. The seed is not fixed ... allow a command line argument
# in the web application, and an argument in the API, that permits the
# user to set a seed."). Unseeded, the draws differ from run to run
# within the reported Monte Carlo interval, which is what a simulation
# should do. With a seed - the page's ?seed=12345, run_app(seed =), or
# the API's seed field - the same table, the same seed and the same
# build give the same numbers. Both generators are seeded: P_Calc draws
# with base R's rnorm and with dqrng's dqrnorm / dqrunif.
.iaSeedValue <- function(x) {
  if (is.null(x) || !length(x)) return(NULL)
  v <- suppressWarnings(as.numeric(trimws(as.character(x[1]))))
  if (length(v) != 1L || !is.finite(v) || v < 1 || v > 2147483647 || v %% 1 != 0)
    return(NULL)
  as.integer(v)
}
.iaSetSeed <- function(seed) {
  set.seed(seed); dqrng::dqset.seed(seed)
  invisible(seed)
}

# After normalizing, two source columns can collapse onto one name (a
# frame carrying both NUMBER and N ends with two called N). R's $ and
# [[ ]] silently take the FIRST, so the reader and the writer can
# disagree about which column they mean. Refuse instead of guessing.
.iaDuplicateNames <- function(DATA) {
  if (is.null(DATA) || !length(names(DATA))) return(character(0))
  nm <- names(DATA)
  unique(nm[duplicated(nm)])
}
