# Extracted from test-batch.R:73

# test -------------------------------------------------------------------------
f <- syntheticPdfMeanSD()
res <- parseBaselineTableFiles(c(f), quiet = TRUE)
expect_equal(nrow(res), 1)
expect_true(res$ok)
