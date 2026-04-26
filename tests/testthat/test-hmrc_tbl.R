test_that("new_hmrc_tbl() attaches expected metadata", {
  df <- data.frame(date = as.Date("2024-01-01"), value = 100)
  out <- hmrc:::new_hmrc_tbl(
    df,
    dataset          = "demo",
    hmrc_publication = "Demo dataset",
    source_url       = "https://example.com/page",
    attachment_url   = "https://example.com/file.ods",
    slug             = "demo-slug",
    cell_methods     = "cash",
    frequency        = "monthly"
  )

  expect_s3_class(out, "hmrc_tbl")
  expect_s3_class(out, "data.frame")

  m <- hmrc_meta(out)
  expect_type(m, "list")
  expect_equal(m$dataset, "demo")
  expect_equal(m$hmrc_publication, "Demo dataset")
  expect_equal(m$source_url, "https://example.com/page")
  expect_equal(m$attachment_url, "https://example.com/file.ods")
  expect_equal(m$cell_methods, "cash")
  expect_equal(m$frequency, "monthly")
  expect_true(inherits(m$fetched_at, "POSIXt"))
  expect_true(is.na(m$vintage_date))
})

test_that("print.hmrc_tbl() emits a provenance header", {
  df  <- data.frame(date = as.Date("2024-01-01"), value = 100)
  out <- hmrc:::new_hmrc_tbl(df, hmrc_publication = "Header test",
                             source_url = "https://example.com/p")

  txt <- capture.output(print(out))
  expect_true(any(grepl("Header test", txt)))
  expect_true(any(grepl("Source: https://example.com/p", txt)))
  expect_true(any(grepl("Vintage: latest", txt)))
})

test_that("as.data.frame.hmrc_tbl() strips class and metadata", {
  df  <- data.frame(date = as.Date("2024-01-01"), value = 100)
  out <- hmrc:::new_hmrc_tbl(df, hmrc_publication = "Strip test")

  bare <- as.data.frame(out)
  expect_false(inherits(bare, "hmrc_tbl"))
  expect_null(attr(bare, "hmrc_meta"))
  expect_s3_class(bare, "data.frame")
})

test_that("subsetting [.hmrc_tbl preserves provenance", {
  df  <- data.frame(date = as.Date(c("2024-01-01", "2024-02-01")), value = c(100, 200))
  out <- hmrc:::new_hmrc_tbl(df, hmrc_publication = "Subset test")

  sub <- out[1, ]
  expect_s3_class(sub, "hmrc_tbl")
  expect_equal(hmrc_meta(sub)$hmrc_publication, "Subset test")
})

test_that("hmrc_meta() returns NULL for non-hmrc_tbl objects", {
  expect_null(hmrc_meta(data.frame(x = 1)))
  expect_null(hmrc_meta(NULL))
})
