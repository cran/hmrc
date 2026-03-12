test_that("get_stamp_duty() rejects unknown types", {
  expect_error(
    get_stamp_duty(type = "land_registry_fee"),
    "Unknown type"
  )
})

test_that("get_stamp_duty() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_stamp_duty(type = "sdlt_total")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_year", "type", "description", "receipts_gbp_m"))
  expect_type(out$tax_year, "character")
  expect_type(out$type, "character")
  expect_type(out$receipts_gbp_m, "double")
})

test_that("get_stamp_duty() type filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_stamp_duty(type = c("sdlt_total", "sdrt"))
  expect_true(all(out$type %in% c("sdlt_total", "sdrt")))
})

test_that("get_stamp_duty() returns annual data covering 2003-04 onwards", {
  skip_on_cran()
  skip_if_offline()

  out <- get_stamp_duty(type = "total")
  expect_true(any(grepl("^2003", out$tax_year)))
})

test_that("get_stamp_duty() tax_year matches expected format", {
  skip_on_cran()
  skip_if_offline()

  out <- get_stamp_duty()
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
})
