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
# 1,000 -> 10,000 -> m, escalating only while the running mid-p is
# < 0.01, so a typical (unalarming) row costs 1,000 replicates - CHEAPER
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
# ORDER MATTERS and mirrors validateData's original sequence exactly:
# uppercase, TRIAL, MEASURE (with its drops), DECM, NUMBER, GROUP->ROW
# fallback, then the ROW grep. Changing the order changes which column
# wins when several match.
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

  DATA
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
