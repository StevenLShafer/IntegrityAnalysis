# test-group-number-header-and-included-n.R - "Group 1 Group 2" over
# wrapped arm names is a header line, not a data row, and "Group 1
# (Lactoferrin group): included 100 pregnant women" is a statement of that
# arm's size (ISSUES.md issue 154, 2026-09-26).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-26 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 31 part 1 AJ3 (Rezk 2016, J Matern Fetal Neonatal #
# Med, the Loadsman corpus; two arms of 100): the arms went out nameless   #
# and without an N although all ten cells read.                            #
############################################################################

pm <- "\u00b1"

test_that("a line of group numbers is a header line, and 'included 100 pregnant women' is a size candidate", {
  L <- data.frame(text = c("Group", "1", "Group", "2"), x = c(127, 151, 187, 211), width = c(21, 4, 21, 4), stringsAsFactors = FALSE)
  expect_true(.ppGroupNumberLine(L))
  expect_true(.ppGroupNumberLine(data.frame(text = c("Group", "1"), x = 1:2, width = 5, stringsAsFactors = FALSE)))
  expect_true(.ppGroupNumberLine(data.frame(text = c("(Lactoferrin", "Group", "2"), x = 1:3, width = 5, stringsAsFactors = FALSE)))
  expect_true(.ppGroupNumberLine(data.frame(text = c("Group", "I", "Group", "II", "P"), x = 1:5, width = 5, stringsAsFactors = FALSE)))
  expect_false(.ppGroupNumberLine(data.frame(text = c("Age", "1", "Group", "2"), x = 1:4, width = 5, stringsAsFactors = FALSE)))
  expect_false(.ppGroupNumberLine(data.frame(text = c("Group", "1", "45", "12"), x = 1:4, width = 5, stringsAsFactors = FALSE)))
  cand <- .ppArmNCandidatesFromText(c("Group 1 (Lactoferrin group): included 100 pregnant women who received lactoferrin.",
                                      "Group 2 (Ferrous group): included 100 pregnant women who received ferrous sulphate."))
  expect_identical(cand$n, c(100L, 100L))
  expect_true(all(grepl("Lactoferrin|Ferrous", cand$before)))
  f <- .ppFillArmNFromText(c(NA_integer_, NA_integer_), c("Group 1 (Lactoferrin group)", "Group 2 (Ferrous group)"), cand, integer(0))
  expect_identical(f$N, c(100L, 100L))
  # the two-column page breaks the sentence after "pregnant", and the flow
  # diagram allocates 110: the included 100 is the arm's size
  cand2 <- .ppArmNCandidatesFromText(c("Allocated to intervention: Lactoferrin (n=110) and ferrous sulphate (n=118) received the drug.",
                                       "Group 1 (Lactoferrin group): included 100 pregnant -Lost follow up (n=6) women who received lactoferrin."))
  expect_true(all(c(110L, 100L) %in% cand2$n))
  f2 <- .ppFillArmNFromText(c(NA_integer_, NA_integer_), c("Group 1 (Lactoferrin group)", "Group 2 (Ferrous group)"), cand2, integer(0))
  expect_identical(f2$N[1], 100L)
})

includedNPdf <- function(file = file.path(tempdir(), "includedN.pdf")) {
  vx <- c(124, 184)
  w <- function(x, y, text) list(x = x, y = y, text = text, adj = 0)
  row <- function(y, label, cells, p) c(list(w(47, y, label)), lapply(1:2, function(k) w(vx[k], y, cells[k])), list(w(240, y, p)))
  cells <- c(
    list(w(47, 40, "Group 1 (Lactoferrin group): included 100 pregnant women who received lactoferrin 250 mg daily.")),
    list(w(47, 52, "Group 2 (Ferrous group): included 100 pregnant women who received ferrous sulphate 150 mg daily.")),
    list(w(47, 80, "Table 1. Maternal characteristics.")),
    list(w(127, 100, "Group 1"), w(187, 100, "Group 2")),
    list(w(121, 110, "(Lactoferrin"), w(174, 110, "(Ferrous"), w(241, 110, "t-test")),
    list(w(130, 120, "group)"), w(180, 120, "group)"), w(241, 120, "p value")),
    row(140, "Age", c(paste("26.4", pm, "5.18"), paste("26.5", pm, "5.65")), "0.130"),
    row(152, "Parity", c(paste("1.42", pm, "1.37"), paste("1.50", pm, "1.29")), "0.43"),
    row(164, "BMI at inclusion", c(paste("21.86", pm, "1.94"), paste("21.90", pm, "1.90")), "0.15"),
    list(w(47, 190, "BMI = body mass index; ANC = antenatal care.")))
  makeTablePdf(file, cells)
}

test_that("a rebuilt page with wrapped 'Group 1 / Group 2' names and 'included 100 pregnant women' statements reads two named arms of 100", {
  r <- parseBaselineTableHeuristics(includedNPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_true(all(grepl("Lactoferrin", r$arms$arm[1]), grepl("Ferrous", r$arms$arm[2])))
  expect_identical(r$arms$N, c(100L, 100L))
  cont <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(cont$MEAN[grepl("^Age", cont$ROW)], c(26.4, 26.5))
  expect_identical(length(unique(cont$ROW)), 3L)
})
