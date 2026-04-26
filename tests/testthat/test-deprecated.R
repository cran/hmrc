test_that("get_* aliases warn and forward to hmrc_* equivalents", {
  withr::local_options(lifecycle_verbosity = "warning")

  expect_warning(out <- list_tax_heads(), "deprecated")
  expect_s3_class(out, "data.frame")
  expect_identical(out, hmrc_list_tax_heads())
})

test_that("clear_cache() alias warns and clears", {
  withr::local_options(lifecycle_verbosity = "warning")

  tmp <- file.path(tempdir(), paste0("hmrc-deprec-clear-", Sys.getpid()))
  unlink(tmp, recursive = TRUE)
  withr::local_options(hmrc.cache_dir = tmp)

  expect_warning(n <- clear_cache(), "deprecated")
  expect_type(n, "integer")
})
