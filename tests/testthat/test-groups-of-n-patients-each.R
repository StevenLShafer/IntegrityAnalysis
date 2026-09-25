# test-groups-of-n-patients-each.R - "allocated to one of four groups of
# 15 patients each" states the arm sizes as surely as "divided into four
# groups of 15" (ISSUES.md issue 94, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 24 AC2 (Fujii, Anaesthesia 1998;53:244, PMID      #
# 9613269 = Loadsman Anaesthesia1998_244): the deterministic pass read all #
# four arms of Age, Height, Weight and Duration with N missing, and the    #
# Methods' "allocated to one of four groups of 15 patients each" was not   #
# a shape the "k groups of n" reader knew - it wanted "into".              #
############################################################################

test_that("'to one of K groups of N patients each' is a size statement", {
  g <- .ppGroupsOfN("Patients were allocated randomly to one of four groups of 15 patients each to receive placebo or granisetron.")
  expect_identical(g$groups, 4L); expect_identical(g$n, 15L)
  expect_identical(.ppGroupNFor(g, 4L)$n, 15L)
  expect_true(is.na(.ppGroupNFor(g, 3L)$n))
  # the "into" form still reads, and a sentence with neither does not
  expect_identical(.ppGroupsOfN("They were divided into three groups of 20.")$n, 20L)
  expect_null(.ppGroupsOfN("Four groups of 15 patients were compared."))
})

toOneOfPdf <- function(file = file.path(tempdir(), "toOneOf.pdf")) {
  vx <- c(230, 320, 410, 500)
  cells <- c(
    list(list(x = 60, y = 50, text = "Patients were allocated randomly to one of four groups of 15 patients each to receive placebo or granisetron.", adj = 0)),
    list(list(x = 60, y = 90, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(120, "", c("Placebo", "G 20", "G 40", "G 100"), vx),
    rowCells(138, "Age (yr)", c("45 \u00b1 12", "46 \u00b1 11", "44 \u00b1 10", "47 \u00b1 12"), vx),
    rowCells(156, "Weight (kg)", c("70 \u00b1 9", "71 \u00b1 8", "69 \u00b1 9", "72 \u00b1 10"), vx),
    rowCells(174, "Height (cm)", c("168 \u00b1 7", "167 \u00b1 8", "166 \u00b1 7", "169 \u00b1 8"), vx),
    list(list(x = 60, y = 204, text = "Values are mean \u00b1 SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a table with no N gets four arms of 15 from that sentence", {
  r <- parseBaselineTableHeuristics(toOneOfPdf(), quiet = TRUE)
  expect_identical(r$arms$N, rep(15L, 4))
  expect_true(all(grepl("document text", r$armNSource)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
