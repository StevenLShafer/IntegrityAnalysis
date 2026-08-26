# downloadPreprintRCTs.R - build a stress-test corpus of randomized
# controlled trial preprints from medRxiv (or bioRxiv), into C:/temp.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5), 2026-08-25,
# at Steve Shafer's request (ISSUES.md issue 21). Run and verified the
# same day against a one-week medRxiv window; the first real harvest's
# outcome is recorded in the issue.
#
# WHY: the journal corpora carry ground truth (Carlisle's values) but a
# fixed range of layouts. Preprints are the opposite deal: no ground
# truth at all, but a firehose of AUTHOR-typeset PDFs - Word exports,
# LaTeX, every table habit in the wild, no copyeditor - which is exactly
# where parser crashes, hangs, and layout blind spots hide. The corpus
# this builds is for hunting those (feed it to
# corpus/buildParseOutcomes.R); it can never validate values.
#
# WHAT THIS DOWNLOADS - AND WHY IT IS ALLOWED: medRxiv and bioRxiv are
# preprint servers whose content is posted to be read and machine-mined;
# they publish an open metadata API (api.biorxiv.org) and every record
# carries the license the authors chose. This script walks the API for
# an interval, keeps records whose title or abstract says randomized
# trial, and fetches each PDF at a polite one request per second,
# recording the DOI, version, category, and LICENSE per file in
# manifest.csv - so what the corpus contains, and under what terms, is
# always explicit. The corpus lives under C:/temp and is NEVER committed
# (same rule as every other corpus; see corpus/README.md).
#
# Usage:
#   "C:\Program Files\R\R-4.5.3\bin\Rscript.exe" corpus/downloadPreprintRCTs.R \
#       [server] [from] [to] [maxPapers] [outDir]
#
#   server     medrxiv (default) or biorxiv. RCTs live almost entirely
#              on medRxiv; the bioRxiv option exists because the two
#              share one API.
#   from, to   date interval, YYYY-MM-DD (default: the last 12 months).
#   maxPapers  stop after this many NEW PDFs in THIS run (default 300)
#              - the per-run batch size, which is what makes a nightly
#              scheduled run a bounded trickle.
#   outDir     default C:/temp/medrxiv_rct (or biorxiv_rct).
#   pauseSec   seconds between PDF fetches (default 6, plus jitter).
#
# Resumable: re-running skips DOIs already resolved in the manifest.
#
# GENTLENESS (Steve's requirement, 2026-08-25): medRxiv is a nonprofit
# community resource, and this corpus has no deadline. The harvester
# runs as a trickle - one metadata page per second, one PDF per
# pauseSec (default 6 s; the standing nightly task uses 120 s), a
# jitter so requests never metronome, and an identifying user agent
# with a contact address so their operators can see who we are and
# write to us. If medRxiv ever rate-limits or 429s, raise pauseSec
# rather than adding retries.
#
# CONTINUOUS OPERATION (Steve's design, 2026-08-25: "it could run
# continuously on this machine over a period of several weeks. Or
# more"): the metadata scan is cached per (server, interval) in
# candidates.csv + scanState.csv inside outDir, so only the FIRST run
# walks the API - every later run goes straight to downloading the
# next batch of not-yet-fetched candidates and stops at maxPapers.
# Re-run the script daily (Task Scheduler) with a modest cap and a
# long pause, and the corpus grows by a gentle nightly batch until the
# candidate list is exhausted. To pick up preprints POSTED SINCE the
# cached scan, run once with a new interval into the same outDir: the
# cache keys on the interval, so a new interval triggers a fresh scan
# whose novel DOIs simply join the candidate list.
#
# WHAT COUNTS AS AN RCT HERE: title or abstract matches
# "randomized/randomised" near "trial", minus titles announcing a
# protocol, systematic review, meta-analysis, or secondary/post-hoc
# analysis - those either have no baseline table or someone else's.
# This is a heuristic net, not a classification: a few non-RCTs getting
# through costs nothing in a corpus with no ground truth.

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
})

args   <- commandArgs(trailingOnly = TRUE)
server <- if (length(args) >= 1) tolower(args[1]) else "medrxiv"
if (!server %in% c("medrxiv", "biorxiv"))
  stop("server must be medrxiv or biorxiv")
to     <- if (length(args) >= 3) args[3] else format(Sys.Date(), "%Y-%m-%d")
from   <- if (length(args) >= 2) args[2] else
  format(Sys.Date() - 365, "%Y-%m-%d")
maxN   <- if (length(args) >= 4) as.integer(args[4]) else 300L
outDir <- if (length(args) >= 5) args[5] else
  file.path("C:/temp", paste0(server, "_rct"))
pauseSec <- if (length(args) >= 6) as.numeric(args[6]) else 6
dir.create(outDir, showWarnings = FALSE, recursive = TRUE)
manifestPath <- file.path(outDir, "manifest.csv")
host <- paste0("https://www.", server, ".org")

cat("Server:", server, " interval:", from, "..", to,
    " cap:", maxN, "\nOutput:", outDir, "\n")

