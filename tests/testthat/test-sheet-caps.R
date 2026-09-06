# The grid's headers are escaped, and spreadsheet reads are bounded
# before they build anything (two reproductions by an outside reviewer,
# 2026-09-05).
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1), 2026-09-05.
suppressWarnings(suppressPackageStartupMessages({library(shiny); library(openxlsx)}))

test_that("a header carrying markup reaches the widget escaped", {
  h <- IntegrityAnalysis:::.escapeHtml(c("Age", "<img src=x onerror=alert(1)>", "n (%)"))
  expect_identical(h[1], "Age")
  expect_false(grepl("<", h[2], fixed = TRUE))
  expect_identical(h[2], "&lt;img src=x onerror=alert(1)&gt;")
})

sparseXlsx <- function(row, col) {
  wb <- createWorkbook(); addWorksheet(wb, "S")
  writeData(wb, "S", "TRIAL", 1, 1); writeData(wb, "S", "x", startRow = row, startCol = col)
  f <- tempfile(fileext = ".xlsx"); saveWorkbook(wb, f, overwrite = TRUE); f
}

test_that("a sparse workbook is read within the caps, not expanded; a dense one past them is refused", {
  f <- sparseXlsx(400000, 2000)
  expect_lt(file.size(f), 20000)
  t0 <- Sys.time()
  m <- IntegrityAnalysis:::.wideRawCells(f, "xlsx")      # the far cell lies outside the read window
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  expect_lte(nrow(m[[1]]), IntegrityAnalysis:::.iaSheetRowCap)
  expect_lte(ncol(m[[1]]), IntegrityAnalysis:::.iaSheetColCap)
  g <- sparseXlsx(10001, 3)                              # inside the window, past the row cap
  expect_error(IntegrityAnalysis:::.wideRawCells(g, "xlsx"), "more than 10000 rows or 500 columns")
  h <- sparseXlsx(3, 501)                                # past the column cap
  expect_error(IntegrityAnalysis:::.wideRawCells(h, "xlsx"), "more than 10000 rows or 500 columns")
  # ...and the API fallback read does not build it either
  r <- IntegrityAnalysis:::.apiReadUpload(f, "sparse.xlsx")
  expect_false(isTRUE(r$ok) && !is.null(r$data) && nrow(r$data) > IntegrityAnalysis:::.iaSheetRowCap)
})

test_that("a sheet within the caps still reads", {
  f <- sparseXlsx(50, 10)
  m <- IntegrityAnalysis:::.wideRawCells(f, "xlsx")
  expect_identical(dim(m[[1]]), c(50L, 10L))
})

test_that("a CSV with too many columns is refused from its first line", {
  f <- tempfile(fileext = ".csv")
  writeLines(c(paste(rep("h", 600), collapse = ","), paste(rep("1", 600), collapse = ",")), f)
  expect_gt(IntegrityAnalysis:::.iaCsvColumns(f), 500)
  expect_error(IntegrityAnalysis:::.wideRawCells(f, "csv"), "more than 10000 rows or 500 columns")
  g <- tempfile(fileext = ".csv")
  writeLines(c("TRIAL,ROW,N,MEAN,SD", "T,Age,10,50,10", "T,Age,10,51,11"), g)
  expect_identical(IntegrityAnalysis:::.iaCsvColumns(g), 5L)
})
