#' Download HMRC tax gap estimates
#'
#' Downloads and tidies the HMRC Measuring the Tax Gap publication, which
#' estimates the difference between the tax theoretically owed and the tax
#' actually collected, broken down by tax type and taxpayer group. Published
#' annually in June, covering the most recent financial year.
#'
#' @param tax Character vector or `NULL` (default = all taxes). Filter by
#'   tax type, e.g. `"Income Tax"`, `"VAT"`, `"Corporation Tax"`. Use
#'   `unique(get_tax_gap()$tax)` to see all available values.
#' @param cache Logical. Use cached file if available (default `TRUE`).
#'
#' @return A data frame with columns:
#'   \describe{
#'     \item{tax_year}{Character. Financial year of the estimate,
#'       e.g. `"2023-24"`.}
#'     \item{tax}{Character. Tax type.}
#'     \item{taxpayer_type}{Character. Taxpayer group (e.g. `"Individuals"`,
#'       `"Small businesses"`).}
#'     \item{component}{Character. Behaviour component (e.g. `"Evasion"`,
#'       `"Error"`, `"Avoidance"`).}
#'     \item{gap_pct}{Numeric. Tax gap as a percentage of the theoretical
#'       tax liability. `NA` where not disclosed.}
#'     \item{gap_gbp_bn}{Numeric. Absolute tax gap in billions of pounds.}
#'     \item{uncertainty}{Character. HMRC uncertainty rating for the
#'       estimate (e.g. `"Low"`, `"Medium"`, `"High"`).}
#'   }
#'
#' @details
#' The tax gap publication is cross-sectional: each edition covers a single
#' financial year. This function returns data for the most recent edition
#' available on GOV.UK. Historical estimates back to 2005-06 are available
#' in a separate HMRC publication (Measuring the Tax Gap: Time Series).
#'
#' @source
#' <https://www.gov.uk/government/statistics/measuring-tax-gaps>
#'
#' @examples
#' \donttest{
#' op <- options(hmrc.cache_dir = tempdir())
#' # Full tax gap breakdown
#' get_tax_gap()
#'
#' # VAT gap only
#' get_tax_gap(tax = "VAT")
#' options(op)
#' }
#'
#' @family data access
#' @export
get_tax_gap <- function(tax   = NULL,
                        cache = TRUE) {

  slug <- "measuring-tax-gaps-tables"
  url  <- resolve_govuk_url(slug, "Measuring_tax_gap_online")
  path <- download_cached(url, cache = cache)

  cli::cli_progress_step("Parsing data")
  out <- parse_tax_gap_table(path)

  if (!is.null(tax)) {
    bad <- setdiff(tax, unique(out$tax))
    if (length(bad) > 0) {
      cli::cli_warn(c(
        "Tax type{?s} not found: {.val {bad}}",
        "i" = "Call {.code get_tax_gap()} with no arguments to see available values."
      ))
    }
    out <- out[out$tax %in% tax, ]
  }

  cli::cli_progress_done()
  out
}

# -- Internal parser -----------------------------------------------------------

parse_tax_gap_table <- function(path) {
  # Tax gap is published as XLSX
  # Sheet "Table 1.1": rows 1-5 = metadata, row 6 = headers, rows 7+ = data
  # Cols: Tax | Type | Component | % gap | GBP bn gap | Uncertainty
  raw <- readxl::read_excel(path, sheet = "Table 1.1",
                             col_names = FALSE, .name_repair = "minimal")
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  # Extract financial year from the title row (row 1)
  tax_year <- NA_character_
  for (i in seq_len(min(6L, nrow(raw)))) {
    cell <- trimws(as.character(raw[i, 1L]))
    m    <- regmatches(cell, regexpr("20\\d{2}[[:space:]]to[[:space:]]20\\d{2}", cell))
    if (length(m) == 1L && nzchar(m)) {
      # Convert "2023 to 2024" -> "2023-24"
      yrs <- regmatches(m, gregexpr("20\\d{2}", m))[[1]]
      tax_year <- paste0(yrs[1], "-", substr(yrs[2], 3, 4))
      break
    }
    m2 <- regmatches(cell, regexpr("20\\d{2}-\\d{2}", cell))
    if (length(m2) == 1L && nzchar(m2)) { tax_year <- m2; break }
  }

  data_rows <- raw[7:nrow(raw), ]

  # Drop rows with no gap amount (trailing blank rows)
  valid <- !is.na(suppressWarnings(as.numeric(
    gsub("<|>|,", "", trimws(as.character(data_rows[[5]])))
  ))) | !is.na(suppressWarnings(as.numeric(
    gsub("%", "", trimws(as.character(data_rows[[4]])))
  )))
  data_rows <- data_rows[valid, ]

  if (nrow(data_rows) == 0) {
    cli::cli_abort("Could not locate data rows in tax gap table. Please file an issue.")
  }

  # Percentage column: strip "%" and "<" markers; "<0.1" -> 0.1 (approximate)
  pct_raw    <- gsub("[%<>]", "", trimws(as.character(data_rows[[4]])))
  gap_pct    <- suppressWarnings(as.numeric(pct_raw))

  # Absolute gap: strip "<" markers
  abs_raw    <- gsub("[\u00a3<>]", "", trimws(as.character(data_rows[[5]])))
  gap_gbp_bn <- suppressWarnings(as.numeric(abs_raw))

  out <- data.frame(
    tax_year      = tax_year,
    tax           = trimws(as.character(data_rows[[1]])),
    taxpayer_type = trimws(as.character(data_rows[[2]])),
    component     = trimws(as.character(data_rows[[3]])),
    gap_pct       = gap_pct,
    gap_gbp_bn    = gap_gbp_bn,
    uncertainty   = trimws(as.character(data_rows[[6]])),
    stringsAsFactors = FALSE
  )

  out <- out[order(out$tax, out$taxpayer_type, out$component), ]
  rownames(out) <- NULL
  out
}
