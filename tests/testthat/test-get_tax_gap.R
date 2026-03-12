test_that("get_tax_gap() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_gap()

  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_year", "tax", "taxpayer_type", "component",
                       "gap_pct", "gap_gbp_bn", "uncertainty"))
  expect_type(out$tax_year, "character")
  expect_type(out$tax, "character")
  expect_type(out$component, "character")
  expect_type(out$gap_gbp_bn, "double")
})

test_that("get_tax_gap() tax_year is a valid financial year", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_gap()
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
})

test_that("get_tax_gap() contains expected tax types", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_gap()
  expect_true("VAT" %in% out$tax || any(grepl("VAT", out$tax, ignore.case = TRUE)))
})

test_that("get_tax_gap() tax filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_gap(tax = "VAT")
  expect_true(nrow(out) > 0)
  expect_true(all(out$tax == "VAT"))
})

test_that("get_tax_gap() gap values are non-negative", {
  skip_on_cran()
  skip_if_offline()

  out <- get_tax_gap()
  non_na <- out$gap_gbp_bn[!is.na(out$gap_gbp_bn)]
  if (length(non_na) > 0) expect_true(all(non_na >= 0))
})
