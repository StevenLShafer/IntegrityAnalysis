# Adjudication of the private security audit of 2026-09-10, S5 (LOW): the
# template fallback read the first sheet of a workbook the wide reader had
# refused for having more than ten sheets, so /parse returned 200.
#
# PROVENANCE: written by Claude Code (model Claude Fable 5.1, Anthropic),
# 2026-09-10, with the fix in R/apiService.R (the sheet count is checked
# once, before either reader). Reproduced THROUGH THE PATH THE REPORT
# NAMES: the upload reader and the actual /parse handler on ten- and
# eleven-sheet workbooks. Checked to FAIL on d6496e0.
suppressWarnings(suppressPackageStartupMessages({ library(shiny); library(openxlsx) }))

workbookWithSheets <- function(k, name) {
  wb <- openxlsx::createWorkbook()
  tpl <- data.frame(TRIAL = "T", ROW = c("Age", "Age"), N = 30, MEAN = c(50, 50.2), SD = 10,
                    ROUND_MEAN = 1, ROUND_OBSERVATION = 0, ROUND_DISPERSION = 0)
  for (i in seq_len(k)) {
    openxlsx::addWorksheet(wb, paste0("S", i))
    openxlsx::writeData(wb, paste0("S", i), tpl)
  }
  f <- file.path(tempdir(), name)
  openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  f
}
parseHandler <- local({
  plumberFile <- system.file("api", "plumber.R", package = "IntegrityAnalysis")
  if (!nzchar(plumberFile)) plumberFile <- test_path("..", "..", "inst", "api", "plumber.R")
  ast <- parse(plumberFile, keep.source = FALSE)
  funs <- lapply(Filter(function(x) is.call(x) && identical(x[[1]], as.name("function")),
                        as.list(ast)), eval)
  Filter(function(f) "file" %in% names(formals(f)), funs)[[1]]
})

test_that("a workbook of more than ten sheets is refused on the template route too (security audit 2026-09-10, S5)", {
  ten <- workbookWithSheets(10L, "sheets-10.xlsx")
  eleven <- workbookWithSheets(11L, "sheets-11.xlsx")
  r10 <- .apiReadUpload(ten, "sheets-10.xlsx")
  expect_true(isTRUE(r10$ok))
  r11 <- .apiReadUpload(eleven, "sheets-11.xlsx")
  expect_false(isTRUE(r11$ok))
  expect_match(r11$reasons, "more than 10 sheets")
  # and through the actual /parse handler: 422, not the first sheet
  part <- stats::setNames(list(readBin(eleven, "raw", n = file.info(eleven)$size)), basename(eleven))
  res <- new.env(); p <- parseHandler(new.env(), res, part)
  expect_false(isTRUE(p$ok))
  expect_equal(res$status, 422)
  expect_match(p$reasons, "more than 10 sheets")
})
