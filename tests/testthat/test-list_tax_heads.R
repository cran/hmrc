test_that("list_tax_heads() returns a data frame with expected structure", {
  out <- list_tax_heads()

  expect_s3_class(out, "data.frame")
  expect_named(out, c("tax_head", "description", "category", "available_from"))
  expect_true(nrow(out) > 0)
  expect_type(out$tax_head, "character")
  expect_type(out$description, "character")
  expect_type(out$category, "character")
})

test_that("list_tax_heads() contains expected tax heads", {
  out <- list_tax_heads()
  expect_true("income_tax" %in% out$tax_head)
  expect_true("vat" %in% out$tax_head)
  expect_true("nics_total" %in% out$tax_head)
  expect_true("total_receipts" %in% out$tax_head)
})

test_that("list_tax_heads() has no missing values in key columns", {
  out <- list_tax_heads()
  expect_false(any(is.na(out$tax_head)))
  expect_false(any(is.na(out$description)))
  expect_false(any(is.na(out$category)))
})

test_that("list_tax_heads() tax_head values are unique", {
  out <- list_tax_heads()
  expect_equal(length(unique(out$tax_head)), nrow(out))
})

test_that("list_tax_heads() categories are from the expected set", {
  out  <- list_tax_heads()
  cats <- c("income", "nics", "consumption", "property", "environment",
            "expenditure", "other", "total")
  expect_true(all(out$category %in% cats))
})
