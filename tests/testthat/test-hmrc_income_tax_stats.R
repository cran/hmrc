test_that("hmrc_income_tax_stats() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_income_tax_stats()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "income_range", "income_lower_gbp",
                      "taxpayers_thousands", "total_income_gbp_m",
                      "tax_liability_gbp_m", "average_rate_pct",
                      "average_tax_gbp"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "income_tax_liabilities_by_range")
  expect_equal(m$cell_methods, "liabilities")
})

test_that("hmrc_income_tax_stats() warns on unknown tax year", {
  skip_on_cran()
  skip_if_offline()

  expect_warning(
    out <- hmrc_income_tax_stats(tax_year = "1900-01"),
    "Tax year"
  )
  expect_equal(nrow(out), 0L)
})
