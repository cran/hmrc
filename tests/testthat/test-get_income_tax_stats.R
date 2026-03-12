test_that("get_income_tax_stats() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_income_tax_stats()

  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_year", "income_range", "income_lower_gbp",
                       "taxpayers_thousands", "total_income_gbp_m",
                       "tax_liability_gbp_m", "average_rate_pct",
                       "average_tax_gbp"))
  expect_type(out$tax_year, "character")
  expect_type(out$income_range, "character")
  expect_type(out$income_lower_gbp, "double")
  expect_type(out$taxpayers_thousands, "double")
  expect_type(out$tax_liability_gbp_m, "double")
  expect_type(out$average_rate_pct, "double")
  expect_type(out$average_tax_gbp, "double")
})

test_that("get_income_tax_stats() tax_year filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_income_tax_stats(tax_year = "2022-23")
  expect_true(all(out$tax_year == "2022-23"))
  expect_true(nrow(out) > 0)
})

test_that("get_income_tax_stats() warns on unknown tax_year", {
  skip_on_cran()
  skip_if_offline()

  expect_warning(
    get_income_tax_stats(tax_year = "1999-00"),
    "not found"
  )
})

test_that("get_income_tax_stats() includes All Ranges row", {
  skip_on_cran()
  skip_if_offline()

  out <- get_income_tax_stats(tax_year = "2022-23")
  expect_true("All Ranges" %in% out$income_range)
  all_row <- out[out$income_range == "All Ranges", ]
  expect_true(is.na(all_row$income_lower_gbp))
})

test_that("get_income_tax_stats() returns multiple tax years", {
  skip_on_cran()
  skip_if_offline()

  out <- get_income_tax_stats()
  expect_true(length(unique(out$tax_year)) >= 2)
})

test_that("get_income_tax_stats() tax_year format is correct", {
  skip_on_cran()
  skip_if_offline()

  out <- get_income_tax_stats()
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
})
