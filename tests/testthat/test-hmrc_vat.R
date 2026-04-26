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
