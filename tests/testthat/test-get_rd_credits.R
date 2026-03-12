test_that("get_rd_credits() rejects unknown schemes", {
  expect_error(
    get_rd_credits(scheme = "r_and_d_magic"),
    "Unknown scheme"
  )
})

test_that("get_rd_credits() rejects unknown measures", {
  expect_error(
    get_rd_credits(measure = "profit"),
    "Unknown measure"
  )
})

test_that("get_rd_credits() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- get_rd_credits()

  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_year", "scheme", "description", "measure", "value"))
  expect_type(out$tax_year, "character")
  expect_type(out$scheme, "character")
  expect_type(out$measure, "character")
  expect_type(out$value, "double")
})

test_that("get_rd_credits() scheme filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_rd_credits(scheme = "sme")
  expect_true(all(out$scheme == "sme"))
})

test_that("get_rd_credits() measure filter works", {
  skip_on_cran()
  skip_if_offline()

  out <- get_rd_credits(measure = "claims")
  expect_true(all(out$measure == "claims"))
})

test_that("get_rd_credits() returns data from 2000-01 onwards", {
  skip_on_cran()
  skip_if_offline()

  out <- get_rd_credits(scheme = "sme", measure = "claims")
  expect_true(any(grepl("^2000", out$tax_year)))
})

test_that("get_rd_credits() tax_year matches expected format", {
  skip_on_cran()
  skip_if_offline()

  out <- get_rd_credits()
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
})
