# safeMatch.R - match() that refuses to join on a missing key.
#
############################################################################
# Provenance                                                               #
# Written 2026-09-01 by Claude Code (model Claude Opus 5) at Steve         #
# Shafer's request, as the join audit called for in the 2026-08-31         #
# handoff. The function itself is not new: it was written on 2026-08-31    #
# in corpus/buildCorpusLibrary.R and copied by hand into                   #
# corpus/fetchCorpusIdentity.R. Two copies of a safety rule is one copy    #
# too many - the audit found five more scripts that needed it, and a       #
# seventh hand-copy would have been the defect rather than the fix.        #
# This file is the single canonical definition; both originals now        #
# source() it.                                                             #
# LOCAL CORPUS TOOLING ONLY - nothing here ships in the app.               #
#                                                                          #
# WHAT GOES WRONG WITHOUT IT                                               #
#                                                                          #
# match(x, table) resolves a MISSING key like any other value: match(NA,   #
# table) returns the position of the first NA in table, and match("",      #
# table) the position of the first "". Those are real indices, not         #
# misses. So a join whose left key can be blank does not fail loudly - it  #
# silently attaches one arbitrary row's data to every unidentified record  #
# on the left, and the coverage figure goes UP.                            #
#                                                                          #
# It did exactly that on 2026-08-31. pmidToPmcid.csv holds 24,541 rows of  #
# which 11,428 have an EMPTY PMCID (PMIDs with no PMC record). A plain     #
# match(ident$PMCID, m$PMCID) gave every work WITHOUT a PMCID - including  #
# all 3,149 confidential A&A peer-review manuscripts - one unrelated       #
# paper's PMID. EFetch then filled in that stranger's journal, title and   #
# authors, and the coverage report read 17,035/17,035. A perfect score,    #
# entirely wrong, and a confidentiality breach in the same stroke.         #
#                                                                          #
# THE PRECONDITION, stated exactly, because it decides where this is       #
# needed: the failure requires a blank on the LEFT *and* a blank in the    #
# table. A join keyed on something that cannot be blank - a filename, a    #
# literal, a paste()d composite - cannot hit it, whatever the table        #
# contains. That is why corpus/buildParseOutcomes.R (keyed on PDF name)    #
# is fine while corpus/buildFraudDownloadList.R (keyed on a PMID that      #
# line 45 deliberately sets to NA) was not.                                #
#                                                                          #
# WHY IT IS SAFE TO APPLY EVERYWHERE. safeMatch differs from match ONLY    #
# on blank keys, and only ever by returning NA where match returned an     #
# index. It can turn a wrong join into a missing one; it can never turn a  #
# right join into a wrong one. So there is no case where a data-keyed      #
# join is better off with plain match(), and reviewing a script is        #
# cheaper when every join in it reads the same way.                        #
#                                                                          #
# Usage:                                                                   #
#   source(file.path(root, "corpus", "safeMatch.R"))                       #
#   i <- safeMatch(left$PMID, right$PMID)                                  #
#   out$JOURNAL <- ifelse(is.na(i), NA_character_, right$JOURNAL[i])       #
#                                                                          #
# Review status: the two prior in-line copies were reviewed on the         #
# 2026-08-31 PRs (#132, #133) and have run against the whole library.      #
# This consolidation adds only the as.character() coercion, so that a      #
# factor or numeric key is tested for blankness the same way a character   #
# one is.                                                                  #
############################################################################

# TRUE for keys that carry no information: NA, or the empty string. Both
# are "we do not know", and neither may be allowed to join.
iaBlankKey <- function(v) is.na(v) | !nzchar(as.character(v))

safeMatch <- function(x, table) {
  i <- match(x, table)
  # A blank on the left is a miss, whatever it happened to find.
  i[iaBlankKey(x)] <- NA_integer_
  # ...and so is a hit that landed on a blank row of the table. (Reached
  # only when x itself is blank, so this is belt-and-braces - but it is
  # the line that makes the guarantee independent of how x was built.)
  i[!is.na(i) & iaBlankKey(table[i])] <- NA_integer_
  i
}
