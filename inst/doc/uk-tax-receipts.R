## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## ----load---------------------------------------------------------------------
# library(hmrc)

## ----discover-----------------------------------------------------------------
# # Anything in the catalogue mentioning capital gains
# hmrc_search("capital gains")
# 
# # Only annual datasets already implemented
# hmrc_search(implemented = TRUE, frequency = "annual")

## ----receipts-basic-----------------------------------------------------------
# # All 41 tax heads
# receipts <- hmrc_tax_receipts()
# head(receipts)
# #>         date   tax_head          description receipts_gbp_m
# #>   2016-04-01 income_tax Income Tax (PAYE...          17423
# #>   2016-05-01 income_tax Income Tax (PAYE...          11847

## ----list-heads---------------------------------------------------------------
# hmrc_list_tax_heads()

## ----receipts-filter----------------------------------------------------------
# big_three <- hmrc_tax_receipts(
#   tax   = c("income_tax", "vat", "nics_total"),
#   start = "2020-01"
# )

## ----meta---------------------------------------------------------------------
# hmrc_meta(big_three)
# #> $dataset
# #> [1] "tax_receipts_monthly"
# #> $source_url
# #> [1] "https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk"
# #> $cell_methods
# #> [1] "cash"
# #> $frequency
# #> [1] "monthly"
# #> $fetched_at
# #> [1] "2026-04-26 09:00:00 UTC"

## ----receipts-plot, fig.width = 7, fig.height = 4-----------------------------
# library(ggplot2)
# 
# ggplot(big_three, aes(x = date, y = receipts_gbp_m / 1000, colour = description)) +
#   geom_line(linewidth = 0.8) +
#   scale_y_continuous(labels = scales::label_comma(suffix = "bn")) +
#   labs(
#     title   = "UK monthly tax receipts",
#     x       = NULL,
#     y       = "GBP billions",
#     colour  = NULL,
#     caption = "Source: HMRC Tax Receipts and NICs bulletin"
#   ) +
#   theme_minimal(base_size = 12) +
#   theme(legend.position = "bottom")

## ----vat----------------------------------------------------------------------
# # Net VAT: total minus repayments
# vat <- hmrc_vat(measure = c("total", "repayments"), start = "2015-01")
# 
# # Repayments are recorded as negative (money flowing out of HMRC)
# head(vat[vat$measure == "repayments", c("date", "receipts_gbp_m")])

## ----fuel---------------------------------------------------------------------
# fuel <- hmrc_fuel_duties(fuel = "total", start = "2010-01")
# 
# # Annual totals
# fuel$year <- format(fuel$date, "%Y")
# aggregate(receipts_gbp_m ~ year, data = fuel, FUN = sum)

## ----tobacco------------------------------------------------------------------
# tobacco <- hmrc_tobacco_duties(product = c("cigarettes", "hand_rolling"),
#                                start   = "2015-01")

## ----ct-----------------------------------------------------------------------
# ct <- hmrc_corporation_tax()
# ct[ct$type == "total_ct", c("tax_year", "receipts_gbp_m")]

## ----stamp--------------------------------------------------------------------
# sd <- hmrc_stamp_duty(type = "sdlt_total")
# tail(sd[, c("tax_year", "receipts_gbp_m")], 5)

## ----rd-----------------------------------------------------------------------
# # Cost of R&D credits: SME vs RDEC
# rd <- hmrc_rd_credits(measure = "amount_gbp_m")
# rd[rd$tax_year == "2023-24", c("scheme", "description", "value")]

## ----cgt----------------------------------------------------------------------
# # Total CGT receipts over time
# cgt <- hmrc_capital_gains(measure = "tax_total_gbp_m")
# tail(cgt[, c("tax_year", "value")], 6)

## ----iht----------------------------------------------------------------------
# iht <- hmrc_inheritance_tax()
# iht[iht$measure == "number_taxed" & iht$estate_band != "Total",
#     c("estate_band", "value")]

## ----patent-box---------------------------------------------------------------
# hmrc_patent_box()

## ----creative-----------------------------------------------------------------
# # Film tax relief over time
# hmrc_creative_industries(sector = "film")
# 
# # All eight sectors in the latest year
# hmrc_creative_industries(tax_year = "2023-24")

## ----taxgap-------------------------------------------------------------------
# gap <- hmrc_tax_gap()
# 
# # Sort by absolute gap
# gap[order(-gap$gap_gbp_bn),
#     c("tax", "component", "gap_gbp_bn", "uncertainty")]

## ----income-tax---------------------------------------------------------------
# it <- hmrc_income_tax_stats(tax_year = "2023-24")
# it[, c("income_range", "taxpayers_thousands", "tax_liability_gbp_m", "average_rate_pct")]

## ----property-----------------------------------------------------------------
# prop <- hmrc_property_transactions(
#   type   = "residential",
#   nation = "uk",
#   start  = "2018-01"
# )

## ----property-plot, fig.width = 7, fig.height = 4-----------------------------
# ggplot(prop, aes(x = date, y = transactions / 1000)) +
#   geom_line(colour = "#3B82F6", linewidth = 0.8) +
#   scale_y_continuous(labels = scales::label_comma(suffix = "k")) +
#   labs(
#     title   = "UK residential property transactions",
#     x       = NULL,
#     y       = "Transactions (thousands)",
#     caption = "Source: HMRC Monthly Property Transactions bulletin"
#   ) +
#   theme_minimal(base_size = 12)

## ----cache--------------------------------------------------------------------
# # Inspect the cache
# hmrc_cache_info()
# 
# # Remove files older than 30 days
# hmrc_clear_cache(max_age_days = 30)
# 
# # Remove everything and start fresh
# hmrc_clear_cache()

