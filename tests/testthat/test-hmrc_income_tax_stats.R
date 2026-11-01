test_that("hmrc_income_tax_stats() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_income_tax_stats()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "income_range", "income_lower_gbp",
                      "taxpayers_thousands", "total_income_gbp_m",
                      "tax_liability_gbp_m", "average_rate_pct",
                      "average_tax_gbp", "estimate"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
  expect_true(all(out$estimate %in% c("outturn", "projection")))
  expect_equal(unique(out$estimate[out$tax_year == min(out$tax_year)]), "outturn")

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "income_tax_liabilities_by_range")
  expect_equal(m$cell_methods, "liabilities")
})

test_that("hmrc_income_tax_stats() average rates are in per cent", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_income_tax_stats())
  all_ranges <- out$average_rate_pct[out$income_range == "All Ranges"]
  expect_true(all(all_ranges > 5 & all_ranges < 50))
  expect_lt(max(out$average_rate_pct, na.rm = TRUE), 50)
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
