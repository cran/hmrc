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
#' @return An `hmrc_tbl` with columns `tax_year`, `income_range`,
#'   `income_lower_gbp`, `taxpayers_thousands`, `total_income_gbp_m`,
#'   `tax_liability_gbp_m`, `average_rate_pct`, `average_tax_gbp`.
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
#' op <- options(hmrc.cache_dir = tempdir())
#' hmrc_income_tax_stats()
#' hmrc_income_tax_stats(tax_year = "2023-24")
#' options(op)
#' }
#'
#' @family data fetchers
#' @export
hmrc_income_tax_stats <- function(tax_year = NULL,
                                  cache    = TRUE) {

  slug <- "income-tax-liabilities-by-income-range"
  loc  <- resolve_govuk_attachment(slug, "Table_2\\.5")
  path <- download_cached(loc$attachment_url, cache = cache)

  cli::cli_progress_step("Parsing data")

  sheets      <- readODS::list_ods_sheets(path)
  data_sheets <- sheets[grepl("^2_5_IT_Liabilities_", sheets)]

  if (length(data_sheets) == 0) {
    cli::cli_abort("No data sheets found in Table 2.5 file. Please file an issue.")
  }

  results <- lapply(data_sheets, function(s) parse_income_tax_sheet(path, s))
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

  new_hmrc_tbl(
    out,
    dataset          = "income_tax_liabilities_by_range",
    hmrc_publication = "Income Tax liabilities by income range (Table 2.5)",
    source_url       = loc$page_url,
    attachment_url   = loc$attachment_url,
    slug             = slug,
    cell_methods     = "liabilities",
    frequency        = "annual"
  )
}

# -- Internal parser -----------------------------------------------------------

parse_income_tax_sheet <- function(path, sheet) {
  yr <- sub("^2_5_IT_Liabilities_", "", sheet)

  raw <- readODS::read_ods(path, sheet = sheet,
                           col_names = FALSE, as_tibble = FALSE)

  data_rows <- raw[4:nrow(raw), ]
  range_raw <- trimws(as.character(data_rows[[1]]))
  valid     <- nzchar(range_raw) &
    !grepl("End of|^NA$", range_raw, ignore.case = TRUE)
  data_rows <- data_rows[valid, ]
  range_raw <- range_raw[valid]

  if (nrow(data_rows) == 0) {
    cli::cli_abort("No data rows found in sheet {.val {sheet}}.")
  }

  income_lower <- vapply(range_raw, function(x) {
    if (grepl("All Ranges", x, ignore.case = TRUE)) return(NA_real_)
    cleaned <- gsub("[\u00a3,+]", "", trimws(x))
    suppressWarnings(as.numeric(cleaned))
  }, numeric(1), USE.NAMES = FALSE)

  income_range <- vapply(range_raw, function(x) {
    if (grepl("All Ranges", x, ignore.case = TRUE)) return("All Ranges")
    gsub("[\u00a3,]", "", trimws(x))
  }, character(1), USE.NAMES = FALSE)

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
