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
  expect_named(out, c("tax_year", "scheme", "description", "measure",
                      "value", "status"))
  expect_true(all(out$scheme == "sme"))
  expect_true(all(out$measure == "claims"))
  expect_false(anyNA(out$status))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "rd_credits_annual")
})

test_that("hmrc_rd_credits() SME plus RDEC matches the all-schemes total", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_rd_credits())
  expect_true("2024-25" %in% out$tax_year)
  # HMRC reports ERIS inside "SME Total" and the merged scheme inside
  # "RDEC & Merged RDEC Total", so the two groups add up to HMRC's total in
  # every year, before and after the April 2024 merger
  for (m in c("claims", "amount_gbp_m")) {
    d <- out[out$measure == m, ]
    w <- reshape(d[, c("tax_year", "scheme", "value")], idvar = "tax_year",
                 timevar = "scheme", direction = "wide")
    parts <- rowSums(w[, c("value.sme", "value.rdec")], na.rm = TRUE)
    rel <- abs(w$value.total - parts) / w$value.total
    expect_lt(max(rel, na.rm = TRUE), 0.02, label = m)
  }
})

test_that("RDEC total column matches the pre- and post-merger headers", {
  old <- c("Financial Year", "Status", "SME Total", "LC & RDEC Total",
           "Total Claims")
  new <- c("Financial Year", "Status", "SME Total", "RDEC by LCs",
           "Merged RDEC by LCs", "RDEC & Merged RDEC Total", "Total Claims")
  spec <- RD_SHEETS$claims$cols
  expect_equal(match_columns(old, spec, "test")[["rdec"]], 4L)
  expect_equal(match_columns(new, spec, "test")[["rdec"]], 6L)
})
