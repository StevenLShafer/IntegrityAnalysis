# test-broken-number-is-no-arm-size.R - a size whose digits are followed by
# a space and more digits ("N = 1 20") is a number the text layer has
# broken, and no arm size (ISSUES.md issue 144, 2026-09-27).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-27 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's arm-count audit (Anesth Analg 2005, PMID 15978307): the #
# caption's "(N = 120)" came through as "(N = 1 20)", "N = 1" matched the  #
# arm names, and all four arms took an N of 1.                             #
############################################################################

test_that("a broken size is dropped from the document candidates and a whole one kept", {
  txt <- paste("Pain on propofol injection after preventive treatment with flurbiprofen axetil or vehicle",
               "(control group) (N = 1 20). Patients were randomly allocated to four groups (n = 30 each).")
  cand <- .ppArmNCandidatesFromText(txt)
  expect_false(any(cand$n == 1L))
  expect_true(any(cand$n == 30L))
  # the recovery gives the arms 30 from the statement, not 1 from the broken caption
  rec <- .ppArmNFromDocument(c("Flurbiprofen Axetil 25 mg", "Flurbiprofen Axetil 50 mg", "Flurbiprofen Axetil 75 mg", "Vehicle"), txt)
  expect_identical(rec$N, rep(30L, 4))
  # without the statement, nothing is invented
  rec2 <- .ppArmNFromDocument(c("Flurbiprofen Axetil 25 mg", "Vehicle"),
                              "treatment with flurbiprofen axetil or vehicle (control group) (N = 1 20).")
  expect_true(all(is.na(rec2$N)))
})
