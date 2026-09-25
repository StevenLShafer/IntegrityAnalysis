# test-non-latin-duration-labels.R - a duration whose label is in another
# script with an English gloss is kept on the durations option's terms,
# block or no block (ISSUES.md issue 83, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 19 finding Y1 (MTS2006_17, Loadsman corpus): the  #
# model returned the row's Japanese name glossed "(surgery duration)" for #
# a row Table 1 prints in Japanese, and the hybrid merge refused it as    #
# another table's row because the block test - the label's first two      #
# words on a line of the block - can never find "surgery" in a Japanese  #
# block.                                                                   #
############################################################################

test_that("a non-Latin duration label with a gloss is kept with a block; an outcome in one is still refused", {
  jp <- function(gloss) paste0("手術時間 (", gloss, ")")   # a Japanese row name, then the gloss
  labs <- c(jp("surgery duration"), jp("anesthesia duration"), jp("postoperative pentazocine required"), "Age (years)")
  blk  <- c("Table 1", "年齢 30 (5)", "手術時間 94 (20)")
  expect_identical(.ppOutcomeLabel(labs, blk), c(FALSE, FALSE, TRUE, FALSE))
  expect_identical(.ppOutcomeLabel(labs, NULL), c(FALSE, FALSE, TRUE, FALSE))
  # a Latin-script duration not printed in the block is still another table's row
  expect_identical(.ppOutcomeLabel("Duration of anaesthesia (min)", blk), TRUE)
  expect_identical(.ppOutcomeLabel("Duration of anaesthesia (min)", NULL), FALSE)
  # accented Latin script is Latin: "Durée de l'anesthésie" is judged by the block as before
  expect_identical(.ppOutcomeLabel("Durée de l'anésthesie (min)", NULL), FALSE)
})
