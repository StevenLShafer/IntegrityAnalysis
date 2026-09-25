# test-oup-rail-rotated-words.R - the OUP download rail, seven points wide,
# is a rotated rail and is stripped (ISSUES.md issue 86, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's batch 21 finding AA1 (PMIDs 9389277 and 9861126, BJA):   #
# "Downloaded from https://academic.oup.com/bja/article/79/4/539/254374 by  #
# ... user on 25 September 2026" runs up the right margin in a font one    #
# point wider than the six-point rule of issue 35, and the URL's article  #
# number became a fourth arm with N = 254996.                              #
############################################################################

test_that("a rail of words seven points wide and far taller than wide is stripped; upright words stay", {
  page <- data.frame(
    text = c("Age", "(yr)", "45", "±", "12", "of", "by", "kg",
             "Downloaded", "academic.oup.com/bja/article/79/4/539/254374", "user", "September"),
    x = c(60, 80, 200, 215, 225, 300, 320, 340, 552, 552, 552, 552),
    y = c(100, 100, 100, 100, 100, 120, 120, 120, 207, 272, 521, 561),
    width = c(16, 14, 10, 6, 10, 8, 8, 9, 7, 7, 7, 7),
    height = c(8, 8, 8, 8, 8, 8, 8, 8, 44, 165, 15, 39),
    stringsAsFactors = FALSE)
  page <- page[rep(seq_len(nrow(page)), 1), ]
  # the stripper wants at least eight words on the page; pad with body text
  body <- data.frame(text = paste0("w", 1:12), x = seq(60, 500, length.out = 12), y = 300,
                     width = 12, height = 8, stringsAsFactors = FALSE)
  page <- rbind(page, body)
  out <- .ppStripRotatedText(page)
  expect_false(any(grepl("academic|Downloaded|September|^user$", out$text)))
  expect_true(all(c("Age", "45", "±", "of", "by", "kg") %in% out$text))
  expect_identical(nrow(out), nrow(page) - 4L)
})

test_that("a rebuilt page with the OUP rail beside its table reads two arms and no phantom", {
  vx <- c(300, 420)
  f <- file.path(tempdir(), "oupRail.pdf")
  cells <- c(
    list(list(x = 60, y = 70, text = "Table 1 Patient characteristics", adj = 0)),
    rowCells(100, "", c("Placebo (n = 30)", "Granisetron (n = 30)"), vx),
    rowCells(118, "Age (yr)", c("45 ± 12", "46 ± 11"), vx),
    rowCells(136, "Weight (kg)", c("58 ± 9", "57 ± 8"), vx),
    list(list(x = 575, y = 400, text = "Downloaded from https://academic.oup.com/bja/article/79/4/539/254374 by guest user on 25 September 2026", adj = 0, srt = 90)))
  makeTablePdf(f, cells)
  r <- parseBaselineTableHeuristics(f, quiet = TRUE)
  expect_identical(nrow(r$arms), 2L)
  expect_identical(r$arms$N, c(30L, 30L))
  expect_false(any(grepl("254374|Downloaded", c(r$arms$arm, r$data$ROW))))
})
