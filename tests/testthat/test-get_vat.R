test_that("get_vat() rejects unknown measures", {
  expect_error(
    get_vat(measure = "exports"),
    "Unknown measure"
  )
})

test_that("get_vat() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_vat(measure = "total", start = "2020-01", end = "2020-12")

  expect_s3_class(out, "data.frame")
  expect_named(out, c("date", "measure", "description", "receipts_gbp_m"))
  expect_s3_class(out$date, "Date")
  expect_type(out$measure, "character")
  expect_type(out$receipts_gbp_m, "double")
})

test_that("get_vat() measure filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_vat(measure = c("payments", "repayments"))
  expect_true(all(out$measure %in% c("payments", "repayments")))
})

test_that("get_vat() date filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_vat(measure = "total", start = "2022-01", end = "2022-06")
  expect_true(all(out$date >= as.Date("2022-01-01")))
  expect_true(all(out$date <= as.Date("2022-06-30")))
})

test_that("get_vat() repayments are negative", {
  skip_on_cran()
  skip_if_offline()

  out <- get_vat(measure = "repayments", start = "2020-01", end = "2023-12")
  # Repayments should be negative (money flowing out of HMRC)
  non_na <- out$receipts_gbp_m[!is.na(out$receipts_gbp_m)]
  if (length(non_na) > 0) expect_true(all(non_na < 0))
})
