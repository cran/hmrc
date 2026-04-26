test_that("catalogue dataset is exported and well-formed", {
  cat <- hmrc::catalogue
  expect_s3_class(cat, "data.frame")
  expect_named(cat, c("dataset", "publication", "function_name",
                      "frequency", "start", "publisher", "slug",
                      "url", "description", "tags"))
  expect_gt(nrow(cat), 10L)
  expect_false(any(duplicated(cat$dataset)))
  expect_true(any(!is.na(cat$function_name)))
})

test_that("hmrc_search() returns matching rows for keyword query", {
  # Word-boundary regex to avoid matching "vat" in "innovation" etc.
  out <- hmrc_search("\\bvat\\b")
  expect_s3_class(out, "data.frame")
  expect_gt(nrow(out), 0L)
  expect_true("vat_monthly" %in% out$dataset)
  hay <- paste(out$dataset, out$publication, out$description)
  expect_true(all(grepl("\\bvat\\b", hay, ignore.case = TRUE)))
})

test_that("hmrc_search() supports case-insensitive regex", {
  out <- hmrc_search("CAPITAL.*GAINS")
  expect_true(any(grepl("capital gains", out$description, ignore.case = TRUE)) ||
              any(grepl("capital_gains", out$dataset)))
})

test_that("hmrc_search() implemented filter works", {
  imp <- hmrc_search(implemented = TRUE)
  pln <- hmrc_search(implemented = FALSE)
  expect_true(all(!is.na(imp$function_name)))
  expect_true(all(is.na(pln$function_name)))
})

test_that("hmrc_search() frequency filter works", {
  out <- hmrc_search(frequency = "annual")
  expect_true(all(out$frequency %in% "annual"))
})

test_that("hmrc_search() rejects invalid query types", {
  expect_error(hmrc_search(query = 1), "character string")
  expect_error(hmrc_search(implemented = "yes"), "TRUE")
})

test_that("hmrc_publications() returns indexed publications", {
  out <- hmrc_publications()
  expect_s3_class(out, "data.frame")
  expect_true("status" %in% names(out))
  expect_true(all(out$status %in% c("implemented", "planned")))
  expect_true("hmrc_tax_receipts" %in% out$function_name)
})

test_that("hmrc_publications() status filter works", {
  imp <- hmrc_publications("implemented")
  pln <- hmrc_publications("planned")
  expect_true(all(imp$status == "implemented"))
  expect_true(all(pln$status == "planned"))
  expect_true(all(!is.na(imp$function_name)))
  expect_true(all(is.na(pln$function_name)))
})

test_that("hmrc_publications() rejects invalid status", {
  expect_error(hmrc_publications("nonsense"))
})
