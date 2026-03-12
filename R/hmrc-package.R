#' hmrc: Download and Tidy HMRC Statistical Data
#'
#' Provides functions to download, parse, and tidy statistical data published
#' by HM Revenue and Customs (HMRC) on GOV.UK. Covers tax receipts, National
#' Insurance contributions, and property transactions. File URLs are resolved
#' at runtime via the GOV.UK Content API, so data is always current.
#'
#' @section Main functions:
#' - [get_tax_receipts()] — monthly tax receipts and NICs (all heads, April 1999+)
#' - [get_property_transactions()] — monthly property transaction counts (Sep 2013+)
#' - [list_tax_heads()] — lookup table of available tax head identifiers
#' - [clear_cache()] — manage locally cached files
#'
#' @section Data source:
#' All data is published by HMRC on GOV.UK under the Open Government Licence.
#' See <https://www.gov.uk/government/organisations/hm-revenue-customs/about/statistics>.
#'
#' @keywords internal
"_PACKAGE"

utils::globalVariables("tax_heads")
