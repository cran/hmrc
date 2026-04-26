test_that("hmrc_cache_info() returns empty data frame when cache is missing", {
  tmp <- file.path(tempdir(), paste0("hmrc-cache-info-", Sys.getpid(), "-empty"))
  unlink(tmp, recursive = TRUE)
  op <- options(hmrc.cache_dir = tmp)
  on.exit(options(op), add = TRUE)

  out <- hmrc_cache_info()
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("file", "extension", "size_bytes", "size_mb",
                      "modified", "age_days", "path"))
  expect_equal(attr(out, "cache_dir"), tmp)
})

test_that("hmrc_cache_info() lists cached files with sizes and ages", {
  tmp <- file.path(tempdir(), paste0("hmrc-cache-info-", Sys.getpid(), "-files"))
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  op <- options(hmrc.cache_dir = tmp)
  on.exit({
    options(op)
    unlink(tmp, recursive = TRUE)
  }, add = TRUE)

  writeLines("a", file.path(tmp, "1234567890_0010.ods"))
  writeLines("bb", file.path(tmp, "9876543210_0008.xlsx"))

  out <- hmrc_cache_info()
  expect_equal(nrow(out), 2L)
  expect_true(all(c("1234567890_0010.ods", "9876543210_0008.xlsx") %in% out$file))
  expect_true(all(out$size_bytes > 0))
  expect_true(all(out$age_days >= 0))
  expect_s3_class(out$modified, "POSIXt")
})
