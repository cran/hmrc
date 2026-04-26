# deprec.R — backwards-compatible aliases for the pre-0.4.0 `get_*` API.
#
# The package adopted the `hmrc_*` prefix in v0.4.0 to align with sibling
# packages (boe, fred, ons, obr). The old `get_*` names are kept as thin
# deprecated wrappers so existing user code continues to work; they will be
# removed in v0.6.0.
#
# Each alias issues a one-time-per-session deprecation warning via
# `lifecycle::deprecate_warn()` and forwards every argument unchanged.

#' Deprecated get_* aliases
#'
#' Renamed to use the `hmrc_*` prefix in v0.4.0. These aliases will be
#' removed in v0.6.0.
#'
#' @keywords internal
#' @name deprecated
NULL

#' @rdname deprecated
#' @export
get_tax_receipts <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_tax_receipts()", "hmrc_tax_receipts()")
  hmrc_tax_receipts(...)
}

#' @rdname deprecated
#' @export
get_vat <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_vat()", "hmrc_vat()")
  hmrc_vat(...)
}

#' @rdname deprecated
#' @export
get_fuel_duties <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_fuel_duties()", "hmrc_fuel_duties()")
  hmrc_fuel_duties(...)
}

#' @rdname deprecated
#' @export
get_tobacco_duties <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_tobacco_duties()", "hmrc_tobacco_duties()")
  hmrc_tobacco_duties(...)
}

#' @rdname deprecated
#' @export
get_corporation_tax <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_corporation_tax()", "hmrc_corporation_tax()")
  hmrc_corporation_tax(...)
}

#' @rdname deprecated
#' @export
get_stamp_duty <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_stamp_duty()", "hmrc_stamp_duty()")
  hmrc_stamp_duty(...)
}

#' @rdname deprecated
#' @export
get_property_transactions <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_property_transactions()",
                            "hmrc_property_transactions()")
  hmrc_property_transactions(...)
}

#' @rdname deprecated
#' @export
get_rd_credits <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_rd_credits()", "hmrc_rd_credits()")
  hmrc_rd_credits(...)
}

#' @rdname deprecated
#' @export
get_tax_gap <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_tax_gap()", "hmrc_tax_gap()")
  hmrc_tax_gap(...)
}

#' @rdname deprecated
#' @export
get_income_tax_stats <- function(...) {
  lifecycle::deprecate_warn("0.4.0", "get_income_tax_stats()",
                            "hmrc_income_tax_stats()")
  hmrc_income_tax_stats(...)
}

#' @rdname deprecated
#' @export
list_tax_heads <- function() {
  lifecycle::deprecate_warn("0.4.0", "list_tax_heads()", "hmrc_list_tax_heads()")
  hmrc_list_tax_heads()
}

#' @rdname deprecated
#' @export
clear_cache <- function(max_age_days = NULL) {
  lifecycle::deprecate_warn("0.4.0", "clear_cache()", "hmrc_clear_cache()")
  hmrc_clear_cache(max_age_days = max_age_days)
}
