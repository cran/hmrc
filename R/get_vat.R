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
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{`Date`. First day of the reference month.}
#'     \item{measure}{Character. VAT measure identifier.}
#'     \item{description}{Character. Plain-English measure label.}
#'     \item{receipts_gbp_m}{Numeric. Value in millions of pounds. Repayments
#'       are negative (money flowing out from HMRC to businesses).}
#'   }
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
#' op <- options(hmrc.cache_dir = tempdir())
#' # Total VAT receipts since 2010
#' get_vat(measure = "total", start = "2010-01")
#'
#' # Full breakdown
#' get_vat(start = "2020-01")
#' options(op)
#' }
#'
#' @family tax receipts
#' @export
get_vat <- function(measure = NULL,
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
  url  <- resolve_govuk_url(slug, "Annual_UK_VAT")
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_vat_table(path)

  if (!is.null(measure)) out <- out[out$measure %in% measure, ]
  out <- filter_dates(out, start, end)

  cli::cli_progress_done()
  out
}

# ── Internal parser ────────────────────────────────────────────────────────────

VAT_COLS <- c(
  "payments"   = "VAT payments",
  "repayments" = "VAT repayments",
  "import_vat" = "Import VAT",
  "home_vat"   = "Home VAT",
  "total"      = "Total VAT receipts"
)

parse_vat_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "T1_VAT_receipts",
                           col_names = FALSE, as_tibble = FALSE)

  # Find the monthly sub-table: "Table 1b" label or "by calendar year and month"
  monthly_start <- NA_integer_
  for (i in seq_len(nrow(raw))) {
    cell <- trimws(as.character(raw[i, 1]))
    if (grepl("Table.*1b|by calendar year and month", cell, ignore.case = TRUE)) {
      monthly_start <- i + 1
      break
    }
  }
  if (is.na(monthly_start)) {
    cli::cli_abort("Could not locate monthly VAT data. Please file an issue.")
  }

  data_rows <- raw[monthly_start:nrow(raw), ]

  dates_raw <- trimws(as.character(data_rows[[1]]))
  dates     <- suppressWarnings(
    as.Date(paste0("01 ", dates_raw), format = "%d %B %Y")
  )
  valid     <- !is.na(dates)
  dates     <- dates[valid]
  data_rows <- data_rows[valid, ]

  col_keys  <- names(VAT_COLS)
  col_descs <- unname(VAT_COLS)

  results <- list()
  for (j in seq_along(col_keys)) {
    col_idx <- j + 1
    if (col_idx > ncol(data_rows)) break
    raw_vals <- as.character(data_rows[[col_idx]])
    # Suppress [x] markers (confidential / not available)
    raw_vals[grepl("\\[", raw_vals)] <- NA_character_
    vals <- suppressWarnings(as.numeric(raw_vals))

    results[[j]] <- data.frame(
      date           = dates,
      measure        = col_keys[j],
      description    = col_descs[j],
      receipts_gbp_m = vals,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  out <- out[order(out$measure, out$date), ]
  rownames(out) <- NULL
  out
}
