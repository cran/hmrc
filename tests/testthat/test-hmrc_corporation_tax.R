test_that("hmrc_corporation_tax() returns expected structure with provenance", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_corporation_tax()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "type", "description", "receipts_gbp_m"))
  expect_type(out$tax_year, "character")
  expect_type(out$type, "character")
  expect_type(out$receipts_gbp_m, "double")

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "corporation_tax_annual")
  expect_equal(m$frequency, "annual")
})

test_that("hmrc_corporation_tax() year format is YYYY-YY", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_corporation_tax()
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
})
