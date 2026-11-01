test_that("hmrc_inheritance_tax() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_inheritance_tax()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "estate_band_lower_gbp", "estate_band",
                      "measure", "value"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
  expect_true(any(out$estate_band == "Total"))
  expect_true(any(grepl("^GBP", out$estate_band)))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "inheritance_tax_annual")
  expect_equal(m$cell_methods, "liabilities")
})

test_that("hmrc_inheritance_tax() includes the five expected measures", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_inheritance_tax()
  expect_setequal(
    unique(out$measure),
    c("number_not_taxed", "number_taxed", "tax_due_gbp_m",
      "avg_tax_gbp", "effective_rate_pct")
  )
})

test_that("hmrc_inheritance_tax() effective rates are in per cent", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_inheritance_tax())
  rate <- out$value[out$measure == "effective_rate_pct"]
  total <- out$value[out$measure == "effective_rate_pct" & out$estate_band == "Total"]
  expect_true(total > 1 && total < 40)
  expect_true(all(rate <= 40, na.rm = TRUE))
})
