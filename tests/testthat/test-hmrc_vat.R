test_that("hmrc_vat() rejects unknown measures", {
  expect_error(
    hmrc_vat(measure = "not_a_measure"),
    "Unknown measure"
  )
})

test_that("hmrc_vat() returns expected structure with provenance", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_vat(measure = "total", start = "2020-01", end = "2020-12")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("date", "measure", "description", "receipts_gbp_m"))
  expect_s3_class(out$date, "Date")
  expect_true(all(out$measure == "total"))
  expect_equal(nrow(out), 12L)

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "vat_monthly")
  expect_equal(m$frequency, "monthly")
})

test_that("hmrc_vat() respects date filters", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_vat(measure = "total", start = "2020-01", end = "2020-06")
  expect_true(all(out$date >= as.Date("2020-01-01")))
  expect_true(all(out$date <= as.Date("2020-06-30")))
})

test_that("hmrc_vat() total is net home VAT plus import VAT", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_vat(start = "1990-01"))
  w <- reshape(out[, c("date", "measure", "receipts_gbp_m")],
               idvar = "date", timevar = "measure", direction = "wide")
  gap <- abs(w$receipts_gbp_m.total - w$receipts_gbp_m.home_vat -
               w$receipts_gbp_m.import_vat)
  # Published figures are rounded, so allow a small tolerance
  expect_lt(max(gap, na.rm = TRUE), 150)
  expect_true(all(w$receipts_gbp_m.repayments <= 0, na.rm = TRUE))
})
