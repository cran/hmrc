#' List available tax heads in the HMRC Tax Receipts bulletin
#'
#' Returns a data frame describing all tax and duty heads available in
#' [get_tax_receipts()]. No network connection is required; the data is
#' bundled with the package.
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{tax_head}{Character. The identifier used in the `tax` argument of
#'       [get_tax_receipts()].}
#'     \item{description}{Character. Plain-English description of the series.}
#'     \item{category}{Character. Broad grouping: `"income"`, `"expenditure"`,
#'       `"consumption"`, `"property"`, `"environment"`, `"nics"`, or
#'       `"total"`.}
#'     \item{available_from}{Character. Earliest year of monthly data
#'       (approximate).}
#'   }
#'
#' @examples
#' list_tax_heads()
#'
#' @family data access
#' @export
list_tax_heads <- function() {
  tax_heads
}
