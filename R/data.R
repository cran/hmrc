#' Tax head lookup table
#'
#' A data frame describing all tax and duty series available in
#' [get_tax_receipts()].
#'
#' @format A data frame with 41 rows and 4 columns:
#'   \describe{
#'     \item{tax_head}{Character. Identifier used in the `tax` argument of
#'       [get_tax_receipts()].}
#'     \item{description}{Character. Plain-English description.}
#'     \item{category}{Character. Broad grouping: `"income"`, `"nics"`,
#'       `"consumption"`, `"property"`, `"environment"`, `"expenditure"`,
#'       `"other"`, or `"total"`.}
#'     \item{available_from}{Character. Approximate start year of monthly data.}
#'   }
#'
#' @source
#' Derived from the HMRC Tax Receipts and NICs bulletin.
#' <https://www.gov.uk/government/statistics/hmrc-tax-and-nics-receipts-for-the-uk>
"tax_heads"