manifest <- if (file.exists(manifestPath))
  read.csv(manifestPath, colClasses = "character") else
  data.frame(doi = character(), version = character(),
             date = character(), category = character(),
             license = character(), title = character(),
             status = character(), file = character(),
             stringsAsFactors = FALSE)
saveManifest <- function() write.csv(manifest, manifestPath,
                                     row.names = FALSE)

rctPattern  <- paste0(
  "(?i)randomi[sz]ed[- ][^.]{0,60}\\btrial\\b|randomi[sz]ed controlled trial",
  # "randomized, controlled study" and kin - CONSORT prefers "trial", but
  # real RCT titles say "study" often enough to cost us candidates
  "|randomi[sz]ed,?\\s+controlled\\s+stud(?:y|ies)",
  "|\\bRCT\\b")
dropPattern <- paste0("(?i)\\bprotocol\\b|systematic review|meta-analys",
                      "|\\bpost.?hoc\\b|secondary analysis")

# The first harvest night (2026-08-26) let two non-RCTs through, both the
# same way: their ABSTRACTS mention the randomized trial their patients
# came from (10.1101/19008268, a DBS imaging analysis of trial enrollees;
# 10.1101/19007195, an EHR cohort compared against published RCT rates),
# while rctPattern was tested against title+abstract and dropPattern
# against the title only. Steve's diagnosis. Two repairs:
#
# - a title hit still qualifies on its own (CONSORT titles say
#   "randomized controlled trial", and titles do not cite other trials);
# - an abstract-only hit must ALSO describe randomization in the active
#   voice - the way a trial reports its own methods ("participants were
#   randomly assigned to ...") - not merely mention a trial, and must not
#   look like an analysis OF another study's enrollees.
#
# Referential mentions ("enrolled in a randomized trial of X",
# "compared with rates reported in RCTs") match neither active pattern
# and are excluded. Imperfect by design - a secondary analysis that
# reprints its parent's methods sentence still slips through - but each
# leak costs only one harmless stress-test PDF.
activePattern    <- paste0(
  "(?i)\\b(?:were|was|are|is)\\s+randoml?y\\s+(?:assigned|allocated|",
  "divided|distributed)\\b",
  "|\\b(?:were|was)\\s+randomi[sz]ed\\s+(?:to|into|in\\s+a)\\b",
  "|\\bwe\\s+randoml?y\\s+(?:assigned|allocated)\\b",
  "|\\bwe\\s+(?:conducted|performed|carried\\s+out|report)\\s+",
  "[^.]{0,80}\\brandomi[sz]ed\\b",
  "|\\bin\\s+this\\s+[^.]{0,60}\\brandomi[sz]ed\\b",
  "|\\bthis\\s+randomi[sz]ed\\b",
  # design self-descriptions: "randomized, double-blinded, phase IIb",
  # "double-blind randomized", "randomized parallel-group" - the way an
  # abstract describes its OWN methods (a referential mention names the
  # parent trial instead: "a randomized trial of X")
  "|\\brandomi[sz]ed,?\\s+(?:double|single|triple|placebo|parallel|",
  "open|blind|sham)[- ]",
  "|\\b(?:double|single|triple)[- ]blind(?:ed)?,?\\s+randomi[sz]ed\\b")
secondaryPattern <- paste0(
  "(?i)\\bsub-?stud(?:y|ies)\\b|\\bancillary\\s+stud",
  "|\\bnested\\s+(?:case|within|in)\\b",
  "|\\b(?:enrolled|participants|patients|subjects|data|sample)\\b",
  "[^.]{0,40}\\b(?:in|from|of)\\s+(?:a|the|an?\\s+ongoing)\\s+",
  "[^.]{0,60}\\brandomi[sz]ed\\b")

# ---- walk the metadata API ---------------------------------------------
# One page per call, 100 records each, cursor-paginated. Every VERSION of
# a preprint is a record; the newest version wins (its PDF supersedes).
apiPage <- function(cursor) {
  url <- sprintf("https://api.biorxiv.org/details/%s/%s/%s/%d",
                 server, from, to, cursor)
  resp <- request(url) |>
    req_user_agent("IntegrityAnalysis corpus builder (steveshafer@gmail.com)") |>
    req_retry(max_tries = 3) |>
    req_perform()
  fromJSON(resp_body_string(resp), simplifyDataFrame = TRUE)
}

# The scan is cached: a completed walk of this (server, interval) never
# repeats. candidates.csv accumulates across intervals; scanState.csv
# records which intervals have been fully walked.
candPath  <- file.path(outDir, "candidates.csv")
statePath <- file.path(outDir, "scanState.csv")
candidates <- if (file.exists(candPath))
  read.csv(candPath, colClasses = "character") else
  data.frame(doi = character(), version = character(),
             date = character(), category = character(),
             license = character(), title = character(),
             stringsAsFactors = FALSE)
scanState <- if (file.exists(statePath))
  read.csv(statePath, colClasses = "character") else
  data.frame(server = character(), from = character(), to = character(),
             stringsAsFactors = FALSE)
