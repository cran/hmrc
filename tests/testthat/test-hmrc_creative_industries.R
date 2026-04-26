test_that("hmrc_creative_industries() rejects unknown sector", {
  expect_error(
    hmrc_creative_industries(sector = "podcast"),
    "Unknown sector"
  )
})

test_that("hmrc_creative_industries() returns expected structure", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_creative_industries(sector = "film")

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("sector", "tax_year", "companies", "claims",
                      "productions", "relief_gbp_m", "status"))
  expect_true(all(out$sector == "film"))
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "creative_industries_reliefs")
})

test_that("hmrc_creative_industries() covers all eight sectors", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_creative_industries()
  expect_setequal(
    unique(out$sector),
    c("film", "high_end_tv", "animation", "childrens_tv",
      "video_games", "theatre", "orchestra", "museum")
  )
})
