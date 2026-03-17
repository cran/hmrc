#' hmrc: Download and Tidy HMRC Statistical Data
#'
#' Provides functions to download, parse, and tidy statistical data published
#' by HM Revenue and Customs (HMRC) on GOV.UK. Covers tax receipts, National
#' Insurance contributions, and property transactions. File URLs are resolved
#' at runtime via the GOV.UK Content API, so data is always current.
#'
#' @section Main functions:
#' - [get_tax_receipts()] — monthly tax receipts and NICs (all heads, April 2016+)
#' - [get_property_transactions()] — monthly property transaction counts (April 2005+)
#' - [get_income_tax_stats()] — annual Income Tax liabilities by income range
#' - [get_tax_gap()] — annual tax gap estimates by tax type
#' - [get_stamp_duty()] — annual stamp duty receipts (SDLT, SDRT)
#' - [get_vat()] — monthly VAT receipts breakdown (April 1973+)
#' - [get_rd_credits()] — annual R&D tax credit statistics (2000-01+)
#' - [get_fuel_duties()] — monthly fuel duty receipts (January 1990+)
#' - [get_tobacco_duties()] — monthly tobacco duty receipts (January 1991+)
#' - [get_corporation_tax()] — annual Corporation Tax receipts by type
#' - [list_tax_heads()] — lookup table of available tax head identifiers
#' - [clear_cache()] — manage locally cached files
#'
#' @section Data source:
#' All data is published by HMRC on GOV.UK under the Open Government Licence.
#' See <https://www.gov.uk/government/organisations/hm-revenue-customs/about/statistics>.
#'
#' @keywords internal
#' @concept HMRC
#' @concept UK tax
#' @concept tax revenue
#' @concept VAT
#' @concept income tax
#' @concept corporation tax
#' @concept stamp duty
#' @concept fuel duty
#' @concept tobacco duty
#' @concept government revenue
"_PACKAGE"

utils::globalVariables("tax_heads")
