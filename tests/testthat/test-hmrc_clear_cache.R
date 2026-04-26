test_that("hmrc_clear_cache() works when cache is empty or absent", {
  tmp <- file.path(tempdir(), paste0("hmrc-clear-cache-", Sys.getpid()))
  unlink(tmp, recursive = TRUE)
  op <- options(hmrc.cache_dir = tmp)
  on.exit(options(op), add = TRUE)

  expect_no_error(hmrc_clear_cache())
})

test_that("hmrc_clear_cache() accepts valid max_age_days", {
  expect_no_error(hmrc_clear_cache(max_age_days = 30))
  expect_no_error(hmrc_clear_cache(max_age_days = 0))
})

test_that("hmrc_clear_cache() rejects invalid max_age_days", {
  expect_error(hmrc_clear_cache(max_age_days = -1))
  expect_error(hmrc_clear_cache(max_age_days = "30"))
})

test_that("hmrc_clear_cache() returns an invisible integer", {
  result <- hmrc_clear_cache()
  expect_type(result, "integer")
})

test_that("hmrc_clear_cache() removes files older than max_age_days", {
  tmp <- file.path(tempdir(), paste0("hmrc-clear-cache-age-", Sys.getpid()))
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  op <- options(hmrc.cache_dir = tmp)
  on.exit({
    options(op)
    unlink(tmp, recursive = TRUE)
  }, add = TRUE)

  old <- file.path(tmp, "old.ods")
  new <- file.path(tmp, "new.ods")
  writeLines("a", old)
  writeLines("a", new)
  Sys.setFileTime(old, Sys.time() - 60 * 60 * 24 * 90)

  removed <- hmrc_clear_cache(max_age_days = 30)
  expect_equal(removed, 1L)
  expect_false(file.exists(old))
  expect_true(file.exists(new))
})
