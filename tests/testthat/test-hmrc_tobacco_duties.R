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
  expect_named(out, c("date", "product", "description", "receipts_gbp_m"))
  expect_true(all(out$product == "cigarettes"))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "tobacco_duties_monthly")
})
