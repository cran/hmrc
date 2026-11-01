test_that("hmrc_tax_gap() returns a tidy time series", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_tax_gap()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "tax", "type", "component",
                      "gap_pct", "gap_gbp_bn"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
  expect_true("2005-06" %in% out$tax_year)
  expect_true(all(c("VAT", "Corporation Tax", "Total tax gap") %in% out$tax))
  expect_true(all(out$gap_pct >= 0 & out$gap_pct <= 100, na.rm = TRUE))
  expect_lt(mean(is.na(out$gap_gbp_bn)), 0.1)

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "tax_gap_annual")
})

test_that("hmrc_tax_gap() has one total per year in both units", {
  skip_on_cran()
  skip_if_offline()

  tot <- as.data.frame(hmrc_tax_gap(tax = "Total tax gap"))
  expect_false(any(duplicated(tot$tax_year)))
  expect_false(anyNA(tot$gap_pct))
  expect_false(anyNA(tot$gap_gbp_bn))
  expect_true(all(tot$gap_pct > 2 & tot$gap_pct < 15))
  expect_true(all(tot$gap_gbp_bn > 10))
})

test_that("hmrc_tax_gap() filters by tax and year", {
  skip_on_cran()
  skip_if_offline()

  vat <- hmrc_tax_gap(tax = "VAT", tax_year = "latest")
  expect_equal(nrow(vat), 1L)
  expect_equal(vat$tax, "VAT")

  expect_warning(hmrc_tax_gap(tax = "Window tax"), "not found")
})
