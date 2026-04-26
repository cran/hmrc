#' Download HMRC Capital Gains Tax statistics
#'
#' Downloads and tidies HMRC Table 1 of the Capital Gains Tax statistics
#' bulletin: estimated number of CGT taxpayers, amounts of gains, and tax
#' liabilities by year of disposal. Data runs from 1987-88 onwards and is
#' published annually each summer.
#'
#' @param tax_year Character vector or `NULL` (default = all years).
#'   Filter to specific tax years, e.g. `"2022-23"`.
#' @param measure Character vector or `NULL` (default = all measures).
#'   Valid values: `"taxpayers_total_thousands"`,
#'   `"taxpayers_individuals_thousands"`, `"taxpayers_trusts_thousands"`,
#'   `"males_pct"`, `"females_pct"`,
#'   `"gains_individuals_gbp_m"`, `"gains_trusts_gbp_m"`,
#'   `"gains_total_gbp_m"`, `"tax_individuals_gbp_m"`,
#'   `"tax_trusts_gbp_m"`, `"tax_total_gbp_m"`.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return An `hmrc_tbl` (long format) with columns `tax_year`, `measure`,
#'   `value`. Numbers of taxpayers are in thousands; amounts in millions
#'   of pounds; percentages in percent. Suppressed cells return `NA`.
#'
#' @details
#' Gains are after the deduction of taper relief and losses plus attributed
#' gains, but before deduction of the Annual Exempt Amount. Trusts include
#' personal representatives of the deceased. Statistics for the latest two
#' tax years are provisional and are revised in subsequent publications as
#' late returns arrive.
#'
#' @source
#' <https://www.gov.uk/government/organisations/hm-revenue-customs/series/capital-gains-tax-statistics>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_capital_gains()
#' hmrc_capital_gains(measure = "tax_total_gbp_m")
#' hmrc_capital_gains(tax_year = "2022-23")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_capital_gains <- function(tax_year = NULL,
                               measure  = NULL,
                               cache    = TRUE) {

  valid_measures <- names(CGT_T1_COLS)
  if (!is.null(measure)) {
    bad <- setdiff(measure, valid_measures)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown measure{?s}: {.val {bad}}",
        "i" = "Valid values: {.val {valid_measures}}"
      ))
    }
  }

  slug <- "capital-gains-tax-statistics"
  loc  <- resolve_govuk_attachment(slug, "Table_1_.*Taxpayer_numbers.*\\.ods")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_cgt_table1(path)

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
  if (!is.null(measure)) out <- out[out$measure %in% measure, ]
  rownames(out) <- NULL

  cli::cli_progress_done()

  new_hmrc_tbl(
    out,
    dataset          = "capital_gains_tax_annual",
    hmrc_publication = "Capital Gains Tax statistics (Table 1)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "liabilities",
    frequency        = "annual"
  )
}

# ── Internal parser ────────────────────────────────────────────────────────────
#
# CGT Table 1 layout (HMRC publication, July release):
#   Row 8 = column headers
#   Row 9+ = data, one row per tax year (e.g. "1987 to 1988")
#   Col 1: Year of disposal
#   Cols 2-12: 11 measures (taxpayers, gains, tax for individuals / trusts /
#              total; plus males/females percentages)
# Suppressed cells hold "[Unavailable]" or similar text and become NA.

CGT_T1_COLS <- c(
  taxpayers_individuals_thousands = "Number of individuals",
  males_pct                       = "Males as %",
  females_pct                     = "Females as %",
  gains_individuals_gbp_m         = "Amounts of gains for individuals",
  tax_individuals_gbp_m           = "Amounts of tax for individuals",
  taxpayers_trusts_thousands      = "Number of trusts",
  gains_trusts_gbp_m              = "Amounts of gains for trusts",
  tax_trusts_gbp_m                = "Amounts of tax for trusts",
  taxpayers_total_thousands       = "Total taxpayers",
  gains_total_gbp_m               = "Total amounts of gains",
  tax_total_gbp_m                 = "Total amounts of tax"
)

parse_cgt_table1 <- function(path) {
  raw <- readODS::read_ods(path, sheet = "Table_1",
                           col_names = FALSE, as_tibble = FALSE)

  # Find the row with "Year of disposal" anchor (header row)
  hdr_row <- NA_integer_
  for (i in seq_len(nrow(raw))) {
    cell <- trimws(as.character(raw[i, 1]))
    if (identical(tolower(cell), "year of disposal")) {
      hdr_row <- i
      break
    }
  }
  if (is.na(hdr_row)) {
    cli::cli_abort("Could not locate header row in CGT Table 1. Please file an issue.")
  }

  data_rows <- raw[(hdr_row + 1L):nrow(raw), ]

  # Tax year is in col 1: "1987 to 1988" -> "1987-88"
  yr_raw <- trimws(as.character(data_rows[[1]]))
  # Strip "[Note ...]" footnote markers
  yr_raw <- trimws(gsub("\\[Note[^\\]]*\\]", "", yr_raw))
  is_year <- grepl("^\\d{4}\\s+to\\s+\\d{4}$", yr_raw)
  data_rows <- data_rows[is_year, ]
  yr_raw    <- yr_raw[is_year]

  to_yyyy_yy <- function(x) {
    parts <- regmatches(x, gregexpr("\\d{4}", x))
    vapply(parts, function(p) {
      if (length(p) >= 2L) paste0(p[1], "-", substr(p[2], 3, 4)) else NA_character_
    }, character(1))
  }
  tax_years <- to_yyyy_yy(yr_raw)

  parse_num <- function(x) {
    x <- gsub(",", "", trimws(as.character(x)))
    x[grepl("\\[", x)] <- NA_character_
    suppressWarnings(as.numeric(x))
  }

  results <- list()
  measure_keys <- names(CGT_T1_COLS)
  for (j in seq_along(measure_keys)) {
    col_idx <- j + 1L
    if (col_idx > ncol(data_rows)) break
    results[[j]] <- data.frame(
      tax_year = tax_years,
      measure  = measure_keys[j],
      value    = parse_num(data_rows[[col_idx]]),
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  out <- out[order(out$measure, out$tax_year), ]
  rownames(out) <- NULL
  out
}
