test_that("hmrc_patent_box() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_patent_box()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "companies", "relief_gbp_m"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))
  expect_type(out$companies, "double")
  expect_type(out$relief_gbp_m, "double")

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "patent_box")
  expect_equal(m$frequency, "annual")
})

test_that("hmrc_patent_box() series starts no later than 2014-15", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_patent_box()
  expect_true(min(out$tax_year) <= "2014-15")
})

test_that("hmrc_patent_box() warns on unknown year", {
  skip_on_cran()
  skip_if_offline()

  expect_warning(
    out <- hmrc_patent_box(tax_year = "1900-01"),
    "Tax year"
  )
  expect_equal(nrow(out), 0L)
})
