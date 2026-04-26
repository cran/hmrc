test_that("hmrc_tax_gap() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_tax_gap()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "tax", "taxpayer_type", "component",
                      "gap_pct", "gap_gbp_bn", "uncertainty"))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "tax_gap_annual")
})

test_that("hmrc_tax_gap() filters by tax type", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_tax_gap(tax = "VAT")
  expect_true(all(out$tax == "VAT") || nrow(out) == 0L)
})
