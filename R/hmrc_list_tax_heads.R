#' List available tax heads in the HMRC Tax Receipts bulletin
#'
#' Returns a data frame describing all tax and duty heads available in
#' [hmrc_tax_receipts()]. No network connection is required: the data is
#' bundled with the package.
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{tax_head}{Character. Identifier used in the `tax` argument of
#'       [hmrc_tax_receipts()].}
#'     \item{description}{Character. Plain-English description.}
#'     \item{category}{Character. Broad grouping.}
#'     \item{available_from}{Character. Earliest year of monthly data.}
#'   }
#'
#' @examples
#' hmrc_list_tax_heads()
#'
#' @family infrastructure
#' @export
hmrc_list_tax_heads <- function() {
  tax_heads
}
