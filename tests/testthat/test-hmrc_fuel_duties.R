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
  expect_named(out, c("date", "fuel", "description", "receipts_gbp_m",
                      "provisional"))
  expect_true(all(out$fuel == "total"))
  expect_equal(nrow(out), 12L)
  expect_type(out$provisional, "logical")

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "fuel_duties_monthly")
  expect_s3_class(m$published_at, "POSIXct")
})

test_that("hmrc_fuel_duties() components add up to the total", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_fuel_duties(start = "2010-01")
  w <- reshape(as.data.frame(out)[, c("date", "fuel", "receipts_gbp_m")],
               idvar = "date", timevar = "fuel", direction = "wide")
  parts <- w$receipts_gbp_m.petrol + w$receipts_gbp_m.diesel +
    w$receipts_gbp_m.other
  gap <- abs(w$receipts_gbp_m.total - parts) / w$receipts_gbp_m.total
  # Petrol and diesel are HMRC's own totals; summing their components as
  # well would double them and break this identity
  expect_lt(mean(gap > 0.02, na.rm = TRUE), 0.02)
  expect_true(all(w$receipts_gbp_m.petrol < w$receipts_gbp_m.total, na.rm = TRUE))
})
