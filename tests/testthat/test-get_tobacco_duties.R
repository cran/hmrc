test_that("get_tobacco_duties() rejects unknown products", {
  expect_error(
    get_tobacco_duties(product = "cigars_fancy"),
    "Unknown product"
  )
})

test_that("get_tobacco_duties() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tobacco_duties(product = "total", start = "2020-01", end = "2020-12")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "product", "description", "receipts_gbp_m"))
  expect_s3_class(out$date, "Date")
  expect_type(out$product, "character")
  expect_type(out$receipts_gbp_m, "double")
})

test_that("get_tobacco_duties() product filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tobacco_duties(product = c("cigarettes", "cigars"))
  expect_true(all(out$product %in% c("cigarettes", "cigars")))
})

test_that("get_tobacco_duties() date filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tobacco_duties(start = "2022-01", end = "2022-06")
  expect_true(all(out$date >= as.Date("2022-01-01")))
  expect_true(all(out$date <= as.Date("2022-06-30")))
})

test_that("get_tobacco_duties() returns data from multiple products by default", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tobacco_duties(start = "2023-01", end = "2023-03")
  expect_true(length(unique(out$product)) > 1)
})
