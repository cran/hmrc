#' hmrc: Download and Tidy HMRC Statistical Data
#'
#' Provides functions to download, parse, and tidy statistical data published
#' by HM Revenue and Customs (HMRC) on GOV.UK. Returns annotated `hmrc_tbl`
#' data frames with provenance metadata (source URL, fetch time, vintage,
#' cell methods) for reproducible fiscal research. File URLs are resolved at
#' runtime via the GOV.UK Content API, so data is always current.
#'
#' @section Data fetchers:
#' - [hmrc_tax_receipts()] — monthly tax receipts and NICs (April 2008+)
#' - [hmrc_property_transactions()] — monthly property transactions (April 2005+)
#' - [hmrc_income_tax_stats()] — annual Income Tax liabilities by income range
#' - [hmrc_tax_gap()] — annual tax gap estimates by tax type
#' - [hmrc_stamp_duty()] — annual stamp duty receipts (SDLT, SDRT)
#' - [hmrc_vat()] — monthly VAT receipts breakdown (April 1973+)
#' - [hmrc_rd_credits()] — annual R&D tax credit statistics (2000-01+)
#' - [hmrc_fuel_duties()] — monthly fuel duty receipts (January 1990+)
#' - [hmrc_tobacco_duties()] — monthly tobacco duty receipts (January 1991+)
#' - [hmrc_corporation_tax()] — annual Corporation Tax receipts by type
#' - [hmrc_capital_gains()] — annual CGT taxpayers, gains, liabilities (1987-88+)
#' - [hmrc_inheritance_tax()] — IHT estates and liabilities by net-estate band
#' - [hmrc_patent_box()] — annual Patent Box election counts and relief
#' - [hmrc_creative_industries()] — annual Film/HETV/Games/Theatre/etc reliefs
#'
#' @section Discovery and infrastructure:
#' - [hmrc_search()] — keyword search of the dataset catalogue
#' - [hmrc_publications()] — index of implemented + planned publications
#' - [hmrc_list_tax_heads()] — lookup table of tax-receipts identifiers
#' - [hmrc_cache_info()] — inspect locally cached files
#' - [hmrc_clear_cache()] — manage locally cached files
#' - [hmrc_meta()] — extract provenance metadata from any `hmrc_tbl` result
#'
#' @section Citation:
#' Run `citation("hmrc")` for the structured citation, or see the
#' `CITATION.cff` file at the package root for the GitHub citation widget.
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

utils::globalVariables(c("tax_heads", "catalogue"))
