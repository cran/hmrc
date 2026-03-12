test_that("get_property_transactions() rejects invalid type", {
  expect_error(
    get_property_transactions(type = "industrial"),
    "should be one of"
  )
})

test_that("get_property_transactions() rejects unknown nation", {
  expect_error(
    get_property_transactions(nation = "france"),
    "Unknown nation"
  )
})

test_that("get_property_transactions() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_property_transactions(start = "2023-01", end = "2023-06")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "nation", "type", "transactions"))
  expect_s3_class(out$date, "Date")
  expect_type(out$nation, "character")
  expect_type(out$type, "character")
})

test_that("get_property_transactions() type filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_property_transactions(type = "residential", start = "2023-01", end = "2023-03")
  expect_true(all(out$type == "residential"))
})

test_that("get_property_transactions() nation filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_property_transactions(nation = "england", start = "2023-01", end = "2023-03")
  expect_true(all(out$nation == "england"))
})

test_that("get_property_transactions() transactions are positive integers", {
  skip_on_cran()
  skip_if_offline()

  out <- get_property_transactions(start = "2023-01", end = "2023-03")
  valid <- out$transactions[!is.na(out$transactions)]
  expect_true(all(valid > 0))
})

test_that("get_property_transactions() date range filtering works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_property_transactions(start = "2021-06", end = "2021-09")
  expect_true(all(out$date >= as.Date("2021-06-01")))
  expect_true(all(out$date <= as.Date("2021-09-30")))
})
