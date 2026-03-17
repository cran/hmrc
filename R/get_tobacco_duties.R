#' Download HMRC tobacco duty receipts
#'
#' Downloads and tidies the HMRC Tobacco Bulletin, which reports monthly
#' tobacco products duty receipts by product type. Data runs from January
#' 1991 to the most recent published month, updated twice per year
#' (February and August).
#'
#' @param product Character vector or `NULL` (default = all products).
#'   Valid values: `"cigarettes"`, `"cigars"`, `"hand_rolling"`,
#'   `"other"`, `"total"`.
#' @param start Character `"YYYY-MM"` or a `Date` object.
#' @param end Character `"YYYY-MM"` or a `Date` object.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{`Date`. First day of the reference month.}
#'     \item{product}{Character. Product type identifier.}
#'     \item{description}{Character. Plain-English product label.}
#'     \item{receipts_gbp_m}{Numeric. Duty receipts in millions of pounds.}
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/tobacco-bulletin>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' # All products since 2015
#' get_tobacco_duties(start = "2015-01")
#'
#' # Cigarettes only
#' get_tobacco_duties(product = "cigarettes")
#' options(op)
#' }
#'
#' @family duties
#' @export
get_tobacco_duties <- function(product = NULL,
                               start   = NULL,
                               end     = NULL,
                               cache   = TRUE) {

  valid_products <- c("cigarettes", "cigars", "hand_rolling", "other", "total")
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
  url  <- resolve_govuk_url(slug, "Tobacco_Tab")
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_tobacco_table(path)

  if (!is.null(product)) out <- out[out$product %in% product, ]
  out <- filter_dates(out, start, end)

  cli::cli_progress_done()
  out
}

# ── Internal parser ────────────────────────────────────────────────────────────

TOBACCO_COLS <- c(
  "cigarettes"   = "Cigarettes",
  "cigars"       = "Cigars",
  "hand_rolling" = "Hand-rolling tobacco",
  "other"        = "Other tobacco products",
  "total"        = "Total tobacco products"
)

parse_tobacco_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1_receipts",
                           col_names = FALSE, as_tibble = FALSE)

  # Find the monthly section: look for "Table_1c" or "Table 1c" label
  monthly_start <- NA_integer_
  for (i in seq_len(nrow(raw))) {
    cell <- trimws(as.character(raw[i, 1]))
    if (grepl("Table.*1c|by month", cell, ignore.case = TRUE)) {
      monthly_start <- i + 1
      break
    }
  }
  if (is.na(monthly_start)) {
    # Fallback: find first cell matching a month-year pattern
    for (i in seq_len(nrow(raw))) {
      cell <- trimws(as.character(raw[i, 1]))
      if (grepl("^[A-Za-z]+ \\d{4}$", cell)) {
        monthly_start <- i
        break
      }
    }
  }
  if (is.na(monthly_start)) {
    cli::cli_abort("Could not locate monthly data in tobacco bulletin. Please file an issue.")
  }

  data_rows <- raw[monthly_start:nrow(raw), ]

  dates_raw <- trimws(as.character(data_rows[[1]]))
  dates     <- suppressWarnings(
    as.Date(paste0("01 ", dates_raw), format = "%d %B %Y")
  )
  valid      <- !is.na(dates)
  dates      <- dates[valid]
  data_rows  <- data_rows[valid, ]

  # Columns 2–6: Cigarettes, Cigars, HRT, Other, Total
  col_keys  <- names(TOBACCO_COLS)
  col_descs <- unname(TOBACCO_COLS)

  results <- list()
  for (j in seq_along(col_keys)) {
    col_idx <- j + 1
    if (col_idx > ncol(data_rows)) break
    vals <- suppressWarnings(as.numeric(as.character(data_rows[[col_idx]])))
    results[[j]] <- data.frame(
      date           = dates,
      product        = col_keys[j],
      description    = col_descs[j],
      receipts_gbp_m = vals,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  out <- out[order(out$product, out$date), ]
  rownames(out) <- NULL
  out
}
