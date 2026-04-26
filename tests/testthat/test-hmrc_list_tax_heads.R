test_that("hmrc_list_tax_heads() returns a data frame with expected structure", {
  out <- hmrc_list_tax_heads()
  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_head", "description", "category", "available_from"))
  expect_true(nrow(out) > 0)
  expect_type(out$tax_head, "character")
  expect_type(out$description, "character")
  expect_type(out$category, "character")
})

test_that("hmrc_list_tax_heads() contains expected tax heads", {
  out <- hmrc_list_tax_heads()
  expect_true("income_tax" %in% out$tax_head)
  expect_true("vat" %in% out$tax_head)
  expect_true("nics_total" %in% out$tax_head)
  expect_true("total_receipts" %in% out$tax_head)
})

test_that("hmrc_list_tax_heads() has unique, non-missing identifiers", {
  out <- hmrc_list_tax_heads()
  expect_false(any(is.na(out$tax_head)))
  expect_equal(length(unique(out$tax_head)), nrow(out))
})

test_that("hmrc_list_tax_heads() categories come from the expected set", {
  out  <- hmrc_list_tax_heads()
  cats <- c("income", "nics", "consumption", "property", "environment",
            "expenditure", "other", "total")
  expect_true(all(out$category %in% cats))
})
