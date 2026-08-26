# rctFilterPatterns.R - the ONE definition of "what counts as an RCT"
# for the preprint harvesters. Sourced by downloadPreprintRCTs.R (the
# api.biorxiv.org metadata route) and harvestMedrxivS3.R (the
# requester-pays S3 route), so a filter improvement reaches both.
#
# PROVENANCE: extracted verbatim 2026-08-26 by Claude Code (model Claude
# Fable 5) from downloadPreprintRCTs.R when the S3 route was added; the
# patterns themselves date to PR #66 (2026-08-25) as repaired in PR #74
# (Steve's 19008268 catch - see the comments below and that PR for the
# 72-candidate empirical replay: 47 kept, 25 referential papers dropped,
# every checked real RCT retained).

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


# Scalar convenience for callers that inspect one document at a time
# (the S3 route, which reads title and abstract out of each package's
# JATS XML). The metadata-scan route keeps its own vectorized use of
# the patterns - same rules, page-at-a-time.
classifyRct <- function(title, abstract) {
  title    <- if (is.null(title) || is.na(title)) "" else title
  abstract <- if (is.null(abstract) || is.na(abstract)) "" else abstract
  txt <- paste(title, abstract)
  titleHit <- grepl(rctPattern, title, perl = TRUE)
  absHit <- grepl(rctPattern, txt, perl = TRUE) &&
    grepl(activePattern, abstract, perl = TRUE) &&
    !grepl(secondaryPattern, abstract, perl = TRUE)
  (titleHit || absHit) && !grepl(dropPattern, title, perl = TRUE)
}
