test_that("hmrc_property_transactions() rejects unknown nation", {
  expect_error(
    hmrc_property_transactions(nation = "atlantis"),
    "Unknown nation"
  )
})

test_that("hmrc_property_transactions() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_property_transactions(nation = "england", type = "residential",
                                    start = "2022-01", end = "2022-06")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("date", "nation", "type", "transactions"))
  expect_true(all(out$nation == "england"))
  expect_true(all(out$type == "residential"))

  m <- hmrc_meta(out)
  expect_equal(m$cell_methods, "counts")
  expect_equal(m$frequency, "monthly")
})

test_that("hmrc_property_transactions() type=all returns both types", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_property_transactions(nation = "uk", start = "2022-01", end = "2022-03")
  expect_true(all(c("residential", "non_residential") %in% out$type))
})
