# Adjudication of security screen 2026-09-10-2047 (over 67a03ab..90d3404),
# finding F3 (HIGH, availability): the 2004 fix clipped the wide reader's
# label column and header, and arm cells are capped, but the cells under a
# "Total" column - dropped from the arms, so never capped - were pasted
# whole into the skip text of every row that reached a skip: 2,000 rows x
# 20 such columns of 30 KB cost 1.33 GB; at the caps about 80 GB.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/parseWideTable.R (the whole block matrix is
# clipped to .ppMaxCellChars on entry; the skip text is built from the
# label and the ARM cells only and clipped to a note's 500 bytes).
# Reproduced through the path the screen names - the workbook through
# parseWideTable() and .apiReadUpload() - and checked to FAIL on b1c1dea
# (a skip text of 600 KB per row there; 12.7 s and 1.3 GB for the sheet).
suppressWarnings(suppressPackageStartupMessages({
  library(shiny); library(openxlsx); library(foreach); library(MBESS); library(Rfast); library(dqrng)
}))

totalColumnsXlsx <- function(rows, K, cell, usable = TRUE) {
  f <- tempfile(fileext = ".xlsx"); wb <- openxlsx::createWorkbook(); openxlsx::addWorksheet(wb, "S")
  m <- rbind(c("Variable", "Arm A (n=10)", "Arm B (n=10)", rep("Total", K)),
             if (usable) c("Age, mean (SD)", "45.3 (12.1)", "46.1 (11.8)", rep(cell, K)),
             cbind(rep("X", rows), "1", "2", matrix(cell, nrow = rows, ncol = K)))
  openxlsx::writeData(wb, "S", as.data.frame(m, stringsAsFactors = FALSE), colNames = FALSE)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE); f
}
heapMB <- function() sum(gc()[, 6])

test_that("cells under a Total column no longer reach the skip text: a note is the label and the arm cells, clipped (screen 2047 F3)", {
  # 10 KB Total cells (not 30): a single cell over 16 KiB is refused at the
  # xlsx preflight now (screen 2026-09-11-1602); 10 KB reaches the parser
  # so the skip-text clip this test guards is still exercised
  f <- totalColumnsXlsx(200L, 20L, strrep("t", 10000L))
  blocks <- parseWideTable(f, "xlsx")
  expect_false(is.null(blocks))
  sk <- blocks[[1]]$skipped
  expect_identical(nrow(sk), 200L)                        # the bare-number rows, each skipped
  expect_lte(max(nchar(sk$text, type = "bytes")), 500L)   # about 600 KB each on b1c1dea
  expect_false(any(grepl("ttttt", sk$text, fixed = TRUE)))   # the Total cells are not in it
  expect_true(all(grepl("X | 1 | 2", sk$text, fixed = TRUE)))
})

test_that("2,000 rows x 20 Total columns of 30 KB read in seconds with bounded memory", {
  f <- totalColumnsXlsx(2000L, 20L, strrep("t", 30000L), usable = FALSE)
  invisible(gc()); before <- sum(gc(reset = TRUE)[, 2])
  t <- system.time(b <- parseWideTable(f, "xlsx"))[["elapsed"]]
  expect_null(b)                                          # nothing usable: NULL, as before
  expect_lt(t, 30)                                        # 12.7 s and 1.3 GB on b1c1dea
  expect_lt(heapMB() - before, 400)
})

test_that("the whole block is clipped on entry: a 10 KB Total cell is 2,000 bytes wherever it is read", {
  f <- totalColumnsXlsx(2L, 1L, strrep("t", 10000L))
  cells <- .wideRawCells(f, "xlsx")[[1]]
  expect_identical(max(nchar(cells)), 10000L)             # the raw read keeps it
  blocks <- parseWideTable(f, "xlsx")
  expect_identical(unique(blocks[[1]]$data$ROW), "Age")   # the usable row is read as before
  expect_identical(nrow(blocks[[1]]$data), 2L)
  # an ordinary table with a Total column drops it and reads
  two <- wideFixtureTwoTrials()
  v <- shiny::isolate(validateData(two))
  tabs <- buildBaselineTables(v$DATA, v$CategoryNames)
  g <- tempfile(fileext = ".xlsx"); writeBaselineTablesXlsx(tabs, g)
  r <- .apiReadUpload(g, "two.xlsx")
  expect_true(isTRUE(r$ok)); expect_identical(nrow(r$data), nrow(two))
})
