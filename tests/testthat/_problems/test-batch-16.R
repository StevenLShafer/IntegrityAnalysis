# Extracted from test-batch.R:16

# test -------------------------------------------------------------------------
dir <- file.path(tempdir(), "batchIn")
dir.create(dir, showWarnings = FALSE)
file.copy(syntheticPdfMeanSD(), file.path(dir, "a.pdf"), overwrite = TRUE)
file.copy(syntheticPdfMeanParen(), file.path(dir, "b.pdf"), overwrite = TRUE)
res <- parseBaselineTableFiles(dir, quiet = TRUE)
expect_s3_class(res, "data.frame")
expect_equal(nrow(res), 2)
expect_setequal(res$file, c("a.pdf", "b.pdf"))
expect_true(all(res$ok))
