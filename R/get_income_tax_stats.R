#' Download HMRC Income Tax liabilities by income range
#'
#' Downloads and tidies HMRC Table 2.5, which reports the number of Income Tax
#' payers and their liabilities grouped by total income range, for each
#' available tax year. Numbers of taxpayers are in thousands; amounts are in
#' millions of pounds unless otherwise noted. Published annually in May/June.
#'
#' @param tax_year Character vector or `NULL` (default = all years). Filter to
#'   specific tax years, e.g. `"2023-24"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{tax_year}{Character. Tax year, e.g. `"2022-23"`.}
#'     \item{income_range}{Character. Income range label.}
#'     \item{income_lower_gbp}{Numeric. Lower limit of the income range in
#'       pounds. `NA` for the `"All Ranges"` row.}
#'     \item{taxpayers_thousands}{Numeric. Number of Income Tax payers
#'       (thousands).}
#'     \item{total_income_gbp_m}{Numeric. Total income (millions of pounds).}
#'     \item{tax_liability_gbp_m}{Numeric. Total Income Tax liability
#'       (millions of pounds).}
#'     \item{average_rate_pct}{Numeric. Average rate of Income Tax
#'       (percent).}
#'     \item{average_tax_gbp}{Numeric. Average amount of Income Tax per
#'       taxpayer (pounds).}
#'   }
#'
#' @details
#' The earliest tax year with outturn data is based on the Survey of Personal
#' Incomes; later years are projected estimates. Values suppressed for small
#' sample sizes are returned as `NA`.
#'
#' @source
#' <https://www.gov.uk/government/statistics/income-tax-liabilities-by-income-range>
#'
#' @examples
#' \donttest{
#' get_income_tax_stats()
#'
#' # Single tax year
#' get_income_tax_stats(tax_year = "2023-24")
#' }
#'
#' @export
get_income_tax_stats <- function(tax_year = NULL,
                                 cache    = TRUE) {

  slug <- "income-tax-liabilities-by-income-range"
  url  <- resolve_govuk_url(slug, "Table_2\\.5")
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")

  sheets <- readODS::list_ods_sheets(path)
  data_sheets <- sheets[grepl("^2_5_IT_Liabilities_", sheets)]

  if (length(data_sheets) == 0) {
    cli::cli_abort("No data sheets found in Table 2.5 file. Please file an issue.")
  }

  results <- lapply(data_sheets, function(s) {
    parse_income_tax_sheet(path, s)
  })
  out <- do.call(rbind, results)

  if (!is.null(tax_year)) {
    bad <- setdiff(tax_year, unique(out$tax_year))
    if (length(bad) > 0) {
      cli::cli_warn(c(
        "Tax year{?s} not found: {.val {bad}}",
        "i" = "Available years: {.val {unique(out$tax_year)}}"
      ))
    }
    out <- out[out$tax_year %in% tax_year, ]
  }

  rownames(out) <- NULL
  cli::cli_progress_done()
  out
}

# -- Internal parser -----------------------------------------------------------

parse_income_tax_sheet <- function(path, sheet) {
  # Extract tax year from sheet name: "2_5_IT_Liabilities_2022-23" -> "2022-23"
  yr <- sub("^2_5_IT_Liabilities_", "", sheet)

  raw <- readODS::read_ods(path, sheet = sheet,
                            col_names = FALSE, as_tibble = FALSE)

  # Row 3 = headers, rows 4+ = data, row with "End of worksheet" = stop
  # 14 columns: see column layout below
  # Col 1:  Range of total income (lower limit)
  # Col 10: Total number of IT payers (thousands)
  # Col 11: Total income (£m)
  # Col 12: Total IT liability (£m)
  # Col 13: Average rate of IT (%)
  # Col 14: Average amount of IT (£)

  data_rows <- raw[4:nrow(raw), ]
  range_raw <- trimws(as.character(data_rows[[1]]))
  valid     <- nzchar(range_raw) &
    !grepl("End of|^NA$", range_raw, ignore.case = TRUE)
  data_rows <- data_rows[valid, ]
  range_raw <- range_raw[valid]

  if (nrow(data_rows) == 0) {
    cli::cli_abort("No data rows found in sheet {.val {sheet}}.")
  }

  # Parse income lower limit
  income_lower <- vapply(range_raw, function(x) {
    if (grepl("All Ranges", x, ignore.case = TRUE)) return(NA_real_)
    # Strip £, commas, + signs
    cleaned <- gsub("[\u00a3,+]", "", trimws(x))
    suppressWarnings(as.numeric(cleaned))
  }, numeric(1), USE.NAMES = FALSE)

  # Clean labels
  income_range <- vapply(range_raw, function(x) {
    if (grepl("All Ranges", x, ignore.case = TRUE)) return("All Ranges")
    cleaned <- gsub("[\u00a3,]", "", trimws(x))
    cleaned
  }, character(1), USE.NAMES = FALSE)

  # Helper to parse numeric columns with "[no estimate]" -> NA
  parse_num <- function(col) {
    vals <- trimws(as.character(data_rows[[col]]))
    vals <- gsub("[%\u00a3,]", "", vals)
    vals[grepl("no estimate", vals, ignore.case = TRUE)] <- NA_character_
    suppressWarnings(as.numeric(vals))
  }

  data.frame(
    tax_year            = yr,
    income_range        = income_range,
    income_lower_gbp    = income_lower,
    taxpayers_thousands = parse_num(10),
    total_income_gbp_m  = parse_num(11),
    tax_liability_gbp_m = parse_num(12),
    average_rate_pct    = parse_num(13),
    average_tax_gbp     = parse_num(14),
    stringsAsFactors    = FALSE
  )
}
