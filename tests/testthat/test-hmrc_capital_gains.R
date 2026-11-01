test_that("hmrc_capital_gains() rejects unknown measure", {
  expect_error(
    hmrc_capital_gains(measure = "not_a_measure"),
    "Unknown measure"
  )
})

test_that("hmrc_capital_gains() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_capital_gains(measure = "tax_total_gbp_m")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "measure", "value", "status"))
  expect_true(all(out$measure == "tax_total_gbp_m"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
  expect_type(out$value, "double")

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "capital_gains_tax_annual")
  expect_equal(m$frequency, "annual")
})

test_that("hmrc_capital_gains() keeps footnoted years and has no gaps", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_capital_gains(measure = "tax_total_gbp_m")
  # "2008 to 2009 [Note 2]" was dropped before 0.4.1
  expect_true("2008-09" %in% out$tax_year)
  starts <- as.integer(substr(sort(out$tax_year), 1, 4))
  expect_true(all(diff(starts) == 1L))
  expect_true(any(out$status == "provisional", na.rm = TRUE))
})

test_that("hmrc_capital_gains() filters by year", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_capital_gains(tax_year = "2020-21")
  expect_true(all(out$tax_year == "2020-21"))
  expect_equal(nrow(out), length(CGT_T1_COLS))
})

test_that("hmrc_capital_gains() warns on unknown year", {
  skip_on_cran()
  skip_if_offline()

  expect_warning(
    out <- hmrc_capital_gains(tax_year = "1900-01"),
    "Tax year"
  )
  expect_equal(nrow(out), 0L)
})
