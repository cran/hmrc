test_that("get_fuel_duties() rejects unknown fuel categories", {
  expect_error(
    get_fuel_duties(fuel = "hydrogen"),
    "Unknown fuel category"
  )
})

test_that("get_fuel_duties() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_fuel_duties(fuel = "total", start = "2020-01", end = "2020-12")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "fuel", "description", "receipts_gbp_m"))
  expect_s3_class(out$date, "Date")
  expect_type(out$fuel, "character")
  expect_type(out$receipts_gbp_m, "double")
})

test_that("get_fuel_duties() fuel filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_fuel_duties(fuel = c("petrol", "diesel"))
  expect_true(all(out$fuel %in% c("petrol", "diesel")))
})

test_that("get_fuel_duties() date filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_fuel_duties(fuel = "total", start = "2022-01", end = "2022-06")
  expect_true(all(out$date >= as.Date("2022-01-01")))
  expect_true(all(out$date <= as.Date("2022-06-30")))
})

test_that("get_fuel_duties() returns data from at least 2010", {
  skip_on_cran()
  skip_if_offline()

  out <- get_fuel_duties(fuel = "total")
  expect_true(min(out$date) <= as.Date("2010-01-01"))
})
