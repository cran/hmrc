test_that("hmrc_stamp_duty() rejects unknown type", {
  expect_error(
    hmrc_stamp_duty(type = "not_a_type"),
    "Unknown type"
  )
})

test_that("hmrc_stamp_duty() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_stamp_duty(type = "sdlt_total")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "type", "description", "receipts_gbp_m"))
  expect_true(all(out$type == "sdlt_total"))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "stamp_duty_annual")
  expect_equal(m$frequency, "annual")
})
