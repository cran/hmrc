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
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "stamp_duty_annual")
  expect_equal(m$frequency, "annual")
})

test_that("hmrc_stamp_duty() total is all property plus all shares", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_stamp_duty())
  expect_setequal(unique(out$type),
                  c("sdlt_property", "sdlt_leases", "sdlt_total", "sdrt",
                    "stamp_duty", "shares_total", "total"))
  w <- reshape(out[, c("tax_year", "type", "receipts_gbp_m")],
               idvar = "tax_year", timevar = "type", direction = "wide")
  # HMRC rounds to the nearest GBP 5m
  expect_lte(max(abs(w$receipts_gbp_m.total - w$receipts_gbp_m.sdlt_total -
                       w$receipts_gbp_m.shares_total)), 10)
  expect_true(all(w$receipts_gbp_m.total > w$receipts_gbp_m.sdlt_total))
})
