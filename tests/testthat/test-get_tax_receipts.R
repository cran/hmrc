test_that("get_tax_receipts() rejects unknown tax heads", {
  expect_error(
    get_tax_receipts(tax = "not_a_tax"),
    "Unknown tax head"
  )
})

test_that("get_tax_receipts() rejects invalid start format", {
  skip_on_cran()
  skip_if_offline()
  expect_error(
    get_tax_receipts(start = "January 2020"),
    "YYYY-MM"
  )
})

test_that("get_tax_receipts() rejects invalid end format", {
  skip_on_cran()
  skip_if_offline()
  expect_error(
    get_tax_receipts(end = 2020),
    "YYYY-MM"
  )
})

test_that("get_tax_receipts() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_receipts(tax = "vat", start = "2020-01", end = "2020-12")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "tax_head", "description", "receipts_gbp_m"))
  expect_s3_class(out$date, "Date")
  expect_type(out$tax_head, "character")
  expect_type(out$receipts_gbp_m, "double")
})

test_that("get_tax_receipts() date range filtering works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_receipts(tax = "income_tax", start = "2022-01", end = "2022-06")
  expect_true(all(out$date >= as.Date("2022-01-01")))
  expect_true(all(out$date <= as.Date("2022-06-30")))
})

test_that("get_tax_receipts() tax filter returns only requested heads", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_receipts(tax = c("vat", "income_tax"), start = "2023-01", end = "2023-03")
  expect_true(all(out$tax_head %in% c("vat", "income_tax")))
})

test_that("get_tax_receipts() returns data back to at least 2017", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_receipts(tax = "vat")
  # Monthly data in NS_Table starts from April 2016
  expect_true(min(out$date) <= as.Date("2017-01-01"))
})

test_that("get_tax_receipts() receipts are numeric", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_receipts(tax = "vat", start = "2020-01", end = "2020-06")
  expect_false(anyNA(out$receipts_gbp_m))
  expect_type(out$receipts_gbp_m, "double")
})
