test_that("hmrc_tobacco_duties() rejects unknown product", {
  expect_error(
    hmrc_tobacco_duties(product = "snus"),
    "Unknown product"
  )
})

test_that("hmrc_tobacco_duties() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_tobacco_duties(product = "cigarettes",
                             start = "2020-01", end = "2020-12")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("date", "product", "description", "receipts_gbp_m",
                      "provisional"))
  expect_true(all(out$product == "cigarettes"))
  expect_equal(nrow(out), 12L)

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "tobacco_duties_monthly")
})

test_that("hmrc_tobacco_duties() products add up to the total", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_tobacco_duties(start = "2015-01"))
  w <- reshape(out[, c("date", "product", "receipts_gbp_m")],
               idvar = "date", timevar = "product", direction = "wide")
  parts <- w$receipts_gbp_m.cigarettes + w$receipts_gbp_m.cigars +
    w$receipts_gbp_m.hand_rolling + w$receipts_gbp_m.other
  expect_lt(max(abs(w$receipts_gbp_m.total - parts), na.rm = TRUE), 1)
})
