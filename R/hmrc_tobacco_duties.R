#' Download HMRC tobacco duty receipts
#'
#' Downloads and tidies the HMRC Tobacco Bulletin, which reports monthly
#' tobacco products duty receipts by product type. Data runs from January
#' 1991 to the most recent published month.
#'
#' @param product Character vector or `NULL` (default = all products).
#'   Valid values: `"cigarettes"`, `"cigars"`, `"hand_rolling"`,
#'   `"other"`, `"total"`.
#' @param start Character `"YYYY-MM"` or a `Date` object.
#' @param end Character `"YYYY-MM"` or a `Date` object.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `date`, `product`, `description`,
#'   `receipts_gbp_m`, and `provisional` (logical, `TRUE` for months HMRC
#'   flags as provisional).
#'
#' @source
#' <https://www.gov.uk/government/statistics/tobacco-bulletin>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   tob <- hmrc_tobacco_duties(product = "cigarettes", start = "2024-01")
#'   head(tob)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_tobacco_duties <- function(product = NULL,
                                start   = NULL,
                                end     = NULL,
                                cache   = TRUE) {

  valid_products <- names(TOBACCO_COLS)
  if (!is.null(product)) {
    bad <- setdiff(product, valid_products)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown product{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_products}}"
      ))
    }
  }
  if (!is.null(start)) parse_month_arg(start, "start")
  if (!is.null(end))   parse_month_arg(end,   "end")

  slug <- "tobacco-bulletin"
  loc  <- resolve_govuk_attachment(slug, "Tobacco_Tab")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_tobacco_table(path)

  if (!is.null(product)) out <- out[out$product %in% product, ]
  out <- filter_dates(out, start, end)
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "tobacco_duties_monthly",
    hmrc_publication = "Tobacco Bulletin",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "cash",
    frequency        = "monthly",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

TOBACCO_COLS <- c(
  cigarettes   = "^cigarettes",
  cigars       = "^cigars",
  hand_rolling = "^(hrt|hand.?rolling)",
  other        = "^other",
  total        = "total$"
)

TOBACCO_DESC <- c(
  cigarettes   = "Cigarettes",
  cigars       = "Cigars",
  hand_rolling = "Hand-rolling tobacco",
  other        = "Other tobacco products",
  total        = "Total tobacco products"
)

parse_tobacco_table <- function(path) {
  pub <- "Tobacco Bulletin"
  raw <- read_sheet_raw(path, "Table_1_receipts", pub)
  blk <- read_monthly_block(raw, pub)
  idx <- match_columns(blk$header, TOBACCO_COLS, pub)

  out <- do.call(rbind, lapply(names(TOBACCO_COLS), function(k) {
    data.frame(
      date           = blk$dates,
      product        = k,
      description    = TOBACCO_DESC[[k]],
      receipts_gbp_m = parse_num(raw[[idx[[k]]]][blk$rows]),
      provisional    = blk$provisional,
      stringsAsFactors = FALSE
    )
  }))
  out <- out[order(out$product, out$date), ]
  rownames(out) <- NULL
  out
}
