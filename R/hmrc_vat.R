#' Download HMRC VAT receipts
#'
#' Downloads and tidies the HMRC VAT Annual Statistics bulletin, which
#' reports monthly VAT receipts broken down into payments, repayments,
#' import VAT, and home VAT. Monthly data runs from April 1973; the
#' bulletin is published annually (December).
#'
#' @param measure Character vector or `NULL` (default = all measures).
#'   Valid values: `"total"`, `"payments"`, `"repayments"`,
#'   `"import_vat"`, `"home_vat"`.
#' @param start Character `"YYYY-MM"` or a `Date` object.
#' @param end Character `"YYYY-MM"` or a `Date` object.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `date`, `measure`, `description`,
#'   `receipts_gbp_m`. Repayments are negative.
#'
#' @details
#' Note that early years (pre-1985) have suppressed payment and repayment
#' splits; only the total is available for those periods. From January 2021,
#' import VAT collected via postponed VAT accounting is recorded within
#' payments and repayments rather than the import VAT column.
#'
#' @source
#' <https://www.gov.uk/government/statistics/value-added-tax-vat-annual-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   vat <- hmrc_vat(measure = c("total", "repayments"), start = "2024-01")
#'   head(vat)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_vat <- function(measure = NULL,
                     start   = NULL,
                     end     = NULL,
                     cache   = TRUE) {

  valid_measures <- c("total", "payments", "repayments", "import_vat", "home_vat")
  if (!is.null(measure)) {
    bad <- setdiff(measure, valid_measures)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown measure{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_measures}}"
      ))
    }
  }
  if (!is.null(start)) parse_month_arg(start, "start")
  if (!is.null(end))   parse_month_arg(end,   "end")

  slug <- "value-added-tax-vat-annual-statistics"
  loc  <- resolve_govuk_attachment(slug, "Annual_UK_VAT")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_vat_table(path)

  if (!is.null(measure)) out <- out[out$measure %in% measure, ]
  out <- filter_dates(out, start, end)
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "vat_monthly",
    hmrc_publication = "VAT annual statistics (monthly receipts)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "cash",
    frequency        = "monthly",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

VAT_COLS <- c(
  payments   = "^payments",
  repayments = "^repayments",
  import_vat = "^import vat",
  home_vat   = "^(net )?home vat",
  total      = "^total vat"
)

VAT_DESC <- c(
  payments   = "VAT payments",
  repayments = "VAT repayments",
  import_vat = "Import VAT",
  home_vat   = "Net home VAT (payments less repayments)",
  total      = "Total VAT receipts"
)

parse_vat_table <- function(path) {
  pub <- "VAT annual statistics"
  raw <- read_sheet_raw(path, "T1_VAT_receipts", pub)
  blk <- read_monthly_block(raw, pub)
  idx <- match_columns(blk$header, VAT_COLS, pub)

  out <- do.call(rbind, lapply(names(VAT_COLS), function(k) {
    data.frame(
      date           = blk$dates,
      measure        = k,
      description    = VAT_DESC[[k]],
      receipts_gbp_m = parse_num(raw[[idx[[k]]]][blk$rows]),
      stringsAsFactors = FALSE
    )
  }))
  out <- out[order(out$measure, out$date), ]
  rownames(out) <- NULL
  out
}
