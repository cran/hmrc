#' Tax head lookup table
#'
#' A data frame describing all tax and duty series available in
#' [hmrc_tax_receipts()].
#'
#' @format A data frame with 42 rows and 4 columns:
#'   \describe{
#'     \item{tax_head}{Character. Identifier used in the `tax` argument of
#'       [hmrc_tax_receipts()].}
#'     \item{description}{Character. Plain-English description.}
#'     \item{category}{Character. Broad grouping: `"income"`, `"nics"`,
#'       `"consumption"`, `"property"`, `"environment"`, `"other"`, or
#'       `"total"`.}
#'     \item{available_from}{Character. First year with receipts in HMRC's
#'       monthly table at the package release. The table is a rolling window
#'       (currently April 2017 onwards), so long-standing taxes show the
#'       window start. `NA` means no receipts in the current window.}
#'   }
#'
#' @source
#' Derived from the HMRC Tax Receipts and NICs bulletin.
#' <https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk>
"tax_heads"
