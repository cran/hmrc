test_that("hmrc_fuel_duties() rejects unknown fuel", {
  expect_error(
    hmrc_fuel_duties(fuel = "rocket_fuel"),
    "Unknown fuel"
  )
})

test_that("hmrc_fuel_duties() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_fuel_duties(fuel = "total", start = "2020-01", end = "2020-12")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("date", "fuel", "description", "receipts_gbp_m"))
  expect_true(all(out$fuel == "total"))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "fuel_duties_monthly")
})
