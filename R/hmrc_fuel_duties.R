#' Download HMRC hydrocarbon oil (fuel duty) receipts
#'
#' Downloads and tidies the HMRC Hydrocarbon Oils Bulletin, which reports
#' monthly fuel duty receipts. Data runs from January 1990 to the most
#' recent published month, updated twice per year (January and July).
#'
#' @param fuel Character vector or `NULL` (default = all).
#'   Valid values: `"total"`, `"petrol"`, `"diesel"`, `"other"`.
#' @param start Character `"YYYY-MM"` or a `Date` object.
#' @param end Character `"YYYY-MM"` or a `Date` object.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` with columns `date`, `fuel`, `description`,
#'   `receipts_gbp_m`, and `provisional` (logical, `TRUE` for months HMRC
#'   flags as provisional).
#'
#' @details
#' `petrol` and `diesel` are HMRC's "Total petrol" and "Total diesel"
#' columns. `other` is the sum of fuel oil, gas oil and road fuel gases.
#' `total` is HMRC's total hydrocarbon oils receipts.
#'
#' @source
#' <https://www.gov.uk/government/statistics/hydrocarbon-oils-bulletin>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = file.path(tempdir(), "hmrc"))
#' try({
#'   fuel <- hmrc_fuel_duties(fuel = "total", start = "2024-01")
#'   head(fuel)
#' })
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_fuel_duties <- function(fuel  = NULL,
                             start = NULL,
                             end   = NULL,
                             cache = TRUE) {

  valid_fuels <- c("total", "petrol", "diesel", "other")
  if (!is.null(fuel)) {
    bad <- setdiff(fuel, valid_fuels)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown fuel category: {.val {bad}}",
        "i" = "Valid values: {.val {valid_fuels}}"
      ))
    }
  }
  if (!is.null(start)) parse_month_arg(start, "start")
  if (!is.null(end))   parse_month_arg(end,   "end")

  slug <- "hydrocarbon-oils-bulletin"
  loc  <- resolve_govuk_attachment(slug, "Oils_Tab")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_fuel_table(path)

  if (!is.null(fuel)) out <- out[out$fuel %in% fuel, ]
  out <- filter_dates(out, start, end)
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "fuel_duties_monthly",
    hmrc_publication = "Hydrocarbon Oils Bulletin (fuel duties)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "cash",
    frequency        = "monthly",
    published_at     = loc$public_updated_at
  )
}

# -- Internal parser -----------------------------------------------------------

# Only HMRC's own totals are read for petrol and diesel. Summing the
# component columns as well would double count, because each block ends
# with its own "Total" column.
FUEL_COLS <- c(
  petrol   = "^total petrol",
  diesel   = "^total diesel",
  fuel_oil = "^fuel oil",
  gas_oil  = "^gas oil",
  rfg      = "^road fuel gas",
  total    = "^total hydrocarbon oil"
)

FUEL_DESC <- c(
  petrol = "Petrol duties",
  diesel = "Diesel duties",
  other  = "Other oils duties (fuel oil, gas oil, road fuel gases)",
  total  = "Total hydrocarbon oils receipts"
)

parse_fuel_table <- function(path) {
  pub <- "Hydrocarbon Oils Bulletin"
  raw <- read_sheet_raw(path, "Table_1_receipts", pub)
  blk <- read_monthly_block(raw, pub)
  idx <- match_columns(blk$header, FUEL_COLS, pub)

  col_vals <- function(key) parse_num(raw[[idx[[key]]]][blk$rows])

  parts <- cbind(col_vals("fuel_oil"), col_vals("gas_oil"), col_vals("rfg"))
  other <- rowSums(parts, na.rm = TRUE)
  other[rowSums(!is.na(parts)) == 0L] <- NA_real_

  values <- list(
    petrol = col_vals("petrol"),
    diesel = col_vals("diesel"),
    other  = other,
    total  = col_vals("total")
  )

  out <- do.call(rbind, lapply(names(values), function(k) {
    data.frame(
      date           = blk$dates,
      fuel           = k,
      description    = FUEL_DESC[[k]],
      receipts_gbp_m = values[[k]],
      provisional    = blk$provisional,
      stringsAsFactors = FALSE
    )
  }))
  out <- out[order(out$fuel, out$date), ]
  rownames(out) <- NULL
  out
}
