test_that("hmrc_corporation_tax() returns expected structure with provenance", {
  skip_on_cran()
  skip_if_offline()

  out <- hmrc_corporation_tax()

  expect_s3_class(out, "hmrc_tbl")
  expect_named(out, c("tax_year", "type", "description", "receipts_gbp_m"))
  expect_type(out$tax_year, "character")
  expect_type(out$type, "character")
  expect_type(out$receipts_gbp_m, "double")
  expect_true(all(grepl("^\\d{4}-\\d{2}$", out$tax_year)))

  m <- hmrc_meta(out)
  expect_equal(m$dataset, "corporation_tax_annual")
  expect_equal(m$frequency, "annual")
})

test_that("hmrc_corporation_tax() all corporate taxes add up", {
  skip_on_cran()
  skip_if_offline()

  out <- as.data.frame(hmrc_corporation_tax())
  w <- reshape(out[, c("tax_year", "type", "receipts_gbp_m")],
               idvar = "tax_year", timevar = "type", direction = "wide")
  levies <- grep("bank_levy|bank_surcharge|rpdt|energy_profits|electricity",
                 names(w), value = TRUE)
  parts <- w$receipts_gbp_m.total_ct + rowSums(w[, levies], na.rm = TRUE)
  expect_lt(max(abs(w$receipts_gbp_m.all_corporate_taxes - parts)), 5)
})