scanDone <- any(scanState$server == server & scanState$from == from &
                  scanState$to == to)

if (scanDone) {
  cat("Scan of", server, from, "..", to, "already cached (",
      nrow(candidates), "candidate(s) on file).\n")
} else {
  wanted <- list()   # doi -> record (newest version)
  cursor <- 0L
  repeat {
    page <- tryCatch(apiPage(cursor), error = function(e) NULL)
    if (is.null(page) || length(page$collection) == 0) break
    col <- page$collection
    txt      <- paste(col$title, col$abstract)
    titleHit <- grepl(rctPattern, col$title, perl = TRUE)
    # abstract-only qualification: active-voice randomization, and not an
    # analysis of some other study's enrollees (see the pattern comments)
    absHit   <- grepl(rctPattern, txt, perl = TRUE) &
      grepl(activePattern, col$abstract, perl = TRUE) &
      !grepl(secondaryPattern, col$abstract, perl = TRUE)
    # dropPattern stays TITLE-only: nearly every genuine trial abstract
    # contains "protocol" (the ethics-approval sentence), so testing it
    # against the abstract would drop real RCTs wholesale.
    hit <- (titleHit | absHit) &
      !grepl(dropPattern, col$title, perl = TRUE)
    for (i in which(hit)) {
      doi <- col$doi[i]
      v   <- suppressWarnings(as.integer(col$version[i]))
      old <- wanted[[doi]]
      if (is.null(old) || isTRUE(v > old$version))
        wanted[[doi]] <- list(doi = doi, version = v, date = col$date[i],
                              category = col$category[i],
                              license = col$license[i],
                              title = col$title[i])
    }
    total <- suppressWarnings(as.integer(page$messages$total[1]))
    cursor <- cursor + nrow(col)
    cat("\rscanned", cursor, "of", total, "records;",
        length(wanted), "RCT candidate(s)   ")
    if (is.na(total) || cursor >= total) break
    Sys.sleep(1)
  }
  cat("\n")
  new <- Filter(function(w) !w$doi %in% candidates$doi, wanted)
  if (length(new) > 0)
    candidates <- rbind(candidates, do.call(rbind, lapply(new, function(w)
      data.frame(doi = w$doi, version = as.character(w$version),
                 date = w$date, category = w$category,
                 license = w$license,
                 title = substr(gsub("[\r\n]+", " ", w$title), 1, 200),
                 stringsAsFactors = FALSE))))
  write.csv(candidates, candPath, row.names = FALSE)
  scanState <- rbind(scanState, data.frame(server = server, from = from,
                                           to = to,
                                           stringsAsFactors = FALSE))
  write.csv(scanState, statePath, row.names = FALSE)
  cat("Scan complete and cached:", nrow(candidates),
      "candidate(s) total.\n")
}

# ---- download the PDFs, politely ---------------------------------------
todo <- lapply(which(!candidates$doi %in% manifest$doi), function(i)
  list(doi = candidates$doi[i],
       version = suppressWarnings(as.integer(candidates$version[i])),
       date = candidates$date[i], category = candidates$category[i],
       license = candidates$license[i], title = candidates$title[i]))
cat(nrow(candidates), "candidate(s);", length(todo), "not yet in the",
    "manifest.\n")
got <- 0L   # this RUN's batch; the manifest carries the total
for (w in todo) {
  if (got >= maxN) break
  fname <- paste0(gsub("[^A-Za-z0-9.]+", "_", w$doi), ".pdf")
  dest  <- file.path(outDir, fname)
  url   <- sprintf("%s/content/%sv%d.full.pdf", host, w$doi, w$version)
  status <- tryCatch({
    request(url) |>
      req_user_agent("IntegrityAnalysis corpus builder (steveshafer@gmail.com)") |>
      req_retry(max_tries = 2) |>
      req_perform(path = dest)
    # a soft-404 comes back as HTML; a real PDF starts with %PDF
    if (file.exists(dest) &&
        identical(readBin(dest, "raw", 4), charToRaw("%PDF"))) {
      got <- got + 1
      "downloaded"
    } else {
      unlink(dest)
      "not_a_pdf"
    }
  }, error = function(e) {
    unlink(dest)
    paste0("error: ", substr(conditionMessage(e), 1, 80))
  })
  manifest <- rbind(manifest, data.frame(
    doi = w$doi, version = as.character(w$version), date = w$date,
    category = w$category, license = w$license,
    title = substr(gsub("[\r\n]+", " ", w$title), 1, 200),
    status = status,
    file = if (status == "downloaded") fname else "",
    stringsAsFactors = FALSE))
  saveManifest()
  cat(sprintf("[%d/%d] %s %s\n", got, maxN, status, w$doi))
  Sys.sleep(pauseSec + stats::runif(1, 0, 2))   # trickle, with jitter
}
saveManifest()
cat("Done:", sum(manifest$status == "downloaded"), "PDF(s) in", outDir,
    "\nNext: Rscript corpus/buildParseOutcomes.R", outDir,
    file.path(outDir, "parse_work"), "\n")
