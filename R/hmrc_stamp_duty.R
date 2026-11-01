#' Download HMRC stamp duty receipts
#'
#' Downloads and tidies the HMRC Annual Stamp Tax Statistics, covering
#' Stamp Duty Land Tax (SDLT), Stamp Duty Reserve Tax (SDRT) on shares,
#' and other stamp duties. Annual data from 2003-04 to the most recent
#' financial year, published each December.
#'
#' @param type Character vector or `NULL` (default = all types).
#'   Valid values: `"sdlt_property"`, `"sdlt_leases"`, `"sdlt_total"`,
#'   `"sdrt"`, `"stamp_duty"`, `"shares_total"`, `"total"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `tax_year`, `type`, `description`,
#'   `receipts_gbp_m` (rounded to nearest GBP 5m by HMRC).
#'
#' @details
#' `sdlt_total` is SDLT on all property; `shares_total` is Stamp Duty
#' Reserve Tax plus Stamp Duty on share documents; `total` is all stamp
#' taxes. Land transaction taxes were devolved to Scotland (LBTT) in April
#' 2015 and Wales (LTT) in April 2018, so SDLT after those dates covers
#' England and Northern Ireland only.
#'
#' @source
#' <https://www.gov.uk/government/statistics/uk-stamp-tax-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   sd <- hmrc_stamp_duty(type = c("sdlt_total", "total"))
#'   tail(sd)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_stamp_duty <- function(type  = NULL,
                            cache = TRUE) {

  valid_types <- names(STAMP_COLS)
  if (!is.null(type)) {
    bad <- setdiff(type, valid_types)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown type{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_types}}"
      ))
    }
  }

  slug <- "uk-stamp-tax-statistics"
  loc  <- resolve_govuk_attachment(slug, "Annual_Stamps")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_stamp_duty_table(path)

  if (!is.null(type)) out <- out[out$type %in% type, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "stamp_duty_annual",
    hmrc_publication = "UK Stamp Tax statistics",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "cash",
    frequency        = "annual",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

STAMP_COLS <- c(
  sdlt_property = "^property excluding new leases",
  sdlt_leases   = "^new leases",
  sdlt_total    = "^all property",
  sdrt          = "^stamp duty reserve tax",
  stamp_duty    = "^stamp duty$",
  shares_total  = "^all shares",
  total         = "^total stamp"
)

STAMP_DESC <- c(
  sdlt_property = "SDLT on property (excl. new leases)",
  sdlt_leases   = "SDLT on new leases",
  sdlt_total    = "SDLT total (all property)",
  sdrt          = "Stamp Duty Reserve Tax (shares)",
  stamp_duty    = "Stamp Duty on documents (shares)",
  shares_total  = "Stamp taxes on shares (SDRT plus Stamp Duty)",
  total         = "Total stamp taxes"
)

parse_stamp_duty_table <- function(path) {
  pub <- "UK Stamp Tax statistics"
  raw <- read_sheet_raw(path, "Table_1a", pub)

  hdr <- find_row(raw, "^financial year$")[1]
  if (is.na(hdr)) abort_schema(pub, "the Table 1a header row")
  idx <- match_columns(unlist(raw[hdr, ]), STAMP_COLS, pub)

  years <- parse_tax_year(raw[[1]])
  rows  <- which(!is.na(years) & seq_along(years) > hdr)
  if (length(rows) == 0L) abort_schema(pub, "any financial-year rows")

  out <- do.call(rbind, lapply(names(STAMP_COLS), function(k) {
    data.frame(
      tax_year       = years[rows],
      type           = k,
      description    = STAMP_DESC[[k]],
      receipts_gbp_m = parse_num(raw[[idx[[k]]]][rows]),
      stringsAsFactors = FALSE
    )
  }))
  out <- out[order(out$type, out$tax_year), ]
  rownames(out) <- NULL
  out
}
