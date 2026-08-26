# Extracted from test-batch.R:39

# test -------------------------------------------------------------------------
dir <- file.path(tempdir(), "batchBad")
dir.create(dir, showWarnings = FALSE)
file.copy(syntheticPdfMeanSD(), file.path(dir, "good.pdf"), overwrite = TRUE)
writeLines("this is not a PDF at all", file.path(dir, "broken.pdf"))
res <- parseBaselineTableFiles(dir, quiet = TRUE)
expect_equal(nrow(res), 2)
bad <- res[res$file == "broken.pdf", ]
expect_false(bad$ok)
expect_true(nzchar(bad$error))
expect_null(res$result[[which(res$file == "broken.pdf")]])
expect_true(res$ok[res$file == "good.pdf"])
