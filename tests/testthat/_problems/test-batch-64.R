# Extracted from test-batch.R:64

# test -------------------------------------------------------------------------
dir <- file.path(tempdir(), "batchOut1")
out <- file.path(tempdir(), "batchOut2")
unlink(out, recursive = TRUE)
dir.create(dir, showWarnings = FALSE)
file.copy(syntheticPdfMeanSD(), file.path(dir, "trial.pdf"), overwrite = TRUE)
res <- parseBaselineTableFiles(dir, outputDir = out, quiet = TRUE)
expect_true(res$ok)
expect_true(file.exists(file.path(out, "trial.xlsx")))
