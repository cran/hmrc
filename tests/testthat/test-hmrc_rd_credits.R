test_that("hmrc_rd_credits() rejects unknown scheme/measure", {
  expect_error(
    hmrc_rd_credits(scheme = "huge"),
    "Unknown scheme"
  )
  expect_error(
    hmrc_rd_credits(measure = "frobnicators"),
    "Unknown measure"
  )
})

test_that("hmrc_rd_credits() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_rd_credits(scheme = "sme", measure = "claims")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "scheme", "description", "measure", "value"))
  expect_true(all(out$scheme == "sme"))
  expect_true(all(out$measure == "claims"))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "rd_credits_annual")
})
