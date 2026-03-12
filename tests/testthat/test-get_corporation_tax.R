test_that("get_corporation_tax() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_corporation_tax()

  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_year", "type", "description", "receipts_gbp_m"))
  expect_type(out$tax_year, "character")
  expect_type(out$type, "character")
  expect_type(out$receipts_gbp_m, "double")
})

test_that("get_corporation_tax() includes core tax types", {
  skip_on_cran()
  skip_if_offline()

  out <- get_corporation_tax()
  expect_true("total_ct" %in% out$type)
  expect_true("onshore_ct" %in% out$type)
})

test_that("get_corporation_tax() tax_year matches expected format", {
  skip_on_cran()
  skip_if_offline()

  out <- get_corporation_tax()
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
})

test_that("get_corporation_tax() total CT receipts are positive", {
  skip_on_cran()
  skip_if_offline()

  out <- get_corporation_tax()
  total <- out[out$type == "total_ct", ]
  non_na <- total$receipts_gbp_m[!is.na(total$receipts_gbp_m)]
  if (length(non_na) > 0) expect_true(all(non_na > 0))
})
