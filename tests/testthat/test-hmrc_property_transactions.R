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
  expect_named(out, c("date", "nation", "type", "transactions", "provisional"))
  expect_true(all(out$nation == "england"))
  expect_true(all(out$type == "residential"))
  expect_equal(nrow(out), 6L)

  m <- hmrc_meta(out)
  expect_equal(m$cell_methods, "counts")
  expect_equal(m$frequency, "monthly")
})

test_that("hmrc_property_transactions() UK equals the sum of the nations", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_property_transactions(start = "2020-01"))
  expect_true(all(c("residential", "non_residential") %in% out$type))
  w <- reshape(out[, c("date", "type", "nation", "transactions")],
               idvar = c("date", "type"), timevar = "nation", direction = "wide")
  parts <- w$transactions.england + w$transactions.scotland +
    w$transactions.wales + w$transactions.northern_ireland
  expect_lt(max(abs(w$transactions.uk - parts)), 50)
})
