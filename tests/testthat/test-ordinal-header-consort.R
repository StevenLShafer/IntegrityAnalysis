# test-ordinal-header-consort.R - an arm-name line of ordinals that goes on
# to head the statistic columns, and arm sizes stated only in a CONSORT
# flow that names more sizes than there are arms (ISSUES.md issue 50,
# 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 5 finding K1 (RezkJMFNM2014, J Matern Fetal      #
# Neonatal Med 2015;28:93): the header "Group 1 Group 2 Group 3 ANOVA test #
# p value" was a data line to the classifier (issue 45's ordinal rule     #
# wanted nothing after the last number), the arms went unnamed; and the   #
# only sizes are in the flow diagram - "Assessed for eligibility (n=109)  #
# ... Excluded (n=19) ... Randomized (n=90) ... Analyzed (n=30) Analyzed  #
# (n=30) Analyzed (n=30)" - fourteen mentions for three arms, which the   #
# position rule refused; and the "ANOVA test" F column counted as a       #
# fourth arm. The page cannot ship; the layout is rebuilt here.           #
############################################################################

consortPdf <- function(file = file.path(tempdir(), "consort.pdf")) {
  vx <- c(200, 290, 380, 470, 540)
  cells <- c(
    list(list(x = 40, y = 40, text = "Assessed for eligibility (n=109). Excluded (n=19). Randomized (n=90).", adj = 0)),
    list(list(x = 40, y = 56, text = "Allocated to group 1 (n=30), group 2 (n=30), group 3 (n=30). Analyzed (n=30) Analyzed (n=30) Analyzed (n=30).", adj = 0)),
    list(list(x = 40, y = 90, text = "Table Maternal characteristics and induction to abortion interval.", adj = 0)),
    rowCells(112, "", c("Group 1", "Group 2", "Group 3", "ANOVA test", "p value"), vx),
    rowCells(132, "Age", c("26.1 ± 4.6", "26.3 ± 5.2", "26.46 ± 5.01", "0.035", ">0.05"), vx),
    rowCells(150, "Parity*", c("1.5 ± 1.11", "1.8 ± 1.34", "1.56 ± 1.38", "0.899", ">0.05"), vx),
    rowCells(168, "Gestational age", c("16.7 ± 2.99", "17.43 ± 3.19", "18.16 ± 3.14", "1.66", ">0.05"), vx),
    rowCells(186, "IAI", c("11.76 ± 1.63", "19.76 ± 1.52", "7.5 ± 1.25", "532.05", "<0.001"), vx),
    list(list(x = 40, y = 210, text = "*Kruskal-Wallis test. IAI: Induction to abortion interval.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("the ordinal header with trailing column words names the arms; the flow's per-arm size fills them; the F column is no arm", {
  r <- parseBaselineTableHeuristics(consortPdf(), quiet = TRUE)
  expect_identical(r$arms$arm, c("Group 1", "Group 2", "Group 3"))
  expect_identical(r$arms$N, c(30L, 30L, 30L))
  expect_true(all(grepl("every per-arm mention states n = 30", r$armNSource)))
  d <- r$data[!is.na(r$data$MEAN), ]
  expect_identical(d$MEAN[d$ROW == "Age"], c(26.1, 26.3, 26.46))
  expect_identical(nrow(d), 12L)
  expect_false(any(grepl("ANOVA", r$arms$arm)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})

test_that("the position rule still refuses when the remaining mentions disagree, or when their product is not the total", {
  cand <- data.frame(n = c(19L, 90L, 30L, 30L, 25L), pos = 1:5,
                     context = "allocated group", near = c("Excluded (n=19)", "Randomized (n=90)", "Analyzed (n=30)", "Analyzed (n=30)", "Analyzed (n=25)"),
                     before = "", stringsAsFactors = FALSE)
  res <- .ppFillArmNFromText(rep(NA_integer_, 3), c("Group 1", "Group 2", "Group 3"), cand, 90L)
  expect_true(all(is.na(res$N)))
  cand2 <- cand[c(1, 2, 3, 4, 4), ]; cand2$pos <- 1:5; cand2$n[5] <- 30L
  res2 <- .ppFillArmNFromText(rep(NA_integer_, 4), paste("Group", 1:4), cand2, 90L)   # 4 x 30 != 90
  expect_true(all(is.na(res2$N)))
})
