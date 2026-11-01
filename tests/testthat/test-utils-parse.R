test_that("parse_num() strips separators and suppression markers", {
  expect_equal(parse_num(c("1,860", "\u00a3741", "14.1%", "-7460")),
               c(1860, 741, 14.1, -7460))
  expect_equal(parse_num(c("[x]", "[c]", "[z]", "[Unavailable]", "N/A",
                           "[no estimate]", "<0.1", "", NA)),
               rep(NA_real_, 9))
  expect_equal(parse_num("1.4999999999999999E-2"), 0.015)
})

test_that("as_percent() rescales proportions only", {
  expect_equal(as_percent(c(0.015, 0.179, NA)), c(1.5, 17.9, NA))
  expect_equal(as_percent(c(56, 44)), c(56, 44))
  expect_true(all(is.na(as_percent(c(NA_real_, NA_real_)))))
})

test_that("parse_month_year() ignores notes and does not depend on locale", {
  x <- c("January 2025", "February 2026 [provisional]",
         "July 2026 [provisional estimates]", "Sept 2024", "2025",
         "1989 to 1990", "End of worksheet")
  expected <- as.Date(c("2025-01-01", "2026-02-01", "2026-07-01",
                        "2024-09-01", NA, NA, NA))
  expect_equal(parse_month_year(x), expected)

  french <- suppressWarnings(
    tryCatch(withr::with_locale(c(LC_TIME = "fr_FR.UTF-8"),
                                parse_month_year("March 2025")),
             error = function(e) NULL)
  )
  if (!is.null(french)) expect_equal(french, as.Date("2025-03-01"))
})

test_that("parse_tax_year() normalises HMRC year labels", {
  expect_equal(
    parse_tax_year(c("2023-24", "2023 to 2024", "2008 to 2009 [Note 2]",
                     "2023-24 (projection)", "1999-00", "2023/24",
                     "Total", "January 2025")),
    c("2023-24", "2023-24", "2008-09", "2023-24", "1999-00", "2023-24",
      NA, NA)
  )
})

test_that("row_label_note() extracts trailing parenthetical labels", {
  expect_equal(row_label_note(c("2023-24 (projection)", "2022-23")),
               c("projection", NA))
})

test_that("match_columns() maps by header and fails with a classed error", {
  header <- c("Month", "Cigarettes", "Cigars", "HRT", "Other", "Overall total")
  idx <- match_columns(header, TOBACCO_COLS, "Tobacco Bulletin")
  expect_equal(unname(idx), 2:6)

  expect_error(
    match_columns(c("Month", "Cigs"), TOBACCO_COLS, "Tobacco Bulletin"),
    class = "hmrc_error_schema"
  )
  idx2 <- match_columns(c("Year", "Number of claims"), CREATIVE_COLS,
                        "Creative Industries statistics",
                        optional = c("companies", "productions", "relief_gbp_m",
                                     "status"))
  expect_true(is.na(idx2[["companies"]]))
})

test_that("header matching ignores note markers", {
  expect_equal(clean_header("Number of individuals [Note 1]"),
               "Number of individuals")
})

test_that("read_monthly_block() finds the monthly table under stacked tables", {
  raw <- data.frame(
    X1 = c("Table 1a: by financial year", "2024 to 2025",
           "Table 1b: by calendar month", "January 2025",
           "February 2025 [provisional]", "End of worksheet"),
    X2 = c("Total petrol", "9000", "Total petrol", "741", "700", NA),
    X3 = c("Total diesel", "12000", "Total diesel", "1027", "990", NA),
    stringsAsFactors = FALSE
  )
  blk <- read_monthly_block(raw, "test")
  expect_equal(blk$rows, 4:5)
  expect_equal(blk$dates, as.Date(c("2025-01-01", "2025-02-01")))
  expect_equal(blk$provisional, c(FALSE, TRUE))
  expect_equal(blk$header[2], "Total petrol")
})

test_that("cache keys are unique per GOV.UK media id", {
  # These two URLs collided under the pre-0.4.1 checksum key
  u1 <- "https://assets.publishing.service.gov.uk/media/1aa46bbd426eed6d5ae0e972/MPT_Tab_Aug_26.ods"
  u2 <- "https://assets.publishing.service.gov.uk/media/d51a1a081cc2bb115efefe16/MPT_Tab_Aug_26.ods"
  expect_false(identical(hmrc_cache_key(u1), hmrc_cache_key(u2)))
  expect_equal(hmrc_cache_key(u1), "1aa46bbd426eed6d5ae0e972_MPT_Tab_Aug_26.ods")
  expect_match(hmrc_cache_key(u1, vintage_key = "2026-01-01"), "@2026-01-01\\.ods$")
})

test_that("is_zip_file() recognises zip containers", {
  good <- withr::local_tempfile(fileext = ".ods")
  bad  <- withr::local_tempfile(fileext = ".ods")
  writeBin(charToRaw("PK\003\004rest"), good)
  writeLines("<html>error</html>", bad)
  expect_true(is_zip_file(good))
  expect_false(is_zip_file(bad))
})

test_that("parse_govuk_time() handles GOV.UK offsets", {
  expect_equal(format(parse_govuk_time("2026-08-21T07:00:03+01:00"),
                      "%Y-%m-%d %H:%M:%S", tz = "UTC"),
               "2026-08-21 06:00:03")
  expect_true(is.na(parse_govuk_time(NA_character_)))
})
