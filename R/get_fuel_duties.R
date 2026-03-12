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
#' @return A data frame with columns:
#'   \describe{
#'     \item{date}{`Date`. First day of the reference month.}
#'     \item{fuel}{Character. Fuel category identifier.}
#'     \item{description}{Character. Plain-English category label.}
#'     \item{receipts_gbp_m}{Numeric. Duty receipts in millions of pounds.}
#'   }
#'
#' @source
#' <https://www.gov.uk/government/statistics/hydrocarbon-oils-bulletin>
#'
#' @examples
#' \donttest{
#' # Total fuel duty receipts since 2010
#' get_fuel_duties(fuel = "total", start = "2010-01")
#'
#' # All categories
#' get_fuel_duties()
#' }
#'
#' @export
get_fuel_duties <- function(fuel  = NULL,
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
  url  <- resolve_govuk_url(slug, "Oils_Tab")
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_fuel_table(path)

  if (!is.null(fuel)) out <- out[out$fuel %in% fuel, ]
  out <- filter_dates(out, start, end)

  cli::cli_progress_done()
  out
}

# ── Internal parser ────────────────────────────────────────────────────────────

parse_fuel_table <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1_receipts",
                           col_names = FALSE, as_tibble = FALSE)

  # Find monthly section (Table 1c): labelled "Month" in col 1
  monthly_start <- NA_integer_
  for (i in seq_len(nrow(raw))) {
    cell <- trimws(as.character(raw[i, 1]))
    if (grepl("^Month$|Table.*1c|by month", cell, ignore.case = TRUE)) {
      monthly_start <- i + 1
      break
    }
  }
  if (is.na(monthly_start)) {
    cli::cli_abort(
      "Could not locate monthly data in hydrocarbon oils bulletin. Please file an issue."
    )
  }

  data_rows <- raw[monthly_start:nrow(raw), ]

  dates_raw <- trimws(as.character(data_rows[[1]]))
  dates     <- suppressWarnings(
    as.Date(paste0("01 ", dates_raw), format = "%d %B %Y")
  )
  valid     <- !is.na(dates)
  dates     <- dates[valid]
  data_rows <- data_rows[valid, ]

  n_cols <- ncol(data_rows)

  # Column map based on known ODS structure (17 cols total including date):
  # B-H: petrol types, I-M: diesel types, N-P: other, Q: total
  # We aggregate into 4 categories:
  #   petrol = cols 2:8 summed
  #   diesel = cols 9:13 summed
  #   other  = cols 14:16 summed
  #   total  = col 17

  safe_sum <- function(df, cols) {
    cols <- cols[cols <= ncol(df)]
    if (length(cols) == 0) return(rep(NA_real_, nrow(df)))
    vals <- suppressWarnings(
      apply(df[, cols, drop = FALSE], 2, function(x) as.numeric(as.character(x)))
    )
    if (is.null(dim(vals))) vals <- matrix(vals, ncol = 1)
    # Replace [No Data] / suppressed with 0 for aggregation
    vals[is.na(vals)] <- 0
    rowSums(vals)
  }

  categories <- list(
    list(key = "petrol", desc = "Petrol duties",        cols = 2:8),
    list(key = "diesel", desc = "Diesel duties",        cols = 9:13),
    list(key = "other",  desc = "Other fuel duties",    cols = 14:16),
    list(key = "total",  desc = "Total oils receipts",  cols = n_cols)
  )

  results <- list()
  for (cat in categories) {
    vals <- if (length(cat$cols) == 1) {
      suppressWarnings(as.numeric(as.character(data_rows[[cat$cols]])))
    } else {
      safe_sum(data_rows, cat$cols)
    }
    results[[length(results) + 1]] <- data.frame(
      date           = dates,
      fuel           = cat$key,
      description    = cat$desc,
      receipts_gbp_m = vals,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  out <- out[order(out$fuel, out$date), ]
  rownames(out) <- NULL
  out
}
