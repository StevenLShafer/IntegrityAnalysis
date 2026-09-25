# test-levels-across-line.R - a categorical variable printed as one line
# with its levels named after the label's colon and every arm's counts side
# by side (ISSUES.md issue 49, 2026-09-25).
#
############################################################################
# Provenance                                                               #
# Written 2026-09-25 by Claude Code (model Claude Fable 5.1) from the       #
# corpus session's finding on RezkHiF2020 (the rotated table of issue 38)  #
# and RezkPH2019: "Age (years): 20-30 31-40  78 (47.6%) 86 (52.4%)  70     #
# (43.75%) 90 (56.25%)  74 (45.7%) 88 (54.3%)". Six n (%) cells on a       #
# three-arm table seeded six columns; the report carried three phantom    #
# arms holding category counts, and the levels came out as rows ">=",     #
# ">=P3", "Category 2" ... The page cannot ship; the layout is rebuilt.    #
############################################################################

test_that("the level names between the colon and the first cell are read, a lone sign glued to its number", {
  expect_identical(.ppSpreadLevels(" 20-30 31-40 "), c("20-30", "31-40"))
  expect_identical(.ppSpreadLevels("P1-2 ≥ P3"), c("P1-2", "≥P3"))
  expect_identical(.ppSpreadLevels("18-25 25.1-29.9 ≥ 30"), c("18-25", "25.1-29.9", "≥30"))
  expect_identical(.ppSpreadLevels(""), character(0))
})

spreadPdf <- function(file = file.path(tempdir(), "spread.pdf")) {
  # cells 65 pt apart (an "n (%)" cell is ~60 pt wide in the device's face),
  # arms 135 pt apart, nothing right of x = 540 (the device clips there)
  ax <- c(180, 315, 450)                       # arm centres
  cx <- c(150, 215, 285, 350, 420, 485)        # the six cells
  cellRow <- function(y, label, texts) c(
    list(list(x = 20, y = y, text = label, adj = 0)),
    lapply(seq_along(texts), function(i) list(x = cx[i], y = y, text = texts[i], adj = 0)))
  cells <- c(
    list(list(x = 20, y = 60, text = "Table 1. Maternal characteristics.", adj = 0)),
    rowCells(84, "", c("Methyldopa (n = 164)", "Labetalol (n = 160)", "Control (n = 162)"), ax),
    # levels across the line: label, colon, two level names, then two cells per arm
    cellRow(106, "Age: 20-30 31-40",
            c("78 (47.6%)", "86 (52.4%)", "70 (43.75%)", "90 (56.25%)", "74 (45.7%)", "88 (54.3%)")),
    cellRow(124, "Parity: P1-2 P3+",
            c("68 (41.5%)", "96 (58.5%)", "66 (41.25%)", "94 (58.75%)", "64 (39.5%)", "98 (60.5%)")),
    rowCells(142, "SBP (mmHg)", c("152.12 ± 5.62", "151.13 ± 5.24", "151.1 ± 5.33"), ax),
    rowCells(160, "Gestational age (Weeks)",  c("8.21 ± 1.67", "8.11 ± 1.74", "8.21 ± 1.42"), ax),
    rowCells(178, "Past adverse outcome", c("50 (30.5%)", "49 (30.6%)", "52 (32.1%)"), ax),
    list(list(x = 20, y = 210, text = "Values are number (percent) or mean ± SD.", adj = 0)))
  makeTablePdf(file, cells)
}

test_that("a levels-across-the-line row is read arm by arm; the arms are the header's three", {
  r <- parseBaselineTableHeuristics(spreadPdf(), quiet = TRUE)
  expect_identical(nrow(r$arms), 3L)
  expect_identical(r$arms$N, c(164L, 160L, 162L))
  age <- r$data[r$data$ROW == "Age", ]
  expect_identical(nrow(age), 3L)
  minus <- intToUtf8(0x2212)                   # the pdf() device sets "-" as U+2212
  names(r$data) <- gsub(minus, "-", names(r$data), fixed = TRUE)
  age <- r$data[r$data$ROW == "Age", ]
  lv <- setdiff(names(age), c(.ppBaseColumns(), "Q1", "Q3"))
  expect_true(all(c("20-30", "31-40", "P1-2", "P3+") %in% lv))
  expect_identical(age[["20-30"]], c(78L, 70L, 74L))
  expect_identical(age[["31-40"]], c(86L, 90L, 88L))
  par <- r$data[r$data$ROW == "Parity", ]
  expect_identical(par[["P1-2"]], c(68L, 66L, 64L))
  expect_identical(par[["P3+"]],  c(96L, 94L, 98L))
  # the ordinary rows are untouched: three continuous cells, one binary n (%) row
  sbp <- r$data[r$data$ROW == "SBP" & !is.na(r$data$MEAN), ]
  expect_identical(sbp$MEAN, c(152.12, 151.13, 151.1))
  expect_true("Past adverse outcome" %in% r$data$ROW)
  expect_false(any(grepl("^Category|^≥|^>=", r$data$ROW)))
  expect_false(isTRUE(vdShared(r$data)$FAIL))
})
