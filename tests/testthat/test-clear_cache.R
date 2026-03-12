test_that("clear_cache() works when cache is empty or absent", {
  # Should not error even if cache doesn't exist yet
  expect_no_error(clear_cache())
})

test_that("clear_cache() accepts valid max_age_days", {
  expect_no_error(clear_cache(max_age_days = 30))
  expect_no_error(clear_cache(max_age_days = 0))
})

test_that("clear_cache() rejects invalid max_age_days", {
  expect_error(clear_cache(max_age_days = -1))
  expect_error(clear_cache(max_age_days = "30"))
})

test_that("clear_cache() returns an invisible integer", {
  result <- clear_cache()
  expect_type(result, "integer")
})
