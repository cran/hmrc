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
  expect_true(all(c("film", "high_end_tv", "animation", "childrens_tv",
                    "video_games", "theatre", "orchestra", "museum") %in%
                    out$sector))
})

test_that("hmrc_creative_industries() reads production counts for TV", {
  skip_on_cran()
  skip_if_offline()

  # TV sheets label the column "Number of programmes"
  out <- hmrc_creative_industries(sector = c("high_end_tv", "animation"))
  expect_gt(mean(!is.na(out$productions)), 0.9)
})

test_that("creative_total_header() keeps the all-reliefs columns", {
  split <- c("Year", "Number of companies: tax relief",
             "Amount of relief paid: tax relief", "Number of companies: AVEC",
             "Amount of relief paid: AVEC", "Number of companies: total",
             "Amount of relief paid: total", "Status")
  idx <- match_columns(creative_total_header(split), CREATIVE_COLS, "test",
                       optional = c("claims", "productions"))
  expect_equal(idx[["companies"]], 6L)
  expect_equal(idx[["relief_gbp_m"]], 7L)
  expect_equal(idx[["status"]], 8L)

  plain <- c("Year", "Number of companies", "Number of claims",
             "Number of productions", "Amount of relief paid", "Status")
  expect_equal(creative_total_header(plain), plain)
})

test_that("hmrc_creative_industries() returns all reliefs, not the legacy relief alone", {
  skip_on_cran()
  skip_if_offline()

  out  <- hmrc_creative_industries(sector = c("film", "video_games"))
  path <- download_cached(hmrc_meta(out)$attachment_url)
  for (sec in c("film", "video_games")) {
    raw <- read_sheet_raw(path, CREATIVE_SECTOR_SHEETS[[sec]])
    hdr <- find_row(raw, "^year$")[1]
    h   <- clean_header(unlist(raw[hdr, ]))
    amt <- which(grepl("^amount of relief", h, ignore.case = TRUE))
    skip_if(length(amt) < 2L, "HMRC no longer splits this sheet by relief type")
    tot   <- amt[grepl("total$", h[amt], ignore.case = TRUE)]
    parts <- setdiff(amt, tot)
    years <- parse_tax_year(raw[[1]])
    rows  <- which(!is.na(years))
    hmrc_total <- parse_num(raw[[tot]][rows])
    summed     <- rowSums(sapply(parts, function(j) parse_num(raw[[j]][rows])),
                          na.rm = TRUE)
    got <- out$relief_gbp_m[out$sector == sec][match(years[rows],
                                                     out$tax_year[out$sector == sec])]
    # The fetcher returns HMRC's total, and that total is the sum of the
    # legacy relief and the expenditure credits (to rounding)
    expect_equal(got, hmrc_total, label = sec)
    expect_lt(max(abs(hmrc_total - summed)), 3, label = sec)
  }
})
